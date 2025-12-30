function [caf_map, detections] = compute_radar_caf_localized(fname, Fs, tx_gps, rx_gps)
% compute_radar_caf_localized: Adds physical distance calculations to detections.
% tx_gps: [lat, lon] of the transmitter (HDTV Tower)
% rx_gps: [lat, lon] of the receiver (Your Office)

% 1. Standard Processing with N320 Phase-Coherent Logic
% Shared LO distribution ensures deterministic phase for range accuracy.
[caf_map, delays, doppler] = compute_radar_caf(fname, Fs, 'suppressClutter', true);

% --- BISTATIC GEOMETRY CONSTANTS ---
c = 299792458; % Speed of light in m/s

% Calculate Baseline Distance (L) in meters
% Using the 'posdist' or 'haversine' method to find distance between GPS coords
L = posdist(tx_gps, rx_gps); 

% 2. Thresholding & Detection
noise_floor = median(caf_map(:));
threshold_val = noise_floor * 10^(15/20); 
[pks, locs] = findpeaks(caf_map(:), 'MinPeakHeight', threshold_val);
[dop_idx, del_idx] = ind2sub(size(caf_map), locs);

% 3. Filtering, Interpolation, and Localization
valid_hits = [];
for i = 1:length(pks)
    % Standard Guards (Keep these loose for the initial site test)
    if delays(del_idx(i)) > 0.5 && abs(doppler(dop_idx(i))) > 5.0
        
        % Parabolic interpolation for sub-sample accuracy
        row = dop_idx(i); col = del_idx(i);
        y_del = caf_map(row, col-1:col+1);
        d_del = 0.5 * (y_del(1)-y_del(3)) / (y_del(1)-2*y_del(2)+y_del(3));
        
        % Refined Delay in seconds
        tau_ref = (delays(col) + (d_del*(1/Fs)*1e6)) / 1e6;
        
        % --- THE LOCALIZATION CALCULATION ---
        % 1. Bistatic Range (The extra distance traveled by the echo)
        bistatic_range_m = tau_ref * c;
        
        % 2. Total Path Length (Distance from Tower -> Plane -> Yagi)
        total_path_m = bistatic_range_m + L;
        
        % Note: The target lies on an ELLIPSE where the Tower and Yagi are the foci.
        % The 'total_path_m' is the constant sum of distances to those foci.
        
        valid_hits = [valid_hits; ...
            tau_ref*1e6, ...          % Delay (us)
            doppler(row), ...         % Doppler (Hz)
            bistatic_range_m / 1000, ... % Bistatic Range (km)
            total_path_m / 1000, ...     % Total Path Length (km)
            20*log10(pks(i)/noise_floor)];
    end
end

% 4. Output Data
detections = array2table(valid_hits, 'VariableNames', ...
    {'Delay_us', 'Doppler_Hz', 'BistaticRange_km', 'TotalPath_km', 'SNR_dB'});

disp('--- TARGET LOCALIZATION REPORT ---');
disp(detections);

% 5. Plot the Radar Ellipses on a map based on above calculations
plot_radar_ellipses(detections, tx_gps, rx_gps)

end

function d = posdist(loc1, loc2)
    % Helper to calculate distance in meters between two [lat, lon] points
    R = 6371000; % Earth radius
    phi1 = deg2rad(loc1(1)); phi2 = deg2rad(loc2(1));
    dphi = deg2rad(loc2(1)-loc1(1)); dlambda = deg2rad(loc2(2)-loc1(2));
    a = sin(dphi/2)^2 + cos(phi1)*cos(phi2)*sin(dlambda/2)^2;
    d = R * 2 * atan2(sqrt(a), sqrt(1-a));
end

function plot_radar_ellipses(detections, tx_gps, rx_gps)
% plot_radar_ellipses: Plots detection ellipses on a geographic map
% detections: Table from the previous localized script
% tx_gps: [lat, lon] of the transmitter
% rx_gps: [lat, lon] of the N320 receiver

% 1. Setup Geographic Map (Mapping Toolbox)
figure('Name', 'Passive Radar Geographic Overlay');
ax = geoaxes;
geobasemap(ax, 'streets'); % Similar look to FlightAware
hold(ax, 'on');

% 2. Plot Foci (Hardware Locations)
geoplot(ax, tx_gps(1), tx_gps(2), 'r^', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'HDTV Tower');
geoplot(ax, rx_gps(1), rx_gps(2), 'bs', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'N320 Receiver');

% 3. Calculate and Plot Ellipses (Radar Toolbox & Geometry)
% Total distance (RangeSum) is the TotalPath_km we calculated
c = physconst('LightSpeed'); % Phased Array Toolbox constant

for i = 1:height(detections)
    % Extract Total Path Length for this detection
    range_sum_km = detections.TotalPath_km(i);
    
    % Generate the ellipse points using Radar Toolbox logic
    % We use an auxiliary function to solve for the ellipse coordinates
    [lat_el, lon_el] = calculate_bistatic_ellipse(tx_gps, rx_gps, range_sum_km);
    
    % Plot the ellipse
    geoplot(ax, lat_el, lon_el, 'g--', 'LineWidth', 1.5, ...
        'DisplayName', sprintf('Target SNR: %.1f dB', detections.SNR_dB(i)));
end

legend(ax, 'Location', 'northeastoutside');
title(ax, 'Bistatic Detection Map (TV Illumination)');
end


