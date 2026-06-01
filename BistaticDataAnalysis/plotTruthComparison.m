function plotTruthComparison(adsb_aligned, tracks_log, metrics, varargin)
%PLOTTRUTHCOMPARISON  Visualise radar-pipeline-vs-ADS-B-truth comparison.
%
%  Produces a two-panel dark-background figure:
%
%  ┌── Panel 1 ─────────────────────────────────────────────────────────────┐
%  │  R_excess vs t_abs_s                                                    │
%  │  • ADS-B truth: dashed lines, one colour per aircraft                   │
%  │  • KF track estimates: solid lines + ±1σ shaded band (if State_cov      │
%  │    is provided), matching TRK_ID_COLORS palette                         │
%  └─────────────────────────────────────────────────────────────────────────┘
%  ┌── Panel 2 ─────────────────────────────────────────────────────────────┐
%  │  Error histograms                                                        │
%  │  Left  sub-plot:  ΔR_excess [m]  histogram for all TP detections        │
%  │  Right sub-plot:  Δf_D [Hz]      histogram for all TP detections        │
%  │  Both include a Normal distribution fit overlay                          │
%  └─────────────────────────────────────────────────────────────────────────┘
%
% ── SYNTAX ──────────────────────────────────────────────────────────────────
%   plotTruthComparison(adsb_aligned, tracks_log, metrics)
%   plotTruthComparison(..., 'TrkIdColors', clr_matrix)
%   plotTruthComparison(..., 'FigureTitle', 'My dataset')
%   plotTruthComparison(..., 'SavePDF', '/path/to/output.pdf')
%
% ── INPUTS ──────────────────────────────────────────────────────────────────
%   adsb_aligned   Struct array from alignTruthToRadar.
%                  Fields used: .hex, .callsign, .t_abs_s, .R_excess_m.
%
%   tracks_log     Struct array of KF track histories.
%                  Preferred fields: .t_abs_s, .R_excess_m, .TrackID,
%                  .StateCovDiag (optional; row = diag(P_k)).
%                  Legacy fallback: .t_abs_s with .State(:,1) = R_excess [m].
%                  Pass [] to show truth-only (no track overlay).
%
%   metrics        Struct from assessTruthVsDetections.
%                  Fields used: .det_range_err_m, .det_doppler_err_hz.
%                  Pass [] to skip the error histogram panel.
%
% ── OPTIONAL NAME-VALUE PARAMETERS ──────────────────────────────────────────
%   'TrkIdColors'   [N×3] RGB matrix — track colour palette.
%                   Default: same 12-colour palette used in analyzeBistaticData.
%
%   'FigureTitle'   char/string appended to figure suptitle.  Default: ''.
%
%   'SavePDF'       char/string path.  If non-empty, saves figure to PDF.
%                   Default: '' (no save).
%
%   'MaxAircraft'   Max number of ADS-B tracks to plot in Panel 1.
%                   Default: 8 (avoids cluttered legends).
%
% ── TOOLBOX REQUIREMENTS ────────────────────────────────────────────────────
%   Statistics and Machine Learning Toolbox — for fitdist/pdf (Normal fit).
%   If not available, the Normal overlay is skipped gracefully.
%
% See also: assessTruthVsDetections, alignTruthToRadar, analyzeBistaticData.

% =========================================================================
%  0.  Parse inputs
% =========================================================================

% Default 12-colour palette (same as analyzeBistaticData.m §7.3)
default_colors = [ ...
    0.929, 0.165, 0.165;  %  1  red
    0.216, 0.494, 0.722;  %  2  blue
    0.180, 0.722, 0.310;  %  3  green
    0.780, 0.220, 0.780;  %  4  magenta
    0.980, 0.600, 0.100;  %  5  orange
    0.220, 0.820, 0.820;  %  6  cyan
    0.750, 0.500, 0.150;  %  7  brown
    0.550, 0.850, 0.200;  %  8  lime
    0.950, 0.400, 0.700;  %  9  pink
    0.400, 0.200, 0.700;  % 10  purple
    0.700, 0.700, 0.200;  % 11  yellow
    0.500, 0.500, 0.900]; % 12  lavender

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'adsb_aligned');
addRequired(p, 'tracks_log');
addRequired(p, 'metrics');
addParameter(p, 'TrkIdColors',  default_colors, @(x) isnumeric(x) && size(x,2)==3);
addParameter(p, 'FigureTitle',  '',  @(x) ischar(x) || isstring(x));
addParameter(p, 'SavePDF',      '',  @(x) ischar(x) || isstring(x));
addParameter(p, 'MaxAircraft',  8,   @(x) isnumeric(x) && x > 0);
parse(p, adsb_aligned, tracks_log, metrics, varargin{:});
opts = p.Results;

TRK_COLORS  = opts.TrkIdColors;
N_TRK_CLR   = size(TRK_COLORS, 1);
BG_COLOR    = [0.10, 0.10, 0.10];   % dark background
GRID_COLOR  = [0.30, 0.30, 0.30];   % subtle grid

% Determine which panels to draw
has_tracks  = ~isempty(tracks_log);
has_metrics = ~isempty(metrics) && isfield(metrics, 'det_range_err_m') && ...
              ~isempty(metrics.det_range_err_m);
has_truth   = ~isempty(adsb_aligned) && ...
              any(~cellfun(@isempty, {adsb_aligned.R_excess_m}));

if ~has_truth
    warning('plotTruthComparison:noTruth', ...
        'adsb_aligned has no valid data — nothing to plot.');
    return
end

% =========================================================================
%  1.  Create figure
% =========================================================================
if has_metrics
    fig = figure('Color', BG_COLOR, 'Position', [80, 80, 1400, 820]);
    n_rows = 2;  n_cols = 2;
    ax_range = subplot(n_rows, n_cols, [1 2]);   % full top row
    ax_dR    = subplot(n_rows, n_cols, 3);
    ax_df    = subplot(n_rows, n_cols, 4);
else
    fig = figure('Color', BG_COLOR, 'Position', [80, 80, 1300, 520]);
    ax_range = axes(fig);
    ax_dR    = [];
    ax_df    = [];
end

% =========================================================================
%  2.  Panel 1: R_excess vs t_abs_s
% =========================================================================
axes(ax_range);
hold(ax_range, 'on');
set(ax_range, 'Color', BG_COLOR, 'XColor', [0.85 0.85 0.85], ...
    'YColor', [0.85 0.85 0.85], 'GridColor', GRID_COLOR, 'GridAlpha', 0.5);
grid(ax_range, 'on');
xlabel(ax_range, 't_{abs} [s]',          'Color', [0.85 0.85 0.85]);
ylabel(ax_range, 'R_{excess} [km]',      'Color', [0.85 0.85 0.85]);

% ── 2a. ADS-B truth dashed lines ────────────────────────────────────────
N_ac     = min(numel(adsb_aligned), opts.MaxAircraft);
adsb_clr = lines(N_ac);   % MATLAB default qualitative colours for truth

legend_handles = gobjects(0);
legend_labels  = {};

for k = 1 : N_ac
    ac = adsb_aligned(k);
    if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
        continue
    end
    valid = ~isnan(ac.R_excess_m);
    if ~any(valid)
        continue
    end
    h = plot(ax_range, ac.t_abs_s(valid), ac.R_excess_m(valid) / 1e3, ...
        '--', 'Color', adsb_clr(k, :), 'LineWidth', 1.5);
    legend_handles(end+1) = h; %#ok<AGROW>
    label = ac.callsign;
    if isempty(strtrim(label))
        label = ac.hex;
    end
    legend_labels{end+1} = ['ADS-B: ', label]; %#ok<AGROW>
end

% ── 2b. KF track estimates: solid lines + optional ±1σ shading ──────────
if has_tracks
    N_trk = numel(tracks_log);
    for ti = 1 : N_trk
        trk = tracks_log(ti);
        [tid, t_trk, R_trk_km, sigma_R_km] = extractTrackPlotSeries(trk, ti);
        if isempty(t_trk) || isempty(R_trk_km)
            continue
        end
        clr = TRK_COLORS(mod(tid - 1, N_TRK_CLR) + 1, :);

        % ±1σ shading from state covariance diagonal (optional)
        if ~isempty(sigma_R_km)
            fill(ax_range, [t_trk; flipud(t_trk)], ...
                [R_trk_km + sigma_R_km; flipud(R_trk_km - sigma_R_km)], ...
                clr, 'FaceAlpha', 0.20, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end

        h = plot(ax_range, t_trk, R_trk_km, '-', 'Color', clr, 'LineWidth', 2.0);
        legend_handles(end+1) = h; %#ok<AGROW>
        legend_labels{end+1}  = sprintf('Track %d', tid); %#ok<AGROW>
    end
end

if ~isempty(legend_handles)
    leg = legend(ax_range, legend_handles, legend_labels, ...
        'Location', 'best', 'FontSize', 8, 'TextColor', [0.85 0.85 0.85]);
    leg.Color = [0.15 0.15 0.15];
end

title_str = 'R_{excess}(t): ADS-B Truth vs Radar';
if ~isempty(opts.FigureTitle)
    title_str = [title_str, '  —  ', char(opts.FigureTitle)];
end
title(ax_range, title_str, 'Color', [0.9 0.9 0.9], 'FontSize', 11);

% =========================================================================
%  3.  Panel 2: Error histograms  (only if metrics are available)
% =========================================================================
if has_metrics && ~isempty(ax_dR)

    dR_err = metrics.det_range_err_m(~isnan(metrics.det_range_err_m));
    df_err = metrics.det_doppler_err_hz(~isnan(metrics.det_doppler_err_hz));

    % ── 3a. Range error histogram ────────────────────────────────────────
    axes(ax_dR);
    set(ax_dR, 'Color', BG_COLOR, 'XColor', [0.85 0.85 0.85], ...
        'YColor', [0.85 0.85 0.85], 'GridColor', GRID_COLOR, 'GridAlpha', 0.5);
    hold(ax_dR, 'on');
    grid(ax_dR, 'on');

    if ~isempty(dR_err)
        edges_R = linspace(min(dR_err) - 5, max(dR_err) + 5, 40);
        histogram(ax_dR, dR_err, edges_R, 'FaceColor', [0.216, 0.494, 0.722], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.8, 'Normalization', 'pdf');

        % Normal fit overlay
        try
            pd  = fitdist(dR_err, 'Normal');
            x_R = linspace(min(dR_err)-50, max(dR_err)+50, 200);
            plot(ax_dR, x_R, pdf(pd, x_R), 'w-', 'LineWidth', 1.8);
            text(ax_dR, 0.98, 0.95, ...
                sprintf('\\mu=%.1f m\n\\sigma=%.1f m', pd.mu, pd.sigma), ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', 'Color', [0.9 0.9 0.9], 'FontSize', 9);
        catch
            % Statistics Toolbox not available — skip fit overlay
        end
    end
    xlabel(ax_dR, '\DeltaR_{excess} [m]',  'Color', [0.85 0.85 0.85]);
    ylabel(ax_dR, 'PDF',                   'Color', [0.85 0.85 0.85]);
    title(ax_dR,  'Range Error (TP detections)', 'Color', [0.9 0.9 0.9], 'FontSize', 10);

    % ── 3b. Doppler error histogram ──────────────────────────────────────
    axes(ax_df);
    set(ax_df, 'Color', BG_COLOR, 'XColor', [0.85 0.85 0.85], ...
        'YColor', [0.85 0.85 0.85], 'GridColor', GRID_COLOR, 'GridAlpha', 0.5);
    hold(ax_df, 'on');
    grid(ax_df, 'on');

    if ~isempty(df_err)
        edges_f = linspace(min(df_err) - 2, max(df_err) + 2, 40);
        histogram(ax_df, df_err, edges_f, 'FaceColor', [0.180, 0.722, 0.310], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.8, 'Normalization', 'pdf');

        try
            pd  = fitdist(df_err, 'Normal');
            x_f = linspace(min(df_err)-20, max(df_err)+20, 200);
            plot(ax_df, x_f, pdf(pd, x_f), 'w-', 'LineWidth', 1.8);
            text(ax_df, 0.98, 0.95, ...
                sprintf('\\mu=%.2f Hz\n\\sigma=%.2f Hz', pd.mu, pd.sigma), ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', 'Color', [0.9 0.9 0.9], 'FontSize', 9);
        catch
        end
    end
    xlabel(ax_df, '\Deltaf_D [Hz]',                 'Color', [0.85 0.85 0.85]);
    ylabel(ax_df, 'PDF',                            'Color', [0.85 0.85 0.85]);
    title(ax_df,  'Doppler Error (TP detections)',  'Color', [0.9 0.9 0.9], 'FontSize', 10);

    % ── Stats annotation summary below histograms ─────────────────────────
    if ~isempty(dR_err)
        fprintf('[plotTruthComparison] Range error:    N=%d  mean=%.1f m  RMS=%.1f m\n', ...
            numel(dR_err), mean(dR_err), sqrt(mean(dR_err.^2)));
    end
    if ~isempty(df_err)
        fprintf('[plotTruthComparison] Doppler error:  N=%d  mean=%.2f Hz  RMS=%.2f Hz\n', ...
            numel(df_err), mean(df_err), sqrt(mean(df_err.^2)));
    end
end

% =========================================================================
%  4.  Save
% =========================================================================
if ~isempty(opts.SavePDF)
    exportgraphics(fig, char(opts.SavePDF), 'ContentType', 'vector', ...
        'BackgroundColor', BG_COLOR);
    fprintf('[plotTruthComparison] Saved: %s\n', opts.SavePDF);
end

fprintf('[plotTruthComparison] Figure ready.\n\n');

end  % ════════════════════ end plotTruthComparison ════════════════════

function [tid, t_trk, R_trk_km, sigma_R_km] = extractTrackPlotSeries(trk, fallback_tid)
tid        = fallback_tid;
t_trk      = zeros(0, 1);
R_trk_km   = zeros(0, 1);
sigma_R_km = zeros(0, 1);

if isfield(trk, 'TrackID') && ~isempty(trk.TrackID)
    tid = trk.TrackID;
end

if ~isfield(trk, 't_abs_s') || isempty(trk.t_abs_s)
    return
end
t_trk = trk.t_abs_s(:);

if isfield(trk, 'R_excess_m') && ~isempty(trk.R_excess_m)
    R_trk_km = trk.R_excess_m(:) / 1e3;
elseif isfield(trk, 'State') && ~isempty(trk.State) && size(trk.State, 2) >= 1
    R_trk_km = trk.State(:, 1) / 1e3;
else
    t_trk = zeros(0, 1);
    return
end

if isfield(trk, 'StateCovDiag') && ~isempty(trk.StateCovDiag)
    sigma_R_km = sqrt(max(trk.StateCovDiag(:, 1), 0)) / 1e3;
elseif isfield(trk, 'StateCovariance') && ~isempty(trk.StateCovariance)
    sigma_R_km = sqrt(max(diag(trk.StateCovariance), 0)) / 1e3;
end
end
