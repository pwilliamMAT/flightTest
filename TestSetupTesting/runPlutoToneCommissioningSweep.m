function sweep = runPlutoToneCommissioningSweep(varargin)
%RUNPLUTOTONECOMMISSIONINGSWEEP Sweep Pluto tone settings to find a baseline-worthy commissioning candidate.
%
% Plain-language goal:
%   Once the Pluto location and antenna path are physically fixed, the next
%   question is which injected tone settings give the most repeatable and
%   interpretable Pluto-to-USRP result. This runner sweeps a short list of
%   tone offsets and amplitudes, repeats each configuration several times,
%   writes each run as a baseline-compatible artifact, and ranks the
%   resulting configurations so the best one can be taken forward into
%   baseline commissioning.
%
% Syntax
%   sweep = runPlutoToneCommissioningSweep
%   sweep = runPlutoToneCommissioningSweep('RunsPerConfiguration', 3, 'Verbose', true)
%
% Suggested first-pass sweep for the current Phase 1 work:
%   - Tone offsets: 250 kHz and 1.5 MHz
%   - Tone amplitudes: 0.50, 0.65, 0.80, 0.90
%   - Same fixed physical setup for every run
%
% See also: runPlutoToneStage6Smoke, helperPlutoToneDefaultThresholds,
%           helperPlutoToneBuildStandaloneResultFromSmoke,
%           commissionPlutoToneBaseline.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SweepRoot', fullfile(pwd, 'TestSetupTesting', 'plutoCommissioningSweeps'), @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionPrefix', "pluto_tone_commissioning", @(x) ischar(x) || isstring(x));
addParameter(p, 'SiteID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementNotes', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'ToneOffsets_Hz', [250e3, 1.5e6], @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'ToneAmplitudes', [0.50, 0.65, 0.80, 0.90], @(x) isnumeric(x) && isvector(x) && ~isempty(x) && all(x > 0) && all(x <= 1));
addParameter(p, 'RunsPerConfiguration', 2, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x, 1) == 0);
addParameter(p, 'CaptureDuration_s', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Thresholds', struct(), @(x) isempty(x) || isstruct(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

test_root = fileparts(mfilename('fullpath'));
project_root = fileparts(test_root);

capture_root = string(opts.CaptureRoot);
if strlength(capture_root) == 0
    capture_root = fullfile(project_root, 'captures', 'plutoCommissioning');
end

thresholds = localResolveThresholds(opts.Thresholds);
tone_offsets_hz = unique(double(opts.ToneOffsets_Hz(:)), 'stable');
tone_amplitudes = unique(double(opts.ToneAmplitudes(:)), 'stable');

localValidateToneOffsets(tone_offsets_hz, double(opts.SampleRate_Hz));

sweep_id = char(string(opts.SessionPrefix) + "_" + string(datetime( ...
    'now', ...
    'TimeZone', 'UTC', ...
    'Format', 'yyyyMMdd''T''HHmmss')));
sweep_folder = fullfile(char(string(opts.SweepRoot)), sweep_id);
run_folder_root = fullfile(sweep_folder, 'runs');

try
    if exist(run_folder_root, 'dir') ~= 7
        mkdir(run_folder_root);
    end
catch me_dir
    error('runPlutoToneCommissioningSweep:mkdirFailed', ...
        'Could not create sweep folder %s: %s', run_folder_root, me_dir.message);
end

config_table = localBuildConfigurationTable(tone_offsets_hz, tone_amplitudes, double(opts.RunsPerConfiguration));
run_rows = repmat(localEmptyRunRow(), height(config_table), 1);
run_results = cell(height(config_table), 1);

if opts.Verbose
    fprintf('[runPlutoToneCommissioningSweep] Sweep ID ......... %s\n', sweep_id);
    fprintf('[runPlutoToneCommissioningSweep] Sweep root ....... %s\n', sweep_folder);
    fprintf('[runPlutoToneCommissioningSweep] Capture root ..... %s\n', char(capture_root));
    fprintf('[runPlutoToneCommissioningSweep] Runs/config ...... %d\n', double(opts.RunsPerConfiguration));
    fprintf('[runPlutoToneCommissioningSweep] Tone offsets [Hz]  %s\n', mat2str(tone_offsets_hz(:).'));
    fprintf('[runPlutoToneCommissioningSweep] Tone amplitudes ... %s\n', mat2str(tone_amplitudes(:).'));
end

for idx = 1:height(config_table)
    config_row = config_table(idx, :);
    [run_rows(idx), run_results{idx}] = localRunOneConfiguration( ...
        config_row, ...
        run_folder_root, ...
        capture_root, ...
        thresholds, ...
        opts, ...
        sweep_id);
end

run_table = struct2table(run_rows);
configuration_summary = localBuildConfigurationSummary(run_table);
recommended_configuration = localRecommendedConfiguration(configuration_summary);
commissioning_notes = localBuildCommissioningNotes(configuration_summary, recommended_configuration, opts);
summary_text = localBuildSweepSummaryText(sweep_id, configuration_summary, recommended_configuration, commissioning_notes, opts);

artifact_paths = localWriteSweepArtifacts(sweep_folder, sweep_id, run_table, configuration_summary, summary_text);

sweep = struct( ...
    'schema_version', 1, ...
    'sweep_id', sweep_id, ...
    'created_utc', char(string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''))), ...
    'site_id', char(string(opts.SiteID)), ...
    'placement_id', char(string(opts.PlacementID)), ...
    'placement_notes', char(string(opts.PlacementNotes)), ...
    'settings', struct( ...
        'sweep_root', char(string(opts.SweepRoot)), ...
        'capture_root', char(capture_root), ...
        'radio_name', char(string(opts.RadioName)), ...
        'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
        'sample_rate_hz', double(opts.SampleRate_Hz), ...
        'lo_offset_hz', double(opts.LOOffset_Hz), ...
        'gain', double(opts.Gain(:).'), ...
        'tone_offsets_hz', tone_offsets_hz(:).', ...
        'tone_amplitudes', tone_amplitudes(:).', ...
        'runs_per_configuration', double(opts.RunsPerConfiguration), ...
        'capture_duration_s', double(opts.CaptureDuration_s), ...
        'thresholds', thresholds), ...
    'run_results', {run_results}, ...
    'run_table', run_table, ...
    'configuration_summary', configuration_summary, ...
    'recommended_configuration', recommended_configuration, ...
    'commissioning_notes', commissioning_notes, ...
    'artifact_paths', artifact_paths);

try
    save(char(artifact_paths.sweep_mat), 'sweep', '-v7.3');
catch me_save
    error('runPlutoToneCommissioningSweep:matSaveFailed', ...
        'Could not save sweep MAT file %s: %s', artifact_paths.sweep_mat, me_save.message);
end

if opts.Verbose
    disp(configuration_summary);
    disp(string(commissioning_notes));
    fprintf('%s\n', summary_text);
end
end

function [run_row, promoted_result] = localRunOneConfiguration(config_row, run_folder_root, capture_root, thresholds, opts, sweep_id)
session_id = localSessionID(string(opts.SessionPrefix), sweep_id, config_row.ConfigurationLabel, config_row.RepeatIndex);
run_folder = fullfile(run_folder_root, char(session_id));

if opts.Verbose
    fprintf(['[runPlutoToneCommissioningSweep] Run %d/%d | %s | ' ...
        'offset %.3f MHz | amp %.2f\n'], ...
        config_row.RunIndex, ...
        config_row.NumConfigurations, ...
        char(session_id), ...
        config_row.ToneOffset_Hz / 1e6, ...
        config_row.ToneAmplitude);
end

try
    smoke_result = runPlutoToneStage6Smoke( ...
        'SessionID', session_id, ...
        'CaptureRoot', char(capture_root), ...
        'CaptureFileBase', session_id, ...
        'RadioName', string(opts.RadioName), ...
        'CenterFrequency_Hz', double(opts.CenterFrequency_Hz), ...
        'SampleRate_Hz', double(opts.SampleRate_Hz), ...
        'LOOffset_Hz', double(opts.LOOffset_Hz), ...
        'Gain', double(opts.Gain(:).'), ...
        'ToneOffset_Hz', double(config_row.ToneOffset_Hz), ...
        'ToneAmplitude', double(config_row.ToneAmplitude), ...
        'CaptureDuration_s', double(opts.CaptureDuration_s), ...
        'Thresholds', thresholds, ...
        'Verbose', opts.Verbose);

    promoted_result = helperPlutoToneBuildStandaloneResultFromSmoke( ...
        smoke_result, ...
        'RunID', session_id, ...
        'PlotFigures', false, ...
        'Verbose', false);

    [artifact_paths, promoted_result] = helperPlutoToneWriteArtifacts( ...
        promoted_result, ...
        'RunFolder', run_folder, ...
        'CopyCaptureFile', false, ...
        'FigureVisibility', 'off', ...
        'Verbose', opts.Verbose);
    promoted_result.artifact_paths = artifact_paths;

    run_row = localBuildRunRow(config_row, promoted_result, "COMPLETED", "");
catch me
    run_row = localBuildErrorRunRow(config_row, run_folder, me);
    promoted_result = struct( ...
        'run_id', char(session_id), ...
        'status', 'ERROR', ...
        'error_report', string(getReport(me, 'extended', 'hyperlinks', 'off')));
end
end

function config_table = localBuildConfigurationTable(tone_offsets_hz, tone_amplitudes, runs_per_configuration)
n_configs = numel(tone_offsets_hz) * numel(tone_amplitudes) * runs_per_configuration;
rows = repmat(struct( ...
    'RunIndex', 0, ...
    'NumConfigurations', 0, ...
    'ConfigurationLabel', "", ...
    'ToneOffset_Hz', NaN, ...
    'ToneAmplitude', NaN, ...
    'RepeatIndex', 0), n_configs, 1);

row_idx = 1;
for tone_idx = 1:numel(tone_offsets_hz)
    for amp_idx = 1:numel(tone_amplitudes)
        configuration_label = localConfigurationLabel(tone_offsets_hz(tone_idx), tone_amplitudes(amp_idx));
        for repeat_idx = 1:runs_per_configuration
            rows(row_idx).RunIndex = row_idx;
            rows(row_idx).NumConfigurations = n_configs;
            rows(row_idx).ConfigurationLabel = configuration_label;
            rows(row_idx).ToneOffset_Hz = tone_offsets_hz(tone_idx);
            rows(row_idx).ToneAmplitude = tone_amplitudes(amp_idx);
            rows(row_idx).RepeatIndex = repeat_idx;
            row_idx = row_idx + 1;
        end
    end
end

config_table = struct2table(rows);
end

function run_row = localEmptyRunRow()
run_row = struct( ...
    'ConfigurationLabel', "", ...
    'ToneOffset_Hz', NaN, ...
    'ToneAmplitude', NaN, ...
    'RepeatIndex', NaN, ...
    'ExecutionStatus', "", ...
    'ResultStatus', "", ...
    'RunID', "", ...
    'RunFolder', "", ...
    'ResultMat', "", ...
    'RefToneFound', false, ...
    'SurvToneFound', false, ...
    'BothToneFound', false, ...
    'RefDetectMargin_dB', NaN, ...
    'SurvDetectMargin_dB', NaN, ...
    'MinDetectMargin_dB', NaN, ...
    'RefFreqErr_Hz', NaN, ...
    'SurvFreqErr_Hz', NaN, ...
    'ChannelFreqDelta_Hz', NaN, ...
    'XcorrPeak_dB', NaN, ...
    'RefLevel_dBFS', NaN, ...
    'SurvLevel_dBFS', NaN, ...
    'MaxLevel_dBFS', NaN, ...
    'FailCodes', "", ...
    'WarnCodes', "", ...
    'ErrorSummary', "");
end

function run_row = localBuildRunRow(config_row, result, execution_status, error_summary)
run_row = localEmptyRunRow();
run_row.ConfigurationLabel = string(config_row.ConfigurationLabel);
run_row.ToneOffset_Hz = double(config_row.ToneOffset_Hz);
run_row.ToneAmplitude = double(config_row.ToneAmplitude);
run_row.RepeatIndex = double(config_row.RepeatIndex);
run_row.ExecutionStatus = string(execution_status);
run_row.ResultStatus = string(localFieldOrDefault(result, {'status'}, ""));
run_row.RunID = string(localFieldOrDefault(result, {'run_id'}, ""));
run_row.RunFolder = string(localFieldOrDefault(result, {'artifact_paths', 'run_folder'}, ""));
run_row.ResultMat = string(localFieldOrDefault(result, {'artifact_paths', 'result_mat'}, ""));
run_row.RefToneFound = logical(localFieldOrDefault(result, {'reference_metrics', 'tone_found'}, false));
run_row.SurvToneFound = logical(localFieldOrDefault(result, {'surveillance_metrics', 'tone_found'}, false));
run_row.BothToneFound = run_row.RefToneFound && run_row.SurvToneFound;
run_row.RefDetectMargin_dB = double(localFieldOrDefault(result, {'reference_metrics', 'detect_margin_db'}, NaN));
run_row.SurvDetectMargin_dB = double(localFieldOrDefault(result, {'surveillance_metrics', 'detect_margin_db'}, NaN));
run_row.MinDetectMargin_dB = min([run_row.RefDetectMargin_dB, run_row.SurvDetectMargin_dB], [], 'omitnan');
run_row.RefFreqErr_Hz = double(localFieldOrDefault(result, {'reference_metrics', 'frequency_error_hz'}, NaN));
run_row.SurvFreqErr_Hz = double(localFieldOrDefault(result, {'surveillance_metrics', 'frequency_error_hz'}, NaN));
run_row.ChannelFreqDelta_Hz = double(localFieldOrDefault(result, {'joint_metrics', 'channel_frequency_delta_hz'}, NaN));
run_row.XcorrPeak_dB = double(localFieldOrDefault(result, {'joint_metrics', 'xcorr_peak_db'}, NaN));
run_row.RefLevel_dBFS = double(localFieldOrDefault(result, {'reference_metrics', 'level_dbfs'}, NaN));
run_row.SurvLevel_dBFS = double(localFieldOrDefault(result, {'surveillance_metrics', 'level_dbfs'}, NaN));
run_row.MaxLevel_dBFS = max([run_row.RefLevel_dBFS, run_row.SurvLevel_dBFS], [], 'omitnan');
run_row.FailCodes = string(strjoin(localCodes(result, 'fail_codes'), ", "));
run_row.WarnCodes = string(strjoin(localCodes(result, 'warn_codes'), ", "));
run_row.ErrorSummary = string(error_summary);
end

function run_row = localBuildErrorRunRow(config_row, run_folder, me)
error_report = string(getReport(me, 'basic', 'hyperlinks', 'off'));
run_row = localEmptyRunRow();
run_row.ConfigurationLabel = string(config_row.ConfigurationLabel);
run_row.ToneOffset_Hz = double(config_row.ToneOffset_Hz);
run_row.ToneAmplitude = double(config_row.ToneAmplitude);
run_row.RepeatIndex = double(config_row.RepeatIndex);
run_row.ExecutionStatus = "ERROR";
run_row.ResultStatus = "ERROR";
run_row.RunFolder = string(run_folder);
run_row.ErrorSummary = error_report;
end

function configuration_summary = localBuildConfigurationSummary(run_table)
configuration_labels = unique(run_table.ConfigurationLabel, 'stable');
rows = repmat(struct( ...
    'ConfigurationLabel', "", ...
    'ToneOffset_Hz', NaN, ...
    'ToneAmplitude', NaN, ...
    'NumRequested', 0, ...
    'NumCompleted', 0, ...
    'NumErrors', 0, ...
    'NumPass', 0, ...
    'NumWarn', 0, ...
    'NumFail', 0, ...
    'NumBothToneFound', 0, ...
    'MedianMinDetectMargin_dB', NaN, ...
    'MedianRefDetectMargin_dB', NaN, ...
    'MedianSurvDetectMargin_dB', NaN, ...
    'MedianAbsRefFreqErr_Hz', NaN, ...
    'MedianAbsSurvFreqErr_Hz', NaN, ...
    'MedianChannelFreqDelta_Hz', NaN, ...
    'StdChannelFreqDelta_Hz', NaN, ...
    'MedianXcorrPeak_dB', NaN, ...
    'MaxLevel_dBFS', NaN, ...
    'CandidateTier', "", ...
    'RecommendedRank', 0, ...
    'RunFolders', ""), numel(configuration_labels), 1);

for idx = 1:numel(configuration_labels)
    label = configuration_labels(idx);
    subset = run_table(run_table.ConfigurationLabel == label, :);
    completed = subset.ExecutionStatus == "COMPLETED";
    completed_subset = subset(completed, :);

    rows(idx).ConfigurationLabel = label;
    rows(idx).ToneOffset_Hz = subset.ToneOffset_Hz(1);
    rows(idx).ToneAmplitude = subset.ToneAmplitude(1);
    rows(idx).NumRequested = height(subset);
    rows(idx).NumCompleted = nnz(completed);
    rows(idx).NumErrors = nnz(subset.ExecutionStatus == "ERROR");
    rows(idx).NumPass = nnz(completed_subset.ResultStatus == "PASS");
    rows(idx).NumWarn = nnz(completed_subset.ResultStatus == "WARN");
    rows(idx).NumFail = nnz(completed_subset.ResultStatus == "FAIL");
    rows(idx).NumBothToneFound = nnz(completed_subset.BothToneFound);
    rows(idx).MedianMinDetectMargin_dB = localMedianScalar(completed_subset.MinDetectMargin_dB);
    rows(idx).MedianRefDetectMargin_dB = localMedianScalar(completed_subset.RefDetectMargin_dB);
    rows(idx).MedianSurvDetectMargin_dB = localMedianScalar(completed_subset.SurvDetectMargin_dB);
    rows(idx).MedianAbsRefFreqErr_Hz = localMedianScalar(abs(completed_subset.RefFreqErr_Hz));
    rows(idx).MedianAbsSurvFreqErr_Hz = localMedianScalar(abs(completed_subset.SurvFreqErr_Hz));
    rows(idx).MedianChannelFreqDelta_Hz = localMedianScalar(completed_subset.ChannelFreqDelta_Hz);
    rows(idx).StdChannelFreqDelta_Hz = localStdScalar(completed_subset.ChannelFreqDelta_Hz);
    rows(idx).MedianXcorrPeak_dB = localMedianScalar(completed_subset.XcorrPeak_dB);
    rows(idx).MaxLevel_dBFS = localMaxScalar(completed_subset.MaxLevel_dBFS);
    rows(idx).CandidateTier = localCandidateTier(rows(idx));
    rows(idx).RunFolders = strjoin(string(completed_subset.RunFolder), "; ");
end

configuration_summary = struct2table(rows);
configuration_summary = sortrows(configuration_summary, ...
    ["NumErrors", "NumBothToneFound", "MedianChannelFreqDelta_Hz", "MedianMinDetectMargin_dB", "StdChannelFreqDelta_Hz", "MaxLevel_dBFS"], ...
    ["ascend", "descend", "ascend", "descend", "ascend", "ascend"]);
configuration_summary.RecommendedRank = (1:height(configuration_summary)).';
end

function tier = localCandidateTier(row)
if row.NumCompleted == 0 || row.NumBothToneFound == 0
    tier = "REJECT";
    return
end

if row.NumErrors == 0 && ...
        row.NumCompleted == row.NumRequested && ...
        row.NumBothToneFound == row.NumCompleted && ...
        isfinite(row.MedianMinDetectMargin_dB) && row.MedianMinDetectMargin_dB >= 6 && ...
        isfinite(row.MedianChannelFreqDelta_Hz) && row.MedianChannelFreqDelta_Hz <= 2e3 && ...
        isfinite(row.MaxLevel_dBFS) && row.MaxLevel_dBFS <= -6
    tier = "STRONG";
elseif row.NumErrors == 0 && ...
        row.NumBothToneFound == row.NumCompleted && ...
        isfinite(row.MedianMinDetectMargin_dB) && row.MedianMinDetectMargin_dB > 0 && ...
        isfinite(row.MedianChannelFreqDelta_Hz) && row.MedianChannelFreqDelta_Hz <= 1e4
    tier = "FOLLOW_UP";
else
    tier = "WEAK";
end
end

function recommended_configuration = localRecommendedConfiguration(configuration_summary)
if height(configuration_summary) == 0
    recommended_configuration = table();
else
    recommended_configuration = configuration_summary(1, :);
end
end

function notes = localBuildCommissioningNotes(configuration_summary, recommended_configuration, opts)
notes = strings(0, 1);
notes(end + 1) = "Commissioning sweep notes:";
notes(end + 1) = "Use one fixed physical Pluto placement for the entire sweep. Do not move cables, antenna, or Pluto between runs.";
notes(end + 1) = "This sweep is for candidate selection. Commission the baseline only after reviewing the top-ranked configuration.";
notes(end + 1) = "Tone amplitudes above 0.8 are allowed by the current runner up to 1.0, but this first sweep stops at 0.9 to avoid jumping straight to the digital ceiling.";
if height(configuration_summary) == 0
    notes(end + 1) = "No completed configurations were available.";
    return
end

top = recommended_configuration;
notes(end + 1) = sprintf(['Top-ranked candidate: offset %.3f MHz | amp %.2f | ' ...
    'median delta %.1f Hz | median min detect %.1f dB | tier %s'], ...
    double(top.ToneOffset_Hz) / 1e6, ...
    double(top.ToneAmplitude), ...
    double(top.MedianChannelFreqDelta_Hz), ...
    double(top.MedianMinDetectMargin_dB), ...
    char(string(top.CandidateTier)));

if string(top.CandidateTier) == "STRONG"
    notes(end + 1) = "This configuration looks strong enough to justify a dedicated repeated commissioning series next.";
else
    notes(end + 1) = "This sweep still needs human review. Even the top-ranked configuration is not automatically baseline-worthy.";
end

notes(end + 1) = sprintf(['If the top-ranked candidate remains preferred, rerun that one fixed ' ...
    'configuration for at least %d identical repeats and feed those saved run folders into commissionPlutoToneBaseline.'], ...
    max(5, double(opts.RunsPerConfiguration)));
end

function summary_text = localBuildSweepSummaryText(sweep_id, configuration_summary, recommended_configuration, commissioning_notes, opts)
lines = strings(0, 1);
lines(end + 1) = "PLUTO COMMISSIONING SWEEP: " + string(sweep_id);
lines(end + 1) = "Site ID: " + string(opts.SiteID);
lines(end + 1) = "Placement ID: " + string(opts.PlacementID);
lines(end + 1) = "Placement notes: " + string(opts.PlacementNotes);
lines(end + 1) = sprintf('Center %.3f MHz | Sample rate %.3f MSps | LO %.3f MHz | Gain %s', ...
    double(opts.CenterFrequency_Hz) / 1e6, ...
    double(opts.SampleRate_Hz) / 1e6, ...
    double(opts.LOOffset_Hz) / 1e6, ...
    mat2str(double(opts.Gain(:).')));

if height(configuration_summary) > 0
    top = recommended_configuration;
    lines(end + 1) = sprintf(['Recommended candidate: offset %.3f MHz | amp %.2f | ' ...
        'median delta %.1f Hz | median min detect %.1f dB | tier %s'], ...
        double(top.ToneOffset_Hz) / 1e6, ...
        double(top.ToneAmplitude), ...
        double(top.MedianChannelFreqDelta_Hz), ...
        double(top.MedianMinDetectMargin_dB), ...
        char(string(top.CandidateTier)));
    lines(end + 1) = "Top candidate run folders:";
    top_run_folders = split(string(top.RunFolders), "; ");
    top_run_folders = top_run_folders(strlength(top_run_folders) > 0);
    indented_run_folders = "  " + top_run_folders(:);
    lines = [lines(:); indented_run_folders(:)];
else
    lines(end + 1) = "No completed configurations were available.";
end

lines = [lines(:); commissioning_notes(:)];
summary_text = char(strjoin(lines, newline));
end

function artifact_paths = localWriteSweepArtifacts(sweep_folder, sweep_id, run_table, configuration_summary, summary_text)
artifact_paths = struct( ...
    'sweep_folder', string(sweep_folder), ...
    'sweep_mat', string(fullfile(sweep_folder, [sweep_id, '.mat'])), ...
    'run_table_csv', string(fullfile(sweep_folder, 'run_table.csv')), ...
    'configuration_summary_csv', string(fullfile(sweep_folder, 'configuration_summary.csv')), ...
    'summary_txt', string(fullfile(sweep_folder, 'summary.txt')));

localWriteTextFile(char(artifact_paths.summary_txt), summary_text, 'runPlutoToneCommissioningSweep:summaryWriteFailed');
localWriteTableCSV(run_table, char(artifact_paths.run_table_csv), 'runPlutoToneCommissioningSweep:runTableWriteFailed');
localWriteTableCSV(configuration_summary, char(artifact_paths.configuration_summary_csv), 'runPlutoToneCommissioningSweep:configTableWriteFailed');
end

function thresholds = localResolveThresholds(thresholds_in)
if isempty(thresholds_in) || (isstruct(thresholds_in) && isempty(fieldnames(thresholds_in)))
    thresholds = helperPlutoToneDefaultThresholds();
else
    thresholds = helperPlutoToneNormalizeThresholds(thresholds_in);
end
end

function localValidateToneOffsets(tone_offsets_hz, sample_rate_hz)
nyquist_hz = sample_rate_hz / 2;
if any(abs(tone_offsets_hz) >= nyquist_hz)
    error('runPlutoToneCommissioningSweep:toneOffsetOutOfRange', ...
        'ToneOffsets_Hz must stay strictly within the Nyquist span %.3f MHz.', nyquist_hz / 1e6);
end
end

function label = localConfigurationLabel(tone_offset_hz, tone_amplitude)
label = "offset_" + localNumberToken(tone_offset_hz / 1e3, 0) + "kHz_amp_" + localNumberToken(tone_amplitude, 2);
end

function session_id = localSessionID(~, sweep_id, configuration_label, repeat_index)
session_id = string(sweep_id) + "_" + configuration_label + "_r" + pad(string(repeat_index), 2, 'left', '0');
session_id = replace(session_id, [".", "-", " "], ["p", "m", "_"]);
end

function token = localNumberToken(value, n_decimals)
fmt = sprintf('%%0.%df', n_decimals);
token = string(sprintf(fmt, value));
token = replace(token, '.', 'p');
end

function value = localFieldOrDefault(source_struct, field_path, default_value)
value = default_value;
current_value = source_struct;
for idx = 1:numel(field_path)
    field_name = field_path{idx};
    if ~isstruct(current_value) || ~isfield(current_value, field_name)
        return
    end
    current_value = current_value.(field_name);
end
value = current_value;
end

function codes = localCodes(result, field_name)
codes = cell(0, 1);
if isstruct(result) && isfield(result, field_name) && ~isempty(result.(field_name))
    normalized_codes = localNormalizeCodes(result.(field_name));
    codes = cellstr(normalized_codes);
end
end

function codes = localNormalizeCodes(raw_codes)
if isempty(raw_codes)
    codes = strings(0, 1);
    return
end

if isstring(raw_codes)
    codes = raw_codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

if ischar(raw_codes)
    codes = string(cellstr(raw_codes));
    codes = codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

if iscell(raw_codes)
    nested_codes = cell(numel(raw_codes), 1);
    for idx = 1:numel(raw_codes)
        nested_codes{idx} = localNormalizeCodes(raw_codes{idx});
    end
    if isempty(nested_codes)
        codes = strings(0, 1);
    else
        codes = vertcat(nested_codes{:});
    end
    codes = codes(:);
    codes = codes(strlength(codes) > 0);
    return
end

try
    codes = string(raw_codes(:));
catch
    codes = strings(0, 1);
end

codes = codes(:);
codes = codes(strlength(codes) > 0);
end

function localWriteTableCSV(tbl, output_path, error_id)
try
    writetable(tbl, output_path);
catch me_write
    error(error_id, 'Could not write %s: %s', output_path, me_write.message);
end
end

function localWriteTextFile(output_path, content, error_id)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('runPlutoToneCommissioningSweep:fileOpenFailed', ...
            'Could not open %s for writing.', output_path);
    end
    fprintf(file_id, '%s', content);
    fclose(file_id);
catch me_write
    if file_id ~= -1
        try
            fclose(file_id);
        catch
        end
    end
    error(error_id, 'Could not write %s: %s', output_path, me_write.message);
end
end

function value = localMedianScalar(values)
values = double(values(:));
if isempty(values)
    value = NaN;
else
    value = median(values, 'omitnan');
end
end

function value = localStdScalar(values)
values = double(values(:));
if isempty(values)
    value = NaN;
else
    value = std(values, 0, 'omitnan');
end
end

function value = localMaxScalar(values)
values = double(values(:));
if isempty(values)
    value = NaN;
else
    values = values(isfinite(values));
    if isempty(values)
        value = NaN;
    else
        value = max(values);
    end
end
end
