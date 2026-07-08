function benchmark_output = runOfflineToolboxBenchmark(source, varargin)
%RUNOFFLINETOOLBOXBENCHMARK Compare custom and toolbox timing/detector paths offline.
%
% Plain-language goal:
%   Benchmark four named analysis variants against the same cached
%   detector/truth input without changing the supported production wrapper:
%
%     custom_baseline
%     toolbox_tdoa
%     toolbox_cfar
%     toolbox_tdoa_cfar
%
%   The benchmark keeps the current truth-diagnostic machinery, so every
%   variant is scored with the same measurement-space gates and the same
%   TP/FA/miss accounting. The only things that change are:
%     1. whether the CFAR detector comes from the custom function or
%        phased.CFARDetector2D
%     2. whether the range-delay measurement comes from the original CAF
%        grid or from phased.TDOAEstimator refinement
%
% Supported sources:
%   - detector replay bundle struct
%   - analysis output struct containing .detector_replay_input
%   - MAT-file path containing detector_replay_input
%   - packaged session ID, session folder, or manifest path
%
% The output always includes a fixed summary table with runtime-per-stage,
% total runtime, truth metrics, and baseline deltas.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source', @(x) isstruct(x) || ischar(x) || isstring(x));
addParameter(p, 'Variants', {'custom_baseline', 'toolbox_tdoa', 'toolbox_cfar', 'toolbox_tdoa_cfar'}, ...
    @(x) iscellstr(x) || isstring(x));
addParameter(p, 'RunTruthDiagnostics', true, @islogical);
addParameter(p, 'DatasetRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PartIndices', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && ...
    all(isfinite(x)) && all(x >= 1) && all(mod(x, 1) == 0)));
addParameter(p, 'MaxBlocksPerPart', inf, ...
    @(x) isnumeric(x) && isscalar(x) && ...
    ((isfinite(x) && x >= 1 && mod(x, 1) == 0) || isinf(x)));
addParameter(p, 'SearchWindowSamples', 6, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'PlotSummary', false, @islogical);
addParameter(p, 'Verbose', false, @islogical);
parse(p, source, varargin{:});
opts = p.Results;

variant_defs = localResolveVariantDefinitions(opts.Variants);
[detector_replay_input, source_info, preparation_runtime_s] = ...
    localResolveBenchmarkSource(opts.source, opts);
 [detector_replay_input, scope_info] = helperRestrictDetectorReplayInput( ...
    detector_replay_input, ...
    'PartIndices', opts.PartIndices, ...
    'MaxBlocksPerPart', opts.MaxBlocksPerPart, ...
    'Verbose', opts.Verbose);

run_truth = opts.RunTruthDiagnostics && localHasTruthTemplate(detector_replay_input) && ...
    ~scope_info.is_limited;
if opts.Verbose
    fprintf('\n[runOfflineToolboxBenchmark] Source type: %s\n', source_info.source_type);
    fprintf('[runOfflineToolboxBenchmark] Preparation runtime: %.3f s\n', preparation_runtime_s);
    if scope_info.is_limited
        fprintf(['[runOfflineToolboxBenchmark] Scoped replay slice: parts %s, ' ...
            'max_blocks_per_part=%s\n'], ...
            localFormatIntegerList(scope_info.selected_part_indices), ...
            localFormatScalarLimit(scope_info.max_blocks_per_part));
    end
    if opts.RunTruthDiagnostics && scope_info.is_limited
        fprintf(['[runOfflineToolboxBenchmark] Truth diagnostics disabled for scoped replay slices. ' ...
            'Use the full replay input for acceptance metrics.\n']);
    end
    fprintf('[runOfflineToolboxBenchmark] Truth diagnostics: %s\n', string(run_truth));
end

variant_results = repmat(struct( ...
    'name', "", ...
    'status', "pending", ...
    'error_message', "", ...
    'detector_backend', "", ...
    'tdoa_backend', "", ...
    'timings', struct(), ...
    'summary', struct(), ...
    'part_detections', {cell(0, 1)}, ...
    'all_track_dets', zeros(0, 6), ...
    'truth_diag_output', struct(), ...
    'detector_stage_info', struct([]), ...
    'tdoa_refinement_info', struct([])), 1, numel(variant_defs));

for iv = 1 : numel(variant_defs)
    variant_def = variant_defs(iv);
    variant_total_tic = tic;
    detector_runtime_s = NaN;
    tdoa_runtime_s = 0;
    truth_runtime_s = 0;

    variant_results(iv).name = string(variant_def.name);
    variant_results(iv).detector_backend = string(variant_def.detector_backend);
    variant_results(iv).tdoa_backend = string(variant_def.tdoa_backend);

    if opts.Verbose
        fprintf('\n[runOfflineToolboxBenchmark] Variant %d/%d: %s\n', ...
            iv, numel(variant_defs), variant_def.name);
    end

    try
        detector_tic = tic;
        [part_detections, all_track_dets, detector_stage_info] = helperRunDetectorReplayVariant( ...
            detector_replay_input, variant_def.detector_backend, 'Verbose', false);
        detector_runtime_s = toc(detector_tic);

        tdoa_refinement_info = struct([]);
        if strcmpi(variant_def.tdoa_backend, 'toolbox')
            tdoa_tic = tic;
            [part_detections, all_track_dets, tdoa_refinement_info] = ...
                helperApplyToolboxTDOARefinement( ...
                    detector_replay_input, part_detections, ...
                    'SearchWindowSamples', opts.SearchWindowSamples, ...
                    'Verbose', false);
            tdoa_runtime_s = toc(tdoa_tic);
        end

        truth_diag_output = struct();
        summary = struct( ...
            'detection_count', size(all_track_dets, 1), ...
            'n_tp', NaN, ...
            'n_fa', NaN, ...
            'n_miss', NaN, ...
            'mean_pd', NaN);

        if run_truth
            truth_tic = tic;
            truth_bundle = localBuildTruthBundle(detector_replay_input, all_track_dets, ...
                part_detections, variant_def.name);
            truth_diag_output = runDetectionTruthDiagnostics( ...
                truth_bundle, ...
                'Verbose', false, ...
                'PlotDetectionTimeSeries', false, ...
                'PlotRDMOverlays', false, ...
                'PlotTrackComparison', false);
            truth_runtime_s = toc(truth_tic);

            summary.detection_count = localGetField( ...
                truth_diag_output.check_summary, 'n_detections', size(all_track_dets, 1));
            summary.n_tp = localGetField(truth_diag_output.truth_metrics, 'n_tp', NaN);
            summary.n_fa = localGetField(truth_diag_output.truth_metrics, 'n_fa', NaN);
            summary.n_miss = localGetField(truth_diag_output.truth_metrics, 'n_miss', NaN);
            summary.mean_pd = localMeanPd(truth_diag_output.truth_metrics);
        end

        variant_results(iv).status = "completed";
        variant_results(iv).timings = struct( ...
            'detector_runtime_s', detector_runtime_s, ...
            'tdoa_runtime_s', tdoa_runtime_s, ...
            'truth_runtime_s', truth_runtime_s, ...
            'total_runtime_s', toc(variant_total_tic));
        variant_results(iv).summary = summary;
        variant_results(iv).part_detections = part_detections;
        variant_results(iv).all_track_dets = all_track_dets;
        variant_results(iv).truth_diag_output = truth_diag_output;
        variant_results(iv).detector_stage_info = detector_stage_info;
        variant_results(iv).tdoa_refinement_info = tdoa_refinement_info;
    catch ME
        variant_results(iv).status = "error";
        variant_results(iv).error_message = string(ME.message);
        variant_results(iv).timings = struct( ...
            'detector_runtime_s', detector_runtime_s, ...
            'tdoa_runtime_s', tdoa_runtime_s, ...
            'truth_runtime_s', truth_runtime_s, ...
            'total_runtime_s', toc(variant_total_tic));
        variant_results(iv).summary = struct( ...
            'detection_count', NaN, ...
            'n_tp', NaN, ...
            'n_fa', NaN, ...
            'n_miss', NaN, ...
            'mean_pd', NaN);

        if opts.Verbose
            fprintf('  [ERROR] %s\n', ME.message);
        end
    end
end

summary_table = localBuildSummaryTable(variant_results);
summary_table = localAddBaselineDeltas(summary_table, "custom_baseline");

benchmark_output = struct( ...
    'session_id', string(localGetField(detector_replay_input, 'session_id', "")), ...
    'analysis_label', string(localResolveAnalysisLabel(detector_replay_input)), ...
    'source_info', source_info, ...
    'scope_info', scope_info, ...
    'preparation_runtime_s', preparation_runtime_s, ...
    'baseline_variant', "custom_baseline", ...
    'variant_results', variant_results, ...
    'summary_table', summary_table);

if opts.PlotSummary && ~isempty(summary_table)
    plotOfflineToolboxBenchmarkSummary(summary_table, ...
        'FigureTitle', char(benchmark_output.analysis_label));
end

if opts.Verbose && ~isempty(summary_table)
    fprintf('\n[runOfflineToolboxBenchmark] Summary:\n');
    disp(summary_table);
end
end

function variant_defs = localResolveVariantDefinitions(requested_variants)
canonical = struct( ...
    'custom_baseline', struct('name', "custom_baseline", 'detector_backend', "custom", 'tdoa_backend', "custom"), ...
    'toolbox_tdoa', struct('name', "toolbox_tdoa", 'detector_backend', "custom", 'tdoa_backend', "toolbox"), ...
    'toolbox_cfar', struct('name', "toolbox_cfar", 'detector_backend', "toolbox", 'tdoa_backend', "custom"), ...
    'toolbox_tdoa_cfar', struct('name', "toolbox_tdoa_cfar", 'detector_backend', "toolbox", 'tdoa_backend', "toolbox"));

requested_variants = string(requested_variants);
requested_variants = requested_variants(:).';
if ~any(strcmpi(requested_variants, "custom_baseline"))
    requested_variants = ["custom_baseline", requested_variants];
end
requested_variants = unique(lower(requested_variants), 'stable');

variant_defs = repmat(canonical.custom_baseline, 1, numel(requested_variants));
for k = 1 : numel(requested_variants)
    variant_name = char(requested_variants(k));
    if ~isfield(canonical, variant_name)
        error('runOfflineToolboxBenchmark:unknownVariant', ...
            'Unknown benchmark variant ''%s''.', variant_name);
    end
    variant_defs(k) = canonical.(variant_name);
end
end

function [detector_replay_input, source_info, preparation_runtime_s] = ...
    localResolveBenchmarkSource(source, opts)
source_info = struct( ...
    'source_type', "", ...
    'session_id', "", ...
    'path', "");
preparation_runtime_s = 0;

if isstruct(source) && isfield(source, 'detector_parts')
    detector_replay_input = source;
    source_info.source_type = "detector_replay_input";
    source_info.session_id = string(localGetField(source, 'session_id', ""));
    return
end

if isstruct(source) && isfield(source, 'detector_replay_input')
    detector_replay_input = source.detector_replay_input;
    source_info.source_type = "analysis_output";
    source_info.session_id = string(localGetField(detector_replay_input, 'session_id', ""));
    return
end

if ~(ischar(source) || isstring(source))
    error('runOfflineToolboxBenchmark:badSource', ...
        'Unsupported source type.');
end

source_text = char(string(source));
if exist(source_text, 'file') == 2 && endsWith(source_text, '.mat', 'IgnoreCase', true)
    loaded = load(source_text);
    if isfield(loaded, 'detector_replay_input')
        detector_replay_input = loaded.detector_replay_input;
    elseif isfield(loaded, 'analysis_output') && isfield(loaded.analysis_output, 'detector_replay_input')
        detector_replay_input = loaded.analysis_output.detector_replay_input;
    else
        error('runOfflineToolboxBenchmark:missingReplayInput', ...
            'MAT-file %s does not contain detector_replay_input.', source_text);
    end
    source_info.source_type = "mat_file";
    source_info.path = string(source_text);
    source_info.session_id = string(localGetField(detector_replay_input, 'session_id', ""));
    return
end

if exist(source_text, 'dir') == 7
    if exist(fullfile(source_text, 'session_manifest.json'), 'file') ~= 2
        error('runOfflineToolboxBenchmark:missingManifest', ...
            'Folder %s does not contain session_manifest.json.', source_text);
    end
    prep_tic = tic;
    analysis_output = runBistaticAnalysisSession("", ...
        'SessionFolder', source_text, ...
        'SaveTruthDiagnosticSnapshot', false, ...
        'SaveDetectorReplaySnapshot', false, ...
        'Verbose', opts.Verbose);
    preparation_runtime_s = toc(prep_tic);
    detector_replay_input = analysis_output.detector_replay_input;
    source_info.source_type = "session_folder";
    source_info.path = string(source_text);
    source_info.session_id = string(localGetField(analysis_output, 'session_id', ""));
    return
end

prep_tic = tic;
analysis_kwargs = { ...
    'SaveTruthDiagnosticSnapshot', false, ...
    'SaveDetectorReplaySnapshot', false, ...
    'Verbose', opts.Verbose};
if strlength(string(opts.DatasetRoot)) > 0
    analysis_kwargs = [analysis_kwargs, {'DatasetRoot', opts.DatasetRoot}];
end
if strlength(string(opts.SessionFolder)) > 0
    analysis_kwargs = [analysis_kwargs, {'SessionFolder', opts.SessionFolder}];
end
if strlength(string(opts.ManifestPath)) > 0
    analysis_kwargs = [analysis_kwargs, {'ManifestPath', opts.ManifestPath}];
end
analysis_output = runBistaticAnalysisSession(source_text, analysis_kwargs{:});
preparation_runtime_s = toc(prep_tic);
detector_replay_input = analysis_output.detector_replay_input;
source_info.source_type = "session_id";
source_info.session_id = string(localGetField(analysis_output, 'session_id', source_text));
end

function tf = localHasTruthTemplate(detector_replay_input)
tf = isfield(detector_replay_input, 'truth_diag_template') && ...
    isstruct(detector_replay_input.truth_diag_template) && ...
    ~isempty(detector_replay_input.truth_diag_template) && ...
    isfield(detector_replay_input.truth_diag_template, 'adsb_files') && ...
    ~isempty(detector_replay_input.truth_diag_template.adsb_files);
end

function truth_bundle = localBuildTruthBundle(detector_replay_input, all_track_dets, part_detections, variant_name)
truth_bundle = detector_replay_input.truth_diag_template;
truth_bundle.all_track_dets = all_track_dets;
truth_bundle.detections = localWrapTrackDetections(all_track_dets);
truth_bundle.analysis_label = sprintf('%s - %s', ...
    localResolveAnalysisLabel(detector_replay_input), variant_name);

[range_cell_m, doppler_bin_hz] = localResolveMeasurementGridFromDetectorParts( ...
    detector_replay_input.detector_parts);
if isfinite(range_cell_m) && range_cell_m > 0
    truth_bundle.range_cell_m = range_cell_m;
end
if isfinite(doppler_bin_hz) && doppler_bin_hz > 0
    truth_bundle.doppler_bin_hz = doppler_bin_hz;
end

if isfield(truth_bundle, 'rdm_parts') && ~isempty(truth_bundle.rdm_parts)
    n_parts = min(numel(part_detections), numel(truth_bundle.rdm_parts));
    for ip = 1 : n_parts
        dets_ip = part_detections{ip};
        truth_bundle.rdm_parts(ip).detections = dets_ip;
        truth_bundle.rdm_parts(ip).det_count = size(dets_ip, 1);
    end
end
end

function detections = localWrapTrackDetections(all_track_dets)
detections = struct( ...
    't_abs_s', {}, ...
    'R_excess_m', {}, ...
    'f_D_hz', {}, ...
    'pwr_db', {}, ...
    'block_index', {}, ...
    'part_index', {});

if isempty(all_track_dets)
    return
end

n_det = size(all_track_dets, 1);
detections(1, n_det) = struct( ...
    't_abs_s', 0, ...
    'R_excess_m', 0, ...
    'f_D_hz', 0, ...
    'pwr_db', NaN, ...
    'block_index', NaN, ...
    'part_index', NaN);

for k = 1 : n_det
    detections(k).t_abs_s = all_track_dets(k, 5);
    detections(k).R_excess_m = all_track_dets(k, 1);
    detections(k).f_D_hz = all_track_dets(k, 2);
    if size(all_track_dets, 2) >= 3
        detections(k).pwr_db = all_track_dets(k, 3);
    end
    if size(all_track_dets, 2) >= 4
        detections(k).block_index = all_track_dets(k, 4);
    end
    if size(all_track_dets, 2) >= 6
        detections(k).part_index = all_track_dets(k, 6);
    end
end
end

function [range_cell_m, doppler_bin_hz] = localResolveMeasurementGridFromDetectorParts(detector_parts)
range_cell_m = NaN;
doppler_bin_hz = NaN;

for ip = 1 : numel(detector_parts)
    if ~(isfinite(range_cell_m) && range_cell_m > 0) && ...
            isfield(detector_parts(ip), 'range_axis') && numel(detector_parts(ip).range_axis) >= 2
        delta_r = diff(detector_parts(ip).range_axis(:));
        delta_r = delta_r(isfinite(delta_r) & delta_r > 0);
        if ~isempty(delta_r)
            range_cell_m = median(delta_r);
        end
    end

    if ~(isfinite(doppler_bin_hz) && doppler_bin_hz > 0) && ...
            isfield(detector_parts(ip), 'doppler_axis') && numel(detector_parts(ip).doppler_axis) >= 2
        delta_f = diff(detector_parts(ip).doppler_axis(:));
        delta_f = delta_f(isfinite(delta_f) & abs(delta_f) > 0);
        if ~isempty(delta_f)
            doppler_bin_hz = median(abs(delta_f));
        end
    end

    if isfinite(range_cell_m) && range_cell_m > 0 && ...
            isfinite(doppler_bin_hz) && doppler_bin_hz > 0
        return
    end
end
end

function summary_table = localBuildSummaryTable(variant_results)
n_variants = numel(variant_results);
variant_name = strings(n_variants, 1);
status = strings(n_variants, 1);
error_message = strings(n_variants, 1);
detector_backend = strings(n_variants, 1);
tdoa_backend = strings(n_variants, 1);
detector_runtime_s = NaN(n_variants, 1);
tdoa_runtime_s = NaN(n_variants, 1);
truth_runtime_s = NaN(n_variants, 1);
total_runtime_s = NaN(n_variants, 1);
detection_count = NaN(n_variants, 1);
n_tp = NaN(n_variants, 1);
n_fa = NaN(n_variants, 1);
n_miss = NaN(n_variants, 1);
mean_pd = NaN(n_variants, 1);

for iv = 1 : n_variants
    variant_name(iv) = string(variant_results(iv).name);
    status(iv) = string(variant_results(iv).status);
    error_message(iv) = string(variant_results(iv).error_message);
    detector_backend(iv) = string(variant_results(iv).detector_backend);
    tdoa_backend(iv) = string(variant_results(iv).tdoa_backend);
    detector_runtime_s(iv) = localGetField(variant_results(iv).timings, 'detector_runtime_s', NaN);
    tdoa_runtime_s(iv) = localGetField(variant_results(iv).timings, 'tdoa_runtime_s', NaN);
    truth_runtime_s(iv) = localGetField(variant_results(iv).timings, 'truth_runtime_s', NaN);
    total_runtime_s(iv) = localGetField(variant_results(iv).timings, 'total_runtime_s', NaN);
    detection_count(iv) = localGetField(variant_results(iv).summary, 'detection_count', NaN);
    n_tp(iv) = localGetField(variant_results(iv).summary, 'n_tp', NaN);
    n_fa(iv) = localGetField(variant_results(iv).summary, 'n_fa', NaN);
    n_miss(iv) = localGetField(variant_results(iv).summary, 'n_miss', NaN);
    mean_pd(iv) = localGetField(variant_results(iv).summary, 'mean_pd', NaN);
end

summary_table = table( ...
    variant_name, status, error_message, detector_backend, tdoa_backend, ...
    detector_runtime_s, tdoa_runtime_s, truth_runtime_s, total_runtime_s, ...
    detection_count, n_tp, n_fa, n_miss, mean_pd);
end

function summary_table = localAddBaselineDeltas(summary_table, baseline_name)
n_rows = height(summary_table);
summary_table.delta_detector_runtime_s = NaN(n_rows, 1);
summary_table.delta_tdoa_runtime_s = NaN(n_rows, 1);
summary_table.delta_truth_runtime_s = NaN(n_rows, 1);
summary_table.delta_total_runtime_s = NaN(n_rows, 1);
summary_table.delta_detection_count = NaN(n_rows, 1);
summary_table.delta_n_tp = NaN(n_rows, 1);
summary_table.delta_n_fa = NaN(n_rows, 1);
summary_table.delta_n_miss = NaN(n_rows, 1);
summary_table.delta_mean_pd = NaN(n_rows, 1);

baseline_idx = find(strcmpi(summary_table.variant_name, baseline_name), 1, 'first');
if isempty(baseline_idx)
    return
end

baseline_row = summary_table(baseline_idx, :);
numeric_fields = { ...
    'detector_runtime_s', 'tdoa_runtime_s', 'truth_runtime_s', 'total_runtime_s', ...
    'detection_count', 'n_tp', 'n_fa', 'n_miss', 'mean_pd'};
delta_fields = { ...
    'delta_detector_runtime_s', 'delta_tdoa_runtime_s', 'delta_truth_runtime_s', 'delta_total_runtime_s', ...
    'delta_detection_count', 'delta_n_tp', 'delta_n_fa', 'delta_n_miss', 'delta_mean_pd'};

for k = 1 : numel(numeric_fields)
    summary_table.(delta_fields{k}) = summary_table.(numeric_fields{k}) - baseline_row.(numeric_fields{k});
end
end

function mean_pd = localMeanPd(truth_metrics)
mean_pd = NaN;
if isstruct(truth_metrics) && isfield(truth_metrics, 'Pd_per_ac') && ...
        istable(truth_metrics.Pd_per_ac) && any(strcmp(truth_metrics.Pd_per_ac.Properties.VariableNames, 'Pd'))
    mean_pd = mean(truth_metrics.Pd_per_ac.Pd, 'omitnan');
end
end

function value = localGetField(struct_in, field_name, default_value)
if isstruct(struct_in) && isfield(struct_in, field_name) && ~isempty(struct_in.(field_name))
    value = struct_in.(field_name);
else
    value = default_value;
end
end

function text_out = localFormatIntegerList(values)
values = values(:).';
if isempty(values)
    text_out = "[]";
else
    text_out = strjoin(string(values), ",");
end
end

function text_out = localFormatScalarLimit(value)
if isinf(value)
    text_out = "Inf";
else
    text_out = string(value);
end
end

function analysis_label = localResolveAnalysisLabel(detector_replay_input)
analysis_label = char(string(localGetField(detector_replay_input, 'analysis_label', "")));
if isempty(analysis_label)
    session_id = char(string(localGetField(detector_replay_input, 'session_id', "")));
    if ~isempty(session_id)
        analysis_label = sprintf('Session %s', session_id);
    else
        analysis_label = 'Offline Toolbox Benchmark';
    end
end
end
