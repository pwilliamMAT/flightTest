function [session_id, written_files] = log_iq_n320_2antennas(varargin)
% log_iq_n320_2antennas: Dual-channel IQ logger for Passive Radar.
% Captures phase-coherent data from RX1 (Surveillance) and RX2 (Reference).
%
% Example run:
% matlab -batch "log_iq_n320_2antennas('radio','My USRP N320','cf',540e6,'sr',6.144e6,'lo',200e3,'gain',30,'dur',10,'file','n320_dual_capture.bb')"
%% 1. Auto-Configure Network for N320 Jumbo Frames
if isunix
    intf = 'eno1'; %'enxa0cec8c28955'; <- if using USB Dongle
    % A. Jumbo Frames
    % Check current MTU
    [~, result] = system(['ifconfig ', intf]);
    if ~contains(result, 'mtu 9000')
        fprintf('Optimizing network for N320 (MTU 9000)...\n');
        % Note: This requires 'sudo' to be passwordless for this command
        % or run the MATLAB session with appropriate permissions.
        system(['sudo ip link set ', intf, ' mtu 9000']);
    % B. CPU Performance Mode (Prevent "O" Overruns)
    % This forces the CPU out of power-save mode to handle 10GbE interrupts instantly
    fprintf('Setting CPU governor to "performance"...\n');
    system('sudo cpupower frequency-set -g performance');

    % C. Kernel Network Buffers (The "Shock Absorber")
    % Increases the socket receive buffer to 49MB to survive disk write stutters
    fprintf('Increasing Linux network socket buffers (rmem)...\n');
    system('sudo sysctl -w net.core.rmem_max=50000000');
    system('sudo sysctl -w net.core.wmem_max=50000000');
    else
        fprintf('Network already optimized (MTU 9000).\n');
    end

end

fprintf('Starting Dual-Channel Capture Setup...\n')

% -------- Parameters --------
args = struct('radio',"", 'cf',599e6, 'sr',8e6, 'lo',200e3, 'gain',30, ...
              'dur',10, 'reps', 1, 'repspace', 1.0, 'file',"", ...
              'session_id', "");

for k = 1:2:numel(varargin)
    key = varargin{k};
    val = varargin{k+1};
    if isfield(args,key), args.(key) = val; else, error("Unknown argument '%s'.", key); end
end

assert(args.dur > 0, 'Duration ''dur'' must be positive.');

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
    bbrx.RadioGain = args.gain;
else
    bbrx.RadioGain = [args.gain, args.gain];
end

% -------- Dual Antenna Selection --------
% For N320, we typically want RX1 and RX2 simultaneously.
antList = hCaptureAntennas(args.radio);
if numel(antList) < 2
    error("Radio does not report enough antennas for dual-channel capture.");
end

% Explicitly set two antennas for coherent capture
% Usually: antList(1) is RX1, antList(2) is RX2
%bbrx.Antennas = {antList{1}, antList{2}};
bbrx.Antennas = string(antList(1:2));
fprintf('Selected Antennas: %s and %s\n', bbrx.Antennas{1}, bbrx.Antennas{2});

% -------- Estimate Size (Double for 2 channels) --------
bytesPerSample = 4 * 2; % 4 bytes per complex sample * 2 channels
estBytes = bbrx.SampleRate * args.dur * bytesPerSample;
fprintf('Planned: %.2f s @ %.3f MSps (2 Ch) → ~%.2f GB\n', ...
    args.dur, bbrx.SampleRate/1e6, estBytes/(1024^3));

% -------- File Writer --------
meta = struct('Label','Passive_Radar_Dual_Channel', ...
              'Antenna1', bbrx.Antennas{1}, ...
              'Antenna2', bbrx.Antennas{2}, ...
              'LOOffset', args.lo, ...
              'DateTime', dtg, ...
              'SessionID', session_id, ...
              'RecordingUTC', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
              'Repetition', 0); % Repetition will be updated in loop


% -------- Capture Loop --------
segment_durations_s = helperCaptureSegments(args.dur);

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

    for i = 1:numel(segment_durations_s)
        if i == 1, fprintf('Collection Started...\n'); end

        % Capture returns [N x 2] complex matrix when 2 antennas are set
        seg = seconds(segment_durations_s(i));
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
