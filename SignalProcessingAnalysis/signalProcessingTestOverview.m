% This analysis injects low power targets into real collected HDTV data by
% attenuating, delaying, and doppler shifting the reference channel and
% adding it to the surveillance channel. Attenuation is done using the
% signal power in the surveillance channel as a reference.
%
% We can roughly assume that the surveillance channel signal power is the
% direct path power and inject attenuated targets to measure our signal
% processing pipeline's ability to detect targets at different power levels
% using the direct path power as a reference.
%
% So if we estimate that targets at the max range of interest would be 50
% dB lower than the direct path, we can inject signals 50 dB lower than the
% surveillance channel signal power and see how good we are at detecting
% those targets.
%
% We can perform range-Doppler processing and measure the SNR of the
% processed data. If the desired output is 90% Pd and 1e-6 FAR, the
% required SNR is ~13 dB:

pd = 0.9;
far = 1e-6;
requiredSnr = shnidman(pd, far);
disp(['Required SNR: ', num2str(requiredSnr)])

% So we need a signal processing approach that will give us 13 dB SNR at
% the required attenuation level.
%
% This approach may give us over-confidence because we are assuming the
% reference channel is a perfect estimate of the true direct path signal, I
% don't know how much extra SNR that gives us over reality.

%% Test File Setup

fname = 'n320_hdtv_capture_20260708T135521_part1';

%% Baseline Test

% The baseline signal processing approach is a Wiener filter + RangeDoppler
% analysis rearranging data into a cube.

baselineSignalProcessingTest(fname,requiredSnr);
