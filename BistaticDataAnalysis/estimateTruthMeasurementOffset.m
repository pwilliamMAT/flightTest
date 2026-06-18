function offset_diag = estimateTruthMeasurementOffset(diag_source, varargin)
%ESTIMATETRUTHMEASUREMENTOFFSET Estimate a global measurement offset vs ADS-B truth.
%
% Plain-language goal:
%   If metadata and fallback timing both still produce TP=0, the next
%   question is whether the detector outputs are clustered at a roughly
%   constant bistatic range and Doppler offset from the projected ADS-B
%   truth. This helper builds a 2-D histogram of detection-minus-truth
%   residuals for candidate pairs that are close in time, identifies the
%   strongest residual cluster, and then re-scores the detections after
%   compensating by that estimated offset.
%
% Syntax
%   offset_diag = estimateTruthMeasurementOffset(out_meta)
%   offset_diag = estimateTruthMeasurementOffset(truth_diag_output)
%
% Input
%   diag_source    Output struct from runBistaticAnalysisSession or
%                  runDetectionTruthDiagnostics. Required data:
%                    - aligned truth (`adsb_aligned`)
%                    - detections (`truth_metrics.det_table` or
%                      `all_track_dets`)
%
% Name-value options
%   'TimeGateS'            Pairing time gate [s]. Default: use the saved
%                          truth-metric gate when available.
%   'RangeCellM'           Detector range spacing [m]. Default: saved value
%                          when available, else 30.
%   'DopplerBinHz'         Detector Doppler spacing [Hz]. Default: saved
%                          value when available, else 10.
%   'GateRangeM'           Detection-truth range gate [m] used for the
%                          zero-offset and compensated rescoring passes.
%   'GateDopplerHz'        Detection-truth Doppler gate [Hz] used for the
%                          rescoring passes.
%   'RangeBinWidthM'       Histogram bin width for residual ΔR [m].
%   'DopplerBinWidthHz'    Histogram bin width for residual Δf [Hz].
%   'MaxRangeOffsetM'      Residual-map half-span in ΔR [m]. Default: 40 km.
%   'MaxDopplerOffsetHz'   Residual-map half-span in Δf [Hz]. Default: 1 kHz.
%   'Plot'                 Show the residual heatmap. Default: true.
%   'Verbose'              Print summary output. Default: true.
%
% Output
%   offset_diag    Struct containing:
%     .summary
%     .zero_offset_metrics
%     .compensated_metrics
%     .candidate_pairs
%     .hist_counts
%     .range_offset_centers_m
%     .doppler_offset_centers_hz
%     .figure_handle
%
% See also: assessTruthVsDetections, runDetectionTruthDiagnostics,
%           runTruthFixTimingComparison.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'diag_source');
addParameter(p, 'TimeGateS', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'RangeCellM', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'DopplerBinHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'GateRangeM', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'GateDopplerHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'RangeBinWidthM', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'DopplerBinWidthHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'MaxRangeOffsetM', 40e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxDopplerOffsetHz', 1e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Plot', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, diag_source, varargin{:});
opts = p.Results;

[det_table, adsb_aligned, analysis_label, saved_metrics, saved_consts] = ...
    localResolveDiagnosticInputs(diag_source);

time_gate_s = localResolveTimeGate(opts.TimeGateS, saved_metrics, adsb_aligned);
range_cell_m = localResolvePositiveScalar(opts.RangeCellM, saved_consts.range_cell_m, 30);
doppler_bin_hz = localResolvePositiveScalar(opts.DopplerBinHz, saved_consts.doppler_bin_hz, 10);
gate_range_m = localResolvePositiveScalar(opts.GateRangeM, saved_metrics.gate_range_m, 3 * range_cell_m);
gate_doppler_hz = localResolvePositiveScalar(opts.GateDopplerHz, saved_metrics.gate_doppler_hz, 3 * doppler_bin_hz);
range_bin_width_m = localResolvePositiveScalar(opts.RangeBinWidthM, [], max(range_cell_m, gate_range_m / 2));
doppler_bin_width_hz = localResolvePositiveScalar(opts.DopplerBinWidthHz, [], max(doppler_bin_hz, gate_doppler_hz / 2));

[candidate_pairs, hist_counts, range_centers_m, doppler_centers_hz] = ...
    localBuildResidualMap(det_table, adsb_aligned, time_gate_s, ...
    opts.MaxRangeOffsetM, opts.MaxDopplerOffsetHz, ...
    range_bin_width_m, doppler_bin_width_hz);

[best_range_offset_m, best_doppler_offset_hz, best_pair_count] = ...
    localEstimateBestOffset(candidate_pairs, hist_counts, range_centers_m, doppler_centers_hz);

zero_offset_metrics = assessTruthVsDetections(det_table, [], adsb_aligned, ...
    'RangeCellM', range_cell_m, ...
    'DopplerBinHz', doppler_bin_hz, ...
    'GateRangeCells', gate_range_m / range_cell_m, ...
    'GateDopplerBins', gate_doppler_hz / doppler_bin_hz, ...
    'TimeGateS', time_gate_s, ...
    'Verbose', false);

comp_det_table = det_table;
comp_det_table.R_excess_m = comp_det_table.R_excess_m - best_range_offset_m;
comp_det_table.f_D_hz = comp_det_table.f_D_hz - best_doppler_offset_hz;

compensated_metrics = assessTruthVsDetections(comp_det_table, [], adsb_aligned, ...
    'RangeCellM', range_cell_m, ...
    'DopplerBinHz', doppler_bin_hz, ...
    'GateRangeCells', gate_range_m / range_cell_m, ...
    'GateDopplerBins', gate_doppler_hz / doppler_bin_hz, ...
    'TimeGateS', time_gate_s, ...
    'Verbose', false);

summary = struct( ...
    'analysis_label', analysis_label, ...
    'n_detections', height(det_table), ...
    'n_candidate_pairs', height(candidate_pairs), ...
    'time_gate_s', time_gate_s, ...
    'gate_range_m', gate_range_m, ...
    'gate_doppler_hz', gate_doppler_hz, ...
    'range_bin_width_m', range_bin_width_m, ...
    'doppler_bin_width_hz', doppler_bin_width_hz, ...
    'estimated_range_offset_m', best_range_offset_m, ...
    'estimated_doppler_offset_hz', best_doppler_offset_hz, ...
    'best_bin_pair_count', best_pair_count, ...
    'zero_tp', zero_offset_metrics.n_tp, ...
    'zero_fa', zero_offset_metrics.n_fa, ...
    'zero_miss', zero_offset_metrics.n_miss, ...
    'comp_tp', compensated_metrics.n_tp, ...
    'comp_fa', compensated_metrics.n_fa, ...
    'comp_miss', compensated_metrics.n_miss);

fig = gobjects(0, 1);
if opts.Plot
    fig = localPlotResidualMap(hist_counts, range_centers_m, doppler_centers_hz, ...
        best_range_offset_m, best_doppler_offset_hz, summary);
end

offset_diag = struct( ...
    'summary', summary, ...
    'zero_offset_metrics', zero_offset_metrics, ...
    'compensated_metrics', compensated_metrics, ...
    'candidate_pairs', candidate_pairs, ...
    'hist_counts', hist_counts, ...
    'range_offset_centers_m', range_centers_m(:), ...
    'doppler_offset_centers_hz', doppler_centers_hz(:), ...
    'figure_handle', fig);

if opts.Verbose
    fprintf('\n[estimateTruthMeasurementOffset] %s\n', char(analysis_label));
    fprintf('  Detections .............. %d\n', height(det_table));
    fprintf('  Candidate pairs ......... %d (|Δt| < %.3f s)\n', ...
        height(candidate_pairs), time_gate_s);
    fprintf('  Strongest offset cluster  ΔR = %.0f m,  Δf = %.1f Hz  (%d pair(s))\n', ...
        best_range_offset_m, best_doppler_offset_hz, best_pair_count);
    fprintf('  Zero-offset scoring ..... TP=%d  FA=%d  miss=%d\n', ...
        zero_offset_metrics.n_tp, zero_offset_metrics.n_fa, zero_offset_metrics.n_miss);
    fprintf('  Compensated scoring ..... TP=%d  FA=%d  miss=%d\n', ...
        compensated_metrics.n_tp, compensated_metrics.n_fa, compensated_metrics.n_miss);
end

end

function [det_table, adsb_aligned, analysis_label, saved_metrics, saved_consts] = ...
        localResolveDiagnosticInputs(diag_source)
if ~(isstruct(diag_source) && isscalar(diag_source))
    error('estimateTruthMeasurementOffset:badInput', ...
        'diag_source must be a scalar struct from runBistaticAnalysisSession or runDetectionTruthDiagnostics.');
end

if isfield(diag_source, 'truth_diag_output') && isstruct(diag_source.truth_diag_output)
    diag_source = diag_source.truth_diag_output;
end

if isfield(diag_source, 'adsb_aligned') && isstruct(diag_source.adsb_aligned)
    adsb_aligned = diag_source.adsb_aligned;
else
    error('estimateTruthMeasurementOffset:missingTruth', ...
        'diag_source does not contain adsb_aligned.');
end

saved_metrics = struct( ...
    'gate_range_m', NaN, ...
    'gate_doppler_hz', NaN, ...
    'time_gate_s', NaN);
if isfield(diag_source, 'truth_metrics') && isstruct(diag_source.truth_metrics)
    if isfield(diag_source.truth_metrics, 'gate_range_m')
        saved_metrics.gate_range_m = diag_source.truth_metrics.gate_range_m;
    end
    if isfield(diag_source.truth_metrics, 'gate_doppler_hz')
        saved_metrics.gate_doppler_hz = diag_source.truth_metrics.gate_doppler_hz;
    end
    if isfield(diag_source.truth_metrics, 'time_gate_s')
        saved_metrics.time_gate_s = diag_source.truth_metrics.time_gate_s;
    end
end

saved_consts = struct('range_cell_m', NaN, 'doppler_bin_hz', NaN);
if isfield(diag_source, 'truth_diag_input') && isstruct(diag_source.truth_diag_input)
    if isfield(diag_source.truth_diag_input, 'range_cell_m')
        saved_consts.range_cell_m = diag_source.truth_diag_input.range_cell_m;
    end
    if isfield(diag_source.truth_diag_input, 'doppler_bin_hz')
        saved_consts.doppler_bin_hz = diag_source.truth_diag_input.doppler_bin_hz;
    end
elseif isfield(diag_source, 'range_cell_m')
    saved_consts.range_cell_m = diag_source.range_cell_m;
    if isfield(diag_source, 'doppler_bin_hz')
        saved_consts.doppler_bin_hz = diag_source.doppler_bin_hz;
    end
end

analysis_label = "Truth measurement offset diagnostic";
if isfield(diag_source, 'analysis_label') && ~isempty(diag_source.analysis_label)
    analysis_label = string(diag_source.analysis_label);
elseif isfield(diag_source, 'session_id') && ~isempty(diag_source.session_id)
    analysis_label = "Session " + string(diag_source.session_id);
end

det_table = localResolveDetectionTable(diag_source);
end

function det_table = localResolveDetectionTable(diag_source)
if isfield(diag_source, 'truth_metrics') && isstruct(diag_source.truth_metrics) && ...
        isfield(diag_source.truth_metrics, 'det_table') && ...
        istable(diag_source.truth_metrics.det_table) && ...
        ~isempty(diag_source.truth_metrics.det_table)
    det_table = diag_source.truth_metrics.det_table(:, {'t_abs_s', 'R_excess_m', 'f_D_hz'});
elseif isfield(diag_source, 'all_track_dets') && isnumeric(diag_source.all_track_dets) && ...
        size(diag_source.all_track_dets, 2) >= 5
    all_track_dets = diag_source.all_track_dets;
    det_table = table( ...
        all_track_dets(:, 5), ...
        all_track_dets(:, 1), ...
        all_track_dets(:, 2), ...
        'VariableNames', {'t_abs_s', 'R_excess_m', 'f_D_hz'});
else
    error('estimateTruthMeasurementOffset:missingDetections', ...
        'diag_source does not contain a usable detection table.');
end

valid = isfinite(det_table.t_abs_s) & isfinite(det_table.R_excess_m) & isfinite(det_table.f_D_hz);
det_table = det_table(valid, :);
end

function time_gate_s = localResolveTimeGate(time_gate_override, saved_metrics, adsb_aligned)
if ~isempty(time_gate_override)
    time_gate_s = time_gate_override;
elseif isfinite(saved_metrics.time_gate_s)
    time_gate_s = saved_metrics.time_gate_s;
else
    time_gate_s = localEstimateTruthTimeGate(adsb_aligned);
end
end

function time_gate_s = localEstimateTruthTimeGate(adsb_aligned)
dt_all = zeros(0, 1);
for k = 1 : numel(adsb_aligned)
    if ~isfield(adsb_aligned(k), 't_abs_s') || isempty(adsb_aligned(k).t_abs_s) || ...
            ~isfield(adsb_aligned(k), 'R_excess_m') || isempty(adsb_aligned(k).R_excess_m)
        continue
    end

    valid = isfinite(adsb_aligned(k).t_abs_s) & isfinite(adsb_aligned(k).R_excess_m);
    if isfield(adsb_aligned(k), 'f_D_hz')
        valid = valid & isfinite(adsb_aligned(k).f_D_hz);
    end

    t_valid = adsb_aligned(k).t_abs_s(valid);
    if numel(t_valid) >= 2
        dt_all = [dt_all; diff(t_valid(:))]; %#ok<AGROW>
    end
end

dt_all = dt_all(dt_all > 0);
if isempty(dt_all)
    time_gate_s = 0.5;
else
    time_gate_s = median(dt_all, 'omitnan');
end
end

function value = localResolvePositiveScalar(primary_value, secondary_value, default_value)
if ~isempty(primary_value) && isfinite(primary_value) && primary_value > 0
    value = primary_value;
elseif ~isempty(secondary_value) && isfinite(secondary_value) && secondary_value > 0
    value = secondary_value;
else
    value = default_value;
end
end

function [candidate_pairs, hist_counts, range_centers_m, doppler_centers_hz] = ...
        localBuildResidualMap(det_table, adsb_aligned, time_gate_s, ...
        max_range_offset_m, max_doppler_offset_hz, ...
        range_bin_width_m, doppler_bin_width_hz)

truth_table = localFlattenTruthSamples(adsb_aligned);

det_idx_all = zeros(0, 1);
truth_idx_all = zeros(0, 1);
dt_all = zeros(0, 1);
dR_all = zeros(0, 1);
df_all = zeros(0, 1);

for iDet = 1 : height(det_table)
    dt_vec = det_table.t_abs_s(iDet) - truth_table.t_abs_s;
    in_time = abs(dt_vec) <= time_gate_s;
    if ~any(in_time)
        continue
    end

    dR_vec = det_table.R_excess_m(iDet) - truth_table.R_excess_m;
    df_vec = det_table.f_D_hz(iDet) - truth_table.f_D_hz;
    in_extent = in_time & abs(dR_vec) <= max_range_offset_m & ...
        abs(df_vec) <= max_doppler_offset_hz;
    if ~any(in_extent)
        continue
    end

    truth_idx = find(in_extent);
    n_add = numel(truth_idx);
    det_idx_all = [det_idx_all; repmat(iDet, n_add, 1)]; %#ok<AGROW>
    truth_idx_all = [truth_idx_all; truth_idx(:)]; %#ok<AGROW>
    dt_all = [dt_all; dt_vec(in_extent)]; %#ok<AGROW>
    dR_all = [dR_all; dR_vec(in_extent)]; %#ok<AGROW>
    df_all = [df_all; df_vec(in_extent)]; %#ok<AGROW>
end

range_centers_m = (-max_range_offset_m : range_bin_width_m : max_range_offset_m).';
doppler_centers_hz = (-max_doppler_offset_hz : doppler_bin_width_hz : max_doppler_offset_hz).';
range_edges_m = [range_centers_m - range_bin_width_m / 2; range_centers_m(end) + range_bin_width_m / 2];
doppler_edges_hz = [doppler_centers_hz - doppler_bin_width_hz / 2; doppler_centers_hz(end) + doppler_bin_width_hz / 2];

hist_counts = zeros(numel(range_centers_m), numel(doppler_centers_hz));
range_bin_idx = zeros(size(dR_all));
doppler_bin_idx = zeros(size(df_all));
if ~isempty(dR_all)
    [hist_counts, ~, ~, range_bin_idx, doppler_bin_idx] = ...
        histcounts2(dR_all, df_all, range_edges_m, doppler_edges_hz);
end

if isempty(det_idx_all)
    candidate_pairs = table();
    return
end

candidate_pairs = table( ...
    det_idx_all, truth_idx_all, dt_all, dR_all, df_all, range_bin_idx, doppler_bin_idx, ...
    'VariableNames', {'det_index', 'truth_index', 'dt_s', 'dR_m', 'df_hz', ...
                      'range_bin_index', 'doppler_bin_index'});
end

function truth_table = localFlattenTruthSamples(adsb_aligned)
t_abs_s = zeros(0, 1);
R_excess_m = zeros(0, 1);
f_D_hz = zeros(0, 1);

for k = 1 : numel(adsb_aligned)
    valid = isfinite(adsb_aligned(k).t_abs_s) & ...
        isfinite(adsb_aligned(k).R_excess_m) & ...
        isfinite(adsb_aligned(k).f_D_hz);
    if ~any(valid)
        continue
    end

    t_abs_s = [t_abs_s; adsb_aligned(k).t_abs_s(valid)]; %#ok<AGROW>
    R_excess_m = [R_excess_m; adsb_aligned(k).R_excess_m(valid)]; %#ok<AGROW>
    f_D_hz = [f_D_hz; adsb_aligned(k).f_D_hz(valid)]; %#ok<AGROW>
end

truth_table = table(t_abs_s, R_excess_m, f_D_hz);
end

function [best_range_offset_m, best_doppler_offset_hz, best_pair_count] = ...
        localEstimateBestOffset(candidate_pairs, hist_counts, range_centers_m, doppler_centers_hz)
best_range_offset_m = 0;
best_doppler_offset_hz = 0;
best_pair_count = 0;

if isempty(candidate_pairs) || isempty(hist_counts)
    return
end

[best_pair_count, linear_idx] = max(hist_counts(:));
if best_pair_count <= 0
    return
end

[range_idx, doppler_idx] = ind2sub(size(hist_counts), linear_idx);
best_mask = candidate_pairs.range_bin_index == range_idx & ...
    candidate_pairs.doppler_bin_index == doppler_idx;

best_range_offset_m = range_centers_m(range_idx);
best_doppler_offset_hz = doppler_centers_hz(doppler_idx);

if any(best_mask)
    best_range_offset_m = median(candidate_pairs.dR_m(best_mask), 'omitnan');
    best_doppler_offset_hz = median(candidate_pairs.df_hz(best_mask), 'omitnan');
end
end

function fig = localPlotResidualMap(hist_counts, range_centers_m, doppler_centers_hz, ...
        best_range_offset_m, best_doppler_offset_hz, summary)
bg = [0.08, 0.08, 0.08];
fg = [0.90, 0.90, 0.90];

fig = figure('Name', 'Truth Measurement Offset Diagnostic', ...
    'NumberTitle', 'off', 'Color', bg, 'Position', [140, 120, 980, 720]);
ax = axes(fig, 'Color', bg, 'XColor', fg, 'YColor', fg, 'FontSize', 10);
imagesc(ax, doppler_centers_hz, range_centers_m, hist_counts);
set(ax, 'YDir', 'normal');
colormap(ax, 'turbo');
hold(ax, 'on');
scatter(ax, best_doppler_offset_hz, best_range_offset_m, 120, 'w', 'x', 'LineWidth', 2.0, ...
    'DisplayName', 'Estimated offset');
xlabel(ax, 'Residual Doppler: detection - truth (Hz)', 'Color', fg);
ylabel(ax, 'Residual bistatic range: detection - truth (m)', 'Color', fg);
title(ax, sprintf(['Residual offset map | best ΔR = %.0f m, best Δf = %.1f Hz | ' ...
    'TP %d → %d'], ...
    summary.estimated_range_offset_m, summary.estimated_doppler_offset_hz, ...
    summary.zero_tp, summary.comp_tp), 'Color', fg);
cb = colorbar(ax, 'eastoutside');
cb.Color = fg;
cb.Label.String = 'Candidate pair count';
legend(ax, 'Location', 'northeast', 'TextColor', fg, 'Color', [0.18, 0.18, 0.18]);
end
