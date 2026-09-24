function G = plutoCwGainSweep(varargin)
%PLUTOCWGAINSWEEP Receive-chain linearity check with a weak known carrier.
%   Concept: in a linear receiver a weak carrier rises 1 dB for every 1 dB of
%   N320 RadioGain. When strong out-of-band signals (the local DTV cluster)
%   overload the front end or ADC, the total output level stops rising and a
%   weak carrier is squeezed (desensitised), so its level rises less than the
%   gain or even falls. This sweep holds one Pluto CW carrier on and steps
%   the gain on both N320 channels, then repeats the steps with the carrier
%   off for the floor at the same bin.
%
%   Workflow: Pluto carrier on -> for each gain, capture FramesPerGain 0.1 s
%   frames -> Pluto off -> same gains again. The carrier bin is the strongest
%   on-minus-off bin within +/-SearchHalfWidth_Hz of the expected offset.
%   Tone levels include the Hann bin loss (1.76 dB) so they match
%   plutoCwLoopAnalyze.
%
% Outputs (struct G):
%   gain_dB        gains stepped (same value on both channels)
%   tone_dBFS      gains x [SURV REF], carrier level with the Pluto on
%   floor_dBFS     gains x [SURV REF], same bin with the Pluto off
%   total_dBFS     gains x [SURV REF], total output power with the Pluto on
%   slope_dB_per_dB  gains-1 x [SURV REF], incremental tone gain per step
%
% Example (carrier in the channel 35/36 gap):
%   G = plutoCwGainSweep('Carrier_Hz', 602.05e6, 'Gains_dB', 0:5:50);
%
% See also: plutoCwLoopTest, plutoCwLoopAnalyze, runBoundaryLoopTests.
p = inputParser;
addParameter(p, 'Carrier_Hz', 602.05e6);         % target RF carrier (after the crystal correction)
addParameter(p, 'N320BelowCarrier_Hz', 1.05e6);  % keep the carrier away from N320 DC
addParameter(p, 'PlutoToneOffset_Hz', 500e3);
addParameter(p, 'PlutoFs_Hz', 2e6);
addParameter(p, 'PlutoPpm', -17.4);
addParameter(p, 'PlutoTxGain_dB', 0);
addParameter(p, 'Amplitude', 0.78);
addParameter(p, 'Gains_dB', 0:5:50);
addParameter(p, 'FramesPerGain', 3);
addParameter(p, 'SearchHalfWidth_Hz', 15e3);
addParameter(p, 'RadioName', "My USRP N320");
parse(p, varargin{:}); o = p.Results;

fsN = 8e6; nFrame = round(0.1 * fsN);            % 10 Hz bins
nCenter = o.Carrier_Hz - o.N320BelowCarrier_Hz;
nominal = round(o.Carrier_Hz / (1 + o.PlutoPpm * 1e-6));   % pre-correct the Pluto crystal
plutoLO = nominal - o.PlutoToneOffset_Hz;
fAx = ((-nFrame/2):(nFrame/2-1)).' * fsN / nFrame;
keep = abs(fAx - o.N320BelowCarrier_Hz) <= o.SearchHalfWidth_Hz + 1e3;
win = hann(nFrame, 'periodic'); wpow = sum(win.^2);

nPer = o.PlutoFs_Hz / gcd(round(o.PlutoToneOffset_Hz), round(o.PlutoFs_Hz));
toneWave = single(o.Amplitude * exp(1j*2*pi*o.PlutoToneOffset_Hz/o.PlutoFs_Hz*(0:nPer*ceil(8192/nPer)-1).'));

bbrx = basebandReceiver(o.RadioName);
bbrx.CenterFrequency = nCenter; bbrx.SampleRate = fsN; bbrx.Antennas = ["RF0:RX2", "RF1:RX2"];
nG = numel(o.Gains_dB);
Pk = zeros(nnz(keep), 2, nG, 2);                  % kept bins x channel x gain x [on off]
tot = zeros(nG, 2, 2);
tx = [];
try
    for state = 1:2                               % 1 = carrier on, 2 = carrier off
        if state == 1
            tx = sdrtx('Pluto', 'CenterFrequency', plutoLO, 'BasebandSampleRate', o.PlutoFs_Hz, 'Gain', o.PlutoTxGain_dB);
            transmitRepeat(tx, toneWave);
            fprintf('%s Pluto carrier ON near %.4f MHz\n', datestr(now,'HH:MM:SS'), o.Carrier_Hz/1e6);
        else
            release(tx); tx = [];
            fprintf('%s Pluto carrier OFF\n', datestr(now,'HH:MM:SS'));
        end
        for g = 1:nG
            bbrx.RadioGain = o.Gains_dB(g) * [1 1];
            capture(bbrx, seconds(0.02));         % discard one capture after the gain change
            acc = zeros(nnz(keep), 2); pt = zeros(1, 2);
            for f = 1:o.FramesPerGain
                x = double(capture(bbrx, seconds(0.1))) / 32767; x = x - mean(x, 1);
                X = fftshift(fft(x .* win), 1) / sqrt(wpow * nFrame);
                acc = acc + abs(X(keep, :)).^2; pt = pt + mean(abs(x).^2, 1);
            end
            Pk(:, :, g, state) = acc / o.FramesPerGain; tot(g, :, state) = pt / o.FramesPerGain;
        end
    end
catch me
    if ~isempty(tx), try, release(tx); catch, end, end
    clear bbrx
    rethrow(me)
end
clear bbrx

% Carrier bin: strongest on/off ratio (summed over gains and channels) in the search window.
fK = fAx(keep); search = abs(fK - o.N320BelowCarrier_Hz) <= o.SearchHalfWidth_Hz;
score = sum(sum(log(Pk(:, :, :, 1) ./ Pk(:, :, :, 2)), 3), 2); score(~search) = -Inf;
[~, iB] = max(score);
G = struct();
G.gain_dB = o.Gains_dB(:);
G.carrier_rf_hz = nCenter + fK(iB);
G.tone_dBFS = squeeze(10*log10(Pk(iB, :, :, 1))).' + 1.76;
G.floor_dBFS = squeeze(10*log10(Pk(iB, :, :, 2))).' + 1.76;
G.total_dBFS = 10*log10(tot(:, :, 1));
G.slope_dB_per_dB = diff(G.tone_dBFS) ./ diff(G.gain_dB);
G.settings = o;
end
