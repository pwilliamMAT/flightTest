function [nSamplePerPulse,nPulse] = helperGetCubeDims(sig,fs,fc,maxSpeed)

% Calculate the dimensions of a RD cube.

% Get samples per pulse
prf = speed2dop(maxSpeed, freq2wavelen(fc)) * 2;
pri = 1 / prf;
nSamplePerPulse = round(pri * fs);

% Get number of pulses
ns = length(sig);
nPulse = floor(ns / nSamplePerPulse);
if mod(nPulse, 2) == 0
    nPulse = nPulse - 1;
end

end