% wienerTapVariationTest  SNR vs Wiener filter tap count at fixed attenuation.
%   Sweeps the number of Wiener-Hopf filter taps from 1 to 625 (powers of
%   5) at 30 dB target attenuation and plots resulting SNR as a function of
%   tap count.

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

%% Configure test at 30 dB attenuation only

cfg = SignalProcessingConfig(fs, Attenuation=30);
maxUnambigSpeed = cfg.MaxSpeed;

%% Sweep Wiener tap counts (powers of 5 up to ~1000)

tapCounts = 5.^(0:4);  % [1, 5, 25, 125, 625]
nTaps = length(tapCounts);
snrResults = zeros(nTaps, 1);

for iTap = 1:nTaps
    wTaps = tapCounts(iTap);
    filterFcn = @(tsurv, tref) ...
        helperWienerHopfFilter(tsurv, tref, wTaps);
    rdFcn = @(tsurv, tref) ...
        helperRangeDopplerCube(tsurv, tref, fs, cfg.Fc, maxUnambigSpeed);
    testFcn = @(tsurv, tref) ...
        wienerTapProcessing(tsurv, tref, filterFcn, rdFcn);
    snrResults(iTap) = helperMeasureSNR(surv, ref, cfg, testFcn);
end

%% Plot SNR vs tap count

snrDb = 20*log10(snrResults);

figure;
semilogx(tapCounts, snrDb, '-o', 'LineWidth', 1.5, 'MarkerSize', 8);
hold on;
yline(requiredSnr, '--r', 'LineWidth', 1.2);
hold off;
set(gca, 'XTick', tapCounts);
xlabel("Number of Filter Taps");
ylabel("SNR (dB)");
title("Wiener Filter SNR vs Tap Count (30 dB Attenuation)");
legend("Measured SNR", sprintf("Required SNR (%.1f dB)", requiredSnr), ...
    'Location', 'best');
grid on;

function [rd, range, doppler] = wienerTapProcessing( ...
        surv, ref, filterFcn, rdFcn)
    survFiltered = filterFcn(surv, ref);
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end
