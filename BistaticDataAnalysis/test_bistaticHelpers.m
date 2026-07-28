%% test_bistaticHelpers.m
% Non-hardware checks for timing and capture helpers.

clear; clc;

cfg = struct( ...
    'fc', 599e6, ...
    'fs', 8e6, ...
    'N_slow_cpi', 200, ...
    'cpi_duration_s', 0.5e-3);

consts = helperDeriveBistaticConstants(cfg);
assert(abs(consts.alpha - helperBistaticDopplerCoupling(cfg.fc)) < 1e-12);
assert(abs(consts.range_cell_m - physconst('LightSpeed') / cfg.fs) < 1e-9);
assert(abs(consts.doppler_bin_hz - 10) < 1e-12);

txLLA = [42.310278, -71.236667, 431.9];
rxLLA = [42.2999333, -71.349333, 15.0];
geom = helperDeriveTxRxGeometry(txLLA, rxLLA);
assert(abs(geom.baseline_3d_m - norm(geom.tx_enu_m)) < 1e-9);
assert(geom.baseline_3d_m > geom.baseline_horizontal_m);

rdot_ref = -125;
fd_ref = helperBistaticDopplerFromRangeRate(rdot_ref, cfg.fc);
assert(abs(helperBistaticRangeRateFromDoppler(fd_ref, cfg.fc) - rdot_ref) < 1e-12);

seg = helperCaptureSegments(0.1);
assert(isscalar(seg) && abs(seg - 0.1) < 1e-12);

seg = helperCaptureSegments(2.3);
assert(numel(seg) == 3);
assert(all(abs(seg - [1; 1; 0.3]) < 1e-12));
assert(abs(sum(seg) - 2.3) < 1e-12);

t0 = datetime(2026, 7, 5, 14, 25, 0, 'TimeZone', 'UTC');
start_dt = [t0; t0 + seconds(3.96); t0 + seconds(6.92)];
[offsets, timing_info] = helperGetPartStartOffsets( ...
    {'part1', 'part2', 'part3'}, 1.0, 3.0, ...
    'StartDateTimes', start_dt, 'Verbose', false);
assert(all(abs(offsets - [0; 3.96; 6.92]) < 1e-9));
assert(all(timing_info.used_metadata));

[fallback_offsets, fallback_info] = helperGetPartStartOffsets( ...
    {'part1', 'part2', 'part3'}, 1.0, 3.0, ...
    'StartDateTimes', NaT(3, 1), 'Verbose', false);
assert(all(abs(fallback_offsets - [0; 4; 8]) < 1e-12));
assert(strcmp(fallback_info.source, 'fallback_gap'));

[burst_offsets, burst_info] = helperGetPartStartOffsets( ...
    {'part1', 'part2', 'part3'}, 1.0, 2.0, ...
    'StartDateTimes', NaT(3, 1), 'Verbose', false);
assert(all(abs(burst_offsets - [0; 3; 6]) < 1e-12));
assert(strcmp(burst_info.source, 'fallback_gap'));

[forced_offsets, forced_info] = helperGetPartStartOffsets( ...
    {'part1', 'part2', 'part3'}, 1.0, 3.0, ...
    'StartDateTimes', start_dt, ...
    'TimingSource', 'fallback', ...
    'Verbose', false);
assert(all(abs(forced_offsets - [0; 4; 8]) < 1e-12));
assert(strcmp(forced_info.source, 'forced_fallback_gap'));

mode_info = helperResolveGeographicPlotMode( ...
    'Use2DFallback', true, ...
    'HasGeoglobe', true, ...
    'DefaultFigureVisible', 'on');
assert(~mode_info.use_globe);
assert(strcmp(mode_info.mode_label, "geoaxes 2-D map"));

mode_info = helperResolveGeographicPlotMode( ...
    'Use2DFallback', false, ...
    'HasGeoglobe', true, ...
    'DefaultFigureVisible', 'off');
assert(~mode_info.use_globe);
assert(contains(mode_info.reason, "DefaultFigureVisible"));

mode_info = helperResolveGeographicPlotMode( ...
    'Use2DFallback', false, ...
    'HasGeoglobe', false, ...
    'DefaultFigureVisible', 'on');
assert(~mode_info.use_globe);
assert(contains(mode_info.reason, "unavailable"));

mode_info = helperResolveGeographicPlotMode( ...
    'Use2DFallback', false, ...
    'HasGeoglobe', true, ...
    'DefaultFigureVisible', 'on');
assert(mode_info.use_globe);
assert(strcmp(mode_info.mode_label, "geoglobe 3-D globe"));

fprintf('test_bistaticHelpers passed.\n');
