function scan = runPlutoAzimuthEnvironmentalScan(varargin)
%RUNPLUTOAZIMUTHENVIRONMENTALSCAN Operator-guided RF environment azimuth scan.
%
% Plain-language concept:
%   This scan turns the directional antenna into a simple hand-rotated RF
%   survey instrument. At each requested bearing, the N320 records both the
%   directional and reference channels. During a short, known window inside
%   that capture, Pluto transmits the standard 11-tone comb. The ambient
%   capture tells us what the RF environment looks like versus azimuth; the
%   short comb burst gives a same-run calibration marker for the directional
%   antenna pattern while the reference channel should remain relatively
%   stable.
%
% Operator workflow:
%   1. Choose 4, 8, or 16 azimuth steps.
%   2. Point the directional antenna at the prompted true bearing.
%   3. Press Enter when the antenna is stable.
%   4. The function captures both N320 channels and injects one 0.2 s Pluto
%      multitone calibration burst during the capture.
%   5. Repeat clockwise until the full 360 degree scan is complete.
%
% Toolbox-first implementation:
%   The receive path uses basebandReceiver and comm.BasebandFileWriter,
%   matching the project's existing N320 capture stack. Spectrum estimates
%   use pwelch from Signal Processing Toolbox so the result is a standard
%   power spectral density view rather than a custom FFT display.
%
% Example:
%   scan = runPlutoAzimuthEnvironmentalScan('NumAzimuthSteps', 8, ...
%       'CaptureDuration_s', 10, 'PulseDuration_s', 0.2);
%
% See also: helperPlutoMultitoneBuildWaveform, helperPlutoToneStartTx,
% helperPlutoMultitoneScoreCapture, pwelch.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'NumAzimuthSteps', 8, @localMustBeSupportedStepCount);
addParameter(p, 'StartBearing_deg', 0, @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addParameter(p, 'Clockwise', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'CaptureDuration_s', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PulseStartDelay_s', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PulseDuration_s', 0.2, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'ToneOffsets_Hz', (-500:100:500) * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'TargetRMSAmplitude', 0.20, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'PeakLimit', 0.80, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'DirectionalChannel', "SURV", @(x) any(strcmpi(string(x), ["SURV", "REF"])));
addParameter(p, 'WelchNFFT', 8192, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'WelchFrameLength', 8192, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'StreamFrameSamples', 262144, @(x) isnumeric(x) && isscalar(x) && x >= 4096);
addParameter(p, 'CaptureSegment_s', 0.1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'AutoConfirm', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'DryRun', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

localValidateTiming(opts);

testRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testRoot);
analysisRoot = fullfile(projectRoot, 'BistaticDataAnalysis');
originalFolder = pwd;
originalPath = path;
cleanupFolder = onCleanup(@() cd(originalFolder));
cleanupPath = onCleanup(@() path(originalPath));

cd(testRoot);
addpath(analysisRoot, '-begin');

scanId = localResolveScanId(opts.SessionID);
scanRoot = localResolveOutputRoot(projectRoot, scanId, opts.OutputRoot);
captureRoot = localResolveCaptureRoot(scanRoot, opts.CaptureRoot);
if ~isfolder(scanRoot)
    mkdir(scanRoot);
end
if ~isfolder(captureRoot)
    mkdir(captureRoot);
end

[combWaveform, waveformInfo] = helperPlutoMultitoneBuildWaveform( ...
    opts.SampleRate_Hz, ...
    opts.ToneOffsets_Hz, ...
    opts.TargetRMSAmplitude, ...
    'PeakLimit', opts.PeakLimit, ...
    'Verbose', opts.Verbose);

scan = struct( ...
    'schema_version', 1, ...
    'scan_id', char(scanId), ...
    'created_utc', char(string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''))), ...
    'settings', localSettings(opts, scanRoot, captureRoot), ...
    'waveform_info', waveformInfo, ...
    'steps', [], ...
    'summary_table', table(), ...
    'analysis', struct(), ...
    'artifact_paths', struct());

bearingsDeg = localBuildBearings(opts.NumAzimuthSteps, opts.StartBearing_deg, opts.Clockwise);
stepResults = repmat(localEmptyStepResult(), opts.NumAzimuthSteps, 1);

if opts.Verbose
    fprintf('\n[runPlutoAzimuthEnvironmentalScan] Scan ID ......... %s\n', scanId);
    fprintf('[runPlutoAzimuthEnvironmentalScan] Steps ........... %d\n', opts.NumAzimuthSteps);
    fprintf('[runPlutoAzimuthEnvironmentalScan] Capture/root .... %s\n', captureRoot);
    fprintf('[runPlutoAzimuthEnvironmentalScan] Output/root ..... %s\n\n', scanRoot);
end

for stepIndex = 1:opts.NumAzimuthSteps
    bearingDeg = bearingsDeg(stepIndex);
    localPromptForBearing(stepIndex, opts.NumAzimuthSteps, bearingDeg, opts.AutoConfirm);

    stepSessionId = localStepSessionId(scanId, stepIndex, bearingDeg);
    captureFileBase = fullfile(captureRoot, char(stepSessionId));
    if opts.Verbose
        fprintf('[runPlutoAzimuthEnvironmentalScan] Step %02d/%02d | bearing %06.2f deg true\n', ...
            stepIndex, opts.NumAzimuthSteps, bearingDeg);
    end

    if opts.DryRun
        stepResults(stepIndex) = localRunDryStep(stepIndex, bearingDeg, stepSessionId, opts);
    else
        captureInfo = localCaptureN320WithPlutoPulse( ...
            'SessionID', stepSessionId, ...
            'CaptureFileBase', captureFileBase, ...
            'RadioName', opts.RadioName, ...
            'CenterFrequency_Hz', opts.CenterFrequency_Hz, ...
            'SampleRate_Hz', opts.SampleRate_Hz, ...
            'LOOffset_Hz', opts.LOOffset_Hz, ...
            'Gain', opts.Gain, ...
            'CaptureDuration_s', opts.CaptureDuration_s, ...
            'PulseStartDelay_s', opts.PulseStartDelay_s, ...
            'PulseDuration_s', opts.PulseDuration_s, ...
            'CombWaveform', combWaveform, ...
            'Bearing_deg', bearingDeg, ...
            'CaptureSegment_s', opts.CaptureSegment_s, ...
            'Verbose', opts.Verbose);

        stepResults(stepIndex) = localAnalyzeCapturedStep( ...
            stepIndex, ...
            bearingDeg, ...
            stepSessionId, ...
            captureInfo, ...
            opts);
    end

    if opts.Verbose
        localPrintStepSummary(stepResults(stepIndex), opts.DirectionalChannel);
    end
end

scan.steps = stepResults;
scan.summary_table = localBuildSummaryTable(stepResults);
scan.analysis = localBuildScanAnalysis(scan.summary_table, opts.DirectionalChannel);
scan = localWriteScanArtifacts(scan, scanRoot, opts);

if opts.Verbose
    localPrintScanSummary(scan);
end
end

function localMustBeSupportedStepCount(value)
if ~(isnumeric(value) && isscalar(value) && any(double(value) == [4 8 16]))
    error('runPlutoAzimuthEnvironmentalScan:unsupportedStepCount', ...
        'NumAzimuthSteps must be 4, 8, or 16.');
end
end

function localValidateTiming(opts)
if opts.PulseStartDelay_s + opts.PulseDuration_s > opts.CaptureDuration_s
    error('runPlutoAzimuthEnvironmentalScan:pulseOutsideCapture', ...
        'PulseStartDelay_s + PulseDuration_s must fit inside CaptureDuration_s.');
end
if opts.PulseDuration_s * opts.SampleRate_Hz < 2048
    error('runPlutoAzimuthEnvironmentalScan:pulseTooShort', ...
        'PulseDuration_s is too short for reliable tone scoring at this sample rate.');
end
end

function scanId = localResolveScanId(requestedId)
scanId = string(requestedId);
if strlength(scanId) == 0
    scanId = "pluto_azimuth_environment_" + string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd''T''HHmmss'));
end
end

function scanRoot = localResolveOutputRoot(projectRoot, scanId, requestedRoot)
scanRoot = string(requestedRoot);
if strlength(scanRoot) == 0
    scanRoot = fullfile(projectRoot, 'captures', 'plutoAzimuthEnvironmentScans', scanId);
end
end

function captureRoot = localResolveCaptureRoot(scanRoot, requestedRoot)
captureRoot = string(requestedRoot);
if strlength(captureRoot) == 0
    captureRoot = fullfile(scanRoot, 'captures');
end
end

function settings = localSettings(opts, scanRoot, captureRoot)
settings = struct( ...
    'num_azimuth_steps', double(opts.NumAzimuthSteps), ...
    'start_bearing_deg', double(opts.StartBearing_deg), ...
    'clockwise', logical(opts.Clockwise), ...
    'capture_duration_s', double(opts.CaptureDuration_s), ...
    'pulse_start_delay_s', double(opts.PulseStartDelay_s), ...
    'pulse_duration_s', double(opts.PulseDuration_s), ...
    'scan_root', char(string(scanRoot)), ...
    'capture_root', char(string(captureRoot)), ...
    'radio_name', char(string(opts.RadioName)), ...
    'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'lo_offset_hz', double(opts.LOOffset_Hz), ...
    'capture_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'gain', double(opts.Gain(:).'), ...
    'tone_offsets_hz', double(opts.ToneOffsets_Hz(:)), ...
    'target_rms_amplitude', double(opts.TargetRMSAmplitude), ...
    'peak_limit', double(opts.PeakLimit), ...
    'directional_channel', char(upper(string(opts.DirectionalChannel))), ...
    'welch_nfft', double(opts.WelchNFFT), ...
    'welch_frame_length', double(opts.WelchFrameLength), ...
    'stream_frame_samples', double(opts.StreamFrameSamples), ...
    'dry_run', logical(opts.DryRun));
end

function bearingsDeg = localBuildBearings(numSteps, startBearingDeg, clockwise)
stepDeg = 360 / double(numSteps);
directionSign = 1;
if ~clockwise
    directionSign = -1;
end
bearingsDeg = mod(double(startBearingDeg) + directionSign * (0:(numSteps - 1)) * stepDeg, 360);
bearingsDeg = bearingsDeg(:);
end

function localPromptForBearing(stepIndex, numSteps, bearingDeg, autoConfirm)
if autoConfirm
    fprintf('[operator prompt skipped] Step %d/%d: bearing %.1f deg true.\n', ...
        stepIndex, numSteps, bearingDeg);
    return
end

fprintf('\n============================================================\n');
fprintf('AZIMUTH STEP %d of %d\n', stepIndex, numSteps);
fprintf('Point the DIRECTIONAL antenna to %.1f degrees TRUE.\n', bearingDeg);
fprintf('Rotate clockwise to the next prompt after this capture completes.\n');
fprintf('============================================================\n');
reply = input('Press Enter when the antenna is stable, or type q then Enter to abort: ', 's');
if startsWith(lower(strtrim(reply)), 'q')
    error('runPlutoAzimuthEnvironmentalScan:operatorAbort', ...
        'Operator aborted before azimuth step %d.', stepIndex);
end
end

function stepSessionId = localStepSessionId(scanId, stepIndex, bearingDeg)
stepSessionId = string(scanId) + "_step" + compose("%02d", stepIndex) + ...
    "_az" + compose("%03.0f", round(mod(bearingDeg, 360)));
end

function step = localEmptyStepResult()
step = struct( ...
    'step_index', NaN, ...
    'bearing_deg', NaN, ...
    'session_id', "", ...
    'status', "PENDING", ...
    'capture_info', struct(), ...
    'capture_analysis_info', struct(), ...
    'environment_metrics', struct(), ...
    'calibration_metrics', struct(), ...
    'diagnostics', struct(), ...
    'reference_psd', struct(), ...
    'surveillance_psd', struct(), ...
    'directional_psd', struct(), ...
    'static_reference_psd', struct());
end

function captureInfo = localCaptureN320WithPlutoPulse(varargin)
p = inputParser;
p.FunctionName = 'localCaptureN320WithPlutoPulse';
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureFileBase', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'CaptureDuration_s', 10, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PulseStartDelay_s', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PulseDuration_s', 0.2, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CombWaveform', [], @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'Bearing_deg', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CaptureSegment_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

localPrepareLinuxCaptureHost(opts.Verbose);

captureFileBase = string(opts.CaptureFileBase);
if strlength(captureFileBase) == 0
    captureFileBase = string(opts.SessionID);
end
captureFile = captureFileBase + "_" + string(opts.SessionID) + "_part1";

radioName = string(opts.RadioName);
if strlength(radioName) == 0
    cfgs = radioConfigurations;
    assert(~isempty(cfgs), "No saved radio configurations found.");
    radioName = string(cfgs(1).Name);
end

bbrx = [];
writer = [];
txContext = struct();
try
    bbrx = basebandReceiver(radioName);
    bbrx.CenterFrequency = double(opts.CenterFrequency_Hz + opts.LOOffset_Hz);
    bbrx.SampleRate = double(opts.SampleRate_Hz);
    if numel(opts.Gain) == 2
        bbrx.RadioGain = double(opts.Gain(:).');
    else
        bbrx.RadioGain = [double(opts.Gain), double(opts.Gain)];
    end
    bbrx.Antennas = ["RF0:RX2", "RF1:RX2"];

    metadata = struct( ...
        'Label', 'Pluto_Azimuth_Environmental_Scan', ...
        'Antenna1', bbrx.Antennas(1), ...
        'Antenna2', bbrx.Antennas(2), ...
        'LOOffset', double(opts.LOOffset_Hz), ...
        'DateTime', string(datetime('now', 'Format', 'yyyy-MM-dd_HH-mm-ss.SSS')), ...
        'SessionID', string(opts.SessionID), ...
        'RecordingUTC', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
        'Duration_s', double(opts.CaptureDuration_s), ...
        'AzimuthBearing_deg', double(opts.Bearing_deg), ...
        'PulseStartDelay_s', double(opts.PulseStartDelay_s), ...
        'PulseDuration_s', double(opts.PulseDuration_s));

    capturePlan = localBuildCapturePlan( ...
        opts.CaptureDuration_s, ...
        opts.PulseStartDelay_s, ...
        opts.PulseDuration_s, ...
        opts.CaptureSegment_s, ...
        opts.Verbose);

    metadata.Duration_s = double(capturePlan.capture_duration_s);
    metadata.PulseStartDelay_s = double(capturePlan.pulse_start_delay_s);
    metadata.PulseDuration_s = double(capturePlan.pulse_duration_s);
    metadata.CaptureFrameDuration_s = double(capturePlan.frame_duration_s);

    writer = comm.BasebandFileWriter(char(captureFile), ...
        'SampleRate', bbrx.SampleRate, ...
        'CenterFrequency', double(opts.CenterFrequency_Hz), ...
        'Metadata', metadata);

    if opts.Verbose
        fprintf('[azimuth capture] File ........ %s\n', captureFile);
        fprintf('[azimuth capture] Duration .... %.3f s\n', capturePlan.capture_duration_s);
        fprintf('[azimuth capture] Frame ....... %.3f s fixed writer frame\n', ...
            capturePlan.frame_duration_s);
        fprintf('[azimuth capture] Pulse ....... %.3f s after %.3f s\n', ...
            capturePlan.pulse_duration_s, capturePlan.pulse_start_delay_s);
        fprintf('[azimuth capture] Antennas .... %s and %s\n', bbrx.Antennas(1), bbrx.Antennas(2));
    end

    localCaptureAndWriteFrames(bbrx, writer, capturePlan.pre_frames, capturePlan.frame_duration_s);

    txContext = helperPlutoToneStartTx( ...
        'CenterFrequencyHz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
        'SampleRateHz', double(opts.SampleRate_Hz), ...
        'Waveform', opts.CombWaveform, ...
        'Verbose', opts.Verbose);
    localCaptureAndWriteFrames(bbrx, writer, capturePlan.pulse_frames, capturePlan.frame_duration_s);
    localReleaseTransmitter(txContext);
    txContext = struct();

    localCaptureAndWriteFrames(bbrx, writer, capturePlan.post_frames, capturePlan.frame_duration_s);

    release(writer);
    writer = [];
    localReleaseReceiverIfSupported(bbrx);
catch me
    localReleaseTransmitter(txContext);
    if ~isempty(writer)
        try
            release(writer);
        catch
        end
    end
    localReleaseReceiverIfSupported(bbrx);
    rethrow(me)
end

captureInfo = struct( ...
    'session_id', string(opts.SessionID), ...
    'capture_duration_s', double(capturePlan.capture_duration_s), ...
    'capture_file_base', captureFileBase, ...
    'radio_name', radioName, ...
    'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'header_lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'header_sample_rate_hz', double(opts.SampleRate_Hz), ...
    'gain', double(opts.Gain(:).'), ...
    'recording_utc', metadata.RecordingUTC, ...
    'pulse_start_delay_s', double(capturePlan.pulse_start_delay_s), ...
    'pulse_duration_s', double(capturePlan.pulse_duration_s), ...
    'azimuth_bearing_deg', double(opts.Bearing_deg), ...
    'local_capture_files', string(captureFile));

fprintf('CAPTURE_SESSION_ID=%s\n', captureInfo.session_id);
fprintf('CAPTURE_FILE_1=%s\n', captureInfo.local_capture_files(1));
end

function localPrepareLinuxCaptureHost(verbose)
if ~isunix
    return
end

interfaceName = 'eno1';
[~, result] = system(['ip link show ', interfaceName]);
if ~contains(result, 'mtu 9000')
    if verbose
        fprintf('Setting MTU 9000 on %s...\n', interfaceName);
    end
    rc = system(['sudo -n ip link set ', interfaceName, ' mtu 9000']);
    if rc ~= 0
        warning('runPlutoAzimuthEnvironmentalScan:mtuSetFailed', ...
            'MTU set failed (rc=%d). Run: sudo ip link set %s mtu 9000', rc, interfaceName);
    end
elseif verbose
    fprintf('MTU already 9000 on %s.\n', interfaceName);
end

if verbose
    fprintf('Confirming CPU governor = performance...\n');
end
rc = system('sudo -n cpupower frequency-set -g performance > /dev/null 2>&1');
if rc ~= 0
    warning('runPlutoAzimuthEnvironmentalScan:cpuGovernorSetFailed', ...
        'CPU governor set failed (rc=%d). Check: systemctl status cpu-performance', rc);
end

if verbose
    fprintf('Confirming kernel socket buffers (rmem/wmem = 50MB)...\n');
end
rc = system('sudo -n sysctl -w net.core.rmem_max=50000000 net.core.wmem_max=50000000 > /dev/null 2>&1');
if rc ~= 0
    warning('runPlutoAzimuthEnvironmentalScan:socketBufferSetFailed', ...
        'sysctl buffer set failed (rc=%d). Check: /etc/sysctl.d/99-usrp-n320.conf', rc);
end
end

function capturePlan = localBuildCapturePlan(captureDuration_s, pulseStartDelay_s, ...
    pulseDuration_s, frameDuration_s, verbose)
% BasebandFileWriter locks the input frame size after the first write.  The
% azimuth scan therefore quantizes the pre-pulse, pulse, and post-pulse
% windows to an integer number of identical capture frames instead of
% writing one 0.5 s frame followed by one 0.2 s frame.
frameDuration_s = double(frameDuration_s);
preFrames = max(0, round(double(pulseStartDelay_s) / frameDuration_s));
pulseFrames = max(1, round(double(pulseDuration_s) / frameDuration_s));
requestedPostDuration_s = double(captureDuration_s) - double(pulseStartDelay_s) - double(pulseDuration_s);
postFrames = max(0, round(requestedPostDuration_s / frameDuration_s));

capturePlan = struct( ...
    'frame_duration_s', frameDuration_s, ...
    'pre_frames', double(preFrames), ...
    'pulse_frames', double(pulseFrames), ...
    'post_frames', double(postFrames), ...
    'pulse_start_delay_s', double(preFrames) * frameDuration_s, ...
    'pulse_duration_s', double(pulseFrames) * frameDuration_s, ...
    'capture_duration_s', double(preFrames + pulseFrames + postFrames) * frameDuration_s);

if verbose
    requested = [double(captureDuration_s), double(pulseStartDelay_s), double(pulseDuration_s)];
    actual = [capturePlan.capture_duration_s, capturePlan.pulse_start_delay_s, capturePlan.pulse_duration_s];
    if any(abs(requested - actual) > 1e-9)
        fprintf(['[azimuth capture] Quantized timing to fixed %.3f s frames: ', ...
            'capture %.3f->%.3f s, pulse start %.3f->%.3f s, pulse duration %.3f->%.3f s\n'], ...
            frameDuration_s, ...
            double(captureDuration_s), capturePlan.capture_duration_s, ...
            double(pulseStartDelay_s), capturePlan.pulse_start_delay_s, ...
            double(pulseDuration_s), capturePlan.pulse_duration_s);
    end
end
end

function localCaptureAndWriteFrames(receiver, writer, frameCount, frameDurationSeconds)
for frameIndex = 1:double(frameCount)
    data = capture(receiver, seconds(frameDurationSeconds));
    writer(data);
end
end

function localReleaseTransmitter(txContext)
if isstruct(txContext) && isfield(txContext, 'transmitter') && ~isempty(txContext.transmitter)
    try
        release(txContext.transmitter);
    catch
    end
end
end

function localReleaseReceiverIfSupported(receiver)
% basebandReceiver on the FTC is not a MATLAB System object and does not
% expose release(). Existing project capture helpers simply let the local
% receiver object go out of scope. Keep this cleanup guarded so it also
% works if a future receiver implementation does support release().
if isempty(receiver)
    return
end

try
    methodNames = methods(receiver);
    if any(strcmp(methodNames, 'release'))
        release(receiver);
    end
catch
    % Do not mask the capture or analysis error with a cleanup-only issue.
end
end

function step = localAnalyzeCapturedStep(stepIndex, bearingDeg, sessionId, captureInfo, opts)
captureFile = string(captureInfo.local_capture_files(1));
analysis = localAnalyzeCaptureFile(captureFile, opts);
step = localBuildStepResult(stepIndex, bearingDeg, sessionId, captureInfo, analysis, opts);
end

function step = localRunDryStep(stepIndex, bearingDeg, sessionId, opts)
[referenceSignal, surveillanceSignal, captureInfo] = localSyntheticStepSignals(stepIndex, bearingDeg, sessionId, opts);
analysis = localAnalyzeSignalVectors(referenceSignal, surveillanceSignal, captureInfo, opts);
step = localBuildStepResult(stepIndex, bearingDeg, sessionId, captureInfo, analysis, opts);
step.status = "DRYRUN";
end

function [referenceSignal, surveillanceSignal, captureInfo] = localSyntheticStepSignals(stepIndex, bearingDeg, sessionId, opts)
sampleRateHz = double(opts.SampleRate_Hz);
numSamples = max(4096, round(opts.CaptureDuration_s * sampleRateHz));
t = (0:(numSamples - 1)).' / sampleRateHz;
rng(1000 + stepIndex);

% DryRun uses a simple synthetic antenna pattern so the analysis products
% visibly demonstrate the intended behavior: the directional channel changes
% with pointing angle, while the reference channel remains mostly stable.
% This is not meant to model a specific antenna; it is only a deterministic
% verification signal for the report-generation path.
directionalGain = 0.15 + 0.85 * ((1 + cosd(bearingDeg)) / 2).^2;
referenceGain = 0.65;
noiseScale = 0.02;
toneOffsetsHz = double(opts.ToneOffsets_Hz(:));
comb = complex(zeros(numSamples, 1));
for idx = 1:numel(toneOffsetsHz)
    comb = comb + exp(1j * 2 * pi * toneOffsetsHz(idx) * t);
end
comb = comb ./ max(1, numel(toneOffsetsHz)) * opts.TargetRMSAmplitude;

pulseStart = max(1, floor(opts.PulseStartDelay_s * sampleRateHz) + 1);
pulseStop = min(numSamples, pulseStart + round(opts.PulseDuration_s * sampleRateHz) - 1);
envelope = zeros(numSamples, 1);
envelope(pulseStart:pulseStop) = 1;

interferer = 0.04 * exp(1j * 2 * pi * (-0.32e6) * t);
surveillanceSignal = directionalGain * (envelope .* comb + interferer) + ...
    noiseScale * (randn(numSamples, 1) + 1j * randn(numSamples, 1));
referenceSignal = referenceGain * (envelope .* comb + 0.6 * interferer) + ...
    noiseScale * (randn(numSamples, 1) + 1j * randn(numSamples, 1));

captureInfo = struct( ...
    'session_id', string(sessionId), ...
    'capture_duration_s', double(opts.CaptureDuration_s), ...
    'capture_file_base', string(sessionId), ...
    'radio_name', "DRYRUN", ...
    'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'sample_rate_hz', sampleRateHz, ...
    'lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'header_lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'header_sample_rate_hz', sampleRateHz, ...
    'gain', double(opts.Gain(:).'), ...
    'recording_utc', posixtime(datetime('now', 'TimeZone', 'UTC')), ...
    'pulse_start_delay_s', double(opts.PulseStartDelay_s), ...
    'pulse_duration_s', double(opts.PulseDuration_s), ...
    'azimuth_bearing_deg', double(bearingDeg), ...
    'local_capture_files', "");
end

function analysis = localAnalyzeCaptureFile(captureFile, opts)
reader = comm.BasebandFileReader(char(captureFile), ...
    'SamplesPerFrame', double(opts.StreamFrameSamples));
cleanupReader = onCleanup(@() release(reader));

sampleRateHz = double(reader.SampleRate);
metadata = reader.Metadata;
if isstruct(metadata) && isfield(metadata, 'PulseStartDelay_s')
    pulseStartDelay_s = double(metadata.PulseStartDelay_s);
else
    pulseStartDelay_s = double(opts.PulseStartDelay_s);
end
if isstruct(metadata) && isfield(metadata, 'PulseDuration_s')
    pulseDuration_s = double(metadata.PulseDuration_s);
else
    pulseDuration_s = double(opts.PulseDuration_s);
end

pulseStartSample = floor(pulseStartDelay_s * sampleRateHz) + 1;
pulseStopSample = pulseStartSample + round(pulseDuration_s * sampleRateHz) - 1;

referencePulse = complex(zeros(0, 1));
surveillancePulse = complex(zeros(0, 1));
refAccumulator = localPsdAccumulator();
survAccumulator = localPsdAccumulator();
sampleOffset = 0;

while ~isDone(reader)
    data = reader();
    if isempty(data)
        continue
    end
    if size(data, 2) < 2
        error('runPlutoAzimuthEnvironmentalScan:singleChannelCapture', ...
            'Expected a two-channel N320 .bb file, but %s has %d channel(s).', ...
            captureFile, size(data, 2));
    end

    frameSamples = size(data, 1);
    frameIndices = sampleOffset + (1:frameSamples).';
    pulseMask = frameIndices >= pulseStartSample & frameIndices <= pulseStopSample;
    ambientMask = ~pulseMask;

    if any(pulseMask)
        surveillancePulse = [surveillancePulse; double(data(pulseMask, 1))]; %#ok<AGROW>
        referencePulse = [referencePulse; double(data(pulseMask, 2))]; %#ok<AGROW>
    end
    if any(ambientMask)
        surveillanceAmbient = double(data(ambientMask, 1));
        referenceAmbient = double(data(ambientMask, 2));
        survAccumulator = localAccumulatePsd(survAccumulator, surveillanceAmbient, sampleRateHz, opts);
        refAccumulator = localAccumulatePsd(refAccumulator, referenceAmbient, sampleRateHz, opts);
    end
    sampleOffset = sampleOffset + frameSamples;
end
clear cleanupReader

captureInfo = struct( ...
    'capture_file_path', char(string(captureFile)), ...
    'reader_metadata', metadata, ...
    'sample_rate_hz', sampleRateHz, ...
    'samples_per_channel', double(sampleOffset), ...
    'pulse_start_sample', double(pulseStartSample), ...
    'pulse_stop_sample', double(pulseStopSample), ...
    'pulse_samples_collected', double(numel(referencePulse)));

analysis = localFinalizeStepAnalysis(referencePulse, surveillancePulse, ...
    refAccumulator, survAccumulator, captureInfo, opts);
end

function analysis = localAnalyzeSignalVectors(referenceSignal, surveillanceSignal, captureInfo, opts)
sampleRateHz = double(captureInfo.sample_rate_hz);
numSamples = min(numel(referenceSignal), numel(surveillanceSignal));
referenceSignal = double(referenceSignal(1:numSamples));
surveillanceSignal = double(surveillanceSignal(1:numSamples));

pulseStartSample = floor(opts.PulseStartDelay_s * sampleRateHz) + 1;
pulseStopSample = min(numSamples, pulseStartSample + round(opts.PulseDuration_s * sampleRateHz) - 1);
pulseMask = false(numSamples, 1);
pulseMask(pulseStartSample:pulseStopSample) = true;

referencePulse = referenceSignal(pulseMask);
surveillancePulse = surveillanceSignal(pulseMask);
refAccumulator = localPsdAccumulator();
survAccumulator = localPsdAccumulator();
refAccumulator = localAccumulatePsd(refAccumulator, referenceSignal(~pulseMask), sampleRateHz, opts);
survAccumulator = localAccumulatePsd(survAccumulator, surveillanceSignal(~pulseMask), sampleRateHz, opts);

captureInfo.capture_file_path = "";
captureInfo.samples_per_channel = double(numSamples);
captureInfo.pulse_start_sample = double(pulseStartSample);
captureInfo.pulse_stop_sample = double(pulseStopSample);
captureInfo.pulse_samples_collected = double(numel(referencePulse));

analysis = localFinalizeStepAnalysis(referencePulse, surveillancePulse, ...
    refAccumulator, survAccumulator, captureInfo, opts);
end

function accumulator = localPsdAccumulator()
accumulator = struct( ...
    'count', 0, ...
    'frequency_hz', [], ...
    'psd_sum', [], ...
    'power_sum', 0, ...
    'sample_count', 0);
end

function accumulator = localAccumulatePsd(accumulator, signal, sampleRateHz, opts)
signal = double(signal(:));
if isempty(signal)
    return
end

accumulator.power_sum = accumulator.power_sum + sum(abs(signal).^2);
accumulator.sample_count = accumulator.sample_count + numel(signal);

frameLength = min(double(opts.WelchFrameLength), numel(signal));
if frameLength < 128
    return
end
window = hamming(frameLength, 'periodic');
overlap = floor(0.5 * frameLength);
nfft = max(double(opts.WelchNFFT), frameLength);
[psdEstimate, frequencyHz] = pwelch(signal, window, overlap, nfft, sampleRateHz, 'centered', 'psd');

if accumulator.count == 0
    accumulator.frequency_hz = frequencyHz(:);
    accumulator.psd_sum = zeros(size(psdEstimate(:)));
end
accumulator.psd_sum = accumulator.psd_sum + psdEstimate(:);
accumulator.count = accumulator.count + 1;
end

function analysis = localFinalizeStepAnalysis(referencePulse, surveillancePulse, ...
    refAccumulator, survAccumulator, captureInfo, opts)
refPsd = localFinalizePsd(refAccumulator);
survPsd = localFinalizePsd(survAccumulator);

if isempty(referencePulse) || isempty(surveillancePulse)
    calibrationMetrics = localEmptyCalibrationMetrics();
    diagnostics = struct('calibration_error', 'No pulse samples were collected.');
else
    [calibrationMetrics, diagnostics] = helperPlutoMultitoneScoreCapture( ...
        referencePulse, ...
        surveillancePulse, ...
        double(captureInfo.sample_rate_hz), ...
        double(opts.ToneOffsets_Hz(:)), ...
        'ScoringMode', "expected-bin", ...
        'Verbose', false);
end

environmentMetrics = localEnvironmentMetrics(refPsd, survPsd, ...
    refAccumulator, survAccumulator, opts.DirectionalChannel);

analysis = struct( ...
    'capture_info', captureInfo, ...
    'reference_psd', refPsd, ...
    'surveillance_psd', survPsd, ...
    'environment_metrics', environmentMetrics, ...
    'calibration_metrics', calibrationMetrics, ...
    'diagnostics', diagnostics);
end

function psd = localFinalizePsd(accumulator)
if accumulator.count == 0
    psd = struct( ...
        'frequency_hz', zeros(0, 1), ...
        'psd_linear', zeros(0, 1), ...
        'psd_db_per_hz', zeros(0, 1), ...
        'ambient_power_db', NaN, ...
        'ambient_sample_count', double(accumulator.sample_count));
    return
end

psdLinear = accumulator.psd_sum ./ accumulator.count;
psd = struct( ...
    'frequency_hz', accumulator.frequency_hz(:), ...
    'psd_linear', psdLinear(:), ...
    'psd_db_per_hz', 10 * log10(psdLinear(:) + eps), ...
    'ambient_power_db', 10 * log10(accumulator.power_sum / max(1, accumulator.sample_count) + eps), ...
    'ambient_sample_count', double(accumulator.sample_count));
end

function metrics = localEnvironmentMetrics(refPsd, survPsd, refAccumulator, survAccumulator, directionalChannel)
if strcmpi(string(directionalChannel), "SURV")
    directionalPsd = survPsd;
    referencePsd = refPsd;
    directionalPowerDb = survPsd.ambient_power_db;
    referencePowerDb = refPsd.ambient_power_db;
else
    directionalPsd = refPsd;
    referencePsd = survPsd;
    directionalPowerDb = refPsd.ambient_power_db;
    referencePowerDb = survPsd.ambient_power_db;
end

[directionalPeakDb, directionalPeakIdx] = max(directionalPsd.psd_db_per_hz);
[referencePeakDb, referencePeakIdx] = max(referencePsd.psd_db_per_hz);
directionalPeakHz = localIndexValue(directionalPsd.frequency_hz, directionalPeakIdx);
referencePeakHz = localIndexValue(referencePsd.frequency_hz, referencePeakIdx);

metrics = struct( ...
    'directional_channel', char(upper(string(directionalChannel))), ...
    'directional_ambient_power_db', directionalPowerDb, ...
    'reference_ambient_power_db', referencePowerDb, ...
    'directional_minus_reference_power_db', directionalPowerDb - referencePowerDb, ...
    'directional_median_psd_db_per_hz', median(directionalPsd.psd_db_per_hz, 'omitnan'), ...
    'reference_median_psd_db_per_hz', median(referencePsd.psd_db_per_hz, 'omitnan'), ...
    'directional_peak_psd_db_per_hz', directionalPeakDb, ...
    'directional_peak_frequency_hz', directionalPeakHz, ...
    'reference_peak_psd_db_per_hz', referencePeakDb, ...
    'reference_peak_frequency_hz', referencePeakHz, ...
    'directional_ambient_sample_count', double(localDirectionalCount(refAccumulator, survAccumulator, directionalChannel)), ...
    'reference_ambient_sample_count', double(localReferenceCount(refAccumulator, survAccumulator, directionalChannel)));
end

function value = localIndexValue(values, idx)
value = NaN;
if ~isempty(values) && isfinite(idx) && idx >= 1 && idx <= numel(values)
    value = values(idx);
end
end

function count = localDirectionalCount(refAccumulator, survAccumulator, directionalChannel)
if strcmpi(string(directionalChannel), "SURV")
    count = survAccumulator.sample_count;
else
    count = refAccumulator.sample_count;
end
end

function count = localReferenceCount(refAccumulator, survAccumulator, directionalChannel)
if strcmpi(string(directionalChannel), "SURV")
    count = refAccumulator.sample_count;
else
    count = survAccumulator.sample_count;
end
end

function calibrationMetrics = localEmptyCalibrationMetrics()
emptyChannel = struct( ...
    'integrated_detect_margin_db', NaN, ...
    'median_detect_margin_db', NaN, ...
    'num_tones_found', 0, ...
    'num_tones_expected', 0);
calibrationMetrics = struct( ...
    'status', 'ERROR', ...
    'scoring_mode', 'expected-bin', ...
    'reference', emptyChannel, ...
    'surveillance', emptyChannel, ...
    'joint', struct('median_channel_frequency_delta_hz', NaN), ...
    'xcorr_advisory', struct('peak_db', NaN, 'lag_samples', NaN));
end

function step = localBuildStepResult(stepIndex, bearingDeg, sessionId, captureInfo, analysis, opts)
step = localEmptyStepResult();
step.step_index = double(stepIndex);
step.bearing_deg = double(bearingDeg);
step.session_id = string(sessionId);
step.status = string(analysis.calibration_metrics.status);
step.capture_info = captureInfo;
step.capture_analysis_info = analysis.capture_info;
step.environment_metrics = analysis.environment_metrics;
step.calibration_metrics = analysis.calibration_metrics;
step.diagnostics = analysis.diagnostics;
step.reference_psd = analysis.reference_psd;
step.surveillance_psd = analysis.surveillance_psd;
step.directional_psd = localSelectChannelPsd(analysis, opts.DirectionalChannel, true);
step.static_reference_psd = localSelectChannelPsd(analysis, opts.DirectionalChannel, false);
end

function psd = localSelectChannelPsd(analysis, directionalChannel, wantDirectional)
directionalIsSurv = strcmpi(string(directionalChannel), "SURV");
if xor(directionalIsSurv, ~wantDirectional)
    psd = analysis.surveillance_psd;
else
    psd = analysis.reference_psd;
end
end

function localPrintStepSummary(step, directionalChannel)
env = step.environment_metrics;
cal = step.calibration_metrics;
dirCal = localCalibrationIntegratedMargin(cal, directionalChannel, true);
refCal = localCalibrationIntegratedMargin(cal, directionalChannel, false);
fprintf(['[azimuth step] Bearing %6.1f deg | ambient dir-ref %+6.2f dB | ', ...
    'cal dir %.2f dB ref %.2f dB | status %s\n'], ...
    step.bearing_deg, ...
    env.directional_minus_reference_power_db, ...
    dirCal, ...
    refCal, ...
    string(step.status));
end

function value = localCalibrationIntegratedMargin(calibrationMetrics, directionalChannel, wantDirectional)
if strcmpi(string(directionalChannel), "SURV")
    if wantDirectional
        value = calibrationMetrics.surveillance.integrated_detect_margin_db;
    else
        value = calibrationMetrics.reference.integrated_detect_margin_db;
    end
else
    if wantDirectional
        value = calibrationMetrics.reference.integrated_detect_margin_db;
    else
        value = calibrationMetrics.surveillance.integrated_detect_margin_db;
    end
end
end

function summaryTable = localBuildSummaryTable(steps)
numSteps = numel(steps);
summaryTable = table( ...
    zeros(numSteps, 1), ...
    zeros(numSteps, 1), ...
    strings(numSteps, 1), ...
    strings(numSteps, 1), ...
    strings(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    nan(numSteps, 1), ...
    'VariableNames', { ...
        'StepIndex', ...
        'Bearing_deg', ...
        'SessionID', ...
        'Status', ...
        'CaptureFile', ...
        'DirectionalAmbientPower_dB', ...
        'ReferenceAmbientPower_dB', ...
        'DirectionalMinusReferencePower_dB', ...
        'DirectionalMedianPSD_dBPerHz', ...
        'ReferenceMedianPSD_dBPerHz', ...
        'DirectionalPeakPSD_dBPerHz', ...
        'DirectionalPeakFrequency_Hz', ...
        'ReferencePeakPSD_dBPerHz', ...
        'ReferencePeakFrequency_Hz', ...
        'DirectionalCalibrationIntegratedMargin_dB', ...
        'ReferenceCalibrationIntegratedMargin_dB'});

for idx = 1:numSteps
    env = steps(idx).environment_metrics;
    cal = steps(idx).calibration_metrics;
    directionalChannel = env.directional_channel;
    captureFile = "";
    if isfield(steps(idx).capture_info, 'local_capture_files') && ~isempty(steps(idx).capture_info.local_capture_files)
        captureFile = string(steps(idx).capture_info.local_capture_files(1));
    end
    summaryTable.StepIndex(idx) = steps(idx).step_index;
    summaryTable.Bearing_deg(idx) = steps(idx).bearing_deg;
    summaryTable.SessionID(idx) = string(steps(idx).session_id);
    summaryTable.Status(idx) = string(steps(idx).status);
    summaryTable.CaptureFile(idx) = captureFile;
    summaryTable.DirectionalAmbientPower_dB(idx) = env.directional_ambient_power_db;
    summaryTable.ReferenceAmbientPower_dB(idx) = env.reference_ambient_power_db;
    summaryTable.DirectionalMinusReferencePower_dB(idx) = env.directional_minus_reference_power_db;
    summaryTable.DirectionalMedianPSD_dBPerHz(idx) = env.directional_median_psd_db_per_hz;
    summaryTable.ReferenceMedianPSD_dBPerHz(idx) = env.reference_median_psd_db_per_hz;
    summaryTable.DirectionalPeakPSD_dBPerHz(idx) = env.directional_peak_psd_db_per_hz;
    summaryTable.DirectionalPeakFrequency_Hz(idx) = env.directional_peak_frequency_hz;
    summaryTable.ReferencePeakPSD_dBPerHz(idx) = env.reference_peak_psd_db_per_hz;
    summaryTable.ReferencePeakFrequency_Hz(idx) = env.reference_peak_frequency_hz;
    summaryTable.DirectionalCalibrationIntegratedMargin_dB(idx) = ...
        localCalibrationIntegratedMargin(cal, directionalChannel, true);
    summaryTable.ReferenceCalibrationIntegratedMargin_dB(idx) = ...
        localCalibrationIntegratedMargin(cal, directionalChannel, false);
end
end

function analysis = localBuildScanAnalysis(summaryTable, directionalChannel)
analysis = struct( ...
    'directional_channel', char(upper(string(directionalChannel))), ...
    'num_steps', height(summaryTable), ...
    'directional_ambient_power_span_db', localRange(summaryTable.DirectionalAmbientPower_dB), ...
    'reference_ambient_power_span_db', localRange(summaryTable.ReferenceAmbientPower_dB), ...
    'directional_calibration_span_db', localRange(summaryTable.DirectionalCalibrationIntegratedMargin_dB), ...
    'reference_calibration_span_db', localRange(summaryTable.ReferenceCalibrationIntegratedMargin_dB), ...
    'strongest_ambient_bearing_deg', localBearingAtMax(summaryTable, 'DirectionalAmbientPower_dB'), ...
    'strongest_calibration_bearing_deg', localBearingAtMax(summaryTable, 'DirectionalCalibrationIntegratedMargin_dB'));
end

function value = localRange(values)
value = max(values, [], 'omitnan') - min(values, [], 'omitnan');
end

function bearing = localBearingAtMax(summaryTable, variableName)
bearing = NaN;
values = summaryTable.(variableName);
if all(isnan(values))
    return
end
[~, idx] = max(values, [], 'omitnan');
bearing = summaryTable.Bearing_deg(idx);
end

function toneTable = localBuildCalibrationToneTable(steps)
rows = cell(numel(steps), 1);
for stepIdx = 1:numel(steps)
    rows{stepIdx} = localBuildStepToneTable(steps(stepIdx));
end

if isempty(rows)
    toneTable = table();
else
    toneTable = vertcat(rows{:});
end
end

function toneTable = localBuildStepToneTable(step)
metrics = step.calibration_metrics;
directionalChannel = string(step.environment_metrics.directional_channel);
[directionalMetrics, referenceMetrics] = localDirectionalAndReferenceMetrics(metrics, directionalChannel);

toneOffsetsHz = double(metrics.tone_offsets_hz(:));
numTones = numel(toneOffsetsHz);
toneTable = table( ...
    repmat(double(step.step_index), numTones, 1), ...
    repmat(double(step.bearing_deg), numTones, 1), ...
    repmat(string(step.session_id), numTones, 1), ...
    toneOffsetsHz, ...
    toneOffsetsHz / 1e3, ...
    localColumn(referenceMetrics.detect_margin_db, numTones), ...
    localColumn(directionalMetrics.detect_margin_db, numTones), ...
    localColumn(directionalMetrics.detect_margin_db, numTones) - localColumn(referenceMetrics.detect_margin_db, numTones), ...
    localColumn(referenceMetrics.tone_peak_dbfs, numTones), ...
    localColumn(directionalMetrics.tone_peak_dbfs, numTones), ...
    localColumn(referenceMetrics.local_floor_dbfs, numTones), ...
    localColumn(directionalMetrics.local_floor_dbfs, numTones), ...
    localColumn(referenceMetrics.tone_found, numTones), ...
    localColumn(directionalMetrics.tone_found, numTones), ...
    localColumn(metrics.joint.channel_frequency_delta_hz, numTones), ...
    'VariableNames', { ...
        'StepIndex', ...
        'Bearing_deg', ...
        'SessionID', ...
        'ToneOffset_Hz', ...
        'ToneOffset_kHz', ...
        'ReferenceDetectMargin_dB', ...
        'DirectionalDetectMargin_dB', ...
        'DirectionalMinusReferenceMargin_dB', ...
        'ReferenceTonePeak_dBFS', ...
        'DirectionalTonePeak_dBFS', ...
        'ReferenceLocalFloor_dBFS', ...
        'DirectionalLocalFloor_dBFS', ...
        'ReferenceToneFound', ...
        'DirectionalToneFound', ...
        'ChannelFrequencyDelta_Hz'});
end

function [directionalMetrics, referenceMetrics] = localDirectionalAndReferenceMetrics(metrics, directionalChannel)
if strcmpi(directionalChannel, "SURV")
    directionalMetrics = metrics.surveillance;
    referenceMetrics = metrics.reference;
else
    directionalMetrics = metrics.reference;
    referenceMetrics = metrics.surveillance;
end
end

function values = localColumn(valuesIn, numRows)
if isempty(valuesIn)
    values = nan(numRows, 1);
    return
end

values = valuesIn(:);
if islogical(values)
    values = logical(values);
elseif isnumeric(values)
    values = double(values);
end

if numel(values) < numRows
    if islogical(values)
        values(end + 1:numRows, 1) = false;
    else
        values(end + 1:numRows, 1) = NaN;
    end
elseif numel(values) > numRows
    values = values(1:numRows);
end
end

function scan = localWriteScanArtifacts(scan, scanRoot, opts)
scan.calibration_tone_table = localBuildCalibrationToneTable(scan.steps);
artifactPaths = struct( ...
    'scan_folder', string(scanRoot), ...
    'result_mat', string(fullfile(scanRoot, 'scan_result.mat')), ...
    'summary_csv', string(fullfile(scanRoot, 'azimuth_summary.csv')), ...
    'calibration_tone_csv', string(fullfile(scanRoot, 'calibration_tone_summary.csv')), ...
    'summary_txt', string(fullfile(scanRoot, 'summary.txt')), ...
    'html', string(fullfile(scanRoot, 'index.html')), ...
    'environment_power_png', string(fullfile(scanRoot, 'environment_power_polar.png')), ...
    'calibration_pattern_png', string(fullfile(scanRoot, 'calibration_pattern_polar.png')), ...
    'calibration_tone_heatmap_png', string(fullfile(scanRoot, 'calibration_tone_margin_heatmap.png')), ...
    'calibration_tone_by_frequency_png', string(fullfile(scanRoot, 'calibration_tone_margin_by_frequency.png')), ...
    'directional_psd_heatmap_png', string(fullfile(scanRoot, 'directional_psd_heatmap.png')), ...
    'reference_psd_heatmap_png', string(fullfile(scanRoot, 'reference_psd_heatmap.png')), ...
    'channel_ratio_png', string(fullfile(scanRoot, 'channel_ratio_and_metrics.png')));

scan.artifact_paths = artifactPaths;
save(artifactPaths.result_mat, 'scan');
writetable(scan.summary_table, artifactPaths.summary_csv);
writetable(scan.calibration_tone_table, artifactPaths.calibration_tone_csv);
localWriteText(artifactPaths.summary_txt, localSummaryText(scan));

if opts.PlotFigures
    localWritePlots(scan, opts);
end
localWriteHtml(scan);
end

function localWritePlots(scan, opts)
fig = localPlotEnvironmentPower(scan, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.environment_power_png);

fig = localPlotCalibrationPattern(scan, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.calibration_pattern_png);

fig = localPlotCalibrationToneHeatmap(scan, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.calibration_tone_heatmap_png);

fig = localPlotCalibrationToneByFrequency(scan, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.calibration_tone_by_frequency_png);

fig = localPlotPsdHeatmap(scan, true, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.directional_psd_heatmap_png);

fig = localPlotPsdHeatmap(scan, false, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.reference_psd_heatmap_png);

fig = localPlotChannelRatios(scan, opts.FigureVisibility);
localExportFigure(fig, scan.artifact_paths.channel_ratio_png);
end

function fig = localPlotEnvironmentPower(scan, figureVisibility)
tbl = scan.summary_table;
theta = deg2rad([tbl.Bearing_deg; tbl.Bearing_deg(1)]);
dirPower = [tbl.DirectionalAmbientPower_dB; tbl.DirectionalAmbientPower_dB(1)];
refPower = [tbl.ReferenceAmbientPower_dB; tbl.ReferenceAmbientPower_dB(1)];

fig = figure('Name', 'Azimuth ambient RF power', 'Color', 'w', 'Visible', figureVisibility);
polarplot(theta, dirPower, '-o', 'LineWidth', 1.3);
hold on;
polarplot(theta, refPower, '-o', 'LineWidth', 1.3);
title('Ambient RF power versus azimuth');
legend({'Directional', 'Reference'}, 'Location', 'bestoutside');
end

function fig = localPlotCalibrationPattern(scan, figureVisibility)
tbl = scan.summary_table;
theta = deg2rad([tbl.Bearing_deg; tbl.Bearing_deg(1)]);
dirCal = [tbl.DirectionalCalibrationIntegratedMargin_dB; tbl.DirectionalCalibrationIntegratedMargin_dB(1)];
refCal = [tbl.ReferenceCalibrationIntegratedMargin_dB; tbl.ReferenceCalibrationIntegratedMargin_dB(1)];

fig = figure('Name', 'Azimuth calibration comb pattern', 'Color', 'w', 'Visible', figureVisibility);
polarplot(theta, dirCal, '-o', 'LineWidth', 1.3);
hold on;
polarplot(theta, refCal, '-o', 'LineWidth', 1.3);
title('Pluto 11-tone calibration response versus azimuth');
legend({'Directional', 'Reference'}, 'Location', 'bestoutside');
end

function fig = localPlotCalibrationToneHeatmap(scan, figureVisibility)
toneTable = scan.calibration_tone_table;
[dirMatrix, refMatrix, toneOffsetsKHz, bearingsDeg] = localCalibrationToneMatrices(toneTable);

fig = figure('Name', 'Per-tone calibration margin heatmap', 'Color', 'w', 'Visible', figureVisibility);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto comb calibration margin by tone and azimuth');

nexttile(tl, 1);
imagesc(toneOffsetsKHz, bearingsDeg, dirMatrix);
axis xy;
grid on;
colorbar;
ylabel('Bearing (deg true)');
title('Directional channel detect margin (dB)');

nexttile(tl, 2);
imagesc(toneOffsetsKHz, bearingsDeg, refMatrix);
axis xy;
grid on;
colorbar;
ylabel('Bearing (deg true)');
title('Reference channel detect margin (dB)');

nexttile(tl, 3);
imagesc(toneOffsetsKHz, bearingsDeg, dirMatrix - refMatrix);
axis xy;
grid on;
colorbar;
xlabel('Tone offset (kHz)');
ylabel('Bearing (deg true)');
title('Directional - reference margin (dB)');
end

function fig = localPlotCalibrationToneByFrequency(scan, figureVisibility)
toneTable = scan.calibration_tone_table;
[dirMatrix, refMatrix, toneOffsetsKHz, bearingsDeg] = localCalibrationToneMatrices(toneTable);

fig = figure('Name', 'Per-tone calibration margin by frequency', 'Color', 'w', 'Visible', figureVisibility);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto comb calibration shape across the 11 tones');

nexttile(tl, 1);
plot(toneOffsetsKHz, dirMatrix.', '-o', 'LineWidth', 1.1);
grid on;
xlabel('Tone offset (kHz)');
ylabel('Directional detect margin (dB)');
title('Directional channel comb shape');
legend(compose('%.0f deg', bearingsDeg), 'Location', 'bestoutside');

nexttile(tl, 2);
plot(toneOffsetsKHz, (dirMatrix - refMatrix).', '-o', 'LineWidth', 1.1);
grid on;
xlabel('Tone offset (kHz)');
ylabel('Directional - reference margin (dB)');
title('Baseline-normalized comb shape');
legend(compose('%.0f deg', bearingsDeg), 'Location', 'bestoutside');
end

function [dirMatrix, refMatrix, toneOffsetsKHz, bearingsDeg] = localCalibrationToneMatrices(toneTable)
if isempty(toneTable)
    dirMatrix = zeros(0, 0);
    refMatrix = zeros(0, 0);
    toneOffsetsKHz = zeros(0, 1);
    bearingsDeg = zeros(0, 1);
    return
end

bearingsDeg = unique(toneTable.Bearing_deg, 'stable');
toneOffsetsKHz = unique(toneTable.ToneOffset_kHz, 'stable');
dirMatrix = nan(numel(bearingsDeg), numel(toneOffsetsKHz));
refMatrix = nan(numel(bearingsDeg), numel(toneOffsetsKHz));

for bearingIdx = 1:numel(bearingsDeg)
    for toneIdx = 1:numel(toneOffsetsKHz)
        rowMask = toneTable.Bearing_deg == bearingsDeg(bearingIdx) & ...
            toneTable.ToneOffset_kHz == toneOffsetsKHz(toneIdx);
        if any(rowMask)
            firstRow = find(rowMask, 1, 'first');
            dirMatrix(bearingIdx, toneIdx) = toneTable.DirectionalDetectMargin_dB(firstRow);
            refMatrix(bearingIdx, toneIdx) = toneTable.ReferenceDetectMargin_dB(firstRow);
        end
    end
end
end

function fig = localPlotPsdHeatmap(scan, wantDirectional, figureVisibility)
[psdMatrix, frequencyHz, bearingsDeg] = localPsdMatrix(scan.steps, wantDirectional);
if wantDirectional
    titleText = 'Directional-channel ambient PSD by azimuth';
    figName = 'Directional ambient PSD heatmap';
else
    titleText = 'Reference-channel ambient PSD by azimuth';
    figName = 'Reference ambient PSD heatmap';
end

fig = figure('Name', figName, 'Color', 'w', 'Visible', figureVisibility);
imagesc(frequencyHz / 1e6, bearingsDeg, psdMatrix);
axis xy;
grid on;
colorbar;
xlabel('Baseband frequency offset (MHz)');
ylabel('Bearing (deg true)');
title(titleText);
end

function fig = localPlotChannelRatios(scan, figureVisibility)
tbl = scan.summary_table;
fig = figure('Name', 'Azimuth scan channel ratios', 'Color', 'w', 'Visible', figureVisibility);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Azimuth scan summary metrics');

nexttile(tl, 1);
plot(tbl.Bearing_deg, tbl.DirectionalMinusReferencePower_dB, '-o', 'LineWidth', 1.2);
grid on;
xlabel('Bearing (deg true)');
ylabel('Directional - reference ambient power (dB)');
title('Ambient channel ratio');

nexttile(tl, 2);
plot(tbl.Bearing_deg, tbl.DirectionalCalibrationIntegratedMargin_dB - ...
    tbl.ReferenceCalibrationIntegratedMargin_dB, '-o', 'LineWidth', 1.2);
grid on;
xlabel('Bearing (deg true)');
ylabel('Directional - reference comb margin (dB)');
title('Calibration comb channel ratio');
end

function [psdMatrix, frequencyHz, bearingsDeg] = localPsdMatrix(steps, wantDirectional)
frequencyHz = [];
for idx = 1:numel(steps)
    if wantDirectional
        psd = steps(idx).directional_psd;
    else
        psd = steps(idx).static_reference_psd;
    end
    if ~isempty(psd.frequency_hz)
        frequencyHz = psd.frequency_hz(:);
        break
    end
end

if isempty(frequencyHz)
    psdMatrix = zeros(numel(steps), 0);
    bearingsDeg = [steps.bearing_deg].';
    return
end

psdMatrix = nan(numel(steps), numel(frequencyHz));
bearingsDeg = nan(numel(steps), 1);
for idx = 1:numel(steps)
    if wantDirectional
        psd = steps(idx).directional_psd;
    else
        psd = steps(idx).static_reference_psd;
    end
    bearingsDeg(idx) = steps(idx).bearing_deg;
    if numel(psd.psd_db_per_hz) == numel(frequencyHz)
        psdMatrix(idx, :) = psd.psd_db_per_hz(:).';
    end
end
end

function localExportFigure(fig, outputPath)
try
    exportgraphics(fig, outputPath, 'Resolution', 150);
catch
    saveas(fig, outputPath);
end
if ishghandle(fig)
    close(fig);
end
end

function textLines = localSummaryText(scan)
analysis = scan.analysis;
textLines = [
    "PLUTO AZIMUTH ENVIRONMENTAL SCAN"
    "Scan ID: " + string(scan.scan_id)
    "Created UTC: " + string(scan.created_utc)
    "Steps: " + string(analysis.num_steps)
    "Directional channel: " + string(analysis.directional_channel)
    "Ambient directional span: " + compose("%.2f", analysis.directional_ambient_power_span_db) + " dB"
    "Ambient reference span: " + compose("%.2f", analysis.reference_ambient_power_span_db) + " dB"
    "Calibration directional span: " + compose("%.2f", analysis.directional_calibration_span_db) + " dB"
    "Calibration reference span: " + compose("%.2f", analysis.reference_calibration_span_db) + " dB"
    "Strongest ambient bearing: " + compose("%.1f", analysis.strongest_ambient_bearing_deg) + " deg true"
    "Strongest calibration bearing: " + compose("%.1f", analysis.strongest_calibration_bearing_deg) + " deg true"
    ""
    "Interpretation:"
    "The ambient plots estimate the RF environment with the Pluto pulse window removed."
    "The calibration plots score only the brief Pluto 11-tone burst."
    "A useful scan should show more azimuth variation on the directional channel than on the reference channel."
    ];
end

function localWriteText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('runPlutoAzimuthEnvironmentalScan:textOpenFailed', ...
        'Could not open %s for writing.', path);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', lines);
clear cleanupFile
end

function localWriteHtml(scan)
htmlPath = scan.artifact_paths.html;
fid = fopen(htmlPath, 'w');
if fid < 0
    error('runPlutoAzimuthEnvironmentalScan:htmlOpenFailed', ...
        'Could not open %s for writing.', htmlPath);
end
cleanupFile = onCleanup(@() fclose(fid));

fprintf(fid, '<!doctype html>\n<html><head><meta charset="utf-8">\n');
fprintf(fid, '<title>%s</title>\n', localHtmlEscape("Pluto Azimuth Environmental Scan"));
fprintf(fid, ['<style>body{font-family:Arial,sans-serif;margin:2rem;line-height:1.4}', ...
    'img{max-width:100%%;border:1px solid #ccc;margin:1rem 0}', ...
    'table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:0.25rem 0.45rem}', ...
    'code{background:#eee;padding:0.1rem 0.25rem}</style>\n']);
fprintf(fid, '</head><body>\n');
fprintf(fid, '<h1>Pluto Azimuth Environmental Scan</h1>\n');
fprintf(fid, '<p><strong>Scan ID:</strong> %s<br>\n', localHtmlEscape(scan.scan_id));
fprintf(fid, '<strong>Created UTC:</strong> %s<br>\n', localHtmlEscape(scan.created_utc));
fprintf(fid, '<strong>Directional channel:</strong> %s</p>\n', ...
    localHtmlEscape(scan.analysis.directional_channel));

fprintf(fid, '<h2>Plain-language interpretation</h2>\n');
fprintf(fid, ['<p>The ambient spectra show what the two receive channels saw while the Pluto ', ...
    'calibration burst window was excluded. The calibration pattern scores only the short ', ...
    '11-tone Pluto burst. If the directional antenna is behaving like a directional sensor, ', ...
    'its ambient and calibration curves should change more with bearing than the reference channel.</p>\n']);

fprintf(fid, '<h2>Summary</h2>\n<ul>\n');
fprintf(fid, '<li>Directional ambient span: %.2f dB</li>\n', scan.analysis.directional_ambient_power_span_db);
fprintf(fid, '<li>Reference ambient span: %.2f dB</li>\n', scan.analysis.reference_ambient_power_span_db);
fprintf(fid, '<li>Directional calibration span: %.2f dB</li>\n', scan.analysis.directional_calibration_span_db);
fprintf(fid, '<li>Reference calibration span: %.2f dB</li>\n', scan.analysis.reference_calibration_span_db);
fprintf(fid, '<li>Strongest ambient bearing: %.1f deg true</li>\n', scan.analysis.strongest_ambient_bearing_deg);
fprintf(fid, '<li>Strongest calibration bearing: %.1f deg true</li>\n', scan.analysis.strongest_calibration_bearing_deg);
fprintf(fid, '</ul>\n');

fprintf(fid, '<h2>Plots</h2>\n');
localHtmlImage(fid, 'environment_power_polar.png', 'Ambient RF power versus azimuth');
localHtmlImage(fid, 'calibration_pattern_polar.png', 'Pluto calibration comb response versus azimuth');
localHtmlImage(fid, 'calibration_tone_margin_heatmap.png', 'Per-tone Pluto comb calibration margin heatmap');
localHtmlImage(fid, 'calibration_tone_margin_by_frequency.png', 'Per-tone Pluto comb shape by bearing');
localHtmlImage(fid, 'directional_psd_heatmap.png', 'Directional-channel ambient PSD heatmap');
localHtmlImage(fid, 'reference_psd_heatmap.png', 'Reference-channel ambient PSD heatmap');
localHtmlImage(fid, 'channel_ratio_and_metrics.png', 'Directional/reference ratio metrics');

fprintf(fid, '<h2>Per-bearing table</h2>\n');
fprintf(fid, '<p>CSV version: <a href="azimuth_summary.csv">azimuth_summary.csv</a></p>\n');
localWriteHtmlTable(fid, scan.summary_table);

fprintf(fid, '<h2>Per-tone calibration table</h2>\n');
fprintf(fid, ['<p>CSV version: <a href="calibration_tone_summary.csv">calibration_tone_summary.csv</a>. ', ...
    'This table is the easiest way to inspect whether one tone or one side of the comb behaves differently across azimuth.</p>\n']);

fprintf(fid, '<h2>Artifacts</h2>\n<ul>\n');
fprintf(fid, '<li><a href="summary.txt">summary.txt</a></li>\n');
fprintf(fid, '<li><a href="scan_result.mat">scan_result.mat</a></li>\n');
fprintf(fid, '<li><a href="azimuth_summary.csv">azimuth_summary.csv</a></li>\n');
fprintf(fid, '<li><a href="calibration_tone_summary.csv">calibration_tone_summary.csv</a></li>\n');
fprintf(fid, '</ul>\n');
fprintf(fid, '</body></html>\n');
clear cleanupFile
end

function localHtmlImage(fid, fileName, altText)
fprintf(fid, '<h3>%s</h3>\n', localHtmlEscape(altText));
fprintf(fid, '<img src="%s" alt="%s">\n', localHtmlEscape(fileName), localHtmlEscape(altText));
end

function localWriteHtmlTable(fid, tbl)
fprintf(fid, '<table><thead><tr>');
for idx = 1:numel(tbl.Properties.VariableNames)
    fprintf(fid, '<th>%s</th>', localHtmlEscape(tbl.Properties.VariableNames{idx}));
end
fprintf(fid, '</tr></thead><tbody>\n');
for rowIdx = 1:height(tbl)
    fprintf(fid, '<tr>');
    for colIdx = 1:numel(tbl.Properties.VariableNames)
        value = tbl{rowIdx, colIdx};
        if isnumeric(value)
            cellText = compose("%.6g", value);
        else
            cellText = string(value);
        end
        fprintf(fid, '<td>%s</td>', localHtmlEscape(cellText));
    end
    fprintf(fid, '</tr>\n');
end
fprintf(fid, '</tbody></table>\n');
end

function escaped = localHtmlEscape(value)
escaped = string(value);
escaped = replace(escaped, "&", "&amp;");
escaped = replace(escaped, "<", "&lt;");
escaped = replace(escaped, ">", "&gt;");
escaped = replace(escaped, """", "&quot;");
escaped = char(escaped);
end

function localPrintScanSummary(scan)
disp(localSummaryText(scan));
fprintf('[runPlutoAzimuthEnvironmentalScan] HTML report: %s\n', scan.artifact_paths.html);
fprintf('[runPlutoAzimuthEnvironmentalScan] Summary CSV: %s\n', scan.artifact_paths.summary_csv);
end
