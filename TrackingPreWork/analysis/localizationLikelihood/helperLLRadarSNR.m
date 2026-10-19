function out = helperLLRadarSNR(cfg,site,ranges,loss)
%HELPERLLRADARSNR Explicit bistatic matched-observation radar equation.
% ERP references a dipole: add 2.15 dB to obtain isotropic radiated power.
% Pass EIRP as power and set transmit gain to zero to avoid double counting.
% F*T0 includes antenna noise at T0 plus receiver equivalent noise (F-1)*T0.
f = cfg.rf;
lambda = physconst("LightSpeed")/site.frequencyHz;
out.eirpW = site.erpW*10^(f.erpToEirpDB/10);
out.noiseTemperatureK = f.referenceTemperatureK*10^(f.noiseFigureDB/10);
out.snrDB = radareqsnr(lambda,ranges,out.eirpW,f.equivalentIntervalS, ...
    Gain=[0 f.receiveGainDBi],Ts=out.noiseTemperatureK,RCS=f.rcsM2, ...
    Loss=loss+f.additionalLossDB);
out.receivedPowerW = out.eirpW*10^(f.receiveGainDBi/10)*lambda^2*f.rcsM2 ...
    ./((4*pi)^3*prod(ranges.^2,2)).*10.^(-(loss+f.additionalLossDB)/10);
out.inputNoiseW = physconst("Boltzmann")*out.noiseTemperatureK*f.bandwidthHz;
% SNR = Pr*tau/(k*Ts). Input Pr/(k*Ts*B) differs by B*tau.
% The 5 microsecond equivalent interval is counted exactly once.
end
