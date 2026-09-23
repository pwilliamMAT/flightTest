function F = plutoCombFineCheck(bbFile, toneOffsets_Hz, window_s, varargin)
%PLUTOCOMBFINECHECK Long coherent FFT (~1 Hz bins) comb search.
%   One Hann-windowed FFT over window_s of the capture. Each bin is
%   normalised by the median power of its +/-10 kHz neighbourhood. For every
%   common offset the comb score is the mean over tones of the best bin
%   within +/-TolHz (tolerates Pluto/N320 sample-clock scaling of the tone
%   offsets). The score across offsets is then expressed as a z-score so the
%   best offset can be judged against the noise-only spread.
p = inputParser;
addParameter(p, 'OffsetSearch_Hz', -60e3:1:60e3);
addParameter(p, 'TolHz', 30);
addParameter(p, 'ExcludeDC_Hz', 1e3);
addParameter(p, 'InjectTone_dBFS', NaN);     % synthetic positive control
addParameter(p, 'InjectOffset_Hz', 7300);
parse(p, varargin{:}); o = p.Results;

r = comm.BasebandFileReader(bbFile);
fs = r.SampleRate;
n0 = floor(window_s(1) * fs); n1 = floor(window_s(2) * fs);
r.SamplesPerFrame = n1;
x = r(); release(r);
if isinteger(x), x = double(x) / double(intmax(class(x))); else, x = double(x); end
x = x(n0+1:min(n1, size(x,1)), :);
N = size(x, 1); N = N - mod(N, 2); x = x(1:N, :);
if ~isnan(o.InjectTone_dBFS)
    n = (0:N-1).'; a = 10^(o.InjectTone_dBFS / 20); s = zeros(N, 1);
    for tf = toneOffsets_Hz(:).'
        s = s + a * exp(1j * (2*pi*(tf + o.InjectOffset_Hz)/fs*n + 2*pi*rand));
    end
    x = x + [s s];
end
df = fs / N;
P = abs(fftshift(fft(x .* hann(N, 'periodic')), 1)).^2;
f = ((-N/2):(N/2-1)).' * df;

keep = abs(f) <= max(abs(toneOffsets_Hz)) + max(abs(o.OffsetSearch_Hz)) + 20e3;   % comb span plus search margin
fk = f(keep); Pk = P(keep, :);
nNb = 2 * round(10e3 / df) + 1;
% movmedian on ~1.6M points is slow; use a decimated median floor instead.
dec = round(100 / df); nk = floor(numel(fk) / dec);
blk = reshape(Pk(1:nk*dec, :), dec, nk, 2);
floorDec = squeeze(median(blk, 1));
floorDec = movmedian(floorDec, max(3, round(nNb/dec)), 1);
floorFull = repelem(floorDec, dec, 1);
floorFull(end+1:numel(fk), :) = repmat(floorFull(end, :), numel(fk) - size(floorFull,1), 1);
norm_dB = 10*log10(Pk ./ floorFull);

tones = toneOffsets_Hz(abs(toneOffsets_Hz) > o.ExcludeDC_Hz);
tol = round(o.TolHz / df);
offs = o.OffsetSearch_Hz; score = zeros(numel(offs), 2);
i0 = round((tones(:) - fk(1)) / df) + 1;
% per-tone running max over +/-tol so each offset is one lookup
mx = movmax(norm_dB, 2*tol + 1, 1);
for i = 1:numel(offs)
    idx = i0 + round(offs(i) / df);
    ok = idx >= 1 & idx <= numel(fk);
    score(i, :) = mean(mx(idx(ok), :), 1);
end
z = (score - median(score, 1)) ./ (1.4826 * mad(score, 1, 1));
[bestZ, bi] = max(z, [], 1);
F = struct('file', bbFile, 'df_hz', df, 'N', N, 'offsets_hz', offs, 'score_dB', score, ...
    'z', z, 'bestZ', bestZ, 'bestOffset_hz', offs(bi), 'zAt0', z(offs == 0, :), ...
    'scoreAt0_dB', score(offs == 0, :), 'medianScore_dB', median(score, 1));
end
