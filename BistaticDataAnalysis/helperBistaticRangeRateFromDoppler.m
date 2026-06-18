function Rdot_mps = helperBistaticRangeRateFromDoppler(f_D_hz, fc)
%HELPERBISTATICRANGERATEFROMDOPPLER Convert Doppler to bistatic excess-path rate.
%
%   Rdot_mps = helperBistaticRangeRateFromDoppler(f_D_hz, fc)
%
%   Inverts the passive-radar CAF convention from createRDM.m:
%
%       f_D = -(fc / c) * Rdot
%
%   Positive Doppler therefore implies negative bistatic range rate.

alpha = helperBistaticDopplerCoupling(fc);
Rdot_mps = -f_D_hz ./ alpha;

end
