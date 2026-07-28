function review = reviewPlutoToneCaptureSpectra(varargin)
%REVIEWPLUTOTONECAPTURESPECTRA Plot spectra for saved Pluto-to-USRP captures.
%
% Plain-language goal:
%   A Pluto CW injection should appear in the received N320 baseband as a
%   narrow spectral spike at the requested tone offset. This offline review
%   reads saved dual-channel .bb captures, plots the Welch PSD for the two
%   receive paths, and reports how strongly each antenna sees that tone.
%
% Why Welch PSD is used:
%   pwelch averages spectra from multiple short windows. That reduces the
%   noise variance enough that a weak CW line is easier to compare against
%   the local floor without needing a new hardware run.
%
% Frozen channel convention:
%   CH1/RX1 = SURV = RF0:RX2
%   CH2/RX2 = REF  = RF1:RX2
%
% Example:
%   review = reviewPlutoToneCaptureSpectra;
%
%   review = reviewPlutoToneCaptureSpectra( ...
%       'CaptureFolders', fullfile(pwd, 'captures', 'plutoSmoke'), ...
%       'MaxCaptures', 3);
%
% Outputs:
%   TestSetupTesting/plutoSpectrumReviews/<review_id>/summary.csv
%   TestSetupTesting/plutoSpectrumReviews/<review_id>/*_spectrum.png

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'CaptureFolders', strings(0, 1), @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'CaptureFiles', strings(0, 1), @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'MaxCaptures', inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'MinCaptureBytes', 1024 * 1024, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'NumSamples', 262144, @(x) isnumeric(x) && isscalar(x) && x >= 4096);
addParameter(p, 'WelchWindowLength', 8192, @(x) isnumeric(x) && isscalar(x) && x >= 128);
addParameter(p, 'NFFT', 131072, @(x) isnumeric(x) && isscalar(x) && x >= 1024);
addParameter(p, 'DefaultExpectedToneHz', 250e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ToneSearchHalfWidthHz', 40e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ToneZoomHalfWidthHz', 120e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

test_root = fileparts(mfilename('fullpath'));
project_root = fileparts(test_root);

capture_files = localResolveCaptureFiles(project_root, opts);
if isfinite(opts.MaxCaptures)
    capture_files = capture_files(1:min(numel(capture_files), opts.MaxCaptures));
end
if isempty(capture_files)
    error('reviewPlutoToneCaptureSpectra:noCaptures', ...
        'No capture files were found for spectrum review.');
end

review_id = "pluto_spectrum_review_" + string(datetime( ...
    'now', 'TimeZone', 'UTC', 'Format', 'yyyyMMdd''T''HHmmss'));
output_folder = string(opts.OutputFolder);
if strlength(output_folder) == 0
    output_folder = fullfile(test_root, 'plutoSpectrumReviews', char(review_id));
end
if exist(char(output_folder), 'dir') ~= 7
    mkdir(char(output_folder));
end

summary_rows = repmat(localEmptySummaryRow(), numel(capture_files), 1);
capture_reviews = cell(numel(capture_files), 1);

if opts.Verbose
    fprintf('[reviewPlutoToneCaptureSpectra] Captures .... %d\n', numel(capture_files));
    fprintf('[reviewPlutoToneCaptureSpectra] Output ...... %s\n', char(output_folder));
end

for idx = 1:numel(capture_files)
    capture_path = string(capture_files(idx));
    if opts.Verbose
        fprintf('[reviewPlutoToneCaptureSpectra] %02d/%02d %s\n', ...
            idx, numel(capture_files), char(capture_path));
    end

    try
        capture_reviews{idx} = localReviewOneCapture(capture_path, output_folder, opts);
        summary_rows(idx) = capture_reviews{idx}.summary_row;
    catch me
        warning('reviewPlutoToneCaptureSpectra:captureFailed', ...
            'Could not review %s: %s', char(capture_path), me.message);
        summary_rows(idx) = localErrorSummaryRow(capture_path, me, opts);
        capture_reviews{idx} = struct( ...
            'capture_file', capture_path, ...
            'status', "ERROR", ...
            'message', string(me.message));
    end
end

summary_table = struct2table(summary_rows);
summary_path = fullfile(char(output_folder), 'summary.csv');
writetable(summary_table, summary_path);

review = struct( ...
    'schema_version', 1, ...
    'review_id', char(review_id), ...
    'output_folder', char(output_folder), ...
    'summary_csv', summary_path, ...
    'capture_files', capture_files, ...
    'summary_table', summary_table, ...
    'capture_reviews', {capture_reviews});

try
    save(fullfile(char(output_folder), 'review.mat'), 'review');
catch me_save
    warning('reviewPlutoToneCaptureSpectra:matSaveFailed', ...
        'Could not save review.mat: %s', me_save.message);
end

if opts.Verbose
    disp(summary_table(:, {'CaptureName', 'ExpectedToneHz', ...
        'RefDetectMarginDB', 'SurvDetectMarginDB', ...
        'RefFrequencyErrorHz', 'SurvFrequencyErrorHz', ...
        'ChannelFrequencyDeltaHz', 'SpectrumPNG'}));
end
end

function capture_files = localResolveCaptureFiles(project_root, opts)
explicit_files = string(opts.CaptureFiles);
explicit_files = explicit_files(:);
explicit_files = explicit_files(strlength(explicit_files) > 0);

if ~isempty(explicit_files)
    capture_files = explicit_files;
    return
end

capture_folders = string(opts.CaptureFolders);
capture_folders = capture_folders(:);
capture_folders = capture_folders(strlength(capture_folders) > 0);
if isempty(capture_folders)
    capture_folders = [
        string(fullfile(project_root, 'captures', 'plutoSmoke'))
        string(fullfile(project_root, 'captures', 'plutoCommissioning'))
        ];
end

capture_files = strings(0, 1);
for folder_idx = 1:numel(capture_folders)
    folder_path = char(capture_folders(folder_idx));
    if exist(folder_path, 'dir') ~= 7
        continue
    end
    listing = dir(folder_path);
    for item_idx = 1:numel(listing)
        item = listing(item_idx);
        if item.isdir || startsWith(string(item.name), ".")
            continue
        end
        if item.bytes < opts.MinCaptureBytes
            continue
        end
        capture_files(end + 1, 1) = string(fullfile(item.folder, item.name)); %#ok<AGROW>
    end
end

capture_files = unique(capture_files, 'stable');
end

function capture_review = localReviewOneCapture(capture_path, output_folder, opts)
[iq, header] = localReadCapture(capture_path, opts.NumSamples);

if size(iq, 2) < 2
    error('reviewPlutoToneCaptureSpectra:singleChannelCapture', ...
        'Expected at least two channels in %s.', char(capture_path));
end

% Keep the labels aligned with the frozen project convention. The plot
% deliberately shows SURV first because it is CH1 on disk, but the metrics
% table follows the Phase 1 summary convention of reporting REF and SURV.
surv_signal = double(iq(:, 1));
ref_signal = double(iq(:, 2));
fs = header.sample_rate_hz;
expected_tone_hz = localExpectedToneFromName(capture_path, opts.DefaultExpectedToneHz);

surv_psd = localComputePSD(surv_signal, fs, opts);
ref_psd = localComputePSD(ref_signal, fs, opts);

[ref_metrics, ref_diag] = localScoreSignal( ...
    ref_signal, fs, expected_tone_hz, 'REF', opts);
[surv_metrics, surv_diag] = localScoreSignal( ...
    surv_signal, fs, expected_tone_hz, 'SURV', opts);

png_path = localPlotSpectrumReview( ...
    capture_path, output_folder, header, expected_tone_hz, ...
    ref_psd, surv_psd, ref_metrics, surv_metrics, ref_diag, surv_diag, opts);

summary_row = localSummaryRow( ...
    capture_path, header, expected_tone_hz, ref_metrics, surv_metrics, png_path);

capture_review = struct( ...
    'capture_file', capture_path, ...
    'status', "OK", ...
    'header', header, ...
    'expected_tone_hz', expected_tone_hz, ...
    'reference_metrics', ref_metrics, ...
    'surveillance_metrics', surv_metrics, ...
    'reference_psd', ref_psd, ...
    'surveillance_psd', surv_psd, ...
    'spectrum_png', png_path, ...
    'summary_row', summary_row);
end

function [iq, header] = localReadCapture(capture_path, num_samples)
reader = comm.BasebandFileReader(char(capture_path), 'SamplesPerFrame', num_samples);
cleanup_reader = onCleanup(@() release(reader));

reader_info = info(reader);
metadata = reader.Metadata;
samples_to_read = min(num_samples, reader_info.NumSamplesInData);
release(reader);

reader = comm.BasebandFileReader(char(capture_path), 'SamplesPerFrame', samples_to_read);
cleanup_reader = onCleanup(@() release(reader));
iq = reader();

header = struct( ...
    'sample_rate_hz', double(reader.SampleRate), ...
    'center_frequency_hz', double(reader.CenterFrequency), ...
    'lo_offset_hz', localMetadataNumber(metadata, 'LOOffset', NaN), ...
    'tune_frequency_hz', double(reader.CenterFrequency) + ...
        localMetadataNumber(metadata, 'LOOffset', 0), ...
    'num_samples_in_file', double(reader_info.NumSamplesInData), ...
    'num_samples_read', double(size(iq, 1)), ...
    'num_channels', double(size(iq, 2)), ...
    'metadata', metadata);
end

function psd = localComputePSD(signal, fs, opts)
signal = double(signal(:));
signal = signal - mean(signal, 'omitnan');
full_scale = localFullScale(signal);

window_length = min(opts.WelchWindowLength, numel(signal));
window = hann(window_length, 'periodic');
overlap_length = floor(window_length / 2);
nfft = min(opts.NFFT, 2 ^ nextpow2(numel(signal)));
nfft = max(nfft, 2 ^ nextpow2(window_length));

[pxx, frequency_hz] = pwelch(signal, window, overlap_length, nfft, fs, 'centered');
rbw_hz = fs / nfft;
bin_power = pxx .* rbw_hz;
spectrum_dbfs = 10 * log10(bin_power ./ (full_scale ^ 2) + eps);

psd = struct( ...
    'frequency_hz', frequency_hz(:), ...
    'spectrum_dbfs', spectrum_dbfs(:), ...
    'rbw_hz', rbw_hz, ...
    'full_scale', full_scale, ...
    'window_length', window_length, ...
    'overlap_length', overlap_length, ...
    'nfft', nfft);
end

function [metrics, diagnostics] = localScoreSignal(signal, fs, expected_tone_hz, channel_label, opts)
if isfinite(expected_tone_hz)
    [metrics, diagnostics] = helperPlutoToneScoreChannel( ...
        signal, fs, ...
        'ChannelLabel', channel_label, ...
        'ExpectedFrequencyHz', expected_tone_hz, ...
        'SearchHalfWidthHz', opts.ToneSearchHalfWidthHz, ...
        'WelchWindowLength', opts.WelchWindowLength, ...
        'NFFT', opts.NFFT, ...
        'Verbose', false);
else
    metrics = localPeakOnlyMetrics(signal, fs, channel_label, opts);
    diagnostics = struct();
end
end

function metrics = localPeakOnlyMetrics(signal, fs, channel_label, opts)
psd = localComputePSD(signal, fs, opts);
[tone_peak_dbfs, peak_idx] = max(psd.spectrum_dbfs);
measured_frequency_hz = psd.frequency_hz(peak_idx);
floor_dbfs = median(psd.spectrum_dbfs, 'omitnan');

channel_label = upper(string(channel_label));
if channel_label == "REF"
    channel_index = 2;
    rx_label = 'CH2/RX2';
else
    channel_index = 1;
    rx_label = 'CH1/RX1';
end

metrics = struct( ...
    'channel_label', char(channel_label), ...
    'channel_index', channel_index, ...
    'rx_label', rx_label, ...
    'tone_found', true, ...
    'expected_frequency_hz', NaN, ...
    'measured_frequency_hz', measured_frequency_hz, ...
    'frequency_error_hz', NaN, ...
    'level_dbfs', 20 * log10(rms(double(signal(:))) / localFullScale(signal) + eps), ...
    'tone_peak_dbfs', tone_peak_dbfs, ...
    'local_floor_dbfs', floor_dbfs, ...
    'detect_margin_db', tone_peak_dbfs - floor_dbfs, ...
    'level_delta_vs_baseline_db', NaN, ...
    'status', 'INFO', ...
    'fail_codes', {cell(0, 1)}, ...
    'warn_codes', {cell(0, 1)});
end

function png_path = localPlotSpectrumReview( ...
    capture_path, output_folder, header, expected_tone_hz, ...
    ref_psd, surv_psd, ref_metrics, surv_metrics, ref_diag, surv_diag, opts)

[~, capture_name, capture_ext] = fileparts(char(capture_path));
if strlength(string(capture_ext)) > 0
    capture_name = [capture_name, capture_ext];
end
safe_name = matlab.lang.makeValidName(capture_name);
png_path = string(fullfile(char(output_folder), [safe_name, '_spectrum.png']));

fig = figure( ...
    'Name', ['Pluto spectrum: ', capture_name], ...
    'NumberTitle', 'off', ...
    'Visible', char(string(opts.FigureVisibility)), ...
    'Position', [100, 100, 1400, 900]);
cleanup_fig = onCleanup(@() close(fig));
tlo = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax_full = nexttile(tlo, 1);
plot(ax_full, surv_psd.frequency_hz / 1e6, surv_psd.spectrum_dbfs, ...
    'Color', [0.10, 0.40, 0.75], 'DisplayName', 'SURV CH1/RX1');
hold(ax_full, 'on');
plot(ax_full, ref_psd.frequency_hz / 1e6, ref_psd.spectrum_dbfs, ...
    'Color', [0.85, 0.33, 0.10], 'DisplayName', 'REF CH2/RX2');
localAddToneLine(ax_full, expected_tone_hz / 1e6);
grid(ax_full, 'on');
xlabel(ax_full, 'Baseband Frequency [MHz]');
ylabel(ax_full, 'Welch Bin Power [dBFS]');
title(ax_full, 'Full Captured Baseband Spectrum');
legend(ax_full, 'Location', 'best');

ax_zoom = nexttile(tlo, 2);
plot(ax_zoom, surv_psd.frequency_hz / 1e3, surv_psd.spectrum_dbfs, ...
    'Color', [0.10, 0.40, 0.75], 'DisplayName', 'SURV');
hold(ax_zoom, 'on');
plot(ax_zoom, ref_psd.frequency_hz / 1e3, ref_psd.spectrum_dbfs, ...
    'Color', [0.85, 0.33, 0.10], 'DisplayName', 'REF');
localAddToneLine(ax_zoom, expected_tone_hz / 1e3);
if isfinite(expected_tone_hz)
    xlim(ax_zoom, (expected_tone_hz + [-opts.ToneZoomHalfWidthHz, opts.ToneZoomHalfWidthHz]) / 1e3);
else
    xlim(ax_zoom, localPeakZoomLimitsKHz(ref_psd, surv_psd));
end
grid(ax_zoom, 'on');
xlabel(ax_zoom, 'Baseband Frequency [kHz]');
ylabel(ax_zoom, 'Welch Bin Power [dBFS]');
title(ax_zoom, 'Tone Region');
legend(ax_zoom, 'Location', 'best');

ax_bar = nexttile(tlo, 3);
bar(ax_bar, categorical({'REF margin', 'SURV margin'}), ...
    [ref_metrics.detect_margin_db, surv_metrics.detect_margin_db], ...
    'FaceColor', [0.35, 0.55, 0.75]);
grid(ax_bar, 'on');
ylabel(ax_bar, 'Tone Above Local Floor [dB]');
title(ax_bar, 'Per-Antenna Tone Visibility');

ax_text = nexttile(tlo, 4);
text(ax_text, 0.01, 0.98, localSummaryText( ...
    capture_name, header, expected_tone_hz, ref_metrics, surv_metrics, ...
    ref_diag, surv_diag), ...
    'Interpreter', 'none', ...
    'FontName', 'Courier New', ...
    'FontSize', 10, ...
    'VerticalAlignment', 'top');
xlim(ax_text, [0, 1]);
ylim(ax_text, [0, 1]);
set(ax_text, 'XTick', [], 'YTick', []);
xlabel(ax_text, 'Normalized X');
ylabel(ax_text, 'Normalized Y');
title(ax_text, 'Capture and Tone Metrics');

exportgraphics(fig, char(png_path), 'Resolution', 150);
end

function localAddToneLine(ax, tone_value)
if isfinite(tone_value)
    xline(ax, tone_value, '--k', 'Expected tone', ...
        'LabelVerticalAlignment', 'bottom', ...
        'LabelHorizontalAlignment', 'left', ...
        'HandleVisibility', 'off');
end
end

function limits_khz = localPeakZoomLimitsKHz(ref_psd, surv_psd)
[~, ref_idx] = max(ref_psd.spectrum_dbfs);
[~, surv_idx] = max(surv_psd.spectrum_dbfs);
center_hz = mean([ref_psd.frequency_hz(ref_idx), surv_psd.frequency_hz(surv_idx)]);
limits_khz = (center_hz + [-120e3, 120e3]) / 1e3;
end

function text_out = localSummaryText(capture_name, header, expected_tone_hz, ...
    ref_metrics, surv_metrics, ref_diag, surv_diag)
delta_hz = abs(ref_metrics.measured_frequency_hz - surv_metrics.measured_frequency_hz);
text_out = sprintf([ ...
    'Capture: %s\n' ...
    'Fs: %.6f MSps | Fc: %.3f MHz | Tune: %.3f MHz\n' ...
    'Samples read/ch: %d of %d | Channels: %d\n' ...
    'Expected tone: %s\n' ...
    '\n' ...
    'REF  CH2/RX2: margin %+7.2f dB | peak %8.2f dBFS | floor %8.2f dBFS\n' ...
    '              measured %11.1f Hz | error %s | level %7.2f dBFS\n' ...
    'SURV CH1/RX1: margin %+7.2f dB | peak %8.2f dBFS | floor %8.2f dBFS\n' ...
    '              measured %11.1f Hz | error %s | level %7.2f dBFS\n' ...
    '\n' ...
    'Channel frequency delta: %.1f Hz\n' ...
    'Welch RBW: REF %.1f Hz | SURV %.1f Hz\n'], ...
    capture_name, ...
    header.sample_rate_hz / 1e6, ...
    header.center_frequency_hz / 1e6, ...
    header.tune_frequency_hz / 1e6, ...
    header.num_samples_read, ...
    header.num_samples_in_file, ...
    header.num_channels, ...
    localFormatFrequency(expected_tone_hz), ...
    ref_metrics.detect_margin_db, ...
    ref_metrics.tone_peak_dbfs, ...
    ref_metrics.local_floor_dbfs, ...
    ref_metrics.measured_frequency_hz, ...
    localFormatFrequency(ref_metrics.frequency_error_hz), ...
    ref_metrics.level_dbfs, ...
    surv_metrics.detect_margin_db, ...
    surv_metrics.tone_peak_dbfs, ...
    surv_metrics.local_floor_dbfs, ...
    surv_metrics.measured_frequency_hz, ...
    localFormatFrequency(surv_metrics.frequency_error_hz), ...
    surv_metrics.level_dbfs, ...
    delta_hz, ...
    localDiagnosticRBW(ref_diag, NaN), ...
    localDiagnosticRBW(surv_diag, NaN));
end

function rbw_hz = localDiagnosticRBW(diagnostics, default_value)
rbw_hz = default_value;
if isstruct(diagnostics) && isfield(diagnostics, 'rbw_hz') && isfinite(diagnostics.rbw_hz)
    rbw_hz = diagnostics.rbw_hz;
end
end

function text_out = localFormatFrequency(value_hz)
if isfinite(value_hz)
    text_out = sprintf('%.1f Hz', value_hz);
else
    text_out = 'unknown';
end
end

function expected_tone_hz = localExpectedToneFromName(capture_path, default_expected_tone_hz)
name = lower(string(capture_path));
expected_tone_hz = double(default_expected_tone_hz);

tokens = regexp(name, 'offset_([0-9]+)khz', 'tokens', 'once');
if ~isempty(tokens)
    expected_tone_hz = str2double(tokens{1}) * 1e3;
    return
end

tokens = regexp(name, 'offset([0-9]+)', 'tokens', 'once');
if isempty(tokens)
    return
end

offset_code = str2double(tokens{1});
switch offset_code
    case 15
        expected_tone_hz = 1.5e6;
    case 32
        expected_tone_hz = 3.2e6;
    otherwise
        expected_tone_hz = offset_code * 1e3;
end
end

function row = localSummaryRow(capture_path, header, expected_tone_hz, ...
    ref_metrics, surv_metrics, png_path)
[~, capture_name, capture_ext] = fileparts(char(capture_path));
if strlength(string(capture_ext)) > 0
    capture_name = [capture_name, capture_ext];
end

row = localEmptySummaryRow();
row.CaptureName = string(capture_name);
row.CaptureFile = string(capture_path);
row.Status = "OK";
row.SampleRateHz = header.sample_rate_hz;
row.CenterFrequencyHz = header.center_frequency_hz;
row.TuneFrequencyHz = header.tune_frequency_hz;
row.SamplesRead = header.num_samples_read;
row.ExpectedToneHz = expected_tone_hz;
row.RefMeasuredFrequencyHz = ref_metrics.measured_frequency_hz;
row.SurvMeasuredFrequencyHz = surv_metrics.measured_frequency_hz;
row.RefFrequencyErrorHz = ref_metrics.frequency_error_hz;
row.SurvFrequencyErrorHz = surv_metrics.frequency_error_hz;
row.ChannelFrequencyDeltaHz = abs(ref_metrics.measured_frequency_hz - ...
    surv_metrics.measured_frequency_hz);
row.RefDetectMarginDB = ref_metrics.detect_margin_db;
row.SurvDetectMarginDB = surv_metrics.detect_margin_db;
row.RefTonePeakDBFS = ref_metrics.tone_peak_dbfs;
row.SurvTonePeakDBFS = surv_metrics.tone_peak_dbfs;
row.RefLocalFloorDBFS = ref_metrics.local_floor_dbfs;
row.SurvLocalFloorDBFS = surv_metrics.local_floor_dbfs;
row.RefLevelDBFS = ref_metrics.level_dbfs;
row.SurvLevelDBFS = surv_metrics.level_dbfs;
row.SpectrumPNG = string(png_path);
row.ErrorMessage = "";
end

function row = localErrorSummaryRow(capture_path, me, opts)
[~, capture_name, capture_ext] = fileparts(char(capture_path));
if strlength(string(capture_ext)) > 0
    capture_name = [capture_name, capture_ext];
end
row = localEmptySummaryRow();
row.CaptureName = string(capture_name);
row.CaptureFile = string(capture_path);
row.Status = "ERROR";
row.ExpectedToneHz = localExpectedToneFromName(capture_path, opts.DefaultExpectedToneHz);
row.ErrorMessage = string(me.message);
end

function row = localEmptySummaryRow()
row = struct( ...
    'CaptureName', "", ...
    'CaptureFile', "", ...
    'Status', "", ...
    'SampleRateHz', NaN, ...
    'CenterFrequencyHz', NaN, ...
    'TuneFrequencyHz', NaN, ...
    'SamplesRead', NaN, ...
    'ExpectedToneHz', NaN, ...
    'RefMeasuredFrequencyHz', NaN, ...
    'SurvMeasuredFrequencyHz', NaN, ...
    'RefFrequencyErrorHz', NaN, ...
    'SurvFrequencyErrorHz', NaN, ...
    'ChannelFrequencyDeltaHz', NaN, ...
    'RefDetectMarginDB', NaN, ...
    'SurvDetectMarginDB', NaN, ...
    'RefTonePeakDBFS', NaN, ...
    'SurvTonePeakDBFS', NaN, ...
    'RefLocalFloorDBFS', NaN, ...
    'SurvLocalFloorDBFS', NaN, ...
    'RefLevelDBFS', NaN, ...
    'SurvLevelDBFS', NaN, ...
    'SpectrumPNG', "", ...
    'ErrorMessage', "");
end

function value = localMetadataNumber(metadata, field_name, default_value)
value = default_value;
if isstruct(metadata) && isfield(metadata, field_name) && ~isempty(metadata.(field_name))
    numeric_value = double(metadata.(field_name));
    if isscalar(numeric_value) && isfinite(numeric_value)
        value = numeric_value;
    end
end
end

function full_scale = localFullScale(signal)
max_abs_value = max(abs(double(signal(:))), [], 'omitnan');
if max_abs_value > 2.0
    full_scale = 32768;
else
    full_scale = 1.0;
end
end
