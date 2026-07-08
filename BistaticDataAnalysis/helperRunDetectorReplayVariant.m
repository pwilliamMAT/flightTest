function [part_detections, all_track_dets, detector_stage_info] = ...
    helperRunDetectorReplayVariant(detector_replay_input, detector_backend, varargin)
%HELPERRUNDETECTORREPLAYVARIANT Re-run one detector implementation on replay blocks.
%
% Plain-language goal:
%   The replay bundle already contains the expensive upstream products:
%   whitened per-block RDMs plus the metadata needed to convert detections
%   back into measurement space. This helper swaps only the detector core
%   so the benchmark can compare the custom and toolbox CFAR paths on the
%   same cached blocks.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'detector_replay_input', @(x) isstruct(x) && isfield(x, 'detector_parts'));
addRequired(p, 'detector_backend', @(x) ischar(x) || isstring(x));
addParameter(p, 'CaseDefinition', struct(), @isstruct);
addParameter(p, 'Verbose', false, @islogical);
parse(p, detector_replay_input, detector_backend, varargin{:});
opts = p.Results;

backend = lower(char(string(opts.detector_backend)));
if ~ismember(backend, {'custom', 'toolbox'})
    error('helperRunDetectorReplayVariant:badBackend', ...
        'detector_backend must be ''custom'' or ''toolbox''.');
end

case_def = localResolveCaseDefinition(detector_replay_input, opts.CaseDefinition);
n_parts = numel(detector_replay_input.detector_parts);
part_detections = cell(1, n_parts);
detector_stage_info = repmat(struct( ...
    'part_index', 0, ...
    'n_blocks', 0, ...
    'n_detections', 0), 1, n_parts);
all_track_dets_parts = cell(1, n_parts);

for ip = 1 : n_parts
    part_info = detector_replay_input.detector_parts(ip);
    detector_stage_info(ip).part_index = ip;
    detector_stage_info(ip).n_blocks = numel(part_info.blocks);
    block_detections = cell(1, numel(part_info.blocks));
    n_block_detections = 0;
    track_rows_ip = cell(1, numel(part_info.blocks));
    n_track_rows_ip = 0;

    for ib = 1 : numel(part_info.blocks)
        blk = part_info.blocks(ib);
        blk_opts = case_def.cfar_options;
        blk_opts.nci_looks = blk.look_count;
        blk_opts.verbose = false;

        if strcmp(backend, 'toolbox')
            blk_dets = detectTargetsToolboxCFAR2D( ...
                blk.rdm_whitened_db, part_info.range_axis, part_info.doppler_axis, ...
                case_def.pfa, case_def.guard_cells, case_def.train_cells, ...
                case_def.min_range_m, blk_opts);
        else
            blk_dets = detectTargets( ...
                blk.rdm_whitened_db, part_info.range_axis, part_info.doppler_axis, ...
                case_def.pfa, case_def.guard_cells, case_def.train_cells, ...
                case_def.min_range_m, blk_opts);
        end

        if isempty(blk_dets)
            continue
        end

        if isfield(blk, 'row_nf_db') && ~isempty(blk.row_nf_db)
            r_idx = localRangeToIndex(blk_dets(:, 1), part_info.range_axis, numel(blk.row_nf_db));
            blk_dets(:, 3) = blk_dets(:, 3) + blk.row_nf_db(r_idx);
        elseif isfield(blk, 'abs_nf_db') && ~isempty(blk.abs_nf_db)
            blk_dets(:, 3) = blk_dets(:, 3) + blk.abs_nf_db;
        end

        t_abs_center_s = localGetField(blk, 't_abs_center_s', ...
            part_info.time_window_s(1) + blk.t_part_center_s);
        blk_with_meta = [blk_dets, repmat([blk.block_num, t_abs_center_s], size(blk_dets, 1), 1)];
        n_block_detections = n_block_detections + 1;
        block_detections{n_block_detections} = blk_with_meta;
        n_track_rows_ip = n_track_rows_ip + 1;
        track_rows_ip{n_track_rows_ip} = [blk_with_meta, repmat(ip, size(blk_with_meta, 1), 1)];
    end

    if n_block_detections > 0
        dets_ip = vertcat(block_detections{1:n_block_detections});
    else
        dets_ip = zeros(0, 5);
    end
    part_detections{ip} = dets_ip;
    detector_stage_info(ip).n_detections = size(dets_ip, 1);
    if n_track_rows_ip > 0
        all_track_dets_parts{ip} = vertcat(track_rows_ip{1:n_track_rows_ip});
    else
        all_track_dets_parts{ip} = zeros(0, 6);
    end

    if opts.Verbose
        fprintf('[helperRunDetectorReplayVariant] Part %d/%d (%s): %d detection(s)\n', ...
            ip, n_parts, backend, size(dets_ip, 1));
    end
end

if any(cellfun(@(rows_ip) ~isempty(rows_ip), all_track_dets_parts))
    all_track_dets = vertcat(all_track_dets_parts{:});
else
    all_track_dets = zeros(0, 6);
end

if ~isempty(all_track_dets)
    [~, sort_idx] = sort(all_track_dets(:, 5));
    all_track_dets = all_track_dets(sort_idx, :);
end
end

function case_def = localResolveCaseDefinition(detector_replay_input, case_override)
defaults = detector_replay_input.detector_defaults;
case_def = struct( ...
    'name', "baseline", ...
    'pfa', defaults.pfa, ...
    'guard_cells', defaults.guard_cells(:).', ...
    'train_cells', defaults.train_cells(:).', ...
    'min_range_m', defaults.min_range_m, ...
    'cfar_options', defaults.cfar_options);

if isempty(fieldnames(case_override))
    return
end

override_fields = fieldnames(case_override);
for k = 1 : numel(override_fields)
    field_name = override_fields{k};
    case_def.(field_name) = case_override.(field_name);
end
end

function idx = localRangeToIndex(range_values, range_axis, max_index)
if nargin < 3 || isempty(max_index)
    max_index = numel(range_axis);
end

if isempty(range_axis) || numel(range_axis) < 2
    idx = ones(size(range_values));
    return
end

range_bin_m = median(diff(range_axis));
idx = round((range_values - range_axis(1)) / range_bin_m) + 1;
idx = max(1, min(max_index, idx));
end

function value = localGetField(struct_in, field_name, default_value)
if isstruct(struct_in) && isfield(struct_in, field_name) && ~isempty(struct_in.(field_name))
    value = struct_in.(field_name);
else
    value = default_value;
end
end
