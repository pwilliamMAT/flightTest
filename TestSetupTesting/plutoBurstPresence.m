function R = plutoBurstPresence(bbFile, toneOffsets_Hz, pulseStart_s, pulseDur_s, varargin)
%PLUTOBURSTPRESENCE Is the Pluto comb present anywhere in an N320 capture?
%   Reads a dual-channel .bb capture in 10 ms blocks (100 Hz FFT bins) and
%   compares the mean spectrum inside the nominal pulse window against the
%   ambient spectrum outside it. The pulse/ambient ratio shows added energy
%   even if the comb landed at an unexpected frequency offset. A common
%   comb offset is then searched, and comb power vs time is tracked.
p = inputParser;
addParameter(p, 'Block_s', 0.010);
addParameter(p, 'Guard_s', 0.05);
addParameter(p, 'OffsetSearch_Hz', -60e3:100:60e3);
addParameter(p, 'SpecSpan_Hz', 1e6);     % spectrogram span kept (+/-)
addParameter(p, 'SpecBin_Hz', 2e3);      % spectrogram bin width
parse(p, varargin{:}); o = p.Results;

r = comm.BasebandFileReader(bbFile);
fs = r.SampleRate;
N = round(o.Block_s * fs);
blocksPerFrame = 10;
r.SamplesPerFrame = N * blocksPerFrame;
nTot = r.info.NumSamplesInData;
nBlocks = floor(nTot / N);
w = hann(N, 'periodic'); wpow = sum(w.^2);
f = ((-N/2):(N/2-1)).' * fs / N;         % centered, 100 Hz bins

keep = abs(f) <= o.SpecSpan_Hz;
nAgg = round(o.SpecBin_Hz / (fs/N));
fk = f(keep); nk = floor(numel(fk)/nAgg);
fSpec = mean(reshape(fk(1:nk*nAgg), nAgg, nk), 1).';

t = ((0:nBlocks-1).' + 0.5) * o.Block_s;
inPulse = t > pulseStart_s + o.Guard_s & t < pulseStart_s + pulseDur_s - o.Guard_s;
ambient = t < pulseStart_s - o.Guard_s | t > pulseStart_s + pulseDur_s + o.Guard_s;

sumP = zeros(N, 2); sumA = zeros(N, 2);
blockPow = zeros(nBlocks, 2);
spec = zeros(nk, nBlocks, 2, 'single');
blockSpec = zeros(N, nBlocks, 2, 'single');  % kept for comb-vs-time
b = 0; scale = [];
while ~isDone(r) && b < nBlocks
    x = r();
    if isempty(scale)
        if isinteger(x), scale = double(intmax(class(x))); else, scale = 1; end
    end
    x = double(x) / scale;
    for k = 1:blocksPerFrame
        if b >= nBlocks || k*N > size(x,1), break; end
        b = b + 1;
        seg = x((k-1)*N+1:k*N, :);
        blockPow(b, :) = mean(abs(seg).^2, 1);
        X = fftshift(fft(seg .* w), 1);
        P = abs(X).^2 / wpow / N;        % per-bin power, full-scale = 1
        blockSpec(:, b, :) = reshape(single(P), N, 1, 2);
        if inPulse(b), sumP = sumP + P; end
        if ambient(b), sumA = sumA + P; end
        pk = P(keep, :);
        spec(:, b, :) = reshape(single(squeeze(sum(reshape(pk(1:nk*nAgg, :), nAgg, nk, 2), 1))), nk, 1, 2);
    end
end
release(r);
t = t(1:b); inPulse = inPulse(1:b); ambient = ambient(1:b);

meanP = sumP / nnz(inPulse); meanA = sumA / nnz(ambient);
ratio_dB = 10*log10(meanP ./ meanA);

% Common comb offset search: average pulse/ambient ratio over all tone bins.
offs = o.OffsetSearch_Hz; score = zeros(numel(offs), 2);
for i = 1:numel(offs)
    idx = round((toneOffsets_Hz(:) + offs(i)) / (fs/N)) + N/2 + 1;
    score(i, :) = mean(ratio_dB(idx, :), 1);
end
[bestScore, bi] = max(score, [], 1);
bestOff = offs(bi);

% Comb power vs time at the planned bins and at the best offset (REF channel 2 offset used for both).
idxPlan = round(toneOffsets_Hz(:) / (fs/N)) + N/2 + 1;
idxBest = round((toneOffsets_Hz(:) + bestOff(2)) / (fs/N)) + N/2 + 1;
combPlan_dB = 10*log10(squeeze(sum(blockSpec(idxPlan, 1:b, :), 1)));
combBest_dB = 10*log10(squeeze(sum(blockSpec(idxBest, 1:b, :), 1)));

% Strongest pulse-window excess lines (per channel), >= 1 kHz apart.
top = struct();
for c = 1:2
    [pk, loc] = findpeaks(ratio_dB(:, c), 'SortStr', 'descend', 'NPeaks', 20, 'MinPeakDistance', round(1e3/(fs/N)));
    top(c).freq_hz = f(loc); top(c).excess_db = pk;
    top(c).level_dbfs = 10*log10(meanP(loc, c));
end

R = struct('file', bbFile, 'fs', fs, 'block_s', o.Block_s, 't', t, ...
    'blockPow_dBFS', 10*log10(blockPow(1:b, :)), 'inPulse', inPulse, 'ambient', ambient, ...
    'f', f, 'ratio_dB', ratio_dB, 'meanP_dBFS', 10*log10(meanP), 'meanA_dBFS', 10*log10(meanA), ...
    'offsets_hz', offs, 'offsetScore_dB', score, 'bestOffset_hz', bestOff, 'bestScore_dB', bestScore, ...
    'combPlan_dB', combPlan_dB, 'combBest_dB', combBest_dB, 'top', top, ...
    'fSpec', fSpec, 'spec_dBFS', 10*log10(double(spec(:, 1:b, :))));
end
