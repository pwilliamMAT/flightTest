function baseline = commissionPlutoToneBaseline(varargin)
%COMMISSIONPLUTOTONEBASELINE Commission a standalone Pluto tone baseline from prior run results.
%
% Plain-language goal:
%   The baseline file is the reusable reference for later Pluto prechecks.
%   For this implementation slice, commissioning is driven from existing
%   standalone run results so the schema, aggregation, and artifact-writing
%   path can be proven before the hardware runtime wrapper is finalized.
%
% Syntax
%   baseline = commissionPlutoToneBaseline(...)
%
% Required name-value options for this slice
%   'Thresholds'   Threshold struct matching the frozen baseline schema
%   'RunSources'   One or more saved result sources or result structs
%
% Public configuration options
%   'BaselineRoot'        Root folder for baseline artifacts
%   'BaselineID'          Baseline identifier. Default: timestamp-based
%   'SiteID'              Site identifier string
%   'PlacementID'         Placement identifier string
%   'PlacementNotes'      Free-text placement notes
%   'RadioName'           N320 radio name
%   'CaptureFileBase'     Capture stem
%   'CenterFrequency_Hz'  Capture center frequency
%   'SampleRate_Hz'       Capture sample rate
%   'LOOffset_Hz'         Capture LO offset
%   'Gain'                Capture gain scalar or [surv ref]
%   'ToneOffset_Hz'       Expected tone offset in complex baseband
%   'ToneAmplitude'       Digital tone amplitude
%   'CaptureDuration_s'   Capture duration
%   'NumRuns'             Expected commissioning run count
%   'PlotFigures'         Whether to create a visible figure. Default: true
%   'Verbose'             Print summary/status. Default: true
%
% See also: helperPlutoToneLoadResult, helperPlutoToneNormalizeThresholds,
%           helperPlutoTonePlotSummary, reviewPlutoTonePrecheckResult.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'BaselineRoot', fullfile(pwd, 'TestSetupTesting', 'plutoToneBaselines'), @(x) ischar(x) || isstring(x));
addParameter(p, 'BaselineID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SiteID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlacementNotes', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Thresholds', struct(), @isstruct);
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureFileBase', "pluto_tone_baseline", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequency_Hz', 540e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRate_Hz', 6.144e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 200e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'ToneOffset_Hz', 250e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ToneAmplitude', 0.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CaptureDuration_s', 0.25, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'NumRuns', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x, 1) == 0);
addParameter(p, 'RunSources', [], @(x) isstruct(x) || ischar(x) || isstring(x) || iscell(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

thresholds = helperPlutoToneNormalizeThresholds(opts.Thresholds);
[run_results, run_source_paths] = localResolveRunResults(opts.RunSources);

if isempty(run_results)
    error('commissionPlutoToneBaseline:runSourcesRequired', ...
        ['This commissioning slice requires RunSources because the live ' ...
         'hardware runtime wrapper is not implemented yet.']);
end

using_defaults = p.UsingDefaults;
if any(strcmp(using_defaults, 'NumRuns'))
    num_runs = numel(run_results);
else
    num_runs = opts.NumRuns;
    if num_runs ~= numel(run_results)
        error('commissionPlutoToneBaseline:numRunsMismatch', ...
            'NumRuns=%d but %d commissioning result(s) were supplied.', ...
            num_runs, numel(run_results));
    end
end

baseline_id = string(opts.BaselineID);
if strlength(baseline_id) == 0
    baseline_id = "pluto_baseline_" + string(datetime('now', 'TimeZone', 'UTC', ...
        'Format', 'yyyyMMdd''T''HHmmss'));
end

baseline_root = char(string(opts.BaselineRoot));
baseline_folder = fullfile(baseline_root, char(baseline_id));
baseline_mat_path = fullfile(baseline_folder, 'baseline.mat');
baseline_json_path = fullfile(baseline_folder, 'baseline.json');
summary_txt_path = fullfile(baseline_folder, 'summary.txt');
summary_png_path = fullfile(baseline_folder, 'summary.png');

expected_settings = localBuildSettingsStruct(opts);
localValidateRunSettings(run_results, expected_settings);

baseline = struct( ...
    'schema_version', 1, ...
    'baseline_id', char(baseline_id), ...
    'created_utc', char(string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''))), ...
    'site_id', char(string(opts.SiteID)), ...
    'placement_id', char(string(opts.PlacementID)), ...
    'placement_notes', char(string(opts.PlacementNotes)), ...
    'settings', expected_settings, ...
    'channel_map', localBuildChannelMap(), ...
    'statistics', localBuildStatistics(run_results), ...
    'thresholds', thresholds, ...
    'commissioning', localBuildCommissioningInfo(run_results, run_source_paths, num_runs), ...
    'provenance', struct());

baseline.provenance = localBuildProvenance(baseline_mat_path, baseline_json_path);

summary_result = localBuildSummaryResult(baseline);
summary_struct = helperPlutoToneBuildSummary(summary_result, 'HeadlinePrefix', 'PLUTO BASELINE');
summary_text = char(string(summary_struct.text_block));

try
    if exist(baseline_folder, 'dir') ~= 7
        mkdir(baseline_folder);
    end
catch me_dir
    error('commissionPlutoToneBaseline:mkdirFailed', ...
        'Could not create baseline folder %s: %s', baseline_folder, me_dir.message);
end

localWriteTextFile(summary_txt_path, summary_text, 'commissionPlutoToneBaseline:summaryWriteFailed');
localWriteBaselineMAT(baseline, baseline_mat_path);
localWriteBaselineJSON(baseline, baseline_json_path);
localWriteSummaryPNG(summary_result, summary_png_path, opts.PlotFigures);

if opts.Verbose
    fprintf('[commissionPlutoToneBaseline] Baseline ID ... %s\n', char(baseline_id));
    fprintf('[commissionPlutoToneBaseline] Num runs ...... %d\n', num_runs);
    fprintf('[commissionPlutoToneBaseline] MAT ........... %s\n', baseline_mat_path);
    fprintf('[commissionPlutoToneBaseline] JSON .......... %s\n', baseline_json_path);
    fprintf('[commissionPlutoToneBaseline] Summary ....... %s\n', summary_txt_path);
    fprintf('%s\n', summary_text);
end
end

function [run_results, run_source_paths] = localResolveRunResults(run_sources)
run_results = struct([]);
run_source_paths = strings(0, 1);

if isempty(run_sources)
    return
end

if isstruct(run_sources)
    run_results = run_sources(:);
    run_source_paths = strings(numel(run_results), 1);
    return
end

if ischar(run_sources) || isstring(run_sources)
    source_list = cellstr(string(run_sources(:)));
elseif iscell(run_sources)
    source_list = run_sources(:);
else
    error('commissionPlutoToneBaseline:badRunSources', ...
        'RunSources must be a struct array, path string, string array, or cell array.');
end

n_sources = numel(source_list);
run_results = struct([]);
run_source_paths = strings(n_sources, 1);
for idx = 1:n_sources
    loaded_result = helperPlutoToneLoadResult(source_list{idx});
    if isempty(run_results)
        run_results = loaded_result;
    else
        run_results(idx) = orderfields(loaded_result, run_results(1));
    end
    run_source_paths(idx) = string(source_list{idx});
end
end

function settings = localBuildSettingsStruct(opts)
settings = struct( ...
    'radio_name', char(string(opts.RadioName)), ...
    'capture_file_base', char(string(opts.CaptureFileBase)), ...
    'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'lo_offset_hz', double(opts.LOOffset_Hz), ...
    'capture_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'gain', double(opts.Gain(:).'), ...
    'tone_offset_hz', double(opts.ToneOffset_Hz), ...
    'tone_rf_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz + opts.ToneOffset_Hz), ...
    'tone_amplitude', double(opts.ToneAmplitude), ...
    'capture_duration_s', double(opts.CaptureDuration_s));
end

function localValidateRunSettings(run_results, expected_settings)
fields_to_compare = { ...
    'center_frequency_hz', ...
    'sample_rate_hz', ...
    'lo_offset_hz', ...
    'capture_tune_frequency_hz', ...
    'gain', ...
    'tone_offset_hz', ...
    'tone_rf_frequency_hz', ...
    'tone_amplitude', ...
    'capture_duration_s'};

for idx = 1:numel(run_results)
    if ~isfield(run_results(idx), 'settings') || ~isstruct(run_results(idx).settings)
        error('commissionPlutoToneBaseline:missingRunSettings', ...
            'Commissioning result %d is missing the settings struct.', idx);
    end

    mismatch_fields = strings(0, 1);
    for jdx = 1:numel(fields_to_compare)
        field_name = fields_to_compare{jdx};
        expected_value = expected_settings.(field_name);
        if ~isfield(run_results(idx).settings, field_name)
            mismatch_fields(end + 1) = string(field_name); %#ok<AGROW>
            continue
        end

        run_value = double(run_results(idx).settings.(field_name));
        if ~isequaln(size(run_value), size(expected_value)) || any(abs(run_value(:) - expected_value(:)) > 1e-9)
            mismatch_fields(end + 1) = string(field_name); %#ok<AGROW>
        end
    end

    if ~isempty(mismatch_fields)
        error('commissionPlutoToneBaseline:settingsMismatch', ...
            'Commissioning result %d does not match the requested settings: %s', ...
            idx, strjoin(cellstr(mismatch_fields), ', '));
    end
end
end

function channel_map = localBuildChannelMap()
channel_map = struct( ...
    'reference_label', 'REF', ...
    'reference_channel_index', 2, ...
    'reference_rx_label', 'CH2/RX2', ...
    'surveillance_label', 'SURV', ...
    'surveillance_channel_index', 1, ...
    'surveillance_rx_label', 'CH1/RX1');
end

function statistics = localBuildStatistics(run_results)
statistics = struct( ...
    'reference', localBuildChannelStatistics(run_results, 'reference_metrics'), ...
    'surveillance', localBuildChannelStatistics(run_results, 'surveillance_metrics'), ...
    'joint', localBuildJointStatistics(run_results));
end

function channel_stats = localBuildChannelStatistics(run_results, field_name)
channel_stats = struct( ...
    'level_dbfs', localMedianMetric(run_results, field_name, 'level_dbfs'), ...
    'tone_peak_dbfs', localMedianMetric(run_results, field_name, 'tone_peak_dbfs'), ...
    'local_floor_dbfs', localMedianMetric(run_results, field_name, 'local_floor_dbfs'), ...
    'detect_margin_db', localMedianMetric(run_results, field_name, 'detect_margin_db'), ...
    'measured_frequency_hz', localMedianMetric(run_results, field_name, 'measured_frequency_hz'));
end

function joint_stats = localBuildJointStatistics(run_results)
joint_stats = struct( ...
    'channel_frequency_delta_hz', localMedianMetric(run_results, 'joint_metrics', 'channel_frequency_delta_hz'), ...
    'xcorr_lag_samples', localMedianMetric(run_results, 'joint_metrics', 'xcorr_lag_samples'), ...
    'xcorr_lag_seconds', localMedianMetric(run_results, 'joint_metrics', 'xcorr_lag_seconds'), ...
    'xcorr_peak_db', localMedianMetric(run_results, 'joint_metrics', 'xcorr_peak_db'));
end

function value = localMedianMetric(run_results, struct_field, metric_field)
n_runs = numel(run_results);
values = NaN(n_runs, 1);
for idx = 1:n_runs
    if isfield(run_results(idx), struct_field) && isstruct(run_results(idx).(struct_field)) && ...
            isfield(run_results(idx).(struct_field), metric_field)
        metric_value = double(run_results(idx).(struct_field).(metric_field));
        if isscalar(metric_value)
            values(idx) = metric_value;
        end
    end
end
value = median(values, 'omitnan');
end

function commissioning = localBuildCommissioningInfo(run_results, run_source_paths, num_runs)
run_ids = strings(numel(run_results), 1);
result_paths = strings(numel(run_results), 1);
for idx = 1:numel(run_results)
    if isfield(run_results(idx), 'run_id')
        run_ids(idx) = string(run_results(idx).run_id);
    end

    if isfield(run_results(idx), 'artifact_paths') && isstruct(run_results(idx).artifact_paths)
        if isfield(run_results(idx).artifact_paths, 'run_folder') && ...
                strlength(string(run_results(idx).artifact_paths.run_folder)) > 0
            result_paths(idx) = string(run_results(idx).artifact_paths.run_folder);
        elseif isfield(run_results(idx).artifact_paths, 'result_mat') && ...
                strlength(string(run_results(idx).artifact_paths.result_mat)) > 0
            result_paths(idx) = string(run_results(idx).artifact_paths.result_mat);
        elseif isfield(run_results(idx).artifact_paths, 'result_json') && ...
                strlength(string(run_results(idx).artifact_paths.result_json)) > 0
            result_paths(idx) = string(run_results(idx).artifact_paths.result_json);
        end
    end

    if strlength(result_paths(idx)) == 0 && idx <= numel(run_source_paths)
        result_paths(idx) = run_source_paths(idx);
    end
end

commissioning = struct( ...
    'num_runs', num_runs, ...
    'aggregation_method', 'median', ...
    'run_ids', run_ids, ...
    'result_paths', result_paths);
end

function provenance = localBuildProvenance(baseline_mat_path, baseline_json_path)
repo_root = fileparts(fileparts(mfilename('fullpath')));
provenance = struct( ...
    'baseline_mat_path', string(baseline_mat_path), ...
    'baseline_json_path', string(baseline_json_path), ...
    'matlab_release', string(version('-release')), ...
    'git_branch', localGitValue(repo_root, 'branch --show-current'), ...
    'git_commit', localGitValue(repo_root, 'rev-parse HEAD'));
end

function value = localGitValue(repo_root, git_args)
value = "";
try
    command = sprintf('git -C "%s" %s', repo_root, git_args);
    [status, output] = system(command);
    if status == 0
        value = strtrim(string(output));
    end
catch
    value = "";
end
end

function result = localBuildSummaryResult(baseline)
reference_frequency_error_hz = baseline.statistics.reference.measured_frequency_hz - baseline.settings.tone_offset_hz;
surveillance_frequency_error_hz = baseline.statistics.surveillance.measured_frequency_hz - baseline.settings.tone_offset_hz;

reference_metrics = struct( ...
    'channel_label', 'REF', ...
    'channel_index', 2, ...
    'rx_label', 'CH2/RX2', ...
    'tone_found', true, ...
    'expected_frequency_hz', baseline.settings.tone_offset_hz, ...
    'measured_frequency_hz', baseline.statistics.reference.measured_frequency_hz, ...
    'frequency_error_hz', reference_frequency_error_hz, ...
    'level_dbfs', baseline.statistics.reference.level_dbfs, ...
    'tone_peak_dbfs', baseline.statistics.reference.tone_peak_dbfs, ...
    'local_floor_dbfs', baseline.statistics.reference.local_floor_dbfs, ...
    'detect_margin_db', baseline.statistics.reference.detect_margin_db, ...
    'level_delta_vs_baseline_db', 0, ...
    'status', 'PASS', ...
    'fail_codes', {cell(0, 1)}, ...
    'warn_codes', {cell(0, 1)});

surveillance_metrics = struct( ...
    'channel_label', 'SURV', ...
    'channel_index', 1, ...
    'rx_label', 'CH1/RX1', ...
    'tone_found', true, ...
    'expected_frequency_hz', baseline.settings.tone_offset_hz, ...
    'measured_frequency_hz', baseline.statistics.surveillance.measured_frequency_hz, ...
    'frequency_error_hz', surveillance_frequency_error_hz, ...
    'level_dbfs', baseline.statistics.surveillance.level_dbfs, ...
    'tone_peak_dbfs', baseline.statistics.surveillance.tone_peak_dbfs, ...
    'local_floor_dbfs', baseline.statistics.surveillance.local_floor_dbfs, ...
    'detect_margin_db', baseline.statistics.surveillance.detect_margin_db, ...
    'level_delta_vs_baseline_db', 0, ...
    'status', 'PASS', ...
    'fail_codes', {cell(0, 1)}, ...
    'warn_codes', {cell(0, 1)});

joint_metrics = struct( ...
    'channel_frequency_delta_hz', baseline.statistics.joint.channel_frequency_delta_hz, ...
    'xcorr_lag_samples', baseline.statistics.joint.xcorr_lag_samples, ...
    'xcorr_lag_seconds', baseline.statistics.joint.xcorr_lag_seconds, ...
    'xcorr_peak_db', baseline.statistics.joint.xcorr_peak_db, ...
    'xcorr_note', 'Commissioned baseline median metrics.', ...
    'status', 'PASS', ...
    'fail_codes', {cell(0, 1)}, ...
    'warn_codes', {cell(0, 1)});

result = struct( ...
    'schema_version', 1, ...
    'run_id', char(string(baseline.baseline_id)), ...
    'created_utc', char(string(baseline.created_utc)), ...
    'overall_pass', true, ...
    'status', 'PASS', ...
    'fail_codes', {cell(0, 1)}, ...
    'warn_codes', {cell(0, 1)}, ...
    'settings', baseline.settings, ...
    'capture_info', struct(), ...
    'channel_map', baseline.channel_map, ...
    'reference_metrics', reference_metrics, ...
    'surveillance_metrics', surveillance_metrics, ...
    'joint_metrics', joint_metrics, ...
    'baseline_comparison', struct( ...
        'baseline_id', char(string(baseline.baseline_id)), ...
        'settings_match', true, ...
        'settings_mismatch_fields', {cell(0, 1)}, ...
        'reference_level_delta_db', 0, ...
        'surveillance_level_delta_db', 0, ...
        'comparison_applied', true), ...
    'precheck_summary', struct(), ...
    'artifact_paths', struct());
end

function localWriteBaselineMAT(baseline, baseline_mat_path)
try
    save_struct = struct('baseline', baseline);
    save(baseline_mat_path, '-struct', 'save_struct', '-v7.3');
catch me_save
    error('commissionPlutoToneBaseline:matSaveFailed', ...
        'Could not save baseline MAT file %s: %s', baseline_mat_path, me_save.message);
end
end

function localWriteBaselineJSON(baseline, baseline_json_path)
json_text = jsonencode(helperPlutoTonePrepareForJSON(baseline));
localWriteTextFile(baseline_json_path, json_text, 'commissionPlutoToneBaseline:jsonWriteFailed');
end

function localWriteSummaryPNG(summary_result, summary_png_path, plot_figures)
figure_visibility = 'off';
if plot_figures
    figure_visibility = 'on';
end

fig = helperPlutoTonePlotSummary( ...
    summary_result, ...
    'FigureVisibility', figure_visibility, ...
    'SummaryTitle', 'Pluto Tone Baseline Summary');
try
    exportgraphics(fig, summary_png_path);
catch me_png
    if ishghandle(fig)
        close(fig);
    end
    error('commissionPlutoToneBaseline:pngWriteFailed', ...
        'Could not write baseline summary figure %s: %s', summary_png_path, me_png.message);
end
if ishghandle(fig)
    close(fig);
end
end

function localWriteTextFile(output_path, content, error_id)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('commissionPlutoToneBaseline:fileOpenFailed', ...
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
