function check = runPlutoMultitoneCalibrationCheck(varargin)
%RUNPLUTOMULTITONECALIBRATIONCHECK Compare current multitone health against baseline.
%
% Plain-language concept:
%   A calibration check repeats the golden multitone setup and compares the
%   current receive fingerprint with the saved baseline. The check is meant
%   to answer practical health questions: did either antenna path lose
%   injected-signal margin, did REF/SURV coherence change, or did the
%   slow-time detector become less stable than the known-good baseline?
%
% Offline-first workflow:
%   Pass CheckSource to analyze a saved `.bb` capture or capture folder. If
%   CheckSource is omitted, this function runs a live Pluto multitone smoke
%   capture using the waveform and hardware settings stored in the baseline.
%
% Syntax:
%   check = runPlutoMultitoneCalibrationCheck('BaselinePath', baselinePath)
%   check = runPlutoMultitoneCalibrationCheck('BaselinePath', baselinePath, ...
%       'CheckSource', captureFile)
%
% See also: runPlutoMultitoneCalibrationBaseline,
% runPlutoMultitoneStage6Smoke.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'BaselinePath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CheckSource', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

baseline = localLoadBaseline(opts.BaselinePath);
settings = baseline.settings;

runId = string(opts.SessionID);
if strlength(runId) == 0
    runId = "pluto_multitone_cal_check_" + string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd''T''HHmmss'));
end

outputRoot = string(opts.OutputRoot);
if strlength(outputRoot) == 0
    outputRoot = localDefaultOutputRoot(baseline, opts.BaselinePath, runId);
end
if ~isfolder(outputRoot)
    mkdir(outputRoot);
end

checkSource = string(opts.CheckSource);
if strlength(checkSource) == 0
    captureRoot = string(opts.CaptureRoot);
    if strlength(captureRoot) == 0
        captureRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
            'captures', 'plutoMultitoneCalibrationChecks');
    end
    liveResult = runPlutoMultitoneStage6Smoke( ...
        'SessionID', runId, ...
        'CaptureFileBase', runId, ...
        'CaptureRoot', char(captureRoot), ...
        'CenterFrequency_Hz', settings.center_frequency_hz, ...
        'SampleRate_Hz', settings.sample_rate_hz, ...
        'LOOffset_Hz', settings.lo_offset_hz, ...
        'Gain', settings.gain, ...
        'ToneOffsets_Hz', settings.tone_offsets_hz, ...
        'TargetRMSAmplitude', settings.target_rms_amplitude, ...
        'CaptureDuration_s', settings.capture_duration_s, ...
        'PlotFigures', false, ...
        'Verbose', opts.Verbose);
    checkSource = localCaptureFileFromLiveResult(liveResult);
end

[currentRow, reviewArtifacts] = localAnalyzeCheckSource(checkSource, baseline, outputRoot, opts.PlotFigures);
[status, failCodes, warnCodes, comparisonTable] = localCompareToBaseline(currentRow, baseline);

check = struct( ...
    'schema_version', 1, ...
    'check_id', char(runId), ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'baseline_id', baseline.baseline_id, ...
    'baseline_path', char(string(opts.BaselinePath)), ...
    'status', status, ...
    'overall_pass', strcmp(status, 'PASS'), ...
    'fail_codes', {failCodes}, ...
    'warn_codes', {warnCodes}, ...
    'settings', settings, ...
    'check_source', char(checkSource), ...
    'current_metrics', currentRow, ...
    'comparison_table', comparisonTable, ...
    'review_artifacts', reviewArtifacts, ...
    'artifact_paths', struct());

check = localWriteCheckArtifacts(check, outputRoot, opts.PlotFigures);

if opts.Verbose
    localPrintCheckSummary(check);
end
end

function baseline = localLoadBaseline(baselinePath)
baselinePath = string(baselinePath);
if strlength(baselinePath) == 0
    error('runPlutoMultitoneCalibrationCheck:missingBaselinePath', ...
        'BaselinePath is required.');
end

if isfolder(baselinePath)
    baselinePath = fullfile(baselinePath, 'baseline.mat');
end
if ~isfile(baselinePath)
    error('runPlutoMultitoneCalibrationCheck:baselineMissing', ...
        'Baseline MAT file was not found: %s', baselinePath);
end

loaded = load(baselinePath);
if isfield(loaded, 'baseline')
    baseline = loaded.baseline;
elseif isfield(loaded, 'baselineForSave')
    baseline = loaded.baselineForSave;
else
    error('runPlutoMultitoneCalibrationCheck:badBaselineFile', ...
        'The baseline MAT file does not contain a baseline struct.');
end
end

function outputRoot = localDefaultOutputRoot(baseline, baselinePath, runId)
baselineFolder = "";
if isfield(baseline, 'artifact_paths') && isstruct(baseline.artifact_paths) && ...
        isfield(baseline.artifact_paths, 'baseline_folder')
    baselineFolder = string(baseline.artifact_paths.baseline_folder);
end

if strlength(baselineFolder) == 0
    baselinePath = string(baselinePath);
    if isfolder(baselinePath)
        baselineFolder = baselinePath;
    else
        baselineFolder = string(fileparts(baselinePath));
    end
end

outputRoot = fullfile(fileparts(baselineFolder), string(runId) + "_check");
end

function captureFile = localCaptureFileFromLiveResult(liveResult)
captureFile = "";
if isfield(liveResult, 'capture_info') && isfield(liveResult.capture_info, 'capture_file_path')
    captureFile = string(liveResult.capture_info.capture_file_path);
elseif isfield(liveResult, 'capture_info') && isfield(liveResult.capture_info, 'local_capture_files')
    captureFile = string(liveResult.capture_info.local_capture_files(1));
end
if strlength(captureFile) == 0 || exist(char(captureFile), 'file') ~= 2
    error('runPlutoMultitoneCalibrationCheck:captureFileMissing', ...
        'The live check did not return a readable capture file path.');
end
end

function [currentRow, reviewArtifacts] = localAnalyzeCheckSource(checkSource, baseline, outputRoot, plotFigures)
toneOffsetsHz = baseline.settings.tone_offsets_hz;

expectedFolder = fullfile(outputRoot, 'expected_bin_review');
cpiFolder = fullfile(outputRoot, 'cpi_integration_review');
detectorFolder = fullfile(outputRoot, 'slow_time_detector');

expectedReview = reviewPlutoMultitoneCapture(checkSource, ...
    'ToneOffsets_Hz', toneOffsetsHz, ...
    'OutputFolder', expectedFolder, ...
    'PlotFigures', plotFigures, ...
    'Verbose', false);
cpiReview = reviewPlutoMultitoneCpiIntegration(checkSource, ...
    'ToneOffsets_Hz', toneOffsetsHz, ...
    'OutputFolder', cpiFolder, ...
    'PlotFigures', plotFigures, ...
    'Verbose', false);
detector = runPlutoMultitoneSlowTimeDetector(checkSource, ...
    'ToneOffsets_Hz', toneOffsetsHz, ...
    'OutputFolder', detectorFolder, ...
    'PlotFigures', plotFigures, ...
    'Verbose', false);

metrics = expectedReview.multitone_metrics;
cpiSummary = cpiReview.integration.summary;
slowTime = detector.slow_time_detection;

currentRow = table( ...
    1, ...
    string(expectedReview.capture_file), ...
    string(metrics.status), ...
    metrics.reference.integrated_detect_margin_db, ...
    metrics.surveillance.integrated_detect_margin_db, ...
    metrics.joint.median_channel_frequency_delta_hz, ...
    cpiSummary.reference_comb_slow_time_peak_margin_db, ...
    cpiSummary.surveillance_comb_slow_time_peak_margin_db, ...
    cpiSummary.median_cross_channel_coherence, ...
    slowTime.peak_contrast_db, ...
    slowTime.tonewise_peak_detection.comb_peak_contrast_db, ...
    slowTime.tonewise_peak_detection.peak_frequency_std_hz, ...
    'VariableNames', localMetricVariableNames());

reviewArtifacts = struct( ...
    'expected_bin_review', expectedReview.artifact_paths, ...
    'cpi_integration_review', cpiReview.artifact_paths, ...
    'slow_time_detector', detector.artifact_paths);
end

function [status, failCodes, warnCodes, comparisonTable] = localCompareToBaseline(currentRow, baseline)
thresholds = baseline.thresholds;
stats = baseline.statistics;
failCodes = cell(0, 1);
warnCodes = cell(0, 1);

metricNames = localNumericMetricNames();
baselineMedian = nan(numel(metricNames), 1);
currentValue = nan(numel(metricNames), 1);
deltaValue = nan(numel(metricNames), 1);
classification = strings(numel(metricNames), 1);

for idx = 1:numel(metricNames)
    name = metricNames{idx};
    baselineMedian(idx) = stats.(name).median;
    currentValue(idx) = currentRow.(name)(1);
    deltaValue(idx) = currentValue(idx) - baselineMedian(idx);
    classification(idx) = "PASS";
end

[failCodes, warnCodes, classification] = localApplyDropRule( ...
    'REF_ExpectedIntegrated_dB', 'REF_EXPECTED_INTEGRATED_DROP', ...
    thresholds.expected_integrated_warn_drop_db, thresholds.expected_integrated_fail_drop_db, ...
    metricNames, deltaValue, failCodes, warnCodes, classification);
[failCodes, warnCodes, classification] = localApplyDropRule( ...
    'SURV_ExpectedIntegrated_dB', 'SURV_EXPECTED_INTEGRATED_DROP', ...
    thresholds.expected_integrated_warn_drop_db, thresholds.expected_integrated_fail_drop_db, ...
    metricNames, deltaValue, failCodes, warnCodes, classification);
[failCodes, warnCodes, classification] = localApplyDropRule( ...
    'REF_SlowTimePeak_dB', 'REF_SLOW_TIME_PEAK_DROP', ...
    thresholds.slow_time_peak_warn_drop_db, thresholds.slow_time_peak_fail_drop_db, ...
    metricNames, deltaValue, failCodes, warnCodes, classification);
[failCodes, warnCodes, classification] = localApplyDropRule( ...
    'SURV_SlowTimePeak_dB', 'SURV_SLOW_TIME_PEAK_DROP', ...
    thresholds.slow_time_peak_warn_drop_db, thresholds.slow_time_peak_fail_drop_db, ...
    metricNames, deltaValue, failCodes, warnCodes, classification);
[failCodes, warnCodes, classification] = localApplyDropRule( ...
    'TonewiseDetectorContrast_dB', 'TONEWISE_DETECTOR_CONTRAST_DROP', ...
    thresholds.tonewise_contrast_warn_drop_db, thresholds.tonewise_contrast_fail_drop_db, ...
    metricNames, deltaValue, failCodes, warnCodes, classification);

[failCodes, warnCodes, classification] = localApplyCoherenceRule( ...
    metricNames, currentValue, deltaValue, thresholds, failCodes, warnCodes, classification);
[failCodes, warnCodes, classification] = localApplyFrequencyStdRule( ...
    metricNames, deltaValue, thresholds, failCodes, warnCodes, classification);

comparisonTable = table( ...
    string(metricNames(:)), ...
    baselineMedian, ...
    currentValue, ...
    deltaValue, ...
    classification, ...
    'VariableNames', {'Metric', 'BaselineMedian', 'CurrentValue', 'DeltaVsBaseline', 'Status'});

if ~isempty(failCodes)
    status = 'FAIL';
elseif ~isempty(warnCodes)
    status = 'WARN';
else
    status = 'PASS';
end
end

function [failCodes, warnCodes, classification] = localApplyDropRule( ...
        metricName, codePrefix, warnDropDb, failDropDb, metricNames, deltaValue, failCodes, warnCodes, classification)
idx = find(strcmp(metricNames, metricName), 1);
if isempty(idx) || ~isfinite(deltaValue(idx))
    return
end
dropDb = -deltaValue(idx);
if dropDb >= failDropDb
    failCodes{end + 1} = [codePrefix, '_FAIL'];
    classification(idx) = "FAIL";
elseif dropDb >= warnDropDb
    warnCodes{end + 1} = [codePrefix, '_WARN'];
    classification(idx) = "WARN";
end
end

function [failCodes, warnCodes, classification] = localApplyCoherenceRule( ...
        metricNames, currentValue, deltaValue, thresholds, failCodes, warnCodes, classification)
idx = find(strcmp(metricNames, 'MedianCrossChannelCoherence'), 1);
if isempty(idx) || ~isfinite(currentValue(idx))
    return
end
drop = -deltaValue(idx);
if currentValue(idx) <= thresholds.coherence_fail_min || drop >= thresholds.coherence_fail_drop
    failCodes{end + 1} = 'CROSS_CHANNEL_COHERENCE_DROP_FAIL';
    classification(idx) = "FAIL";
elseif currentValue(idx) <= thresholds.coherence_warn_min || drop >= thresholds.coherence_warn_drop
    warnCodes{end + 1} = 'CROSS_CHANNEL_COHERENCE_DROP_WARN';
    classification(idx) = "WARN";
end
end

function [failCodes, warnCodes, classification] = localApplyFrequencyStdRule( ...
        metricNames, deltaValue, thresholds, failCodes, warnCodes, classification)
idx = find(strcmp(metricNames, 'TonewisePeakFrequencyStd_Hz'), 1);
if isempty(idx) || ~isfinite(deltaValue(idx))
    return
end
if deltaValue(idx) >= thresholds.tonewise_frequency_std_fail_increase_hz
    failCodes{end + 1} = 'TONEWISE_PEAK_FREQUENCY_STD_INCREASE_FAIL';
    classification(idx) = "FAIL";
elseif deltaValue(idx) >= thresholds.tonewise_frequency_std_warn_increase_hz
    warnCodes{end + 1} = 'TONEWISE_PEAK_FREQUENCY_STD_INCREASE_WARN';
    classification(idx) = "WARN";
end
end

function names = localMetricVariableNames()
names = { ...
    'RunIndex', ...
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
    'TonewisePeakFrequencyStd_Hz'};
end

function names = localNumericMetricNames()
names = localMetricVariableNames();
names = names(4:end);
end

function check = localWriteCheckArtifacts(check, outputRoot, plotFigures)
resultMat = fullfile(outputRoot, 'result.mat');
resultCsv = fullfile(outputRoot, 'result.csv');
comparisonCsv = fullfile(outputRoot, 'comparison.csv');
summaryTxt = fullfile(outputRoot, 'summary.txt');
summaryPng = fullfile(outputRoot, 'summary.png');

checkForSave = check;
checkForSave.artifact_paths = struct();
save(resultMat, 'checkForSave');
writetable(check.current_metrics, resultCsv);
writetable(check.comparison_table, comparisonCsv);
localWriteText(summaryTxt, localSummaryLines(check));

if plotFigures
    fig = localPlotCheck(check);
    exportgraphics(fig, summaryPng, 'Resolution', 150);
    close(fig);
end

check.artifact_paths = struct( ...
    'output_root', string(outputRoot), ...
    'result_mat', string(resultMat), ...
    'result_csv', string(resultCsv), ...
    'comparison_csv', string(comparisonCsv), ...
    'summary_txt', string(summaryTxt), ...
    'summary_png', string(summaryPng));
save(resultMat, 'check');
end

function lines = localSummaryLines(check)
lines = [
    "PLUTO MULTITONE CALIBRATION CHECK: " + string(check.status)
    "Baseline ID: " + string(check.baseline_id)
    "Check source: " + string(check.check_source)
    "Fail codes: " + strjoin(string(check.fail_codes), ", ")
    "Warn codes: " + strjoin(string(check.warn_codes), ", ")
    ];
for idx = 1:height(check.comparison_table)
    row = check.comparison_table(idx, :);
    lines(end + 1) = row.Metric + ": baseline " + compose("%.3f", row.BaselineMedian) + ...
        " | current " + compose("%.3f", row.CurrentValue) + ...
        " | delta " + compose("%+.3f", row.DeltaVsBaseline) + ...
        " | " + row.Status; %#ok<AGROW>
end
end

function localPrintCheckSummary(check)
disp(localSummaryLines(check));
fprintf('[runPlutoMultitoneCalibrationCheck] Output folder: %s\n', ...
    check.artifact_paths.output_root);
end

function localWriteText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('runPlutoMultitoneCalibrationCheck:textOpenFailed', ...
        'Could not open %s for writing.', path);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', lines);
clear cleanupFile
end

function fig = localPlotCheck(check)
comparison = check.comparison_table;
metricLabels = categorical(comparison.Metric);
metricLabels = reordercats(metricLabels, comparison.Metric);

fig = figure('Name', 'Pluto multitone calibration check', 'Color', 'w');
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Pluto multitone calibration check: %s', check.status));

nexttile(tl, 1);
bar(metricLabels, [comparison.BaselineMedian, comparison.CurrentValue]);
grid on;
ylabel('Metric value');
title('Current metrics versus baseline median');
legend({'Baseline', 'Current'}, 'Location', 'best');

nexttile(tl, 2);
bar(metricLabels, comparison.DeltaVsBaseline);
grid on;
ylabel('Current - baseline');
title('Metric drift');
end
