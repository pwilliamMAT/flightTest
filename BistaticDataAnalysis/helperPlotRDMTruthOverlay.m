function [n_points, h_legend] = helperPlotRDMTruthOverlay(ax, truth_data, varargin)
%HELPERPLOTRDMTRUTHOVERLAY Overlay ADS-B truth on a range-Doppler axes.
%
%   [n_points, h_legend] = helperPlotRDMTruthOverlay(ax, truth_data, ...
%       'QueryTime', t_abs_s)
%
%   Draws the nearest aligned ADS-B truth sample to QueryTime for each
%   aircraft. This mode is used by the interactive RD viewer.
%
%   [n_points, h_legend] = helperPlotRDMTruthOverlay(ax, truth_data, ...
%       'TimeWindow', [t0, t1], 'ConnectSamples', true)
%
%   Draws all aligned ADS-B truth samples inside the time window. This mode
%   is used by the static per-part RDM figures.
%
% Inputs
%   ax         : target axes
%   truth_data : struct array from alignTruthToRadar
%
% Name-value options
%   'QueryTime'      : scalar absolute time [s]
%   'TimeWindow'     : [t0, t1] absolute time window [s]
%   'TimeTolerance'  : max |dt| when QueryTime is used (default: Inf)
%   'ConnectSamples' : true to draw a line through windowed samples
%   'ShowLabels'     : true to label plotted aircraft
%   'IncludeLegend'  : true to return one visible marker handle for legends
%   'DisplayName'    : legend label
%   'Color'          : RGB marker/line color
%   'MarkerSize'     : scatter marker size
%   'LineWidth'      : marker/line width
%   'LabelOffsetHz'  : x-offset for labels in Doppler Hz
%
% Outputs
%   n_points   : total number of truth points rendered
%   h_legend   : one scatter handle suitable for a legend, or an invalid
%                graphics handle when nothing was drawn
%
% See also: alignTruthToRadar, analyzeBistaticData, render_rdm_step.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'ax', @(x) isgraphics(x, 'axes'));
addRequired(p, 'truth_data', @(x) isempty(x) || isstruct(x));
addParameter(p, 'QueryTime', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'TimeWindow', [NaN, NaN], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'TimeTolerance', Inf, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'ConnectSamples', false, @islogical);
addParameter(p, 'ShowLabels', true, @islogical);
addParameter(p, 'IncludeLegend', false, @islogical);
addParameter(p, 'DisplayName', 'ADS-B truth', @(x) ischar(x) || isstring(x));
addParameter(p, 'Color', [1.00, 0.92, 0.15], @(x) isnumeric(x) && numel(x) == 3);
addParameter(p, 'MarkerSize', 90, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LineWidth', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LabelOffsetHz', 8, @(x) isnumeric(x) && isscalar(x));
parse(p, ax, truth_data, varargin{:});
opts = p.Results;

use_query  = isfinite(opts.QueryTime);
use_window = all(isfinite(opts.TimeWindow));

if use_query == use_window
    error('helperPlotRDMTruthOverlay:badTimeMode', ...
        'Specify exactly one of QueryTime or TimeWindow.');
end

n_points = 0;
h_legend = gobjects(1);

if isempty(truth_data)
    return
end

hold_was_on = ishold(ax);
hold(ax, 'on');

for k = 1 : numel(truth_data)
    ac = truth_data(k);
    if ~isfield(ac, 't_abs_s') || ~isfield(ac, 'R_excess_m') || ~isfield(ac, 'f_D_hz')
        continue
    end
    if isempty(ac.t_abs_s) || isempty(ac.R_excess_m) || isempty(ac.f_D_hz)
        continue
    end

    t_vec = ac.t_abs_s(:);
    R_vec = ac.R_excess_m(:);
    f_vec = ac.f_D_hz(:);

    if use_query
        [dt_min, idx_t] = min(abs(t_vec - opts.QueryTime));
        if isempty(idx_t) || dt_min > opts.TimeTolerance
            continue
        end

        R_plot = R_vec(idx_t);
        f_plot = f_vec(idx_t);
        if ~(isfinite(R_plot) && isfinite(f_plot))
            continue
        end

        h_sc = scatter(ax, f_plot, R_plot, opts.MarkerSize, 'd', 'filled', ...
            'MarkerFaceColor', opts.Color, ...
            'MarkerEdgeColor', [0.10, 0.10, 0.10], ...
            'LineWidth', opts.LineWidth);

        n_points = n_points + 1;
        label_x  = f_plot;
        label_y  = R_plot;
    else
        t_win = sort(opts.TimeWindow(:)).';
        mask  = (t_vec >= t_win(1)) & (t_vec <= t_win(2)) & ...
                isfinite(R_vec) & isfinite(f_vec);
        if ~any(mask)
            continue
        end

        R_plot = R_vec(mask);
        f_plot = f_vec(mask);

        if opts.ConnectSamples && numel(R_plot) > 1
            plot(ax, f_plot, R_plot, '-', ...
                'Color', opts.Color, ...
                'LineWidth', max(1.0, opts.LineWidth - 0.25), ...
                'HandleVisibility', 'off');
        end

        h_sc = scatter(ax, f_plot, R_plot, opts.MarkerSize, 'd', 'filled', ...
            'MarkerFaceColor', opts.Color, ...
            'MarkerEdgeColor', [0.10, 0.10, 0.10], ...
            'LineWidth', opts.LineWidth);

        n_points = n_points + numel(R_plot);
        label_x  = f_plot(end);
        label_y  = R_plot(end);
    end

    if opts.IncludeLegend && ~isgraphics(h_legend)
        set(h_sc, 'HandleVisibility', 'on', 'DisplayName', char(string(opts.DisplayName)));
        h_legend = h_sc;
    else
        set(h_sc, 'HandleVisibility', 'off');
    end

    if opts.ShowLabels
        label = '';
        if isfield(ac, 'callsign') && ~isempty(ac.callsign)
            label = strtrim(char(string(ac.callsign)));
        end
        if isempty(label) && isfield(ac, 'hex') && ~isempty(ac.hex)
            label = strtrim(char(string(ac.hex)));
        end
        if ~isempty(label)
            text(ax, label_x + opts.LabelOffsetHz, label_y, [' ', label], ...
                'Color', opts.Color, 'FontSize', 7, 'FontWeight', 'bold', ...
                'HandleVisibility', 'off');
        end
    end
end

if ~hold_was_on
    hold(ax, 'off');
end

end
