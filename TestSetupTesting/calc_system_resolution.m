function [res] = calc_system_resolution(fs, bw, Tint, fc)
    % calc_system_resolution: Calculates Range and Velocity resolution.
    % fs: Sample Rate (6.144e6)
    % bw: Signal Bandwidth (6e6)
    % Tint: Integration Time (e.g., 0.1)
    % fc: Center Frequency (e.g., 540e6)

    c = 3e8; % Speed of light
    lambda = c / fc;

    % 1. Range Resolution (Bistatic)
    % Theoretically: c / (2 * bw) for monostatic, but we report bistatic resolution
    res.range_res_m = c / bw; 

    % 2. Velocity (Doppler) Resolution
    % Determined by the observation window
    res.doppler_res_hz = 1 / Tint;
    res.velocity_res_mps = (res.doppler_res_hz * lambda) / 2;

    fprintf('--- Radar Resolution Metrics ---\n');
    fprintf('Range Resolution:    %.2f meters\n', res.range_res_m);
    fprintf('Velocity Resolution: %.2f m/s (at %.1f MHz)\n', ...
            res.velocity_res_mps, fc/1e6);
end