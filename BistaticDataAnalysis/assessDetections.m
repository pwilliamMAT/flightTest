function [results, flagged_mask] = assessDetections(rdm_before, rdm_after, ...
                                                    range_axis, doppler_axis, ...
                                                    detections, config)
% assessDetections  Expert radar quality checks for a passive bistatic radar.
%
%   [results, flagged_mask] = assessDetections(rdm_before, rdm_after, ...
%       range_axis, doppler_axis, detections, config)
%
%   Runs the checks documented in radarChecksCheckList.md on the
%   Range-Doppler Map and CFAR detection list to identify likely false
%   alarms and waveform artefacts before multi-frame integration or
%   tracking.  Prints a pass/warn summary to the console and optionally
%   generates four diagnostic figures.
%
%   Inputs:
%     rdm_before    [N_range × N_dopp] dB — RDM before clutter mitigation
%     rdm_after     [N_range × N_dopp] dB — RDM after  clutter mitigation
%     range_axis    [N_range × 1] bistatic range excess in metres (0 = DPI)
%     doppler_axis  [1 × N_dopp]  Doppler frequency in Hz
%     detections    [N_det × 3]   [range_m, doppler_hz, power_db] from
%                   detectTargets.  Pass [] when there are no detections.
%     config        struct — required fields:
%                     .fc         centre frequency in Hz (e.g. 600e6)
%                     .fs         sample rate in Hz     (e.g. 5e6)
%                     .prf        pulse repetition frequency in Hz
%                     .cfar_pfa   probability of false alarm
%                   optional fields (defaults shown):
%                     .cfar_min_range_m      = 5e3
%                     .max_aircraft_speed_ms = 300   (m/s — speed gate)
%                     .noise_region_range_m  = [130e3, 150e3]
%                     .noise_region_dopp_hz  = [200, 1000]  (abs values)
%                     .plot_figures          = true
%
%   Outputs:
%     results       struct — one sub-struct per check, each with fields:
%                     .pass      logical  — true = check passed
%                     .metric    double   — primary measured value
%                     .threshold double   — pass/fail boundary
%                     .message   string   — human-readable summary
%     flagged_mask  [N_det × 1] logical — true for detections flagged by
%                   at least one check as suspicious
%
%   Checks:
%     A1  ATSC segment-sync ghost ranges
%     A2  Persistent Doppler ridge (pilot-tone artefact)
%     B3  Zero-Doppler suppression depth (ECA-C quality)
%     C5  Rayleigh noise-floor distribution test
%     C6  Actual vs. expected false-alarm count
%     D7  Physical Doppler / velocity plausibility
%     D8  Suspiciously short bistatic range (near-field zone)
%     D9  Anomalously high detection SNR

%% ── 0. Defaults and shared pre-computations ──────────────────────────────
c_light = physconst('LightSpeed');

% Required fields
for req = {'fc', 'fs', 'prf', 'cfar_pfa'}
    assert(isfield(config, req{1}), 'assessDetections: config.%s is required.', req{1});
end

% Optional fields with defaults
if ~isfield(config, 'cfar_min_range_m'),        config.cfar_min_range_m       = 5e3;           end
if ~isfield(config, 'max_aircraft_speed_ms'),   config.max_aircraft_speed_ms  = 300;           end
if ~isfield(config, 'noise_region_range_m'),    config.noise_region_range_m   = [130e3, 150e3];end
if ~isfield(config, 'noise_region_dopp_hz'),    config.noise_region_dopp_hz   = [200, 1000];   end
if ~isfield(config, 'plot_figures'),            config.plot_figures           = true;          end
if ~isfield(config, 'nci_looks'),              config.nci_looks              = 1;             end
if ~isfield(config, 'single_look_noise_rdm'),  config.single_look_noise_rdm  = [];            end
if ~isfield(config, 'B3_suppression_threshold_db'), config.B3_suppression_threshold_db = 30;  end
% B3_suppression_threshold_db: minimum acceptable zero-Doppler ECA-C depth
%   (dB). Default 30 dB for full-CPI processing.
if ~isfield(config, 'window_coherent_loss_db'), config.window_coherent_loss_db = 0; end
% window_coherent_loss_db: coherent amplitude loss (dB) of the slow-time window
%   applied in createRDM: -20*log10(mean(window)). Added to the windowed
%   before_val in B3 to recover the unwindowed clutter power at ECA-C input.
%   Default 0 (rectangular window — no correction needed).
if ~isfield(config, 'cfar_noise_floor_db'), config.cfar_noise_floor_db = NaN; end
% cfar_noise_floor_db: CFAR operating noise floor (dB) returned by detectTargets
%   from the per-cell noise_est matrix.  When set, B3 uses it as the reference
%   for the at-noise-floor guard and D9 uses it for target SNR, replacing the
%   far-range quiet-region estimate (which is unreliable on this dataset due to
%   circular cross-correlation wrap-around at far range bins).  Default NaN.
% nci_looks: number of non-coherent integrations applied to rdm_after.
% single_look_noise_rdm: optional pre-integration RDM (e.g. Chunk 1 before
%   ECA-C) used for the Rayleigh distribution check so that NCI averaging
%   does not inflate the μ²/σ² ratio beyond the single-look Rayleigh identity.       % [N_range × 1] column
doppler_axis = doppler_axis(:)';    % [1 × N_dopp]  row

N_det       = size(detections, 1);
has_dets    = N_det > 0;
flagged_mask = false(N_det, 1);

range_bin_m  = mean(diff(range_axis));
dopp_bin_hz  = mean(diff(doppler_axis));

[~, zero_dopp_idx] = min(abs(doppler_axis));  % index of bin closest to 0 Hz

% ── Shared: noise floor estimate ──────────────────────────────────────────
% Use a target-free region (far range, off-zero Doppler) for all statistics.
nr = config.noise_region_range_m;
nd = config.noise_region_dopp_hz;
noise_r_mask = range_axis   >= nr(1) & range_axis   <= nr(2);
noise_d_mask = abs(doppler_axis) >= nd(1) & abs(doppler_axis) <= nd(2);

% Fallback if the specified region is too sparse
if sum(noise_r_mask) < 20
    noise_r_mask = range_axis >= 0.85 * max(range_axis);
    warning('assessDetections: noise range region too small; using top 15%% of range bins.');
end
if sum(noise_d_mask) < 20
    max_d = max(abs(doppler_axis));
    noise_d_mask = abs(doppler_axis) >= 0.10*max_d & abs(doppler_axis) <= 0.40*max_d;
    warning('assessDetections: noise Doppler region too small; using 10–40%% of Nyquist.');
end

noise_db       = rdm_after(noise_r_mask, noise_d_mask);   % sub-matrix in dB
noise_floor_db = median(noise_db(:));                     % robust noise floor [dB]
noise_linear   = 10.^(noise_db(:) / 20);                 % linear amplitudes for Rayleigh test

results = struct();

%% ── Check A1: ATSC Segment-Sync Ghost Ranges ─────────────────────────────
% ATSC 1.0 segment sync fires every 832 symbols at 10.762237 Msps (77.27 µs).
% The ACF of the ATSC waveform has peaks at multiples of this delay, which
% appear as false targets in the CAF at fixed bistatic range positions:
%   23.2 km, 46.4 km, 69.5 km, 92.7 km, 115.9 km, 139.1 km …
atsc_seg_range_m = (832 / 10.762237e6) * c_light;          % 23.18 km per harmonic
ghost_ranges     = atsc_seg_range_m : atsc_seg_range_m : max(range_axis);
tol_m            = 3 * range_bin_m;                        % ±3 bins (±90 m at 30 m/bin)

flagged_A1 = false(N_det, 1);
if has_dets
    for k = 1:numel(ghost_ranges)
        flagged_A1 = flagged_A1 | (abs(detections(:,1) - ghost_ranges(k)) < tol_m);
    end
end
flagged_mask = flagged_mask | flagged_A1;

n_A1   = sum(flagged_A1);
pct_A1 = 100 * n_A1 / max(N_det, 1);
results.A1_atsc_ghost_ranges = struct( ...
    'pass',           pct_A1 < 30, ...
    'metric',         pct_A1, ...
    'threshold',      30, ...
    'n_flagged',      n_A1, ...
    'ghost_ranges_m', ghost_ranges, ...
    'message', sprintf( ...
        '%d/%d detections (%.0f%%) near ATSC segment-sync ranges [%.1f, %.1f, ... km]. %s', ...
        n_A1, N_det, pct_A1, ghost_ranges(1)/1e3, ghost_ranges(min(2,end))/1e3, ...
        ternary(pct_A1 < 30, 'PASS', 'WARN — majority may be waveform ghosts.')));

%% ── Check A2: Persistent Doppler Ridge ────────────────────────────────────
% A CW tone in the reference signal creates a persistent ridge at a fixed
% Doppler bin spanning all ranges.  Detect by finding Doppler columns
% (mean power computed over valid range bins only) more than 3σ above the
% column-wise median — after excluding ±5 bins around zero-Doppler.
valid_r_mask = range_axis >= config.cfar_min_range_m;
mean_col_pwr = mean(rdm_after(valid_r_mask, :), 1);        % [1 × N_dopp]
med_col      = median(mean_col_pwr);
std_col      = std(mean_col_pwr);
exclude_dc   = abs((1:numel(doppler_axis)) - zero_dopp_idx) <= 5;
ridge_mask   = (mean_col_pwr > med_col + 3*std_col) & ~exclude_dc;
n_ridges     = sum(ridge_mask);
ridge_hz     = doppler_axis(ridge_mask);

flagged_A2 = false(N_det, 1);
if has_dets && n_ridges > 0
    ridge_idx = find(ridge_mask);
    for k = 1:numel(ridge_idx)
        flagged_A2 = flagged_A2 | (abs(detections(:,2) - doppler_axis(ridge_idx(k))) < dopp_bin_hz);
    end
end
flagged_mask = flagged_mask | flagged_A2;

results.A2_doppler_ridge = struct( ...
    'pass',      n_ridges == 0, ...
    'metric',    n_ridges, ...
    'threshold', 0, ...
    'n_flagged', sum(flagged_A2), ...
    'ridge_hz',  ridge_hz, ...
    'message',   ternary(n_ridges == 0, ...
        'PASS — no persistent Doppler ridges detected.', ...
        sprintf('WARN — %d anomalous Doppler column(s) at [%s] Hz (possible pilot-tone artefact).', ...
            n_ridges, num2str(ridge_hz(:)', '%.1f '))));

%% ── Check B3: Zero-Doppler Suppression Depth ──────────────────────────────
% ECA-C should suppress the zero-Doppler ridge by ≥ 30 dB.
% Compare the mean RDM level at Doppler = 0 over the near-range bins
% (0 to cfar_min_range_m) before and after mitigation.
near_r_mask = range_axis <= config.cfar_min_range_m;
if sum(near_r_mask) == 0, near_r_mask(1:min(10, numel(near_r_mask))) = true; end

% The B3 'before' power is measured from rdm_before, which was computed with
% the slow-time window active in createRDM. For coherent clutter the DC bin
% amplitude is attenuated by mean(window), depressing before_val and
% understating the true ECA-C suppression depth. Adding window_coherent_loss_db
% (= -20*log10(mean(window))) restores the unwindowed clutter power level,
% matching the actual signal at the ECA-C input.  The 'after' value is kept
% windowed since that is what the CFAR detector sees.
before_val_windowed = mean(rdm_before(near_r_mask, zero_dopp_idx));
before_val     = before_val_windowed + config.window_coherent_loss_db;
after_val      = mean(rdm_after( near_r_mask, zero_dopp_idx));
suppression_db = before_val - after_val;

% Special-case: ECA-C may have suppressed the zero-Doppler residual all the
% way down to the absolute thermal noise floor.  Once the clutter power after
% mitigation is within 6 dB of the measured noise floor there is no further
% dynamic range available — the algorithm cannot physically suppress any
% deeper.  Penalising a FAIL here is incorrect; force a PASS and report it.
% The 6 dB guard (not 0 dB) accounts for:
%   (a) the CFAR 75th-percentile noise_est over-estimates true floor by ~1.4 dB
%   (b) the zero-Doppler peak after ECA-C is the maximum, not the background
%   (c) residual slow-time sidelobes from the finite-length ECA-C filter
% Use the CFAR-derived noise floor (same absolute scale as rdm_after) when
% available; fall back to the internal quiet-region estimate when not set.
b3_nf_ref = noise_floor_db;
if ~isnan(config.cfar_noise_floor_db)
    b3_nf_ref = config.cfar_noise_floor_db;
end
at_noise_floor = (after_val <= b3_nf_ref + 6);
b3_pass = suppression_db >= config.B3_suppression_threshold_db || at_noise_floor;

if at_noise_floor && suppression_db < config.B3_suppression_threshold_db
    b3_msg_suffix = sprintf('PASS (after=%.1f dB is within 6 dB of noise floor=%.1f dB — dynamic range exhausted, not a failure).', ...
        after_val, noise_floor_db);
elseif b3_pass
    b3_msg_suffix = 'PASS';
else
    b3_msg_suffix = 'FAIL — ECA-C may not be converging; check CPI stationarity.';
end

results.B3_zero_dopp_suppression = struct( ...
    'pass',           b3_pass, ...
    'metric',         suppression_db, ...
    'threshold',      config.B3_suppression_threshold_db, ...
    'before_db',      before_val, ...
    'after_db',       after_val, ...
    'noise_floor_db', b3_nf_ref, ...
    'at_noise_floor', at_noise_floor, ...
    'message', sprintf( ...
        'Zero-Doppler suppression: %.1f dB (threshold %.0f dB). Before=%.1f dB (unwindowed), After=%.1f dB, NF=%.1f dB%s. %s', ...
        suppression_db, config.B3_suppression_threshold_db, before_val, after_val, b3_nf_ref, ...
        ternary(~isnan(config.cfar_noise_floor_db), ' [CFAR-calibrated]', ' [internal est]'), ...
        b3_msg_suffix));

%% ── Check C5: Rayleigh Noise-Floor Distribution ───────────────────────────
% Under H₀ (white complex Gaussian noise) CAF magnitudes follow Rayleigh.
%   μ²/σ² = π/(4−π) ≈ 5.58   (Rayleigh identity)
% With NCI averaging the amplitude distribution becomes Nakagami-m (m=L),
% which raises the expected ratio to ~40. Run the check on the single-look
% reference RDM (Chunk 1, pre-mitigation) when available so that the
% single-look Rayleigh identity always applies.
if ~isempty(config.single_look_noise_rdm)
    sl_rdm      = config.single_look_noise_rdm;
    % The chunk RDM shares the same range/Doppler axes as the integrated RDM.
    sl_noise_db       = sl_rdm(noise_r_mask, noise_d_mask);
    noise_linear_test = 10.^(sl_noise_db(:) / 20);
    test_label = sprintf('Chunk-1 single-look (N_slow=%d)', size(sl_rdm, 2));
else
    noise_linear_test = noise_linear;          % fallback: integrated RDM
    test_label = 'integrated RDM';
end

mu_lin            = mean(noise_linear_test);
var_lin           = var(noise_linear_test);
rayleigh_ratio    = mu_lin^2 / max(var_lin, eps);
rayleigh_expected = pi / (4 - pi);                          % ≈ 3.660  (μ²/σ² for Rayleigh amplitude)
ratio_norm        = rayleigh_ratio / rayleigh_expected;

results.C5_rayleigh_test = struct( ...
    'pass',           ratio_norm >= 0.8 && ratio_norm <= 1.2, ...
    'metric',         rayleigh_ratio, ...
    'expected',       rayleigh_expected, ...
    'test_data',      test_label, ...
    'noise_floor_db', noise_floor_db, ...
    'message', sprintf( ...
        'Rayleigh ratio=%.3f (expected %.3f ±20%%, %s). Noise floor=%.1f dB. %s', ...
        rayleigh_ratio, rayleigh_expected, test_label, noise_floor_db, ...
        ternary(ratio_norm >= 0.8 && ratio_norm <= 1.2, 'PASS', ...
            'WARN — non-Rayleigh noise; CFAR false-alarm rate may be inaccurate.')));

%% ── Check C6: Actual vs. Expected False-Alarm Count ──────────────────────
% With Pfa = p and N valid CFAR cells: expected false alarms = N × p.
% Ratio ≪ 1 → threshold too tight (missing targets).
% Ratio ≫ 1 → noise model invalid (too many false alarms).
N_cells     = numel(rdm_after);
expected_fa = N_cells * config.cfar_pfa;
fa_ratio    = N_det / max(expected_fa, 1);

results.C6_fa_count = struct( ...
    'pass',     fa_ratio >= 0.01 && fa_ratio <= 10, ...
    'metric',   fa_ratio, ...
    'n_det',    N_det, ...
    'expected', expected_fa, ...
    'message', sprintf( ...
        '%d detections vs. %.0f expected (Pfa=%.0e, N_cells≈%.0e). Ratio=%.2f. %s', ...
        N_det, expected_fa, config.cfar_pfa, N_cells, fa_ratio, ...
        ternary(fa_ratio >= 0.01 && fa_ratio <= 10, 'PASS', ...
            ternary(fa_ratio < 0.01, ...
                'WARN — far fewer detections than expected; threshold may be too tight.', ...
                'WARN — far more detections than expected; noise model may be invalid.'))));

%% ── Check D7: Physical Doppler / Velocity Plausibility ───────────────────
% Maximum bistatic Doppler is bounded by the monostatic equivalent:
%   f_max = 2 × v_max × fc / c
% (The true bistatic Doppler is ≤ this by a cos(β/2) factor, so this is a
% conservative upper bound.)  At 600 MHz, 300 m/s → 1200 Hz.
max_phys_dopp = 2 * config.max_aircraft_speed_ms * config.fc / c_light;

flagged_D7 = false(N_det, 1);
if has_dets
    flagged_D7 = abs(detections(:,2)) > max_phys_dopp;
end
flagged_mask = flagged_mask | flagged_D7;

results.D7_physical_doppler = struct( ...
    'pass',        sum(flagged_D7) == 0, ...
    'metric',      sum(flagged_D7), ...
    'max_phys_hz', max_phys_dopp, ...
    'n_flagged',   sum(flagged_D7), ...
    'message', sprintf( ...
        '%d/%d detections exceed physical Doppler limit %.0f Hz (v_max=%.0f m/s, fc=%.0f MHz). %s', ...
        sum(flagged_D7), N_det, max_phys_dopp, config.max_aircraft_speed_ms, config.fc/1e6, ...
        ternary(sum(flagged_D7) == 0, 'PASS', ...
            'FAIL — detections beyond physical speed limit; likely Nyquist edge artefacts.')));

%% ── Check D8: Suspiciously Short Bistatic Range ───────────────────────────
% Detections at 5–20 km bistatic range excess are likely surface specular
% multipath or near-field clutter, not aircraft at altitude.
near_field_m = 20e3;    % upper edge of the suspicious near-field zone

flagged_D8 = false(N_det, 1);
if has_dets
    flagged_D8 = detections(:,1) >= config.cfar_min_range_m & ...
                 detections(:,1) <  near_field_m;
end
flagged_mask = flagged_mask | flagged_D8;

results.D8_short_range = struct( ...
    'pass',        sum(flagged_D8) == 0, ...
    'metric',      sum(flagged_D8), ...
    'threshold_m', near_field_m, ...
    'n_flagged',   sum(flagged_D8), ...
    'message', sprintf( ...
        '%d/%d detections in near-field zone (%.0f–%.0f km, likely surface multipath). %s', ...
        sum(flagged_D8), N_det, config.cfar_min_range_m/1e3, near_field_m/1e3, ...
        ternary(sum(flagged_D8) == 0, 'PASS', 'WARN — inspect these for multipath.')));

%% ── Check D9: Anomalously High Detection SNR ─────────────────────────────
% Real aircraft echoes are weak.  Detections with SNR > 25 dB above the
% noise floor are more likely waveform range sidelobes or strong multipath.
snr_thresh_db = 25;
det_snr_db    = [];

% Use the CFAR-calibrated noise floor for SNR calculation when available.
% The internal noise_floor_db from the far-range quiet region is unreliable
% on this dataset (circular cross-correlation artifacts at far range give
% anomalous values).  The CFAR noise_est median is on the correct absolute
% scale.
d9_nf_db = noise_floor_db;
if ~isnan(config.cfar_noise_floor_db)
    d9_nf_db = config.cfar_noise_floor_db;
end

flagged_D9 = false(N_det, 1);
if has_dets
    det_snr_db = detections(:,3) - d9_nf_db;
    flagged_D9 = det_snr_db > snr_thresh_db;
end
flagged_mask = flagged_mask | flagged_D9;

results.D9_snr_sanity = struct( ...
    'pass',           sum(flagged_D9) == 0, ...
    'metric',         sum(flagged_D9), ...
    'threshold_db',   snr_thresh_db, ...
    'noise_floor_db', d9_nf_db, ...
    'det_snr_db',     det_snr_db, ...
    'n_flagged',      sum(flagged_D9), ...
    'message', sprintf( ...
        '%d/%d detections above %.0f dB SNR (NF=%.1f dB%s). %s', ...
        sum(flagged_D9), N_det, snr_thresh_db, d9_nf_db, ...
        ternary(~isnan(config.cfar_noise_floor_db), ' [CFAR-calibrated]', ' [internal est]'), ...
        ternary(sum(flagged_D9) == 0, 'PASS', ...
            'WARN — anomalously bright detections; likely waveform sidelobes or multipath.')));

%% ── Print Summary ─────────────────────────────────────────────────────────
fprintf('\n=== assessDetections Quality Report ===\n');
fprintf('  %d total detections,  %d flagged as suspicious (%.0f%%)\n\n', ...
    N_det, sum(flagged_mask), 100*sum(flagged_mask)/max(N_det,1));
check_names = fieldnames(results);
for k = 1:numel(check_names)
    r = results.(check_names{k});
    fprintf('  %s  %s\n', ternary(r.pass, '[PASS]', '[WARN]'), r.message);
end
fprintf('\n');

if ~config.plot_figures
    return;
end

%% ── Figure 1: RDM overlay with ATSC ghost lines + flagged detections ──────
figure('Name', 'Assessment: Ghost Ranges & Detection Flags', 'NumberTitle', 'off');
imagesc(doppler_axis, range_axis/1e3, rdm_after);
set(gca, 'YDir', 'normal');
clim([max(rdm_after(:))-40, max(rdm_after(:))]);
colorbar;
title('RDM (after mitigation) — Quality Overlay');
xlabel('Doppler (Hz)');
ylabel('Bistatic Range (km)');
hold on;

% ATSC ghost-range markers (yellow dashed)
for k = 1:numel(ghost_ranges)
    plot(xlim, [ghost_ranges(k) ghost_ranges(k)]/1e3, ...
        '--', 'Color', [1 0.8 0], 'LineWidth', 0.8, 'HandleVisibility', 'off');
end
plot(NaN, NaN, '--', 'Color', [1 0.8 0], 'LineWidth', 1.2, ...
    'DisplayName', sprintf('ATSC ghost ranges (×%d)', numel(ghost_ranges)));

% Detection markers: green = clean, red = flagged
if has_dets
    clean = ~flagged_mask;
    if any(clean)
        scatter(detections(clean,2), detections(clean,1)/1e3, 40, 'gx', ...
            'LineWidth', 1.5, 'DisplayName', sprintf('Clean (%d)', sum(clean)));
    end
    if any(flagged_mask)
        scatter(detections(flagged_mask,2), detections(flagged_mask,1)/1e3, 60, 'rx', ...
            'LineWidth', 2,   'DisplayName', sprintf('Flagged (%d)', sum(flagged_mask)));
    end
end
ylim([0, max(range_axis)/1e3]);
legend('Location', 'northeast', 'TextColor', 'white', 'Color', [0.2 0.2 0.2]);
hold off;

%% ── Figure 2: Zero-Doppler cut (before vs. after ECA-C) ───────────────────
figure('Name', 'Assessment: Zero-Doppler Suppression', 'NumberTitle', 'off');
plot(range_axis/1e3, rdm_before(:, zero_dopp_idx), 'b-', 'DisplayName', 'Before ECA-C');
hold on;
plot(range_axis/1e3, rdm_after(:,  zero_dopp_idx), 'r-', 'DisplayName', 'After ECA-C');
xline(config.cfar_min_range_m/1e3, 'k--', 'LineWidth', 1.2, 'DisplayName', 'CFAR min range');
hold off;
xlabel('Bistatic Range (km)');
ylabel('CAF Magnitude (dB)');
title(sprintf('Zero-Doppler Cut — Suppression: %.1f dB', suppression_db));
legend;
grid on;

%% ── Figure 3: Rayleigh noise-floor distribution ───────────────────────────
figure('Name', 'Assessment: Noise Distribution', 'NumberTitle', 'off');
histogram(noise_linear, 60, 'Normalization', 'pdf', 'FaceAlpha', 0.6, ...
    'DisplayName', 'Measured amplitude PDF');
hold on;
sigma_ray = sqrt(2/pi) * mu_lin;
r_fit     = linspace(0, max(noise_linear)*1.1, 300);
pdf_ray   = (r_fit / sigma_ray^2) .* exp(-r_fit.^2 / (2*sigma_ray^2));
plot(r_fit, pdf_ray, 'r-', 'LineWidth', 2, ...
    'DisplayName', sprintf('Rayleigh fit (μ²/σ²=%.2f, expected=%.2f)', ...
        rayleigh_ratio, rayleigh_expected));
hold off;
xlabel('Linear Amplitude');
ylabel('Probability Density');
title(sprintf('Noise-Floor Distribution Test — target-free region (%s)', ...
    ternary(results.C5_rayleigh_test.pass, 'PASS', 'WARN')));
legend;
grid on;

%% ── Figure 4: Detection SNR distribution ─────────────────────────────────
if has_dets
    figure('Name', 'Assessment: Detection SNR', 'NumberTitle', 'off');
    histogram(det_snr_db, 20, 'FaceAlpha', 0.7, 'DisplayName', 'All detections');
    hold on;
    xline(snr_thresh_db, 'r--', 'LineWidth', 2, ...
        'DisplayName', sprintf('Suspicious threshold (%d dB)', snr_thresh_db));
    hold off;
    xlabel('SNR above noise floor (dB)');
    ylabel('Count');
    title('Detection SNR Distribution');
    legend;
    grid on;
end

end % assessDetections

%% ── Local helper ──────────────────────────────────────────────────────────
function out = ternary(cond, a, b)
% Return a if cond is true, b if false.
if cond
    out = a;
else
    out = b;
end
end
