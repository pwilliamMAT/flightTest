% blmsDsiSuppressionTest  Test BLMS algorithm for DSI suppression.
%   Uses the Block LMS adaptive filter for Direct Signal Interference
%   suppression and measures SNR. This tests an alternative to the
%   Wiener-Hopf filter approach used in the baseline processing.
%
%   The BLMS filter is initialized with Wiener-Hopf coefficients and
%   adapts during processing. The step size is computed from the
%   surveillance signal covariance per the MathWorks passive radar example.
%
%   Reference: https://www.mathworks.com/help/phased/ug/direct-signal-interference-dsi-suppression-in-passive-radar.html

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

%% BLMS DSI suppression test

nTaps = 100;
filterFcn = @(tsurv, tref) helperBlmsFilter(tsurv, tref, nTaps);
rdFcn = @(tsurv, tref) ...
    helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);
testFcn = @(tsurv, tref) ...
    blmsProcessing(tsurv, tref, filterFcn, rdFcn);

measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'BLMS DSI Suppression');

function [rd, range, doppler] = blmsProcessing(surv, ref, filterFcn, rdFcn)
    survFiltered = filterFcn(surv, ref);
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end
