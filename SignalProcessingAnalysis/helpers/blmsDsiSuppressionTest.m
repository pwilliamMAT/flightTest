function blmsDsiSuppressionTest(fname,requiredSnr)
arguments
    fname = 'n320_hdtv_capture_20260708T135521_part1'
    requiredSnr = 13
end

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

% Load data
reader = comm.BasebandFileReader(fname, 'SamplesPerFrame', inf);
raw_data = reader();
fs = reader.SampleRate;
surv = double(raw_data(:, 1));
ref = double(raw_data(:, 2));

% Configure test
cfg = SignalProcessingConfig(fs);
maxUnambigSpeed = cfg.MaxSpeed;

% BLMS DSI filter
nTaps = 100;
filterFcn = @(tsurv, tref) helperBlmsFilter(tsurv, tref, nTaps);

% RD cube
rdFcn = @(tsurv, tref) helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);

% Apply BLMS filter and then rd cube processing
testFcn = @(tsurv, tref) helperBaselineProcessing(tsurv, tref, filterFcn, rdFcn);

measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'BLMS DSI Suppression');

end
