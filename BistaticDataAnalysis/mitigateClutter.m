function [surv_cube_filtered] = mitigateClutter(surveillance_cube, reference_cube, dpi_lag_in, verbose)
% mitigateClutter  Removes direct-path interference (DPI) and zero-Doppler
%                  clutter via a two-stage ECA-C implementation.
%
%   [surv_cube_filtered] = mitigateClutter(surveillance_cube, reference_cube)
%   [surv_cube_filtered] = mitigateClutter(surveillance_cube, reference_cube, dpi_lag)
%
%   STAGE 1 — ECA (Extensive Cancellation Algorithm), frequency domain:
%     The DPI in the surveillance channel is a filtered/delayed copy of the
%     reference channel. In the frequency domain, estimating a per-bin
%     complex scalar alpha(f) and subtracting alpha * REF_F from SURV_F
%     cancels the DPI.
%
%     *** CRITICAL — CPI alignment before ECA ***
%     The ECA pairs SURV_F[:,k] with REF_F[:,k] and assumes they contain
%     the same HDTV content. This is only valid when the DPI lag is less
%     than one CPI (N_fast samples). With the USRP N320 hardware timing
%     offset (~6000–14000 samples) and short CPIs (N_fast = 2500 at 0.5 ms),
%     the lag is LARGER than a CPI.  The DPI in surv CPI k therefore comes
%     from reference CPI k + floor(dpi_lag / N_fast), NOT ref CPI k.
%     Pairing the wrong CPIs gives alpha ≈ 0 everywhere → zero suppression.
%
%     Fix: flatten the reference cube to a raw vector, offset by dpi_lag
%     samples, then re-form into CPI-cube shape.  This makes each column of
%     the aligned cube exactly the reference content that matches the DPI
%     timing in the corresponding surveillance column.
%
%   STAGE 2 — Zero-Doppler notch (slow-time subspace projection):
%     Projects out the slow-time subspace spanned by the ±N_cancel lowest-
%     Doppler steering vectors, removing static clutter at ±3 Hz.
%
%     *** EFFICIENCY — low-rank projection form ***
%     The naive form  P = I - V'*(V*V')^{-1}*V  creates an N_slow×N_slow
%     matrix (32 MB at N_slow=2000) and requires ~N_fast*N_slow^2 = 10^10
%     operations.  The equivalent low-rank form avoids the large matrix:
%       surv * P = surv - (surv*V') * (V*V')^{-1} * V
%     The intermediate results are [N_fast×7] and [7×N_slow] — tiny.
%
%   Inputs:
%   - surveillance_cube:  [N_fast x N_slow] complex matrix.
%   - reference_cube:     [N_fast x N_slow] complex matrix.
%   - dpi_lag_in:         (optional) integer sample lag of the DPI peak.
%                         If omitted, auto-detected from the cross-correlation
%                         of the first CPI (same logic as createRDM).
%
%   Outputs:
%   - surv_cube_filtered: [N_fast x N_slow] with DPI and zero-Doppler clutter
%                         suppressed.

if nargin < 4, verbose = true; end   % default: print (backward-compatible)
if nargin < 3, dpi_lag_in = []; end

if verbose, fprintf('Applying ECA-C clutter mitigation...\n'); end

[N_fast, N_slow] = size(surveillance_cube);

% =========================================================================
% PRE-STAGE: Detect DPI lag and build time-aligned reference cube
% =========================================================================

% Detect or accept the DPI lag (integer sample count).
if nargin >= 3 && ~isempty(dpi_lag_in)
    dpi_lag = dpi_lag_in;
    if verbose, fprintf('  Using supplied DPI lag: %d samples\n', dpi_lag); end
else
    % Auto-detect: same zero-padded cross-correlation as createRDM uses.
    N_fft_xc = 2^nextpow2(2*N_fast + 10000);
    xc_first = ifft( fft(surveillance_cube(:,1), N_fft_xc) .* ...
                     conj(fft(reference_cube(:,1), N_fft_xc)) );
    [~, dpi_idx] = max(abs(xc_first));
    dpi_lag = dpi_idx - 1;   % convert 1-based index to 0-based lag
    if verbose, fprintf('  Auto-detected DPI lag: %d samples\n', dpi_lag); end
end

% Build the aligned reference cube.
% For each surveillance sample n, the DPI comes from reference sample
% n + dpi_lag.  Flattening both cubes to raw vectors and extracting
% ref_raw[dpi_lag+1 : dpi_lag+total_samples] gives the correct pairing.
ref_raw       = reference_cube(:);          % [N_fast*N_slow x 1] column
total_samples = N_fast * N_slow;

if dpi_lag == 0
    ref_aligned_cube = reference_cube;
elseif dpi_lag + total_samples <= numel(ref_raw)
    ref_aligned_cube = reshape(ref_raw(dpi_lag+1 : dpi_lag+total_samples), N_fast, N_slow);
else
    % The reference data ends before dpi_lag+total_samples (datasets are the
    % same length, so the last dpi_lag samples have no matching reference).
    % Zero-pad the tail — affects < 0.2% of samples and is negligible.
    n_avail     = max(0, numel(ref_raw) - dpi_lag);
    aligned_raw = zeros(total_samples, 1, 'like', ref_raw);
    if n_avail > 0
        aligned_raw(1:n_avail) = ref_raw(dpi_lag+1 : end);
    end
    ref_aligned_cube = reshape(aligned_raw, N_fast, N_slow);
end

% =========================================================================
% STAGE 1: ECA — frequency-domain DPI cancellation
% =========================================================================
if verbose
    fprintf('  Stage 1: ECA frequency-domain DPI cancellation (lag=%d samples)...\n', dpi_lag);
end

SURV_F = fft(surveillance_cube, [], 1);    % [N_fast x N_slow]
REF_F  = fft(ref_aligned_cube,  [], 1);   % [N_fast x N_slow]  ← time-aligned

% Per-frequency-bin LS transfer function:
%   SURV_F(f,:) ≈ alpha(f) * REF_F(f,:)
%   alpha(f) = Σ_n SURV_F(f,n)·conj(REF_F(f,n)) / Σ_n |REF_F(f,n)|²
%
% With the aligned reference, REF_F[:,k] now contains the same HDTV content
% as the DPI in SURV_F[:,k], so alpha captures the channel response and
% subtraction achieves the full cancellation depth.
alpha = sum(SURV_F .* conj(REF_F), 2) ./ (sum(abs(REF_F).^2, 2) + eps);

SURV_F_eca = SURV_F - alpha .* REF_F;
surv_eca   = ifft(SURV_F_eca, [], 1);     % [N_fast x N_slow], complex

% =========================================================================
% STAGE 2: Zero-Doppler notch — efficient low-rank subspace projection
% =========================================================================
% Scale N_cancel proportionally to N_slow so the physical notch width
% (in Doppler bins) stays near ±3 Hz regardless of sub-CPI length:
%   N_slow=2000 (1 Hz/bin)  → N_cancel=3  (±3 bins = ±3 Hz)
%   N_slow=200  (10 Hz/bin) → N_cancel=1  (±1 bin  = ±10 Hz)
N_cancel = max(1, round(3 * N_slow / 2000));
if verbose
    fprintf('  Stage 2: Zero-Doppler slow-time subspace notch (N_slow=%d -> N_cancel=%d, notch +/- %d bins)...\n', ...
        N_slow, N_cancel, N_cancel);
end

k_vec = (-N_cancel:N_cancel).';    % [(2*N_cancel+1) x 1] bin indices
t_vec = (0:N_slow-1);              % [1 x N_slow] slow-time sample indices

% Clutter subspace: V(k,n) = exp(j*2*pi*k*n/N_slow), size [(2*N_cancel+1) x N_slow]
V = exp(1j * 2*pi * k_vec * t_vec / N_slow);

% Low-rank projection  surv·P_orth = surv - (surv·V')·(V·V')⁻¹·V
%   surv·V' is [N_fast × 7]       — cheap multiply
%   (V·V')\V is [7 × N_slow]      — tiny 7×7 solve
%   product  is [N_fast × N_slow]  — same size as input
VVH_inv_V  = (V * V') \ V;         % [7 x N_slow]
proj_coeff = surv_eca * V';        % [N_fast x 7]
surv_cube_filtered = surv_eca - proj_coeff * VVH_inv_V;   % [N_fast x N_slow]

if verbose, fprintf('ECA-C clutter mitigation complete.\n'); end

end
