function render_rdm_step(ax, lbl, sld, step_data, n, N_steps, p)
%RENDER_RDM_STEP Render one tracker time step in the interactive RD viewer.
%
% step_data(n) is expected to contain:
%   t_abs_s, i_part, rdm_image, range_axis, doppler_axis, dets, conf_trks
% and optionally truth_data from alignTruthToRadar.
%
% See also: analyzeBistaticData, helperPlotRDMTruthOverlay, trackTargets.

set(sld, 'Value', n);

sd = step_data(n);

cla(ax);
imagesc(ax, sd.doppler_axis, sd.range_axis, sd.rdm_image);
set(ax, 'YDir', 'normal');
colormap(ax, 'parula');
clim(ax, p.CLIM_TRK);
xlabel(ax, 'Doppler (Hz)', 'Color', 'w');
ylabel(ax, 'Bistatic range excess (m)', 'Color', 'w');
ylim(ax, [0, p.max_display_range_m]);
colorbar(ax, 'eastoutside', 'Color', 'w');
hold(ax, 'on');

n_dets = size(sd.dets, 1);
if n_dets > 0
    scatter(ax, sd.dets(:, 2), sd.dets(:, 1), 90, 'wx', ...
        'LineWidth', 2.5, 'HandleVisibility', 'off');
end

conf_trks = sd.conf_trks;
n_trk     = numel(conf_trks);

for ii = 1 : n_trk
    st    = conf_trks(ii).State;
    P     = conf_trks(ii).StateCovariance;
    tid   = conf_trks(ii).TrackID;
    R_est = st(1);
    D_est = p.alpha_trk * st(2);

    sigma_R = min(sqrt(max(0, P(1, 1))), 5000);
    sigma_D = min(p.alpha_trk * sqrt(max(0, P(2, 2))), 500);
    clr     = p.TRK_ID_COLORS(mod(tid - 1, p.N_ID_COLORS) + 1, :);

    scatter(ax, D_est, R_est, 160, clr, 'filled', 'HandleVisibility', 'off');
    plot(ax, D_est + sigma_D * [-1, 1], [R_est, R_est], ...
        '-', 'Color', clr, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, [D_est, D_est], R_est + sigma_R * [-1, 1], ...
        '-', 'Color', clr, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    text(ax, D_est + 8, R_est, sprintf(' T%d', tid), ...
        'Color', clr, 'FontSize', 8, 'FontWeight', 'bold', ...
        'HandleVisibility', 'off');
end

n_truth = 0;
if isfield(sd, 'truth_data') && ~isempty(sd.truth_data)
    [n_truth, ~] = helperPlotRDMTruthOverlay(ax, sd.truth_data, ...
        'QueryTime', sd.t_abs_s, ...
        'ShowLabels', true, ...
        'IncludeLegend', false, ...
        'Color', [1.00, 0.92, 0.15], ...
        'MarkerSize', 115, ...
        'LineWidth', 1.2, ...
        'LabelOffsetHz', 8);
end

hold(ax, 'off');

title(ax, sprintf( ...
    'Step %d/%d  |  Part %d/%d  |  t = %.3f s  |  CFAR: %d det.  |  Tracks: %d  |  ADS-B: %d', ...
    n, N_steps, sd.i_part, p.N_parts, sd.t_abs_s, n_dets, n_trk, n_truth), ...
    'Color', 'w', 'FontSize', 9);

set(lbl, 'String', sprintf( ...
    'Step  %d / %d     Part %d/%d     t = %.3f s', ...
    n, N_steps, sd.i_part, p.N_parts, sd.t_abs_s));

drawnow;

end
