function [accuracy] = calc_theoretical_accuracy(fs, bw, Tint, fc, snr_db)
    % fs: Sample Rate
    % bw: Bandwidth (6e6)
    % Tint: Integration Time (0.1)
    % fc: Center Frequency (540e6)
    % snr_db: Signal-to-Noise Ratio in dB
    
    c = 3e8;
    lambda = c/fc;
    snr_lin = 10^(snr_db/10);

    % 1. Range Accuracy (CRLB for Time of Arrival)
    % sigma_t >= 1 / (beta * sqrt(2 * SNR)) 
    % where beta is the effective bandwidth (approx bw / sqrt(3) for rectangular)
    beta = bw / sqrt(3);
    sigma_t = 1 / (beta * sqrt(2 * snr_lin));
    accuracy.range_error_m = c * sigma_t;

    % 2. Velocity Accuracy (CRLB for Doppler)
    % sigma_f >= sqrt(3) / (pi * Tint * sqrt(2 * SNR))
    sigma_f = sqrt(3) / (pi * Tint * sqrt(2 * snr_lin));
    accuracy.vel_error_mps = (sigma_f * lambda) / 2;
    
    fprintf('\n--- Theoretical Accuracy (at %d dB SNR) ---\n', snr_db);
    fprintf('RMS Range Error:     %.2f meters\n', accuracy.range_error_m);
    fprintf('RMS Velocity Error:  %.2f m/s\n', accuracy.vel_error_mps);
end