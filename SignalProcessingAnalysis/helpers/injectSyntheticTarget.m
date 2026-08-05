function [newSurv,targetSig] = injectSyntheticTarget(surv,ref,fs,fc,range,speed,atten)
    % Inject a target at a given range, speed, at some attenuation (dB)
    
    % Get the sample delay to apply to the reference signal
    delaySamples = range/physconst("LightSpeed")*fs;
    
    % Get the frequency shift to apply to the reference signal
    fShift = speed2dop(speed,freq2wavelen(fc));
    nSamples = length(surv);
    t = ((1:nSamples)/fs)';
    
    % Get the magnitude to apply to the reference signal
    survMag = rms(surv);
    refMag = rms(ref);
    tarMag = survMag/db2mag(atten)/refMag;
    
    % Apply delay, magnitude, doppler
    df = dsp.VariableFractionalDelay(MaximumDelay=round(2*delaySamples));
    sigDelay = df(ref,delaySamples);
    sigAtten = sigDelay*tarMag;
    targetSig = sigAtten.*exp(1i*2*pi*fShift*t);
    newSurv = surv + targetSig;   
end