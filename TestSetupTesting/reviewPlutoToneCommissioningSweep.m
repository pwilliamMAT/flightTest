function review = reviewPlutoToneCommissioningSweep(sweep_folder, varargin)
%REVIEWPLUTOTONECOMMISSIONINGSWEEP Rebuild the commissioning-sweep summary from saved run artifacts.
%
% Plain-language goal:
%   If the commissioning sweep finishes its hardware runs but fails while
%   assembling the final summary, the saved per-run artifacts should still
%   be enough to recover the ranked configuration table without rerunning
%   hardware. This helper reloads the saved run folders, rebuilds the run
%   and configuration summaries, and rewrites the top-level sweep summary
%   files in place.
%
% Syntax
%   review = reviewPlutoToneCommissioningSweep(sweepFolder)
%   review = reviewPlutoToneCommissioningSweep(sweepFolder, 'Verbose', true)

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'sweep_folder', @(x) ischar(x) || isstring(x));
addParameter(p, 'SiteID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementNotes', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, sweep_folder, varargin{:});
opts = p.Results;

sweep_folder = char(string(sweep_folder));
if exist(sweep_folder, 'dir') ~= 7
    error('reviewPlutoToneCommissioningSweep:missingSweepFolder', ...
        'Sweep folder %s does not exist.', sweep_folder);
end

run_artifacts = dir(fullfile(sweep_folder, 'runs', '*', 'result.mat'));
if isempty(run_artifacts)
    error('reviewPlutoToneCommissioningSweep:noRunArtifacts', ...
        'Sweep folder %s does not contain any runs/*/result.mat artifacts.', sweep_folder);
end

n_runs = numel(run_artifacts);
run_results = cell(n_runs, 1);
run_rows = repmat(localEmptyRunRow(), n_runs, 1);

for idx = 1:n_runs
    mat_path = fullfile(run_artifacts(idx).folder, run_artifacts(idx).name);
    result = helperPlutoToneLoadResult(mat_path);
    run_results{idx} = result;
    run_rows(idx) = localBuildRunRow(result, "RECOVERED");
end

run_table = struct2table(run_rows);
run_table = sortrows(run_table, ["ToneOffset_Hz", "ToneAmplitude", "RepeatIndex"], ["ascend", "ascend", "ascend"]);
configuration_summary = localBuildConfigurationSummary(run_table);
recommended_configuration = localRecommendedConfiguration(configuration_summary);
sweep_id = string(localSweepIDFromFolder(sweep_folder));
commissioning_notes = localBuildCommissioningNotes(configuration_summary, recommended_configuration);
summary_text = localBuildSweepSummaryText(sweep_id, configuration_summary, recommended_configuration, commissioning_notes, opts);
artifact_paths = localWriteReviewArtifacts(sweep_folder, run_table, configuration_summary, summary_text);

review = struct( ...
    'schema_version', 1, ...
    'sweep_id', char(sweep_id), ...
    'site_id', char(string(opts.SiteID)), ...
    'placement_id', char(string(opts.PlacementID)), ...
    'placement_notes', char(string(opts.PlacementNotes)), ...
    'run_results', {run_results}, ...
    'run_table', run_table, ...
    'configuration_summary', configuration_summary, ...
    'recommended_configuration', recommended_configuration, ...
    'commissioning_notes', commissioning_notes, ...
    'summary_text', summary_text, ...
    'artifact_paths', artifact_paths);

review_mat_path = fullfile(sweep_folder, 'sweep_review.mat');
try
    save(review_mat_path, 'review', '-v7.3');
catch me_save
    error('reviewPlutoToneCommissioningSweep:matSaveFailed', ...
        'Could not save review MAT file %s: %s', review_mat_path, me_save.message);
end

if opts.Verbose
    disp(configuration_summary);
    disp(string(commissioning_notes));
    fprintf('%s\n', summary_text);
end
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

function run_row = localBuildRunRow(result, execution_status)
run_row = localEmptyRunRow();
settings = localFieldOrDefault(result, {'settings'}, struct());

run_row.ConfigurationLabel = localConfigurationLabel( ...
    localFieldOrDefault(settings, {'tone_offset_hz'}, NaN), ...
    localFieldOrDefault(settings, {'tone_amplitude'}, NaN));
run_row.ToneOffset_Hz = double(localFieldOrDefault(settings, {'tone_offset_hz'}, NaN));
run_row.ToneAmplitude = double(localFieldOrDefault(settings, {'tone_amplitude'}, NaN));
run_row.RepeatIndex = localRepeatIndexFromRunID(string(localFieldOrDefault(result, {'run_id'}, "")));
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
run_row.MaxLevel_dBFS = localMaxScalar([run_row.RefLevel_dBFS, run_row.SurvLevel_dBFS]);
run_row.FailCodes = string(strjoin(localCodes(result, 'fail_codes'), ", "));
run_row.WarnCodes = string(strjoin(localCodes(result, 'warn_codes'), ", "));
run_row.ErrorSummary = "";
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

    rows(idx).ConfigurationLabel = label;
    rows(idx).ToneOffset_Hz = subset.ToneOffset_Hz(1);
    rows(idx).ToneAmplitude = subset.ToneAmplitude(1);
    rows(idx).NumRequested = height(subset);
    rows(idx).NumCompleted = height(subset);
    rows(idx).NumErrors = 0;
    rows(idx).NumPass = nnz(subset.ResultStatus == "PASS");
    rows(idx).NumWarn = nnz(subset.ResultStatus == "WARN");
    rows(idx).NumFail = nnz(subset.ResultStatus == "FAIL");
    rows(idx).NumBothToneFound = nnz(subset.BothToneFound);
    rows(idx).MedianMinDetectMargin_dB = localMedianScalar(subset.MinDetectMargin_dB);
    rows(idx).MedianRefDetectMargin_dB = localMedianScalar(subset.RefDetectMargin_dB);
    rows(idx).MedianSurvDetectMargin_dB = localMedianScalar(subset.SurvDetectMargin_dB);
    rows(idx).MedianAbsRefFreqErr_Hz = localMedianScalar(abs(subset.RefFreqErr_Hz));
    rows(idx).MedianAbsSurvFreqErr_Hz = localMedianScalar(abs(subset.SurvFreqErr_Hz));
    rows(idx).MedianChannelFreqDelta_Hz = localMedianScalar(subset.ChannelFreqDelta_Hz);
    rows(idx).StdChannelFreqDelta_Hz = localStdScalar(subset.ChannelFreqDelta_Hz);
    rows(idx).MedianXcorrPeak_dB = localMedianScalar(subset.XcorrPeak_dB);
    rows(idx).MaxLevel_dBFS = localMaxScalar(subset.MaxLevel_dBFS);
    rows(idx).CandidateTier = localCandidateTier(rows(idx));
    rows(idx).RunFolders = strjoin(string(subset.RunFolder), "; ");
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

function notes = localBuildCommissioningNotes(configuration_summary, recommended_configuration)
notes = strings(0, 1);
notes(end + 1) = "Recovered commissioning sweep notes:";
notes(end + 1) = "This review was rebuilt from saved per-run artifacts, so no new hardware captures were required.";
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
    notes(end + 1) = "Even the top-ranked recovered configuration still needs human review before baseline commissioning.";
end
end

function summary_text = localBuildSweepSummaryText(sweep_id, configuration_summary, recommended_configuration, commissioning_notes, opts)
lines = strings(0, 1);
lines(end + 1) = "PLUTO COMMISSIONING SWEEP REVIEW: " + string(sweep_id);
lines(end + 1) = "Site ID: " + string(opts.SiteID);
lines(end + 1) = "Placement ID: " + string(opts.PlacementID);
lines(end + 1) = "Placement notes: " + string(opts.PlacementNotes);

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
    for idx = 1:numel(top_run_folders)
        lines(end + 1) = "  " + top_run_folders(idx);
    end
else
    lines(end + 1) = "No completed configurations were available.";
end

lines = [lines(:); commissioning_notes(:)];
summary_text = char(strjoin(lines, newline));
end

function artifact_paths = localWriteReviewArtifacts(sweep_folder, run_table, configuration_summary, summary_text)
artifact_paths = struct( ...
    'sweep_folder', string(sweep_folder), ...
    'run_table_csv', string(fullfile(sweep_folder, 'run_table.csv')), ...
    'configuration_summary_csv', string(fullfile(sweep_folder, 'configuration_summary.csv')), ...
    'summary_txt', string(fullfile(sweep_folder, 'summary.txt')), ...
    'review_mat', string(fullfile(sweep_folder, 'sweep_review.mat')));

localWriteTextFile(char(artifact_paths.summary_txt), summary_text, 'reviewPlutoToneCommissioningSweep:summaryWriteFailed');
localWriteTableCSV(run_table, char(artifact_paths.run_table_csv), 'reviewPlutoToneCommissioningSweep:runTableWriteFailed');
localWriteTableCSV(configuration_summary, char(artifact_paths.configuration_summary_csv), 'reviewPlutoToneCommissioningSweep:configTableWriteFailed');
end

function sweep_id = localSweepIDFromFolder(sweep_folder)
[~, sweep_id] = fileparts(char(string(sweep_folder)));
end

function repeat_index = localRepeatIndexFromRunID(run_id)
repeat_index = NaN;
tokens = regexp(char(run_id), '_r(\d+)$', 'tokens', 'once');
if ~isempty(tokens)
    repeat_index = str2double(tokens{1});
end
end

function label = localConfigurationLabel(tone_offset_hz, tone_amplitude)
label = "offset_" + localNumberToken(tone_offset_hz / 1e3, 0) + "kHz_amp_" + localNumberToken(tone_amplitude, 2);
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
        error('reviewPlutoToneCommissioningSweep:fileOpenFailed', ...
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
