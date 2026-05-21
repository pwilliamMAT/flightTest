function [all_detections, cfar_nf_db, rdm_before, rdm_after, ...
          range_axis, doppler_axis, config] = processOnePart(config)
% processOnePart  Core passive bistatic radar processing pipeline for one data part.
%
%   Runs the full signal-processing chain (IQ loading → reference-quality
%   check → DPI-lag detection → ECA-C clutter mitigation → Cross-Ambiguity
%   Function → bounded non-coherent integration → per-block OS-CFAR) for
%   a single 1-second data file specified by config.dataFile.
%
%   WHY a separate function?
%   The multi-part trajectory analysis requires running the identical
%   processing chain on three consecutive 1-second files (part1/part2/part3).
%   By encapsulating steps 2–5 in a function, analyzeBistaticData.m can loop
%   over the parts cleanly, collect all detections, and print a consolidated
%   track table without duplicating the core logic.
%
%   Inputs:
%     config  — struct built by analyzeBistaticData §1.
%               config.dataFile must be set to the target file before each call.
%
%   Outputs:
%     all_detections  [N_det × 5] — per-block CFAR detections for this part.
%                       col 1: bistatic range (m)
%                       col 2: Doppler frequency (Hz)
%                       col 3: detection power (dB, same scale as rdm_after)
%                       col 4: block number within this part (1-based)
%                       col 5: block centre time within this part (s, 0-based)
%                     Empty [0 × 5] when no detections are found.
%     cfar_nf_db      scalar (dB) — median CFAR noise floor across all blocks.
%                     Same absolute scale as rdm_after.  Passed to
%                     assessDetections via config.cfar_noise_floor_db so that
%                     B3 (at-noise-floor guard) and D9 (SNR sanity) use a
%                     reference that is consistent with the CFAR detector.
%     rdm_before      [N_range × N_dopp] 10-look display RDM before ECA-C (dB)
%     rdm_after       [N_range × N_dopp] 10-look display RDM after  ECA-C (dB)
%     range_axis      [N_range × 1] bistatic range excess (m)
%     doppler_axis    [1 × N_dopp]  Doppler frequency (Hz)
%     config          config struct updated with:
%                       .cfar_noise_floor_db  — median block noise floor (dB)
%                       .single_look_noise_rdm — Chunk-1 pre-ECA-C RDM for C5
%                       .nci_looks             — max_nci_looks (for C5 check)
%                       .cfar_options.nci_looks — same value

%% A. Load IQ Data
fprintf('  Loading IQ data from: %s\n', config.dataFile);
[~, ~, ref_cube, surv_cube] = loadIQData( ...
    config.dataFile, config.numSamples, config.cpi_duration_s, config.fs, ...
    struct('swap_channels', config.swap_channels));

%% B. Reference Channel Quality Check
fprintf('  Reference channel quality check...\n');
checkRefQuality(ref_cube, config);

%% C. Dimension Setup + DPI Lag Detection
N_slow_cpi   = config.N_slow_cpi;
N_slow_total = size(surv_cube, 2);
N_fast_dim   = size(surv_cube, 1);
N_chunks     = floor(N_slow_total / N_slow_cpi);

% Calibrate the CFAR Gamma threshold to the bounded block size (3 looks),
% not the full 10-look record.  betaincinv computes the correct alpha for
% a Gamma(L, θ) noise distribution where L = nci_looks.
config.cfar_options.nci_looks = config.max_nci_looks;
config.nci_looks               = config.max_nci_looks;

fprintf('  Detecting DPI lag (first %d-CPI sub-chunk [%d × %d])...\n', ...
    N_slow_cpi, N_fast_dim, N_slow_cpi);
[~, ~, ~, dpi_lag] = createRDM(surv_cube(:, 1:N_slow_cpi), ...
                                ref_cube(:, 1:N_slow_cpi), config.fs, config.prf);

%% D. Sub-chunk ECA-C + Bounded Non-Coherent Integration
%
% WHY bounded NCI?
% At 5 MSps the bistatic range cell is c/fs ≈ 60 m.  A target at 200 m/s
% travels ≈60 m in 300 ms (3 × 100 ms chunks) — exactly one range bin.
% Integrating all 10 looks (1 s) smears the target across 3–4 bins, removing
% the integration gain.  Capping NCI at config.max_nci_looks = 3 keeps the
% target within one resolution cell for each CFAR block.
%
% The full 10-look RDM is still accumulated for display and quality checks;
% only the bounded per-block RDMs feed the CFAR detector.

fprintf('  Bounded NCI (%d-look blocks, %d chunks) | DPI lag = %d samples:\n', ...
    config.max_nci_looks, N_chunks, dpi_lag);

% Full-record power accumulators (display and quality-check only).
rdm_power_before_full = zeros(N_fast_dim, N_slow_cpi);
rdm_power_after_full  = zeros(N_fast_dim, N_slow_cpi);

% Per-block power accumulator (bounded, flushed every max_nci_looks chunks).
rdm_power_block  = zeros(N_fast_dim, N_slow_cpi);
block_look_count = 0;
block_num        = 0;

% Pre-allocate collectors.
all_detections = zeros(0, 5);
block_nf_dbs   = zeros(1, 0);

chunk_dur_s = N_slow_cpi / config.prf;   % seconds per 200-CPI chunk (= 0.1 s)

for k_chunk = 1 : N_chunks
    col_idx = (k_chunk - 1)*N_slow_cpi + 1 : k_chunk*N_slow_cpi;
    surv_k  = surv_cube(:, col_idx);
    ref_k   = ref_cube(:,  col_idx);

    fprintf('\n    === Chunk %d/%d | CPIs %d–%d ===\n', ...
        k_chunk, N_chunks, col_idx(1), col_idx(end));

    % createRDM returns amplitude-dB: rdm = 20*log10(|CAF| + eps).
    [rdm_k_before, doppler_axis, range_axis] = ...
        createRDM(surv_k, ref_k, config.fs, config.prf, dpi_lag);

    surv_k_filt = mitigateClutter(surv_k, ref_k, dpi_lag);

    rdm_k_after = createRDM(surv_k_filt, ref_k, config.fs, config.prf, dpi_lag);

    % Save Chunk 1 pre-mitigation RDM for the Rayleigh distribution check (C5).
    if k_chunk == 1, rdm_chunk1_before = rdm_k_before; end

    % 10.^(x/10) converts amplitude-dB → power (|CAF|²).
    rdm_power_before_full = rdm_power_before_full + 10.^(rdm_k_before / 10);
    rdm_power_after_full  = rdm_power_after_full  + 10.^(rdm_k_after  / 10);

    % Capture first-chunk index BEFORE incrementing so block_center_s is correct.
    first_chunk_in_block = k_chunk - block_look_count;   % 1-based, stays valid until reset
    block_look_count = block_look_count + 1;
    rdm_power_block  = rdm_power_block  + 10.^(rdm_k_after / 10);

    block_is_full = (block_look_count == config.max_nci_looks);
    is_last_chunk = (k_chunk == N_chunks);

    if block_is_full || is_last_chunk
        block_num  = block_num + 1;
        rdm_block  = 10 * log10(rdm_power_block / block_look_count);

        % Block centre time within this part (0-indexed seconds).
        % Uses chunk start/end times: chunk k starts at (k-1)*chunk_dur_s.
        % Centre = midpoint of [start of first chunk, end of last chunk].
        block_center_s = ((first_chunk_in_block - 1 + k_chunk) / 2) * chunk_dur_s;

        % --- Range-Dependent Noise Whitening (per-block, applied to CFAR input) ---
        % WHY: After ECA-C the post-mitigation RDM exhibits a range-dependent noise
        %   floor gradient — the noise floor drops ~20 dB from near to far range.
        %   This violates the i.i.d. noise assumption of 2D OS-CFAR: training cells
        %   whose window spans both close-range (high NF) and far-range (low NF) bins
        %   produce a biased order statistic, causing "popcorn" false alarms where the
        %   CFAR threshold falls below the true local noise floor in quiet (far) bins.
        %   Whitening forces every range bin's median to 0 dB so CFAR sees a
        %   stationary, spatially uniform noise process — restoring the i.i.d. property.
        % HOW: Subtract the per-row (range-bin) median across all Doppler bins.
        %   Using the MEDIAN (not mean) naturally protects against bias from isolated
        %   target peaks: a real aircraft echo occupies O(1) Doppler bin per range row
        %   (far less than 50% contamination), so the median discards it and the
        %   normalization reflects only the background noise floor.
        % PRESERVATION: rdm_block (unwhitened) continues to accumulate in
        %   rdm_power_block for the full-record display RDM.  After CFAR, each
        %   detection's power column is restored to the absolute ADC scale by adding
        %   back the per-row noise floor at the detection's range bin, so downstream
        %   quality checks (assessDetections B3 / D9) operate on the unchanged scale.
        row_nf_block = median(rdm_block, 2);          % [N_range × 1] per-row noise floor (dB)
        rdm_block_w  = rdm_block - row_nf_block;      % whitened: each row's median → 0 dB
        abs_nf_block = median(row_nf_block);          % scalar representative absolute NF (dB)

        % Per-block CFAR options: nci_looks must match the actual look count
        % so betaincinv computes the correct Gamma(L, θ) threshold multiplier.
        opts_block           = config.cfar_options;
        opts_block.nci_looks = block_look_count;

        fprintf('\n    --- Block %d (%d-look, t_ctr=%.2f s) -> CFAR (whitened) ---\n', ...
            block_num, block_look_count, block_center_s);
        [blk_dets, ~, blk_nf_db] = detectTargets(rdm_block_w, range_axis, doppler_axis, ...
            config.cfar_pfa, config.cfar_guard_cells, [], config.cfar_min_range_m, opts_block);
        fprintf('        Block %d: %d detection(s)  NF_abs=%.1f dB  NF_white=%.1f dB\n', ...
            block_num, size(blk_dets, 1), abs_nf_block, blk_nf_db);

        if ~isempty(blk_dets)
            % Restore absolute power: detectTargets returns power on the whitened scale
            % (≈ SNR dB above the local row noise floor).  Add back the per-row noise
            % floor at each detection's range bin to recover the original absolute power,
            % keeping the detection format consistent with assessDetections expectations.
            range_bin_m = mean(diff(range_axis));
            r_idx = max(1, min(N_fast_dim, round(blk_dets(:,1) / range_bin_m) + 1));
            blk_dets(:,3) = blk_dets(:,3) + row_nf_block(r_idx);

            % Append block metadata as columns 4 (block_num) and 5 (block_center_s).
            blk_with_meta  = [blk_dets, ...
                repmat([block_num, block_center_s], size(blk_dets, 1), 1)];
            all_detections = [all_detections; blk_with_meta]; %#ok<AGROW>
        end

        % Store the absolute (pre-whitening) noise floor.  blk_nf_db from the
        % whitened CFAR is ≈0 dB and not meaningful for assessDetections;
        % abs_nf_block gives the correct absolute reference for B3 and D9.
        block_nf_dbs = [block_nf_dbs, abs_nf_block]; %#ok<AGROW>

        % Reset block accumulators for the next group.
        rdm_power_block  = zeros(N_fast_dim, N_slow_cpi);
        block_look_count = 0;
    end
end

%% E. Normalise Full-Record Display RDMs
rdm_before = 10 * log10(rdm_power_before_full / N_chunks);
rdm_after  = 10 * log10(rdm_power_after_full  / N_chunks);

%% F. Representative CFAR Noise Floor
% Median of per-block noise floors gives a stable scalar on the same
% absolute scale as rdm_after.  This is the value assessDetections uses
% to evaluate B3 (is the post-ECA-C power at the noise floor?) and D9
% (is the detection SNR physically plausible?).
cfar_nf_db = median(block_nf_dbs);

% Propagate back into config so the caller's assessDetections call uses it.
config.cfar_noise_floor_db  = cfar_nf_db;
config.single_look_noise_rdm = rdm_chunk1_before;   % for C5 Rayleigh check

fprintf('\n  Done: %d detection(s) | %d blocks | NF=%.1f dB (median across blocks)\n', ...
    size(all_detections, 1), block_num, cfar_nf_db);

end
