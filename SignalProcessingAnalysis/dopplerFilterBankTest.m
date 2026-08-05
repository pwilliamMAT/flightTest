function dopplerFilterBankTest(fname,requiredSnr)
% dopplerFilterBankTest  Test Doppler filter bank range-Doppler processing.
%   Uses helperDopplerFilterBank instead of helperRangeDopplerCube for
%   range-Doppler processing and measures SNR. This tests an alternative
%   approach that uses banks of Doppler-shifted reference signals for
%   matched filtering rather than reshaping into a cube.
arguments
    fname = 'n320_hdtv_capture_20260708T135521_part1'
    requiredSnr = 13
end

% Load data
reader = comm.BasebandFileReader(fname, 'SamplesPerFrame', inf);
raw_data = reader();
fs = reader.SampleRate;
surv = double(raw_data(:, 1));
ref = double(raw_data(:, 2));

% Configure test
cfg = SignalProcessingConfig(fs);
wTaps = 1000;
maxUnambigSpeed = cfg.MaxSpeed;
nLags = round(cfg.MaxRange / physconst("LightSpeed") * fs);
nDop = 64;

% Use Wiener filter
filterFcn = @(tsurv, tref) helperWienerHopfFilter(tsurv, tref, wTaps);

% Use a Doppler filter bank
rdFcn = @(tsurv, tref)helperDopplerFilterBank(tsurv, tref, fs, cfg.Fc, nLags, maxUnambigSpeed, nDop);

% Wiener filter followed by filter bank
testFcn = @(tsurv, tref) helperBaselineProcessing(tsurv, tref, filterFcn, rdFcn);

measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'Doppler Filter Bank');

end
