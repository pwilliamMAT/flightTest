function truth_diag_input = buildDetectionTruthDiagnosticInput(config, data_parts, ...
    part_start_offsets_s, part_end_offsets_s, all_track_dets, varargin)
%BUILDDETECTIONTRUTHDIAGNOSTICINPUT Build a standalone post-detection bundle.
%
% Plain-language goal:
%   The expensive part of the passive-radar pipeline is the raw-IQ
%   processing that produces detections and Range-Doppler maps. Once those
%   products already exist, truth alignment and plotting should be able to
%   run on their own. This helper packages just the post-detection data
%   needed by the standalone truth-diagnostic unit.
%
% Syntax
%   truth_diag_input = buildDetectionTruthDiagnosticInput(config, data_parts, ...
%       part_start_offsets_s, part_end_offsets_s, all_track_dets)
%
%   truth_diag_input = buildDetectionTruthDiagnosticInput(..., ...
%       'TracksLog', tracks_log, ...
%       'PartResults', part_res, ...
%       'PartTimingInfo', part_timing_info, ...
%       'SessionID', session_id, ...
%       'AnalysisLabel', 'My session')
%
% Required inputs
%   config               Analysis config struct from analyzeBistaticData.
%   data_parts           Cell array of radar file paths or filenames.
%   part_start_offsets_s Absolute part start times [s].
%   part_end_offsets_s   Absolute part end times [s].
%   all_track_dets       [N x 6] detection matrix:
%                        [range_m, dopp_hz, pwr_db, blk, t_abs_s, i_part]
%
% Name-value options
%   'SessionID'          Session identifier string.
%   'AnalysisLabel'      Figure/report title string.
%   'TracksLog'          Snapshot layout returned by trackTargets.
%   'TrackHistories'     Optional pre-built track histories. Overrides
%                        TracksLog when supplied.
%   'PartResults'        Optional part_res struct from analyzeBistaticData.
%                        When present, whitened per-part RDM products are
%                        added so the standalone unit can recreate RDM
%                        truth overlays without rerunning the main pipeline.
%   'PartTimingInfo'     Optional timing summary from
%                        helperGetPartStartOffsets so replay and
%                        comparison utilities can preserve which timing
%                        path was used for this bundle.
%   'PartDurationS'      Part duration [s]. Default: median(end-start).
%   'TruthQueryTimesS'   Optional precomputed truth query grid [s].
%   'RDMDisplayCLim'     Whitened RDM display limits. Default: [-10 20].
%   'Verbose'            Logical console output.
%
% Output
%   truth_diag_input     Struct consumed by runDetectionTruthDiagnostics.
%
% See also: runDetectionTruthDiagnostics, saveDetectionTruthDiagnosticInput.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'config', @(x) isstruct(x) && isscalar(x));
addRequired(p, 'data_parts', @(x) iscell(x) || isstring(x));
addRequired(p, 'part_start_offsets_s', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'part_end_offsets_s', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'all_track_dets', @(x) isnumeric(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'AnalysisLabel', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'TracksLog', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'TrackHistories', [], @(x) isempty(x) || isstruct(x));
addParameter(p, 'PartResults', struct([]), @(x) isempty(x) || isstruct(x));
addParameter(p, 'PartTimingInfo', struct(), @(x) isempty(x) || isstruct(x));
addParameter(p, 'PartDurationS', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'TruthQueryTimesS', [], @(x) isempty(x) || (isnumeric(x) && isvector(x)));
addParameter(p, 'RDMDisplayCLim', [-10, 20], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'Verbose', false, @islogical);
parse(p, config, data_parts, part_start_offsets_s, part_end_offsets_s, all_track_dets, varargin{:});
opts = p.Results;

part_start_offsets_s = part_start_offsets_s(:);
part_end_offsets_s = part_end_offsets_s(:);

if numel(part_start_offsets_s) ~= numel(part_end_offsets_s)
    error('buildDetectionTruthDiagnosticInput:badPartWindows', ...
        'part_start_offsets_s and part_end_offsets_s must have the same length.');
end

data_parts = cellstr(string(data_parts(:).'));

part_dur_s = opts.PartDurationS;
if ~(isfinite(part_dur_s) && part_dur_s > 0)
    span_vec = part_end_offsets_s - part_start_offsets_s;
    span_vec = span_vec(isfinite(span_vec) & span_vec > 0);
    if isempty(span_vec)
        error('buildDetectionTruthDiagnosticInput:badPartDuration', ...
            'Part duration could not be derived from the provided windows.');
    end
    part_dur_s = median(span_vec);
end

if ~isfield(config, 'max_nci_looks') || isempty(config.max_nci_looks)
    error('buildDetectionTruthDiagnosticInput:missingMaxNCI', ...
        'config.max_nci_looks is required.');
end

bistatic_consts = helperDeriveBistaticConstants(config);

if isempty(opts.TruthQueryTimesS)
    t_abs_query = helperBuildTruthQueryTimes( ...
        part_start_offsets_s, part_dur_s, ...
        bistatic_consts.chunk_dur_s, config.max_nci_looks);
else
    t_abs_query = opts.TruthQueryTimesS(:);
end

if isempty(opts.TrackHistories)
    if isempty(opts.TracksLog)
        track_histories = struct( ...
            'TrackID', {}, ...
            't_abs_s', {}, ...
            'R_excess_m', {}, ...
            'Rdot_mps', {}, ...
            'f_D_hz', {}, ...
            'StateCovDiag', {});
    else
        track_histories = helperTracksLogToHistories(opts.TracksLog, config.fc);
    end
else
    track_histories = opts.TrackHistories;
end

rdm_parts = localBuildRDMParts(opts.PartResults, part_start_offsets_s, ...
    part_end_offsets_s, opts.RDMDisplayCLim);
[range_cell_m, doppler_bin_hz] = localResolveMeasurementGrid( ...
    config, opts.PartResults, bistatic_consts);

adsb_files = {};
if isfield(config, 'adsb_files') && ~isempty(config.adsb_files)
    adsb_files = cellstr(string(config.adsb_files(:).'));
end

truth_diag_input = struct( ...
    'schema_version',         1, ...
    'created_posix_utc',      posixtime(datetime('now', 'TimeZone', 'UTC')), ...
    'session_id',             char(string(opts.SessionID)), ...
    'analysis_label',         char(string(opts.AnalysisLabel)), ...
    'verbose',                logical(opts.Verbose), ...
    'data_parts',             {data_parts}, ...
    'adsb_files',             {adsb_files}, ...
    'txLLA',                  config.txLLA, ...
    'rxLLA',                  config.rxLLA, ...
    'fc',                     config.fc, ...
    'fs',                     config.fs, ...
    'max_display_range_m',    localGetOptionalConfigField(config, 'max_display_range_m', Inf), ...
    'radar_epoch_utc',        localGetOptionalConfigField(config, 'radar_epoch_utc', NaN), ...
    'range_cell_m',           range_cell_m, ...
    'doppler_bin_hz',         doppler_bin_hz, ...
    'chunk_dur_s',            bistatic_consts.chunk_dur_s, ...
    'max_nci_looks',          config.max_nci_looks, ...
    'part_dur_s',             part_dur_s, ...
    'part_timing_source',     char(string(localGetOptionalConfigField(config, 'part_timing_source', ""))), ...
    'part_timing_info',       opts.PartTimingInfo, ...
    'part_start_offsets_s',   part_start_offsets_s, ...
    'part_end_offsets_s',     part_end_offsets_s, ...
    't_abs_query',            t_abs_query, ...
    'all_track_dets',         all_track_dets, ...
    'detections',             {localWrapTrackDetections(all_track_dets)}, ...
    'track_histories',        track_histories, ...
    'rdm_parts',              rdm_parts);

if opts.Verbose
    fprintf('[buildDetectionTruthDiagnosticInput] Built bundle for %d part(s), %d detections, %d truth query times.\n', ...
        numel(part_start_offsets_s), size(all_track_dets, 1), numel(t_abs_query));
end

end

function rdm_parts = localBuildRDMParts(part_results, part_start_offsets_s, part_end_offsets_s, rdm_display_clim)
rdm_parts = struct( ...
    'part_index',        {}, ...
    'time_window_s',     {}, ...
    'rdm_image',         {}, ...
    'range_axis',        {}, ...
    'doppler_axis',      {}, ...
    'detections',        {}, ...
    'det_count',         {}, ...
    'cfar_nf_db',        {}, ...
    'display_clim',      {}, ...
    'is_whitened_image', {});

if isempty(part_results)
    return
end

n_parts = numel(part_results);
rdm_parts(1, n_parts) = struct( ...
    'part_index',        0, ...
    'time_window_s',     [0, 0], ...
    'rdm_image',         zeros(0, 0), ...
    'range_axis',        zeros(0, 1), ...
    'doppler_axis',      zeros(1, 0), ...
    'detections',        zeros(0, 0), ...
    'det_count',         0, ...
    'cfar_nf_db',        NaN, ...
    'display_clim',      rdm_display_clim(:).', ...
    'is_whitened_image', true);

for ip = 1 : n_parts
    dets = zeros(0, 0);
    if isfield(part_results(ip), 'detections') && ~isempty(part_results(ip).detections)
        dets = part_results(ip).detections;
    end

    rdm_img = zeros(0, 0);
    range_axis = zeros(0, 1);
    doppler_axis = zeros(1, 0);
    if isfield(part_results(ip), 'rdm_after') && ~isempty(part_results(ip).rdm_after)
        rdm_img = part_results(ip).rdm_after - median(part_results(ip).rdm_after, 2);
    elseif isfield(part_results(ip), 'rdm_image') && ~isempty(part_results(ip).rdm_image)
        rdm_img = part_results(ip).rdm_image;
    end
    if isfield(part_results(ip), 'range_axis') && ~isempty(part_results(ip).range_axis)
        range_axis = part_results(ip).range_axis;
    end
    if isfield(part_results(ip), 'doppler_axis') && ~isempty(part_results(ip).doppler_axis)
        doppler_axis = part_results(ip).doppler_axis;
    end

    cfar_nf_db = NaN;
    if isfield(part_results(ip), 'cfar_nf_db') && ~isempty(part_results(ip).cfar_nf_db)
        cfar_nf_db = part_results(ip).cfar_nf_db;
    end

    rdm_parts(ip).part_index = ip;
    rdm_parts(ip).time_window_s = [part_start_offsets_s(ip), part_end_offsets_s(ip)];
    rdm_parts(ip).rdm_image = rdm_img;
    rdm_parts(ip).range_axis = range_axis;
    rdm_parts(ip).doppler_axis = doppler_axis;
    rdm_parts(ip).detections = dets;
    rdm_parts(ip).det_count = size(dets, 1);
    rdm_parts(ip).cfar_nf_db = cfar_nf_db;
    rdm_parts(ip).display_clim = rdm_display_clim(:).';
    rdm_parts(ip).is_whitened_image = true;
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

function value = localGetOptionalConfigField(config, field_name, default_value)
if isfield(config, field_name) && ~isempty(config.(field_name))
    value = config.(field_name);
else
    value = default_value;
end
end

function [range_cell_m, doppler_bin_hz] = localResolveMeasurementGrid(config, part_results, bistatic_consts)
range_cell_m = NaN;
doppler_bin_hz = NaN;

if isstruct(part_results) && ~isempty(part_results)
    for ip = 1 : numel(part_results)
        if isfield(part_results(ip), 'range_axis') && numel(part_results(ip).range_axis) >= 2
            delta_r = diff(part_results(ip).range_axis(:));
            delta_r = delta_r(isfinite(delta_r) & delta_r > 0);
            if ~isempty(delta_r)
                range_cell_m = median(delta_r);
                break
            end
        end
    end

    for ip = 1 : numel(part_results)
        if isfield(part_results(ip), 'doppler_axis') && numel(part_results(ip).doppler_axis) >= 2
            delta_f = diff(part_results(ip).doppler_axis(:));
            delta_f = delta_f(isfinite(delta_f) & abs(delta_f) > 0);
            if ~isempty(delta_f)
                doppler_bin_hz = median(abs(delta_f));
                break
            end
        end
    end
end

if ~(isfinite(range_cell_m) && range_cell_m > 0)
    if isfield(config, 'fs') && isnumeric(config.fs) && isscalar(config.fs) && config.fs > 0
        range_cell_m = physconst('LightSpeed') / config.fs;
    else
        range_cell_m = bistatic_consts.range_cell_m;
    end
end

if ~(isfinite(doppler_bin_hz) && doppler_bin_hz > 0)
    doppler_bin_hz = bistatic_consts.doppler_bin_hz;
end
end
