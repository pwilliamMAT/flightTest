function F = dtvFitPointing(A, varargin)
%DTVFITPOINTING Compare DTV tower levels with a Yagi pattern and fit its pointing.
%   Uses the observed channel powers from dtvAbsoluteLevelCheck and the
%   isotropic predictions from dtvPredictDirectPath. The receive antenna is
%   modelled as a simple Yagi: G(d) = G0 - 12*(d/HPBW)^2 dBi, floored at
%   G0 - FrontToBack_dB, where d is the angle between tower bearing and
%   boresight. For each channel (SURV, REF) the residual
%       observed dBFS - (predicted dBm + G(d))
%   should be the same constant for every tower if the model and pointing
%   are right; its robust spread (MAD) is the fit criterion. Only channels
%   with SNR above MinSnr_dB are used.
%
%   F.assumed reports the residuals for the stated pointing; F.best gives the
%   pointing (and beamwidth / front-to-back) that minimises the spread.
%
% See also: dtvPredictDirectPath, dtvAbsoluteLevelCheck.
p = inputParser;
addParameter(p, 'AssumedBoresight_deg', [270 10]);   % [SURV REF]
addParameter(p, 'G0_dBi', 12);
addParameter(p, 'HPBW_deg', 45);
addParameter(p, 'FrontToBack_dB', 20);
addParameter(p, 'MinSnr_dB', 6);
addParameter(p, 'FitBoresight_deg', 0:2:358);
addParameter(p, 'FitHPBW_deg', 30:5:80);
addParameter(p, 'FitFrontToBack_dB', 10:5:30);
parse(p, varargin{:}); o = p.Results;

gainFn = @(d, g0, bw, fb) max(g0 - 12*(d/bw).^2, g0 - fb);
angDiff = @(a, b) abs(mod(a - b + 180, 360) - 180);
obs = [A.surv_dBFS, A.ref_dBFS]; snr = [A.surv_snr_dB, A.ref_snr_dB];
name = ["SURV", "REF"];

F = struct();
for c = 1:2
    use = snr(:, c) >= o.MinSnr_dB;
    d = angDiff(A.bearing_deg, o.AssumedBoresight_deg(c));
    res = obs(:, c) - (A.P_iso_dBm + gainFn(d, o.G0_dBi, o.HPBW_deg, o.FrontToBack_dB));
    K = median(res(use));
    F.assumed.(name(c)) = table(A.rf_channel, A.call_signs, A.bearing_deg, d, snr(:, c), res - K, use, ...
        'VariableNames', {'rf_channel', 'call_signs', 'bearing_deg', 'off_boresight_deg', 'snr_dB', 'residual_dB', 'used'});
    F.assumed_offset_dB.(name(c)) = K;
    F.assumed_spread_dB.(name(c)) = 1.4826 * mad(res(use), 1);

    bestS = Inf;
    for az = o.FitBoresight_deg
        dd = angDiff(A.bearing_deg, az);
        for bw = o.FitHPBW_deg
            for fb = o.FitFrontToBack_dB
                r = obs(use, c) - (A.P_iso_dBm(use) + gainFn(dd(use), o.G0_dBi, bw, fb));
                s = 1.4826 * mad(r, 1);
                if s < bestS, bestS = s; F.best.(name(c)) = struct('boresight_deg', az, 'hpbw_deg', bw, 'front_to_back_dB', fb, 'spread_dB', s); end
            end
        end
    end
    % spread vs boresight (best beamwidth/front-to-back at each azimuth), for plotting
    curve = zeros(numel(o.FitBoresight_deg), 1);
    for i = 1:numel(o.FitBoresight_deg)
        dd = angDiff(A.bearing_deg(use), o.FitBoresight_deg(i)); sBest = Inf;
        for bw = o.FitHPBW_deg
            for fb = o.FitFrontToBack_dB
                sBest = min(sBest, 1.4826 * mad(obs(use, c) - (A.P_iso_dBm(use) + gainFn(dd, o.G0_dBi, bw, fb)), 1));
            end
        end
        curve(i) = sBest;
    end
    F.spread_vs_boresight.(name(c)) = curve;
end
F.fit_boresight_deg = o.FitBoresight_deg;
F.settings = o;
end
