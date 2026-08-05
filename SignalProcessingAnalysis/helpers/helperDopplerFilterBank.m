function [rd, range, speed] = helperDopplerFilterBank(surv, ref, fs, fc, nLags, maxSpeed, nDop)
    % helperDopplerFilterBank  Range-Doppler processing via Doppler filter bank.
    %   [rd, range, speed] = helperDopplerFilterBank(surv, ref, fs, fc, nLags, maxSpeed, nDop)
    %   computes the range-Doppler map by cross-correlating the surveillance
    %   channel with Doppler-shifted copies of the reference channel.

    % Measure number of samples
    nSamples = length(ref);

    % Calculate range
    range = (-nLags:nLags) / fs * physconst("LightSpeed");

    % Measure time
    t = ((1:nSamples) / fs)';

    % Get doppler frequencies
    speed = linspace(-maxSpeed, maxSpeed, nDop);
    fDoppler = speed2dop(speed, freq2wavelen(fc));

    % Initialize range-Doppler
    rd = zeros(2*nLags+1, nDop);

    for iSpeed = 1:nDop
        fShift = fDoppler(iSpeed);
        fSig = exp(1i * 2 * pi * fShift * t);
        refShift = ref .* fSig;
        rd(:, iSpeed) = xcorr(surv, refShift, nLags);
    end
end
