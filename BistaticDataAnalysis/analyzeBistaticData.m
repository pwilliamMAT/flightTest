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
fprintf('1. Configuring parameters...\n');
config.dataFile = '../../n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part1'; % Path to IQ data
config.numSamples = 5e6;       % 1s of data at 5 Msps
config.fs = 5e6;               % Sample rate in Hz
config.fc = 600e6;             % Centre frequency in Hz (HDTV channel, used for Doppler→velocity)
config.cpi_duration_s = 0.5e-3; % CPI duration: 0.5 ms → PRF = 2000 Hz → ±250 m/s unambiguous velocity
                                % N_fast = 2500 samples → range window ≈ 150 km  (c/fs × N_fast)
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
% Physics constraint: at 5 MSps the bistatic range cell is ~60 m.  A target
% at 200 m/s travels ~60 m in 300 ms (3 × 100 ms chunks) — one full range
% bin.  Capping NCI at 3 looks keeps the target within its resolution cell
% and prevents inter-frame range walk from smearing the peak.
config.max_nci_looks = 3;
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
config.swap_channels = false;   % <— set true if reference antenna is on RX1

%% 2. Multi-Part Processing
% Run the full ECA-C + bounded-NCI + CFAR pipeline on each consecutive
% 1-second Newton data file.  processOnePart encapsulates steps 2–5 and
% returns detections with block-number and block-centre-time metadata.
data_parts = { ...
    '../../n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part1', ...
    '../../n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part2', ...
    '../../n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part3'  ...
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
    fprintf('\n\n====================================================\n');
    fprintf('  PART %d / %d  —  %s\n', i_part, N_parts, data_parts{i_part});
    fprintf('====================================================\n');
    config.dataFile = data_parts{i_part};
    [dets, nf_db, rdm_b, rdm_a, rax, dax, config] = processOnePart(config);
    % Shift block_center_s (col 5) to absolute time within the full dataset.
    if ~isempty(dets)
        dets(:, 5) = dets(:, 5) + (i_part - 1) * part_dur_s;
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
fprintf('\n\n=== Consolidated Detection Trajectory (Newton dataset, %d parts) ===\n', N_parts);
fprintf('NF: CFAR noise floor — same absolute scale as RDM (raw ADC power, dB).\n');
fprintf('Vel: Doppler-to-velocity uses monostatic approx: v = f_d * c / (2*fc).\n\n');
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

fprintf('5b. Expert radar quality checks (Part 1)...\n');
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
