function render_rdm_step(ax, lbl, sld, step_data, n, N_steps, p)
%RENDER_RDM_STEP  Render one tracker time step in the interactive RD map viewer.
%
%   ax        — axes handle (classic MATLAB axes)
%   lbl       — step-label uicontrol handle (Style='text')
%   sld       — slider uicontrol handle (Style='slider')
%   step_data — (N_steps×1) struct with fields:
%                 t_abs_s      — absolute time of this step (s)
%                 i_part       — file-part index (1..N_parts)
%                 rdm_image    — whitened RDM [range × doppler] (dB)
%                 range_axis   — range axis vector [m]
%                 doppler_axis — Doppler axis vector [Hz]
%                 dets         — CFAR detections at this step [M×6]
%                 conf_trks    — objectTrack array for confirmed tracks
%   n         — step index to display (1 .. N_steps)
%   N_steps   — total number of tracker time steps
%   p         — params struct:
%                 alpha_trk           — Hz/(m/s)  2fc/c
%                 TRK_ID_COLORS       — [12×3] per-TrackID RGB palette
%                 N_ID_COLORS         — number of colours in palette
%                 CLIM_TRK            — [1×2] RDM colour axis limits [dB]
%                 max_display_range_m — y-axis upper limit [m]
%                 N_parts             — total number of file parts
%                 truth_data          — (optional) struct array from
%                                       alignTruthToRadar; if present,
%                                       ADS-B truth positions are drawn as
%                                       yellow diamond ◆ markers.
%
% Called from analyzeBistaticData.m §7.6 slider / button callbacks.
%
% See also: analyzeBistaticData, trackTargets.

% ── Update slider position (for programmatic navigation from buttons) ─────
set(sld, 'Value', n);

sd = step_data(n);

% ── RDM background ────────────────────────────────────────────────────────
cla(ax);
imagesc(ax, sd.doppler_axis, sd.range_axis, sd.rdm_image);
set(ax, 'YDir', 'normal');
colormap(ax, 'parula');
clim(ax, p.CLIM_TRK);
xlabel(ax, 'Doppler  (Hz)',             'Color', 'w');
ylabel(ax, 'Bistatic range excess  (m)', 'Color', 'w');
ylim(ax, [0, p.max_display_range_m]);
colorbar(ax, 'eastoutside', 'Color', 'w');
hold(ax, 'on');

% ── CFAR detections at this exact time step — white × ────────────────────
n_dets = size(sd.dets, 1);
if n_dets > 0
    % White markers stand out against the parula colormap regardless of RDM value.
    scatter(ax, sd.dets(:, 2), sd.dets(:, 1), 90, 'wx', ...
        'LineWidth', 2.5, 'HandleVisibility', 'off');
end

% ── Confirmed track states ────────────────────────────────────────────────
conf_trks = sd.conf_trks;
n_trk     = numel(conf_trks);

for ii = 1 : n_trk
    st    = conf_trks(ii).State;
    P     = conf_trks(ii).StateCovariance;
    tid   = conf_trks(ii).TrackID;
    R_est = st(1);
    D_est = p.alpha_trk * st(2);    % range-rate → Doppler via α = 2fc/c

    % 1σ uncertainties — capped to keep error bars on-screen
    sigma_R = min(sqrt(max(0, P(1,1))), 5000);           % cap at 5 km
    sigma_D = min(p.alpha_trk * sqrt(max(0, P(2,2))), 500); % cap at 500 Hz

    clr = p.TRK_ID_COLORS(mod(tid - 1, p.N_ID_COLORS) + 1, :);

    % Filled circle at estimated state
    scatter(ax, D_est, R_est, 160, clr, 'filled', 'HandleVisibility', 'off');

    % ±1σ error cross (horizontal = Doppler uncertainty,
    %                  vertical   = range uncertainty)
    plot(ax, D_est + sigma_D * [-1, 1], [R_est, R_est], ...
        '-', 'Color', clr, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot(ax, [D_est, D_est], R_est + sigma_R * [-1, 1], ...
        '-', 'Color', clr, 'LineWidth', 1.5, 'HandleVisibility', 'off');

    % TrackID label — same colour as the marker
    text(ax, D_est + 8, R_est, sprintf(' T%d', tid), ...
        'Color', clr, 'FontSize', 8, 'FontWeight', 'bold', ...
        'HandleVisibility', 'off');
end

% ── ADS-B truth overlay (optional) ───────────────────────────────────────
%  If step_data(n).truth_data is populated by §8 of analyzeBistaticData,
%  render yellow diamond ◆ markers at each aircraft's (f_D, R_excess).
%  Uses HandleVisibility='off' to keep the legend clean.
if isfield(sd, 'truth_data') && ~isempty(sd.truth_data)
    td = sd.truth_data;   % struct array from alignTruthToRadar
    for kt = 1 : numel(td)
        ac = td(kt);
        if isempty(ac.t_abs_s) || isempty(ac.R_excess_m)
            continue
        end
        % Nearest interpolated sample to this step's time
        [~, idx_t] = min(abs(ac.t_abs_s - sd.t_abs_s));
        R_truth = ac.R_excess_m(idx_t);
        f_truth = ac.f_D_hz(idx_t);
        if isnan(R_truth) || isnan(f_truth)
            continue
        end
        scatter(ax, f_truth, R_truth, 120, 'yd', 'filled', ...
            'HandleVisibility', 'off');
        label_ac = ac.callsign;
        if isempty(strtrim(label_ac))
            label_ac = ac.hex;
        end
        text(ax, f_truth + 8, R_truth, [' ', label_ac], ...
            'Color', [1 1 0], 'FontSize', 7, 'HandleVisibility', 'off');
    end
end

hold(ax, 'off');

% ── Title ─────────────────────────────────────────────────────────────────
title(ax, sprintf( ...
    'Step %d/%d  |  Part %d/%d  |  t = %.3f s  |  CFAR: %d det.  |  Tracks: %d', ...
    n, N_steps, sd.i_part, p.N_parts, sd.t_abs_s, n_dets, n_trk), ...
    'Color', 'w', 'FontSize', 9);

% ── Step info label above the axes ────────────────────────────────────────
set(lbl, 'String', sprintf( ...
    'Step  %d / %d     Part %d/%d     t = %.3f s', ...
    n, N_steps, sd.i_part, p.N_parts, sd.t_abs_s));

drawnow;

end  % ══════════════════════ end render_rdm_step ═══════════════════════════
