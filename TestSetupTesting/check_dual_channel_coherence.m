function [xc_peak_dB, lag_us] = check_dual_channel_coherence(fname, Fs)
% check_dual_channel_coherence: Verifies phase-alignment between Ch1 and Ch2
% Usage: check_dual_channel_coherence('n320_dual_capture.bb', 6.144e6)

% 1. Load a small slice of both channels
bbr = comm.BasebandFileReader(fname);
bbr.SamplesPerFrame = round(0.05 * Fs); % 50ms slice
data = bbr();
data = double(data);
release(bbr);

ch1 = data(:,1); % Surveillance
ch2 = data(:,2); % Reference

% 2. Normalize and compute cross-correlation
% We remove DC and normalize energy to compare "shapes" not "sizes"
ch1 = (ch1 - mean(ch1)) / std(ch1);
ch2 = (ch2 - mean(ch2)) / std(ch2);

[xc, lags] = xcorr(ch1, ch2, round(0.001 * Fs)); % Check +/- 1ms window

% 3. Calculate metrics
[max_val, max_idx] = max(abs(xc));
xc_peak_dB = 10*log10(max_val^2 / mean(abs(xc).^2)); % Peak-to-Sidelobe Ratio
lag_us = lags(max_idx) / Fs * 1e6;

% 4. Plotting
figure('Name', 'Dual-Channel Coherence Test');
plot(lags/Fs*1e6, 20*log10(abs(xc)/max(abs(xc)) + eps));
grid on;
xlabel('Relative Delay (\mu s)'); ylabel('Correlation Magnitude (dB)');
title(sprintf('Coherence: Peak at %.2f \\mus (PSLR: %.2f dB)', lag_us, xc_peak_dB));

fprintf('--- Coherence Report ---\n');
fprintf('Correlation Peak Found at: %.3f microseconds\n', lag_us);
fprintf('Peak-to-Sidelobe Ratio:    %.2f dB\n', xc_peak_dB);

if xc_peak_dB > 15
    fprintf('RESULT: SUCCESS. Channels are phase-coherent.\n');
else
    fprintf('RESULT: WEAK COHERENCE. Check antenna alignment or Reference gain.\n');
end
end