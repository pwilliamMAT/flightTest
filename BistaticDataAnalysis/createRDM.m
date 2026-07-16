function [rdm, doppler_axis, range_axis, dpi_lag] = createRDM(surv_cube, ref_cube, fs, prf, dpi_lag_in, verbose)
% createRDM  Generates a Range-Doppler Map via the Cross-Ambiguity Function (CAF).
%
%   [rdm, doppler_axis, range_axis] = createRDM(surv_cube, ref_cube, fs, prf)
%
%   PASSIVE RADAR NOTE — why phased.RangeDopplerResponse is NOT used here:
%   phased.RangeDopplerResponse is an active-radar tool. It expects a known,
%   clean transmitted waveform as its matched-filter template. In passive
%   radar there is no known waveform — only a noisy reference signal captured
%   from a broadcast transmitter. Using that object with mean(ref_cube) as a
%   template produces no meaningful range peaks because it doesn't actually
%   cross-correlate the two channels on a CPI-by-CPI basis.
%
%   The correct operation is the Cross-Ambiguity Function (CAF):
%     1. For each slow-time CPI, cross-correlate surv vs ref in the fast-time
%        (delay) dimension. The peak of this correlation marks the Time
%        Difference of Arrival (TDOA), which converts directly to bistatic range.
%     2. Stack the resulting delay profiles into a 2-D matrix.
%     3. Apply an FFT along the slow-time axis to resolve Doppler.
%
%   Inputs:
%   - surv_cube:  [fast_time_samples x slow_time_cpis] complex matrix — surveillance channel.
%   - ref_cube:   [fast_time_samples x slow_time_cpis] complex matrix — reference channel.
%   - fs:         Sampling rate in Hz.
%   - prf:        Pulse Repetition Frequency (= 1/CPI_duration) in Hz.
%
%   Outputs:
%   - rdm:          Range-Doppler Map, CAF magnitude in dB
%                   (20*log10(|CAF| + eps)).
%   - doppler_axis: Doppler frequency axis in Hz at the FFT bin centres
%                   (length = num_cpis).
%   - range_axis:   Bistatic range axis in metres (length = fast_time_samples).
%

if nargin < 6, verbose = true; end   % default: print everything (backward-compatible)
if nargin < 5, dpi_lag_in = []; end

if verbose, fprintf('Generating Range-Doppler Map via Cross-Ambiguity Function (CAF)...\n'); end

[N_fast, N_slow] = size(surv_cube);
c = physconst('LightSpeed');

% --- 1. Build the range-profile matrix via FFT-based cross-correlation ---
% For each CPI column i, the cross-correlation is:
%   xc(tau) = IFFT( FFT(surv(:,i)) .* conj(FFT(ref(:,i))) )
%
% Zero-padding ensures a LINEAR (not circular) cross-correlation.
%
% Minimum requirement for correctness:
%   N_fft_range >= dpi_lag + 2*N_fast - 1
% so the extraction window [dpi_lag+1 : dpi_lag+N_fast] is never affected
% by circular wrap-around.
%
% The USRP N320 hardware start-time offset creates a DPI lag of up to
% ~10 000 samples regardless of CPI length. With a short CPI (e.g. 0.5 ms
% → N_fast = 2 500), the naive 2*N_fast = 5 000 would be smaller than the
% lag. Using nextpow2 of (2*N_fast + 10 000) ensures the FFT is always
% large enough while staying a power-of-two for efficiency.
N_fft_range = 2^nextpow2(2*N_fast + 10000);
range_profiles = zeros(N_fast, N_slow);

% Determine the bulk timing offset (DPI lag).
% If the caller supplies dpi_lag_in (e.g. from a previous unfiltered call),
% use it directly — this is essential for the post-mitigation RDM where the
% DPI has been suppressed and auto-detection would latch onto noise.
% Otherwise auto-detect from the strongest peak in the first CPI.
if nargin >= 5 && ~isempty(dpi_lag_in)
    dpi_lag = dpi_lag_in;
    if verbose
        fprintf('  Using supplied DPI lag: %d samples (%.3f ms, %.1f km equivalent)\n', ...
            dpi_lag, dpi_lag/fs*1e3, dpi_lag/fs*c/1e3);
    end
else
    xc_first = ifft( fft(surv_cube(:,1), N_fft_range) .* ...
                     conj(fft(ref_cube(:,1), N_fft_range)) );

    % Constrained search window — physically motivated bound.
    %
    % The USRP N320 pre-flight coherence check (PassiveRadarCollection_
    % wPreFlightChecks.m) shows the inter-channel hardware lag is < 1 sample
    % (< 200 ns at 5 Msps). Searching all N_fft_range = 32768 samples is
    % unnecessary and causes the detector to latch onto:
    %   • ATSC segment-sync autocorrelation sidelobes at n × 387 samples, or
    %   • a random noise spike (if the reference channel has no ATSC signal,
    %     e.g. when the antennas are physically swapped).
    %
    % We restrict the search to lags 0 … MAX_DPI_LAG samples, which covers
    % any plausible hardware offset while excluding ATSC artefacts and noise.
    MAX_DPI_LAG = 500;    % samples; 100 µs @ 5 Msps = 30 km — far larger than any ground-based offset
    search_idx  = 1 : min(MAX_DPI_LAG + 1, numel(xc_first));
    [peak_val, peak_pos] = max(abs(xc_first(search_idx)));
    dpi_lag = peak_pos - 1;   % convert 1-based index to 0-based lag

    % Quality check — the DPI peak must stand clearly above the noise floor.
    % Use the median of the full cross-correlation (robust against the spike).
    noise_floor       = median(abs(xc_first));
    peak_to_noise_db  = 20 * log10(peak_val / max(noise_floor, eps));

    if peak_to_noise_db < 15
        fprintf(['  WARNING: DPI correlation peak is only %.1f dB above noise floor\n' ...
                 '           (window ±%d samples, threshold 15 dB).\n' ...
                 '           Possible causes:\n' ...
                 '             1. Reference channel has no ATSC signal — check antenna.\n' ...
                 '             2. Channels physically swapped — set config.swap_channels = true.\n' ...
                 '           Forcing dpi_lag = 0 to avoid an invalid range-window shift.\n'], ...
                 peak_to_noise_db, MAX_DPI_LAG);
        dpi_lag = 0;
    end

    if verbose
        fprintf('  Detected DPI lag: %d samples (%.3f ms, %.1f km equiv.) | P/N = %.1f dB\n', ...
            dpi_lag, dpi_lag/fs*1e3, dpi_lag/fs*c/1e3, peak_to_noise_db);
    end
end

% Guard: window must not exceed the FFT output buffer
if dpi_lag + N_fast > N_fft_range
    warning('createRDM:windowOverflow', ...
        'DPI lag (%d) + N_fast (%d) exceeds FFT length (%d). Clamping window.', ...
        dpi_lag, N_fast, N_fft_range);
    dpi_lag = N_fft_range - N_fast;
end

for i = 1:N_slow
    xc = ifft( fft(surv_cube(:, i), N_fft_range) .* ...
               conj(fft(ref_cube(:, i), N_fft_range)) );
    range_profiles(:, i) = xc(dpi_lag+1 : dpi_lag+N_fast);  % window centred on DPI
end

% --- 2. Slow-time windowing + Doppler FFT ---
% A rectangular window (no tapering) has ~13 dB Doppler sidelobes.  Those
% sidelobes from strong clutter/DPI residuals spread into adjacent Doppler
% bins and cause false alarms or masked detections in the CFAR stage.
%
% Kaiser window (beta = 6) provides -44 dB first-sidelobe suppression.
% This is critical when ECA-C suppression depth is limited at short CPIs
% (e.g. ~13-20 dB at N_slow=200): residual DC clutter power can be 30+ dB
% above the noise floor, so window sidelobes at -44 dB land just below the
% noise floor and do NOT contaminate the OS-CFAR training window.  A Hann
% window (-32 dB) would leave sidelobes 12+ dB above the noise floor,
% inflating the CFAR 75th-percentile threshold everywhere — the threshold
% wall that produces zero detections.
%
% Applied to range_profiles (CPI-by-CPI cross-correlation of surv × ref),
% this is equivalent to windowing both channels symmetrically in slow-time.
%
%   range_profiles  is [N_fast × N_slow]
%   win_slow        is [1       × N_slow]  (row vector, broadcasts over range)
%   product         is [N_fast × N_slow]  (MATLAB implicit expansion)
win_slow    = kaiser(N_slow, 6).';         % Kaiser(β=6) window, row vector
rdm_complex = fftshift(fft(range_profiles .* win_slow, N_slow, 2), 2);

% --- 3. Build physical axes ---
% Range: each bin k represents an additional bistatic range BEYOND the DPI
% location. Bin 0 = DPI (direct path), bin k = k/fs * c metres of bistatic
% range excess. This is the physically meaningful quantity for target detection.
range_axis   = (0:N_fast-1).' / fs * c;           % [m], column vector

% Doppler: use the actual fftshifted FFT bin centres, not an endpoint-
% inclusive linspace. The spacing must remain PRF/N_slow so the reported
% Doppler values match the detector bins, tracker constants, and truth gates.
% For even N_slow the positive limit is PRF/2 - PRF/N_slow.
%
% The Kaiser(beta=6) window widens the 3 dB resolution by ~2x but limits
% Doppler sidelobes to -44 dB, protecting CFAR training cells from
% residual zero-Doppler clutter leakage.
doppler_axis = ((0:N_slow-1) - floor(N_slow / 2)) * (prf / N_slow);  % [Hz], row vector

% --- 4. Convert CAF magnitude to amplitude dB ---
% eps prevents log10(0) = -Inf when the correlation magnitude is zero,
% flooring the minimum representable level at ~-300 dB.
rdm = 20 * log10(abs(rdm_complex) + eps);

if verbose, fprintf('RDM generation complete.\n'); end

end
