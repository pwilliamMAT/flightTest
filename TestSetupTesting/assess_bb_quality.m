function [x_out, Fs] = assess_bb_quality(fname, varargin)
% assess_bb_quality: quick visualization + metrics for a baseband .bb capture.
% Usage: assess_bb_quality('n320_540_5Msps_10s.bb', 'cf', 540e6, 'bw', 6e6);

% ---- parameters ----
p = inputParser;
addParameter(p,'cf',540e6);          % expected RF center (Hz)
addParameter(p,'bw',6e6);            % expected occupied bandwidth (Hz)
addParameter(p,'fftlen',16384);      % Welch FFT length (max)
addParameter(p,'stftNfft',4096);     % spectrogram FFT length
addParameter(p,'stftWin',2048);      % spectrogram window
addParameter(p,'stftOvl',1024);      % spectrogram overlap
parse(p,varargin{:});

cf    = p.Results.cf;
bw    = p.Results.bw;
NfftW = p.Results.fftlen;
NfftS = p.Results.stftNfft;
wSTFT = p.Results.stftWin;
oSTFT = p.Results.stftOvl;
 
% ---- read .bb ----
bbr = comm.BasebandFileReader(fname);
Fs  = bbr.SampleRate;
CFh = bbr.CenterFrequency;
meta= bbr.Metadata;
fprintf('File: %s\n', fname);
fprintf('  Fs=%.3f MSps | CF(header)=%.3f MHz | Channels=%d\n', Fs/1e6, CFh/1e6, bbr.NumChannels);
if ~isempty(meta), disp(meta); end
 
% Efficient full-file read
S   = info(bbr);
N   = S.NumSamplesInData;
bbr.SamplesPerFrame = min(1e6, N);
 
x   = zeros(N,1,'double');
idx = 1;
while ~isDone(bbr)
    fr = bbr();
    n  = numel(fr);
    if n == 0, break; end
    x(idx:idx+n-1) = double(fr);
    idx = idx + n;
end
release(bbr);
x = x(:);
 
% Short-capture guard
L = numel(x);
if L < max(NfftW, 4*wSTFT)
    warning('Short capture (%d samples). Results may be noisy.', L);
end
NfftW  = min([NfftW, 4096, L]);
winLen = NfftW;
ovl    = max(floor(winLen/2), 0);
 
% ---- DC offset (complex mean) ----
dc_mag = abs(mean(x));
dc_rel = dc_mag / (rms(x) + eps);
dc_dB  = 20*log10(dc_rel + eps);
fprintf('DC offset |mag|: %.3e (%.2f dB relative to RMS)\n', dc_mag, dc_dB);
 
% ---- PSD via Welch (TWO-SIDED) ----
[pxx,f] = pwelch(x, hamming(winLen), ovl, NfftW, Fs, 'centered');
 
% Plot PSD
figure('Name','PSD + Spectrogram');
subplot(2,1,1);
plot(f/1e6, 10*log10(pxx + realmin)); grid on;
xlabel('Frequency (MHz)'); ylabel('PSD (dB/Hz)');
title(sprintf('PSD (Fs=%.3f MSps) — %s', Fs/1e6, fname));
 
% ---- Occupied bandwidth (full span) ----
try
    [bw99,flo,fhi,powBand] = obw(pxx, f); 
    fprintf('OBW(99%%): %.2f MHz [%.3f, %.3f] MHz; Band power≈%.4g (lin)\n', ...
            bw99/1e6, flo/1e6, fhi/1e6, powBand);
catch ME
    warning('obw failed: %s', ME.message);
end
 
% ---- CORRECTED Power Calculation ----
halfBW = bw/2;
P_tot = bandpower(pxx, f, 'psd');
f_min = max(min(f), -halfBW);
f_max = min(max(f), +halfBW);
P_ib  = bandpower(pxx, f, [f_min, f_max], 'psd');
P_oob = max(P_tot - P_ib, 0); 

fprintf('Bandpower(in-band): %.4g | Out-of-band: %.4g | Total: %.4g\n', ...
        P_ib, P_oob, P_tot);
snr_dB = 10*log10((P_ib + eps) / (P_oob + eps));
fprintf('SNR_est ≈ %.2f dB\n', snr_dB);
 
% ---- ATSC Pilot Tone & Image Rejection Check ----
% For a 6MHz ATSC signal centered at 0Hz, the pilot is at approx -2.69 MHz
expected_pilot_loc = -2.690559e6; 
tolerance = 0.2e6; 

% Find highest peak in the PSD
[max_val, max_idx] = max(pxx);
f_pilot = f(max_idx);

if abs(abs(f_pilot) - abs(expected_pilot_loc)) > tolerance
    fprintf('Pilot Check: Could not identify ATSC Pilot near expected loc.\n');
    fprintf('             Strongest peak found at %.2f MHz.\n', f_pilot/1e6);
else
    if f_pilot < 0
        orientation = 'Correct (Pilot on Negative side)';
    else
        orientation = 'INVERTED (Pilot on Positive side)';
    end
    
    % Measure Pilot-to-Artifact Ratio (Image Rejection)
    [~, mirror_idx] = min(abs(f - (-f_pilot)));
    mirror_val = pxx(mirror_idx);
    pilot_snr = 10*log10(max_val / (mirror_val + eps));
    
    fprintf('ATSC Pilot Found at: %.3f MHz (%s)\n', f_pilot/1e6, orientation);
    fprintf('Pilot-to-Image Ratio: %.2f dB\n', pilot_snr);
end
 
% ---- Spectrogram ----
subplot(2,1,2);
spectrogram(x, hamming(wSTFT), oSTFT, NfftS, Fs, 'centered', 'yaxis');
title('Spectrogram'); 
ylim([-Fs/2/1e6, Fs/2/1e6]); % Show full complex bandwidth
ylabel('MHz'); 
colormap turbo;
 
% ---- Digital Re-Centering for Passive Radar ----
% Current Pilot: +2.11 MHz
% Targeted Pilot: -2.69 MHz
% Required Shift: -4.80 MHz

f_shift = -4.80e6; % The frequency shift in Hz
t = (0:length(x)-1)' / Fs; % Time vector

% Perform the complex shift (Heterodyning)
x_centered = x .* exp(1j * 2 * pi * f_shift * t);

% Quick Verification: Check if the pilot is now at -2.69 MHz
[pxx_new, f_new] = pwelch(x_centered, hamming(winLen), ovl, NfftW, Fs, 'centered');
[~, max_idx_new] = max(pxx_new);
fprintf('New Pilot Location: %.3f MHz (Expected: -2.691 MHz)\n', f_new(max_idx_new)/1e6);

% Return the centered/cleaned data for further processing
% We apply the -4.8MHz shift here so it's "Radar Ready"
t = (0:length(x)-1)' / Fs;
x_out = x .* exp(1j * 2 * pi * (-4.8e6) * t);
end