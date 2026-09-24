function A = dtvAbsoluteLevelCheck(P, varargin)
%DTVABSOLUTELEVELCHECK Measure DTV channel power on REF and SURV and compare with prediction.
%   For each channel in P (from dtvPredictDirectPath) the N320 is tuned to
%   the channel centre and records a short dual-channel capture. The power in
%   the ATSC occupied bandwidth (+/-2.69 MHz, excluding the DC bins) is
%   integrated and the noise measured over the same bandwidth in an empty
%   reference channel is subtracted.
%
%   The N320 is not calibrated in dBm, so the comparison is relative: for a
%   good model, observed dBFS minus predicted dBm (isotropic prediction plus
%   receive antenna gain at the tower bearing) is the same constant for every
%   tower on a given channel. The spread of that offset is the test; the fit
%   of antenna pointing (fitPointing) uses the same idea.
%
% Example:
%   P = dtvPredictDirectPath();
%   A = dtvAbsoluteLevelCheck(P);
%
% See also: dtvPredictDirectPath, basebandReceiver.
p = inputParser;
addParameter(p, 'RadioName', "My USRP N320");
addParameter(p, 'Gain', [30 50]);                  % [SURV REF] = [RF0:RX2 RF1:RX2]
addParameter(p, 'Capture_s', 0.25);
addParameter(p, 'NoiseChannelCenter_Hz', 551e6);   % RF channel 27, empty in the table
addParameter(p, 'OccupiedHalfWidth_Hz', 2.69e6);
addParameter(p, 'ExcludeDC_Hz', 5e3);
parse(p, varargin{:}); o = p.Results;

fs = 8e6; Nb = 8000;                               % 1 kHz bins
w = hann(Nb, 'periodic'); wp = sum(w.^2);
f = ((-Nb/2):(Nb/2-1)).' * fs / Nb;
occ = abs(f) <= o.OccupiedHalfWidth_Hz & abs(f) > o.ExcludeDC_Hz;

bbrx = basebandReceiver(o.RadioName);
bbrx.SampleRate = fs; bbrx.RadioGain = o.Gain; bbrx.Antennas = ["RF0:RX2", "RF1:RX2"];
centres = [o.NoiseChannelCenter_Hz; P.center_frequency_mhz(:) * 1e6];
psd = zeros(Nb, 2, numel(centres));
for k = 1:numel(centres)
    bbrx.CenterFrequency = centres(k);
    x = double(capture(bbrx, seconds(o.Capture_s))) / 32767;
    x = x - mean(x, 1);
    nb = floor(size(x, 1) / Nb); acc = zeros(Nb, 2);
    for b = 1:nb
        acc = acc + abs(fftshift(fft(x((b-1)*Nb+1:b*Nb, :) .* w), 1)).^2 / wp / Nb;
    end
    psd(:, :, k) = acc / nb;                        % per-bin power, full scale = 1
end
clear bbrx

noiseLin = sum(psd(occ, :, 1), 1);                  % 1 x 2, same bandwidth, empty channel
A = P;
chanLin = squeeze(sum(psd(occ, :, 2:end), 1)).';    % channels x 2
sigLin = max(chanLin - noiseLin, eps);
A.surv_dBFS = 10*log10(sigLin(:, 1));  A.ref_dBFS = 10*log10(sigLin(:, 2));
A.surv_snr_dB = 10*log10(chanLin(:, 1) ./ noiseLin(1));
A.ref_snr_dB  = 10*log10(chanLin(:, 2) ./ noiseLin(2));
A.Properties.UserData = struct('noise_dBFS', 10*log10(noiseLin), 'gain_dB', o.Gain, ...
    'occupied_half_width_hz', o.OccupiedHalfWidth_Hz, 'psd', psd, 'f_hz', f, 'centres_hz', centres);
end
