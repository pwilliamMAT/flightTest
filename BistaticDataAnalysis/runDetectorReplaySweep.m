function detector_replay_output = runDetectorReplaySweep(replay_input, varargin)
%RUNDETECTORREPLAYSWEEP Re-run detector tuning from saved block-level CFAR inputs.
%
% Plain-language goal:
%   Sweep CFAR and post-CFAR detector parameters without repeating the
%   expensive IQ loading, clutter mitigation, and CAF generation stages.
%   This function starts from the saved whitened per-block RDMs, reruns
%   detectTargets, rebuilds the detection list, and optionally scores the
%   result against ADS-B truth using the existing truth-diagnostic tooling.
%
% Syntax
%   out = runDetectorReplaySweep(detector_replay_input)
%   out = runDetectorReplaySweep('detector_replay_input.mat')
%
%   cases = struct( ...
%       'Name', {'baseline', 'tighter'}, ...
%       'Pfa', {1e-4, 1e-5}, ...
%       'MinSNRDB', {0, 3});
%   out = runDetectorReplaySweep('detector_replay_input.mat', 'Cases', cases);
%
% Input
%   replay_input  Either:
%                   - the bundle returned by buildDetectorReplayInput
%                   - a struct containing .detector_replay_input
%                   - a MAT-file path containing detector_replay_input
%
% Key name-value options
%   'Cases'                 Struct array or table of parameter cases.
%   'Pfa'                   Scalar override for a single-case run.
%   'GuardCells'            [range, Doppler] guard half-widths.
%   'TrainCells'            [range, Doppler] training half-widths.
%   'MinRangeM'             Minimum reportable bistatic range [m].
%   'CfarType'              'CA' or 'OS'.
%   'OSRankFraction'        OS-CFAR rank fraction.
%   'LocalMaxima'           Enable/disable local-max suppression.
%   'LMRangeBins'           Local-max half-width in range bins.
%   'LMDoppBins'            Local-max half-width in Doppler bins.
%   'MinSNRDB'              Additional threshold margin above CFAR.
%   'ATSCGuardPenaltyDB'    Extra threshold margin at ATSC ghost ranges.
%   'ATSCGuardWidthBins'    Half-width of each ATSC guard zone.
%   'NotchGuardDoppBins'    Zero-Doppler notch guard half-width.
%   'RunTruthDiagnostics'   Score each case against ADS-B truth when the
%                           replay bundle has a truth template. Default: true.
%   'PlotCases'             Indices, names, or 'all'. Default: first case
%                           only when there is exactly one case.
%   'PlotDetectionTimeSeries'
%   'PlotRDMOverlays'
%   'GateRangeCells'
%   'GateDopplerBins'
%   'TimeGateS'
%   'Verbose'
%
% Output
%   detector_replay_output  Struct containing:
%     .session_id
%     .analysis_label
%     .summary_table
%     .case_results
%
% See also: buildDetectorReplayInput, saveDetectorReplayInput,
%           detectTargets, runDetectionTruthDiagnostics.

p = inputParser;
p.FunctionName = mfilename;
p.PartialMatching = false;
addRequired(p, 'replay_input', @(x) isstruct(x) || ischar(x) || isstring(x));
addParameter(p, 'Cases', struct([]), @(x) isempty(x) || isstruct(x) || istable(x));
addParameter(p, 'Pfa', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0 && x < 1));
addParameter(p, 'GuardCells', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'TrainCells', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'MinRangeM', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'CfarType', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'OSRankFraction', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0 && x <= 1));
addParameter(p, 'LocalMaxima', [], @(x) isempty(x) || islogical(x));
addParameter(p, 'LMRangeBins', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'LMDoppBins', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'MinSNRDB', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'ATSCGuardPenaltyDB', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'ATSCGuardWidthBins', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'NotchGuardDoppBins', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 0));
addParameter(p, 'RunTruthDiagnostics', true, @islogical);
addParameter(p, 'PlotCases', [], @(x) isempty(x) || isnumeric(x) || ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'PlotDetectionTimeSeries', true, @islogical);
addParameter(p, 'PlotRDMOverlays', false, @islogical);
addParameter(p, 'GateRangeCells', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'GateDopplerBins', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'TimeGateS', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'ShowRDMLabels', true, @islogical);
addParameter(p, 'ConnectRDMTruthSamples', true, @islogical);
addParameter(p, 'MaxAircraft', 12, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', [], @(x) isempty(x) || islogical(x));
normalized_varargin = localNormalizeNameValueArgs(varargin, localSupportedOptionNames());
parse(p, replay_input, normalized_varargin{:});
opts = p.Results;

detector_replay_input = localResolveReplayInput(opts.replay_input);
verbose = localResolveVerbose(opts.Verbose, detector_replay_input);

case_defs = localResolveCases(detector_replay_input, opts);
plot_case_idx = localResolvePlotCases(case_defs, opts.PlotCases);
run_truth = opts.RunTruthDiagnostics && localHasTruthTemplate(detector_replay_input);

if verbose
    fprintf('\n[runDetectorReplaySweep] %d detector case(s), %d part(s).\n', ...
        numel(case_defs), numel(detector_replay_input.detector_parts));
    if run_truth
        fprintf('[runDetectorReplaySweep] ADS-B truth scoring is enabled.\n');
    else
        fprintf('[runDetectorReplaySweep] No usable truth template; running detector-only summaries.\n');
    end
end

case_results = repmat(struct( ...
    'name', "", ...
    'parameters', struct(), ...
    'part_detections', {cell(0, 1)}, ...
    'all_track_dets', zeros(0, 6), ...
    'truth_diag_output', struct(), ...
    'summary', struct()), 1, numel(case_defs));

for ic = 1 : numel(case_defs)
    case_def = case_defs(ic);
    if verbose
        fprintf('\n[runDetectorReplaySweep] Case %d/%d: %s\n', ...
            ic, numel(case_defs), case_def.name);
    end

    [part_detections, all_track_dets] = localRunSingleCase(detector_replay_input, case_def);

    truth_diag_output = struct();
    summary = struct( ...
        'n_detections', size(all_track_dets, 1), ...
        'n_tp', NaN, ...
        'n_fa', NaN, ...
        'n_miss', NaN, ...
        'mean_pd', NaN);

    if run_truth
        plot_this_case = ismember(ic, plot_case_idx);
        truth_bundle = localBuildTruthBundle(detector_replay_input, all_track_dets, ...
            part_detections, case_def);

        truth_diag_output = runDetectionTruthDiagnostics( ...
            truth_bundle, ...
            'Verbose', verbose, ...
            'FigureTitle', localResolveFigureTitle(detector_replay_input, case_def), ...
            'PlotDetectionTimeSeries', plot_this_case && opts.PlotDetectionTimeSeries, ...
            'PlotRDMOverlays', plot_this_case && opts.PlotRDMOverlays, ...
            'PlotTrackComparison', false, ...
            'GateRangeCells', opts.GateRangeCells, ...
            'GateDopplerBins', opts.GateDopplerBins, ...
            'TimeGateS', opts.TimeGateS, ...
            'ShowRDMLabels', opts.ShowRDMLabels, ...
            'ConnectRDMTruthSamples', opts.ConnectRDMTruthSamples, ...
            'MaxAircraft', opts.MaxAircraft);

        summary.n_detections = localGetField(truth_diag_output.check_summary, ...
            'n_detections', size(all_track_dets, 1));
        summary.n_tp = localGetField(truth_diag_output.truth_metrics, 'n_tp', NaN);
        summary.n_fa = localGetField(truth_diag_output.truth_metrics, 'n_fa', NaN);
        summary.n_miss = localGetField(truth_diag_output.truth_metrics, 'n_miss', NaN);
        summary.mean_pd = localMeanPd(truth_diag_output.truth_metrics);
    end

    case_results(ic).name = string(case_def.name);
    case_results(ic).parameters = localSummarizeCaseParameters(case_def);
    case_results(ic).part_detections = part_detections;
    case_results(ic).all_track_dets = all_track_dets;
    case_results(ic).truth_diag_output = truth_diag_output;
    case_results(ic).summary = summary;
end

summary_table = localBuildSummaryTable(case_results);

if verbose && ~isempty(summary_table)
    fprintf('\n[runDetectorReplaySweep] Case summary:\n');
    disp(summary_table);
end

detector_replay_output = struct( ...
    'session_id', string(detector_replay_input.session_id), ...
    'analysis_label', string(detector_replay_input.analysis_label), ...
    'summary_table', summary_table, ...
    'case_results', case_results);

end

function detector_replay_input = localResolveReplayInput(replay_input)
if ischar(replay_input) || isstring(replay_input)
    loaded = load(char(string(replay_input)));
    if isfield(loaded, 'detector_replay_input')
        detector_replay_input = loaded.detector_replay_input;
    else
        error('runDetectorReplaySweep:badMatFile', ...
            'MAT-file does not contain detector_replay_input.');
    end
elseif isstruct(replay_input) && isfield(replay_input, 'detector_replay_input')
    detector_replay_input = replay_input.detector_replay_input;
elseif isstruct(replay_input) && isfield(replay_input, 'detector_parts')
    detector_replay_input = replay_input;
else
    error('runDetectorReplaySweep:badInput', ...
        'Input must be a replay bundle, a struct containing .detector_replay_input, or a MAT-file path.');
end
end

function verbose = localResolveVerbose(opt_verbose, detector_replay_input)
if isempty(opt_verbose)
    if isfield(detector_replay_input, 'verbose') && ~isempty(detector_replay_input.verbose)
        verbose = logical(detector_replay_input.verbose);
    else
        verbose = false;
    end
else
    verbose = logical(opt_verbose);
end
end

function case_defs = localResolveCases(detector_replay_input, opts)
base_case = localBuildBaseCase(detector_replay_input);
base_case = localApplyGlobalOverrides(base_case, opts);

if isempty(opts.Cases)
    case_defs = base_case;
    return
end

if istable(opts.Cases)
    case_overrides = table2struct(opts.Cases);
else
    case_overrides = opts.Cases;
end

[case_overrides, alias_pairs] = localNormalizeCaseOverrides(case_overrides);
if ~isempty(alias_pairs)
    warning('runDetectorReplaySweep:caseFieldAlias', ...
        'Accepted compatibility aliases in Cases: %s. Prefer the canonical README field names.', ...
        strjoin(alias_pairs, ', '));
end

case_defs = repmat(base_case, 1, numel(case_overrides));
for ic = 1 : numel(case_overrides)
    case_defs(ic) = localMergeCaseOverride(base_case, case_overrides(ic), ic);
end
end

function base_case = localBuildBaseCase(detector_replay_input)
defaults = detector_replay_input.detector_defaults;
base_case = struct( ...
    'name', 'baseline', ...
    'pfa', defaults.pfa, ...
    'guard_cells', defaults.guard_cells(:).', ...
    'train_cells', defaults.train_cells(:).', ...
    'min_range_m', defaults.min_range_m, ...
    'cfar_options', defaults.cfar_options);
end

function case_def = localApplyGlobalOverrides(case_def, opts)
if ~isempty(opts.Pfa), case_def.pfa = opts.Pfa; end
if ~isempty(opts.GuardCells), case_def.guard_cells = opts.GuardCells(:).'; end
if ~isempty(opts.TrainCells), case_def.train_cells = opts.TrainCells(:).'; end
if ~isempty(opts.MinRangeM), case_def.min_range_m = opts.MinRangeM; end
if strlength(string(opts.CfarType)) > 0
    case_def.cfar_options.cfar_type = char(string(opts.CfarType));
end
if ~isempty(opts.OSRankFraction), case_def.cfar_options.os_rank_fraction = opts.OSRankFraction; end
if ~isempty(opts.LocalMaxima), case_def.cfar_options.local_maxima = opts.LocalMaxima; end
if ~isempty(opts.LMRangeBins), case_def.cfar_options.lm_range_bins = opts.LMRangeBins; end
if ~isempty(opts.LMDoppBins), case_def.cfar_options.lm_dopp_bins = opts.LMDoppBins; end
if ~isempty(opts.MinSNRDB), case_def.cfar_options.min_snr_db = opts.MinSNRDB; end
if ~isempty(opts.ATSCGuardPenaltyDB), case_def.cfar_options.atsc_guard_penalty_db = opts.ATSCGuardPenaltyDB; end
if ~isempty(opts.ATSCGuardWidthBins), case_def.cfar_options.atsc_guard_width_bins = opts.ATSCGuardWidthBins; end
if ~isempty(opts.NotchGuardDoppBins), case_def.cfar_options.notch_guard_dopp_bins = opts.NotchGuardDoppBins; end
end

function case_def = localMergeCaseOverride(base_case, case_override, ic)
case_def = base_case;
name_value = localGetFirstField(case_override, {'Name', 'name'}, "");
if strlength(string(name_value)) > 0
    case_def.name = char(string(name_value));
else
    case_def.name = sprintf('case_%d', ic);
end

pfa_value = localGetFirstField(case_override, {'Pfa', 'pfa'}, []);
if ~isempty(pfa_value), case_def.pfa = pfa_value; end

guard_value = localGetFirstField(case_override, {'GuardCells', 'guard_cells', 'guardCells'}, []);
if ~isempty(guard_value), case_def.guard_cells = guard_value(:).'; end

train_value = localGetFirstField(case_override, {'TrainCells', 'train_cells', 'trainCells'}, []);
if ~isempty(train_value), case_def.train_cells = train_value(:).'; end

min_range_value = localGetFirstField(case_override, {'MinRangeM', 'min_range_m', 'minRangeM'}, []);
if ~isempty(min_range_value), case_def.min_range_m = min_range_value; end

cfar_struct = localGetFirstField(case_override, {'CfarOptions', 'cfar_options', 'cfarOptions'}, struct());
if isstruct(cfar_struct) && ~isempty(fieldnames(cfar_struct))
    case_def.cfar_options = localMergeStruct(case_def.cfar_options, cfar_struct);
end

case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'CfarType', 'cfar_type', 'cfarType'}, 'cfar_type');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'OSRankFraction', 'os_rank_fraction', 'osRankFraction'}, 'os_rank_fraction');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'LocalMaxima', 'local_maxima', 'localMaxima'}, 'local_maxima');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'LMRangeBins', 'lm_range_bins', 'lmRangeBins'}, 'lm_range_bins');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'LMDoppBins', 'lm_dopp_bins', 'lmDoppBins'}, 'lm_dopp_bins');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'MinSNRDB', 'min_snr_db', 'minSNRDB'}, 'min_snr_db');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'ATSCGuardPenaltyDB', 'atsc_guard_penalty_db', 'atscGuardPenaltyDB'}, 'atsc_guard_penalty_db');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'ATSCGuardWidthBins', 'atsc_guard_width_bins', 'atscGuardWidthBins'}, 'atsc_guard_width_bins');
case_def.cfar_options = localApplyOptionOverride(case_def.cfar_options, case_override, {'NotchGuardDoppBins', 'notch_guard_dopp_bins', 'notchGuardDoppBins'}, 'notch_guard_dopp_bins');
end

function cfar_options = localApplyOptionOverride(cfar_options, case_override, source_fields, target_field)
value = localGetFirstField(case_override, source_fields, []);
if ~isempty(value)
    cfar_options.(target_field) = value;
end
end

function plot_case_idx = localResolvePlotCases(case_defs, plot_cases)
if isempty(plot_cases)
    if isscalar(case_defs)
        plot_case_idx = 1;
    else
        plot_case_idx = zeros(1, 0);
    end
    return
end

if isnumeric(plot_cases)
    plot_case_idx = unique(plot_cases(:).');
    plot_case_idx = plot_case_idx(plot_case_idx >= 1 & plot_case_idx <= numel(case_defs));
    return
end

case_names = string({case_defs.name});
plot_names = string(plot_cases);
if isscalar(plot_names) && strcmpi(plot_names, "all")
    plot_case_idx = 1 : numel(case_defs);
    return
end

plot_case_idx = zeros(1, 0);
for k = 1 : numel(plot_names)
    idx = find(strcmpi(case_names, plot_names(k)));
    plot_case_idx = [plot_case_idx, idx(:).']; %#ok<AGROW>
end
plot_case_idx = unique(plot_case_idx);
end

function tf = localHasTruthTemplate(detector_replay_input)
tf = isfield(detector_replay_input, 'truth_diag_template') && ...
    isstruct(detector_replay_input.truth_diag_template) && ...
    ~isempty(detector_replay_input.truth_diag_template) && ...
    isfield(detector_replay_input.truth_diag_template, 'adsb_files') && ...
    ~isempty(detector_replay_input.truth_diag_template.adsb_files);
end

function [part_detections, all_track_dets] = localRunSingleCase(detector_replay_input, case_def)
n_parts = numel(detector_replay_input.detector_parts);
part_detections = cell(1, n_parts);
all_track_dets = zeros(0, 6);

for ip = 1 : n_parts
    part_info = detector_replay_input.detector_parts(ip);
    range_axis = part_info.range_axis;
    doppler_axis = part_info.doppler_axis;
    dets_ip = zeros(0, 5);

    for ib = 1 : numel(part_info.blocks)
        blk = part_info.blocks(ib);
        blk_opts = case_def.cfar_options;
        blk_opts.nci_looks = blk.look_count;
        blk_opts.verbose = false;

        blk_dets = detectTargets( ...
            blk.rdm_whitened_db, range_axis, doppler_axis, ...
            case_def.pfa, case_def.guard_cells, case_def.train_cells, ...
            case_def.min_range_m, blk_opts);

        if isempty(blk_dets)
            continue
        end

        if isfield(blk, 'row_nf_db') && ~isempty(blk.row_nf_db)
            r_idx = localRangeToIndex(blk_dets(:, 1), range_axis, numel(blk.row_nf_db));
            blk_dets(:, 3) = blk_dets(:, 3) + blk.row_nf_db(r_idx);
        elseif isfield(blk, 'abs_nf_db') && ~isempty(blk.abs_nf_db)
            blk_dets(:, 3) = blk_dets(:, 3) + blk.abs_nf_db;
        end

        t_abs_center_s = localGetField(blk, 't_abs_center_s', ...
            part_info.time_window_s(1) + blk.t_part_center_s);
        blk_with_meta = [blk_dets, ...
            repmat([blk.block_num, t_abs_center_s], size(blk_dets, 1), 1)];
        dets_ip = [dets_ip; blk_with_meta]; %#ok<AGROW>
        all_track_dets = [all_track_dets; ... %#ok<AGROW>
            blk_with_meta, repmat(ip, size(blk_with_meta, 1), 1)];
    end

    part_detections{ip} = dets_ip;
end

if ~isempty(all_track_dets)
    [~, sort_idx] = sort(all_track_dets(:, 5));
    all_track_dets = all_track_dets(sort_idx, :);
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

function truth_bundle = localBuildTruthBundle(detector_replay_input, all_track_dets, part_detections, case_def)
truth_bundle = detector_replay_input.truth_diag_template;
truth_bundle.all_track_dets = all_track_dets;
truth_bundle.detections = localWrapTrackDetections(all_track_dets);
truth_bundle.analysis_label = localResolveFigureTitle(detector_replay_input, case_def);
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

function figure_title = localResolveFigureTitle(detector_replay_input, case_def)
if isfield(detector_replay_input, 'analysis_label') && ~isempty(detector_replay_input.analysis_label)
    base_title = string(detector_replay_input.analysis_label);
elseif isfield(detector_replay_input, 'session_id') && ~isempty(detector_replay_input.session_id)
    base_title = "Session " + string(detector_replay_input.session_id);
else
    base_title = "Detector Replay";
end

figure_title = char(base_title + " - " + string(case_def.name));
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

function value = localGetField(struct_in, field_name, default_value)
if isstruct(struct_in) && isfield(struct_in, field_name) && ~isempty(struct_in.(field_name))
    value = struct_in.(field_name);
else
    value = default_value;
end
end

function value = localGetFirstField(struct_in, field_names, default_value)
value = default_value;
for k = 1 : numel(field_names)
    field_name = field_names{k};
    if isfield(struct_in, field_name) && ~isempty(struct_in.(field_name))
        value = struct_in.(field_name);
        return
    end
end
end

function mean_pd = localMeanPd(truth_metrics)
mean_pd = NaN;
if isstruct(truth_metrics) && isfield(truth_metrics, 'Pd_per_ac') && ...
        istable(truth_metrics.Pd_per_ac) && any(strcmp(truth_metrics.Pd_per_ac.Properties.VariableNames, 'Pd'))
    mean_pd = mean(truth_metrics.Pd_per_ac.Pd, 'omitnan');
end
end

function summary = localSummarizeCaseParameters(case_def)
summary = struct( ...
    'pfa', case_def.pfa, ...
    'guard_cells', case_def.guard_cells(:).', ...
    'train_cells', case_def.train_cells(:).', ...
    'min_range_m', case_def.min_range_m, ...
    'cfar_type', string(localGetField(case_def.cfar_options, 'cfar_type', 'CA')), ...
    'os_rank_fraction', localGetField(case_def.cfar_options, 'os_rank_fraction', NaN), ...
    'local_maxima', localGetField(case_def.cfar_options, 'local_maxima', false), ...
    'lm_range_bins', localGetField(case_def.cfar_options, 'lm_range_bins', NaN), ...
    'lm_dopp_bins', localGetField(case_def.cfar_options, 'lm_dopp_bins', NaN), ...
    'min_snr_db', localGetField(case_def.cfar_options, 'min_snr_db', NaN), ...
    'atsc_guard_penalty_db', localGetField(case_def.cfar_options, 'atsc_guard_penalty_db', NaN), ...
    'atsc_guard_width_bins', localGetField(case_def.cfar_options, 'atsc_guard_width_bins', NaN), ...
    'notch_guard_dopp_bins', localGetField(case_def.cfar_options, 'notch_guard_dopp_bins', NaN));
end

function summary_table = localBuildSummaryTable(case_results)
if isempty(case_results)
    summary_table = table();
    return
end

n_cases = numel(case_results);
case_name = strings(n_cases, 1);
n_detections = NaN(n_cases, 1);
n_tp = NaN(n_cases, 1);
n_fa = NaN(n_cases, 1);
n_miss = NaN(n_cases, 1);
mean_pd = NaN(n_cases, 1);
pfa = NaN(n_cases, 1);
guard_range = NaN(n_cases, 1);
guard_dopp = NaN(n_cases, 1);
train_range = NaN(n_cases, 1);
train_dopp = NaN(n_cases, 1);
min_range_m = NaN(n_cases, 1);
cfar_type = strings(n_cases, 1);
min_snr_db = NaN(n_cases, 1);

for ic = 1 : n_cases
    case_name(ic) = string(case_results(ic).name);
    n_detections(ic) = localGetField(case_results(ic).summary, 'n_detections', NaN);
    n_tp(ic) = localGetField(case_results(ic).summary, 'n_tp', NaN);
    n_fa(ic) = localGetField(case_results(ic).summary, 'n_fa', NaN);
    n_miss(ic) = localGetField(case_results(ic).summary, 'n_miss', NaN);
    mean_pd(ic) = localGetField(case_results(ic).summary, 'mean_pd', NaN);

    params = case_results(ic).parameters;
    pfa(ic) = localGetField(params, 'pfa', NaN);
    guard_cells = localGetField(params, 'guard_cells', [NaN, NaN]);
    train_cells = localGetField(params, 'train_cells', [NaN, NaN]);
    if numel(guard_cells) >= 2
        guard_range(ic) = guard_cells(1);
        guard_dopp(ic) = guard_cells(2);
    end
    if numel(train_cells) >= 2
        train_range(ic) = train_cells(1);
        train_dopp(ic) = train_cells(2);
    end
    min_range_m(ic) = localGetField(params, 'min_range_m', NaN);
    cfar_type(ic) = string(localGetField(params, 'cfar_type', ""));
    min_snr_db(ic) = localGetField(params, 'min_snr_db', NaN);
end

summary_table = table( ...
    case_name, n_detections, n_tp, n_fa, n_miss, mean_pd, ...
    pfa, guard_range, guard_dopp, train_range, train_dopp, ...
    min_range_m, cfar_type, min_snr_db);
end

function merged = localMergeStruct(base_struct, override_struct)
merged = base_struct;
override_fields = fieldnames(override_struct);
for k = 1 : numel(override_fields)
    field_name = override_fields{k};
    merged.(field_name) = override_struct.(field_name);
end
end

function supported_names = localSupportedOptionNames()
supported_names = { ...
    'Cases', ...
    'Pfa', ...
    'GuardCells', ...
    'TrainCells', ...
    'MinRangeM', ...
    'CfarType', ...
    'OSRankFraction', ...
    'LocalMaxima', ...
    'LMRangeBins', ...
    'LMDoppBins', ...
    'MinSNRDB', ...
    'ATSCGuardPenaltyDB', ...
    'ATSCGuardWidthBins', ...
    'NotchGuardDoppBins', ...
    'RunTruthDiagnostics', ...
    'PlotCases', ...
    'PlotDetectionTimeSeries', ...
    'PlotRDMOverlays', ...
    'GateRangeCells', ...
    'GateDopplerBins', ...
    'TimeGateS', ...
    'ShowRDMLabels', ...
    'ConnectRDMTruthSamples', ...
    'MaxAircraft', ...
    'Verbose'};
end

function args = localNormalizeNameValueArgs(args_in, supported_names)
args = args_in;
if isempty(args)
    return
end

if mod(numel(args), 2) ~= 0
    return
end

for k = 1 : 2 : numel(args)
    name_value = args{k};
    if ~(ischar(name_value) || isstring(name_value))
        continue
    end

    canonical_name = localMatchSupportedName(name_value, supported_names);
    if strlength(canonical_name) == 0
        suggestion = localSuggestSupportedName(name_value, supported_names);
        message = sprintf('Unknown option ''%s''.', char(string(name_value)));
        if strlength(suggestion) > 0
            message = sprintf('%s Did you mean ''%s''?', message, char(suggestion));
        end
        error('runDetectorReplaySweep:unknownOption', '%s', message);
    end

    args{k} = char(canonical_name);
end
end

function canonical_name = localMatchSupportedName(name_value, supported_names)
name_value = char(string(name_value));
canonical_name = "";

exact_idx = find(strcmpi(supported_names, name_value), 1, 'first');
if ~isempty(exact_idx)
    canonical_name = string(supported_names{exact_idx});
    return
end

prefix_matches = startsWith(supported_names, name_value, 'IgnoreCase', true);
if nnz(prefix_matches) == 1
    canonical_name = string(supported_names{find(prefix_matches, 1, 'first')});
end
end

function suggestion = localSuggestSupportedName(name_value, supported_names)
name_value = char(string(name_value));
best_score = inf;
best_name = "";

for k = 1 : numel(supported_names)
    candidate = supported_names{k};
    score = localEditDistance(lower(name_value), lower(candidate));
    if score < best_score
        best_score = score;
        best_name = string(candidate);
    end
end

if best_score <= max(3, ceil(strlength(best_name) / 4))
    suggestion = best_name;
else
    suggestion = "";
end
end

function [case_overrides, alias_pairs] = localNormalizeCaseOverrides(case_overrides)
alias_pairs = strings(0, 1);
if isempty(case_overrides)
    return
end

alias_map = { ...
    'guardCells', 'GuardCells'; ...
    'trainCells', 'TrainCells'; ...
    'minRangeM', 'MinRangeM'; ...
    'cfarType', 'CfarType'; ...
    'cfarOptions', 'CfarOptions'; ...
    'osRankFraction', 'OSRankFraction'; ...
    'localMaxima', 'LocalMaxima'; ...
    'lmRangeBins', 'LMRangeBins'; ...
    'lmDoppBins', 'LMDoppBins'; ...
    'minSNRDB', 'MinSNRDB'; ...
    'atscGuardPenaltyDB', 'ATSCGuardPenaltyDB'; ...
    'atscGuardWidthBins', 'ATSCGuardWidthBins'; ...
    'notchGuardDoppBins', 'NotchGuardDoppBins'};

for ic = 1 : numel(case_overrides)
    fields_ic = fieldnames(case_overrides(ic));
    for im = 1 : size(alias_map, 1)
        alias_name = alias_map{im, 1};
        canonical_name = alias_map{im, 2};
        alias_idx = find(strcmpi(fields_ic, alias_name), 1, 'first');
        if isempty(alias_idx)
            continue
        end

        actual_alias_name = fields_ic{alias_idx};
        if strcmp(actual_alias_name, canonical_name)
            continue
        end

        if isfield(case_overrides(ic), canonical_name)
            error('runDetectorReplaySweep:duplicateCaseField', ...
                ['Cases entry %d includes both ''%s'' and ''%s''. ' ...
                 'Keep only the canonical field name.'], ...
                ic, actual_alias_name, canonical_name);
        end

        alias_pairs(end+1, 1) = string(sprintf('%s -> %s', actual_alias_name, canonical_name)); %#ok<AGROW>
    end
end

alias_pairs = unique(alias_pairs);
end

function distance = localEditDistance(source_text, target_text)
source_text = char(source_text);
target_text = char(target_text);

n_source = numel(source_text);
n_target = numel(target_text);
dp = zeros(n_source + 1, n_target + 1);
dp(:, 1) = 0 : n_source;
dp(1, :) = 0 : n_target;

for i = 2 : n_source + 1
    for j = 2 : n_target + 1
        substitution_cost = double(source_text(i-1) ~= target_text(j-1));
        dp(i, j) = min([ ...
            dp(i-1, j) + 1, ...
            dp(i, j-1) + 1, ...
            dp(i-1, j-1) + substitution_cost]);
    end
end

distance = dp(end, end);
end
