%% test_adsbTruthPipeline.m
% Self-contained test / demo for the ADS-B truth integration pipeline.
%
% WHAT IT DOES
% ────────────────────────────────────────────────────────────────────────
%  1. Synthesises a realistic SBS-1 ADS-B text file with two simulated
%     aircraft flying through the Newton MA bistatic coverage zone.
%  2. Runs every step of the truth pipeline:
%       loadADSBTruth  →  adsbToBistatic  →  alignTruthToRadar
%       →  assessTruthVsDetections  →  plotTruthComparison
%  3. Synthesises fake CFAR detections (with noise) so
%     assessTruthVsDetections can demonstrate TP/FA/miss logic.
%  4. Shows the R_excess(t) truth comparison figure.
%
% REQUIREMENTS
%  • MATLAB R2023a+
%  • Mapping Toolbox  (geodetic2enu, wgs84Ellipsoid)
%  • All six new functions on your MATLAB path:
%      loadADSBTruth, getRadarEpoch, adsbToBistatic,
%      alignTruthToRadar, assessTruthVsDetections, plotTruthComparison
%
% HOW TO RUN
%  >> cd('<repo>/flightTest/BistaticDataAnalysis')
%  >> test_adsbTruthPipeline
%
% NOTE ON "ADDING TO THE §1 CONFIG BLOCK"
%  When you eventually run with real ADS-B data, open analyzeBistaticData.m
%  and scroll to §1 (the config block near the top, around line 95).
%  After the existing config lines add:
%
%    config.adsb_files = { '/path/to/adsb_20260705_142500.txt.gz' };
%    config.radar_epoch_utc = datetime(2026,7,5,14,25,0,'TimeZone','UTC');
%
%  Then re-run analyzeBistaticData.m — §8 will execute automatically.
%  This test script exercises exactly that §8 logic in isolation.
%
% See also: loadADSBTruth, adsbToBistatic, alignTruthToRadar,
%           assessTruthVsDetections, plotTruthComparison.

clear; close all;
orig_fig_vis = get(groot, 'DefaultFigureVisible');
cleanup_fig_vis = onCleanup(@() set(groot, 'DefaultFigureVisible', orig_fig_vis));
set(groot, 'DefaultFigureVisible', 'off');
fprintf('══════════════════════════════════════════════════════════════\n');
fprintf('  ADS-B Truth Pipeline  —  Synthetic Test\n');
fprintf('══════════════════════════════════════════════════════════════\n\n');

% =========================================================================
%  §0  Site geometry  (Newton MA deployment, same as analyzeBistaticData)
% =========================================================================
txLLA = [42.310278,  -71.236667, 431.9];   % WNAC-DT Needham Heights MA
rxLLA = [42.2999333, -71.349333,  15.0];   % Garage rooftop Newton MA
fc    = 600e6;                              % 600 MHz ATSC

% "Recording" starts at this UTC epoch (pretend Part 1 began here)
radar_epoch_utc = datetime(2026, 7, 5, 14, 25, 0, 'TimeZone', 'UTC');
t_epoch_unix    = posixtime(radar_epoch_utc);

% Radar time axis: 3 parts × 1 s each, 10 s inter-part gap → 0–22 s
fs          = 5e6;
part_dur_s  = 1.0;
gap_s       = 10.0;
N_parts_sim = 3;
t_abs_query = [];
for ip = 1 : N_parts_sim
    t0 = (ip-1) * (part_dur_s + gap_s);
    % One query point per 0.5 s within each part
    t_abs_query = [t_abs_query; (t0 : 0.5 : t0 + part_dur_s - 0.5)']; %#ok<AGROW>
end

% =========================================================================
%  §1  Synthesise SBS-1 ADS-B records for two aircraft
% =========================================================================
% Aircraft 1 — UAL123  — flying east  (approaching then receding)
% Aircraft 2 — DAL456  — flying north (constant positive Doppler)
%
% We generate positions every 2 s starting 5 s before the radar epoch,
% so there is overlap with all three recording parts.

fprintf('[§1] Synthesising two aircraft trajectories…\n');

% Midpoint between Tx and Rx — aircraft start near here
scene_lat = (txLLA(1) + rxLLA(1)) / 2;
scene_lon = (txLLA(2) + rxLLA(2)) / 2;

% --- Aircraft 1: UAL123, cruising eastbound at 250 m/s, alt 3500 m ------
hex1 = 'A1B2C3';
cs1  = 'UAL123';
alt1_ft = 11500;   % ≈ 3500 m
spd1_kts = 486;    % ≈ 250 m/s ground speed
trk1_deg = 90;     % due east

t_wall1 = t_epoch_unix + (-5 : 2 : 27)';   % -5 s to +27 s at 2-s intervals
n1      = numel(t_wall1);
% Start 0.5° west of scene centre, move east at 250 m/s ≈ 0.0023°/s longitude
lat1    = scene_lat + 0.05 + zeros(n1, 1);          % slightly north of midpoint
lon1    = scene_lon - 0.01 + 0.0023 * (0:n1-1)';   % drifting east

% --- Aircraft 2: DAL456, climbing northbound at 180 m/s, alt 2800 m ----
hex2 = 'D4E5F6';
cs2  = 'DAL456';
alt2_ft = 9200;    % ≈ 2800 m
spd2_kts = 350;    % ≈ 180 m/s
trk2_deg = 15;     % NNE

t_wall2 = t_epoch_unix + (-3 : 2 : 25)';
n2      = numel(t_wall2);
lat2    = scene_lat - 0.03 + 0.0016 * (0:n2-1)';   % moving north
lon2    = scene_lon + 0.02 + 0.0004 * (0:n2-1)';   % slight east drift

% --- Write synthetic SBS-1 file to a temp directory ---------------------
tmp_dir  = tempname;
mkdir(tmp_dir);
adsb_file = fullfile(tmp_dir, 'adsb_synthetic_test.txt');

fid = fopen(adsb_file, 'w');
if fid < 0
    error('test_adsbTruthPipeline:fileOpen', 'Cannot open temp file: %s', adsb_file);
end

% Helper: produce SBS-1 date/time strings from a Unix epoch scalar.
%  We use year/month/day/hour/minute/second on a timezone-aware datetime
%  and format with sprintf — this avoids ALL datestr / char(datetime)
%  ambiguity and works identically across every MATLAB version and locale.
get_utc = @(t) datetime(t, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
dt_fmt  = @(t) sprintf('%04d/%02d/%02d', ...
    year(get_utc(t)), month(get_utc(t)), day(get_utc(t)));
tm_fmt  = @(t) sprintf('%02d:%02d:%06.3f', ...
    hour(get_utc(t)), minute(get_utc(t)), second(get_utc(t)));
% e.g. dt_fmt(t) -> '2026/07/05',  tm_fmt(t) -> '14:25:11.000'

% Aircraft 1: callsign MSG,1  (one at start)
fprintf(fid, 'MSG,1,1,1,%s,1,%s,%s,%s,%s,%s,,,,,,,,,,\n', ...
    hex1, dt_fmt(t_wall1(1)), tm_fmt(t_wall1(1)), ...
          dt_fmt(t_wall1(1)), tm_fmt(t_wall1(1)), cs1);

% Aircraft 2: callsign MSG,1
fprintf(fid, 'MSG,1,1,1,%s,1,%s,%s,%s,%s,%s,,,,,,,,,,\n', ...
    hex2, dt_fmt(t_wall2(1)), tm_fmt(t_wall2(1)), ...
          dt_fmt(t_wall2(1)), tm_fmt(t_wall2(1)), cs2);

% Aircraft 1: position and velocity records
for i = 1 : n1
    % MSG,3 — position
    fprintf(fid, 'MSG,3,1,1,%s,1,%s,%s,%s,%s,,%d,,,%s,%s,,,,0\n', ...
        hex1, dt_fmt(t_wall1(i)), tm_fmt(t_wall1(i)), ...
              dt_fmt(t_wall1(i)), tm_fmt(t_wall1(i)), ...
        alt1_ft, ...
        sprintf('%.6f', lat1(i)), sprintf('%.6f', lon1(i)));
    % MSG,4 — velocity (even indices only, simulates ~4 s update rate)
    if mod(i,2) == 0
        fprintf(fid, 'MSG,4,1,1,%s,1,%s,%s,%s,%s,,,%d,%d,,0,,0\n', ...
            hex1, dt_fmt(t_wall1(i)), tm_fmt(t_wall1(i)), ...
                  dt_fmt(t_wall1(i)), tm_fmt(t_wall1(i)), ...
            spd1_kts, trk1_deg);
    end
end

% Aircraft 2: position and velocity records
for i = 1 : n2
    fprintf(fid, 'MSG,3,1,1,%s,1,%s,%s,%s,%s,,%d,,,%s,%s,,,,0\n', ...
        hex2, dt_fmt(t_wall2(i)), tm_fmt(t_wall2(i)), ...
              dt_fmt(t_wall2(i)), tm_fmt(t_wall2(i)), ...
        alt2_ft, ...
        sprintf('%.6f', lat2(i)), sprintf('%.6f', lon2(i)));
    if mod(i,2) == 0
        fprintf(fid, 'MSG,4,1,1,%s,1,%s,%s,%s,%s,,,%d,%d,,0,,0\n', ...
            hex2, dt_fmt(t_wall2(i)), tm_fmt(t_wall2(i)), ...
                  dt_fmt(t_wall2(i)), tm_fmt(t_wall2(i)), ...
            spd2_kts, trk2_deg);
    end
end

fclose(fid);
fprintf('  Synthetic SBS-1 file: %s\n', adsb_file);
fprintf('  Aircraft 1 (%s): %d position fixes, eastbound\n', hex1, n1);
fprintf('  Aircraft 2 (%s): %d position fixes, northbound\n', hex2, n2);

% Show first two lines so format can be verified at a glance:
fid2 = fopen(adsb_file, 'r');
fprintf('  First 2 lines of synthetic file:\n');
for ii = 1:2
    ln = fgetl(fid2);
    if ischar(ln), fprintf('    %s\n', ln); end
end
fclose(fid2);
fprintf('\n');

% =========================================================================
%  §2  Run loadADSBTruth
% =========================================================================
% Quick inline verify: confirm that the format produced by dt_fmt/tm_fmt
% is parseable by the same datetime() call used inside loadADSBTruth.
sample_dt_str = [dt_fmt(t_wall1(1)), ' ', tm_fmt(t_wall1(1))];
fprintf('[S2] Verifying timestamp format: "%s"\n', sample_dt_str);
try
    test_parse = datetime(sample_dt_str, ...
        'InputFormat', 'yyyy/MM/dd HH:mm:ss.SSS', 'TimeZone', 'UTC');
    fprintf('     Parse OK -> %s UTC\n', string(test_parse, 'yyyy-MM-dd HH:mm:ss'));
catch ME
    error('test_adsbTruthPipeline:badFormat', ...
        'datetime parse failed on "%s":\n  %s\n', sample_dt_str, ME.message);
end

fprintf('[S2] loadADSBTruth\n');
adsb_tracks = loadADSBTruth({adsb_file}, 'Verbose', false);

if isempty(adsb_tracks)
    error('test_adsbTruthPipeline:noTracks', ...
        'loadADSBTruth returned 0 aircraft. Check the file format printed above.');
end
assert(numel(adsb_tracks) == 2, 'Expected two synthetic aircraft tracks.');

fprintf('  Loaded %d aircraft:\n', numel(adsb_tracks));
for k = 1 : numel(adsb_tracks)
    fprintf('    [%d] %s (%s)  %d fixes  alt %.0f–%.0f m\n', k, ...
        adsb_tracks(k).hex, adsb_tracks(k).callsign, ...
        numel(adsb_tracks(k).t_utc), ...
        min(adsb_tracks(k).alt_m), max(adsb_tracks(k).alt_m));
end
fprintf('\n');

% =========================================================================
%  §3  getRadarEpoch — using ManualEpoch (mimics the Newton use case)
% =========================================================================
fprintf('[§3] getRadarEpoch\n');
% In a real run you would pass an actual Part-1 file path.  Here we use a
% placeholder path to demonstrate the M_D_YYYY fallback, then override it
% with ManualEpoch so the test is deterministic.
fake_part1_path = 'n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part1';
t_epoch = getRadarEpoch(fake_part1_path, ...
    'ManualEpoch', radar_epoch_utc);

% =========================================================================
%  §4  adsbToBistatic
% =========================================================================
fprintf('[§4] adsbToBistatic\n');
adsb_bistatic = adsbToBistatic(adsb_tracks, txLLA, rxLLA, fc);
assert(numel(adsb_bistatic) == numel(adsb_tracks));

for k = 1 : numel(adsb_bistatic)
    ac = adsb_bistatic(k);
    if numel(ac.t_utc) < 3
        continue
    end
    dRdt_ctr = (ac.R_excess_m(3:end) - ac.R_excess_m(1:end-2)) ./ ...
               (ac.t_utc(3:end)      - ac.t_utc(1:end-2));
    fd_ctr   = ac.f_D_hz(2:end-1);
    valid_fd = abs(dRdt_ctr) > 1e-6 & abs(fd_ctr) > 1e-6;
    assert(all(sign(fd_ctr(valid_fd)) == -sign(dRdt_ctr(valid_fd))), ...
        'ADS-B bistatic Doppler sign should oppose dR/dt.');
end

% =========================================================================
%  §5  alignTruthToRadar
% =========================================================================
fprintf('[§5] alignTruthToRadar\n');
adsb_aligned = alignTruthToRadar(adsb_bistatic, t_epoch, t_abs_query);

% =========================================================================
%  §6  Synthesise fake CFAR detections (truth + noise) for metric demo
% =========================================================================
fprintf('[§6] Synthesising fake CFAR detections…\n');

c_light   = physconst('LightSpeed');
alpha     = 2 * fc / c_light;
range_cell_m  = c_light / (2 * fs);    % 30 m
doppler_bin_hz = 2.0;                  % 2 Hz bins (simplified)

rng(42);   % reproducible random numbers

fake_dets = struct('t_abs_s', {}, 'R_excess_m', {}, 'f_D_hz', {});
for q = 1 : numel(t_abs_query)
    for k = 1 : numel(adsb_aligned)
        R_t = adsb_aligned(k).R_excess_m(q);
        f_t = adsb_aligned(k).f_D_hz(q);
        if isnan(R_t) || isnan(f_t)
            continue
        end
        % 80% detection probability
        if rand > 0.80
            continue
        end
        % Add ±1 range cell / ±1 Doppler bin of noise
        d.t_abs_s    = t_abs_query(q);
        d.R_excess_m = R_t + (2*rand-1) * range_cell_m;
        d.f_D_hz     = f_t + (2*rand-1) * doppler_bin_hz;
        fake_dets(end+1) = d;
    end
    % 15% chance of a false alarm at a random range/Doppler
    if rand < 0.15
        d.t_abs_s    = t_abs_query(q);
        d.R_excess_m = 5e3 + rand * 50e3;
        d.f_D_hz     = (rand - 0.5) * 200;
        fake_dets(end+1) = d;
    end
end
fprintf('  %d fake detections generated (%d query points × aircraft).\n\n', ...
    numel(fake_dets), numel(t_abs_query));
assert(~isempty(fake_dets), 'Synthetic detections should not be empty.');

% =========================================================================
%  §6b  Synthesise tracker snapshots and convert to per-track histories
% =========================================================================
fprintf('[§6b] Synthesising tracker snapshots...\n');

valid_trk = ~isnan(adsb_aligned(1).R_excess_m) & ~isnan(adsb_aligned(1).f_D_hz);
t_trk     = adsb_aligned(1).t_abs_s(valid_trk);
R_trk     = adsb_aligned(1).R_excess_m(valid_trk);
f_trk     = adsb_aligned(1).f_D_hz(valid_trk);
trk_snapshots = repmat(struct('time', 0, 'tracks', struct([]), 'n_confirmed', 0), ...
    1, numel(t_trk));

for ii = 1 : numel(t_trk)
    trk_struct = struct( ...
        'TrackID',         101, ...
        'State',           [R_trk(ii) + 0.2 * range_cell_m * sin(ii / 2); ...
                            -(f_trk(ii) + 0.2 * doppler_bin_hz * cos(ii / 3)) / alpha], ...
        'StateCovariance', diag([range_cell_m^2, (doppler_bin_hz / alpha)^2]));
    trk_snapshots(ii).time        = t_trk(ii);
    trk_snapshots(ii).tracks      = trk_struct;
    trk_snapshots(ii).n_confirmed = 1;
end

track_histories = helperTracksLogToHistories(trk_snapshots, fc);
assert(isscalar(track_histories), 'Expected one synthetic track history.');
assert(all(isfinite(track_histories(1).t_abs_s)));
assert(all(isfinite(track_histories(1).R_excess_m)));
assert(all(isfinite(track_histories(1).f_D_hz)));
assert(all(diff(track_histories(1).t_abs_s) > 0));

% =========================================================================
%  §7  assessTruthVsDetections
% =========================================================================
fprintf('[§7] assessTruthVsDetections\n');
metrics = assessTruthVsDetections( ...
    fake_dets, track_histories, adsb_aligned, ...
    'RangeCellM',      range_cell_m,   ...
    'DopplerBinHz',    doppler_bin_hz, ...
    'GateRangeCells',  3,              ...
    'GateDopplerBins', 3,              ...
    'Verbose',         true);
assert(metrics.n_tp > 0, 'Synthetic truth comparison should yield true positives.');
assert(~isempty(metrics.trk_table), 'Track metrics table should not be empty.');
assert(any(isfinite(metrics.trk_table.range_rmse_m)), ...
    'At least one track should produce finite range metrics.');

% =========================================================================
%  §8  plotTruthComparison
% =========================================================================
fprintf('[§8] plotTruthComparison\n');
plotTruthComparison(adsb_aligned, track_histories, metrics, ...
    'FigureTitle', 'Synthetic Test — Newton MA geometry');

% =========================================================================
%  §8b  Standalone diagnostic bundle + snapshot rerun
% =========================================================================
fprintf('[§8b] Standalone detection-truth diagnostic unit\n');

part_start_offsets_diag = ((0 : N_parts_sim - 1).' * (part_dur_s + gap_s));
part_end_offsets_diag = part_start_offsets_diag + part_dur_s;
data_parts_diag = arrayfun(@(k) sprintf('synthetic_part%d_20260705142500.bb', k), ...
    1 : N_parts_sim, 'UniformOutput', false);

all_track_dets_diag = zeros(numel(fake_dets), 6);
for k = 1 : numel(fake_dets)
    t_det = fake_dets(k).t_abs_s;
    ip = find((t_det >= part_start_offsets_diag) & (t_det < part_end_offsets_diag), 1, 'last');
    if isempty(ip) && abs(t_det - part_end_offsets_diag(end)) < 1e-9
        ip = N_parts_sim;
    end
    if isempty(ip)
        error('test_adsbTruthPipeline:badSyntheticDetectionTime', ...
            'Synthetic detection time %.3f s is outside the part windows.', t_det);
    end

    all_track_dets_diag(k, :) = [ ...
        fake_dets(k).R_excess_m, ...
        fake_dets(k).f_D_hz, ...
        18, ...
        k, ...
        fake_dets(k).t_abs_s, ...
        ip];
end

range_axis_diag = linspace(0, 120e3, 220).';
doppler_axis_diag = linspace(-180, 180, 121);
part_results_diag = repmat(struct( ...
    'detections', zeros(0, 5), ...
    'cfar_nf_db', -8, ...
    'rdm_before', zeros(0, 0), ...
    'rdm_after', zeros(0, 0), ...
    'range_axis', range_axis_diag, ...
    'doppler_axis', doppler_axis_diag), 1, N_parts_sim);

for ip = 1 : N_parts_sim
    part_mask = all_track_dets_diag(:, 6) == ip;
    dets_ip = all_track_dets_diag(part_mask, 1:5);

    rdm_after_diag = -8 + 0.3 * randn(numel(range_axis_diag), numel(doppler_axis_diag));
    for jd = 1 : size(dets_ip, 1)
        [~, r_idx] = min(abs(range_axis_diag - dets_ip(jd, 1)));
        [~, d_idx] = min(abs(doppler_axis_diag - dets_ip(jd, 2)));
        r_lo = max(1, r_idx - 1);
        r_hi = min(numel(range_axis_diag), r_idx + 1);
        d_lo = max(1, d_idx - 1);
        d_hi = min(numel(doppler_axis_diag), d_idx + 1);
        rdm_after_diag(r_lo:r_hi, d_lo:d_hi) = 16;
    end

    part_results_diag(ip).detections = dets_ip;
    part_results_diag(ip).rdm_before = rdm_after_diag;
    part_results_diag(ip).rdm_after = rdm_after_diag;
end

config_diag = struct( ...
    'fc', fc, ...
    'fs', fs, ...
    'N_slow_cpi', 200, ...
    'cpi_duration_s', 0.5e-3, ...
    'max_nci_looks', 5, ...
    'txLLA', txLLA, ...
    'rxLLA', rxLLA, ...
    'max_display_range_m', 120e3, ...
    'adsb_files', {{adsb_file}}, ...
    'radar_epoch_utc', radar_epoch_utc, ...
    'verbose', false);

truth_diag_input = buildDetectionTruthDiagnosticInput( ...
    config_diag, data_parts_diag, ...
    part_start_offsets_diag, part_end_offsets_diag, all_track_dets_diag, ...
    'TrackHistories', track_histories, ...
    'PartResults', part_results_diag, ...
    'PartDurationS', part_dur_s, ...
    'TruthQueryTimesS', t_abs_query, ...
    'SessionID', 'synthetic_truth_demo', ...
    'AnalysisLabel', 'Synthetic Truth Diagnostic Unit', ...
    'RDMDisplayCLim', [-10, 20], ...
    'Verbose', false);

truth_snapshot_compact = fullfile(tmp_dir, 'truth_diag_snapshot.mat');
truth_snapshot_full = fullfile(tmp_dir, 'truth_diag_snapshot_full.mat');

saveDetectionTruthDiagnosticInput(truth_diag_input, truth_snapshot_compact, ...
    'IncludeRDMParts', false, ...
    'Verbose', false);
saveDetectionTruthDiagnosticInput(truth_diag_input, truth_snapshot_full, ...
    'IncludeRDMParts', true, ...
    'Verbose', false);

compact_loaded = load(truth_snapshot_compact, 'truth_diag_input');
assert(~isfield(compact_loaded.truth_diag_input, 'rdm_parts'), ...
    'Compact snapshot should omit cached RDM parts.');

diag_output_compact = runDetectionTruthDiagnostics( ...
    truth_snapshot_compact, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true, ...
    'PlotTrackComparison', false, ...
    'Verbose', false);

assert(isempty(diag_output_compact.figure_handles.rdm_overlays), ...
    'Compact snapshot should skip standalone RDM overlay recreation.');

diag_output = runDetectionTruthDiagnostics( ...
    truth_snapshot_full, ...
    'PlotDetectionTimeSeries', true, ...
    'PlotRDMOverlays', true, ...
    'PlotTrackComparison', true, ...
    'TrackColors', [0.929, 0.165, 0.165; 0.216, 0.494, 0.722], ...
    'Verbose', false);

assert(~isempty(diag_output.adsb_aligned), ...
    'Standalone diagnostic unit should produce aligned truth.');
assert(diag_output.truth_metrics.n_tp > 0, ...
    'Standalone diagnostic unit should preserve the true-positive matches.');
assert(diag_output.check_summary.n_aircraft_overlap >= 1, ...
    'Standalone diagnostic unit should report overlapping truth aircraft.');

snapshot_info = helperSaveTruthDiagnosticSnapshots( ...
    truth_diag_input, tmp_dir, ...
    'SnapshotMode', 'both', ...
    'BaseName', 'auto_truth_diag', ...
    'Verbose', false);

assert(exist(snapshot_info.compact_path, 'file') == 2, ...
    'Session-style compact snapshot should be saved to disk.');
assert(exist(snapshot_info.full_path, 'file') == 2, ...
    'Session-style full snapshot should be saved to disk.');

% =========================================================================
%  §9  R_excess raw truth plot (sanity check)
% =========================================================================
fprintf('[§9] Raw bistatic R_excess truth plot\n');

fig2 = figure('Color', [0.1 0.1 0.1], 'Position', [100 540 900 380]);
ax2  = axes(fig2);
set(ax2, 'Color', [0.1 0.1 0.1], 'XColor', 'w', 'YColor', 'w', ...
    'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.5);
hold(ax2, 'on');
grid(ax2, 'on');
clrs = [0.929 0.165 0.165; 0.216 0.494 0.722];
for k = 1 : numel(adsb_bistatic)
    ac = adsb_bistatic(k);
    t_rel = ac.t_utc - t_epoch;
    plot(ax2, t_rel, ac.R_excess_m / 1e3, 'Color', clrs(k,:), 'LineWidth', 2);
    label = ac.callsign;
    if isempty(strtrim(label)), label = ac.hex; end
    text(ax2, t_rel(end), ac.R_excess_m(end)/1e3, sprintf(' %s', label), ...
        'Color', clrs(k,:), 'FontSize', 9);
end
% Mark the three radar recording windows
for ip = 1 : N_parts_sim
    t0 = (ip-1)*(part_dur_s+gap_s);
    patch(ax2, [t0 t0+part_dur_s t0+part_dur_s t0], [0 0 120 120], ...
        [0.3 0.3 0.3], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
end
xlabel(ax2, 't_{rel} to radar epoch  [s]', 'Color', 'w');
ylabel(ax2, 'R_{excess}  [km]',            'Color', 'w');
title(ax2, 'Bistatic truth tracks (grey shading = recording windows)', ...
    'Color', 'w', 'FontSize', 10);
ylim(ax2, [0, 120]);

% =========================================================================
%  §10  Cleanup
% =========================================================================
fprintf('\n══════════════════════════════════════════════════════════════\n');
fprintf('  Test complete.  Temp file: %s\n', adsb_file);
fprintf('  To clean up: rmdir(''%s'', ''s'')\n', tmp_dir);
fprintf('══════════════════════════════════════════════════════════════\n\n');
