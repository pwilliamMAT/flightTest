function [caf_map, delays, doppler] = compute_radar_caf(inputSource, Fs, varargin)
% compute_radar_caf: Optimized engine with Shift-then-Decimate logic

% 1. Optional parameter for clutter suppression
p = inputParser;
addOptional(p, 'suppressClutter', false);
parse(p, varargin{:});
doSuppress = p.Results.suppressClutter;

% 2. Load Data (Input Checking)
if ischar(inputSource) || isstring(inputSource)
    bbr = comm.BasebandFileReader(inputSource);
    bbr.SamplesPerFrame = round(0.100 * Fs); 
    raw_data = bbr();
    release(bbr);
    data = double(raw_data);
else
    data = double(inputSource);
end

%% --- STEP 1: High-Rate Digital Re-Centering ---
% We shift BEFORE decimation to ensure the -4.8MHz signal is moved 
% to baseband (0Hz) before we filter and downsample.
f_shift = -4.80e6;
t_high = (0:size(data,1)-1)' / Fs;
shift_vec_high = exp(1j * 2 * pi * f_shift * t_high);

s_surv_centered = data(:,1) .* shift_vec_high; 
s_ref_centered  = data(:,2) .* shift_vec_high; 

%% --- STEP 2: Decimation (The Speed Fix) ---
decimation_factor = 10; % Reduces 6.144MHz to 614.4kHz
if decimation_factor > 1
    % Resample (low-pass filters + downsamples)
    s_surv = resample(s_surv_centered, 1, decimation_factor);
    s_ref  = resample(s_ref_centered, 1, decimation_factor);
    
    % Update the Sampling Frequency and metadata
    Fs = Fs / decimation_factor; 
else
    s_surv = s_surv_centered;
    s_ref = s_ref_centered;
end

numSamples = size(s_surv, 1);
t = (0:numSamples-1)' / Fs;

%% --- STEP 3: Clutter Suppression ---
if doSuppress
    % Subtracts the static component
    s_surv = s_surv - (s_ref * (s_ref' * s_surv) / (s_ref' * s_ref));
end

%% --- STEP 4: Parameters for Search ---
max_delay_us = 300; 
max_doppler_hz = 1000; 
doppler_step = 5; % Speed boost: 5Hz steps are sufficient for 100ms CPI
doppler = -max_doppler_hz:doppler_step:max_doppler_hz; 
max_lag = round((max_delay_us/1e6) * Fs);
caf_map = zeros(length(doppler), max_lag + 1);

%% --- STEP 5: Processing Loop ---
% This loop is now handling 10x fewer samples per iteration!
fprintf('Processing CAF (Decimated Samples: %d)...\n', numSamples);
for i = 1:length(doppler)
    % Shift Reference by Doppler
    s_ref_shifted = s_ref .* exp(1j * 2 * pi * doppler(i) * t);
    
    % Cross-correlate 
    [r, ~] = xcorr(s_surv, s_ref_shifted, max_lag);
    
    % Store magnitude 
    mid = max_lag + 1;
    caf_map(i, :) = abs(r(mid:end));
end

%% --- STEP 6: Visualization ---
delays = (0:max_lag) / Fs * 1e6; 
% Note: imagesc is still here for manual tests, 
% but showPlots=false in File 2 will skip the Map.
figure('Name', 'Passive Radar CAF Map');
imagesc(delays, doppler, 20*log10(caf_map ./ max(caf_map(:)) + eps));
axis xy; colormap jet; colorbar;
xlabel('Bistatic Delay (\mu s)'); ylabel('Doppler Shift (Hz)');
title(['Target Detection Map (Fs_{eff}: ', num2str(Fs/1e3), ' kHz)']);
end