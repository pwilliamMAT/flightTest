function L = plutoCombLineCheck(bbFile, toneOffsets_Hz, varargin)
%PLUTOCOMBLINECHECK Do the planned comb bins stand above their neighbours?
%   Averages 10 ms Hann-windowed FFT blocks (100 Hz bins) over the capture
%   (or a time window), normalises each bin by the moving median of the
%   surrounding +/-10 kHz, and scores the comb at a range of common offsets.
%   Noise-only -> ~0 dB at every offset; a present tone -> clear positive dB.
p = inputParser;
addParameter(p, 'Block_s', 0.010);
addParameter(p, 'Window_s', [0 Inf]);
addParameter(p, 'OffsetSearch_Hz', -60e3:100:60e3);
addParameter(p, 'ExcludeDC_Hz', 1e3);
parse(p, varargin{:}); o = p.Results;

r = comm.BasebandFileReader(bbFile);
fs = r.SampleRate; N = round(o.Block_s * fs);
r.SamplesPerFrame = N;
w = hann(N, 'periodic'); wpow = sum(w.^2);
f = ((-N/2):(N/2-1)).' * fs / N;
acc = zeros(N, 2); nb = 0; b = 0; scale = [];
while ~isDone(r)
    x = r(); b = b + 1;
    if size(x,1) < N, break; end
    tc = (b - 0.5) * o.Block_s;
    if tc < o.Window_s(1) || tc > o.Window_s(2), continue; end
    if isempty(scale)
        if isinteger(x), scale = double(intmax(class(x))); else, scale = 1; end
    end
    x = double(x) / scale;
    acc = acc + abs(fftshift(fft(x .* w), 1)).^2 / wpow / N; nb = nb + 1;
end
release(r);
P = acc / nb;
norm_dB = 10*log10(P ./ movmedian(P, 201, 1));   % vs +/-10 kHz neighbourhood

tones = toneOffsets_Hz(abs(toneOffsets_Hz) > o.ExcludeDC_Hz);
offs = o.OffsetSearch_Hz; score = zeros(numel(offs), 2);
for i = 1:numel(offs)
    idx = round((tones(:) + offs(i)) / (fs/N)) + N/2 + 1;
    score(i, :) = mean(norm_dB(idx, :), 1);
end
idx0 = round(tones(:) / (fs/N)) + N/2 + 1;
[best, bi] = max(score, [], 1);
L = struct('file', bbFile, 'numBlocks', nb, 'tones_hz', tones(:), ...
    'toneNorm_dB', norm_dB(idx0, :), 'scoreAt0_dB', score(offs == 0, :), ...
    'bestOffset_hz', offs(bi), 'bestScore_dB', best, 'offsets_hz', offs, 'score_dB', score, ...
    'dcNorm_dB', norm_dB(N/2+1, :), ...
    'pilotNorm_dB', max(norm_dB(abs(f + 2.6905e6) <= 2e3, :), [], 1));   % ATSC pilot = positive control
end
