function baselineSignalProcessingTest(fname,requiredSnr)
arguments
    fname = 'n320_hdtv_capture_20260708T135521_part1'
    requiredSnr = 13
end

% Load real data
reader = comm.BasebandFileReader(fname, 'SamplesPerFrame', inf);
raw_data = reader();
fs = reader.SampleRate;
surv = double(raw_data(:, 1));
ref = double(raw_data(:, 2));

% Configure test
cfg = SignalProcessingConfig(fs);

% Use Wiener filter with 1000 taps
wTaps = 1000;
filterFcn = @(tsurv, tref) helperWienerHopfFilter(tsurv, tref, wTaps);

% Apply Wiener filter and then rd processing
rdFcn = @(tsurv, tref) helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, cfg.MaxSpeed);
testFcn = @(tsurv, tref) helperBaselineProcessing(tsurv, tref, filterFcn, rdFcn);

% Measure the SNR of the test function with targets injected at the given
% attenuation level from the signal level.
measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'Baseline Signal Processing');

end
