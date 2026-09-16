function [session_id, written_files] = log_iq_n320_2antennas(varargin)
% log_iq_n320_2antennas: Dual-channel IQ logger for Passive Radar.
% Captures phase-coherent data from two explicitly ordered N320 ports.
%
% Example run:
% matlab -batch "log_iq_n320_2antennas('radio','My USRP N320','cf',599e6,'sr',6.144e6,'lo',0,'gain',[16 16],'dur',10,'file','n320_dual_capture.bb')"
%% 1. Auto-Configure System for N320 Capture
% All three settings are persisted at boot via system configuration:
%   A. MTU 9000       — NetworkManager profile (nmcli connection modify)
%   B. CPU governor   — /etc/systemd/system/cpu-performance.service
%   C. Socket buffers — /etc/sysctl.d/99-usrp-n320.conf
% sudo -n is used here so that if a setting ever reverts, the call fails
% immediately with a warning rather than hanging (no TTY in matlab -batch).
if isunix
    intf = 'eno1'; %'enxa0cec8c28955'; <- if using USB Dongle

    % A. Jumbo Frames — only set if not already 9000
    [~, result] = system(['ip link show ', intf]);
    if ~contains(result, 'mtu 9000')
        fprintf('Setting MTU 9000 on %s...\n', intf);
        rc = system(['sudo -n ip link set ', intf, ' mtu 9000']);
        if rc ~= 0
            warning('MTU set failed (rc=%d). Run: sudo ip link set %s mtu 9000', rc, intf);
        end
    else
        fprintf('MTU already 9000 on %s.\n', intf);
    end

    % B. CPU Performance Mode — always apply (managed by cpu-performance.service at boot)
    % Prevents "O" overruns by keeping CPU out of power-save during 10GbE interrupts
    fprintf('Confirming CPU governor = performance...\n');
    rc = system('sudo -n cpupower frequency-set -g performance > /dev/null 2>&1');
    if rc ~= 0
        warning('CPU governor set failed (rc=%d). Check: systemctl status cpu-performance', rc);
    end

    % C. Kernel Network Buffers — always apply (managed by /etc/sysctl.d/99-usrp-n320.conf at boot)
    % 50MB socket buffer absorbs disk write stutters during high-rate capture
    fprintf('Confirming kernel socket buffers (rmem/wmem = 50MB)...\n');
    rc = system('sudo -n sysctl -w net.core.rmem_max=50000000 net.core.wmem_max=50000000 > /dev/null 2>&1');
    if rc ~= 0
        warning('sysctl buffer set failed (rc=%d). Check: /etc/sysctl.d/99-usrp-n320.conf', rc);
    end
end

fprintf('Starting Dual-Channel Capture Setup...\n')

% -------- Parameters --------
args = struct('radio',"", 'cf',599e6, 'sr',6.144e6, 'lo',0, ...
              'gain',[16, 16], ...
              'antennas', ["RF0:RX2", "RF1:RX2"], ...
              'roles', ["surveillance", "reference"], ...
              'operator_setup_notes', "", ...
              'dur',10, 'reps', 1, 'repspace', 1.0, 'file',"", ...
              'session_id', "");
          
for k = 1:2:numel(varargin)
    key = varargin{k};
    val = varargin{k+1};
    if isfield(args,key), args.(key) = val; else, error("Unknown argument '%s'.", key); end
end

dtg = string(datetime('now','Format','yyyy-MM-dd_HH-mm-ss.SSS'));
if strlength(string(args.session_id)) == 0
    session_id = string(datetime('now','Format','yyyyMMdd''T''HHmmss'));
else
    session_id = string(args.session_id);
end
written_files = strings(args.reps, 1);

fprintf('date time group (DTG) for this capture: %s\n', dtg);
fprintf('Session ID (use in analyzeBistaticData): %s\n', session_id);



% -------- Initialize Radio --------
if args.radio == ""
    cfgs = radioConfigurations;
    assert(~isempty(cfgs),"No saved radio configurations found.");
    args.radio = string(cfgs(1).Name);
end


% Create Receiver
bbrx = basebandReceiver(args.radio);
bbrx.CenterFrequency = args.cf + args.lo; % Apply LO offset
bbrx.SampleRate      = args.sr;
%bbrx.RadioGain       = args.gain;
% --- MODIFIED SECTION ---
% Allow for independent gains: [SurveillanceGain, ReferenceGain]
% If args.gain is a single number, apply it to both. 
% If it's a vector, apply respectively.
if numel(args.gain) == 2
    gain_db = reshape(double(args.gain), 1, []);
else
    gain_db = repmat(double(args.gain), 1, 2);
end
bbrx.RadioGain = gain_db;

% -------- Dual Antenna Selection --------
% Directly assign both N320 receive ports for coherent dual-channel capture.
% basebandReceiver defaults to a single antenna on construction, so Antennas
% must be SET here — reading it back before assignment always returns 1 antenna.
% N320 port naming convention: RF0:RX2 (channel 0) and RF1:RX2 (channel 1).
antenna_ports = reshape(string(args.antennas), 1, []);
channel_roles = lower(reshape(string(args.roles), 1, []));
if numel(antenna_ports) ~= 2 || any(strlength(antenna_ports) == 0)
    error('log_iq_n320_2antennas:invalidAntennaPorts', ...
        'antennas must name exactly two nonempty N320 receive ports.');
end
if numel(channel_roles) ~= 2 || ...
        ~isequal(sort(channel_roles), sort(["reference", "surveillance"]))
    error('log_iq_n320_2antennas:invalidChannelRoles', ...
        'roles must contain exactly one surveillance and one reference role.');
end

bbrx.Antennas = antenna_ports;
assert(numel(bbrx.Antennas) == 2, ...
    "Failed to configure dual antennas. Check radio connection and configuration.");
if ~isequal(string(bbrx.Antennas(:).'), antenna_ports)
    error('log_iq_n320_2antennas:antennaPortReadbackMismatch', ...
        'Requested ports %s do not match the receiver readback %s.', ...
        strjoin(antenna_ports, ", "), strjoin(string(bbrx.Antennas(:).'), ", "));
end

operator_setup_notes = helperResolveOperatorSetupNotes(args.operator_setup_notes);
channel_mapping = helperBuildChannelMapping( ...
    bbrx.Antennas, channel_roles, gain_db);
channel_mapping_json = string(jsonencode(channel_mapping));

fprintf('Selected Antennas: %s and %s\n', bbrx.Antennas(1), bbrx.Antennas(2));
fprintf('Channel Roles: CH1=%s and CH2=%s\n', channel_roles(1), channel_roles(2));

% -------- Estimate Size (Double for 2 channels) --------
bytesPerSample = 4 * 2; % 4 bytes per complex sample * 2 channels
estBytes = bbrx.SampleRate * args.dur * bytesPerSample;
fprintf('Planned: %.2f s @ %.3f MSps (2 Ch) → ~%.2f GB\n', ...
    args.dur, bbrx.SampleRate/1e6, estBytes/(1024^3));

% -------- File Writer --------
meta = struct('Label','Passive_Radar_Dual_Channel', ...
              'Antenna1',   bbrx.Antennas(1), ...
              'Antenna2',   bbrx.Antennas(2), ...
              'CaptureManifestVersion', 3, ...
              'OperatorSetupNotes', operator_setup_notes, ...
              'ChannelMappingJSON', channel_mapping_json, ...
              'StoredChannel1Index', 1, ...
              'N320Port1', bbrx.Antennas(1), ...
              'Channel1Role', channel_roles(1), ...
              'Channel1GainDB', gain_db(1), ...
              'StoredChannel2Index', 2, ...
              'N320Port2', bbrx.Antennas(2), ...
              'Channel2Role', channel_roles(2), ...
              'Channel2GainDB', gain_db(2), ...
              'GainDB',      gain_db, ...
              'LOOffset',   args.lo, ...
              'DateTime',   dtg, ...
              'SessionID',  session_id, ...
              'RecordingUTC', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
              'Duration_s', args.dur, ...
              'Repetition', 0); % Repetition will be updated in loop


% -------- Capture Loop --------
seg = seconds(1); 
nSeg = ceil(args.dur / seconds(seg));

for rr = 1:args.reps
    fprintf('--- Capture Round %d of %d ---\n', rr, args.reps);
    meta.DateTime = string(datetime('now','Format','yyyy-MM-dd_HH-mm-ss.SSS'));
    meta.RecordingUTC = posixtime(datetime('now', 'TimeZone', 'UTC'));
    meta.Repetition = rr;
    written_files(rr) = args.file + "_" + session_id + "_part" + string(rr);
    bbw = comm.BasebandFileWriter(written_files(rr), ...
            'SampleRate',      bbrx.SampleRate, ...
            'CenterFrequency', args.cf, ...
            'Metadata',        meta);

    for i = 1:nSeg
        if i == 1, fprintf('Collection Started...\n'); end
        
        % Capture returns [N x 2] complex matrix when 2 antennas are set
        data = capture(bbrx, seg); % , 'Background',true -> background is actually heavier unless running long capture
        %while isCapturing(bbrx) <- uncomment when background=true
        %     pause(0.3); 
        %end


        % Write dual-channel data directly to file
        bbw(data);
    end
    release(bbw);
    pause(args.repspace); % Short pause between repetitions
end

fprintf('Done: %s\n', args.file);
end
