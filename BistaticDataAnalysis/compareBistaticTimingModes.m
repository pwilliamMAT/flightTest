function comparison = compareBistaticTimingModes(metadata_output, fallback_output, varargin)
%COMPAREBISTATICTIMINGMODES Compare truth metrics for metadata and fallback timing runs.
%
% Plain-language goal:
%   The ADS-B truth fix is now mostly a timing-validation problem, not a
%   formula-derivation problem. This helper takes two completed
%   runBistaticAnalysisSession outputs, summarizes their timing and
%   truth-scoring results side by side, and optionally compares both
%   against the saved pre-patch console log.
%
% Syntax
%   comparison = compareBistaticTimingModes(out_meta, out_fallback)
%   comparison = compareBistaticTimingModes(..., ...
%       'ReferenceLogPath', 'C:\path\to\bistaticOutput.txt')
%
% Input
%   metadata_output  Output from runBistaticAnalysisSession(...,
%                    'PartTimingSource', 'metadata')
%   fallback_output  Output from runBistaticAnalysisSession(...,
%                    'PartTimingSource', 'fallback')
%
% Name-value options
%   'ReferenceLogPath'  Optional pre-patch console log to parse.
%   'Verbose'           Print a compact comparison summary. Default: true.
%
% Output
%   comparison         Struct containing:
%     .summary_table
%     .delta_table
%     .reference_summary
%     .assessment
%     .metadata_summary
%     .fallback_summary
%     .metadata_track_table
%     .fallback_track_table

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'metadata_output', @(x) isstruct(x) && isscalar(x));
addRequired(p, 'fallback_output', @(x) isstruct(x) && isscalar(x));
addParameter(p, 'ReferenceLogPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, metadata_output, fallback_output, varargin{:});
opts = p.Results;

metadata_summary = localSummarizeSessionOutput(metadata_output, "metadata");
fallback_summary = localSummarizeSessionOutput(fallback_output, "fallback");
summary_table = localBuildSummaryTable(metadata_summary, fallback_summary);
delta_table = localBuildDeltaTable(metadata_summary, fallback_summary);
reference_summary = localParseReferenceLog(opts.ReferenceLogPath);
assessment = localAssessComparison(metadata_summary, fallback_summary, reference_summary);

comparison = struct( ...
    'summary_table', summary_table, ...
    'delta_table', delta_table, ...
    'reference_summary', reference_summary, ...
    'assessment', assessment, ...
    'metadata_summary', metadata_summary, ...
    'fallback_summary', fallback_summary, ...
    'metadata_track_table', metadata_summary.track_table, ...
    'fallback_track_table', fallback_summary.track_table);

if opts.Verbose
    fprintf('\n[compareBistaticTimingModes] Mode summary:\n');
    disp(summary_table);

    fprintf('[compareBistaticTimingModes] Metadata minus fallback:\n');
    disp(delta_table);

    if reference_summary.available
        fprintf(['[compareBistaticTimingModes] Reference log: TP=%g, FA=%g, ' ...
                 'missed=%g, detections=%g, timing=%s\n'], ...
            reference_summary.n_tp, reference_summary.n_fa, ...
            reference_summary.n_miss, reference_summary.n_detections, ...
            char(reference_summary.timing_source));
    end

    if ~isempty(assessment.notes)
        fprintf('[compareBistaticTimingModes] Assessment:\n');
        for iNote = 1 : numel(assessment.notes)
            fprintf('  - %s\n', char(assessment.notes(iNote)));
        end
    end
end

end

function summary = localSummarizeSessionOutput(output_struct, mode_name)
timing_summary = localResolveTimingSummary(output_struct);
truth_metrics = localGetStructField(output_struct, 'truth_metrics');
truth_diag_summary = localGetStructField(output_struct, 'truth_diag_summary');
track_table = localResolveTrackTable(truth_metrics);
track_stats = localSummarizeTrackTable(track_table);

n_detections = localGetNumericField(truth_diag_summary, 'n_detections', NaN);
if ~isfinite(n_detections)
    if isfield(output_struct, 'all_track_dets') && isnumeric(output_struct.all_track_dets)
        n_detections = size(output_struct.all_track_dets, 1);
    elseif isfield(truth_metrics, 'det_table') && istable(truth_metrics.det_table)
        n_detections = height(truth_metrics.det_table);
    end
end

summary = struct( ...
    'mode', string(mode_name), ...
    'requested_source', timing_summary.requested_source, ...
    'resolved_source', timing_summary.resolved_source, ...
    'n_parts', timing_summary.n_parts, ...
    'part_duration_s', timing_summary.part_duration_s, ...
    'part_start_offsets_s', timing_summary.part_start_offsets_s, ...
    'start_spacing_s', timing_summary.start_spacing_s, ...
    'inter_part_gap_s', timing_summary.inter_part_gap_s, ...
    'median_start_spacing_s', timing_summary.median_start_spacing_s, ...
    'median_gap_s', timing_summary.median_gap_s, ...
    'n_metadata_parts', timing_summary.n_metadata_parts, ...
    'used_metadata', timing_summary.used_metadata, ...
    'n_detections', n_detections, ...
    'n_tp', localGetNumericField(truth_metrics, 'n_tp', NaN), ...
    'n_fa', localGetNumericField(truth_metrics, 'n_fa', NaN), ...
    'n_miss', localGetNumericField(truth_metrics, 'n_miss', NaN), ...
    'n_tracks', track_stats.n_tracks, ...
    'mean_track_range_bias_m', track_stats.mean_range_bias_m, ...
    'mean_track_range_rmse_m', track_stats.mean_range_rmse_m, ...
    'mean_track_doppler_bias_hz', track_stats.mean_doppler_bias_hz, ...
    'mean_track_doppler_rmse_hz', track_stats.mean_doppler_rmse_hz, ...
    'track_table', track_table);
end

function timing_summary = localResolveTimingSummary(output_struct)
if isfield(output_struct, 'part_timing_summary') && ...
        isstruct(output_struct.part_timing_summary) && ...
        isscalar(output_struct.part_timing_summary)
    timing_summary = output_struct.part_timing_summary;
    return
end

part_start_offsets_s = localGetNumericVectorField(output_struct, 'part_start_offsets_s', zeros(0, 1));
part_duration_s = localGetNumericField(output_struct, 'part_duration_s', NaN);
if ~isfinite(part_duration_s) && isfield(output_struct, 'truth_diag_input') && ...
        isstruct(output_struct.truth_diag_input) && ...
        isfield(output_struct.truth_diag_input, 'part_dur_s')
    part_duration_s = localGetNumericField(output_struct.truth_diag_input, 'part_dur_s', NaN);
end

part_timing_info = localGetStructField(output_struct, 'part_timing_info');
requested_source = "";
resolved_source = "";
used_metadata = false(numel(part_start_offsets_s), 1);
if isfield(part_timing_info, 'requested_source')
    requested_source = string(part_timing_info.requested_source);
end
if isfield(part_timing_info, 'source')
    resolved_source = string(part_timing_info.source);
end
if isfield(part_timing_info, 'used_metadata') && ...
        numel(part_timing_info.used_metadata) == numel(part_start_offsets_s)
    used_metadata = logical(part_timing_info.used_metadata(:));
end

start_spacing_s = diff(part_start_offsets_s);
inter_part_gap_s = start_spacing_s - part_duration_s;

timing_summary = struct( ...
    'requested_source', requested_source, ...
    'resolved_source', resolved_source, ...
    'n_parts', numel(part_start_offsets_s), ...
    'part_duration_s', part_duration_s, ...
    'part_start_offsets_s', part_start_offsets_s, ...
    'start_spacing_s', start_spacing_s, ...
    'inter_part_gap_s', inter_part_gap_s, ...
    'median_start_spacing_s', localMedianOrNaN(start_spacing_s), ...
    'median_gap_s', localMedianOrNaN(inter_part_gap_s), ...
    'used_metadata', used_metadata, ...
    'n_metadata_parts', nnz(used_metadata));
end

function track_table = localResolveTrackTable(truth_metrics)
track_table = table();
if isfield(truth_metrics, 'trk_table') && istable(truth_metrics.trk_table)
    track_table = truth_metrics.trk_table;
end
end

function track_stats = localSummarizeTrackTable(track_table)
track_stats = struct( ...
    'n_tracks', 0, ...
    'mean_range_bias_m', NaN, ...
    'mean_range_rmse_m', NaN, ...
    'mean_doppler_bias_hz', NaN, ...
    'mean_doppler_rmse_hz', NaN);

if ~istable(track_table) || isempty(track_table)
    return
end

track_stats.n_tracks = height(track_table);
track_stats.mean_range_bias_m = localMeanTableColumn(track_table, 'range_bias_m');
track_stats.mean_range_rmse_m = localMeanTableColumn(track_table, 'range_rmse_m');
track_stats.mean_doppler_bias_hz = localMeanTableColumn(track_table, 'doppler_bias_hz');
track_stats.mean_doppler_rmse_hz = localMeanTableColumn(track_table, 'doppler_rmse_hz');
end

function value = localMeanTableColumn(track_table, variable_name)
value = NaN;
if ~any(strcmp(track_table.Properties.VariableNames, variable_name))
    return
end

column = track_table.(variable_name);
column = column(isfinite(column));
if isempty(column)
    return
end

value = mean(column);
end

function summary_table = localBuildSummaryTable(metadata_summary, fallback_summary)
summary_table = table( ...
    [metadata_summary.mode; fallback_summary.mode], ...
    [metadata_summary.requested_source; fallback_summary.requested_source], ...
    [metadata_summary.resolved_source; fallback_summary.resolved_source], ...
    [metadata_summary.n_parts; fallback_summary.n_parts], ...
    [metadata_summary.n_metadata_parts; fallback_summary.n_metadata_parts], ...
    [metadata_summary.part_duration_s; fallback_summary.part_duration_s], ...
    [metadata_summary.median_start_spacing_s; fallback_summary.median_start_spacing_s], ...
    [metadata_summary.median_gap_s; fallback_summary.median_gap_s], ...
    [metadata_summary.n_detections; fallback_summary.n_detections], ...
    [metadata_summary.n_tp; fallback_summary.n_tp], ...
    [metadata_summary.n_fa; fallback_summary.n_fa], ...
    [metadata_summary.n_miss; fallback_summary.n_miss], ...
    [metadata_summary.n_tracks; fallback_summary.n_tracks], ...
    [metadata_summary.mean_track_range_bias_m; fallback_summary.mean_track_range_bias_m], ...
    [metadata_summary.mean_track_range_rmse_m; fallback_summary.mean_track_range_rmse_m], ...
    [metadata_summary.mean_track_doppler_bias_hz; fallback_summary.mean_track_doppler_bias_hz], ...
    [metadata_summary.mean_track_doppler_rmse_hz; fallback_summary.mean_track_doppler_rmse_hz], ...
    'VariableNames', { ...
        'mode', 'requested_source', 'resolved_source', 'n_parts', ...
        'n_metadata_parts', 'part_duration_s', 'median_start_spacing_s', ...
        'median_gap_s', 'n_detections', 'n_tp', 'n_fa', 'n_miss', ...
        'n_tracks', 'mean_track_range_bias_m', 'mean_track_range_rmse_m', ...
        'mean_track_doppler_bias_hz', 'mean_track_doppler_rmse_hz'});
end

function delta_table = localBuildDeltaTable(metadata_summary, fallback_summary)
delta_table = table( ...
    "metadata_minus_fallback", ...
    metadata_summary.median_start_spacing_s - fallback_summary.median_start_spacing_s, ...
    metadata_summary.median_gap_s - fallback_summary.median_gap_s, ...
    metadata_summary.n_detections - fallback_summary.n_detections, ...
    metadata_summary.n_tp - fallback_summary.n_tp, ...
    metadata_summary.n_fa - fallback_summary.n_fa, ...
    metadata_summary.n_miss - fallback_summary.n_miss, ...
    metadata_summary.mean_track_range_bias_m - fallback_summary.mean_track_range_bias_m, ...
    metadata_summary.mean_track_range_rmse_m - fallback_summary.mean_track_range_rmse_m, ...
    metadata_summary.mean_track_doppler_bias_hz - fallback_summary.mean_track_doppler_bias_hz, ...
    metadata_summary.mean_track_doppler_rmse_hz - fallback_summary.mean_track_doppler_rmse_hz, ...
    'VariableNames', { ...
        'comparison', 'median_start_spacing_delta_s', 'median_gap_delta_s', ...
        'n_detections_delta', 'n_tp_delta', 'n_fa_delta', 'n_miss_delta', ...
        'mean_track_range_bias_delta_m', 'mean_track_range_rmse_delta_m', ...
        'mean_track_doppler_bias_delta_hz', 'mean_track_doppler_rmse_delta_hz'});
end

function reference_summary = localParseReferenceLog(reference_log_path)
reference_summary = struct( ...
    'available', false, ...
    'path', string(reference_log_path), ...
    'timing_source', "", ...
    'part_start_offsets_s', zeros(0, 1), ...
    'n_detections', NaN, ...
    'n_tp', NaN, ...
    'n_fa', NaN, ...
    'n_miss', NaN, ...
    'gate_range_m', NaN, ...
    'gate_doppler_hz', NaN, ...
    'time_gate_s', NaN);

reference_log_path = string(reference_log_path);
if strlength(reference_log_path) == 0 || exist(char(reference_log_path), 'file') ~= 2
    return
end

lines = splitlines(string(fileread(char(reference_log_path))));
part_offsets = zeros(0, 1);

for iLine = 1 : numel(lines)
    line = strtrim(lines(iLine));
    if strlength(line) == 0
        continue
    end

    if startsWith(line, "[helperGetPartStartOffsets] Timing source:")
        reference_summary.timing_source = strtrim(extractAfter(line, ":"));
        continue
    end

    tok = regexp(char(line), 'Part\s+\d+\s+start offset:\s*([0-9.+-]+)\s*s', 'tokens', 'once');
    if ~isempty(tok)
        part_offsets(end + 1, 1) = str2double(tok{1});
        continue
    end

    tok = regexp(char(line), ...
        'Total detections:\s*(\d+)\s*\|\s*TP:\s*(\d+)\s*\|\s*FA:\s*(\d+)\s*\|\s*Missed:\s*(\d+)', ...
        'tokens', 'once');
    if ~isempty(tok)
        reference_summary.n_detections = str2double(tok{1});
        reference_summary.n_tp = str2double(tok{2});
        reference_summary.n_fa = str2double(tok{3});
        reference_summary.n_miss = str2double(tok{4});
        continue
    end

    if contains(line, "Gate:")
        tok = regexp(char(line), '([0-9.+-]+)\s*m.*?([0-9.+-]+)\s*Hz', 'tokens', 'once');
        if ~isempty(tok)
            reference_summary.gate_range_m = str2double(tok{1});
            reference_summary.gate_doppler_hz = str2double(tok{2});
        end
        continue
    end

    if contains(line, "Time gate:")
        tok = regexp(char(line), '([0-9.+-]+)\s*s', 'tokens', 'once');
        if ~isempty(tok)
            reference_summary.time_gate_s = str2double(tok{1});
        end
    end
end

reference_summary.available = true;
reference_summary.part_start_offsets_s = part_offsets;
end

function assessment = localAssessComparison(metadata_summary, fallback_summary, reference_summary)
notes = strings(0, 1);
preferred_mode = localChoosePreferredMode(metadata_summary, fallback_summary);
timing_sensitive = localMetricsDiffer(metadata_summary, fallback_summary);

if strlength(preferred_mode) > 0
    notes(end + 1) = "Preferred timing mode by truth metrics: " + preferred_mode + ".";
end

if timing_sensitive
    notes(end + 1) = "Metadata and fallback timing do not collapse to the same top-level metrics.";
else
    notes(end + 1) = "Metadata and fallback timing produced the same top-level metrics.";
end

if isfinite(metadata_summary.n_tp) && isfinite(fallback_summary.n_tp) && ...
        isfinite(metadata_summary.n_fa) && isfinite(fallback_summary.n_fa) && ...
        metadata_summary.n_tp == fallback_summary.n_tp && ...
        metadata_summary.n_fa == fallback_summary.n_fa
    notes(end + 1) = "Because TP and FA are unchanged, timing is unlikely to be the main explanation for TP=0.";
end

metadata_improved_vs_reference = false;
fallback_improved_vs_reference = false;

if reference_summary.available
    metadata_improved_vs_reference = localBeatsReference(metadata_summary, reference_summary);
    fallback_improved_vs_reference = localBeatsReference(fallback_summary, reference_summary);

    if xor(metadata_improved_vs_reference, fallback_improved_vs_reference)
        timing_sensitive = true;
        if metadata_improved_vs_reference
            notes(end + 1) = "Only metadata timing improved against the pre-patch reference.";
        else
            notes(end + 1) = "Only fallback timing improved against the pre-patch reference.";
        end
    elseif metadata_improved_vs_reference && fallback_improved_vs_reference
        notes(end + 1) = "Both timing modes improved against the pre-patch reference.";
    else
        notes(end + 1) = "Neither timing mode improved against the pre-patch reference on TP/FA counts.";
    end
end

assessment = struct( ...
    'preferred_mode', preferred_mode, ...
    'timing_sensitive', timing_sensitive, ...
    'metadata_improved_vs_reference', metadata_improved_vs_reference, ...
    'fallback_improved_vs_reference', fallback_improved_vs_reference, ...
    'notes', notes);
end

function preferred_mode = localChoosePreferredMode(metadata_summary, fallback_summary)
preferred_mode = "";

if localCompareHigherIsBetter(metadata_summary.n_tp, fallback_summary.n_tp)
    preferred_mode = "metadata";
    return
elseif localCompareHigherIsBetter(fallback_summary.n_tp, metadata_summary.n_tp)
    preferred_mode = "fallback";
    return
end

if localCompareLowerIsBetter(metadata_summary.n_fa, fallback_summary.n_fa)
    preferred_mode = "metadata";
    return
elseif localCompareLowerIsBetter(fallback_summary.n_fa, metadata_summary.n_fa)
    preferred_mode = "fallback";
    return
end

if localCompareLowerIsBetter(metadata_summary.n_miss, fallback_summary.n_miss)
    preferred_mode = "metadata";
    return
elseif localCompareLowerIsBetter(fallback_summary.n_miss, metadata_summary.n_miss)
    preferred_mode = "fallback";
    return
end

if localCompareLowerIsBetter(metadata_summary.mean_track_range_rmse_m, fallback_summary.mean_track_range_rmse_m)
    preferred_mode = "metadata";
    return
elseif localCompareLowerIsBetter(fallback_summary.mean_track_range_rmse_m, metadata_summary.mean_track_range_rmse_m)
    preferred_mode = "fallback";
end
end

function tf = localBeatsReference(mode_summary, reference_summary)
tf = false;

if localCompareHigherIsBetter(mode_summary.n_tp, reference_summary.n_tp)
    tf = true;
    return
end

if isfinite(mode_summary.n_tp) && isfinite(reference_summary.n_tp) && ...
        mode_summary.n_tp == reference_summary.n_tp
    if localCompareLowerIsBetter(mode_summary.n_fa, reference_summary.n_fa)
        tf = true;
        return
    end

    if isfinite(mode_summary.n_fa) && isfinite(reference_summary.n_fa) && ...
            mode_summary.n_fa == reference_summary.n_fa && ...
            localCompareLowerIsBetter(mode_summary.n_miss, reference_summary.n_miss)
        tf = true;
    end
end
end

function tf = localMetricsDiffer(metadata_summary, fallback_summary)
tol = 1e-9;

numeric_fields = { ...
    'median_start_spacing_s', ...
    'median_gap_s', ...
    'n_detections', ...
    'n_tp', ...
    'n_fa', ...
    'n_miss', ...
    'mean_track_range_rmse_m', ...
    'mean_track_doppler_rmse_hz'};

for k = 1 : numel(numeric_fields)
    field_name = numeric_fields{k};
    a = metadata_summary.(field_name);
    b = fallback_summary.(field_name);
    if localFiniteDifference(a, b, tol)
        tf = true;
        return
    end
end

tf = metadata_summary.resolved_source ~= fallback_summary.resolved_source;
end

function tf = localFiniteDifference(a, b, tol)
if isfinite(a) && isfinite(b)
    tf = abs(a - b) > tol;
else
    tf = xor(isfinite(a), isfinite(b));
end
end

function tf = localCompareHigherIsBetter(a, b)
tf = isfinite(a) && (~isfinite(b) || a > b);
end

function tf = localCompareLowerIsBetter(a, b)
tf = isfinite(a) && (~isfinite(b) || a < b);
end

function value = localGetNumericField(source_struct, field_name, default_value)
value = default_value;
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    return
end

candidate = source_struct.(field_name);
if isnumeric(candidate) && isscalar(candidate)
    value = double(candidate);
end
end

function values = localGetNumericVectorField(source_struct, field_name, default_value)
values = default_value;
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    return
end

candidate = source_struct.(field_name);
if isnumeric(candidate) && isvector(candidate)
    values = double(candidate(:));
end
end

function value = localGetStructField(source_struct, field_name)
value = struct();
if isstruct(source_struct) && isfield(source_struct, field_name) && ...
        isstruct(source_struct.(field_name))
    value = source_struct.(field_name);
end
end

function value = localMedianOrNaN(x)
if isempty(x)
    value = NaN;
else
    value = median(x, 'omitnan');
end
end
