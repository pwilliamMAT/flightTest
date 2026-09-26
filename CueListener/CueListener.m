classdef CueListener < handle
    %CUELISTENER Receive ADS-B cue-tasker messages and keep the planner's view of them.
    %
    %   Concept
    %   -------
    %   The ADS-B cue tasker (ADSB-remoter `adsb-console --headless`, running on the
    %   ADS-B Raspberry Pi) watches the dump1090 feed, predicts where each aircraft
    %   will be over the next 10 minutes, and works out which DTV towers would
    %   illuminate it well enough for passive radar from our receive site. It
    %   "rings the bell" by sending one small JSON message per aircraft over UDP
    %   multicast. Deciding *which* aircraft to collect on, with which tower and
    %   when, is the job of this side of the system (the resource manager), so this
    %   class only listens, keeps the latest cue for every aircraft, and answers the
    %   question "what are the best opportunities right now?".
    %
    %   Message types (JSON schemas 1.1.0 in the ADSB-remoter repo):
    %     track_cue              latest prediction for one aircraft, with up to N
    %                            (default 3) DTV opportunities ranked by peak SNR,
    %                            each with its predicted observation windows
    %     track_cue_withdrawal   the aircraft is gone; forget that prediction
    %     cue_heartbeat          sender health: starting / running / degraded / stopping
    %     cue_snapshot_begin/end brackets a periodic resend of every active cue
    %
    %   Why Java sockets: MATLAB's udpport can join a multicast group only on
    %   Windows, and it cannot choose which network interface joins. The RF
    %   collection desktop's default route is Wi-Fi, so the join must be made
    %   explicitly on the data-network interface (192.168.10.41). A
    %   java.net.MulticastSocket does both, on Linux and Windows.
    %
    %   Workflow
    %   --------
    %     L = CueListener();              % multicast 239.192.10.1:31986 on 192.168.10.41
    %     start(L);
    %     poll(L);                        % drain whatever has arrived (or use Background=true)
    %     activeCues(L)                   % one row per aircraft, best opportunity first
    %     opportunities(L, "adsb:A8D5A0") % every predicted window for one aircraft
    %     stop(L);
    %
    %     L = CueListener.replay("capture.jsonl");   % offline, from a LogFile or cue_capture.py log
    %
    %   Name-value options
    %   ------------------
    %     MulticastGroup      group to join; "" for unicast only    (default "239.192.10.1")
    %     Port                UDP port; 0 picks a free port          (default 31986)
    %     InterfaceAddress    local address whose interface joins    (default "192.168.10.41")
    %     ReceiveBufferBytes  socket buffer; snapshot bursts overflow the kernel default (8 MiB)
    %     LogFile             append every datagram as JSONL, cue_capture.py format ("" = off)
    %     DtvTableFile        FCC DTV CSV used to turn emitter ids into call signs
    %     Background          poll from a MATLAB timer after start()  (default false)
    %     PollPeriod_s        timer period when Background is true    (default 0.25)
    %     MessageFcn          @(msg, listener) called for every decoded message ([] = none)
    %
    %   See also runCueListener, plotCueWindows, helperCueParseUtc.

    properties (SetAccess = private)
        MulticastGroup (1,1) string
        Port (1,1) double
        InterfaceAddress (1,1) string
        ReceiveBufferBytes (1,1) double
        LogFile (1,1) string
        DtvTableFile (1,1) string
        Background (1,1) logical
        PollPeriod_s (1,1) double
        MessageFcn
        % Latest track_cue struct per track_id.
        Tracks
        % Last withdrawal struct per track_id.
        Withdrawn
        % Last cue_heartbeat struct and when it arrived (UTC).
        LastHeartbeat struct = struct([])
        LastHeartbeatReceivedUtc (1,1) datetime = NaT('TimeZone', 'UTC')
        % source_instance_id of the cue tasker currently being followed.
        SourceInstanceId (1,1) string = ""
        % Counters: received messages, decode errors, sequence gaps, restarts, ...
        Stats struct
    end

    properties (Dependent)
        LocalPort
        IsRunning
    end

    properties (Access = private)
        Socket = []
        Packet = []
        GroupAddress = []
        NetworkInterface = []
        LogFid = -1
        Timer = []
        NextSequence = NaN
        CallSigns
    end

    properties (Constant, Access = private)
        BufferBytes = 65535
        MaxDatagramsPerPoll = 2000
    end

    methods
        function obj = CueListener(varargin)
            p = inputParser;
            p.FunctionName = 'CueListener';
            addParameter(p, 'MulticastGroup', "239.192.10.1", @localIsText);
            addParameter(p, 'Port', 31986, @(x) isnumeric(x) && isscalar(x) && x >= 0);
            addParameter(p, 'InterfaceAddress', "192.168.10.41", @localIsText);
            addParameter(p, 'ReceiveBufferBytes', 8 * 1024 * 1024, @(x) isnumeric(x) && x > 0);
            addParameter(p, 'LogFile', "", @localIsText);
            addParameter(p, 'DtvTableFile', localDefaultDtvTable(), @localIsText);
            addParameter(p, 'Background', false, @(x) islogical(x) || isnumeric(x));
            addParameter(p, 'PollPeriod_s', 0.25, @(x) isnumeric(x) && x > 0);
            addParameter(p, 'MessageFcn', [], @(x) isempty(x) || isa(x, 'function_handle'));
            parse(p, varargin{:});
            o = p.Results;

            obj.MulticastGroup = string(o.MulticastGroup);
            obj.Port = o.Port;
            obj.InterfaceAddress = string(o.InterfaceAddress);
            obj.ReceiveBufferBytes = o.ReceiveBufferBytes;
            obj.LogFile = string(o.LogFile);
            obj.DtvTableFile = string(o.DtvTableFile);
            obj.Background = logical(o.Background);
            obj.PollPeriod_s = o.PollPeriod_s;
            obj.MessageFcn = o.MessageFcn;
            obj.Tracks = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Withdrawn = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Stats = localEmptyStats();
            obj.CallSigns = localLoadCallSigns(obj.DtvTableFile);
        end

        function start(obj)
            %START Open the socket, join the multicast group and (optionally) start polling.
            if obj.IsRunning
                return
            end
            % MulticastSocket(SocketAddress) sets SO_REUSEADDR before binding, so a
            % socat or cue_capture.py monitor can listen on the same port.
            obj.Socket = java.net.MulticastSocket(java.net.InetSocketAddress(obj.Port));
            obj.Socket.setReceiveBufferSize(obj.ReceiveBufferBytes);
            % receive() waits at most 1 ms, so poll() drains the queue without blocking.
            obj.Socket.setSoTimeout(1);
            if strlength(obj.MulticastGroup) > 0
                obj.GroupAddress = java.net.InetSocketAddress( ...
                    java.net.InetAddress.getByName(char(obj.MulticastGroup)), 0);
                if strlength(obj.InterfaceAddress) > 0
                    obj.NetworkInterface = java.net.NetworkInterface.getByInetAddress( ...
                        java.net.InetAddress.getByName(char(obj.InterfaceAddress)));
                    if isempty(obj.NetworkInterface)
                        obj.Socket.close();
                        obj.Socket = [];
                        error('CueListener:NoInterface', ...
                            'No local network interface has address %s.', obj.InterfaceAddress);
                    end
                    obj.Socket.joinGroup(obj.GroupAddress, obj.NetworkInterface);
                else
                    obj.Socket.joinGroup(obj.GroupAddress.getAddress());
                end
            end
            obj.Packet = java.net.DatagramPacket(zeros(1, obj.BufferBytes, 'int8'), obj.BufferBytes);
            if strlength(obj.LogFile) > 0
                obj.LogFid = fopen(obj.LogFile, 'a', 'n', 'UTF-8');
                if obj.LogFid < 0
                    obj.stop();
                    error('CueListener:LogFile', 'Cannot open log file %s.', obj.LogFile);
                end
            end
            if obj.Background
                obj.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', obj.PollPeriod_s, ...
                    'BusyMode', 'drop', 'Name', 'CueListenerPoll', ...
                    'TimerFcn', @(~, ~) obj.poll());
                start(obj.Timer);
            end
        end

        function stop(obj)
            %STOP Stop polling, leave the group and close the socket. The cue state is kept.
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                stop(obj.Timer);
                delete(obj.Timer);
            end
            obj.Timer = [];
            if ~isempty(obj.Socket)
                if ~isempty(obj.GroupAddress)
                    try
                        if isempty(obj.NetworkInterface)
                            obj.Socket.leaveGroup(obj.GroupAddress.getAddress());
                        else
                            obj.Socket.leaveGroup(obj.GroupAddress, obj.NetworkInterface);
                        end
                    catch
                        % Closing the socket drops the membership anyway.
                    end
                end
                obj.Socket.close();
            end
            obj.Socket = [];
            obj.Packet = [];
            obj.GroupAddress = [];
            obj.NetworkInterface = [];
            if obj.LogFid >= 0
                fclose(obj.LogFid);
                obj.LogFid = -1;
            end
        end

        function delete(obj)
            obj.stop();
        end

        function messages = poll(obj)
            %POLL Receive and process every datagram waiting on the socket.
            messages = {};
            if isempty(obj.Socket)
                return
            end
            for k = 1:obj.MaxDatagramsPerPoll
                % receive() shrinks the packet length to the last datagram, so reset it.
                obj.Packet.setLength(obj.BufferBytes);
                try
                    obj.Socket.receive(obj.Packet);
                catch err
                    if contains(err.message, 'SocketTimeoutException')
                        break
                    end
                    rethrow(err);
                end
                n = obj.Packet.getLength();
                data = obj.Packet.getData();
                text = native2unicode(typecast(data(1:n), 'uint8').', 'UTF-8');
                msg = obj.ingest(text);
                if ~isempty(msg)
                    messages{end + 1} = msg; %#ok<AGROW>
                end
            end
        end

        function msg = ingest(obj, text, receivedUtc)
            %INGEST Decode one JSON datagram, log it, and update the cue state.
            if nargin < 3
                receivedUtc = datetime('now', 'TimeZone', 'UTC');
            end
            if obj.LogFid >= 0
                fprintf(obj.LogFid, '{"received_unix_s":%.3f,"payload":%s}\n', ...
                    posixtime(receivedUtc), text);
            end
            try
                msg = jsondecode(text);
            catch
                obj.Stats.DecodeErrors = obj.Stats.DecodeErrors + 1;
                msg = [];
                return
            end
            msg = obj.ingestMessage(msg, receivedUtc);
        end

        function msg = ingestMessage(obj, msg, receivedUtc)
            %INGESTMESSAGE Update the cue state from one already-decoded message struct.
            if nargin < 3
                receivedUtc = datetime('now', 'TimeZone', 'UTC');
            end
            if ~isstruct(msg) || ~isscalar(msg) || ~isfield(msg, 'message_type')
                obj.Stats.DecodeErrors = obj.Stats.DecodeErrors + 1;
                msg = [];
                return
            end
            obj.Stats.Received = obj.Stats.Received + 1;
            obj.trackSequence(msg);
            type = char(msg.message_type);
            if isvarname(type)
                if isfield(obj.Stats.MessageCounts, type)
                    obj.Stats.MessageCounts.(type) = obj.Stats.MessageCounts.(type) + 1;
                else
                    obj.Stats.MessageCounts.(type) = 1;
                end
            end
            switch type
                case 'track_cue'
                    obj.applyTrackCue(msg);
                case 'track_cue_withdrawal'
                    obj.applyWithdrawal(msg);
                case 'cue_heartbeat'
                    obj.LastHeartbeat = msg;
                    obj.LastHeartbeatReceivedUtc = receivedUtc;
                case {'cue_snapshot_begin', 'cue_snapshot_end'}
                    % Snapshot cues are ordinary track cues; the brackets only count.
                otherwise
                    obj.Stats.UnknownMessages = obj.Stats.UnknownMessages + 1;
            end
            if ~isempty(obj.MessageFcn)
                obj.MessageFcn(msg, obj);
            end
        end

        function cue = latestCue(obj, trackId)
            %LATESTCUE The most recent track_cue struct for one track_id ([] if none).
            trackId = char(trackId);
            if isKey(obj.Tracks, trackId)
                cue = obj.Tracks(trackId);
            else
                cue = [];
            end
        end

        function tbl = activeCues(obj, varargin)
            %ACTIVECUES One row per cued aircraft, strongest best opportunity first.
            %   Cues whose prediction has expired (valid_until_utc before Now) are left
            %   out unless IncludeExpired is true. Aircraft with no usable opportunity
            %   sort last with NaN SNR.
            p = inputParser;
            addParameter(p, 'Now', datetime('now', 'TimeZone', 'UTC'), @(x) isdatetime(x));
            addParameter(p, 'IncludeExpired', false, @(x) islogical(x) || isnumeric(x));
            parse(p, varargin{:});
            now = localUtc(p.Results.Now);

            keys = obj.Tracks.keys();
            rows = cell(numel(keys), 1);
            for k = 1:numel(keys)
                cue = obj.Tracks(keys{k});
                validUntil = helperCueParseUtc(cue.prediction.valid_until_utc);
                if ~p.Results.IncludeExpired && validUntil < now
                    continue
                end
                rows{k} = obj.summarizeCue(cue, now, validUntil);
            end
            rows = [rows{:}];
            if isempty(rows)
                tbl = localEmptyActiveTable();
                return
            end
            tbl = struct2table(rows(:), 'AsArray', true);
            tbl = sortrows(tbl, 'BestPeakSNR_dB', 'descend', 'MissingPlacement', 'last');
        end

        function tbl = opportunities(obj, trackId)
            %OPPORTUNITIES Every predicted observation window for one aircraft.
            cue = obj.latestCue(trackId);
            rows = struct([]);
            if ~isempty(cue)
                opps = localAsCell(cue.opportunities);
                for i = 1:numel(opps)
                    opp = opps{i};
                    windows = localAsCell(opp.windows);
                    for j = 1:numel(windows)
                        w = windows{j};
                        row = struct( ...
                            'EmitterId', string(opp.emitter_id), ...
                            'Emitter', obj.emitterLabel(opp), ...
                            'Frequency_MHz', opp.carrier_frequency_hz / 1e6, ...
                            'RfChannel', localNumberOrNaN(opp.rf_channel), ...
                            'WindowStart', helperCueParseUtc(w.start_utc), ...
                            'WindowEnd', helperCueParseUtc(w.end_utc), ...
                            'Duration_s', w.duration_s, ...
                            'PeakSNR_dB', w.max_snr_db, ...
                            'MeanSNR_dB', w.mean_snr_db, ...
                            'PeakSNRTime', helperCueParseUtc(w.peak_snr_utc), ...
                            'MinBistaticRange_m', w.min_bistatic_range_m, ...
                            'MaxBistaticRange_m', w.max_bistatic_range_m, ...
                            'MinDoppler_Hz', w.min_bistatic_doppler_hz, ...
                            'MaxDoppler_Hz', w.max_bistatic_doppler_hz, ...
                            'EntryReason', string(w.entry_reason), ...
                            'ExitReason', string(w.exit_reason));
                        rows = [rows; row]; %#ok<AGROW>
                    end
                end
            end
            if isempty(rows)
                tbl = table();
                return
            end
            tbl = sortrows(struct2table(rows, 'AsArray', true), 'PeakSNR_dB', 'descend');
        end

        function s = status(obj)
            %STATUS Sender health and receive counters in one struct.
            s = struct( ...
                'IsRunning', obj.IsRunning, ...
                'SourceInstanceId', obj.SourceInstanceId, ...
                'HeartbeatStatus', "", ...
                'HeartbeatReceivedUtc', obj.LastHeartbeatReceivedUtc, ...
                'SenderActiveTracks', NaN, ...
                'SenderEligibleTracks', NaN, ...
                'CuedTracks', obj.Tracks.Count, ...
                'Stats', obj.Stats);
            if ~isempty(obj.LastHeartbeat)
                s.HeartbeatStatus = string(obj.LastHeartbeat.status);
                s.SenderActiveTracks = obj.LastHeartbeat.active_tracks;
                s.SenderEligibleTracks = obj.LastHeartbeat.cue_eligible_tracks;
            end
        end

        function value = get.LocalPort(obj)
            if isempty(obj.Socket)
                value = NaN;
            else
                value = double(obj.Socket.getLocalPort());
            end
        end

        function value = get.IsRunning(obj)
            value = ~isempty(obj.Socket);
        end
    end

    methods (Static)
        function obj = replay(logFile, varargin)
            %REPLAY Build a listener offline from a JSONL log.
            %   Accepts this class's LogFile format and tools/cue_capture.py output
            %   (lines of {"received_unix_s": ..., "payload": {...}}) as well as raw
            %   one-message-per-line JSON.
            obj = CueListener(varargin{:});
            lines = readlines(logFile, 'EmptyLineRule', 'skip');
            for k = 1:numel(lines)
                try
                    record = jsondecode(lines(k));
                catch
                    obj.Stats.DecodeErrors = obj.Stats.DecodeErrors + 1;
                    continue
                end
                receivedUtc = datetime('now', 'TimeZone', 'UTC');
                if isstruct(record) && isfield(record, 'payload')
                    if isfield(record, 'received_unix_s')
                        receivedUtc = datetime(record.received_unix_s, ...
                            'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                    end
                    record = record.payload;
                end
                obj.ingestMessage(record, receivedUtc);
            end
        end
    end

    methods (Access = private)
        function trackSequence(obj, msg)
            % Sequence numbers are per sender instance and rise by one per datagram,
            % so a jump means lost datagrams and a new source_instance_id means the
            % cue tasker restarted (its sequence starts again at 1).
            if ~isfield(msg, 'source_instance_id') || ~isfield(msg, 'sequence_number')
                return
            end
            source = string(msg.source_instance_id);
            sequence = double(msg.sequence_number);
            if source ~= obj.SourceInstanceId
                if strlength(obj.SourceInstanceId) > 0
                    obj.Stats.SourceRestarts = obj.Stats.SourceRestarts + 1;
                end
                obj.SourceInstanceId = source;
                obj.NextSequence = sequence + 1;
                return
            end
            if sequence > obj.NextSequence
                obj.Stats.SequenceGaps = obj.Stats.SequenceGaps + (sequence - obj.NextSequence);
            elseif sequence < obj.NextSequence
                obj.Stats.OutOfOrder = obj.Stats.OutOfOrder + 1;
            end
            obj.NextSequence = max(obj.NextSequence, sequence + 1);
        end

        function applyTrackCue(obj, cue)
            trackId = char(cue.track.track_id);
            if isKey(obj.Tracks, trackId)
                previous = obj.Tracks(trackId);
                sameSource = string(previous.source_instance_id) == string(cue.source_instance_id);
                if sameSource && previous.prediction.revision > cue.prediction.revision
                    obj.Stats.StaleRevisionsIgnored = obj.Stats.StaleRevisionsIgnored + 1;
                    return
                end
            end
            obj.Tracks(trackId) = cue;
            if isKey(obj.Withdrawn, trackId)
                remove(obj.Withdrawn, trackId);
            end
        end

        function applyWithdrawal(obj, withdrawal)
            trackId = char(withdrawal.track_id);
            obj.Withdrawn(trackId) = withdrawal;
            if isKey(obj.Tracks, trackId)
                current = obj.Tracks(trackId);
                if current.prediction.revision <= withdrawal.withdrawn_prediction_revision
                    remove(obj.Tracks, trackId);
                end
            end
        end

        function row = summarizeCue(obj, cue, now, validUntil)
            opps = localAsCell(cue.opportunities);
            state = cue.track.state;
            row = struct( ...
                'TrackId', string(cue.track.track_id), ...
                'ICAO', string(cue.track.icao), ...
                'Callsign', localStringOrEmpty(cue.track.callsign), ...
                'Revision', cue.prediction.revision, ...
                'ReportAge_s', seconds(now - helperCueParseUtc(cue.track.last_report_utc)), ...
                'ValidUntil', validUntil, ...
                'Opportunities', numel(opps), ...
                'BestEmitter', "", ...
                'BestFrequency_MHz', NaN, ...
                'BestPeakSNR_dB', NaN, ...
                'BestWindowStart', NaT('TimeZone', 'UTC'), ...
                'BestWindowEnd', NaT('TimeZone', 'UTC'), ...
                'Latitude_deg', state.latitude_deg, ...
                'Longitude_deg', state.longitude_deg, ...
                'Altitude_m', state.altitude_m_msl, ...
                'Maturity', string(cue.prediction.maturity));
            bestSnr = -Inf;
            for i = 1:numel(opps)
                windows = localAsCell(opps{i}.windows);
                for j = 1:numel(windows)
                    if windows{j}.max_snr_db > bestSnr
                        bestSnr = windows{j}.max_snr_db;
                        row.BestEmitter = obj.emitterLabel(opps{i});
                        row.BestFrequency_MHz = opps{i}.carrier_frequency_hz / 1e6;
                        row.BestPeakSNR_dB = bestSnr;
                        row.BestWindowStart = helperCueParseUtc(windows{j}.start_utc);
                        row.BestWindowEnd = helperCueParseUtc(windows{j}.end_utc);
                    end
                end
            end
        end

        function label = emitterLabel(obj, opp)
            % emitter_id is "dtv:<facility_id>:<rf_channel>:<MHz>"; show the call sign
            % from the FCC DTV table when it is available.
            label = string(opp.emitter_id);
            parts = split(label, ":");
            if numel(parts) >= 3 && isKey(obj.CallSigns, char(parts(2)))
                label = sprintf("%s ch%s", obj.CallSigns(char(parts(2))), parts(3));
            end
        end
    end
end

function tf = localIsText(x)
tf = (ischar(x) && (isrow(x) || isempty(x))) || (isstring(x) && isscalar(x));
end

function stats = localEmptyStats()
stats = struct('Received', 0, 'DecodeErrors', 0, 'SequenceGaps', 0, 'OutOfOrder', 0, ...
    'SourceRestarts', 0, 'StaleRevisionsIgnored', 0, 'UnknownMessages', 0, ...
    'MessageCounts', struct());
end

function items = localAsCell(value)
% jsondecode returns a struct array for uniform JSON arrays, a cell array for
% mixed ones, and [] for empty arrays or null.
if isempty(value)
    items = {};
elseif iscell(value)
    items = value(:).';
else
    items = num2cell(value(:).');
end
end

function value = localNumberOrNaN(x)
if isempty(x)
    value = NaN;
else
    value = double(x);
end
end

function value = localStringOrEmpty(x)
if isempty(x)
    value = "";
else
    value = string(x);
end
end

function t = localUtc(t)
if isempty(t.TimeZone)
    t.TimeZone = 'UTC';
end
end

function tbl = localEmptyActiveTable()
tbl = table('Size', [0 16], ...
    'VariableTypes', {'string', 'string', 'string', 'double', 'double', 'datetime', ...
    'double', 'string', 'double', 'double', 'datetime', 'datetime', 'double', 'double', ...
    'double', 'string'}, ...
    'VariableNames', {'TrackId', 'ICAO', 'Callsign', 'Revision', 'ReportAge_s', ...
    'ValidUntil', 'Opportunities', 'BestEmitter', 'BestFrequency_MHz', 'BestPeakSNR_dB', ...
    'BestWindowStart', 'BestWindowEnd', 'Latitude_deg', 'Longitude_deg', 'Altitude_m', ...
    'Maturity'});
end

function path = localDefaultDtvTable()
repoRoot = fileparts(fileparts(mfilename('fullpath')));
path = string(fullfile(repoRoot, 'TestSetupTesting', 'siteData', '20_DTV_direct_path_input.csv'));
end

function callSigns = localLoadCallSigns(path)
callSigns = containers.Map('KeyType', 'char', 'ValueType', 'char');
if strlength(path) == 0 || ~isfile(path)
    return
end
opts = detectImportOptions(path, 'TextType', 'string');
opts = setvartype(opts, {'facility_id', 'call_sign'}, 'string');
dtv = readtable(path, opts);
for k = 1:height(dtv)
    callSigns(char(dtv.facility_id(k))) = char(dtv.call_sign(k));
end
end
