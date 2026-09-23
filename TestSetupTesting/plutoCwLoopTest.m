function H = plutoCwLoopTest(varargin)
%PLUTOCWLOOPTEST Close the Pluto -> N320 over-the-air loop with a single CW carrier.
%   The N320 records in 0.1 s frames: ambient, then the Pluto carrier on, then
%   ambient again, so every run carries its own carrier-off baseline. For each
%   frame only the FFT bins within +/-Keep_Hz of the expected carrier are kept
%   (10 Hz bins), which supports stacked (non-coherent) and coherent analysis.
%
%   The Pluto LO is placed away from the carrier (PlutoLO_Hz + ToneOffset_Hz =
%   carrier), so LO leakage and the I/Q image can be kept out of the band the
%   carrier is meant to occupy. AllowedBand_Hz, when given, asserts that the
%   carrier +/- the crystal tolerance lies inside [lo hi].
%
%   An optional CW text (IdText) can be keyed on the carrier after the capture.
%
% Example (carrier at the channel 35/36 boundary, N320 at 599 MHz):
%   H = plutoCwLoopTest('N320Center_Hz', 599e6, 'PlutoLO_Hz', 601.56e6, ...
%       'ToneOffset_Hz', 500e3, 'PlutoFs_Hz', 2e6);
%
% See also: plutoCombFineCheck, plutoLoopbackCheck, sdrtx, basebandReceiver.
p = inputParser;
addParameter(p, 'N320Center_Hz', 599e6);
addParameter(p, 'PlutoLO_Hz', 601.56e6);
addParameter(p, 'ToneOffset_Hz', 500e3);        % Pluto baseband offset: carrier = LO + offset
addParameter(p, 'PlutoFs_Hz', 2e6);
addParameter(p, 'Amplitude', 0.78);
addParameter(p, 'PlutoTxGain_dB', 0);
addParameter(p, 'PreFrames', 10);
addParameter(p, 'PulseFrames', 100);
addParameter(p, 'PostFrames', 110);
addParameter(p, 'FrameDuration_s', 0.1);
addParameter(p, 'AllowedBand_Hz', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'CrystalTolerance_Hz', 15e3);
addParameter(p, 'IdText', "");
addParameter(p, 'IdWpm', 18);
addParameter(p, 'Keep_Hz', 40e3);              % bandwidth kept around the expected carrier
parse(p, varargin{:}); o = p.Results;

rfCarrier = o.PlutoLO_Hz + o.ToneOffset_Hz;
if ~isempty(o.AllowedBand_Hz)
    assert(rfCarrier - o.CrystalTolerance_Hz > o.AllowedBand_Hz(1) && rfCarrier + o.CrystalTolerance_Hz < o.AllowedBand_Hz(2), ...
        'Carrier plus crystal tolerance must stay inside AllowedBand_Hz.');
end
fsN = 8e6; bbExpected = rfCarrier - o.N320Center_Hz;   % expected carrier offset at the N320

% Pluto carrier waveform: integer number of cycles so the repeat is seamless.
nPer = o.PlutoFs_Hz / gcd(round(o.ToneOffset_Hz), round(o.PlutoFs_Hz));
nBuf = nPer * ceil(8192 / nPer);
toneWave = single(o.Amplitude * exp(1j*2*pi*o.ToneOffset_Hz/o.PlutoFs_Hz*(0:nBuf-1).'));

bbrx = basebandReceiver("My USRP N320");
bbrx.CenterFrequency = o.N320Center_Hz; bbrx.SampleRate = fsN;
bbrx.RadioGain = [30 50]; bbrx.Antennas = ["RF0:RX2", "RF1:RX2"];

% Per frame, keep the Hann-windowed FFT bins within +/-Keep_Hz of the expected
% carrier (10 Hz bins for 0.1 s frames). Small to store; supports both averaged
% and coherent analysis afterwards.
nFrame = round(o.FrameDuration_s * fsN);
fAx = ((-nFrame/2):(nFrame/2-1)).' * fsN / nFrame;
keepIdx = find(abs(fAx - bbExpected) <= o.Keep_Hz);
win = hann(nFrame, 'periodic'); wpow = sum(win.^2);
nTot = o.PreFrames + o.PulseFrames + o.PostFrames;
spec = complex(zeros(numel(keepIdx), 2, nTot, 'single')); label = strings(nTot, 1); tWall = NaT(nTot, 1);

tx = []; H = struct('status', "incomplete");
try
    k = 0;
    for phase = ["pre", "pulse", "post"]
        switch phase
            case "pre",   nF = o.PreFrames;
            case "pulse", nF = o.PulseFrames;
                tx = sdrtx('Pluto', 'CenterFrequency', o.PlutoLO_Hz, 'BasebandSampleRate', o.PlutoFs_Hz, 'Gain', o.PlutoTxGain_dB);
                transmitRepeat(tx, toneWave);
                fprintf('%s Pluto carrier ON at %.4f MHz (LO %.4f, gain %g dB)\n', datestr(now,'HH:MM:SS'), rfCarrier/1e6, o.PlutoLO_Hz/1e6, o.PlutoTxGain_dB);
            case "post",  nF = o.PostFrames;
                localRelease(tx); tx = [];
                fprintf('%s Pluto carrier OFF\n', datestr(now,'HH:MM:SS'));
        end
        for i = 1:nF
            x = double(capture(bbrx, seconds(o.FrameDuration_s))) / 32767;
            k = k + 1; label(k) = phase; tWall(k) = datetime('now');
            X = fftshift(fft((x - mean(x, 1)) .* win), 1) / sqrt(wpow * nFrame);
            spec(:, :, k) = single(X(keepIdx, :));
        end
    end
    H.status = "captured";
catch me
    H.status = "failed"; H.error = me.message;
    fprintf('%s CAPTURE FAILED: %s\n', datestr(now,'HH:MM:SS'), me.message);
end
localRelease(tx); tx = [];
clear bbrx

% Optional CW text on the same carrier (sent even after a capture failure, if we transmitted).
if strlength(string(o.IdText)) > 0 && any(label == "pulse")
    idWave = localMorse(string(o.IdText), o.IdWpm, o.PlutoFs_Hz, o.ToneOffset_Hz, o.Amplitude);
    txid = sdrtx('Pluto', 'CenterFrequency', o.PlutoLO_Hz, 'BasebandSampleRate', o.PlutoFs_Hz, 'Gain', o.PlutoTxGain_dB);
    try
        % Fixed-size complex chunks: sdrtx rejects a size change, and an all-zero
        % slice of a complex array becomes real (Pluto rejects real input).
        chunk = 2^16;
        idWave = [idWave; zeros(chunk*ceil(numel(idWave)/chunk) - numel(idWave) + chunk, 1, 'like', idWave)];
        for s = 1:chunk:numel(idWave)
            txid(complex(idWave(s:s+chunk-1)));
        end
        pause(0.5);
    catch meId
        fprintf('%s CW text error: %s\n', datestr(now,'HH:MM:SS'), meId.message);
    end
    localRelease(txid);
    if exist('meId', 'var'), H.id_error = meId.message; else
        fprintf('%s CW text sent (%.1f s)\n', datestr(now,'HH:MM:SS'), numel(idWave)/o.PlutoFs_Hz); end
    H.id_duration_s = numel(idWave)/o.PlutoFs_Hz;
end

H.settings = o; H.rf_carrier_hz = rfCarrier; H.n320_baseband_offset_hz = bbExpected;
H.f_hz = fAx(keepIdx); H.spec = spec(:, :, 1:k); H.label = label(1:k); H.t_wall = tWall(1:k);
end

function localRelease(tx)
if ~isempty(tx)
    try, release(tx); catch, end
end
end

function w = localMorse(text, wpm, fs, fTone, amp)
% PARIS timing: 1 unit = 1.2/wpm s. Raised-cosine keying edges (5 ms) limit key clicks.
code = containers.Map( ...
    {'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z', ...
     '0','1','2','3','4','5','6','7','8','9'}, ...
    {'.-','-...','-.-.','-..','.','..-.','--.','....','..','.---','-.-','.-..','--','-.','---','.--.','--.-','.-.','...','-', ...
     '..-','...-','.--','-..-','-.--','--..','-----','.----','..---','...--','....-','.....','-....','--...','---..','----.'});
u = round(1.2 / wpm * fs);
key = [];
words = split(upper(string(text)));
for wi = 1:numel(words)
    ch = char(words(wi));
    for ci = 1:numel(ch)
        sym = code(ch(ci));
        for si = 1:numel(sym)
            n = u * (1 + 2*(sym(si) == '-'));
            key = [key; ones(n, 1); zeros(u, 1)]; %#ok<AGROW>
        end
        key = [key; zeros(2*u, 1)]; %#ok<AGROW>   % letter gap = 3 units total
    end
    key = [key; zeros(4*u, 1)]; %#ok<AGROW>       % word gap = 7 units total
end
r = round(0.005 * fs); ramp = 0.5 - 0.5*cos(pi*(0:r-1).'/r);
env = conv(key, [ramp; ones(1,1); flipud(ramp)] / (sum(ramp)*2 + 1), 'same');
env = min(env / max(env), 1);
w = single(amp * env .* exp(1j*2*pi*fTone/fs*(0:numel(key)-1).'));
end
