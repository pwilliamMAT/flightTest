function detector_replay_input = buildDetectorReplayInput(config, data_parts, ...
    part_start_offsets_s, part_end_offsets_s, part_results, varargin)
%BUILDDETECTORREPLAYINPUT Build a detector-only replay bundle.
%
% Plain-language goal:
%   The slow part of the pipeline is everything up to the whitened
%   block-level RDMs. Once those exist, CFAR tuning should be able to run
%   repeatedly without reloading IQ, re-running ECA-C, or rebuilding the
%   cross-ambiguity function. This helper saves the exact per-block CFAR
%   inputs together with the metadata needed to score new detections
%   against ADS-B truth.
%
% Syntax
%   detector_replay_input = buildDetectorReplayInput(config, data_parts, ...
%       part_start_offsets_s, part_end_offsets_s, part_results)
%
% Name-value options
%   'SessionID'            Session identifier string.
%   'AnalysisLabel'        Figure/report title string.
%   'PartDurationS'        Part duration [s]. Default: median(end-start).
%   'TruthDiagnosticInput' Optional existing truth_diag_input bundle to use
%                          as the truth-scoring template.
%   'TracksLog'            Optional tracker snapshot log used to build the
%                          truth template when TruthDiagnosticInput is not
%                          supplied.
%   'TrackHistories'       Optional pre-built track histories. Overrides
%                          TracksLog.
%   'RDMDisplayCLim'       Whitened RDM display limits for the truth
%                          template. Default: [-10 20].
%   'Verbose'              Logical console output.
%
% Output
%   detector_replay_input  Struct consumed by runDetectorReplaySweep.
%
% See also: processOnePart, runDetectorReplaySweep, saveDetectorReplayInput.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'config', @(x) isstruct(x) && isscalar(x));
addRequired(p, 'data_parts', @(x) iscell(x) || isstring(x));
addRequired(p, 'part_start_offsets_s', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'part_end_offsets_s', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'part_results', @(x) isstruct(x) && ~isempty(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'AnalysisLabel', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PartDurationS', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'TruthDiagnosticInput', struct([]), @(x) isempty(x) || isstruct(x));
addParameter(p, 'TracksLog', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'TrackHistories', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'RDMDisplayCLim', [-10, 20], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'Verbose', false, @islogical);
parse(p, config, data_parts, part_start_offsets_s, part_end_offsets_s, part_results, varargin{:});
opts = p.Results;

data_parts = cellstr(string(data_parts(:).'));
part_start_offsets_s = part_start_offsets_s(:);
part_end_offsets_s = part_end_offsets_s(:);

n_parts = numel(part_start_offsets_s);
if numel(part_end_offsets_s) ~= n_parts || numel(part_results) ~= n_parts
    error('buildDetectorReplayInput:inconsistentPartCount', ...
        'data_parts, part windows, and part_results must describe the same number of parts.');
end

part_dur_s = opts.PartDurationS;
if ~(isfinite(part_dur_s) && part_dur_s > 0)
    span_vec = part_end_offsets_s - part_start_offsets_s;
    span_vec = span_vec(isfinite(span_vec) & span_vec > 0);
    if isempty(span_vec)
        error('buildDetectorReplayInput:badPartDuration', ...
            'Part duration could not be derived from the provided windows.');
    end
    part_dur_s = median(span_vec);
end

detector_parts = localBuildDetectorParts(part_results, data_parts, ...
    part_start_offsets_s, part_end_offsets_s);
original_all_track_dets = localCollectOriginalDetections(part_results);
truth_diag_template = localResolveTruthTemplate(opts, config, data_parts, ...
    part_start_offsets_s, part_end_offsets_s, part_results, ...
    original_all_track_dets, part_dur_s);
detector_defaults = localBuildDetectorDefaults(config);

detector_replay_input = struct( ...
    'schema_version',         1, ...
    'created_posix_utc',      posixtime(datetime('now', 'TimeZone', 'UTC')), ...
    'session_id',             char(string(opts.SessionID)), ...
    'analysis_label',         char(string(opts.AnalysisLabel)), ...
    'verbose',                logical(opts.Verbose), ...
    'data_parts',             {data_parts}, ...
    'part_start_offsets_s',   part_start_offsets_s, ...
    'part_end_offsets_s',     part_end_offsets_s, ...
    'part_dur_s',             part_dur_s, ...
    'detector_defaults',      detector_defaults, ...
    'detector_parts',         detector_parts, ...
    'original_all_track_dets', original_all_track_dets, ...
    'truth_diag_template',    truth_diag_template);

if opts.Verbose
    n_blocks_total = sum(arrayfun(@(p_) numel(p_.blocks), detector_parts));
    fprintf(['[buildDetectorReplayInput] Built detector replay bundle for %d part(s), ' ...
        '%d block(s), %d original detections.\n'], ...
        n_parts, n_blocks_total, size(original_all_track_dets, 1));
end

end

function detector_parts = localBuildDetectorParts(part_results, data_parts, ...
    part_start_offsets_s, part_end_offsets_s)
n_parts = numel(part_results);
detector_parts(1, n_parts) = struct( ...
    'part_index', 0, ...
    'data_part', "", ...
    'time_window_s', [0, 0], ...
    'range_axis', zeros(0, 1), ...
    'doppler_axis', zeros(1, 0), ...
    'cfar_nf_db', NaN, ...
    'original_detections', zeros(0, 5), ...
    'blocks', struct( ...
        'block_num', {}, ...
        'look_count', {}, ...
        't_part_center_s', {}, ...
        't_abs_center_s', {}, ...
        'rdm_whitened_db', {}, ...
        'row_nf_db', {}, ...
        'abs_nf_db', {}));

for ip = 1 : n_parts
    if ~isfield(part_results(ip), 'detector_blocks') || isempty(part_results(ip).detector_blocks)
        error('buildDetectorReplayInput:missingDetectorBlocks', ...
            'part_results(%d) does not contain detector_blocks. Re-run processOnePart with the updated code.', ip);
    end

    dets_ip = zeros(0, 5);
    if isfield(part_results(ip), 'detections') && ~isempty(part_results(ip).detections)
        dets_ip = part_results(ip).detections;
    end

    blocks_src = part_results(ip).detector_blocks;
    blocks_dst = repmat(struct( ...
        'block_num', 0, ...
        'look_count', 0, ...
        't_part_center_s', 0, ...
        't_abs_center_s', 0, ...
        'rdm_whitened_db', zeros(0, 0), ...
        'row_nf_db', zeros(0, 1), ...
        'abs_nf_db', NaN), 1, numel(blocks_src));

    for ib = 1 : numel(blocks_src)
        blocks_dst(ib).block_num = blocks_src(ib).block_num;
        blocks_dst(ib).look_count = blocks_src(ib).look_count;
        blocks_dst(ib).t_part_center_s = blocks_src(ib).t_part_center_s;
        blocks_dst(ib).t_abs_center_s = part_start_offsets_s(ip) + blocks_src(ib).t_part_center_s;
        blocks_dst(ib).rdm_whitened_db = blocks_src(ib).rdm_whitened_db;
        blocks_dst(ib).row_nf_db = blocks_src(ib).row_nf_db;
        blocks_dst(ib).abs_nf_db = blocks_src(ib).abs_nf_db;
    end

    detector_parts(ip).part_index = ip;
    detector_parts(ip).data_part = string(data_parts{ip});
    detector_parts(ip).time_window_s = [part_start_offsets_s(ip), part_end_offsets_s(ip)];
    detector_parts(ip).range_axis = part_results(ip).range_axis;
    detector_parts(ip).doppler_axis = part_results(ip).doppler_axis;
    detector_parts(ip).cfar_nf_db = part_results(ip).cfar_nf_db;
    detector_parts(ip).original_detections = dets_ip;
    detector_parts(ip).blocks = blocks_dst;
end
end

function original_all_track_dets = localCollectOriginalDetections(part_results)
original_all_track_dets = zeros(0, 6);

for ip = 1 : numel(part_results)
    if ~isfield(part_results(ip), 'detections') || isempty(part_results(ip).detections)
        continue
    end

    dets_ip = part_results(ip).detections;
    if size(dets_ip, 2) < 5
        error('buildDetectorReplayInput:badDetectionLayout', ...
            'part_results(%d).detections must have at least 5 columns.', ip);
    end

    original_all_track_dets = [original_all_track_dets; ... %#ok<AGROW>
        dets_ip(:, 1:5), repmat(ip, size(dets_ip, 1), 1)];
end
end

function truth_diag_template = localResolveTruthTemplate(opts, config, data_parts, ...
    part_start_offsets_s, part_end_offsets_s, part_results, ...
    original_all_track_dets, part_dur_s)
if isstruct(opts.TruthDiagnosticInput) && ~isempty(opts.TruthDiagnosticInput) && ...
        ~isempty(fieldnames(opts.TruthDiagnosticInput))
    truth_diag_template = opts.TruthDiagnosticInput;
    return
end

truth_diag_template = buildDetectionTruthDiagnosticInput( ...
    config, data_parts, part_start_offsets_s, part_end_offsets_s, original_all_track_dets, ...
    'TracksLog', opts.TracksLog, ...
    'TrackHistories', opts.TrackHistories, ...
    'PartResults', part_results, ...
    'PartDurationS', part_dur_s, ...
    'SessionID', opts.SessionID, ...
    'AnalysisLabel', opts.AnalysisLabel, ...
    'RDMDisplayCLim', opts.RDMDisplayCLim, ...
    'Verbose', false);
end

function detector_defaults = localBuildDetectorDefaults(config)
cfar_options = struct();
if isfield(config, 'cfar_options') && ~isempty(config.cfar_options)
    cfar_options = config.cfar_options;
end

detector_defaults = struct( ...
    'pfa', localGetConfigField(config, 'cfar_pfa', 1e-4), ...
    'guard_cells', localGetConfigField(config, 'cfar_guard_cells', [4, 2]), ...
    'train_cells', localGetConfigField(config, 'cfar_train_cells', [20, 4]), ...
    'min_range_m', localGetConfigField(config, 'cfar_min_range_m', 5e3), ...
    'cfar_options', cfar_options);
end

function value = localGetConfigField(config, field_name, default_value)
if isfield(config, field_name) && ~isempty(config.(field_name))
    value = config.(field_name);
else
    value = default_value;
end
end
