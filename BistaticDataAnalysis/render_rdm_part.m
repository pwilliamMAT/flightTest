function render_rdm_part(ax, lbl, sld, part_data, n, n_parts, params)
%RENDER_RDM_PART Render one part in the single-window per-part RDM viewer.
%
% part_data(n) is expected to contain:
%   part_index, time_window_s, rdm_image, range_axis, doppler_axis,
%   detections, and optionally truth_data.
%
% See also: analyzeBistaticData, helperPlotRDMTruthOverlay.

if ~isempty(sld) && isgraphics(sld)
    set(sld, 'Value', n);
end

pd = part_data(n);

cla(ax);
imagesc(ax, pd.doppler_axis, pd.range_axis, pd.rdm_image);
set(ax, 'YDir', 'normal');
colormap(ax, 'parula');
clim(ax, params.clim);
xlabel(ax, 'Doppler (Hz)', 'Color', 'w');
ylabel(ax, 'Bistatic range excess (m)', 'Color', 'w');
ylim(ax, [0, params.max_display_range_m]);

cb = colorbar(ax, 'eastoutside');
cb.Color = 'w';
cb.Label.String = 'dB above local noise floor (whitened)';
cb.Label.Color = 'w';

hold(ax, 'on');

legend_handles = gobjects(0, 1);
legend_labels = strings(0, 1);

n_det = size(pd.detections, 1);
if n_det > 0
    h_det = scatter(ax, pd.detections(:, 2), pd.detections(:, 1), 80, 'ro', ...
        'LineWidth', 2, 'DisplayName', sprintf('Detections (n=%d)', n_det));
    legend_handles(end + 1, 1) = h_det;
    legend_labels(end + 1, 1) = "Detections";
end

n_truth = 0;
if isfield(pd, 'truth_data') && ~isempty(pd.truth_data)
    [n_truth, h_truth] = helperPlotRDMTruthOverlay(ax, pd.truth_data, ...
        'TimeWindow', pd.time_window_s, ...
        'ConnectSamples', true, ...
        'ShowLabels', true, ...
        'IncludeLegend', true, ...
        'DisplayName', 'ADS-B truth', ...
        'MarkerSize', 80, ...
        'LineWidth', 1.4, ...
        'LabelOffsetHz', 8);
    if isgraphics(h_truth)
        legend_handles(end + 1, 1) = h_truth;
        legend_labels(end + 1, 1) = "ADS-B truth";
    end
end

if ~isempty(legend_handles)
    legend(ax, legend_handles, cellstr(legend_labels), 'Location', 'northeast', ...
        'TextColor', 'white', 'Color', [0.20, 0.20, 0.20]);
end

hold(ax, 'off');

title(ax, sprintf([ ...
    'Post-ECA-C RDM (whitened) - Part %d/%d - %d detection(s) - ' ...
    'ADS-B truth %d pt(s)'], ...
    pd.part_index, n_parts, n_det, n_truth), ...
    'Color', 'w', 'FontSize', 9);

if ~isempty(lbl) && isgraphics(lbl)
    set(lbl, 'String', sprintf( ...
        'Part %d / %d     t = [%.3f, %.3f] s', ...
        pd.part_index, n_parts, pd.time_window_s(1), pd.time_window_s(2)));
end

drawnow;

end
