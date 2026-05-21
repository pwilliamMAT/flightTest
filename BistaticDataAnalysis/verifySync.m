% verifySync.m
%
% This script performs a time synchronization check between the reference and
% surveillance channels of a passive bistatic radar system.
%
% The check is accomplished by performing a cross-correlation between the two
% channels. A strong peak in the cross-correlation output indicates that the
% direct-path signal from the transmitter is present in both channels and
% that they are time-synchronized.

%% 1. Configuration
% Define the parameters for loading the data.
dataFile = '../../n320_540_5Msps_pt1s_garage_5_7_2026'; % Path to the IQ data file
numSamples = 5e6; % Total number of samples to process (1s of data at 5 Msps)
Fs = 5e6; % Sample rate in Hz

%% 2. Load IQ Data
% Use the loadIQData function to read the raw data file and
% separate the reference and surveillance channels. We only need the raw
% 1D vectors for this step, not the data cubes.
cpi_duration_s = 0.1; % This isn't used here, but the function requires it.
[ref_channel, surv_channel, ~, ~] = loadIQData(dataFile, numSamples, cpi_duration_s, Fs);

%% 3. Perform Cross-Correlation
% The goal is to find the time delay between the reference and surveillance
% channels. The MATLAB `xcorr` function is perfect for this. It computes the
% cross-correlation of two discrete-time sequences.
%
% We will correlate the first 100,000 samples to keep the computation fast.
% This is more than enough to establish synchronization.
correlation_length = 100000;
[correlation, lags] = xcorr(surv_channel(1:correlation_length), ref_channel(1:correlation_length));

% The 'lags' output from xcorr represents the time shifts in samples. We can
% convert this to time in microseconds for a more intuitive plot.
lags_us = lags / Fs * 1e6;

%% 4. Visualize the Result
% Plotting the magnitude of the cross-correlation against the time lags will
% allow us to visually inspect for a synchronization peak.
figure;
plot(lags_us, abs(correlation));
title('Cross-Correlation of Reference and Surveillance Channels');
xlabel('Time Lag (\mus)');
ylabel('Correlation Magnitude');
grid on;

% Add annotations to highlight the peak.
[max_corr, max_idx] = max(abs(correlation));
peak_lag_us = lags_us(max_idx);
hold on;
plot(peak_lag_us, max_corr, 'r*', 'MarkerSize', 10);
legend('Correlation', sprintf('Peak at %.2f \\mus', peak_lag_us));
hold off;

fprintf('Synchronization check complete.\n');
fprintf('A strong peak in the plot confirms that the channels are synchronized.\n');
fprintf('The peak occurred at a time lag of %.2f microseconds.\n', peak_lag_us);
