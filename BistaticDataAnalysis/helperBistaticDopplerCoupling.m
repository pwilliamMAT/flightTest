function alpha = helperBistaticDopplerCoupling(fc)
%HELPERBISTATICDOPPLERCOUPLING Doppler coupling for bistatic excess-path rate.
%
%   alpha = helperBistaticDopplerCoupling(fc)
%
%   For the measurement state R_excess = R_tx + R_rx - L, the passive CAF
%   convention implemented in createRDM.m maps bistatic range rate to
%   Doppler as:
%
%       f_D = -(fc / c) * dR_excess/dt = -alpha * Rdot
%
%   This helper returns only the positive magnitude alpha = fc / c. Callers
%   should apply the sign explicitly through:
%
%       f_D_hz = -alpha * Rdot_mps
%       Rdot_mps = -f_D_hz / alpha

validateattributes(fc, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, 'fc');

alpha = fc / physconst('LightSpeed');

end
