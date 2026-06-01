function [detections, threshold_map, nf_db] = detectTargets(rdm_db, range_axis, doppler_axis, ...
                                                      pfa, guard_cells, train_cells, min_range_m, options)
% detectTargets  2-D Cell-Averaging CFAR detector for a passive radar RDM.
%
%   [detections, threshold_map] = detectTargets(rdm_db, range_axis, doppler_axis)
%   [detections, threshold_map] = detectTargets(..., pfa, guard_cells, train_cells, min_range_m, options)
%
%   The RDM (output of createRDM) is in dB.  Internally the function converts
%   to linear power, applies a 2-D CFAR detector, and returns detections as
%   a list of [range, Doppler, power] triplets.
%
%   CFAR STATISTICS (CA-CFAR, default):
%   Under H0, complex Gaussian IQ noise power is exponentially distributed.
%   For N independent training cells the CA-CFAR threshold multiplier is:
%
%       P_fa = (1 + alpha/N)^{-N}   =>   alpha = N * (P_fa^{-1/N} - 1)
%
%   The per-cell threshold is T = alpha * mean(training_cell_powers).
%   Near array edges, N is reduced by zero-padding; alpha is computed
%   cell-by-cell from the actual (non-padded) count to keep P_fa uniform.
%
%   OPTIONS FLAGS — all fields are optional; defaults preserve the original
%   CA-CFAR behaviour and can be overridden field-by-field:
%
%   options.cfar_type         'CA'  Cell-Averaging CFAR (default).
%                             'OS'  Order-Statistics CFAR. More robust to
%                                   heterogeneous training regions (e.g.
%                                   ATSC range-sidelobe spikes). Uses the
%                                   k-th ranked training cell instead of
%                                   the mean, so isolated bright cells do
%                                   not inflate the threshold elsewhere.
%
%   options.os_rank_fraction  Fraction of outer-window cells used as rank
%                             for OS-CFAR: k = floor(frac * N_outer).
%                             Default 0.75 (75th percentile). With k at
%                             75% the estimate is immune to contamination
%                             in up to ~25% of the window.
%
%   options.local_maxima      false (default) | true
%                             Post-CFAR non-maxima suppression. A detection
%                             is kept only if it is the peak cell in a
%                             local neighbourhood. Converts clusters of
%                             adjacent above-threshold bins (from one target
%                             echo spanning several bins via Kaiser window
%                             sidelobes) into a single point detection.
%
%   options.lm_range_bins     Half-width of local-maxima neighbourhood in
%                             range bins. Default 4 (±120 m at 30 m/bin).
%
%   options.lm_dopp_bins      Half-width in Doppler bins. Default 2 (±2 Hz).
%
%   options.min_snr_db        Minimum excess above the CFAR threshold (dB).
%                             0 = disabled (default). Set to e.g. 6 dB to
%                             reject near-threshold marginal detections.
%
%   options.atsc_guard_ranges_m   Row vector of range positions (metres) where
%                             a threshold penalty should be applied to
%                             suppress ATSC segment-sync ghost detections.
%                             Typical value: (832/10.762237e6)*3e8 × (1:6)
%                             = [23180, 46360, 69540, 92720, 115900, 139080] m.
%                             Pass [] (default) to disable.
%
%   options.atsc_guard_penalty_db  Extra threshold margin (dB) applied at
%                             each ATSC ghost range.  A detection there must
%                             exceed the CFAR threshold by this additional
%                             amount.  Default 10 dB.
%
%   options.atsc_guard_width_bins  Half-width of each guard zone in range
%                             bins.  Default 3 (±90 m at 30 m/bin).
%
%   Inputs:
%   - rdm_db:        [N_range x N_dopp] RDM in dB (from createRDM).
%   - range_axis:    [N_range x 1] bistatic range excess in metres.
%   - doppler_axis:  [1 x N_dopp] Doppler frequency axis in Hz.
%   - pfa:           Desired probability of false alarm (default 1e-4).
%   - guard_cells:   [Ng_range, Ng_doppler] guard cell half-widths (default [4, 2]).
%   - train_cells:   [Nt_range, Nt_doppler] training cell half-widths (default [20, 4]).
%   - min_range_m:   Minimum bistatic range to report detections (default 5000 m).
%   - options:       Struct of optional flags (see above). Omit or pass []
%                    to use all defaults (= original CA-CFAR behaviour).
%
%   Outputs:
%   - detections:    [N_det x 3]. Columns: [range_m, doppler_hz, power_db].
%                    Empty (0 x 3) if no detections.
%   - threshold_map: [N_range x N_dopp] adaptive CFAR threshold in dB.

% --- Positional-argument defaults ---
if nargin < 4 || isempty(pfa),         pfa         = 1e-4;   end
if nargin < 5 || isempty(guard_cells), guard_cells = [4, 2]; end
if nargin < 6 || isempty(train_cells), train_cells = [20, 4]; end
if nargin < 7 || isempty(min_range_m), min_range_m = 5e3;    end
if nargin < 8 || isempty(options),     options     = struct(); end

% --- Options defaults (each field independently so callers can override
%     only the fields they care about without specifying the rest) ---
if ~isfield(options, 'cfar_type'),        options.cfar_type        = 'CA';  end
if ~isfield(options, 'os_rank_fraction'), options.os_rank_fraction = 0.75;  end
if ~isfield(options, 'local_maxima'),     options.local_maxima     = false; end
if ~isfield(options, 'lm_range_bins'),    options.lm_range_bins    = 4;     end
if ~isfield(options, 'lm_dopp_bins'),     options.lm_dopp_bins     = 2;     end
if ~isfield(options, 'min_snr_db'),              options.min_snr_db              = 0;   end
if ~isfield(options, 'atsc_guard_ranges_m'),     options.atsc_guard_ranges_m     = [];  end
if ~isfield(options, 'atsc_guard_penalty_db'),   options.atsc_guard_penalty_db   = 10;  end
if ~isfield(options, 'atsc_guard_width_bins'),   options.atsc_guard_width_bins   = 3;   end
if ~isfield(options, 'notch_guard_dopp_bins'),   options.notch_guard_dopp_bins   = 0;   end
if ~isfield(options, 'nci_looks'),               options.nci_looks               = 1;   end
if ~isfield(options, 'verbose'),                 options.verbose                 = true; end
verbose = options.verbose;
% nci_looks: number of non-coherently integrated RDMs (e.g. N_chunks from
% the sub-CPI loop). When > 1 the noise follows a Gamma(L, θ) distribution
% instead of exponential, so the CFAR threshold multiplier is computed via
% the exact incomplete-beta inverse rather than the standard formula.
% notch_guard_dopp_bins: number of Doppler bins each side of zero-Doppler to
% exclude from CFAR training cell estimation. Set equal to N_cancel used in
% mitigateClutter (Stage 2 subspace notch half-width = 3 bins). When non-zero,
% the notch-zone columns are replaced with a noise floor estimate before
% computing the CFAR threshold, so the near-zero power in the notch does not
% bias the order-statistic / mean estimator downward. Detection comparisons
% always use the original unmodified RDM.

Ng_r = guard_cells(1);   Ng_d = guard_cells(2);
Nt_r = train_cells(1);   Nt_d = train_cells(2);
Ho_r = Ng_r + Nt_r;      Ho_d = Ng_d + Nt_d;    % outer half-widths

extra = '';
if options.local_maxima
    extra = [extra, sprintf(', local_max=[%d %d]', options.lm_range_bins, options.lm_dopp_bins)];
end
if options.min_snr_db > 0
    extra = [extra, sprintf(', min_snr=%.0f dB', options.min_snr_db)];
end
if options.notch_guard_dopp_bins > 0
    extra = [extra, sprintf(', notch_guard=%c%d bins', char(177), options.notch_guard_dopp_bins)];
end
if options.nci_looks > 1
    extra = [extra, sprintf(', NCI=%d looks', options.nci_looks)];
end
if verbose
    fprintf('Running 2-D %s-CFAR (Pfa=%.0e, guard=[%d %d], train=[%d %d], min_range=%.0f km%s)...\n', ...
        upper(options.cfar_type), pfa, Ng_r, Ng_d, Nt_r, Nt_d, min_range_m/1e3, extra);
end

% --- Convert RDM to linear power ---
% CFAR statistics assume exponentially distributed noise power (complex
% Gaussian IQ).  Operating in dB gives log-normal noise and invalidates
% the closed-form threshold equations.
rdm_linear = 10.^(rdm_db / 10);
[N_range, N_dopp] = size(rdm_linear);

% =========================================================================
% CFAR PRE-CONDITIONING: zero-Doppler notch fill
% =========================================================================
% The ECA-C Stage-2 subspace projection zeroes out slow-time bins ±N_cancel
% around zero-Doppler. When the CFAR training window slides across this notch,
% the near-zero cells contaminate the noise estimate:
%   CA-CFAR: near-zero cells pull the training-cell mean downward
%            → threshold too low → false alarms near the notch edges.
%   OS-CFAR: near-zero cells occupy the bottom ranks of the sorted window.
%            With k = 75th percentile and notch covering >25% of the
%            window, the selected rank drops into sub-noise-floor territory.
%
% Fix: build a CFAR-only copy of the RDM where the notch columns are
% replaced by the per-range-bin median of the Nt_d adjacent non-notch
% columns on each side. CFAR noise estimation uses this filled copy;
% detection comparisons (detect_mask) still use the original rdm_linear.
if options.notch_guard_dopp_bins > 0
    [~, z_bin]    = min(abs(doppler_axis));
    n_guard       = options.notch_guard_dopp_bins;
    notch_cols    = max(1, z_bin - n_guard) : min(N_dopp, z_bin + n_guard);
    left_ref_cols = max(1, min(notch_cols) - Nt_d) : max(1, min(notch_cols) - 1);
    right_ref_cols= min(N_dopp, max(notch_cols) + 1) : min(N_dopp, max(notch_cols) + Nt_d);
    ref_cols_cfar = [left_ref_cols, right_ref_cols];
    ref_cols_cfar = ref_cols_cfar(ref_cols_cfar >= 1 & ref_cols_cfar <= N_dopp);
    if numel(ref_cols_cfar) >= 2
        fill_vals = median(rdm_linear(:, ref_cols_cfar), 2);   % [N_range × 1]
    else
        fill_vals = repmat(median(rdm_linear(:)), N_range, 1);
    end
    rdm_cfar = rdm_linear;
    rdm_cfar(:, notch_cols) = repmat(fill_vals, 1, numel(notch_cols));
else
    rdm_cfar = rdm_linear;
end

% =========================================================================
% CFAR VARIANT: compute noise_est and threshold_linear
% =========================================================================
% Number of non-coherent looks: scales the Gamma CFAR threshold formula.
% For L=1 (single-look exponential noise) the formula reduces to the
% standard CA-CFAR multiplier N*(Pfa^{-1/N} - 1).
L_nci = max(1, round(options.nci_looks));

if strcmpi(options.cfar_type, 'CA')
    % -----------------------------------------------------------------
    % CA-CFAR — training region = outer box minus inner guard box.
    % Sliding box sums via conv2 give O(N log N) complexity.
    % -----------------------------------------------------------------
    kernel_outer = ones(2*Ho_r + 1, 2*Ho_d + 1);
    kernel_inner = ones(2*Ng_r + 1, 2*Ng_d + 1);

    sum_outer = conv2(rdm_cfar, kernel_outer, 'same');
    sum_inner = conv2(rdm_cfar, kernel_inner, 'same');
    sum_train = sum_outer - sum_inner;

    % Count valid (non-zero-padded) training cells per CUT so the noise
    % estimate stays unbiased near the array edges.
    count_outer = conv2(ones(N_range, N_dopp), kernel_outer, 'same');
    count_inner = conv2(ones(N_range, N_dopp), kernel_inner, 'same');
    count_train = max(count_outer - count_inner, 1);

    noise_est = sum_train ./ count_train;
    % CA-CFAR threshold multiplier for Gamma(L, θ) noise.
    % Exact formula via incomplete-beta inverse:
    %   P_fa = 1 - I_{α/(α+N)}(L, N·L)  ⟺  x = betaincinv(1-Pfa, L, N·L); α = x·N/(1-x)
    % For L=1 this reduces to the standard exponential formula N*(Pfa^{-1/N}-1).
    if L_nci <= 1
        alpha_map = count_train .* (pfa .^ (-1 ./ count_train) - 1);
    else
        x_map     = betaincinv(1 - pfa, L_nci, count_train * L_nci);
        alpha_map = x_map .* count_train ./ max(1 - x_map, eps);
    end
    threshold_linear = alpha_map .* noise_est;

elseif strcmpi(options.cfar_type, 'OS')
    % -----------------------------------------------------------------
    % OS-CFAR — uses the k-th order statistic of the outer window.
    % Guard cells are included in the sort; choosing k = 0.75*N_outer
    % makes the estimate immune to contamination in up to ~25% of cells,
    % which covers ATSC pilot-tone range sidelobes.
    %
    % ordfilt2(A, k, domain) returns the k-th smallest value in each
    % neighbourhood (MATLAB Image Processing Toolbox).
    %
    % Threshold multiplier: the exact OS-CFAR P_fa formula is complex.
    % We use the CA-CFAR formula with N_train as a conservative
    % approximation — intentionally slightly higher threshold, which is
    % appropriate when suppressing clutter false alarms.
    % -----------------------------------------------------------------
    N_outer_total = (2*Ho_r + 1) * (2*Ho_d + 1);
    k_rank        = max(1, floor(options.os_rank_fraction * N_outer_total));
    os_domain     = true(2*Ho_r + 1, 2*Ho_d + 1);

    noise_est    = ordfilt2(rdm_cfar, k_rank, os_domain);

    N_inner     = (2*Ng_r + 1) * (2*Ng_d + 1);
    N_train_nom = N_outer_total - N_inner;
    if L_nci <= 1
        alpha_scalar = N_train_nom * (pfa^(-1/N_train_nom) - 1);
    else
        x_os         = betaincinv(1 - pfa, L_nci, N_train_nom * L_nci);
        alpha_scalar = x_os * N_train_nom / max(1 - x_os, eps);
    end
    threshold_linear = alpha_scalar * noise_est;

else
    error('detectTargets:unknownCfarType', ...
        'options.cfar_type must be ''CA'' or ''OS''; got ''%s''.', options.cfar_type);
end

threshold_map = 10 * log10(threshold_linear + eps);   % dB for output

% --- Global noise floor estimate (returned for quality-check instrumentation) ---
% Median of the noise_est matrix, excluding the zero-Doppler guard zone.
% noise_est contains the per-cell training-window statistic (mean for CA,
% k-th ranked value for OS) in linear power units, on the same scale as
% rdm_db after 10.^(rdm_db/10).  The median over all range bins and off-DC
% Doppler bins gives a single stable dB value that assessDetections can use
% as the B3 at-noise-floor guard and the D9 SNR reference, bypassing the
% (broken) far-range quiet-region estimate which mis-fires on this dataset.
nf_excl = true(1, N_dopp);
if options.notch_guard_dopp_bins > 0
    [~, z_nf] = min(abs(doppler_axis));
    ng_nf = options.notch_guard_dopp_bins;
    nf_excl(max(1, z_nf - ng_nf) : min(N_dopp, z_nf + ng_nf)) = false;
end
nf_db = 10 * log10(max(median(noise_est(:, nf_excl), 'all'), eps));

% --- ATSC ambiguity guard zones ---
% Raise the CFAR threshold at the n × 23.18 km segment-sync harmonics.
% A detection at a ghost range must exceed the nominal threshold by an
% extra penalty_db, equivalent to requiring a lower effective Pfa there.
% This does NOT hard-exclude those range bins — a sufficiently strong echo
% (real aircraft) can still pass.
if ~isempty(options.atsc_guard_ranges_m)
    pen_linear = 10^(options.atsc_guard_penalty_db / 10);
    pen_w      = options.atsc_guard_width_bins;
    for k_gz = 1:numel(options.atsc_guard_ranges_m)
        [~, ghost_bin] = min(abs(range_axis - options.atsc_guard_ranges_m(k_gz)));
        guard_bins = max(1, ghost_bin - pen_w) : min(N_range, ghost_bin + pen_w);
        threshold_linear(guard_bins, :) = threshold_linear(guard_bins, :) * pen_linear;
    end
    threshold_map = 10 * log10(threshold_linear + eps);  % recompute with penalty
end

% ── DEBUG: CFAR threshold sanity check at one mid-range, off-DC cell ─────
% Prints: noise floor (dB), linear alpha, threshold (dB) = NF + 10*log10(α),
% and whether that cell is above or below the threshold.
% Remove this block once the threshold levels are verified.
dbg_r = min(max(round(N_range * 0.30), Ho_r + 2), N_range - Ho_r - 1);
dbg_d = min(max(round(N_dopp * 0.62), Ho_d + 2), N_dopp - Ho_d - 1);
dbg_nf_db = 10 * log10(max(noise_est(dbg_r, dbg_d), eps));
if strcmpi(options.cfar_type, 'OS')
    dbg_alpha = alpha_scalar;
else
    dbg_alpha = alpha_map(dbg_r, dbg_d);
end
dbg_thr_db = dbg_nf_db + 10 * log10(max(dbg_alpha, eps));
if rdm_linear(dbg_r, dbg_d) > threshold_linear(dbg_r, dbg_d)
    dbg_str = 'ABOVE THRESH';
else
    dbg_str = 'below thresh';
end
if verbose
    fprintf('  [CFAR-DEBUG] Cell[r=%d,d=%d]: NF=%.1f dB  alpha=%.4f (+%.2f dB)  Thr=%.1f dB  RDM=%.1f dB  [%s]\n', ...
        dbg_r, dbg_d, dbg_nf_db, dbg_alpha, 10*log10(max(dbg_alpha, eps)), ...
        dbg_thr_db, rdm_db(dbg_r, dbg_d), dbg_str);
end
% ── END DEBUG ────────────────────────────────────────────────────────────

% =========================================================================
% BUILD DETECTION MASK
% =========================================================================

% --- min_snr_db gate (Step 3) ---
% Require the CUT to exceed the threshold by an additional margin.
% Rejects near-threshold detections likely caused by noise fluctuations.
if options.min_snr_db > 0
    snr_factor  = 10^(options.min_snr_db / 10);
    detect_mask = rdm_linear > (threshold_linear * snr_factor);
else
    detect_mask = rdm_linear > threshold_linear;   % original behaviour
end

% --- Local maxima suppression (Step 1) ---
% Keep a detection only if its cell is the strongest in its neighbourhood.
% ordfilt2 with order = N_lm returns the maximum of each neighbourhood.
if options.local_maxima
    lm_r      = options.lm_range_bins;
    lm_d      = options.lm_dopp_bins;
    N_lm      = (2*lm_r + 1) * (2*lm_d + 1);
    lm_domain = true(2*lm_r + 1, 2*lm_d + 1);

    local_max_map = ordfilt2(rdm_linear, N_lm, lm_domain);
    detect_mask   = detect_mask & (rdm_linear >= local_max_map);
end

% =========================================================================
% EXCLUSION ZONES
% =========================================================================

% Near-range: DPI sidelobes and strong static clutter.
range_bin_min = find(range_axis >= min_range_m, 1, 'first');
if ~isempty(range_bin_min) && range_bin_min > 1
    detect_mask(1:range_bin_min-1, :) = false;
end

% Far-range edge: the CFAR window extends Ho_r bins beyond the last valid
% range cell.  conv2/ordfilt2 zero-pad there, making the noise estimate too
% low and generating false alarms in the last Ho_r range bins.
if N_range > Ho_r
    detect_mask(N_range - Ho_r + 1 : end, :) = false;
end

% Doppler edges: same zero-padding effect in the Doppler dimension.
% Suppress the outer Ho_d bins on each side of the Doppler axis.
% dopp_bin_width accounts for any PRF/N_slow combination.
dopp_bin_width   = (doppler_axis(end) - doppler_axis(1)) / max(N_dopp - 1, 1);
edge_dopp_hz     = Ho_d * dopp_bin_width;
suppress_dopp_edge = abs(doppler_axis) > (max(abs(doppler_axis)) - edge_dopp_hz);
detect_mask(:, suppress_dopp_edge) = false;

% Zero-Doppler notch: suppress detections within the ECA-C Stage-2 suppression
% zone. The half-width scales with the actual Doppler bin size, so the
% exclusion is correct for any CPI length (1 Hz/bin at N_slow=2000 or
% 10 Hz/bin at N_slow_cpi=200). A minimum of 3.5 Hz is kept for backward
% compatibility with configurations that do not set notch_guard_dopp_bins.
if options.notch_guard_dopp_bins > 0
    notch_half_hz = (options.notch_guard_dopp_bins + 0.5) * dopp_bin_width;
else
    notch_half_hz = 3.5;   % legacy: ±3 bins at 1 Hz/bin resolution
end
suppress_dopp_zero = abs(doppler_axis(:)) <= notch_half_hz;
detect_mask(:, suppress_dopp_zero) = false;

% =========================================================================
% EXTRACT DETECTIONS
% =========================================================================

[r_idx, d_idx] = find(detect_mask);   % both column vectors

if isempty(r_idx)
    detections = zeros(0, 3);
    if verbose, fprintf('  No detections above threshold.\n'); end
    return;
end

det_range  = range_axis(r_idx);
det_dopp   = doppler_axis(d_idx);
det_power  = rdm_db(sub2ind([N_range, N_dopp], r_idx, d_idx));

detections = [det_range(:), det_dopp(:), det_power(:)];   % [N_det x 3]

if verbose, fprintf('  %d detections found.\n', size(detections, 1)); end
end
