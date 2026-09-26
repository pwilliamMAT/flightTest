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
    %   Message types (CT schema 2.0.0, ICD_Messages.md section 2; times are integer
    %   epoch milliseconds in *_utc_ms fields):
    %     track_cue              latest prediction for one aircraft, with up to 8 DTV
    %                            opportunities ranked by peak SNR (as many as fit one
    %                            Ethernet frame), each with its predicted windows
    %     track_cue_withdrawal   the aircraft is gone; forget that prediction
    %     cue_heartbeat          sender health: starting / running / degraded / stopping
    %     cue_snapshot_begin/end brackets a periodic resend of every active cue
    %
    %   Receiver rules (ICD_Messages.md section 2.0): keep the track_cue with the
    %   highest prediction.revision per track_id; delete a track on a withdrawal whose
    %   withdrawn_prediction_revision is at least the revision held; drop repeated
    %   message_id values; and treat a snapshot as complete when the number of
    %   track_cues received with its snapshot_id equals the published_track_count in
    %   cue_snapshot_end. A lost cue is repaired by the next 60 s snapshot.
    %
    %   Framing (ICD section 1.3): each datagram is either plain JSON (first byte '{')
    %   or compressed: 0xDC, a dictionary id, then raw deflate with that preset
    %   dictionary. The listener detects this per datagram and decodes with
    %   java.util.zip (plain Java 8, works in compiled apps). Dictionaries ship in
    %   CueListener/dictionaries and are checked against their SHA-256 when loaded.
    %   Messages whose schema_version is not 2.x are counted and dropped.
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
    %     DictionaryDir       folder of cue-dictionary-<id>.bin/.sha256 (default: dictionaries/)
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
        DictionaryDir (1,1) string
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
        % generated_utc_ms of the most recent snapshot that arrived complete.
        LastCompleteSnapshotUtc (1,1) datetime = NaT('TimeZone', 'UTC')
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
        % Compression dictionaries by id (int8 row vectors).
        Dictionaries
        % track_cues received so far per open snapshot_id.
        OpenSnapshots
        % Recently seen message_id values, oldest first, for de-duplication.
        SeenMessageIds
        SeenOrder = strings(0, 1)
    end

    properties (Constant, Access = private)
        BufferBytes = 65535
        MaxDatagramsPerPoll = 2000
        MaxRememberedMessageIds = 10000
        CompressedFrameTag = 220        % 0xDC
        PlainFrameFirstByte = 123       % '{'
        SupportedMajorVersion = "2"
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
            addParameter(p, 'DictionaryDir', localDefaultDictionaryDir(), @localIsText);
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
            obj.DictionaryDir = string(o.DictionaryDir);
            obj.Background = logical(o.Background);
            obj.PollPeriod_s = o.PollPeriod_s;
            obj.MessageFcn = o.MessageFcn;
            obj.Tracks = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Withdrawn = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Stats = localEmptyStats();
            obj.OpenSnapshots = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.SeenMessageIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
            obj.CallSigns = localLoadCallSigns(obj.DtvTableFile);
            obj.Dictionaries = localLoadDictionaries(obj.DictionaryDir);
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
                msg = obj.ingestDatagram(data(1:n).');
                if ~isempty(msg)
                    messages{end + 1} = msg; %#ok<AGROW>
                end
            end
        end

        function msg = ingestDatagram(obj, datagram, receivedUtc)
            %INGESTDATAGRAM Decode one datagram (plain or compressed) and ingest the message.
            if nargin < 3
                receivedUtc = datetime('now', 'TimeZone', 'UTC');
            end
            try
                text = obj.decodeDatagram(datagram);
            catch err
                obj.Stats.FrameErrors = obj.Stats.FrameErrors + 1;
                obj.Stats.LastFrameError = string(err.message);
                msg = [];
                return
            end
            msg = obj.ingest(text, receivedUtc);
        end

        function text = decodeDatagram(obj, datagram)
            %DECODEDATAGRAM The UTF-8 JSON text carried by one datagram (ICD section 1.3).
            %   DATAGRAM is int8 or uint8 bytes. Plain datagrams start with '{'; compressed
            %   ones are 0xDC, a dictionary id, then raw deflate with that preset dictionary.
            datagram = datagram(:).';
            if isa(datagram, 'int8')
                bytes = typecast(datagram, 'uint8');     % Java byte[] arrives as int8
            else
                bytes = uint8(datagram);
            end
            if isempty(bytes)
                error('CueListener:EmptyDatagram', 'Empty datagram.');
            end
            if bytes(1) == obj.PlainFrameFirstByte
                obj.Stats.PlainDatagrams = obj.Stats.PlainDatagrams + 1;
                text = native2unicode(bytes, 'UTF-8');
                return
            end
            if bytes(1) ~= obj.CompressedFrameTag
                error('CueListener:UnknownFrame', 'Unknown frame tag 0x%02X.', bytes(1));
            end
            if numel(bytes) < 3
                error('CueListener:TruncatedFrame', 'Truncated compressed datagram.');
            end
            dictionaryId = double(bytes(2));
            if ~isKey(obj.Dictionaries, dictionaryId)
                error('CueListener:UnknownDictionary', 'Unknown dictionary id %d.', dictionaryId);
            end
            % MATLAB passes arrays to Java by copy, so write the compressed bytes into an
            % InflaterOutputStream and read the result back from the ByteArrayOutputStream.
            inflater = java.util.zip.Inflater(true);      % raw deflate, no zlib header
            inflater.setDictionary(obj.Dictionaries(dictionaryId));
            sink = java.io.ByteArrayOutputStream(16384);
            stream = java.util.zip.InflaterOutputStream(sink, inflater);
            stream.write(typecast(bytes(3:end), 'int8'));
            stream.close();
            inflater.end();
            obj.Stats.CompressedDatagrams = obj.Stats.CompressedDatagrams + 1;
            text = native2unicode(typecast(sink.toByteArray(), 'uint8').', 'UTF-8');
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
            if ~isfield(msg, 'schema_version') || ...
                    ~startsWith(string(msg.schema_version), obj.SupportedMajorVersion + ".")
                obj.Stats.UnsupportedVersion = obj.Stats.UnsupportedVersion + 1;
                msg = [];
                return
            end
            if isfield(msg, 'message_id') && obj.isDuplicate(msg.message_id)
                obj.Stats.Duplicates = obj.Stats.Duplicates + 1;
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
                    obj.countSnapshotCue(msg);
                    obj.applyTrackCue(msg);
                case 'track_cue_withdrawal'
                    obj.applyWithdrawal(msg);
                case 'cue_heartbeat'
                    obj.LastHeartbeat = msg;
                    obj.LastHeartbeatReceivedUtc = receivedUtc;
                case 'cue_snapshot_begin'
                    obj.OpenSnapshots(char(msg.snapshot_id)) = 0;
                case 'cue_snapshot_end'
                    obj.closeSnapshot(msg);
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
            %   Cues whose prediction has expired (valid_until_utc_ms before Now) are left
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
                validUntil = helperCueParseUtc(cue.prediction.valid_until_utc_ms);
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
                            'WindowStart', helperCueParseUtc(w.start_utc_ms), ...
                            'WindowEnd', helperCueParseUtc(w.end_utc_ms), ...
                            'Duration_s', w.duration_s, ...
                            'PeakSNR_dB', w.max_snr_db, ...
                            'MeanSNR_dB', w.mean_snr_db, ...
                            'PeakSNRTime', helperCueParseUtc(w.peak_snr_utc_ms), ...
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
                'CuedTracks', double(obj.Tracks.Count), ...
                'LastCompleteSnapshotUtc', obj.LastCompleteSnapshotUtc, ...
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
            %   Accepts this class's LogFile format, ADSB-remoter tools/cue_capture.py
            %   output (lines of {"received_unix_s", "payload", "datagram_b64"}), and raw
            %   one-message-per-line JSON. When a line carries the wire bytes
            %   (datagram_b64), those are decoded exactly as a live datagram would be.
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
                if isstruct(record) && isfield(record, 'received_unix_s')
                    receivedUtc = datetime(record.received_unix_s, ...
                        'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
                end
                if isstruct(record) && isfield(record, 'datagram_b64')
                    obj.ingestDatagram(matlab.net.base64decode(record.datagram_b64), receivedUtc);
                    continue
                end
                if isstruct(record) && isfield(record, 'payload')
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

        function tf = isDuplicate(obj, messageId)
            key = char(messageId);
            tf = isKey(obj.SeenMessageIds, key);
            if tf
                return
            end
            obj.SeenMessageIds(key) = true;
            obj.SeenOrder(end + 1, 1) = string(key);
            if numel(obj.SeenOrder) > obj.MaxRememberedMessageIds
                remove(obj.SeenMessageIds, char(obj.SeenOrder(1)));
                obj.SeenOrder(1) = [];
            end
        end

        function countSnapshotCue(obj, cue)
            if ~isfield(cue, 'snapshot_id') || isempty(cue.snapshot_id)
                return
            end
            key = char(cue.snapshot_id);
            if isKey(obj.OpenSnapshots, key)
                obj.OpenSnapshots(key) = obj.OpenSnapshots(key) + 1;
            else
                % The begin bracket was lost; count the cues anyway.
                obj.OpenSnapshots(key) = 1;
            end
        end

        function closeSnapshot(obj, snapshotEnd)
            key = char(snapshotEnd.snapshot_id);
            received = 0;
            if isKey(obj.OpenSnapshots, key)
                received = obj.OpenSnapshots(key);
                remove(obj.OpenSnapshots, key);
            end
            if received == snapshotEnd.published_track_count
                obj.Stats.SnapshotsComplete = obj.Stats.SnapshotsComplete + 1;
                obj.LastCompleteSnapshotUtc = helperCueParseUtc(snapshotEnd.generated_utc_ms);
            else
                % Some snapshot cues were lost; the next snapshot repairs them.
                obj.Stats.SnapshotsIncomplete = obj.Stats.SnapshotsIncomplete + 1;
            end
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
                'ReportAge_s', seconds(now - helperCueParseUtc(cue.track.last_report_utc_ms)), ...
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
                        row.BestWindowStart = helperCueParseUtc(windows{j}.start_utc_ms);
                        row.BestWindowEnd = helperCueParseUtc(windows{j}.end_utc_ms);
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
    'Duplicates', 0, 'SnapshotsComplete', 0, 'SnapshotsIncomplete', 0, ...
    'PlainDatagrams', 0, 'CompressedDatagrams', 0, 'FrameErrors', 0, 'LastFrameError', "", ...
    'UnsupportedVersion', 0, 'MessageCounts', struct());
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

function path = localDefaultDictionaryDir()
path = string(fullfile(fileparts(mfilename('fullpath')), 'dictionaries'));
end

function dictionaries = localLoadDictionaries(folder)
% Released compression dictionaries by id, each checked against its .sha256 file.
dictionaries = containers.Map('KeyType', 'double', 'ValueType', 'any');
if strlength(folder) == 0 || ~isfolder(folder)
    return
end
files = dir(fullfile(folder, 'cue-dictionary-*.bin'));
for k = 1:numel(files)
    [~, stem] = fileparts(files(k).name);
    id = str2double(extractAfter(stem, 'cue-dictionary-'));
    fid = fopen(fullfile(folder, files(k).name), 'r');
    bytes = fread(fid, Inf, '*uint8').';
    fclose(fid);
    expected = strtok(fileread(fullfile(folder, stem + ".sha256")));
    digest = java.security.MessageDigest.getInstance('SHA-256').digest(typecast(bytes, 'int8'));
    actual = lower(reshape(dec2hex(typecast(digest, 'uint8'), 2).', 1, []));
    if ~strcmp(actual, expected)
        error('CueListener:DictionaryChecksum', '%s: SHA-256 %s does not match %s.', ...
            files(k).name, actual, expected);
    end
    dictionaries(id) = typecast(bytes, 'int8');
end
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
