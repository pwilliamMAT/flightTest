function result = runPlutoMultitoneStage6Smoke(varargin)
%RUNPLUTOMULTITONESTAGE6SMOKE Combined Pluto-to-USRP multitone smoke test.
%
% Plain-language concept:
%   This is the lowest-risk live Phase 2B experiment after the CW gate. The
%   Pluto transmits several narrow tones in one CPI instead of one tone. The
%   N320 capture path is unchanged. On receive, each channel is scored at
%   each expected tone offset, then the evidence is summarized across the
%   tone comb. This tests whether multiple pilot lines give stronger
%   channel evidence without introducing chirp matched filtering yet.
%
% Important boundary:
%   This runner is a smoke experiment only. It does not replace
%   runPlutoTonePrecheck, does not require a commissioned baseline, and does
%   not alter the Phase 1 CW readiness gate.
%
% Example FTC command:
%   matlab -batch "cd('TestSetupTesting'); result = runPlutoMultitoneStage6Smoke('Verbose',true);"

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SessionID', "pluto_multitone_smoke", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureFileBase', "pluto_multitone_smoke", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'ToneOffsets_Hz', [-350 -250 -150 -50 50 150 250 350] * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'TargetRMSAmplitude', 0.20, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'PeakLimit', 0.80, @(x) isnumeric(x) && isscalar(x) && x > 0 && x <= 1);
addParameter(p, 'CaptureDuration_s', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

test_root = fileparts(mfilename('fullpath'));
project_root = fileparts(test_root);
analysis_root = fullfile(project_root, 'BistaticDataAnalysis');

capture_root = string(opts.CaptureRoot);
if strlength(capture_root) == 0
    capture_root = fullfile(project_root, 'captures', 'plutoMultitoneSmoke');
end

original_folder = pwd;
original_path = path;
cleanup_folder = onCleanup(@() cd(original_folder));
cleanup_path = onCleanup(@() path(original_path));

cd(test_root);
addpath(analysis_root, '-begin');

if opts.Verbose
    fprintf('[runPlutoMultitoneStage6Smoke] Project root .. %s\n', project_root);
    fprintf('[runPlutoMultitoneStage6Smoke] Test root ..... %s\n', test_root);
    fprintf('[runPlutoMultitoneStage6Smoke] loadIQData ..... %s\n', which('loadIQData'));
end

tx_context = struct();

try
    [waveform, waveform_info] = helperPlutoMultitoneBuildWaveform( ...
        opts.SampleRate_Hz, ...
        opts.ToneOffsets_Hz, ...
        opts.TargetRMSAmplitude, ...
        'PeakLimit', opts.PeakLimit, ...
        'Verbose', opts.Verbose);

    tx_context = helperPlutoToneStartTx( ...
        'CenterFrequencyHz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
        'SampleRateHz', double(opts.SampleRate_Hz), ...
        'Waveform', waveform, ...
        'Verbose', opts.Verbose);

    capture_info = helperPlutoToneCaptureN320( ...
        'SessionID', string(opts.SessionID), ...
        'CaptureRoot', char(capture_root), ...
        'CaptureFileBase', string(opts.CaptureFileBase), ...
        'RadioName', string(opts.RadioName), ...
        'CenterFrequencyHz', double(opts.CenterFrequency_Hz), ...
        'SampleRateHz', double(opts.SampleRate_Hz), ...
        'LOOffsetHz', double(opts.LOOffset_Hz), ...
        'Gain', double(opts.Gain(:).'), ...
        'CaptureDurationSeconds', double(opts.CaptureDuration_s), ...
        'Verbose', opts.Verbose);

    [reference_signal, surveillance_signal, capture_info_out] = helperPlutoToneReadCapture( ...
        capture_info, ...
        'ExpectedSampleRateHz', double(opts.SampleRate_Hz), ...
        'CaptureDurationSeconds', double(opts.CaptureDuration_s), ...
        'Verbose', opts.Verbose);

    localReleaseTransmitter(tx_context);
    tx_context = struct();

    [multitone_metrics, diagnostics] = helperPlutoMultitoneScoreCapture( ...
        reference_signal, ...
        surveillance_signal, ...
        double(opts.SampleRate_Hz), ...
        double(opts.ToneOffsets_Hz(:)), ...
        'Verbose', opts.Verbose);

    result = struct( ...
        'settings', struct( ...
            'session_id', char(string(opts.SessionID)), ...
            'capture_root', char(capture_root), ...
            'radio_name', char(string(opts.RadioName)), ...
            'capture_file_base', char(string(opts.CaptureFileBase)), ...
            'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
            'sample_rate_hz', double(opts.SampleRate_Hz), ...
            'lo_offset_hz', double(opts.LOOffset_Hz), ...
            'capture_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
            'gain', double(opts.Gain(:).'), ...
            'tone_offsets_hz', double(opts.ToneOffsets_Hz(:)), ...
            'target_rms_amplitude', double(opts.TargetRMSAmplitude), ...
            'peak_limit', double(opts.PeakLimit), ...
            'capture_duration_s', double(opts.CaptureDuration_s)), ...
        'waveform_info', waveform_info, ...
        'capture_info', capture_info_out, ...
        'multitone_metrics', multitone_metrics, ...
        'diagnostics', diagnostics);

    if opts.PlotFigures
        result.figure_handle = localPlotMultitoneSmoke(result);
    end

    if opts.Verbose
        localPrintSummary(result);
    end
catch me
    localReleaseTransmitter(tx_context);
    rethrow(me)
end
end

function localReleaseTransmitter(tx_context)
if isstruct(tx_context) && isfield(tx_context, 'transmitter') && ~isempty(tx_context.transmitter)
    try
        release(tx_context.transmitter);
    catch
    end
end
end

function localPrintSummary(result)
metrics = result.multitone_metrics;
fprintf('\nPLUTO MULTITONE SMOKE: %s\n', metrics.status);
fprintf('REF  tones %d/%d | median margin %.1f dB | integrated margin %.1f dB\n', ...
    metrics.reference.num_tones_found, ...
    metrics.reference.num_tones_expected, ...
    metrics.reference.median_detect_margin_db, ...
    metrics.reference.integrated_detect_margin_db);
fprintf('SURV tones %d/%d | median margin %.1f dB | integrated margin %.1f dB\n', ...
    metrics.surveillance.num_tones_found, ...
    metrics.surveillance.num_tones_expected, ...
    metrics.surveillance.median_detect_margin_db, ...
    metrics.surveillance.integrated_detect_margin_db);
fprintf('JOINT median channel delta %.1f Hz | xcorr %.1f dB at %+d sample(s)\n\n', ...
    metrics.joint.median_channel_frequency_delta_hz, ...
    metrics.xcorr_advisory.peak_db, ...
    metrics.xcorr_advisory.lag_samples);
end

function fig = localPlotMultitoneSmoke(result)
metrics = result.multitone_metrics;
tone_offsets_khz = metrics.tone_offsets_hz(:) / 1e3;

fig = figure('Name', 'Pluto multitone smoke summary', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto Phase 2B multitone smoke summary');

nexttile(tl, 1);
bar(tone_offsets_khz, [metrics.reference.detect_margin_db(:), metrics.surveillance.detect_margin_db(:)]);
grid on;
xlabel('Expected tone offset (kHz)');
ylabel('Detect margin (dB)');
title('Per-tone detect margin');
legend({'REF', 'SURV'}, 'Location', 'best');

nexttile(tl, 2);
bar(tone_offsets_khz, metrics.joint.channel_frequency_delta_hz(:));
grid on;
xlabel('Expected tone offset (kHz)');
ylabel('Channel frequency delta (Hz)');
title('Per-tone REF/SURV frequency agreement');

nexttile(tl, 3);
plot(result.diagnostics.xcorr_diagnostics.lags_samples, ...
    20 * log10(result.diagnostics.xcorr_diagnostics.correlation_abs + eps), ...
    'LineWidth', 1.1);
grid on;
xlabel('Lag (samples)');
ylabel('Correlation magnitude (dB)');
title('Advisory cross-correlation');

nexttile(tl, 4);
summary_values = [ ...
    metrics.reference.num_tones_found; ...
    metrics.surveillance.num_tones_found; ...
    metrics.joint.num_tones_found_both_channels];
bar(categorical(["REF found", "SURV found", "Both found"]), summary_values);
ylim([0, metrics.num_tones + 0.5]);
grid on;
ylabel('Tone count');
title(sprintf('Status: %s', metrics.status));
end
