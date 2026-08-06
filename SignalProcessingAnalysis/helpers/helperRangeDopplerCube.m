function [resp, range, speed] = helperRangeDopplerCube(surv, ref, fs, fc, maxSpeed)
    % helperRangeDopplerCube  Range-Doppler processing via cube reshaping.
    %   [resp, range, speed] = helperRangeDopplerCube(surv, ref, fs, fc, maxSpeed)
    %   reshapes data into a matrix based on desired max unambiguous speed,
    %   cross-correlates each column, and applies FFT in slow-time for
    %   Doppler processing.

    % Get the matrix dimensions based on the desired max unambiguous speed
    [nSamplePerPulse,nCol] = helperGetCubeDims(surv,fs,fc,maxSpeed);
    ns = nCol * nSamplePerPulse;
    surv = surv(1:ns);
    ref = ref(1:ns);
    survMat = reshape(surv, [nSamplePerPulse nCol]);
    refMat = reshape(ref, [nSamplePerPulse nCol]);

    % Get the Doppler freq shifts and speeds
    prf = 1 / (nSamplePerPulse / fs);
    dopFreqs = -prf/2:prf/(nCol-1):prf/2;
    speed = dop2speed(dopFreqs, freq2wavelen(fc));

    % Get the bistatic ranges
    rangeRes = physconst('LightSpeed') / fs;
    range = ((-nSamplePerPulse+1):(nSamplePerPulse-1)) * rangeRes;

    % Cross correlate each surveillance with reference
    resp = zeros(length(range), nCol);
    for iCol = 1:nCol
        resp(:, iCol) = xcorr(survMat(:, iCol), refMat(:, iCol));
    end

    % FFT slow time for Doppler shift
    resp = abs(fftshift(fft(resp, [], 2), 2));
end
