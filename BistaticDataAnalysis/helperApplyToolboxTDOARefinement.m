function [part_detections_out, all_track_dets_out, refinement_info] = ...
    helperApplyToolboxTDOARefinement(detector_replay_input, part_detections_in, varargin)
%HELPERAPPLYTOOLBOXTDOAREFINEMENT Re-measure detection ranges with phased.TDOAEstimator.
%
% Plain-language goal:
%   Start from an existing detection table, keep each detection's Doppler,
%   time, and block assignment, and only replace its bistatic range excess
%   with a toolbox-based TDOA estimate measured on the original signal
%   block. This isolates the timing/range measurement comparison from the
%   detector comparison.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'detector_replay_input', @(x) isstruct(x) && isfield(x, 'detector_parts'));
addRequired(p, 'part_detections_in', @(x) iscell(x));
addParameter(p, 'SearchWindowSamples', 6, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'Verbose', false, @islogical);
parse(p, detector_replay_input, part_detections_in, varargin{:});
opts = p.Results;

signal_cfg = localResolveSignalConfig(detector_replay_input);
n_parts = numel(detector_replay_input.detector_parts);

if numel(part_detections_in) ~= n_parts
    error('helperApplyToolboxTDOARefinement:partCountMismatch', ...
        'part_detections_in must contain one cell per detector_replay_input.detector_parts entry.');
end

part_detections_out = part_detections_in;
refinement_info = repmat(struct( ...
    'part_index', 0, ...
    'data_part', "", ...
    'direct_path_delay_s', NaN, ...
    'clutter_alignment_lag_samples', NaN, ...
    'block_results', struct([])), 1, n_parts);

for ip = 1 : n_parts
    refinement_info(ip).part_index = ip;
    refinement_info(ip).data_part = string(detector_replay_input.detector_parts(ip).data_part);

    if isempty(part_detections_out{ip})
        refinement_info(ip).block_results = struct([]);
        continue
    end

    data_part = char(refinement_info(ip).data_part);
    if exist(data_part, 'file') ~= 2
        error('helperApplyToolboxTDOARefinement:missingRadarFile', ...
            'Radar file not found for part %d: %s', ip, data_part);
    end

    if opts.Verbose
        fprintf('[helperApplyToolboxTDOARefinement] Loading part %d/%d: %s\n', ...
            ip, n_parts, data_part);
    end

    [~, ~, ref_cube, surv_cube] = loadIQData( ...
        data_part, signal_cfg.num_samples, signal_cfg.cpi_duration_s, signal_cfg.fs, ...
        struct('swap_channels', signal_cfg.swap_channels, 'verbose', false));

    first_chunk_cols = 1 : min(signal_cfg.N_slow_cpi, size(ref_cube, 2));
    direct_path_delay_s = localEstimateDirectPathDelay( ...
        ref_cube(:, first_chunk_cols), surv_cube(:, first_chunk_cols), signal_cfg.fs);
    clutter_alignment_lag_samples = localEstimateClutterAlignmentLag( ...
        ref_cube(:, first_chunk_cols), surv_cube(:, first_chunk_cols), ...
        signal_cfg.fs, signal_cfg.prf);
    refinement_info(ip).direct_path_delay_s = direct_path_delay_s;
    refinement_info(ip).clutter_alignment_lag_samples = clutter_alignment_lag_samples;

    block_ids = unique(part_detections_out{ip}(:, 4), 'stable');
    block_results = repmat(struct( ...
        'block_num', 0, ...
        'ranges_before_m', zeros(0, 1), ...
        'ranges_after_m', zeros(0, 1), ...
        'estimates', struct([])), 1, numel(block_ids));

    tdoa_estimator = phased.TDOAEstimator( ...
        'SampleRate', signal_cfg.fs, ...
        'NumEstimates', 8);
    cleanup_tdoa = onCleanup(@() release(tdoa_estimator));

    for ib = 1 : numel(block_ids)
        block_num = block_ids(ib);
        block_meta = localResolveBlockMeta(detector_replay_input.detector_parts(ip), block_num);
        col_idx = localResolveBlockColumns(block_meta, signal_cfg, size(ref_cube, 2));
        ref_block = ref_cube(:, col_idx);
        surv_block = surv_cube(:, col_idx);

        % Filter once per block, then reuse the filtered block for each
        % detection in that block with different Doppler hypotheses.
        surv_block_filt = mitigateClutter( ...
            surv_block, ref_block, clutter_alignment_lag_samples, false);

        det_rows = find(part_detections_out{ip}(:, 4) == block_num);
        block_results(ib).block_num = block_num;
        block_results(ib).ranges_before_m = part_detections_out{ip}(det_rows, 1);
        block_results(ib).ranges_after_m = part_detections_out{ip}(det_rows, 1);
        block_results(ib).estimates = repmat(struct( ...
            'row_index', 0, ...
            'range_before_m', NaN, ...
            'range_after_m', NaN, ...
            'tdoa_info', struct()), 1, numel(det_rows));

        for id = 1 : numel(det_rows)
            row_idx = det_rows(id);
            range_before_m = part_detections_out{ip}(row_idx, 1);
            doppler_hz = part_detections_out{ip}(row_idx, 2);

            [range_after_m, tdoa_info] = helperEstimateToolboxTDOARange( ...
                ref_block, surv_block_filt, signal_cfg.fs, signal_cfg.prf, ...
                doppler_hz, direct_path_delay_s, range_before_m, ...
                'SearchWindowSamples', opts.SearchWindowSamples, ...
                'ApplyClutterMitigation', false, ...
                'TDOAEstimator', tdoa_estimator, ...
                'Verbose', false);

            part_detections_out{ip}(row_idx, 1) = range_after_m;
            block_results(ib).ranges_after_m(id) = range_after_m;
            block_results(ib).estimates(id) = struct( ...
                'row_index', row_idx, ...
                'range_before_m', range_before_m, ...
                'range_after_m', range_after_m, ...
                'tdoa_info', tdoa_info);
        end

        clear ref_block surv_block surv_block_filt
    end

    refinement_info(ip).block_results = block_results;
    clear ref_cube surv_cube
    clear cleanup_tdoa
end

all_track_dets_out = localStackPartDetections(part_detections_out);
end

function signal_cfg = localResolveSignalConfig(detector_replay_input)
signal_cfg = struct( ...
    'fs', NaN, ...
    'num_samples', NaN, ...
    'cpi_duration_s', NaN, ...
    'prf', NaN, ...
    'N_slow_cpi', NaN, ...
    'chunk_dur_s', NaN, ...
    'swap_channels', false);

if isfield(detector_replay_input, 'signal_config') && isstruct(detector_replay_input.signal_config)
    signal_cfg = localMergeStruct(signal_cfg, detector_replay_input.signal_config);
end

if ~(isfinite(signal_cfg.fs) && signal_cfg.fs > 0) && ...
        isfield(detector_replay_input, 'truth_diag_template') && ...
        isfield(detector_replay_input.truth_diag_template, 'fs')
    signal_cfg.fs = detector_replay_input.truth_diag_template.fs;
end

part_template = detector_replay_input.detector_parts(1);
if ~(isfinite(signal_cfg.N_slow_cpi) && signal_cfg.N_slow_cpi > 0) && ...
        isfield(part_template, 'doppler_axis') && numel(part_template.doppler_axis) >= 2
    signal_cfg.N_slow_cpi = numel(part_template.doppler_axis);
end

if ~(isfinite(signal_cfg.cpi_duration_s) && signal_cfg.cpi_duration_s > 0) && ...
        isfinite(signal_cfg.fs) && signal_cfg.fs > 0 && ...
        isfield(part_template, 'range_axis') && ~isempty(part_template.range_axis)
    n_fast = numel(part_template.range_axis);
    signal_cfg.cpi_duration_s = n_fast / signal_cfg.fs;
end

if ~(isfinite(signal_cfg.prf) && signal_cfg.prf > 0) && ...
        isfinite(signal_cfg.cpi_duration_s) && signal_cfg.cpi_duration_s > 0
    signal_cfg.prf = 1 / signal_cfg.cpi_duration_s;
end

if ~(isfinite(signal_cfg.chunk_dur_s) && signal_cfg.chunk_dur_s > 0) && ...
        isfinite(signal_cfg.N_slow_cpi) && signal_cfg.N_slow_cpi > 0 && ...
        isfinite(signal_cfg.prf) && signal_cfg.prf > 0
    signal_cfg.chunk_dur_s = signal_cfg.N_slow_cpi / signal_cfg.prf;
end

if ~(isfinite(signal_cfg.num_samples) && signal_cfg.num_samples > 0) && ...
        isfield(detector_replay_input, 'part_dur_s') && ...
        isfinite(detector_replay_input.part_dur_s) && detector_replay_input.part_dur_s > 0 && ...
        isfinite(signal_cfg.fs) && signal_cfg.fs > 0
    signal_cfg.num_samples = round(detector_replay_input.part_dur_s * signal_cfg.fs);
end

required_fields = {'fs', 'num_samples', 'cpi_duration_s', 'prf', 'N_slow_cpi', 'chunk_dur_s'};
for k = 1 : numel(required_fields)
    field_name = required_fields{k};
    if ~(isfinite(signal_cfg.(field_name)) && signal_cfg.(field_name) > 0)
        error('helperApplyToolboxTDOARefinement:missingSignalConfig', ...
            'Could not resolve detector_replay_input.signal_config.%s.', field_name);
    end
end
end

function direct_path_delay_s = localEstimateDirectPathDelay(ref_chunk, surv_chunk, fs)
ref_vec = ref_chunk(:);
surv_vec = surv_chunk(:);
signal_pair = zeros(numel(ref_vec), 1, 2, 'like', ref_vec);
signal_pair(:, :, 1) = ref_vec;
signal_pair(:, :, 2) = surv_vec;

estimator = phased.TDOAEstimator('SampleRate', fs, 'NumEstimates', 1);
cleanup_estimator = onCleanup(@() release(estimator));
direct_path_delay_s = estimator(signal_pair);
clear cleanup_estimator
end

function clutter_alignment_lag_samples = localEstimateClutterAlignmentLag( ...
    ref_chunk, surv_chunk, fs, prf)
[~, ~, ~, clutter_alignment_lag_samples] = createRDM( ...
    surv_chunk, ref_chunk, fs, prf, [], false);
end

function block_meta = localResolveBlockMeta(part_info, block_num)
block_idx = find([part_info.blocks.block_num] == block_num, 1, 'first');
if isempty(block_idx)
    error('helperApplyToolboxTDOARefinement:missingBlock', ...
        'Part %d does not contain block %d.', part_info.part_index, block_num);
end
block_meta = part_info.blocks(block_idx);
end

function col_idx = localResolveBlockColumns(block_meta, signal_cfg, n_cols_total)
block_duration_s = block_meta.look_count * signal_cfg.chunk_dur_s;
block_start_s = block_meta.t_part_center_s - 0.5 * block_duration_s;
first_col = max(1, round(block_start_s * signal_cfg.prf) + 1);
n_cols_block = block_meta.look_count * signal_cfg.N_slow_cpi;
last_col = min(n_cols_total, first_col + n_cols_block - 1);
col_idx = first_col:last_col;

if numel(col_idx) < n_cols_block
    warning('helperApplyToolboxTDOARefinement:truncatedBlock', ...
        ['Block %d expected %d slow-time columns but only %d were available. ' ...
         'Using the truncated block for TDOA refinement.'], ...
        block_meta.block_num, n_cols_block, numel(col_idx));
end
end

function all_track_dets = localStackPartDetections(part_detections)
rows_per_part = cellfun(@(dets_ip) size(dets_ip, 1), part_detections);
all_track_dets = zeros(sum(rows_per_part), 6);
row_cursor = 0;
for ip = 1 : numel(part_detections)
    dets_ip = part_detections{ip};
    if isempty(dets_ip)
        continue
    end
    row_count = size(dets_ip, 1);
    row_sel = row_cursor + (1 : row_count);
    all_track_dets(row_sel, :) = [dets_ip(:, 1:5), repmat(ip, row_count, 1)];
    row_cursor = row_cursor + row_count;
end

all_track_dets = all_track_dets(1:row_cursor, :);
if ~isempty(all_track_dets)
    [~, sort_idx] = sort(all_track_dets(:, 5));
    all_track_dets = all_track_dets(sort_idx, :);
end
end

function merged = localMergeStruct(base_struct, override_struct)
merged = base_struct;
override_fields = fieldnames(override_struct);
for k = 1 : numel(override_fields)
    field_name = override_fields{k};
    merged.(field_name) = override_struct.(field_name);
end
end
