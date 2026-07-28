function baseline = runPlutoMultitoneCalibrationBaseline(varargin)
%RUNPLUTOMULTITONECALIBRATIONBASELINE Create a golden multitone calibration baseline.
%
% Plain-language concept:
%   A calibration baseline is the known-good fingerprint of the injected
%   Pluto comb as received by both N320 channels. Later health checks do
%   not need the environment to be perfect; they need to know whether the
%   current fingerprint has drifted from this golden reference. Drift can
%   indicate changed antenna coupling, a parked car near the antennas,
%   cable/receiver changes, or a degraded injection path.
%
% Offline-first workflow:
%   This first implementation commissions the baseline from saved captures
%   or from a repeatability batch CSV. That lets us settle the metric schema
%   and thresholds before making the live hardware path authoritative.
%
% Syntax:
%   baseline = runPlutoMultitoneCalibrationBaseline('RunSources', sources)
%
% RunSources can contain:
%   * `.bb` capture files
%   * folders containing `*part1` capture files
%   * a `batch_summary.csv` written by runPlutoMultitoneRepeatabilityBatch
%
% See also: runPlutoMultitoneCalibrationCheck,
% runPlutoMultitoneRepeatabilityBatch.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RunSources', [], @(x) ischar(x) || isstring(x) || iscell(x) || istable(x));
addParameter(p, 'BaselineRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'BaselineID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SiteID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementNotes', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ToneOffsets_Hz', (-500:100:500) * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'TargetRMSAmplitude', 0.20, @(x) isnumeric(x) && isscalar(x) && x > 0 && x < 1);
addParameter(p, 'CaptureDuration_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CpiDuration_s', 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Thresholds', localDefaultThresholds(), @isstruct);
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

runTable = localResolveRunTable(opts.RunSources, opts);
if isempty(runTable) || height(runTable) < 1
    error('runPlutoMultitoneCalibrationBaseline:noRuns', ...
        'At least one saved capture or batch_summary.csv row is required.');
end

baselineId = string(opts.BaselineID);
if strlength(baselineId) == 0
    baselineId = "pluto_multitone_baseline_" + string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd''T''HHmmss'));
end

baselineRoot = string(opts.BaselineRoot);
if strlength(baselineRoot) == 0
    baselineRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'captures', 'plutoMultitoneCalibrationBaselines');
end
baselineFolder = fullfile(baselineRoot, baselineId);
if ~isfolder(baselineFolder)
    mkdir(baselineFolder);
end

baseline = struct( ...
    'schema_version', 1, ...
    'baseline_id', char(baselineId), ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'site_id', char(string(opts.SiteID)), ...
    'placement_id', char(string(opts.PlacementID)), ...
    'placement_notes', char(string(opts.PlacementNotes)), ...
    'settings', localSettings(opts), ...
    'thresholds', opts.Thresholds, ...
    'run_table', runTable, ...
    'statistics', localBaselineStatistics(runTable), ...
    'artifact_paths', struct());

baseline = localWriteBaselineArtifacts(baseline, baselineFolder, opts.PlotFigures);

if opts.Verbose
    localPrintBaselineSummary(baseline);
end
end

function runTable = localResolveRunTable(runSources, opts)
if istable(runSources)
    runTable = localNormalizeRunTable(runSources);
    return
end

sourceList = localSourceList(runSources);
if isempty(sourceList)
    runTable = table();
    return
end

tables = cell(numel(sourceList), 1);
for idx = 1:numel(sourceList)
    source = string(sourceList{idx});
    if isfile(source) && endsWith(lower(source), ".csv")
        tables{idx} = localReadBatchSummary(source);
    else
        tables{idx} = localAnalyzeCaptureSource(source, opts);
    end
end
runTable = vertcat(tables{:});
runTable = localNormalizeRunTable(runTable);
end

function sourceList = localSourceList(runSources)
if isempty(runSources)
    sourceList = {};
elseif ischar(runSources) || isstring(runSources)
    sourceList = cellstr(string(runSources(:)));
elseif iscell(runSources)
    sourceList = runSources(:);
else
    error('runPlutoMultitoneCalibrationBaseline:badRunSources', ...
        'RunSources must be a path string, string array, cell array, or table.');
end
end

function runTable = localReadBatchSummary(source)
if ~isfile(source)
    error('runPlutoMultitoneCalibrationBaseline:batchSummaryMissing', ...
        'Batch summary CSV not found: %s', source);
end
runTable = readtable(source, 'TextType', 'string');
if ismember('Status', runTable.Properties.VariableNames)
    runTable = runTable(runTable.Status == "OK", :);
end
end

function runTable = localAnalyzeCaptureSource(source, opts)
expectedReview = reviewPlutoMultitoneCapture(source, ...
    'ToneOffsets_Hz', opts.ToneOffsets_Hz, ...
    'OutputFolder', "", ...
    'PlotFigures', false, ...
    'Verbose', false);
cpiReview = reviewPlutoMultitoneCpiIntegration(source, ...
    'ToneOffsets_Hz', opts.ToneOffsets_Hz, ...
    'OutputFolder', "", ...
    'PlotFigures', false, ...
    'Verbose', false);
detector = runPlutoMultitoneSlowTimeDetector(source, ...
    'ToneOffsets_Hz', opts.ToneOffsets_Hz, ...
    'OutputFolder', "", ...
    'PlotFigures', false, ...
    'Verbose', false);

metrics = expectedReview.multitone_metrics;
cpiSummary = cpiReview.integration.summary;
slowTime = detector.slow_time_detection;

runTable = table( ...
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
end

function runTable = localNormalizeRunTable(runTable)
metricNames = localMetricVariableNames();
for idx = 1:numel(metricNames)
    name = metricNames{idx};
    if ~ismember(name, runTable.Properties.VariableNames)
        if ismember(name, {'RunIndex'})
            runTable.(name) = (1:height(runTable)).';
        elseif ismember(name, {'CaptureFile', 'ExpectedStatus'})
            runTable.(name) = strings(height(runTable), 1);
        else
            runTable.(name) = nan(height(runTable), 1);
        end
    end
end
runTable = runTable(:, metricNames);
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

function settings = localSettings(opts)
settings = struct( ...
    'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'lo_offset_hz', double(opts.LOOffset_Hz), ...
    'capture_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'gain', double(opts.Gain(:).'), ...
    'tone_offsets_hz', double(opts.ToneOffsets_Hz(:)), ...
    'target_rms_amplitude', double(opts.TargetRMSAmplitude), ...
    'capture_duration_s', double(opts.CaptureDuration_s), ...
    'cpi_duration_s', double(opts.CpiDuration_s));
end

function statistics = localBaselineStatistics(runTable)
metricNames = localNumericMetricNames();
statistics = struct();
for idx = 1:numel(metricNames)
    name = metricNames{idx};
    values = runTable.(name);
    statistics.(name) = struct( ...
        'median', median(values, 'omitnan'), ...
        'mean', mean(values, 'omitnan'), ...
        'std', std(values, 'omitnan'), ...
        'min', min(values, [], 'omitnan'), ...
        'max', max(values, [], 'omitnan'));
end
statistics.num_runs = height(runTable);
end

function names = localNumericMetricNames()
names = { ...
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

function thresholds = localDefaultThresholds()
thresholds = struct( ...
    'expected_integrated_warn_drop_db', 2.0, ...
    'expected_integrated_fail_drop_db', 4.0, ...
    'slow_time_peak_warn_drop_db', 2.0, ...
    'slow_time_peak_fail_drop_db', 4.0, ...
    'tonewise_contrast_warn_drop_db', 2.0, ...
    'tonewise_contrast_fail_drop_db', 4.0, ...
    'coherence_warn_drop', 0.15, ...
    'coherence_fail_drop', 0.30, ...
    'coherence_warn_min', 0.55, ...
    'coherence_fail_min', 0.40, ...
    'tonewise_frequency_std_warn_increase_hz', 15.0, ...
    'tonewise_frequency_std_fail_increase_hz', 30.0);
end

function baseline = localWriteBaselineArtifacts(baseline, baselineFolder, plotFigures)
baselineMat = fullfile(baselineFolder, 'baseline.mat');
summaryCsv = fullfile(baselineFolder, 'baseline_summary.csv');
summaryTxt = fullfile(baselineFolder, 'summary.txt');
summaryPng = fullfile(baselineFolder, 'summary.png');

baselineForSave = baseline;
baselineForSave.artifact_paths = struct();
save(baselineMat, 'baselineForSave');
writetable(baseline.run_table, summaryCsv);
localWriteText(summaryTxt, localBaselineSummaryLines(baseline));

if plotFigures
    fig = localPlotBaseline(baseline);
    exportgraphics(fig, summaryPng, 'Resolution', 150);
    close(fig);
end

baseline.artifact_paths = struct( ...
    'baseline_folder', string(baselineFolder), ...
    'baseline_mat', string(baselineMat), ...
    'summary_csv', string(summaryCsv), ...
    'summary_txt', string(summaryTxt), ...
    'summary_png', string(summaryPng));
save(baselineMat, 'baseline');
end

function lines = localBaselineSummaryLines(baseline)
stats = baseline.statistics;
lines = [
    "PLUTO MULTITONE CALIBRATION BASELINE"
    "Baseline ID: " + string(baseline.baseline_id)
    "Runs: " + stats.num_runs
    "REF expected integrated median: " + compose("%.2f", stats.REF_ExpectedIntegrated_dB.median) + " dB"
    "SURV expected integrated median: " + compose("%.2f", stats.SURV_ExpectedIntegrated_dB.median) + " dB"
    "REF slow-time peak median: " + compose("%.2f", stats.REF_SlowTimePeak_dB.median) + " dB"
    "SURV slow-time peak median: " + compose("%.2f", stats.SURV_SlowTimePeak_dB.median) + " dB"
    "Median cross-channel coherence: " + compose("%.3f", stats.MedianCrossChannelCoherence.median)
    "Tonewise detector contrast median: " + compose("%.2f", stats.TonewiseDetectorContrast_dB.median) + " dB"
    ];
end

function localPrintBaselineSummary(baseline)
disp(localBaselineSummaryLines(baseline));
fprintf('[runPlutoMultitoneCalibrationBaseline] Baseline folder: %s\n', ...
    baseline.artifact_paths.baseline_folder);
end

function localWriteText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('runPlutoMultitoneCalibrationBaseline:textOpenFailed', ...
        'Could not open %s for writing.', path);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', lines);
clear cleanupFile
end

function fig = localPlotBaseline(baseline)
runTable = baseline.run_table;
fig = figure('Name', 'Pluto multitone calibration baseline', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto multitone calibration baseline');

nexttile(tl, 1);
plot(runTable.RunIndex, runTable.REF_ExpectedIntegrated_dB, '-o');
hold on;
plot(runTable.RunIndex, runTable.SURV_ExpectedIntegrated_dB, '-o');
grid on;
xlabel('Run index');
ylabel('Expected-bin integrated margin (dB)');
title('Comb evidence');
legend({'REF', 'SURV'}, 'Location', 'best');

nexttile(tl, 2);
plot(runTable.RunIndex, runTable.REF_SlowTimePeak_dB, '-o');
hold on;
plot(runTable.RunIndex, runTable.SURV_SlowTimePeak_dB, '-o');
grid on;
xlabel('Run index');
ylabel('Slow-time peak margin (dB)');
title('CPI integration');
legend({'REF', 'SURV'}, 'Location', 'best');

nexttile(tl, 3);
plot(runTable.RunIndex, runTable.MedianCrossChannelCoherence, '-o');
ylim([0, 1]);
grid on;
xlabel('Run index');
ylabel('Coherence');
title('REF/SURV coherence');

nexttile(tl, 4);
plot(runTable.RunIndex, runTable.TonewiseDetectorContrast_dB, '-o');
grid on;
xlabel('Run index');
ylabel('Tonewise contrast (dB)');
title('Detector contrast');
end
