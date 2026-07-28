function batch = runPlutoMultitoneRepeatabilityBatch(varargin)
%RUNPLUTOMULTITONEREPEATABILITYBATCH Repeat one Pluto multitone setup.
%
% Plain-language concept:
%   A calibration health check needs repeatability before it needs more
%   waveform design. This batch runner repeats one fixed Pluto multitone
%   waveform several times, then runs the existing offline reviews on each
%   saved capture. The large `.bb` files stay on the field-test computer;
%   the portable outputs are summary tables, MAT files, text summaries, and
%   PNG plots.
%
% Syntax:
%   batch = runPlutoMultitoneRepeatabilityBatch
%   batch = runPlutoMultitoneRepeatabilityBatch('RepeatCount', 20)
%
% Default waveform:
%   11 tones from -500 kHz to +500 kHz with 100 kHz spacing.
%
% See also: runPlutoMultitoneStage6Smoke, reviewPlutoMultitoneCapture,
% reviewPlutoMultitoneCpiIntegration, runPlutoMultitoneSlowTimeDetector.

defaultBatchId = "pluto_outer11_100khz_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RepeatCount', 20, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'BatchID', defaultBatchId, @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionPrefix', "pluto_outer11_100khz", @(x) ischar(x) || isstring(x));
addParameter(p, 'ToneOffsets_Hz', (-500:100:500) * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'CaptureRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PauseBetweenRuns_s', 2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'ContinueOnError', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

testRoot = fileparts(mfilename('fullpath'));
projectRoot = fileparts(testRoot);
captureRoot = string(opts.CaptureRoot);
if strlength(captureRoot) == 0
    captureRoot = fullfile(projectRoot, 'captures', 'plutoMultitoneSmoke');
end

outputRoot = string(opts.OutputRoot);
if strlength(outputRoot) == 0
    outputRoot = fullfile(captureRoot, string(opts.BatchID) + "_analysis");
end
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

originalFigureVisible = get(groot, 'DefaultFigureVisible');
if opts.PlotFigures
    set(groot, 'DefaultFigureVisible', 'off');
end
cleanupFigureVisibility = onCleanup(@() set(groot, 'DefaultFigureVisible', originalFigureVisible));

repeatCount = double(opts.RepeatCount);
toneOffsetsHz = double(opts.ToneOffsets_Hz(:));
rows = localInitializeRows(repeatCount);

if opts.Verbose
    fprintf('[runPlutoMultitoneRepeatabilityBatch] Batch ......... %s\n', string(opts.BatchID));
    fprintf('[runPlutoMultitoneRepeatabilityBatch] Repeats ....... %d\n', repeatCount);
    fprintf('[runPlutoMultitoneRepeatabilityBatch] Tone offsets .. %s kHz\n', ...
        strjoin(compose('%.0f', toneOffsetsHz(:).' / 1e3), ', '));
    fprintf('[runPlutoMultitoneRepeatabilityBatch] Output root ... %s\n', outputRoot);
end

for runIdx = 1:repeatCount
    sessionId = sprintf('%s_%03d', char(string(opts.SessionPrefix)), runIdx);
    rows.RunIndex(runIdx) = runIdx;
    rows.SessionID(runIdx) = string(sessionId);

    if opts.Verbose
        fprintf('\n=== Pluto multitone repeatability run %d/%d: %s ===\n', ...
            runIdx, repeatCount, sessionId);
    end

    try
        liveResult = runPlutoMultitoneStage6Smoke( ...
            'SessionID', string(sessionId), ...
            'CaptureFileBase', string(sessionId), ...
            'CaptureRoot', char(captureRoot), ...
            'ToneOffsets_Hz', toneOffsetsHz, ...
            'PlotFigures', false, ...
            'Verbose', opts.Verbose);

        captureFile = localCaptureFileFromResult(liveResult);
        rows.CaptureFile(runIdx) = captureFile;

        runOutputRoot = fullfile(outputRoot, string(sessionId));
        if ~isfolder(runOutputRoot)
            mkdir(runOutputRoot);
        end

        expectedReview = reviewPlutoMultitoneCapture( ...
            captureFile, ...
            'ToneOffsets_Hz', toneOffsetsHz, ...
            'OutputFolder', fullfile(runOutputRoot, 'expected_bin_review'), ...
            'PlotFigures', opts.PlotFigures, ...
            'Verbose', false);

        cpiReview = reviewPlutoMultitoneCpiIntegration( ...
            captureFile, ...
            'ToneOffsets_Hz', toneOffsetsHz, ...
            'OutputFolder', fullfile(runOutputRoot, 'cpi_integration_review'), ...
            'PlotFigures', opts.PlotFigures, ...
            'Verbose', false);

        slowTimeDetection = runPlutoMultitoneSlowTimeDetector( ...
            captureFile, ...
            'ToneOffsets_Hz', toneOffsetsHz, ...
            'OutputFolder', fullfile(runOutputRoot, 'slow_time_detector'), ...
            'PlotFigures', opts.PlotFigures, ...
            'Verbose', false);

        rows = localFillSuccessRow(rows, runIdx, expectedReview, cpiReview, slowTimeDetection);
        rows.Status(runIdx) = "OK";
    catch me
        rows.Status(runIdx) = "ERROR";
        rows.ErrorMessage(runIdx) = string(me.message);
        if opts.Verbose
            fprintf('[runPlutoMultitoneRepeatabilityBatch] ERROR in %s: %s\n', ...
                sessionId, me.message);
        end
        if ~opts.ContinueOnError
            rethrow(me)
        end
    end

    localWriteBatchArtifacts(rows, outputRoot, opts, toneOffsetsHz);
    if runIdx < repeatCount && opts.PauseBetweenRuns_s > 0
        pause(opts.PauseBetweenRuns_s);
    end
end

batchTable = localRowsToTable(rows);
batch = struct( ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'settings', struct( ...
        'repeat_count', repeatCount, ...
        'batch_id', char(string(opts.BatchID)), ...
        'session_prefix', char(string(opts.SessionPrefix)), ...
        'tone_offsets_hz', toneOffsetsHz, ...
        'capture_root', char(captureRoot), ...
        'output_root', char(outputRoot)), ...
    'table', batchTable, ...
    'artifact_paths', localWriteBatchArtifacts(rows, outputRoot, opts, toneOffsetsHz));

if opts.Verbose
    fprintf('\nPLUTO MULTITONE REPEATABILITY BATCH COMPLETE\n');
    disp(batchTable);
    fprintf('[runPlutoMultitoneRepeatabilityBatch] Summary CSV: %s\n', ...
        batch.artifact_paths.summary_csv);
end
end

function rows = localInitializeRows(repeatCount)
rows = struct( ...
    'RunIndex', zeros(repeatCount, 1), ...
    'SessionID', strings(repeatCount, 1), ...
    'Status', strings(repeatCount, 1), ...
    'CaptureFile', strings(repeatCount, 1), ...
    'ExpectedStatus', strings(repeatCount, 1), ...
    'REF_ExpectedIntegrated_dB', nan(repeatCount, 1), ...
    'SURV_ExpectedIntegrated_dB', nan(repeatCount, 1), ...
    'SearchPeakMedianDelta_Hz', nan(repeatCount, 1), ...
    'REF_SlowTimePeak_dB', nan(repeatCount, 1), ...
    'SURV_SlowTimePeak_dB', nan(repeatCount, 1), ...
    'MedianCrossChannelCoherence', nan(repeatCount, 1), ...
    'CommonDetectorContrast_dB', nan(repeatCount, 1), ...
    'TonewiseDetectorContrast_dB', nan(repeatCount, 1), ...
    'TonewisePeakFrequencyStd_Hz', nan(repeatCount, 1), ...
    'ErrorMessage', strings(repeatCount, 1));
end

function batchTable = localRowsToTable(rows)
batchTable = table( ...
    rows.RunIndex(:), ...
    rows.SessionID(:), ...
    rows.Status(:), ...
    rows.CaptureFile(:), ...
    rows.ExpectedStatus(:), ...
    rows.REF_ExpectedIntegrated_dB(:), ...
    rows.SURV_ExpectedIntegrated_dB(:), ...
    rows.SearchPeakMedianDelta_Hz(:), ...
    rows.REF_SlowTimePeak_dB(:), ...
    rows.SURV_SlowTimePeak_dB(:), ...
    rows.MedianCrossChannelCoherence(:), ...
    rows.CommonDetectorContrast_dB(:), ...
    rows.TonewiseDetectorContrast_dB(:), ...
    rows.TonewisePeakFrequencyStd_Hz(:), ...
    rows.ErrorMessage(:), ...
    'VariableNames', { ...
        'RunIndex', ...
        'SessionID', ...
        'Status', ...
        'CaptureFile', ...
        'ExpectedStatus', ...
        'REF_ExpectedIntegrated_dB', ...
        'SURV_ExpectedIntegrated_dB', ...
        'SearchPeakMedianDelta_Hz', ...
        'REF_SlowTimePeak_dB', ...
        'SURV_SlowTimePeak_dB', ...
        'MedianCrossChannelCoherence', ...
        'CommonDetectorContrast_dB', ...
        'TonewiseDetectorContrast_dB', ...
        'TonewisePeakFrequencyStd_Hz', ...
        'ErrorMessage'});
end

function captureFile = localCaptureFileFromResult(liveResult)
captureFile = "";
if isfield(liveResult, 'capture_info') && isfield(liveResult.capture_info, 'capture_file_path')
    captureFile = string(liveResult.capture_info.capture_file_path);
elseif isfield(liveResult, 'capture_info') && isfield(liveResult.capture_info, 'local_capture_files')
    captureFile = string(liveResult.capture_info.local_capture_files(1));
end
if strlength(captureFile) == 0 || exist(char(captureFile), 'file') ~= 2
    error('runPlutoMultitoneRepeatabilityBatch:captureFileMissing', ...
        'The live run did not return a readable capture file path.');
end
end

function rows = localFillSuccessRow(rows, runIdx, expectedReview, cpiReview, slowTimeDetection)
metrics = expectedReview.multitone_metrics;
cpiSummary = cpiReview.integration.summary;
detector = slowTimeDetection.slow_time_detection;

rows.ExpectedStatus(runIdx) = string(metrics.status);
rows.REF_ExpectedIntegrated_dB(runIdx) = metrics.reference.integrated_detect_margin_db;
rows.SURV_ExpectedIntegrated_dB(runIdx) = metrics.surveillance.integrated_detect_margin_db;
rows.SearchPeakMedianDelta_Hz(runIdx) = metrics.joint.median_channel_frequency_delta_hz;
rows.REF_SlowTimePeak_dB(runIdx) = cpiSummary.reference_comb_slow_time_peak_margin_db;
rows.SURV_SlowTimePeak_dB(runIdx) = cpiSummary.surveillance_comb_slow_time_peak_margin_db;
rows.MedianCrossChannelCoherence(runIdx) = cpiSummary.median_cross_channel_coherence;
rows.CommonDetectorContrast_dB(runIdx) = detector.peak_contrast_db;
rows.TonewiseDetectorContrast_dB(runIdx) = detector.tonewise_peak_detection.comb_peak_contrast_db;
rows.TonewisePeakFrequencyStd_Hz(runIdx) = detector.tonewise_peak_detection.peak_frequency_std_hz;
end

function artifactPaths = localWriteBatchArtifacts(rows, outputRoot, opts, toneOffsetsHz)
batchTable = localRowsToTable(rows);
summaryCsv = fullfile(outputRoot, 'batch_summary.csv');
summaryMat = fullfile(outputRoot, 'batch_summary.mat');
summaryTxt = fullfile(outputRoot, 'batch_summary.txt');
summaryPng = fullfile(outputRoot, 'batch_summary.png');

writetable(batchTable, summaryCsv);
settings = struct( ...
    'repeat_count', double(opts.RepeatCount), ...
    'batch_id', char(string(opts.BatchID)), ...
    'session_prefix', char(string(opts.SessionPrefix)), ...
    'tone_offsets_hz', toneOffsetsHz(:));
save(summaryMat, 'batchTable', 'settings');

fid = fopen(summaryTxt, 'w');
if fid < 0
    error('runPlutoMultitoneRepeatabilityBatch:summaryOpenFailed', ...
        'Could not open %s for writing.', summaryTxt);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, 'PLUTO MULTITONE REPEATABILITY BATCH\n');
fprintf(fid, 'Batch ID: %s\n', string(opts.BatchID));
fprintf(fid, 'Tone offsets kHz: %s\n\n', strjoin(compose('%.0f', toneOffsetsHz(:).' / 1e3), ', '));
fprintf(fid, '%s\n', localBatchStatsText(batchTable));
clear cleanupFile

if opts.PlotFigures
    fig = localPlotBatchSummary(batchTable);
    exportgraphics(fig, summaryPng, 'Resolution', 150);
    close(fig);
end

artifactPaths = struct( ...
    'summary_csv', string(summaryCsv), ...
    'summary_mat', string(summaryMat), ...
    'summary_txt', string(summaryTxt), ...
    'summary_png', string(summaryPng));
end

function lines = localBatchStatsText(batchTable)
okMask = batchTable.Status == "OK";
if ~any(okMask)
    lines = "No successful runs yet.";
    return
end

lines = [
    "Successful runs: " + nnz(okMask) + "/" + height(batchTable)
    "REF expected integrated margin: median " + ...
        compose("%.2f", median(batchTable.REF_ExpectedIntegrated_dB(okMask), 'omitnan')) + " dB"
    "SURV expected integrated margin: median " + ...
        compose("%.2f", median(batchTable.SURV_ExpectedIntegrated_dB(okMask), 'omitnan')) + " dB"
    "REF slow-time peak margin: median " + ...
        compose("%.2f", median(batchTable.REF_SlowTimePeak_dB(okMask), 'omitnan')) + " dB"
    "SURV slow-time peak margin: median " + ...
        compose("%.2f", median(batchTable.SURV_SlowTimePeak_dB(okMask), 'omitnan')) + " dB"
    "Median cross-channel coherence: median " + ...
        compose("%.3f", median(batchTable.MedianCrossChannelCoherence(okMask), 'omitnan'))
    "Tonewise detector contrast: median " + ...
        compose("%.2f", median(batchTable.TonewiseDetectorContrast_dB(okMask), 'omitnan')) + " dB"
    ];
end

function fig = localPlotBatchSummary(batchTable)
okMask = batchTable.Status == "OK";
runIndex = batchTable.RunIndex;

fig = figure('Name', 'Pluto multitone repeatability batch', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto multitone repeatability batch');

nexttile(tl, 1);
plot(runIndex(okMask), batchTable.REF_ExpectedIntegrated_dB(okMask), '-o', 'LineWidth', 1.1);
hold on;
plot(runIndex(okMask), batchTable.SURV_ExpectedIntegrated_dB(okMask), '-o', 'LineWidth', 1.1);
grid on;
xlabel('Run index');
ylabel('Expected-bin integrated margin (dB)');
title('Whole-capture comb evidence');
legend({'REF', 'SURV'}, 'Location', 'best');

nexttile(tl, 2);
plot(runIndex(okMask), batchTable.REF_SlowTimePeak_dB(okMask), '-o', 'LineWidth', 1.1);
hold on;
plot(runIndex(okMask), batchTable.SURV_SlowTimePeak_dB(okMask), '-o', 'LineWidth', 1.1);
grid on;
xlabel('Run index');
ylabel('Slow-time peak margin (dB)');
title('CPI integration');
legend({'REF', 'SURV'}, 'Location', 'best');

nexttile(tl, 3);
plot(runIndex(okMask), batchTable.MedianCrossChannelCoherence(okMask), '-o', 'LineWidth', 1.1);
ylim([0, 1]);
grid on;
xlabel('Run index');
ylabel('Median coherence');
title('REF/SURV coherence');

nexttile(tl, 4);
plot(runIndex(okMask), batchTable.CommonDetectorContrast_dB(okMask), '-o', 'LineWidth', 1.1);
hold on;
plot(runIndex(okMask), batchTable.TonewiseDetectorContrast_dB(okMask), '-o', 'LineWidth', 1.1);
grid on;
xlabel('Run index');
ylabel('Detector contrast (dB)');
title('Common-bin vs tonewise detector');
legend({'Common-bin', 'Tonewise'}, 'Location', 'best');
end
