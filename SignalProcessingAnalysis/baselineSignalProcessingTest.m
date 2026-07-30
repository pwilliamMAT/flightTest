% baselineSignalProcessingTest  Baseline passive radar SNR measurement.
%   This analysis injects low power targets into real collected HDTV data by
%   attenuating, delaying, and doppler shifting the reference channel and
%   adding it to the surveillance channel. Attenuation is done using the
%   signal power in the surveillance channel as a reference.
%
%   We can roughly assume that the surveillance channel signal power is the
%   direct path power and inject attenuated targets to measure our signal
%   processing pipeline's ability to detect targets at different power levels
%   using the direct path power as a reference.
%
%   So if we estimate that targets at the max range of interest would be 50
%   dB lower than the direct path, we can inject signals 50 dB lower than the
%   surveillance channel signal power and see how good we are at detecting
%   those targets.
%
%   We can perform range-Doppler processing and measure the SNR of the
%   processed data. If the desired output is 90% Pd and 1e-6 FAR, the
%   required SNR is ~13 dB:

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

%% Load real data

fname = 'n320_hdtv_capture_20260708T135521_part1';
reader = comm.BasebandFileReader(fname, 'SamplesPerFrame', inf);
raw_data = reader();
fs = reader.SampleRate;
surv = double(raw_data(:, 1));
ref = double(raw_data(:, 2));

%% Configure test

cfg = SignalProcessingConfig(fs);

%% Baseline test

% Use Wiener filter with 1000 taps and perform RD processing on data
% arranged into a cube.
wTaps = 1000;
maxUnambigSpeed = cfg.MaxSpeed;
filterFcn = @(tsurv, tref) helperWienerHopfFilter(tsurv, tref, wTaps);
rdFcn = @(tsurv, tref) ...
    helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);
testFcn = @(tsurv, tref) baselineProcessing(tsurv, tref, filterFcn, rdFcn);

% Measure the SNR of the test function with targets injected at the given
% attenuation level from the signal level.
measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'Baseline Signal Processing');

%% Other tests to perform
%
% There are many modifications to our signal processing algorithm that we
% could test to see if SNR improves. Here is a subset of tests we should
% run:
%
% It would be interesting to run the baseline test with and without
% amplifier on reference channel, this should confirm amplifier improves
% SNR. It is possible that without an amplifier also on the surveillance
% channel that the impact will be limited, the surveillance channel noise
% could be limiting our SNR right now.
%
% We should test the effect of increasing the number of Wiener
% coefficients, baseline above uses 1000, we should test increasing at some
% fixed signal power level and see the SNR trend.
%
% Test the other two DSI suppression algorithms from
% https://www.mathworks.com/help/phased/ug/direct-signal-interference-dsi-suppression-in-passive-radar.html.
% Particularly the BLMS algorithm appears to work very well from this
% article. We should test the signal processing algorithms as we vary their
% parameters.
%
% Cube vs. Doppler filters. Right now we arbitrarily rearrange the signal
% into a cube and perform RD processing similar to pulsed radar, but using
% banks of doppler shifted reference signal may yield better results, at
% the expense of computational burde. See helperDopplerFilterBank, we could
% replace helperRangeDopplerCube in our processing algorithm.

function [rd, range, doppler] = baselineProcessing(surv, ref, filterFcn, rdFcn)
    % Baseline processing applies a DSI suppression function and then does
    % range-Doppler processing on the filtered output.

    % DSI suppression
    survFiltered = filterFcn(surv, ref);

    % Range-Doppler processing
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end
