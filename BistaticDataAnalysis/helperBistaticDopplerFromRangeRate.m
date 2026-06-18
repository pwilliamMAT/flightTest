function f_D_hz = helperBistaticDopplerFromRangeRate(Rdot_mps, fc)
%HELPERBISTATICDOPPLERFROMRANGERATE Convert bistatic excess-path rate to Doppler.
%
%   f_D_hz = helperBistaticDopplerFromRangeRate(Rdot_mps, fc)
%
%   Uses the passive-radar CAF sign convention from createRDM.m:
%
%       f_D = -(fc / c) * Rdot
%
%   Positive Doppler therefore means the bistatic excess path is shrinking.

alpha = helperBistaticDopplerCoupling(fc);
f_D_hz = -alpha .* Rdot_mps;

end
