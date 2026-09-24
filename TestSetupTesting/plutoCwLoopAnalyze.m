function S = plutoCwLoopAnalyze(H, varargin)
%PLUTOCWLOOPANALYZE Detect the carrier in a plutoCwLoopTest record, per channel.
%   The carrier is located as the best carrier-on / carrier-off power ratio
%   within +/-SearchHalfWidth_Hz of the nominal offset. The stronger channel
%   gives the carrier bin. The weaker channel is then tested at that bin by
%   the Rayleigh statistic of its frame-to-frame phase relative to the
%   stronger channel (carrier-on frames), with the carrier-off frames at the
%   same bin as the null. Coupling is the tone level (Hann bin loss added
%   back) minus the Pluto DAC level (20*log10(Amplitude)).
%
% Example:
%   H = plutoCwLoopTest(...); S = plutoCwLoopAnalyze(H)
%
% See also: plutoCwLoopTest, plutoCombFineCheck.
p = inputParser;
addParameter(p, 'SearchHalfWidth_Hz', 15e3);
addParameter(p, 'HannBinLoss_dB', 1.76);
addParameter(p, 'StrongMinZ', 8);            % robust z of the on/off ratio needed to call the strong channel detected
parse(p, varargin{:}); o = p.Results;

f = double(H.f_hz); X = double(H.spec); Pw = abs(X).^2;
on = H.label == "pulse"; off = ~on;
Pon = mean(Pw(:, :, on), 3); Poff = mean(Pw(:, :, off), 3);
ratio = 10*log10(Pon ./ Poff);
search = abs(f - H.n320_baseband_offset_hz) <= o.SearchHalfWidth_Hz;
name = ["SURV", "REF"];

best = zeros(1, 2); z = zeros(1, 2);
for c = 1:2
    r = ratio(:, c); zz = (r - median(r)) / (1.4826 * mad(r, 1));
    rs = r; rs(~search) = -Inf; [~, best(c)] = max(rs); z(c) = zz(best(c));
end
[~, strong] = max(ratio(sub2ind(size(ratio), best, 1:2)));
weak = 3 - strong; iB = best(strong);

phaseR = @(m) abs(mean(exp(1j * angle(squeeze(X(iB, weak, m)) .* conj(squeeze(X(iB, strong, m)))))));
Ron = phaseR(on); Roff = phaseR(off); nOn = nnz(on); nOff = nnz(off);
pOn = exp(-nOn * Ron^2); pOff = exp(-nOff * Roff^2);

Xs = squeeze(X(iB, weak, on)); Xr = squeeze(X(iB, strong, on));
weakCoh = abs(mean(Xs .* conj(Xr) ./ abs(Xr)));               % weak-channel component locked to the strong one
toneDb = 10*log10(Pon(iB, :)) + o.HannBinLoss_dB;              % 1 x 2, per-channel tone level (dBFS)
toneDb(weak) = 20*log10(weakCoh) + o.HannBinLoss_dB;
dacDb = 20*log10(H.settings.Amplitude);

S = struct();
S.carrier_rf_hz = H.settings.N320Center_Hz + f(iB);
S.carrier_offset_from_nominal_hz = f(iB) - H.n320_baseband_offset_hz;
S.carrier_offset_ppm = S.carrier_offset_from_nominal_hz / (H.rf_carrier_hz / 1e6);
S.strong_channel = name(strong); S.weak_channel = name(weak);
S.strong_detected = z(strong) >= o.StrongMinZ;   % otherwise neither channel saw the carrier
S.onoff_dB = [ratio(best(1), 1), ratio(best(2), 2)];           % [SURV REF], each at its own best bin
S.onoff_z = z;
S.weak_onoff_at_strong_bin_dB = ratio(iB, weak);
S.weak_phase_R_on = Ron; S.weak_phase_p_on = pOn;
S.weak_phase_R_off = Roff; S.weak_phase_p_off = pOff;
S.weak_detected = S.strong_detected && pOn < 1e-6 && pOff > 1e-3;
S.tone_dBFS = toneDb;                                          % [SURV REF]
S.coupling_dB = toneDb - dacDb;                                % [SURV REF]
S.floor_dBFS_per_bin = 10*log10(median(Poff, 1));             % [SURV REF], 10 Hz bins
S.frames_on = nOn; S.frames_off = nOff;
S.trace_dBFS = squeeze(10*log10(max(Pw(max(iB-2,1):min(iB+2,end), :, :), [], 1)));   % 2 x frames
S.labels = H.label;
end
