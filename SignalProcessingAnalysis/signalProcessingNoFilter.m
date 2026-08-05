% Test the SNR without any DSI filter.

pd = 0.9;
far = 1e-6;
requiredSnr = shnidman(pd, far);
disp(['Required SNR: ', num2str(requiredSnr)])

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

% Use no DSI filter
filterFcn = @(tsurv, tref) tsurv;
rdFcn = @(tsurv, tref) ...
    helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);
testFcn = @(tsurv, tref) baselineProcessing(tsurv, tref, filterFcn, rdFcn);

% Measure the SNR of the test function with targets injected at the given
% attenuation level from the signal level.
measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'No DSI Filter Signal Processing');

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
