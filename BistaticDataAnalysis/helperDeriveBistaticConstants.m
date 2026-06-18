function constants = helperDeriveBistaticConstants(config)
%HELPERDERIVEBISTATICCONSTANTS  Shared radar constants for tracking/truth.
%
%  constants = helperDeriveBistaticConstants(config)
%
%  Required config fields:
%    .fc              carrier frequency [Hz]
%    .fs              sample rate [Hz]
%    .N_slow_cpi      slow-time samples per chunk/CPI block
%    .cpi_duration_s  CPI duration [s]
%
%  Returned fields:
%    .c_light         speed of light [m/s]
%    .alpha           Doppler coupling alpha = fc/c [Hz/(m/s)] for
%                     f_D = -alpha * dR_excess/dt
%    .range_cell_m    bistatic range-cell spacing [m]
%    .doppler_bin_hz  Doppler bin size [Hz]
%    .chunk_dur_s     chunk duration [s]

required_fields = {'fc', 'fs', 'N_slow_cpi', 'cpi_duration_s'};
for k = 1 : numel(required_fields)
    fld = required_fields{k};
    if ~isfield(config, fld) || isempty(config.(fld))
        error('helperDeriveBistaticConstants:missingField', ...
            'config.%s is required.', fld);
    end
end

c_light = physconst('LightSpeed');

constants = struct( ...
    'c_light',        c_light, ...
    'alpha',          helperBistaticDopplerCoupling(config.fc), ...
    'range_cell_m',   c_light / config.fs, ...
    'doppler_bin_hz', 1 / (config.N_slow_cpi * config.cpi_duration_s), ...
    'chunk_dur_s',    config.N_slow_cpi * config.cpi_duration_s);

end
