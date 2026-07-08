function [detector_replay_input_out, scope_info] = helperRestrictDetectorReplayInput( ...
    detector_replay_input_in, varargin)
%HELPERRESTRICTDETECTORREPLAYINPUT Limit replay scope for fast offline iterations.
%
% Plain-language goal:
%   Full offline benchmark runs are appropriate for acceptance, but they
%   are slow when you are iterating on one benchmark helper. This helper
%   trims a detector replay bundle down to a smaller slice of the cached
%   replay data so the offline benchmark can exercise the same code paths
%   on fewer parts and fewer blocks per part.
%
% Scope limits are benchmark-only. They are meant for development loops on
% saved replay snapshots, not for final accuracy reporting.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'detector_replay_input_in', ...
    @(x) isstruct(x) && isfield(x, 'detector_parts'));
addParameter(p, 'PartIndices', [], ...
    @(x) isempty(x) || (isnumeric(x) && isvector(x) && ...
    all(isfinite(x)) && all(x >= 1) && all(mod(x, 1) == 0)));
addParameter(p, 'MaxBlocksPerPart', inf, ...
    @(x) isnumeric(x) && isscalar(x) && ...
    ((isfinite(x) && x >= 1 && mod(x, 1) == 0) || isinf(x)));
addParameter(p, 'Verbose', false, @islogical);
parse(p, detector_replay_input_in, varargin{:});
opts = p.Results;

n_parts_total = numel(detector_replay_input_in.detector_parts);
selected_part_indices = localResolvePartIndices(opts.PartIndices, n_parts_total);
max_blocks_per_part = opts.MaxBlocksPerPart;

scope_info = struct( ...
    'is_limited', false, ...
    'selected_part_indices', selected_part_indices, ...
    'max_blocks_per_part', max_blocks_per_part, ...
    'part_count_before', n_parts_total, ...
    'part_count_after', numel(selected_part_indices));

if isequal(selected_part_indices, 1:n_parts_total) && isinf(max_blocks_per_part)
    detector_replay_input_out = detector_replay_input_in;
    return
end

detector_replay_input_out = detector_replay_input_in;
detector_replay_input_out.detector_parts = detector_replay_input_in.detector_parts(selected_part_indices);

for ip = 1 : numel(detector_replay_input_out.detector_parts)
    detector_replay_input_out.detector_parts(ip).part_index = ip;

    if isfield(detector_replay_input_out.detector_parts(ip), 'blocks') && ...
            ~isempty(detector_replay_input_out.detector_parts(ip).blocks) && ...
            isfinite(max_blocks_per_part)
        n_keep_blocks = min(numel(detector_replay_input_out.detector_parts(ip).blocks), max_blocks_per_part);
        detector_replay_input_out.detector_parts(ip).blocks = ...
            detector_replay_input_out.detector_parts(ip).blocks(1:n_keep_blocks);

        if isfield(detector_replay_input_out.detector_parts(ip), 'original_detections') && ...
                ~isempty(detector_replay_input_out.detector_parts(ip).original_detections) && ...
                size(detector_replay_input_out.detector_parts(ip).original_detections, 2) >= 4
            dets_ip = detector_replay_input_out.detector_parts(ip).original_detections;
            detector_replay_input_out.detector_parts(ip).original_detections = ...
                dets_ip(dets_ip(:, 4) <= n_keep_blocks, :);
        end
    end
end

detector_replay_input_out = localSubsetPerPartFields( ...
    detector_replay_input_out, detector_replay_input_in, selected_part_indices);
detector_replay_input_out.original_all_track_dets = localFilterAllTrackDetections( ...
    localGetField(detector_replay_input_in, 'original_all_track_dets', zeros(0, 6)), ...
    selected_part_indices, max_blocks_per_part);

if isfield(detector_replay_input_out, 'truth_diag_template') && ...
        isstruct(detector_replay_input_out.truth_diag_template) && ...
        ~isempty(detector_replay_input_out.truth_diag_template)
    detector_replay_input_out.truth_diag_template = localRestrictTruthTemplate( ...
        detector_replay_input_out.truth_diag_template, ...
        detector_replay_input_in.truth_diag_template, ...
        selected_part_indices, max_blocks_per_part);
end

scope_info.is_limited = true;
if opts.Verbose
    fprintf(['[helperRestrictDetectorReplayInput] Selected %d/%d part(s); ' ...
        'max_blocks_per_part=%s.\n'], ...
        scope_info.part_count_after, scope_info.part_count_before, ...
        localFormatScalarLimit(max_blocks_per_part));
end
end

function selected_part_indices = localResolvePartIndices(part_indices_in, n_parts_total)
if isempty(part_indices_in)
    selected_part_indices = 1:n_parts_total;
else
    selected_part_indices = unique(part_indices_in(:).', 'stable');
end

if any(selected_part_indices > n_parts_total)
    error('helperRestrictDetectorReplayInput:badPartIndex', ...
        'Requested part index exceeds the replay bundle size (%d parts).', n_parts_total);
end
end

function replay_out = localSubsetPerPartFields(replay_out, replay_in, selected_part_indices)
subset_fields = {'data_parts', 'part_start_offsets_s', 'part_end_offsets_s'};
for k = 1 : numel(subset_fields)
    field_name = subset_fields{k};
    if ~isfield(replay_in, field_name) || isempty(replay_in.(field_name))
        continue
    end

    value_in = replay_in.(field_name);
    if isnumeric(value_in) || islogical(value_in) || isstring(value_in)
        replay_out.(field_name) = value_in(selected_part_indices);
    elseif iscell(value_in) || isstruct(value_in)
        replay_out.(field_name) = value_in(selected_part_indices);
    end
end
end

function truth_template_out = localRestrictTruthTemplate( ...
    truth_template_out, truth_template_in, selected_part_indices, max_blocks_per_part)
subset_fields = {'data_parts', 'part_start_offsets_s', 'part_end_offsets_s', 'rdm_parts'};
for k = 1 : numel(subset_fields)
    field_name = subset_fields{k};
    if ~isfield(truth_template_in, field_name) || isempty(truth_template_in.(field_name))
        continue
    end

    value_in = truth_template_in.(field_name);
    if numel(value_in) < max(selected_part_indices)
        continue
    end
    truth_template_out.(field_name) = value_in(selected_part_indices);
end

if isfield(truth_template_out, 'all_track_dets')
    truth_template_out.all_track_dets = localFilterAllTrackDetections( ...
        truth_template_in.all_track_dets, selected_part_indices, max_blocks_per_part);
end

if isfield(truth_template_out, 'detections') && isstruct(truth_template_in.detections)
    truth_template_out.detections = localFilterDetectionStruct( ...
        truth_template_in.detections, selected_part_indices, max_blocks_per_part);
end

if isfield(truth_template_out, 'rdm_parts') && isstruct(truth_template_out.rdm_parts)
    for ip = 1 : numel(truth_template_out.rdm_parts)
        if isfield(truth_template_out.rdm_parts(ip), 'part_index')
            truth_template_out.rdm_parts(ip).part_index = ip;
        end
        if isfinite(max_blocks_per_part) && isfield(truth_template_out.rdm_parts(ip), 'detections') && ...
                ~isempty(truth_template_out.rdm_parts(ip).detections) && ...
                size(truth_template_out.rdm_parts(ip).detections, 2) >= 4
            dets_ip = truth_template_out.rdm_parts(ip).detections;
            truth_template_out.rdm_parts(ip).detections = dets_ip(dets_ip(:, 4) <= max_blocks_per_part, :);
            if isfield(truth_template_out.rdm_parts(ip), 'det_count')
                truth_template_out.rdm_parts(ip).det_count = ...
                    size(truth_template_out.rdm_parts(ip).detections, 1);
            end
        end
    end
end
end

function all_track_dets_out = localFilterAllTrackDetections( ...
    all_track_dets_in, selected_part_indices, max_blocks_per_part)
all_track_dets_out = all_track_dets_in;
if isempty(all_track_dets_in) || size(all_track_dets_in, 2) < 6
    return
end

keep_mask = ismember(all_track_dets_in(:, 6), selected_part_indices);
if isfinite(max_blocks_per_part) && size(all_track_dets_in, 2) >= 4
    keep_mask = keep_mask & (all_track_dets_in(:, 4) <= max_blocks_per_part);
end

all_track_dets_out = all_track_dets_in(keep_mask, :);
for ip = 1 : numel(selected_part_indices)
    all_track_dets_out(all_track_dets_out(:, 6) == selected_part_indices(ip), 6) = ip;
end
end

function detections_out = localFilterDetectionStruct( ...
    detections_in, selected_part_indices, max_blocks_per_part)
detections_out = detections_in;
if isempty(detections_in) || ~isfield(detections_in, 'part_index')
    return
end

part_idx = [detections_in.part_index];
keep_mask = ismember(part_idx, selected_part_indices);
if isfield(detections_in, 'block_index') && isfinite(max_blocks_per_part)
    keep_mask = keep_mask & ([detections_in.block_index] <= max_blocks_per_part);
end

detections_out = detections_in(keep_mask);
for ip = 1 : numel(selected_part_indices)
    hit_mask = [detections_out.part_index] == selected_part_indices(ip);
    [detections_out(hit_mask).part_index] = deal(ip);
end
end

function value = localGetField(struct_in, field_name, default_value)
if isstruct(struct_in) && isfield(struct_in, field_name) && ~isempty(struct_in.(field_name))
    value = struct_in.(field_name);
else
    value = default_value;
end
end

function text_out = localFormatScalarLimit(value)
if isinf(value)
    text_out = "Inf";
else
    text_out = string(value);
end
end
