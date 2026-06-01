function [tracks_log, tracker_obj] = trackTargets(all_track_dets, config)
%TRACKTARGETS  Associate passive-bistatic CFAR detections across time using
%  a Global Nearest-Neighbour tracker in the Range–Doppler measurement space.
%
%  Processes all block-level detections from all file parts sequentially,
%  calling trackerGNN once per unique block timestamp.  Returns a full log
%  of tracker state at each time step for downstream visualization.
%
% ── TRACKER CONFIGURATION ─────────────────────────────────────────────────
%   Filter   : trackingKF, state [R (m); Ṙ (m/s)], via initMeasurementSpaceKF
%              (fc and fs passed from config via closure — no hardcoded constants)
%   Gate     : AssignmentThreshold = 50  (Mahalanobis² normalized distance)
%   Confirm  : [2, 3] — require 2 detections in any 3-frame window.  Filters
%              isolated false-alarm detections that would otherwise flood the
%              track pool and prevent real-aircraft association.
%   Delete   : [5, 5] — track is dropped after 5 consecutive missed frames
%              (500 ms at 100 ms/step).  Provides enough tolerance to survive
%              the ~3 s inter-part gap (which counts as ONE missed step, not 30,
%              because trackerGNN only steps at detection timestamps).
%
% ── INTER-PART GAP HANDLING ──────────────────────────────────────────────
%   The t_abs_s values in all_track_dets must include the inter-part time
%   offset (set in analyzeBistaticData §2 using config.inter_part_gap_s).
%   trackerGNN passes the elapsed time to predict(filter, dt); the
%   trackingKF 'constvel' model then correctly expands F(dt) and Q(dt),
%   opening the assignment gate appropriately for both the 100 ms
%   within-part intervals and the ~10 s cross-part gaps.
%
%   NOTE (future datasets): replace the hardcoded config.inter_part_gap_s
%   with per-recording start timestamps read from file metadata or a
%   companion log file.
%
% ── INPUTS ────────────────────────────────────────────────────────────────
%   all_track_dets  [N × 6] double — consolidated detection matrix from
%                   analyzeBistaticData §3.  Columns:
%                     1  range_m    bistatic range excess [m]
%                     2  dopp_hz    Doppler frequency [Hz]
%                     3  pwr_db     detection power [dB]
%                     4  blk        sub-CPI block index within the file part
%                     5  t_abs_s    absolute timestamp [s], inter-part gap included
%                     6  i_part     file-part number (1, 2, 3, …)
%
%   config          struct — relevant fields:
%                     .fc    carrier frequency [Hz]  (used to print Doppler coupling)
%                     .verbose  logical
%
% ── OUTPUTS ──────────────────────────────────────────────────────────────
%   tracks_log  struct array [1 × N_timesteps], one entry per unique t_abs_s:
%                 .time         absolute timestamp [s]
%                 .tracks       objectTrack array from trackerGNN (may be empty)
%                 .n_confirmed  number of confirmed tracks at this step
%
%   tracker_obj  trackerGNN — tracker after full processing; inspect via
%                tracker_obj.NumTracks, tracker_obj.NumConfirmedTracks
%
% ── TOOLBOX ──────────────────────────────────────────────────────────────
%   Sensor Fusion and Tracking Toolbox (trackerGNN, objectDetection, objectTrack)

% ── Build trackerGNN ──────────────────────────────────────────────────────
% ── Closure so initMeasurementSpaceKF gets the correct fc and fs ────────────
init_fcn = @(det) initMeasurementSpaceKF(det, config.fc, config.fs);

c_light     = physconst('LightSpeed');
range_bin_m = c_light / (2 * config.fs);  % range bin [m] — from config
dopp_bin_hz = 10;                          % Doppler bin [Hz] (fixed by N_slow/PRF)
% R_meas must match the variance used inside initMeasurementSpaceKF.
% 3-bin range / 2-bin Doppler: see initMeasurementSpaceKF for rationale.
R_meas      = diag([(3 * range_bin_m)^2, (2 * dopp_bin_hz)^2]);

% ── Tracker thresholds ────────────────────────────────────────────────────
%   ConfirmationThreshold [M, N]: confirm after M detections in N frames.
%     [2, 3] rejects isolated false-alarm detections while still confirming
%     a real aircraft that has ≥ 2 detections in any 3-step window.
%   DeletionThreshold [M, N]: delete after M consecutive misses in N frames.
%     [5, 5] gives a track 500 ms (5 × 100 ms) of tolerance before dropping;
%     important since aircraft can be missed during transient fades or at the
%     part boundary where prediction uncertainty is briefly wider.
tracker_obj = trackerGNN( ...
    'FilterInitializationFcn', init_fcn, ...
    'AssignmentThreshold',     50,      ...  % Mahalanobis² gate
    'ConfirmationThreshold',   [2, 3],  ...  % require 2 of 3 frames to confirm
    'DeletionThreshold',       [5, 5]); %    % drop after 5 consecutive misses

% ── Sort by timestamp and find unique update steps ────────────────────────
[t_steps, ~, ~] = unique(all_track_dets(:, 5), 'sorted');   % [N_steps × 1]
N_steps         = numel(t_steps);

% Pre-allocate log
tracks_log = repmat( ...
    struct('time', 0, 'tracks', objectTrack.empty, 'n_confirmed', 0), ...
    1, N_steps);

alpha = 2 * config.fc / c_light;   % Doppler coupling [Hz/(m/s)]

fprintf('[trackTargets] %d detections  |  %d time steps  |  %d parts\n', ...
    size(all_track_dets, 1), N_steps, numel(unique(all_track_dets(:, 6))));
fprintf('[trackTargets] Confirm=[2,3]  Assign=50  Delete=[5,5]  alpha=%.2f Hz/(m/s)  range_bin=%.1f m\n\n', ...
    alpha, range_bin_m);

% ── Sequential tracker update loop ───────────────────────────────────────
for k = 1 : N_steps
    t_k    = t_steps(k);
    mask_k = (all_track_dets(:, 5) == t_k);
    dets_k = all_track_dets(mask_k, :);   % [n_k × 6] detections at this step

    % Wrap each detection as an objectDetection.
    %   Measurement = [range_m; dopp_hz] — the 2-element vector expected by
    %   initMeasurementSpaceKF via H = [1 0; 0 alpha].
    n_k      = size(dets_k, 1);
    det_cell = cell(1, n_k);
    for j = 1 : n_k
        det_cell{j} = objectDetection(t_k, ...
            [dets_k(j, 1); dets_k(j, 2)], ...   % [range_m; dopp_hz]
            'MeasurementNoise', R_meas);
    end

    % Update the tracker.  trackerGNN internally:
    %   1. Calls predict(filter, dt) for each existing track — F(dt) and
    %      Q(dt) are updated automatically by the 'constvel' MotionModel.
    %   2. Runs GNN assignment of detections to predicted tracks.
    %   3. Calls correct(filter, z) for each assigned detection.
    %   4. Creates new tentative tracks for unassigned detections.
    %   5. Confirms/deletes tracks based on threshold criteria.
    tracks_k = tracker_obj(det_cell, t_k);

    % Log
    tracks_log(k).time        = t_k;
    tracks_log(k).tracks      = tracks_k;
    tracks_log(k).n_confirmed = tracker_obj.NumConfirmedTracks;

    if config.verbose
        fprintf('  t=%7.3f s  |  %2d det  →  %2d confirmed  |  %2d total\n', ...
            t_k, n_k, tracker_obj.NumConfirmedTracks, tracker_obj.NumTracks);
    end
end

fprintf('[trackTargets] Done — peak confirmed tracks: %d\n\n', ...
    max([tracks_log.n_confirmed]));

end
