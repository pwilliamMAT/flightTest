function truth_diag_output = runDetectionTruthDiagnostics(diag_input, varargin)
%RUNDETECTIONTRUTHDIAGNOSTICS Run standalone detection-vs-truth diagnostics.
%
% Plain-language goal:
%   The raw-IQ pipeline takes minutes, but the truth-side work should not.
%   This function takes a saved post-detection bundle and reruns only the
%   fast stages: ADS-B loading, bistatic projection, truth alignment,
%   detection-vs-truth assessment, and the plotting/checking views.
%
% Syntax
%   out = runDetectionTruthDiagnostics(diag_input)
%   out = runDetectionTruthDiagnostics('truth_diag_snapshot.mat')
%
% Input
%   diag_input  Either:
%                 - the bundle produced by buildDetectionTruthDiagnosticInput
%                 - a struct containing .truth_diag_input
%                 - a MAT-file path containing truth_diag_input
%
% Name-value options
%   'Verbose'                 Logical console output. Default: bundle value.
%   'FigureTitle'             Override figure title text.
%   'PlotDetectionTimeSeries' Create the range-vs-time and Doppler-vs-time
%                             detection/truth figure. Default: true.
%   'PlotRDMOverlays'         Create standalone static RDM truth overlays
%                             from the cached per-part RDM bundle. Default: true.
%   'PlotTrackComparison'     Also draw the legacy track-vs-truth figure.
%                             Default: false.
%   'GateRangeCells'          Range gate width for assessTruthVsDetections.
%   'GateDopplerBins'         Doppler gate width for assessTruthVsDetections.
%   'ShowRDMLabels'           Label aircraft on the RDM overlays.
%   'ConnectRDMTruthSamples'  Connect truth samples inside each part window.
%   'MaxAircraft'             Max aircraft to draw on the time-series figure.
%   'TrackColors'             Optional [N x 3] RGB palette passed through to
%                             plotTruthComparison.
%
% Output
%   truth_diag_output  Struct containing:
%     .truth_diag_input
%     .adsb_tracks
%     .adsb_bistatic
%     .adsb_aligned
%     .truth_metrics
%     .t_epoch_utc
%     .check_summary
%     .figure_handles
%
% See also: buildDetectionTruthDiagnosticInput, plotDetectionTruthDiagnostics,
%           assessTruthVsDetections.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'diag_input', @(x) isstruct(x) || ischar(x) || isstring(x));
addParameter(p, 'Verbose', [], @(x) isempty(x) || islogical(x));
addParameter(p, 'FigureTitle', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotDetectionTimeSeries', true, @islogical);
addParameter(p, 'PlotRDMOverlays', true, @islogical);
addParameter(p, 'PlotTrackComparison', false, @islogical);
addParameter(p, 'GateRangeCells', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'GateDopplerBins', 3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ShowRDMLabels', true, @islogical);
addParameter(p, 'ConnectRDMTruthSamples', true, @islogical);
addParameter(p, 'MaxAircraft', 12, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'TrackColors', [], @(x) isempty(x) || (isnumeric(x) && size(x, 2) == 3));
parse(p, diag_input, varargin{:});
opts = p.Results;

truth_diag_input = localResolveDiagnosticInput(diag_input);
verbose = localResolveVerbose(opts.Verbose, truth_diag_input);

localValidateBundle(truth_diag_input);

figure_handles = struct( ...
    'detection_truth', gobjects(1), ...
    'track_comparison', gobjects(1), ...
    'rdm_overlays', gobjects(0, 1));

truth_diag_output = struct( ...
    'truth_diag_input', truth_diag_input, ...
    'adsb_tracks', struct([]), ...
    'adsb_bistatic', struct([]), ...
    'adsb_aligned', struct([]), ...
    'truth_metrics', struct(), ...
    't_epoch_utc', NaN, ...
    'check_summary', struct(), ...
    'figure_handles', figure_handles);

figure_title = char(string(opts.FigureTitle));
if isempty(figure_title)
    figure_title = localResolveFigureTitle(truth_diag_input);
end

t_abs_query = localResolveTruthQueryTimes(truth_diag_input);
detections = localResolveDetections(truth_diag_input);
track_histories = localResolveTrackHistories(truth_diag_input);
t_epoch_utc = localResolveRadarEpoch(truth_diag_input, verbose);

if verbose
    fprintf('\n[runDetectionTruthDiagnostics] Running standalone truth diagnostics...\n');
    fprintf('  Parts ............ %d\n', numel(truth_diag_input.part_start_offsets_s));
    fprintf('  Detections ....... %d\n', numel(detections));
    fprintf('  ADS-B files ...... %d\n', numel(truth_diag_input.adsb_files));
    fprintf('  Truth query times  %d\n', numel(t_abs_query));
end

adsb_tracks = loadADSBTruth(truth_diag_input.adsb_files, 'Verbose', verbose);
adsb_bistatic = adsbToBistatic(adsb_tracks, truth_diag_input.txLLA, truth_diag_input.rxLLA, truth_diag_input.fc);
adsb_aligned = alignTruthToRadar(adsb_bistatic, t_epoch_utc, t_abs_query);

truth_metrics = assessTruthVsDetections( ...
    detections, track_histories, adsb_aligned, ...
    'RangeCellM', truth_diag_input.range_cell_m, ...
    'DopplerBinHz', truth_diag_input.doppler_bin_hz, ...
    'GateRangeCells', opts.GateRangeCells, ...
    'GateDopplerBins', opts.GateDopplerBins, ...
    'Verbose', verbose);

check_summary = localBuildCheckSummary(truth_diag_input, adsb_aligned, detections, truth_metrics);
localPrintCheckSummary(check_summary);
localEmitWarnings(check_summary);

if opts.PlotRDMOverlays
    figure_handles.rdm_overlays = localPlotRDMOverlays( ...
        truth_diag_input, adsb_aligned, opts.ShowRDMLabels, opts.ConnectRDMTruthSamples);
end

if opts.PlotDetectionTimeSeries
    figure_handles.detection_truth = plotDetectionTruthDiagnostics( ...
        adsb_aligned, detections, truth_metrics, ...
        'FigureTitle', figure_title, ...
        'MaxAircraft', opts.MaxAircraft);
end

if opts.PlotTrackComparison
    if isempty(opts.TrackColors)
        plotTruthComparison(adsb_aligned, track_histories, truth_metrics, ...
            'FigureTitle', figure_title);
    else
        plotTruthComparison(adsb_aligned, track_histories, truth_metrics, ...
            'TrkIdColors', opts.TrackColors, ...
            'FigureTitle', figure_title);
    end
    figure_handles.track_comparison = gcf;
end

truth_diag_output.adsb_tracks = adsb_tracks;
truth_diag_output.adsb_bistatic = adsb_bistatic;
truth_diag_output.adsb_aligned = adsb_aligned;
truth_diag_output.truth_metrics = truth_metrics;
truth_diag_output.t_epoch_utc = t_epoch_utc;
truth_diag_output.check_summary = check_summary;
truth_diag_output.figure_handles = figure_handles;

if verbose
    fprintf('[runDetectionTruthDiagnostics] Complete.\n\n');
end

end

function truth_diag_input = localResolveDiagnosticInput(diag_input)
if ischar(diag_input) || isstring(diag_input)
    mat_path = char(string(diag_input));
    loaded = load(mat_path);
    if isfield(loaded, 'truth_diag_input')
        truth_diag_input = loaded.truth_diag_input;
        return
    end
    if isfield(loaded, 'diag_input')
        truth_diag_input = loaded.diag_input;
        return
    end
    error('runDetectionTruthDiagnostics:missingBundle', ...
        'MAT-file %s does not contain truth_diag_input.', mat_path);
end

if isstruct(diag_input) && isfield(diag_input, 'truth_diag_input')
    truth_diag_input = diag_input.truth_diag_input;
    return
end

if isstruct(diag_input) && isfield(diag_input, 'schema_version')
    truth_diag_input = diag_input;
    return
end

error('runDetectionTruthDiagnostics:badInput', ...
    'Input must be a diagnostic bundle, a struct containing .truth_diag_input, or a MAT-file path.');
end

function verbose = localResolveVerbose(opt_verbose, truth_diag_input)
if isempty(opt_verbose)
    if isfield(truth_diag_input, 'verbose') && ~isempty(truth_diag_input.verbose)
        verbose = logical(truth_diag_input.verbose);
    else
        verbose = false;
    end
else
    verbose = logical(opt_verbose);
end
end

function localValidateBundle(truth_diag_input)
required_fields = { ...
    'adsb_files', ...
    'txLLA', ...
    'rxLLA', ...
    'fc', ...
    'range_cell_m', ...
    'doppler_bin_hz', ...
    'part_start_offsets_s', ...
    'part_end_offsets_s'};

for k = 1 : numel(required_fields)
    field_name = required_fields{k};
    if ~isfield(truth_diag_input, field_name)
        error('runDetectionTruthDiagnostics:missingField', ...
            'truth_diag_input.%s is required.', field_name);
    end
end

if isempty(truth_diag_input.adsb_files)
    error('runDetectionTruthDiagnostics:noADSBFiles', ...
        'truth_diag_input.adsb_files is empty. No truth source is available.');
end
end

function figure_title = localResolveFigureTitle(truth_diag_input)
if isfield(truth_diag_input, 'analysis_label') && ~isempty(truth_diag_input.analysis_label)
    figure_title = char(string(truth_diag_input.analysis_label));
elseif isfield(truth_diag_input, 'session_id') && ~isempty(truth_diag_input.session_id)
    figure_title = sprintf('Session %s', char(string(truth_diag_input.session_id)));
else
    figure_title = 'Detection Truth Diagnostics';
end
end

function t_abs_query = localResolveTruthQueryTimes(truth_diag_input)
if isfield(truth_diag_input, 't_abs_query') && ~isempty(truth_diag_input.t_abs_query)
    t_abs_query = truth_diag_input.t_abs_query(:);
    return
end

required_fields = {'part_dur_s', 'chunk_dur_s', 'max_nci_looks'};
for k = 1 : numel(required_fields)
    if ~isfield(truth_diag_input, required_fields{k})
        error('runDetectionTruthDiagnostics:missingTimingField', ...
            'truth_diag_input.%s is required to rebuild t_abs_query.', required_fields{k});
    end
end

t_abs_query = helperBuildTruthQueryTimes( ...
    truth_diag_input.part_start_offsets_s, truth_diag_input.part_dur_s, ...
    truth_diag_input.chunk_dur_s, truth_diag_input.max_nci_looks);
end

function detections = localResolveDetections(truth_diag_input)
if isfield(truth_diag_input, 'detections') && ~isempty(truth_diag_input.detections)
    detections = truth_diag_input.detections;
    return
end

if isfield(truth_diag_input, 'all_track_dets')
    all_track_dets = truth_diag_input.all_track_dets;
    detections = struct( ...
        't_abs_s', num2cell(all_track_dets(:, 5)), ...
        'R_excess_m', num2cell(all_track_dets(:, 1)), ...
        'f_D_hz', num2cell(all_track_dets(:, 2)));
    return
end

detections = [];
end

function track_histories = localResolveTrackHistories(truth_diag_input)
if isfield(truth_diag_input, 'track_histories') && ~isempty(truth_diag_input.track_histories)
    track_histories = truth_diag_input.track_histories;
else
    track_histories = [];
end
end

function t_epoch_utc = localResolveRadarEpoch(truth_diag_input, verbose)
manual_epoch = [];
if isfield(truth_diag_input, 'radar_epoch_utc') && ~isempty(truth_diag_input.radar_epoch_utc)
    manual_epoch = truth_diag_input.radar_epoch_utc;
    if isnumeric(manual_epoch) && isscalar(manual_epoch) && isnan(manual_epoch)
        manual_epoch = [];
    end
end

probe_name = 'radar_recording';
if isfield(truth_diag_input, 'data_parts') && ~isempty(truth_diag_input.data_parts)
    probe_name = truth_diag_input.data_parts{1};
elseif isfield(truth_diag_input, 'session_id') && ~isempty(truth_diag_input.session_id)
    probe_name = truth_diag_input.session_id;
end

if isempty(manual_epoch)
    t_epoch_utc = getRadarEpoch(probe_name, 'Verbose', verbose);
else
    t_epoch_utc = getRadarEpoch(probe_name, 'ManualEpoch', manual_epoch, 'Verbose', verbose);
end
end

function check_summary = localBuildCheckSummary(truth_diag_input, adsb_aligned, detections, truth_metrics)
n_aircraft_total = numel(adsb_aligned);
n_aircraft_overlap = 0;
n_truth_visible = 0;
n_truth_in_display = 0;
max_display_dopp_hz = localResolveMaxDisplayDoppler(truth_diag_input);
max_display_range_m = Inf;
if isfield(truth_diag_input, 'max_display_range_m') && ~isempty(truth_diag_input.max_display_range_m)
    max_display_range_m = truth_diag_input.max_display_range_m;
end

for k = 1 : numel(adsb_aligned)
    if isfield(adsb_aligned(k), 'overlap_s') && adsb_aligned(k).overlap_s > 0
        n_aircraft_overlap = n_aircraft_overlap + 1;
    end

    valid = isfinite(adsb_aligned(k).R_excess_m) & isfinite(adsb_aligned(k).f_D_hz);
    n_truth_visible = n_truth_visible + sum(valid);

    display_mask = valid & (adsb_aligned(k).R_excess_m >= 0) & ...
        (adsb_aligned(k).R_excess_m <= max_display_range_m);
    if isfinite(max_display_dopp_hz)
        display_mask = display_mask & abs(adsb_aligned(k).f_D_hz) <= max_display_dopp_hz;
    end
    n_truth_in_display = n_truth_in_display + sum(display_mask);
end

n_detections = 0;
if isstruct(detections)
    n_detections = numel(detections);
elseif istable(detections)
    n_detections = height(detections);
end

per_part_truth_points = zeros(0, 1);
per_part_detection_counts = zeros(0, 1);
if isfield(truth_diag_input, 'part_start_offsets_s') && isfield(truth_diag_input, 'part_end_offsets_s')
    n_parts = numel(truth_diag_input.part_start_offsets_s);
    per_part_truth_points = zeros(n_parts, 1);
    per_part_detection_counts = zeros(n_parts, 1);
    for ip = 1 : n_parts
        t_window = [truth_diag_input.part_start_offsets_s(ip), truth_diag_input.part_end_offsets_s(ip)];
        for k = 1 : numel(adsb_aligned)
            valid = isfinite(adsb_aligned(k).R_excess_m) & isfinite(adsb_aligned(k).f_D_hz) & ...
                (adsb_aligned(k).t_abs_s >= t_window(1)) & (adsb_aligned(k).t_abs_s <= t_window(2));
            per_part_truth_points(ip) = per_part_truth_points(ip) + sum(valid);
        end

        if isfield(truth_diag_input, 'rdm_parts') && numel(truth_diag_input.rdm_parts) >= ip
            per_part_detection_counts(ip) = truth_diag_input.rdm_parts(ip).det_count;
        elseif isfield(truth_diag_input, 'all_track_dets') && ~isempty(truth_diag_input.all_track_dets)
            per_part_detection_counts(ip) = sum(truth_diag_input.all_track_dets(:, 6) == ip);
        end
    end
end

check_summary = struct( ...
    'n_aircraft_total', n_aircraft_total, ...
    'n_aircraft_overlap', n_aircraft_overlap, ...
    'n_truth_visible_samples', n_truth_visible, ...
    'n_truth_samples_in_display', n_truth_in_display, ...
    'n_detections', n_detections, ...
    'n_tp', localGetMetricField(truth_metrics, 'n_tp', 0), ...
    'n_fa', localGetMetricField(truth_metrics, 'n_fa', 0), ...
    'n_miss', localGetMetricField(truth_metrics, 'n_miss', 0), ...
    'per_part_truth_points', per_part_truth_points, ...
    'per_part_detection_counts', per_part_detection_counts);
end

function max_display_dopp_hz = localResolveMaxDisplayDoppler(truth_diag_input)
max_display_dopp_hz = Inf;

if ~isfield(truth_diag_input, 'rdm_parts') || isempty(truth_diag_input.rdm_parts)
    return
end

max_vals = zeros(0, 1);
for ip = 1 : numel(truth_diag_input.rdm_parts)
    if isfield(truth_diag_input.rdm_parts(ip), 'doppler_axis') && ...
            ~isempty(truth_diag_input.rdm_parts(ip).doppler_axis)
        max_vals(end + 1, 1) = max(abs(truth_diag_input.rdm_parts(ip).doppler_axis)); %#ok<AGROW>
    end
end

if ~isempty(max_vals)
    max_display_dopp_hz = max(max_vals);
end
end

function value = localGetMetricField(metrics, field_name, default_value)
if isstruct(metrics) && isfield(metrics, field_name) && ~isempty(metrics.(field_name))
    value = metrics.(field_name);
else
    value = default_value;
end
end

function localPrintCheckSummary(check_summary)
fprintf('[runDetectionTruthDiagnostics] Truth overlap: %d/%d aircraft, %d visible query samples (%d inside display).\n', ...
    check_summary.n_aircraft_overlap, check_summary.n_aircraft_total, ...
    check_summary.n_truth_visible_samples, check_summary.n_truth_samples_in_display);
fprintf('[runDetectionTruthDiagnostics] Detections: %d total, TP=%d, FA=%d, missed truth CPIs=%d.\n', ...
    check_summary.n_detections, check_summary.n_tp, check_summary.n_fa, check_summary.n_miss);

if ~isempty(check_summary.per_part_truth_points)
    for ip = 1 : numel(check_summary.per_part_truth_points)
        fprintf('  Part %d: %d truth point(s), %d detection(s).\n', ...
            ip, check_summary.per_part_truth_points(ip), check_summary.per_part_detection_counts(ip));
    end
end
end

function localEmitWarnings(check_summary)
if check_summary.n_aircraft_overlap == 0
    warning('runDetectionTruthDiagnostics:noOverlap', ...
        'No ADS-B aircraft overlap the radar window.');
end

if check_summary.n_truth_visible_samples == 0
    warning('runDetectionTruthDiagnostics:noVisibleTruth', ...
        'No finite truth samples were produced on the radar query grid.');
end

if check_summary.n_truth_samples_in_display == 0
    warning('runDetectionTruthDiagnostics:noTruthInDisplay', ...
        'Truth exists, but none of it falls inside the displayed RDM limits.');
end

if check_summary.n_detections > 0 && check_summary.n_tp == 0
    warning('runDetectionTruthDiagnostics:noTruePositives', ...
        'Detections exist, but none matched the projected truth within the current gates.');
end
end

function fig_handles = localPlotRDMOverlays(truth_diag_input, adsb_aligned, show_labels, connect_samples)
fig_handles = gobjects(0, 1);

if ~isfield(truth_diag_input, 'rdm_parts') || isempty(truth_diag_input.rdm_parts)
    return
end

fg_color = [0.90, 0.90, 0.90];
bg_color = [0.08, 0.08, 0.08];

for ip = 1 : numel(truth_diag_input.rdm_parts)
    part_info = truth_diag_input.rdm_parts(ip);
    if isempty(part_info.rdm_image) || isempty(part_info.range_axis) || isempty(part_info.doppler_axis)
        continue
    end

    fig = figure('Name', sprintf('Truth Overlay RDM - Part %d', ip), ...
        'NumberTitle', 'off', 'Color', bg_color, 'Position', [120 + 40 * ip, 80 + 30 * ip, 920, 620]);
    ax = axes(fig, 'Color', bg_color, 'XColor', fg_color, 'YColor', fg_color, 'FontSize', 9);
    imagesc(ax, part_info.doppler_axis, part_info.range_axis, part_info.rdm_image);
    set(ax, 'YDir', 'normal');
    colormap(ax, 'parula');
    if isfield(part_info, 'display_clim') && ~isempty(part_info.display_clim)
        clim(ax, part_info.display_clim);
    end
    xlabel(ax, 'Doppler (Hz)', 'Color', fg_color);
    ylabel(ax, 'Bistatic range excess (m)', 'Color', fg_color);
    if isfield(truth_diag_input, 'max_display_range_m') && isfinite(truth_diag_input.max_display_range_m)
        ylim(ax, [0, truth_diag_input.max_display_range_m]);
    end
    cb = colorbar(ax, 'eastoutside');
    cb.Color = fg_color;
    cb.Label.String = 'dB above local noise floor (whitened)';
    hold(ax, 'on');

    legend_handles = gobjects(0, 1);
    if ~isempty(part_info.detections)
        h_det = scatter(ax, part_info.detections(:, 2), part_info.detections(:, 1), 82, 'w', 'x', ...
            'LineWidth', 2.2, 'DisplayName', sprintf('Detections (n=%d)', size(part_info.detections, 1)));
        legend_handles(end + 1, 1) = h_det; %#ok<AGROW>
    end

    [n_truth_pts, h_truth] = helperPlotRDMTruthOverlay(ax, adsb_aligned, ...
        'TimeWindow', part_info.time_window_s, ...
        'ConnectSamples', connect_samples, ...
        'ShowLabels', show_labels, ...
        'IncludeLegend', true, ...
        'DisplayName', 'ADS-B truth', ...
        'Color', [1.00, 0.92, 0.15], ...
        'MarkerSize', 84, ...
        'LineWidth', 1.4, ...
        'LabelOffsetHz', 8);

    if isgraphics(h_truth)
        legend_handles(end + 1, 1) = h_truth; %#ok<AGROW>
    end

    if ~isempty(legend_handles)
        leg = legend(ax, legend_handles, 'Location', 'northeast', 'FontSize', 8);
        leg.Color = [0.16, 0.16, 0.16];
        leg.TextColor = fg_color;
    end

    title(ax, sprintf('Whitened RDM - Part %d - %d detection(s) - ADS-B truth %d point(s)', ...
        ip, part_info.det_count, n_truth_pts), 'Color', fg_color, 'FontSize', 10);
    hold(ax, 'off');

    fig_handles(end + 1, 1) = fig; %#ok<AGROW>
end
end
