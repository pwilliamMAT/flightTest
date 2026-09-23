function LB = plutoLoopbackCheck(varargin)
%PLUTOLOOPBACKCHECK Does the Pluto radiate the calibration comb?
%   Transmits the same 12-tone no-DC comb the azimuth scan uses (TX port,
%   dipole) and receives it on the Pluto's own RX port (pigtail) at the same
%   centre frequency. Captures with TX off (baseline), TX at its default
%   gain, and TX 20 dB lower. Each tone bin is scored as height above the
%   median of its +/-10 kHz neighbourhood (100 Hz bins); the ATSC pilot is a
%   positive control that is present regardless of the Pluto.
p = inputParser;
addParameter(p, 'CenterFrequency_Hz', 599e6);
addParameter(p, 'SampleRate_Hz', 8e6);
addParameter(p, 'ToneOffsets_Hz', [-650 -550 -450 -350 -250 -150 150 250 350 450 550 650] * 1e3);
addParameter(p, 'TargetRMSAmplitude', 0.20);
addParameter(p, 'RxGain_dB', 20);
addParameter(p, 'NumFrames', 8);
addParameter(p, 'FrameSamples', 2^20);
addParameter(p, 'LowerTxBy_dB', 20);
addParameter(p, 'DiscardFrames', 8);
parse(p, varargin{:}); o = p.Results;

fs = o.SampleRate_Hz;
waveform = helperPlutoMultitoneBuildWaveform(fs, o.ToneOffsets_Hz, o.TargetRMSAmplitude);

rx = sdrrx('Pluto', 'CenterFrequency', o.CenterFrequency_Hz, 'BasebandSampleRate', fs, ...
    'GainSource', 'Manual', 'Gain', o.RxGain_dB, 'OutputDataType', 'double', ...
    'SamplesPerFrame', o.FrameSamples);
cleanRx = onCleanup(@() release(rx));

LB = struct('settings', o);
LB.off = localMeasure(rx, o, fs);

tx = sdrtx('Pluto', 'CenterFrequency', o.CenterFrequency_Hz, 'BasebandSampleRate', fs);
defaultGain = tx.Gain;
transmitRepeat(tx, waveform);
pause(0.5);
LB.on_default = localMeasure(rx, o, fs);
LB.on_default.tx_gain_db = defaultGain;
release(tx);

tx = sdrtx('Pluto', 'CenterFrequency', o.CenterFrequency_Hz, 'BasebandSampleRate', fs, ...
    'Gain', defaultGain - o.LowerTxBy_dB);
transmitRepeat(tx, waveform);
pause(0.5);
LB.on_lower = localMeasure(rx, o, fs);
LB.on_lower.tx_gain_db = defaultGain - o.LowerTxBy_dB;
release(tx);

LB.off_after = localMeasure(rx, o, fs);   % confirm TX really stopped
end

function M = localMeasure(rx, o, fs)
N = round(0.010 * fs);                     % 10 ms blocks -> 100 Hz bins
w = hann(N, 'periodic'); wpow = sum(w.^2);
f = ((-N/2):(N/2-1)).' * fs / N;
acc = zeros(N, 1); nb = 0; pw = [];
for k = 1:o.DiscardFrames, rx(); end       % flush libiio buffers queued before the change
perFrame = zeros(o.NumFrames, 1);
for k = 1:o.NumFrames
    [x, ~, overflow] = rx();
    if overflow, warning('plutoLoopbackCheck:overflow', 'RX overflow on frame %d', k); end
    x = x - mean(x);
    pw(end+1) = mean(abs(x).^2); %#ok<AGROW>
    Xf = fftshift(fft(x(1:N) .* w)); Pf = abs(Xf).^2; nf = 10*log10(Pf ./ movmedian(Pf, 201));
    perFrame(k) = mean(nf(round(o.ToneOffsets_Hz(:) / (fs/N)) + N/2 + 1));
    for b = 1:floor(numel(x) / N)
        seg = x((b-1)*N+1:b*N);
        acc = acc + abs(fftshift(fft(seg .* w))).^2 / wpow / N; nb = nb + 1;
    end
end
P = acc / nb;
norm_dB = 10*log10(P ./ movmedian(P, 201));
idx = round(o.ToneOffsets_Hz(:) / (fs/N)) + N/2 + 1;
offs = -60e3:100:60e3; score = zeros(size(offs));
for i = 1:numel(offs), score(i) = mean(norm_dB(idx + round(offs(i)/(fs/N)))); end
[best, bi] = max(score);
% strongest bin within +/-20 kHz of each tone (catches a Pluto LO offset)
toneMax = zeros(numel(idx), 1); toneMaxOff = zeros(numel(idx), 1);
for t = 1:numel(idx)
    win = idx(t) + (-200:200);
    [toneMax(t), j] = max(norm_dB(win)); toneMaxOff(t) = f(win(j)) - o.ToneOffsets_Hz(t);
end
M = struct('per_frame_comb_dB', perFrame, 'power_dBFS', 10*log10(mean(pw)), 'tone_norm_dB', norm_dB(idx), ...
    'tone_level_dBFS', 10*log10(P(idx)), 'comb_score_at0_dB', score(offs == 0), ...
    'best_offset_hz', offs(bi), 'best_score_dB', best, ...
    'tone_nearby_max_dB', toneMax, 'tone_nearby_offset_hz', toneMaxOff, ...
    'pilot_norm_dB', max(norm_dB(abs(f + 2.6905e6) <= 2e3)), 'f', f, 'norm_dB', norm_dB, 'P', P);
end
