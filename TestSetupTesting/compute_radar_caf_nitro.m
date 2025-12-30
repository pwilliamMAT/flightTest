function [caf_map, delays, doppler] = compute_radar_caf_nitro(inputSource, Fs, varargin)
% NITRO VERSION: Frequency-domain correlation for max speed.

p = inputParser;
addOptional(p, 'suppressClutter', false);
parse(p, varargin{:});
doSuppress = p.Results.suppressClutter;

% 1. Load Data
if ischar(inputSource) || isstring(inputSource)
    bbr = comm.BasebandFileReader(inputSource);
    data = double(bbr());
    release(bbr);
else
    data = double(inputSource);
end

% 2. Shift-then-Decimate (Keep the speed boost from decimation)
f_shift = -4.80e6;
t_high = (0:size(data,1)-1)' / Fs;
s_surv = data(:,1) .* exp(1j * 2 * pi * f_shift * t_high); 
s_ref  = data(:,2) .* exp(1j * 2 * pi * f_shift * t_high); 

dec_factor = 10;
s_surv = resample(s_surv, 1, dec_factor);
s_ref  = resample(s_ref, 1, dec_factor);
Fs = Fs / dec_factor;

if doSuppress
    s_surv = s_surv - (s_ref * (s_ref' * s_surv) / (s_ref' * s_ref));
end

% 3. Search Parameters
max_delay_us = 300; 
max_doppler_hz = 1000; 
doppler_step = 5; 
doppler = -max_doppler_hz:doppler_step:max_doppler_hz; 
max_lag = round((max_delay_us/1e6) * Fs);

% 4. NITRO ENGINE: FFT-Based Correlation
numSamples = size(s_surv, 1);
t = (0:numSamples-1)' / Fs;

% Pre-calculate FFT of surveillance once
% We pad to the next power of 2 for maximum FFT speed
N_fft = 2^nextpow2(numSamples + max_lag);
S_surv_fft = fft(s_surv, N_fft);

caf_map = zeros(length(doppler), max_lag + 1);

% This loop is now very "lean"
for i = 1:length(doppler)
    % Shift reference channel in time domain
    s_ref_shifted = s_ref .* exp(1j * 2 * pi * doppler(i) * t);
    
    % FFT of shifted reference
    S_ref_fft = fft(s_ref_shifted, N_fft);
    
    % Element-wise multiplication (Correlation in Frequency Domain)
    % Conjugating the reference performs the correlation
    R = ifft(S_surv_fft .* conj(S_ref_fft));
    
    % Extract the first max_lag samples (positive lags)
    caf_map(i, :) = abs(R(1:max_lag+1));
end

delays = (0:max_lag) / Fs * 1e6;
end