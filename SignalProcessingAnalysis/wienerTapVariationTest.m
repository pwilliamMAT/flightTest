% wienerTapVariationTest  Test SNR sensitivity to Wiener filter tap count.
%   Varies the number of Wiener-Hopf filter taps used for DSI suppression
%   and measures SNR at each tap count to determine the optimal number of
%   filter coefficients for the passive radar signal processing pipeline.

%% Setup

pd = 0.9;
far = 1e-6;
requiredSnr = shnidman(pd, far);

%% Load real data

fname = 'n320_hdtv_capture_20260708T135521_part1';
reader = comm.BasebandFileReader(fname, 'SamplesPerFrame', inf);
raw_data = reader();
fs = reader.SampleRate;
surv = double(raw_data(:, 1));
ref = double(raw_data(:, 2));

%% Configure test

cfg = SignalProcessingConfig(fs);
maxUnambigSpeed = cfg.MaxSpeed;

%% Sweep Wiener tap counts

tapCounts = [100, 250, 500, 1000, 2000];
nTaps = length(tapCounts);
allSnr = zeros(length(cfg.Attenuation), nTaps);

for iTap = 1:nTaps
    wTaps = tapCounts(iTap);
    filterFcn = @(tsurv, tref) ...
        helperWienerHopfFilter(tsurv, tref, wTaps);
    rdFcn = @(tsurv, tref) ...
        helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);
    testFcn = @(tsurv, tref) ...
        wienerTapProcessing(tsurv, tref, filterFcn, rdFcn);
    allSnr(:, iTap) = helperMeasureSNR(surv, ref, cfg, testFcn);
end

%% Plot results

helperPlotSnrComparison(cfg.Attenuation, allSnr, requiredSnr, ...
    tapCounts, "Wiener Tap Variation", "Taps = ");

function [rd, range, doppler] = wienerTapProcessing( ...
        surv, ref, filterFcn, rdFcn)
    survFiltered = filterFcn(surv, ref);
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end
