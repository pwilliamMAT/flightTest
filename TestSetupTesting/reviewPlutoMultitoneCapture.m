function review = reviewPlutoMultitoneCapture(source, varargin)
%REVIEWPLUTOMULTITONECAPTURE Offline review for a saved Pluto multitone capture.
%
% Plain-language concept:
%   The live multitone smoke runner proves whether the Pluto/N320 path can
%   transmit and receive a comb of pilot tones. Once the `.bb` capture has
%   synced off the field-test computer, this offline review repeats the
%   receive-side scoring without touching hardware and writes durable review
%   artifacts. That keeps repeated experiments comparable even when the live
%   MATLAB batch output scrolls away.
%
% Syntax:
%   review = reviewPlutoMultitoneCapture(source)
%   review = reviewPlutoMultitoneCapture(source, 'OutputFolder', outDir)
%
% Inputs:
%   source can be a `.bb` capture file path, or a folder containing a
%   `*part1` capture file.
%
% Outputs:
%   The returned struct and written artifacts contain the same channel
%   convention used by Phase 1:
%     SURV = CH1/RX1 = RF0:RX2
%     REF  = CH2/RX2 = RF1:RX2
%
% See also: helperPlutoMultitoneScoreCapture, helperPlutoToneReadCapture.

arguments
    source {mustBeTextScalar}
end
arguments (Repeating)
    varargin
end

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CaptureDuration_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ToneOffsets_Hz', [-350 -250 -150 -50 50 150 250 350] * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'ScoringMode', "expected-bin", @(x) any(strcmpi(string(x), ["expected-bin", "search-peak"])));
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

source = string(source);
capture_file = localResolveCaptureFile(source);
output_folder = localResolveOutputFolder(capture_file, opts.OutputFolder);
if strlength(output_folder) > 0 && ~isfolder(output_folder)
    mkdir(output_folder);
end

capture_info = struct( ...
    'session_id', char(localSessionIdFromPath(capture_file)), ...
    'local_capture_files', capture_file, ...
    'header_center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'header_lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'header_sample_rate_hz', double(opts.SampleRate_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'capture_duration_s', double(opts.CaptureDuration_s));

% Read the capture through the same helper as the live runner. This preserves
% the project channel mapping and the existing loadIQData behavior.
[reference_signal, surveillance_signal, capture_info_out] = helperPlutoToneReadCapture( ...
    capture_info, ...
    'ExpectedSampleRateHz', double(opts.SampleRate_Hz), ...
    'CaptureDurationSeconds', double(opts.CaptureDuration_s), ...
    'Verbose', opts.Verbose);

[multitone_metrics, diagnostics] = helperPlutoMultitoneScoreCapture( ...
    reference_signal, ...
    surveillance_signal, ...
    double(opts.SampleRate_Hz), ...
    double(opts.ToneOffsets_Hz(:)), ...
    'ScoringMode', opts.ScoringMode, ...
    'Verbose', opts.Verbose);

review = struct( ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'source', char(source), ...
    'capture_file', char(capture_file), ...
    'settings', struct( ...
        'sample_rate_hz', double(opts.SampleRate_Hz), ...
        'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
        'lo_offset_hz', double(opts.LOOffset_Hz), ...
        'capture_duration_s', double(opts.CaptureDuration_s), ...
        'scoring_mode', char(string(opts.ScoringMode)), ...
        'tone_offsets_hz', double(opts.ToneOffsets_Hz(:))), ...
    'capture_info', capture_info_out, ...
    'multitone_metrics', multitone_metrics, ...
    'diagnostics', diagnostics, ...
    'artifact_paths', struct());

if opts.PlotFigures
    review.figure_handle = localPlotReview(review);
end

if strlength(output_folder) > 0
    review = localWriteArtifacts(review, output_folder);
end

if opts.Verbose
    localPrintSummary(review);
end
end

function capture_file = localResolveCaptureFile(source)
if isfile(source)
    capture_file = source;
    return
end

if ~isfolder(source)
    error('reviewPlutoMultitoneCapture:sourceNotFound', ...
        'Source must be a capture file or folder: %s', source);
end

files = dir(fullfile(source, '*part1*'));
files = files(~[files.isdir]);
if isempty(files)
    files = dir(fullfile(source, '*'));
    files = files(~[files.isdir]);
end
if isempty(files)
    error('reviewPlutoMultitoneCapture:noCaptureFiles', ...
        'No capture files were found in %s.', source);
end

[~, newest_idx] = max([files.datenum]);
capture_file = string(fullfile(files(newest_idx).folder, files(newest_idx).name));
end

function output_folder = localResolveOutputFolder(capture_file, requested_output_folder)
requested_output_folder = string(requested_output_folder);
if strlength(requested_output_folder) > 0
    output_folder = requested_output_folder;
    return
end

capture_folder = string(fileparts(capture_file));
timestamp = string(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
output_folder = fullfile(capture_folder, "multitone_review_" + timestamp);
end

function session_id = localSessionIdFromPath(capture_file)
[~, name] = fileparts(capture_file);
session_id = string(name);
part_idx = strfind(session_id, "_part");
if ~isempty(part_idx)
    session_id = extractBefore(session_id, part_idx(1));
end
end

function review = localWriteArtifacts(review, output_folder)
result_mat = fullfile(output_folder, 'result.mat');
summary_txt = fullfile(output_folder, 'summary.txt');
summary_png = fullfile(output_folder, 'summary.png');

review_for_save = review;
if isfield(review_for_save, 'figure_handle')
    review_for_save = rmfield(review_for_save, 'figure_handle');
end
save(result_mat, 'review_for_save');

fid = fopen(summary_txt, 'w');
if fid < 0
    error('reviewPlutoMultitoneCapture:summaryOpenFailed', ...
        'Could not open summary file for writing: %s', summary_txt);
end
cleanup_file = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', localSummaryLines(review));
clear cleanup_file

if isfield(review, 'figure_handle') && isgraphics(review.figure_handle)
    exportgraphics(review.figure_handle, summary_png, 'Resolution', 150);
end

review.artifact_paths = struct( ...
    'result_mat', string(result_mat), ...
    'summary_txt', string(summary_txt), ...
    'summary_png', string(summary_png));
end

function lines = localSummaryLines(review)
metrics = review.multitone_metrics;
lines = [
    "PLUTO MULTITONE REVIEW: " + string(metrics.status)
    "Scoring mode: " + string(metrics.scoring_mode)
    "Capture: " + string(review.capture_file)
    "REF  tones " + metrics.reference.num_tones_found + "/" + metrics.num_tones + ...
        " | median margin " + compose("%.1f", metrics.reference.median_detect_margin_db) + ...
        " dB | integrated margin " + compose("%.1f", metrics.reference.integrated_detect_margin_db) + " dB"
    "SURV tones " + metrics.surveillance.num_tones_found + "/" + metrics.num_tones + ...
        " | median margin " + compose("%.1f", metrics.surveillance.median_detect_margin_db) + ...
        " dB | integrated margin " + compose("%.1f", metrics.surveillance.integrated_detect_margin_db) + " dB"
    "JOINT median channel delta " + compose("%.1f", metrics.joint.median_channel_frequency_delta_hz) + ...
        " Hz (" + string(metrics.joint.frequency_agreement_source) + ") | xcorr " + ...
        compose("%.1f", metrics.xcorr_advisory.peak_db) + ...
        " dB at " + metrics.xcorr_advisory.lag_samples + " sample(s)"
    "Warn codes: " + strjoin(string(metrics.warn_codes), ", ")
    "Fail codes: " + strjoin(string(metrics.fail_codes), ", ")
    ];
end

function localPrintSummary(review)
disp(localSummaryLines(review));
if isfield(review, 'artifact_paths') && isfield(review.artifact_paths, 'summary_txt')
    fprintf('[reviewPlutoMultitoneCapture] Artifacts written to %s\n', ...
        fileparts(review.artifact_paths.summary_txt));
end
end

function fig = localPlotReview(review)
metrics = review.multitone_metrics;
tone_offsets_khz = metrics.tone_offsets_hz(:) / 1e3;

fig = figure('Name', 'Pluto multitone capture review', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto multitone capture review');

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
plot(review.diagnostics.xcorr_diagnostics.lags_samples, ...
    20 * log10(review.diagnostics.xcorr_diagnostics.correlation_abs + eps), ...
    'LineWidth', 1.1);
grid on;
xlabel('Lag (samples)');
ylabel('Correlation magnitude (dB)');
title('Advisory cross-correlation');

nexttile(tl, 4);
counts = [
    metrics.reference.num_tones_found
    metrics.surveillance.num_tones_found
    metrics.joint.num_tones_found_both_channels];
bar(categorical(["REF found", "SURV found", "Both found"]), counts);
ylim([0, metrics.num_tones + 0.5]);
grid on;
ylabel('Tone count');
title(sprintf('Status: %s', metrics.status));
end
