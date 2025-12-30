%% ========================================================================
%  PASSIVE RADAR SYSTEM CHARACTERIZATION AND DETECTION SCRIPT
%  Purpose: Evaluate system performance, generate detection thresholds,
%           and localize aircraft targets
%% ========================================================================

%% CONFIGURATION: Data Files and System Parameters
% -------------------------------------------------------------------------
dual_channel_file = 'n320_dual_capture.bb';  % Main dataset for detection
Fs = 6.144e6;                                 % Sample rate (Hz)
Tint = 0.1;                                   % Coherent integration time (100ms)
pfa = 1e-6;                                   % Probability of false alarm

% Transmitter and Receiver GPS Coordinates
tx_gps = [42.311389, -71.216111];  % ATSC TV Tower
rx_gps = [42.3007, -71.3490];      % Apple Hill Campus Receiver

%% STEP 1: SIGNAL QUALITY ASSESSMENT
% -------------------------------------------------------------------------
% PURPOSE: Validate baseband data integrity, measure SNR, detect DC offset,
%          and verify signal centering before processing
% OUTPUT: Clean, centered IQ data; PSD and spectrogram plots
% -------------------------------------------------------------------------
fprintf('\n=== STEP 1: Signal Quality Assessment ===\n');
[x, Fs_measured] = assess_bb_quality(dual_channel_file, 'cf', 540e6, 'bw', 6e6);

% Use a short slice for subsequent single-channel analysis (saves memory/time)
slice_len = round(0.020 * Fs);  % 20ms slice
x_slice = x(1:min(slice_len, length(x)));

%% STEP 2: SYSTEM RESOLUTION CALCULATION
% -------------------------------------------------------------------------
% PURPOSE: Calculate the fundamental resolution limits of the radar system
% OUTPUT: Range resolution (meters) and velocity resolution (m/s)
%         These define the "bin size" for delay-Doppler maps
% -------------------------------------------------------------------------
fprintf('\n=== STEP 2: System Resolution Calculation ===\n');
res = calc_system_resolution(Fs, 6e6, Tint, 540e6);
range_res = res.range_res_m;
vel_res = res.velocity_res_mps;

%% STEP 3: DUAL-CHANNEL COHERENCE VERIFICATION
% -------------------------------------------------------------------------
% PURPOSE: Verify phase synchronization between surveillance and reference
%          channels. Essential for bistatic radar operation.
% OUTPUT: Cross-correlation plot; Peak-to-Sidelobe Ratio (must be >15 dB)
% PLOT: Correlation vs time delay showing direct path peak
% -------------------------------------------------------------------------
fprintf('\n=== STEP 3: Dual-Channel Coherence Check ===\n');
check_dual_channel_coherence(dual_channel_file, Fs);

%% STEP 4A: SELF-AMBIGUITY FUNCTION (SAF) - CLUTTER CHARACTERIZATION
% -------------------------------------------------------------------------
% PURPOSE: Characterize the clutter profile of the surveillance channel alone.
%          This is the "signature" of static objects in the environment.
% OUTPUT: 2D map of signal autocorrelation (delay vs Doppler)
% PLOT: Clutter map showing stationary targets at 0 Hz Doppler
% NOTE: This uses SINGLE-CHANNEL data (surveillance only) - different from CAF
% -------------------------------------------------------------------------
fprintf('\n=== STEP 4A: Self-Ambiguity Function (Clutter Profile) ===\n');
[ambg_saf, delays_saf, doppler_saf] = calculate_saf(x_slice, Fs, 0.2, 500);
fprintf('SAF complete. This shows clutter from surveillance channel autocorrelation.\n');

%% STEP 4B: CROSS-AMBIGUITY FUNCTION (CAF) - TARGET DETECTION
% -------------------------------------------------------------------------
% PURPOSE: Compute bistatic delay-Doppler map by correlating surveillance 
%          and reference channels. This is where MOVING targets appear.
% OUTPUT: 2D CAF map with CFAR detection applied
% PLOT: Detection map with threshold applied (targets above noise floor)
% NOTE: This uses DUAL-CHANNEL cross-correlation - produces actual detections
% -------------------------------------------------------------------------
fprintf('\n=== STEP 4B: Cross-Ambiguity Function with CFAR Detection ===\n');
[map_caf, dets_raw] = compute_radar_caf_thresholded(dual_channel_file, Fs);
fprintf('CAF complete with CFAR detection. Raw detections: %d\n', height(dets_raw));

%% STEP 5: STATISTICAL THRESHOLD CALCULATION
% -------------------------------------------------------------------------
% PURPOSE: Calculate detection threshold based on noise statistics and 
%          desired false alarm rate (Pfa = 1e-6)
% OUTPUT: Threshold in dB above noise floor; Peak-to-Noise Ratio (PNR)
% -------------------------------------------------------------------------
fprintf('\n=== STEP 5: Detection Threshold Calculation ===\n');
[thresholddB, current_pnr] = calc_detection_threshold(map_caf, pfa);

%% STEP 5B: INTERPOLATION SENSITIVITY IMPROVEMENT (DEMONSTRATION)
% -------------------------------------------------------------------------
% PURPOSE: Demonstrate how spline interpolation improves detection sensitivity
%          by refining peak locations to sub-sample accuracy.
% OUTPUT: CAF map with interpolated peaks; detection comparison
% PLOT: Side-by-side or overlay showing detection improvement
% NOTE: This is a DEMONSTRATION of the technique. The final production
%       detections in Step 6 already include this interpolation internally
%       (see compute_radar_caf_localized_TbxFns.m lines 65-67).
%       This step helps visualize WHY interpolation matters.
% -------------------------------------------------------------------------
fprintf('\n=== STEP 5B: Interpolation Improvement Demonstration ===\n');
[map_interp, dets_interp] = compute_radar_caf_interpolated(dual_channel_file, Fs);
fprintf('Detections without interpolation: %d\n', height(dets_raw));
fprintf('Detections with interpolation:    %d\n', height(dets_interp));
fprintf('Improvement: Interpolation refines peak locations to sub-sample accuracy.\n');

%% STEP 6: AIRCRAFT LOCALIZATION WITH GEOGRAPHIC OVERLAY (FINAL DETECTION)
% -------------------------------------------------------------------------
% PURPOSE: Convert delay-Doppler detections to geographic coordinates and
%          plot bistatic ellipses on map. This is the PRODUCTION detection
%          output with guard zones applied to reject clutter.
% OUTPUT: Detection table with [Delay, Doppler, TotalPath]; Geographic map
% PLOT: Map showing TX/RX locations, bistatic ellipses for each detection
% NOTE: This internally uses spline interpolation (demonstrated in Step 5B)
%       for maximum sensitivity and sub-sample accuracy.
%       Previous steps (4A, 4B, 5B) were for characterization/demonstration.
% -------------------------------------------------------------------------
fprintf('\n=== STEP 6: Geographic Localization (Production Detections) ===\n');
[detections, hFig] = compute_radar_caf_localized_TbxFns(dual_channel_file, Fs, tx_gps, rx_gps);
fprintf('Final detections with geographic coordinates: %d targets\n', height(detections));

%% STEP 7: LINK BUDGET AND COVERAGE ANALYSIS
% -------------------------------------------------------------------------
% PURPOSE: Calculate maximum detection range based on measured noise floor,
%          reference signal power, and target radar cross-section (RCS)
% OUTPUT: Maximum detection range in kilometers
% ASSUMPTION: Target RCS = 1.0 m² (small aircraft / Cessna)
% -------------------------------------------------------------------------
fprintf('\n=== STEP 7: Coverage and Link Budget ===\n');
ref_pwr = mean(abs(x_slice).^2);  % Reference power from direct path
target_rcs = 1.0;                  % Small aircraft RCS (m²)
max_dist_km = calc_coverage_map(ref_pwr, thresholddB, tx_gps, rx_gps, target_rcs);

%% STEP 8: THEORETICAL LOCALIZATION ACCURACY
% -------------------------------------------------------------------------
% PURPOSE: Predict range and velocity measurement uncertainty based on SNR,
%          bandwidth, and integration time
% OUTPUT: Expected errors in range (meters) and velocity (m/s) for 20 dB SNR
% -------------------------------------------------------------------------
fprintf('\n=== STEP 8: Theoretical Accuracy Limits ===\n');
target_snr = 20;  % Strong target reference (dB)
accuracy = calc_theoretical_accuracy(Fs, 6e6, Tint, 540e6, target_snr);
fprintf('Range Uncertainty:     ±%.2f meters\n', accuracy.range_error_m);
fprSTEP 10: MISSION SUMMARY REPORT
% -------------------------------------------------------------------------
% PURPOSE: Consolidate all performance metrics into a single summary table
% OUTPUT: Structured table with all key system parameters
% SAVED: MissionReport_LoganCorridor.mat
% -------------------------------------------------------------------------
fprintf('\n=== STEP 10: Generating Mission Summary Report ===\n');

MetricNames = { ...
    'Range Resolution (Bin Size)'; ...
    'Velocity Resolution'; ...
    'Detection Threshold (above noise)'; ...
    'Max Coverage (1.0m^2 target)'; ...
    'Range Accuracy (at 20dB SNR)'; ...
    'Velocity Accuracy (at 20dB SNR)'; ...
    'Suppression Depth (Dynamic Range)' ...
};

Values = [ ...
    res.range_res_m; ...
    res.velocity_res_mps; ...
    thresholddB; ...
    max_dist_km; ...
    accuracy.range_error_m; ...
    accuracy.vel_error_mps; ...
    suppression.dynamic_range ...
];

Units = {'meters'; 'm/s'; 'dB'; 'km'; 'meters'; 'm/s'; 'dB'};

RadarReport = table(MetricNames, Values, Units);
fprintf('\n========================================================\n');
fprintf('        PASSIVE RADAR MISSION SUMMARY REPORT            \n');
fprintf('========================================================\n');
disp(RadarReport);

% Save report to disk
save('MissionReport_LoganCorridor.mat', 'RadarReport');
fprintf('Report saved to: MissionReport_LoganCorridor.mat\n');
% writetable(RadarReport, 'MissionReport.csv'); % Uncomment to save as CSV

%% STEP 11: GEOGRAPHIC COVERAGE VISUALIZATION
% -------------------------------------------------------------------------
% PURPOSE: Plot system coverage area on geographic map with TX/RX locations
% OUTPUT: Interactive map showing 62km detection radius
% PLOT: Geographic map with coverage circle, hardware locations, and basemap
% REQUIRES: Mapping Toolbox
% -------------------------------------------------------------------------
fprintf('\n=== STEP 11: Plotting Geographic Coverage Map ===\n');

%(RadarReport);

% Optional: Save to disk for your records
save('MissionReport_LoganCorridor.mat', 'RadarReport');
% writetable(RadarReport, 'MissionReport.csv'); % Uncomment to save as CSV


%% Plot Radar Coverage on Geographic Map
% Requires: Mapping Toolbox



% 2. Initialize Geographic Figure
% Initialize Geographic Figure
figure('Name', 'Passive Radar Coverage Map', 'Color', 'w');
gx = geoaxes;
hold(gx, 'on');

% Plot the Receiver and Transmitter
geoplot(gx, rx_gps(1), rx_gps(2), '^r', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'RX: Apple Hill');
geoplot(gx, tx_gps(1), tx_gps(2), 'bd', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'TX: TV Tower');

% Generate and Plot the Coverage Circle
[lat_c, lon_c] = scircle1(rx_gps(1), rx_gps(2), km2deg(max_dist_km));
geoplot(gx, lat_c, lon_c, 'g--', 'LineWidth', 2, 'DisplayName', sprintf('%.0f km Detection Range', max_dist_km));

% Format the Map
geobasemap(gx, 'streets-light'); % Options: 'topographic', 'satellite', 'streets'
title(sprintf('Radar Coverage Area (RCS = %.1f m^2)\nMax Range: %.1f km', target_rcs, max_dist_km));
legend('Location', 'northeastoutside');
geolimits(gx, [41.8, 42.8], [-72.5, -70.5]); % Center view on Eastern MA
grid on;

fprintf('\n=== SCRIPT COMPLETE ===\n');
fprintf('Review the following outputs:\n');
fprintf('  1. Signal quality plots (PSD, spectrogram)\n');
fprintf('  2. Coherence verification plot\n');
fprintf('  3. Self-Ambiguity Function (clutter map)\n');
fprintf('  4. Interpolation improvement demonstration\n');
fprintf('  6. Geographic localization map with detections\n');
fprintf('  7. Coverage map\n');
fprintf('  8. Coverage map\n');
fprintf('  7. Mission summary report table\n');