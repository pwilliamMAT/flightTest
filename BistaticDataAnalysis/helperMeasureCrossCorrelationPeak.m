function metrics = helperMeasureCrossCorrelationPeak(surveillance_cube, reference_cube, fs, varargin)
%HELPERMEASURECROSSCORRELATIONPEAK Measure direct-path lag dominance.
%
%  The direct path should appear as one clearly dominant correlation peak
%  between surveillance and reference. If the plot is flat, multi-peaked,
%  or ambiguous, ECA-C usually struggles because the "copy of the
%  illuminator" is not obvious in the surveillance channel.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'surveillance_cube', @(x) isnumeric(x) && ~isempty(x) && ismatrix(x));
addRequired(p, 'reference_cube', @(x) isnumeric(x) && ~isempty(x) && ismatrix(x));
addRequired(p, 'fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxLagSamples', 500, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'MaxCPIs', 32, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'PeakMinDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'IsolationMinDB', 6, @(x) isnumeric(x) && isscalar(x));
parse(p, surveillance_cube, reference_cube, fs, varargin{:});
opts = p.Results;

if ~isequal(size(surveillance_cube), size(reference_cube))
    error('helperMeasureCrossCorrelationPeak:sizeMismatch', ...
        'Surveillance and reference cubes must have the same size.');
end

[n_fast, n_slow] = size(surveillance_cube);
n_cpis_use = min(n_slow, opts.MaxCPIs);
max_lag = min(opts.MaxLagSamples, n_fast - 1);

n_fft = 2^nextpow2(2 * n_fast - 1);
xc_accum = zeros(n_fft, 1);
lags_full = (-n_fft/2 : n_fft/2 - 1).';

% Use a PHAT-weighted cross-correlation per CPI before coherent averaging.
% This whitens the spectrum so a strong ATSC pilot does not create a broad
% pedestal that hides the true lag peak.
for k = 1:n_cpis_use
    surv_use = double(surveillance_cube(:, k));
    ref_use = double(reference_cube(:, k));

    surv_use = surv_use - mean(surv_use);
    ref_use = ref_use - mean(ref_use);
    surv_use = surv_use / (rms(surv_use) + eps);
    ref_use = ref_use / (rms(ref_use) + eps);

    cpsd = fft(surv_use, n_fft) .* conj(fft(ref_use, n_fft));
    xc = fftshift(ifft(cpsd ./ max(abs(cpsd), eps)));
    xc_accum = xc_accum + xc;
end

xc_mag_full = abs(xc_accum / n_cpis_use);
lag_mask = abs(lags_full) <= max_lag;
lags = lags_full(lag_mask);
xc_mag = xc_mag_full(lag_mask);
[peak_value, peak_idx] = max(xc_mag);

median_value = median(xc_mag);
guard_bins = max(2, round(0.01 * numel(lags)));
secondary_mask = true(size(xc_mag));
secondary_mask(max(1, peak_idx - guard_bins) : min(numel(xc_mag), peak_idx + guard_bins)) = false;
if any(secondary_mask)
    second_value = max(xc_mag(secondary_mask));
else
    second_value = median_value;
end

peak_to_median_db = 20 * log10(peak_value / max(median_value, eps));
peak_to_second_db = 20 * log10(peak_value / max(second_value, eps));
peak_lag_samples = lags(peak_idx);
peak_lag_us = peak_lag_samples / fs * 1e6;

pass = peak_to_median_db >= opts.PeakMinDB && peak_to_second_db >= opts.IsolationMinDB;

metrics = struct( ...
    'lags_samples',          lags(:), ...
    'lags_us',               lags(:) / fs * 1e6, ...
    'magnitude_db_rel',      20 * log10(xc_mag(:) / max(peak_value, eps) + eps), ...
    'peak_lag_samples',      peak_lag_samples, ...
    'peak_lag_us',           peak_lag_us, ...
    'peak_to_median_db',     peak_to_median_db, ...
    'peak_to_second_db',     peak_to_second_db, ...
    'peak_min_db',           opts.PeakMinDB, ...
    'isolation_min_db',      opts.IsolationMinDB, ...
    'n_fast',                n_fast, ...
    'n_cpis_used',           n_cpis_use, ...
    'pass',                  pass, ...
    'message', sprintf( ...
        ['Lag peak at %+d samples (%.3f us), %.1f dB above median and ' ...
         '%.1f dB above the next peak across %d CPI(s). %s'], ...
        peak_lag_samples, peak_lag_us, peak_to_median_db, peak_to_second_db, n_cpis_use, ...
        localPassString(pass)));
end

function txt = localPassString(tf)
if tf
    txt = 'PASS';
else
    txt = 'WARN';
end
end
