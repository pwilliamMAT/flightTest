function ecaCdDsiSuppressionTest(fname,requiredSnr)
arguments
    fname = 'n320_hdtv_capture_20260708T135521_part1'
    requiredSnr = 13
end

%   Test ecacd DSi suppression algorithm.
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

% ECA-CD filter
nCancelBins = 2;
[~,nPulse] = helperGetCubeDims(surv,fs,cfg.Fc,maxUnambigSpeed);
filterFcn = @(tsurv, tref) helperEcaCd(tsurv, tref, nCancelBins, nPulse);

% RD cube
rdFcn = @(tsurv, tref) helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);

% Apply BLMS filter and then rd cube processing
testFcn = @(tsurv, tref) helperBaselineProcessing(tsurv, tref, filterFcn, rdFcn);

measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'BLMS DSI Suppression');

end