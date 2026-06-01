% analyzeBistaticData.m
%
% This is the main script for the passive bistatic radar signal processing
% chain. It orchestrates the calling of various processing functions to
% load, analyze, and process the radar data.
%
% Workflow:
% 1. Define configuration parameters.
% 2. Load IQ data using loadIQData.m.
% 3. Perform a synchronization check.
% 4. Mitigate direct-path interference (DPI) and clutter.
% 5. Detect targets using 2-D CA-CFAR on the clutter-mitigated RDM.
% 6. (Future) Bistatic range estimation.
% 7. (Future) Target tracking.

%% 0. Clear Workspace
clear; clc; close all;

%% 1. Configuration Parameters
% ── Verbosity flag ──────────────────────────────────────────────────────
%   false (default): one summary line per phase; warnings and the detection
%                    table are always shown.
%   true:            full per-chunk / per-block debug output from all functions.
verbose = false;   % ← set true for troubleshooting

if verbose
    fprintf('1. Configuring parameters...\n');
end
config.dataFile = '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_1'; % Path to IQ data
config.numSamples = 8e6;       % 1s of data at 8 Msps
config.fs = 8e6;               % Sample rate in Hz
config.fc = 599e6;             % Centre frequency in Hz (CBS Tower, Newton MA, used for Doppler→velocity)
config.cpi_duration_s = 0.5e-3; % CPI duration: 0.5 ms → PRF = 2000 Hz → ±250 m/s unambiguous velocity
                                % N_fast = 4000 samples → range window ≈ 150 km  (c/fs × N_fast)
                                % N_slow = numSamples/N_fast = 2000 CPIs → Doppler resolution = 1 Hz/bin
                                % (was 10 ms → ±12.5 m/s; aircraft at 250 m/s were Doppler-aliased to ~0 Hz)
% Calculate PRF from CPI duration
config.prf = 1 / config.cpi_duration_s;
% Maximum bistatic range to display (bistatic range excess beyond the DPI).
% Deployment is on top of a parking garage; targets of interest are aircraft
% at 10–150 km. The range axis in createRDM is relative to the detected DPI
% lag, so 0 m = DPI and positive values = bistatic range to aircraft.
config.max_display_range_m = 150e3; % 150 km
config.cfar_pfa         = 1e-4;   % CFAR probability of false alarm (relaxed to recover lower-SNR candidates; tighten to 1e-5 if FA density is high)
config.cfar_min_range_m = 5e3;    % suppress detections below 5 km (DPI sidelobes)
config.cfar_guard_cells = [6, 2]; % guard half-widths [range, Doppler]; range increased 4→6 for waveform sideband smearing
%
% CFAR options — each field is optional; omit to fall back to defaults.
% Set cfar_type to 'CA' to restore the original Cell-Averaging behaviour.
config.cfar_options.cfar_type        = 'OS';   % OS-CFAR: robust to ATSC range-sidelobe spikes
config.cfar_options.os_rank_fraction = 0.75;   % 75th-percentile rank (immune to ~25% contamination)
config.cfar_options.local_maxima     = true;   % collapse detection clusters into single points
config.cfar_options.lm_range_bins    = 4;      % local-maxima neighbourhood: ±4 bins = ±120 m
config.cfar_options.lm_dopp_bins     = 2;      % local-maxima neighbourhood: ±2 bins = ±2 Hz
config.cfar_options.min_snr_db       = 0;      % extra margin above threshold (0 = disabled)
% ATSC ghost-range guard zones: raise CFAR threshold by 10 dB at each
% n × 23.18 km segment-sync harmonic (up to max_display_range_m).
% The ATSC waveform's segment-sync symbol repeats every 832 symbols at
% 10.762237 Msps → 77.27 µs → 23.18 km range harmonic spacing.
atsc_seg_m_ = (832 / 10.762237e6) * physconst('LightSpeed');  % 23.18 km step
config.cfar_options.atsc_guard_ranges_m  = atsc_seg_m_ : atsc_seg_m_ : config.max_display_range_m;
config.cfar_options.atsc_guard_penalty_db = 10;   % dB extra threshold at ghost ranges
config.cfar_options.atsc_guard_width_bins = 3;    % ±3 range bins (±90 m) per guard zone
% Reference channel quality thresholds (used by checkRefQuality in step 2b).
config.ref_snr_threshold_db = 10;    % min reference SNR in dB
config.ref_sfm_threshold_db = -15;   % min spectral flatness in dB
% Sub-chunk non-coherent integration parameters.
% Each 200-CPI (100 ms) block is individually clutter-mitigated; the
% resulting power maps are averaged non-coherently.
config.N_slow_cpi = 200;             % slow-time samples per sub-CPI (100 ms at PRF=2000 Hz)
% Maximum non-coherent integration looks per detection block.
% Physics constraint: at 8 MSps the bistatic range cell is c/fs ≈ 37.5 m.  A target
% at 200 m/s travels ~37.5 m in 188 ms (1.9 × 100 ms chunks) — one full range
% bin.  Capping NCI at 2 looks keeps the target within its resolution cell
% and prevents inter-frame range walk from smearing the peak.
config.max_nci_looks = 2;
% Slow-time window applied in createRDM before the Doppler FFT: Kaiser(β=6).
% Coherent loss = -20*log10(mean(kaiser(N,6))). Computed at runtime so the
% B3 correction in assessDetections automatically tracks any N_slow_cpi change.
config.window_type              = 'kaiser';
config.window_coherent_loss_db  = -20 * log10(mean(kaiser(config.N_slow_cpi, 6)));
% Zero-Doppler ECA-C suppression threshold (B3 check).
% B3 now compares unwindowed 'before' power vs windowed 'after' power, which
% recovers the true clutter power at the ECA-C input. 30 dB is correct.
config.B3_suppression_threshold_db = 30;  % dB — true operational target
% CFAR zero-Doppler guard: prevents the ECA-C Stage-2 subspace notch from
% pulling CFAR training-cell estimates downward. Width = N_cancel bins.
config.cfar_options.notch_guard_dopp_bins = max(1, round(3 * config.N_slow_cpi / 2000));
% Derived dynamically from N_slow_cpi to match N_cancel inside mitigateClutter
% (max(1, round(3*N_slow/2000))). For N_slow_cpi=200 this gives 1 bin.
% Channel swap flag.
% Set to true if the power diagnostic printed by loadIQData shows CH1 (RX1)
% is significantly stronger than CH2 (RX2).  That pattern means the reference
% antenna (directional, aimed at the ATSC tower) was plugged into the RX1
% port instead of RX2, inverting the default CH1=Surv / CH2=Ref assignment.
% Symptom: reference SNR ≈ 0 dB + ECA-C suppression depth ≈ 0 dB.
config.swap_channels = false;   % ← set true if reference antenna is on RX1
config.verbose       = verbose; % propagate to all called functions
% ── Site coordinates (Newton MA deployment, 21 May 2026) ────────────────
%   Tx: CBS Tower, Newton MA  (599 MHz ATSC)
%   Rx: Parking-garage rooftop, 4 Apple Hill Dr, Newton MA
config.txLLA = [42.310278,  -71.236667, 431.9];   % [lat °N, lon °W(−), alt m MSL]
config.rxLLA = [42.2999333, -71.349333,  15.0];   % [lat °N, lon °W(−), alt m MSL]
% ── Inter-part gap (Natick dataset, 21 May 2026) ────────────────────────
%   Measured from BasebandFileWriter header DateTime stamps:
%     • File 1→2 gap: ~5.96 s  (first-capture hardware-init overhead)
%     • Files 2→10:   ~2.7–3.1 s  (steady-state: pause(repspace) + writer overhead)
%   Using nominal 3.0 s for KF propagation (steady-state average).
%   For production, read per-file DateTime from headers and compute exact Δt.
config.inter_part_gap_s = 3.0;  % [s] nominal steady-state gap (measured ~2.85 s avg)

%% 2. Multi-Part Processing
% Run the full ECA-C + bounded-NCI + CFAR pipeline on each consecutive
% 1-second Natick data file.  processOnePart encapsulates steps 2–5 and
% returns detections with block-number and block-centre-time metadata.
data_parts = { ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_1',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_2',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_3',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_4',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_5',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_6',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_7',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_8',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_9',  ...
    '../../04_Natick_Ah_Pkg_May_21_26/n320_599_8Msps_100ms_10'  ...
};
N_parts    = numel(data_parts);
part_dur_s = config.numSamples / config.fs;   % 1.0 s per part

% Pre-allocate per-part result storage.
part_res = struct( ...
    'detections',   cell(1, N_parts), ...
    'cfar_nf_db',   cell(1, N_parts), ...
    'rdm_before',   cell(1, N_parts), ...
    'rdm_after',    cell(1, N_parts), ...
    'range_axis',   cell(1, N_parts), ...
    'doppler_axis', cell(1, N_parts));

for i_part = 1 : N_parts
    fprintf('\n[Part %d/%d]  %s\n', i_part, N_parts, data_parts{i_part});
    if config.verbose
        fprintf('  %s\n', repmat('-', 1, 52));
    end
    config.dataFile = data_parts{i_part};
    [dets, nf_db, rdm_b, rdm_a, rax, dax, config] = processOnePart(config);
    % Shift block_center_s (col 5) to absolute time within the full dataset,
    % including the inter-part wall-clock gap so the tracker's prediction
    % step uses the true elapsed time between consecutive file parts.
    if ~isempty(dets)
        dets(:, 5) = dets(:, 5) + (i_part - 1) * (part_dur_s + config.inter_part_gap_s);
    end
    part_res(i_part).detections  = dets;
    part_res(i_part).cfar_nf_db  = nf_db;
    part_res(i_part).rdm_before  = rdm_b;
    part_res(i_part).rdm_after   = rdm_a;
    part_res(i_part).range_axis  = rax;
    part_res(i_part).doppler_axis = dax;
end

%% 3. Consolidated Detection Trajectory
% Concatenate detections from all three parts, sort by absolute time, and
% print a trajectory table.  This lets us check whether the same aircraft
% appears consistently across parts (stable Doppler, smoothly evolving range).
all_track_dets = zeros(0, 6);   % cols: [range_m, dopp_hz, pwr_db, blk, t_abs_s, i_part]
for i_part = 1 : N_parts
    d = part_res(i_part).detections;
    if ~isempty(d)
        all_track_dets = [all_track_dets; ...
            d, repmat(i_part, size(d,1), 1)]; %#ok<AGROW>
    end
end

c_light_traj = physconst('LightSpeed');
fprintf('\n=== Consolidated Detection Trajectory  |  %d parts  |  %d detection(s) ===\n', ...
    N_parts, size(all_track_dets, 1));
if config.verbose
    fprintf('NF: CFAR noise floor — same absolute scale as RDM (raw ADC power, dB).\n');
    fprintf('Vel: Doppler-to-velocity uses monostatic approx: v = f_d * c / (2*fc).\n');
end
fprintf('\n');
fprintf('%4s %4s  %9s  %10s  %10s  %8s  %8s\n', ...
    'Part', 'Blk', 'T_abs(s)', 'Range(km)', 'Dopp(Hz)', 'Vel(m/s)', 'SNR(dB)');
fprintf('%s\n', repmat('-', 1, 64));
if isempty(all_track_dets)
    fprintf('  (no detections across any part)\n');
else
    [~, sort_idx] = sort(all_track_dets(:, 5));
    all_track_dets = all_track_dets(sort_idx, :);
    for k = 1 : size(all_track_dets, 1)
        i_p   = all_track_dets(k, 6);
        rng_m = all_track_dets(k, 1);
        dop   = all_track_dets(k, 2);
        pwr   = all_track_dets(k, 3);
        blk   = all_track_dets(k, 4);
        t_abs = all_track_dets(k, 5);
        nf    = part_res(i_p).cfar_nf_db;
        vel   = dop * c_light_traj / (2 * config.fc);
        fprintf('  %3d  %3d   %7.3f   %10.3f   %9.1f   %7.1f   %6.1f\n', ...
            i_p, blk, t_abs, rng_m/1e3, dop, vel, pwr - nf);
    end
end
fprintf('%s\n\n', repmat('-', 1, 64));

%% 3.5. Cross-Frame Consistency Checks (E10 / E11 / E12)
%
% E10 (original definition — from radarChecksCheckList.md):
%   At least one detection persists across all 3 parts within ±2 range bins
%   AND ±2 Doppler bins.  Designed for stationary or slow-moving scatterers
%   (buildings, terrain multipath) where the target is in the same RDM cell
%   across consecutive 1-second captures.
%
%   For THIS DATASET: inter-part gap = 10 s, aircraft speed ~200 m/s →
%   bistatic range changes ~2000 m ≈ 67 range bins between parts.  E10 is
%   therefore EXPECTED TO FAIL.  A fail here is informative, not a problem —
%   it confirms targets are moving (aircraft) rather than stationary clutter.
%
% E11 (original definition):
%   A persistent detection (if E10 passes) shows a monotonic Doppler trend
%   across parts — consistent with smooth, linear aircraft motion.
%   Only evaluated when at least one E10 match exists.
%
% E12 (new — kinematic consistency for moving targets):
%   For aircraft detected across large inter-part gaps (Δt > ~1 s), E10's
%   range tolerance is physically inapplicable.  E12 checks instead for
%   cross-part Doppler consistency (within ±25 Hz, allowing ~1 Hz/s Doppler
%   rate × 10 s gap + margin) AND that the bistatic range trend is monotonic
%   in the direction implied by the Doppler sign:
%     f_D < 0  →  Ṙ > 0  →  range INCREASING
%     f_D > 0  →  Ṙ < 0  →  range DECREASING
%   E12 passes for a genuine aircraft track; E10 failing + E12 passing is the
%   expected outcome for this Newton dataset.
%
% IMPORTANT: E10/E11 should never be modified to match a specific dataset.
%   They are the canonical system-quality checks.  E12 handles the
%   kinematic-target case that E10 was not designed for.

if N_parts < 3 || isempty(all_track_dets)
    fprintf('[E10/E11/E12] Insufficient parts or no detections — skipping.\n\n');
else
    c_chk        = physconst('LightSpeed');
    range_bin_chk = c_chk / (2 * config.fs);                              % 30 m
    dopp_bin_chk  = 1 / (config.N_slow_cpi * config.cpi_duration_s);      % 10 Hz

    tol_range_e10 = 2 * range_bin_chk;    % ±2 bins ≈ ±60 m  (original E10)
    tol_dopp_e10  = 2 * dopp_bin_chk;     % ±2 bins ≈ ±20 Hz (original E10)
    tol_dopp_e12  = 2.5 * dopp_bin_chk;   % ±25 Hz (E12 kinematic check)

    dets_p1 = part_res(1).detections;   % [N × 5]: range,dopp,pwr,blk,t_abs
    dets_p2 = part_res(2).detections;
    dets_p3 = part_res(3).detections;

    % ── E10 / E11 (original) ─────────────────────────────────────────────
    e10_matches = zeros(0, 2);   % [range_p1, dopp_p1] for each match
    for k_chk = 1 : size(dets_p1, 1)
        r1 = dets_p1(k_chk, 1);
        d1 = dets_p1(k_chk, 2);
        in_p2 = any(abs(dets_p2(:,1) - r1) < tol_range_e10 & ...
                    abs(dets_p2(:,2) - d1) < tol_dopp_e10);
        in_p3 = any(abs(dets_p3(:,1) - r1) < tol_range_e10 & ...
                    abs(dets_p3(:,2) - d1) < tol_dopp_e10);
        if in_p2 && in_p3
            e10_matches(end+1, :) = [r1, d1]; %#ok<AGROW>
        end
    end

    fprintf('=== E10 / E11 (original checklist definition) ===\n');
    fprintf('  Tolerance: ±%.0f m range  AND  ±%.0f Hz Doppler\n', ...
        tol_range_e10, tol_dopp_e10);
    fprintf('  Part dets: %d / %d / %d\n', ...
        size(dets_p1,1), size(dets_p2,1), size(dets_p3,1));
    if isempty(e10_matches)
        fprintf('  E10: FAIL — 0 detections within tolerance across all 3 parts.\n');
        expected_range_shift = 200 * config.inter_part_gap_s;   % rough upper bound
        fprintf('  (EXPECTED for moving targets: at 200 m/s over %.0f s, range shifts\n', ...
            config.inter_part_gap_s);
        fprintf('   ~%.0f m ≈ %.0f range bins — far outside ±2-bin window.)\n', ...
            expected_range_shift, expected_range_shift / range_bin_chk);
        fprintf('  E11: N/A — no E10 match to evaluate.\n');
    else
        fprintf('  E10: PASS — %d persistent detection(s) found.\n', size(e10_matches,1));
        % E11: check Doppler monotonicity for each E10 match
        % (If E10 passed, the scatterer is at the same position → Doppler
        %  should also remain stable.  A monotonically drifting Doppler
        %  across 3 parts indicates a slowly-moving or manoeuvring target.)
        fprintf('  E11: Doppler trend for each E10 match:\n');
        for km = 1 : size(e10_matches, 1)
            r1 = e10_matches(km, 1);   d1 = e10_matches(km, 2);
            [~, ip2] = min(abs(dets_p2(:,1)-r1) + abs(dets_p2(:,2)-d1));
            [~, ip3] = min(abs(dets_p3(:,1)-r1) + abs(dets_p3(:,2)-d1));
            d2 = dets_p2(ip2, 2);   d3 = dets_p3(ip3, 2);
            e11 = (d2 > d1 && d3 > d2) || (d2 < d1 && d3 < d2);
            if e11, e11_str_chk = 'PASS'; else, e11_str_chk = 'FAIL (non-monotonic)'; end
            fprintf('    Match %d: Dopp = [%.1f, %.1f, %.1f] Hz — E11: %s\n', ...
                km, d1, d2, d3, e11_str_chk);
        end
    end
    fprintf('\n');

    % ── E12: kinematic consistency for moving targets ─────────────────────
    % cols: [range_p1, dopp_p1, range_p2, range_p3, e12_kine_pass]
    e12_matches = zeros(0, 5);
    for k_chk = 1 : size(dets_p1, 1)
        d1 = dets_p1(k_chk, 2);
        in_p2 = find(abs(dets_p2(:,2) - d1) < tol_dopp_e12, 1, 'first');
        in_p3 = find(abs(dets_p3(:,2) - d1) < tol_dopp_e12, 1, 'first');
        if ~isempty(in_p2) && ~isempty(in_p3)
            r1 = dets_p1(k_chk, 1);
            r2 = dets_p2(in_p2,  1);
            r3 = dets_p3(in_p3,  1);
            range_incr = (r2 > r1) && (r3 > r2);
            range_decr = (r2 < r1) && (r3 < r2);
            kine_pass  = (d1 < 0 && range_incr) || (d1 >= 0 && range_decr);
            e12_matches(end+1, :) = [r1, d1, r2, r3, double(kine_pass)]; %#ok<AGROW>
        end
    end

    fprintf('=== E12 (kinematic consistency — moving targets) ===\n');
    fprintf('  Tolerance: Doppler ±%.0f Hz across %.0f s inter-part gap\n', ...
        tol_dopp_e12, config.inter_part_gap_s);
    if isempty(e12_matches)
        fprintf('  E12: FAIL — no cross-part Doppler-consistent detections found.\n');
    else
        fprintf('  E12: PASS — %d kinematically consistent detection(s):\n\n', ...
            size(e12_matches, 1));
        fprintf('  %12s  %9s  %12s  %12s  %8s\n', ...
            'Range_P1(km)', 'Dopp(Hz)', 'Range_P2(km)', 'Range_P3(km)', 'Kine');
        for km = 1 : size(e12_matches, 1)
            if e12_matches(km,5), e12_str_chk = 'PASS'; else, e12_str_chk = 'FAIL'; end
            fprintf('  %12.3f  %9.1f  %12.3f  %12.3f  %8s\n', ...
                e12_matches(km,1)/1e3, e12_matches(km,2), ...
                e12_matches(km,3)/1e3, e12_matches(km,4)/1e3, ...
                e12_str_chk);
        end
    end
    fprintf('=====================================================\n\n');
end

%% 4. Quality Check on Representative Part (Part 1)
% Run the expert quality checks on Part 1 only (representative) to validate
% B3 (ECA-C suppression depth) and D9 (detection SNR) with the CFAR-
% calibrated noise floor now correctly passed via config.cfar_noise_floor_db.
rdm_before   = part_res(1).rdm_before;
rdm_after    = part_res(1).rdm_after;
range_axis   = part_res(1).range_axis;
doppler_axis = part_res(1).doppler_axis;
config.cfar_noise_floor_db = part_res(1).cfar_nf_db;

% Strip block/time columns (4-5) — assessDetections expects [range, dopp, pwr].
if ~isempty(part_res(1).detections)
    detections = part_res(1).detections(:, 1:3);
else
    detections = zeros(0, 3);
end

if config.verbose
    fprintf('5b. Expert radar quality checks (Part 1)...\n');
end
[~, flagged_mask] = assessDetections(rdm_before, rdm_after, ...
    range_axis, doppler_axis, detections, config);

% Range-whitened display RDM — apply the same per-row median normalisation
% used inside processOnePart's block CFAR to the full 10-look rdm_after so
% the "After" figure panels show a flat noise floor instead of the ~20 dB
% range-gradient.  rdm_after (unwhitened) was already passed to
% assessDetections above and continues to be the reference for B3 / D9.
rdm_after_display = rdm_after - median(rdm_after, 2);

% -------------------------------------------------------------------------
% HOW TO READ THESE PLOTS
% -------------------------------------------------------------------------
% Each subplot is a Range-Doppler Map (RDM) produced by the Cross-Ambiguity
% Function (CAF) — the standard output of a passive bistatic radar processor.
%
% X-AXIS — Doppler frequency (Hz):
%   The Doppler shift of a received echo, resolved by a slow-time FFT across
%   the 100 CPIs. Range: -PRF/2 to +PRF/2 = ±50 Hz. Resolution: 1 Hz/bin.
%   - Zero Doppler (centre):  static objects — ground, buildings, the DPI.
%   - Positive Doppler:       targets moving toward the receiver.
%   - Negative Doppler:       targets moving away from the receiver.
%   At 540 MHz, 1 Hz Doppler ≈ 0.28 m/s radial velocity. A commercial
%   aircraft at 250 m/s produces roughly ±900 Hz — well beyond the ±50 Hz
%   unambiguous range of a 100 Hz PRF. Increase the PRF (shorter CPI) or
%   use more CPIs to avoid Doppler aliasing on fast targets.
%
% Y-AXIS — Bistatic range excess (m):
%   The additional path length (TX→target→RX) beyond the direct path
%   (TX→RX), derived from the TDOA of the target echo relative to the DPI.
%   - Range = 0:              the Direct-Path Interference (DPI) peak — the
%                             broadcast signal arriving directly from the TV
%                             tower with no additional path delay.
%   - Range > 0:              echoes from targets or static reflectors at
%                             that bistatic range excess. Aircraft at 10 km
%                             bistatic range excess appear at 10,000 m.
%   Range resolution: c / (2 * fs) = 30 m/bin at 5 Msps.
%   Note: the absolute hardware timing offset between the USRP N320's two
%   ADC channels (~6387 samples, ~383 km) has been removed; range = 0 is
%   the DPI location, not absolute lag = 0.
%
% COLORSCALE — CAF Magnitude (dB):
%   20*log10(|CAF|), where |CAF| is the cross-correlation magnitude between
%   the surveillance and reference channels. The absolute dB values reflect
%   the raw ADC (int16) scaling and are NOT calibrated to physical power
%   units (dBm, dBW). Only RELATIVE differences matter: a bright cell is
%   above the noise floor by that many dB.
%   Display window: 40 dB dynamic range anchored to the peak value. Cells
%   more than 40 dB below the peak are clipped to the minimum colour.
%
% WHAT TO LOOK FOR:
%   - A bright horizontal ridge at Doppler = 0 (all ranges) in the "Before"
%     plot: zero-Doppler clutter from static buildings/terrain and DPI
%     range sidelobes.
%   - That ridge significantly reduced in the "After" plot: ECA-C working.
%   - Isolated bright cells at non-zero Doppler and positive range in the
%     "After" plot: candidate aircraft echoes above the noise floor.
%     These are inputs to the CFAR detector in the next processing stage.
% -------------------------------------------------------------------------
%% 5. Per-Part RDM Figures
% One figure per processed file part — each shows the range-whitened
% post-ECA-C RDM so the noise floor is flat across range and target echoes
% stand out clearly against a uniform background.
%
% Colour window rationale: after per-row median whitening every row's median
% is exactly 0 dB.  Background noise scatter is ±3–5 dB; aircraft echoes
% typically appear at +8–15 dB above the local noise floor.  A fixed window
% of [-10, 20] dB captures this dynamic range and is applied identically to
% all three figures so they can be compared side-by-side without rescaling.
%
% Detection markers: red circles overlaid via scatter().
%   X-coord = Doppler (Hz), Y-coord = bistatic range (m)  [imagesc axes].

CLIM_WHITE = [-10, 20];  % [dB] — fixed identical clim across all three figures

for i_fig = 1 : N_parts
    r_ax_fig  = part_res(i_fig).range_axis;
    d_ax_fig  = part_res(i_fig).doppler_axis;
    % Per-row median normalisation: same operation as the block-level
    % whitening inside processOnePart, now applied to the full 10-look RDM.
    rdm_w_fig = part_res(i_fig).rdm_after - median(part_res(i_fig).rdm_after, 2);
    dets_fig  = part_res(i_fig).detections;   % [N_det × 5+] or empty

    figure('Name', sprintf('RDM - Part %d', i_fig), 'NumberTitle', 'off');
    imagesc(d_ax_fig, r_ax_fig, rdm_w_fig);
    set(gca, 'YDir', 'normal');   % bistatic range increases upward
    title(sprintf('Post-ECA-C RDM (whitened) — Part %d of %d — %d detection(s)', ...
        i_fig, N_parts, size(dets_fig, 1)));
    xlabel('Doppler (Hz)');
    ylabel('Bistatic range excess (m)');
    cb_fig = colorbar;
    cb_fig.Label.String = 'dB above local noise floor (whitened)';
    clim(CLIM_WHITE);
    ylim([0, config.max_display_range_m]);

    if ~isempty(dets_fig)
        hold on;
        % Red circles: clearly distinguishable against the cool-colour
        % background of the whitened noise floor.
        scatter(dets_fig(:, 2), dets_fig(:, 1), 80, 'ro', ...
            'LineWidth', 2, 'DisplayName', sprintf('Detections (n=%d)', size(dets_fig,1)));
        legend('Location', 'northeast', 'TextColor', 'white', 'Color', [0.2 0.2 0.2]);
        hold off;
    end
end

fprintf('\nProcessing complete.\n');

%% 6. Geographic Ellipse Visualization
% Map each CFAR detection's bistatic iso-range ellipse onto a 3-D globe
% using plotBistaticEllipses3D.m, colour-coded by data part.
%
% Rendering cost scales as:  N_detections × N_ribbon_rings × NEllipsePoints
% geoplot3 calls (one call per ring per detection, each with NEllipsePoints
% vertices).  At 50 detections × 11 rings × 180 pts = 99 000 vertices —
% manageable.  Above ~75 detections the geoglobe renderer becomes noticeably
% slow; the guard below caps the plot at the top-SNR subset when needed.

% ── Site coordinates (Newton MA deployment, 21-May-2026) ─────────────────
%   Tx: CBS Tower, Newton MA  (599 MHz ATSC)
%   Rx: Parking-garage rooftop, 4 Apple Hill Dr, Newton MA
%   Coordinates are defined once in §1 config and reused here.
txLLA_plot = config.txLLA;
rxLLA_plot = config.rxLLA;

MAX_ELLIPSES = 50;   % cap: above this the geoglobe renderer becomes sluggish

if isempty(all_track_dets)
    fprintf('[Geographic plot] No detections — skipping ellipse globe.\n');
else
    dets_to_plot = all_track_dets;
    N_plot       = size(dets_to_plot, 1);

    if N_plot > MAX_ELLIPSES
        % Keep the MAX_ELLIPSES highest-SNR detections.
        % SNR = pwr_db (col 3) minus the per-part CFAR noise floor.
        snr_vals = zeros(N_plot, 1);
        for ii = 1 : N_plot
            ip           = dets_to_plot(ii, 6);
            snr_vals(ii) = dets_to_plot(ii, 3) - part_res(ip).cfar_nf_db;
        end
        [~, snr_ord]  = sort(snr_vals, 'descend');
        dets_to_plot  = dets_to_plot(snr_ord(1:MAX_ELLIPSES), :);
        fprintf('[Geographic plot] %d detections available — showing top-%d by SNR.\n', ...
            N_plot, MAX_ELLIPSES);
    else
        fprintf('[Geographic plot] Plotting all %d detections.\n', N_plot);
    end

    plotBistaticEllipses3D(config.txLLA, config.rxLLA, dets_to_plot, ...
        'TargetAlt_m',    3000, ...   % assumed ~10 000 ft MSL
        'NEllipsePoints',  180, ...   % 180 pts: smooth at globe zoom; keeps call count low
        'Basemap',        'satellite', ...
        'Verbose',         config.verbose);
end

%% 7. Tracking + Coordinated Visualization Loop
% Runs the GNN tracker (trackTargets) over all block-level detections, then
% replays results part-by-part in two synchronized figure windows:
%
%   Figure A — 2-D Range-Doppler Map (per part, whitened)
%     Red   ×  : raw CFAR detections
%     Green  ○  : smoothed track state [R_est, D_est] from trackerGNN
%     Label T#  : trackerGNN TrackID
%
%   Figure B — 3-D geoglobe (or 2-D geoaxes fallback)
%     Iso-range ellipse for each confirmed track's smoothed R estimate,
%     colour-coded by file part.  Previous-frame ellipses are deleted before
%     each redraw to keep the view uncluttered.
%
% Hybrid temporal granularity:
%   Tracker runs at the sub-CPI block level (~100 ms per update step).
%   Visualization is refreshed once per file part (1 s of data), showing
%   the fully NCI-integrated whitened RDM alongside the latest track states.
if isempty(all_track_dets)
    fprintf('[§7] No detections — tracking and visualization skipped.\n');
else

% ── 7.1  Run tracker through all time steps ──────────────────────────────
[tracks_log, ~] = trackTargets(all_track_dets, config);

% ── 7.2  Pre-create globe figure ─────────────────────────────────────────
use_globe_trk = exist('geoglobe', 'file') == 2 || ...
                exist('geoglobe', 'builtin') == 3;
if use_globe_trk
    uif_globe = uifigure( ...
        'Name',     'Tracker — Geographic Ellipses (All Tracks)', ...
        'Position', [970, 100, 900, 580]);
    g_ax = geoglobe(uif_globe, 'Basemap', 'satellite', 'Terrain', 'gmted2010');
    hold(g_ax, 'on');
    geoplot3(g_ax, config.txLLA(1), config.txLLA(2), config.txLLA(3)+200, ...
        'ro', 'MarkerSize', 16, 'LineWidth', 2);
    geoplot3(g_ax, config.rxLLA(1), config.rxLLA(2), config.rxLLA(3)+200, ...
        'bo', 'MarkerSize', 12, 'LineWidth', 2);
else
    fig_globe = figure( ...
        'Name',     'Tracker — Geographic Ellipses (2D Map)', ...
        'Position', [970, 100, 900, 580], 'NumberTitle', 'off');
    g_ax = geoaxes(fig_globe, 'Basemap', 'satellite');
    hold(g_ax, 'on');
    geoplot(g_ax, config.txLLA(1), config.txLLA(2), ...
        'r^', 'MarkerSize', 14, 'MarkerFaceColor', 'red', 'LineWidth', 2);
    geoplot(g_ax, config.rxLLA(1), config.rxLLA(2), ...
        'bs', 'MarkerSize', 12, 'MarkerFaceColor', [0.20 0.45 0.90], 'LineWidth', 2);
    fprintf('[§7] geoglobe unavailable — using geoaxes 2-D map fallback.\n');
end

% ── 7.3  Pre-compute ENU bistatic geometry (shared across all frames) ─────
spheroid_trk = wgs84Ellipsoid('meter');
[txE_trk, txN_trk, ~] = geodetic2enu( ...
    config.txLLA(1), config.txLLA(2), config.txLLA(3), ...
    config.rxLLA(1), config.rxLLA(2), config.rxLLA(3), spheroid_trk);
L_trk     = hypot(txE_trk, txN_trk);
theta_trk = atan2(txN_trk, txE_trk);
R2_trk    = [cos(theta_trk), -sin(theta_trk); ...
             sin(theta_trk),  cos(theta_trk)];
midE_trk  = txE_trk / 2;
midN_trk  = txN_trk / 2;
phi_trk   = linspace(0, 2*pi, 180)';   % [180 × 1] parametric angle
TGT_ALT_M = 3000;   % assumed target altitude MSL [m]

% Per-track colour palette — 12 qualitative colours indexed by TrackID.
% The SAME colour is used for the RDM marker and globe ellipse so both
% figures are cross-referenceable by colour.
TRK_ID_COLORS = [ ...
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
N_ID_COLORS = size(TRK_ID_COLORS, 1);
CLR_NAMES   = {'red','blue','green','magenta','orange','cyan', ...
               'brown','lime','pink','purple','yellow','lavender'};

CLIM_TRK  = [-10, 20];   % [dB] whitened RDM display window
alpha_trk = 2 * config.fc / physconst('LightSpeed');   % Hz/(m/s)

% ── 7.4a  Pre-compute per-tracker-step data for interactive viewer ─────────
% One struct entry per tracks_log step: t_abs_s, which part, whitened RDM,
% axis vectors, only the CFAR detections at that exact time, and track array.
N_steps = numel(tracks_log);
step_data = struct( ...
    't_abs_s',     cell(N_steps, 1), ...
    'i_part',      cell(N_steps, 1), ...
    'rdm_image',   cell(N_steps, 1), ...
    'range_axis',  cell(N_steps, 1), ...
    'doppler_axis', cell(N_steps, 1), ...
    'dets',        cell(N_steps, 1), ...
    'conf_trks',   cell(N_steps, 1));

for s = 1 : N_steps
    t_s = tracks_log(s).time;
    i_p = 0;
    for ip = 1 : N_parts
        t_lo = (ip - 1) * (part_dur_s + config.inter_part_gap_s);
        t_hi = t_lo + part_dur_s;
        if t_s >= t_lo && t_s < t_hi
            i_p = ip;
            break;
        end
    end
    if i_p == 0, i_p = 1; end   % fallback for boundary edge cases

    rdm_w  = part_res(i_p).rdm_after - median(part_res(i_p).rdm_after, 2);
    mask_t = abs(all_track_dets(:, 5) - t_s) < 1e-9;

    step_data(s).t_abs_s      = t_s;
    step_data(s).i_part       = i_p;
    step_data(s).rdm_image    = rdm_w;
    step_data(s).range_axis   = part_res(i_p).range_axis;
    step_data(s).doppler_axis = part_res(i_p).doppler_axis;
    step_data(s).dets         = all_track_dets(mask_t, :);
    step_data(s).conf_trks    = tracks_log(s).tracks;
    step_data(s).truth_data   = [];   % populated by §8 if ADS-B data is available
end

% ── 7.4  Part-level console quality table ─────────────────────────────────
for i_part = 1 : N_parts
    t_start = (i_part - 1) * (part_dur_s + config.inter_part_gap_s);
    t_end   =  t_start + part_dur_s;

    step_mask = ([tracks_log.time] >= t_start) & ([tracks_log.time] < t_end);
    if any(step_mask)
        last_log  = tracks_log(find(step_mask, 1, 'last'));
        conf_trks = last_log.tracks;
    else
        conf_trks = objectTrack.empty;
    end
    n_trk = numel(conf_trks);

    fprintf('\n  Part %d/%d — Confirmed tracks at end of part:\n', i_part, N_parts);
    if n_trk == 0
        fprintf('    (none)\n');
    else
        fprintf('  %-6s  %-10s  %-10s  %-11s  %-8s  %-9s  %-4s\n', ...
            'T#', 'R_est(km)', 'D_est(Hz)', 'v_est(m/s)', ...
            'σ_R(m)', 'σ_v(m/s)', 'Age');
        for ii = 1 : n_trk
            st  = conf_trks(ii).State;
            P   = conf_trks(ii).StateCovariance;
            tid = conf_trks(ii).TrackID;
            fprintf('  T%-5d  %-10.3f  %-10.1f  %-11.1f  %-8.1f  %-9.2f  %-4d\n', ...
                tid, st(1)/1e3, alpha_trk*st(2), st(2), ...
                sqrt(max(0, P(1,1))), sqrt(max(0, P(2,2))), ...
                conf_trks(ii).Age);
        end
    end
end

% ── 7.5  Globe — one-time static render, last-known state per TrackID ─────
% Iterate through all tracker steps, keeping the most recent objectTrack
% state for each unique TrackID.  Tracks deleted before the final part
% (e.g. T7) still appear at their last-known position.
all_tid_seen  = zeros(1, 0, 'double');
all_last_trks = {};
for s = 1 : N_steps
    trks = tracks_log(s).tracks;
    for ii = 1 : numel(trks)
        tid_d = double(trks(ii).TrackID);
        idx   = find(all_tid_seen == tid_d, 1);
        if isempty(idx)
            all_tid_seen(end+1)  = tid_d;    %#ok<AGROW>
            all_last_trks{end+1} = trks(ii); %#ok<AGROW>
        else
            all_last_trks{idx}   = trks(ii);  % overwrite with later state
        end
    end
end
n_unique_tracks = numel(all_tid_seen);

fprintf('\n[§7] Rendering globe — %d unique tracks (last-known state)...\n', ...
    n_unique_tracks);
for k = 1 : n_unique_tracks
    tid   = all_tid_seen(k);
    trk   = all_last_trks{k};
    R_est = trk.State(1);
    clr   = TRK_ID_COLORS(mod(tid - 1, N_ID_COLORS) + 1, :);

    a_e = (R_est + L_trk) / 2;
    c_e = L_trk / 2;
    if a_e <= c_e || R_est <= 0, continue, end
    b_e = sqrt(a_e^2 - c_e^2);

    x_loc   = a_e * cos(phi_trk);
    y_loc   = b_e * sin(phi_trk);
    xy_e    = R2_trk * [x_loc'; y_loc'];
    enu_e_g = xy_e(1, :)' + midE_trk;
    enu_n_g = xy_e(2, :)' + midN_trk;
    enu_u_g = repmat(TGT_ALT_M - config.rxLLA(3), 180, 1);
    [lat_e, lon_e, ~] = enu2geodetic( ...
        enu_e_g, enu_n_g, enu_u_g, ...
        config.rxLLA(1), config.rxLLA(2), config.rxLLA(3), spheroid_trk);

    if use_globe_trk
        geoplot3(g_ax, lat_e', lon_e', TGT_ALT_M * ones(1, 180), ...
            'Color', clr, 'LineWidth', 3);
    else
        geoplot(g_ax, lat_e, lon_e, ...
            'Color', clr, 'LineWidth', 2.5, 'HandleVisibility', 'off');
    end
end
drawnow;
fprintf('[§7] Globe render complete.\n');

% ── Track colour legend companion figure ──────────────────────────────────
leg_fig_h = max(180, 70 + n_unique_tracks * 26);
fig_trk_leg = figure('Name', 'Track Colour Legend', ...
    'Position',   [1880, 100, 300, leg_fig_h], ...
    'Color',      [0.10, 0.10, 0.10], ...
    'MenuBar',    'none', 'ToolBar', 'none', 'NumberTitle', 'off');
ax_tl = axes(fig_trk_leg, ...
    'Position',  [0.02, 0.02, 0.96, 0.96], ...
    'Color',     [0.10, 0.10, 0.10], ...
    'XColor',    'none', 'YColor', 'none', ...
    'XLim',      [0, 1], 'YLim', [0, 1]);
hold(ax_tl, 'on');
text(ax_tl, 0.5, 0.98, 'Track Colour Legend', ...
    'HorizontalAlignment', 'center', 'Color', [0.85, 0.85, 0.85], ...
    'FontSize', 10, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
text(ax_tl, 0.16, 0.90, ...
    sprintf('%-5s  %-9s  %-10s', 'T#', 'R (km)', 'D (Hz)'), ...
    'Color', [0.55, 0.55, 0.55], 'FontSize', 8, 'FontName', 'Courier', ...
    'VerticalAlignment', 'top');
y_spacing = min(0.08, 0.82 / max(n_unique_tracks, 1));
for k = 1 : n_unique_tracks
    tid  = all_tid_seen(k);
    trk  = all_last_trks{k};
    clr  = TRK_ID_COLORS(mod(tid - 1, N_ID_COLORS) + 1, :);
    y_k  = 0.86 - (k - 1) * y_spacing;
    scatter(ax_tl, 0.07, y_k, 70, clr, 'filled');
    text(ax_tl, 0.16, y_k, ...
        sprintf('T%-4d  %6.1f  %+8.0f', ...
        tid, trk.State(1)/1e3, alpha_trk * trk.State(2)), ...
        'Color', 'w', 'FontSize', 9, 'FontName', 'Courier', ...
        'VerticalAlignment', 'middle');
end
hold(ax_tl, 'off');

% Console colour legend
fprintf('\n  Track-to-colour mapping:\n');
fprintf('  %-6s  %-10s  %-10s  %s\n', 'T#', 'R (km)', 'D (Hz)', 'Colour');
for k = 1 : n_unique_tracks
    tid  = all_tid_seen(k);
    trk  = all_last_trks{k};
    fprintf('  T%-5d  %-10.3f  %-10.1f  %s\n', ...
        tid, trk.State(1)/1e3, alpha_trk * trk.State(2), ...
        CLR_NAMES{mod(tid - 1, N_ID_COLORS) + 1});
end

% ── 7.6  Interactive Range-Doppler Map Viewer ─────────────────────────────
% Pack rendering parameters into one struct for the callback closure.
rdm_params.alpha_trk           = alpha_trk;
rdm_params.TRK_ID_COLORS       = TRK_ID_COLORS;
rdm_params.N_ID_COLORS         = N_ID_COLORS;
rdm_params.CLIM_TRK            = CLIM_TRK;
rdm_params.max_display_range_m = config.max_display_range_m;
rdm_params.N_parts             = N_parts;

fig_rdm = figure( ...
    'Name',        'Tracker — RD Map Viewer', ...
    'Position',    [50, 100, 940, 620], ...
    'NumberTitle', 'off', ...
    'Color',       [0.13, 0.13, 0.13]);
ax_rdm = axes(fig_rdm, ...
    'Units',    'normalized', ...
    'Position', [0.08, 0.20, 0.85, 0.72], ...
    'Color',    [0.05, 0.05, 0.05], ...
    'XColor',   'w', 'YColor', 'w', 'FontSize', 9);

lbl_step = uicontrol(fig_rdm, ...
    'Style',               'text', ...
    'Units',               'normalized', ...
    'Position',            [0.08, 0.94, 0.84, 0.04], ...
    'BackgroundColor',     [0.13, 0.13, 0.13], ...
    'ForegroundColor',     [0.90, 0.90, 0.90], ...
    'FontSize',            10, ...
    'FontWeight',          'bold', ...
    'HorizontalAlignment', 'center', ...
    'String',              '');

if N_steps > 1
    sld_step_vec = [1/(N_steps-1), 1/(N_steps-1)];
else
    sld_step_vec = [1, 1];
end
sld = uicontrol(fig_rdm, ...
    'Style',      'slider', ...
    'Units',      'normalized', ...
    'Position',   [0.18, 0.10, 0.64, 0.03], ...
    'Min',        1, 'Max', N_steps, 'Value', 1, ...
    'SliderStep', sld_step_vec);

btn_prev = uicontrol(fig_rdm, ...
    'Style',           'pushbutton', ...
    'String',          '< Prev', ...
    'Units',           'normalized', ...
    'Position',        [0.04, 0.085, 0.12, 0.055], ...
    'FontSize',        10, ...
    'BackgroundColor', [0.25, 0.25, 0.25], ...
    'ForegroundColor', 'w');
btn_next = uicontrol(fig_rdm, ...
    'Style',           'pushbutton', ...
    'String',          'Next >', ...
    'Units',           'normalized', ...
    'Position',        [0.84, 0.085, 0.12, 0.055], ...
    'FontSize',        10, ...
    'BackgroundColor', [0.25, 0.25, 0.25], ...
    'ForegroundColor', 'w');

% Define render callback AFTER all handles exist so the closure captures them.
render_fn = @(n) render_rdm_step(ax_rdm, lbl_step, sld, ...
    step_data, n, N_steps, rdm_params);

% Assign callbacks AFTER render_fn is defined.
set(sld,      'Callback', @(src, ~) render_fn(max(1, min(N_steps, round(src.Value)))));
set(btn_prev, 'Callback', @(~, ~)   render_fn(max(1, round(sld.Value) - 1)));
set(btn_next, 'Callback', @(~, ~)   render_fn(min(N_steps, round(sld.Value) + 1)));

% Initial render — shows step 1.
render_fn(1);

fprintf('\n[§7] Visualization complete — %d parts, %d tracker steps.\n', ...
    N_parts, N_steps);
fprintf('       Drag the slider or use < Prev / Next > buttons to step through time.\n\n');
end  % if ~isempty(all_track_dets)

%% §8  ADS-B Truth Integration  (optional — runs only when config.adsb_files is set)
% ─────────────────────────────────────────────────────────────────────────
%  To enable ADS-B truth evaluation, set these fields in the §1 config block
%  before running this script:
%
%    config.adsb_files = { ...
%        '/path/to/adsb_20260705_142500.txt.gz', ...
%        '/path/to/adsb_20260705_143000.txt.gz'  ...
%    };
%
%  Optionally override the radar epoch when the filename has no embedded time:
%    config.radar_epoch_utc = datetime(2026,7,5,14,25,11,'TimeZone','UTC');
%
%  The pipeline then runs:
%    loadADSBTruth  →  getRadarEpoch  →  adsbToBistatic
%    →  alignTruthToRadar  →  assessTruthVsDetections  →  plotTruthComparison
% ─────────────────────────────────────────────────────────────────────────

if ~isfield(config, 'adsb_files') || isempty(config.adsb_files)
    fprintf('[§8] config.adsb_files not set — skipping ADS-B truth pipeline.\n');
    fprintf('     (Set config.adsb_files in §1 to enable truth-vs-radar comparison.)\n\n');
else
    fprintf('\n════════════════════════════════════════════════════════════════\n');
    fprintf('[§8] ADS-B Truth Integration\n');
    fprintf('════════════════════════════════════════════════════════════════\n');

    % ── §8.1  Load and parse ADS-B SBS-1 files ───────────────────────────
    fprintf('\n[§8.1] Loading ADS-B truth data…\n');
    adsb_tracks = loadADSBTruth(config.adsb_files, 'Verbose', config.verbose);

    if isempty(adsb_tracks)
        warning('analyzeBistaticData:noADSBTracks', ...
            '§8: loadADSBTruth returned no aircraft tracks — check adsb_files paths.');
    else
        % ── §8.2  Get radar recording epoch ──────────────────────────────
        fprintf('\n[§8.2] Extracting radar recording epoch…\n');
        if isfield(config, 'radar_epoch_utc') && ~isempty(config.radar_epoch_utc)
            t_epoch_utc = getRadarEpoch(data_parts{1}, ...
                'ManualEpoch', config.radar_epoch_utc, ...
                'Verbose', config.verbose);
        else
            t_epoch_utc = getRadarEpoch(data_parts{1}, 'Verbose', config.verbose);
        end

        % ── §8.3  Project ADS-B into bistatic measurement space ──────────
        fprintf('\n[§8.3] Projecting ADS-B positions to (R_excess, f_D)…\n');
        adsb_bistatic = adsbToBistatic(adsb_tracks, config.txLLA, config.rxLLA, config.fc);

        % ── §8.4  Align truth to radar time axis ─────────────────────────
        %  Build the full multi-part t_abs_s query vector from all_track_dets
        %  (which spans all parts).
        fprintf('\n[§8.4] Aligning truth to radar time axis…\n');
        if exist('all_track_dets', 'var') && ~isempty(all_track_dets)
            t_abs_query = sort(unique(all_track_dets(:, 5)));
        else
            % Fallback: reconstruct from part durations and inter-part gaps
            t_abs_query = [];
            for ip8 = 1 : N_parts
                t_start8 = (ip8 - 1) * (part_dur_s + config.inter_part_gap_s);
                t_abs_query = [t_abs_query; ...
                    (t_start8 : 1/config.fs : t_start8 + part_dur_s - 1/config.fs).']; %#ok<AGROW>
            end
        end

        adsb_aligned = alignTruthToRadar(adsb_bistatic, t_epoch_utc, t_abs_query);

        % ── §8.4b Back-fill truth_data into step_data for the RDM viewer ──
        %  Each step_data entry gets the adsb_aligned sub-struct that
        %  render_rdm_step uses to draw yellow ◆ truth markers.
        if exist('step_data', 'var') && ~isempty(step_data)
            for s8 = 1 : numel(step_data)
                step_data(s8).truth_data = adsb_aligned;
            end
            fprintf('[§8.4b] truth_data populated into %d step_data entries.\n', ...
                numel(step_data));
        end

        % ── §8.5  Assess detections and tracks vs truth ───────────────────
        fprintf('\n[§8.5] Computing truth-vs-detection metrics…\n');

        % Wrap all_track_dets rows as a struct array for assessTruthVsDetections
        if exist('all_track_dets', 'var') && ~isempty(all_track_dets)
            det_struct = struct( ...
                't_abs_s',    num2cell(all_track_dets(:, 5)), ...
                'R_excess_m', num2cell(all_track_dets(:, 1)), ...
                'f_D_hz',     num2cell(all_track_dets(:, 2)));
        else
            det_struct = [];
        end

        if exist('tracks_log', 'var') && ~isempty(tracks_log)
            trk_log_for_metrics = tracks_log;
        else
            trk_log_for_metrics = [];
        end

        range_cell_m  = physconst('LightSpeed') / (2 * config.fs);
        doppler_bin_hz = 1 / (config.N_slow * (config.N_fast / config.fs));

        truth_metrics = assessTruthVsDetections( ...
            det_struct, trk_log_for_metrics, adsb_aligned, ...
            'RangeCellM',      range_cell_m,  ...
            'DopplerBinHz',    doppler_bin_hz, ...
            'GateRangeCells',  3,              ...
            'GateDopplerBins', 3,              ...
            'Verbose',         config.verbose);

        % ── §8.6  Plot truth comparison figure ────────────────────────────
        fprintf('\n[§8.6] Plotting truth comparison…\n');
        plotTruthComparison(adsb_aligned, trk_log_for_metrics, truth_metrics, ...
            'TrkIdColors',  TRK_ID_COLORS, ...
            'FigureTitle',  sprintf('%d-part Newton recording', N_parts));

        fprintf('\n[§8] ADS-B truth pipeline complete.\n\n');
    end
end  % §8
