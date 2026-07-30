% dopplerFilterBankTest  Test Doppler filter bank range-Doppler processing.
%   Uses helperDopplerFilterBank instead of helperRangeDopplerCube for
%   range-Doppler processing and measures SNR. This tests an alternative
%   approach that uses banks of Doppler-shifted reference signals for
%   matched filtering rather than reshaping into a cube.

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
wTaps = 1000;
maxUnambigSpeed = cfg.MaxSpeed;
nLags = round(cfg.MaxRange / physconst("LightSpeed") * fs);
nDop = 64;

%% Doppler filter bank test

filterFcn = @(tsurv, tref) helperWienerHopfFilter(tsurv, tref, wTaps);
rdFcn = @(tsurv, tref) ...
    helperDopplerFilterBank( ...
    tsurv, tref, fs, cfg.Fc, nLags, maxUnambigSpeed, nDop);
testFcn = @(tsurv, tref) ...
    dopplerFbProcessing(tsurv, tref, filterFcn, rdFcn);

measuredSnr = helperMeasureSNR(surv, ref, cfg, testFcn);
helperPlotSnr(cfg.Attenuation, measuredSnr, requiredSnr, ...
    'Doppler Filter Bank');

function [rd, range, doppler] = dopplerFbProcessing( ...
        surv, ref, filterFcn, rdFcn)
    survFiltered = filterFcn(surv, ref);
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end
