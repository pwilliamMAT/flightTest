%% test_bistaticHelpers.m
% Non-hardware checks for timing and capture helpers.

clear; clc;

cfg = struct( ...
    'fc', 599e6, ...
    'fs', 8e6, ...
    'N_slow_cpi', 200, ...
    'cpi_duration_s', 0.5e-3);

consts = helperDeriveBistaticConstants(cfg);
assert(abs(consts.range_cell_m - physconst('LightSpeed') / (2 * cfg.fs)) < 1e-9);
assert(abs(consts.doppler_bin_hz - 10) < 1e-12);

seg = helperCaptureSegments(0.1);
assert(numel(seg) == 1 && abs(seg - 0.1) < 1e-12);

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

fprintf('test_bistaticHelpers passed.\n');
