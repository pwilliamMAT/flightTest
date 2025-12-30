%% 3D Integrated Radar Display (Robust Version)
rx_gps = [42.3007, -71.3490];    % Natick RX
logan_gps = [42.3656, -71.0096];
max_range_km = 62;

% 1. PULL MAP IMAGERY (High Fidelity)
% We create a temporary geo-axis to grab the "Streets" view (highways)
temp_fig = figure('Visible', 'off'); 
gx = geoaxes('Basemap', 'streets');
geolimits(gx, [41.9, 42.8], [-72.2, -70.5]);
drawnow; pause(2); % Wait for highways to load

% Capture the map as an image
map_frame = getframe(gx);
map_img = map_frame.cdata;
close(temp_fig);

% 2. INITIALIZE THE MAIN 3D PLOT
fig = figure('Name', 'Tactical Radar Display', 'Color', 'w');
ax = axes('NextPlot', 'add');

% Conversion factors (Natick-centric)
lat2km = 111.1; 
lon2km = 111.1 * cosd(rx_gps(1));

% 3. TEXTURE-MAP THE HIGHWAYS TO THE FLOOR
% Define the spatial bounds of the captured image in KM relative to Natick
lon_lims = [-72.2, -70.5];
lat_lims = [41.9, 42.7];

x_map = (lon_lims - rx_gps(2)) * lon2km;
y_map = (lat_lims - rx_gps(1)) * lat2km;

% Create a surface for the map image
% Note: flipud ensures the map isn't upside down
surface(x_map, y_map, [0 0; 0 0], flipud(map_img), ...
    'FaceColor', 'texturemap', 'EdgeColor', 'none', 'HandleVisibility', 'off');

% 4. OVERLAY THE 3D DOME
[az, el] = meshgrid(0:10:360, 0:5:90);
xd = max_range_km * cosd(el) .* cosd(az);
yd = max_range_km * cosd(el) .* sind(az);
zd = (max_range_km * sind(el)) / 4; 
surf(ax, xd, yd, zd, 'FaceColor', 'g', 'FaceAlpha', 0.15, 'EdgeAlpha', 0.1, 'DisplayName', 'Coverage');

% 5. ADD THE FLIGHT PATH & HARDWARE
logan_x = (logan_gps(2) - rx_gps(2)) * lon2km;
logan_y = (logan_gps(1) - rx_gps(1)) * lat2km;

% 3D Path
x_p = linspace(-60, logan_x, 50);
y_p = linspace(-10, logan_y, 50);
z_p = tan(deg2rad(3)) * (abs(logan_x - x_p)); 
plot3(ax, x_p, y_p, z_p, 'r', 'LineWidth', 4, 'DisplayName', 'Logan Approach');

% 6. FORMATTING
view(140, 30); grid on;
axis(ax, [-70 70 -70 70 0 15]);
xlabel('West-East (km)'); ylabel('South-North (km)'); zlabel('Alt (km)');
title('\bf High-Fidelity Integrated Radar Mission View');
legend('Location', 'northeast');


% --- 7. ADD HARDWARE ICONS (Slightly above Z=0 to prevent flickering) ---
% Convert TX GPS to relative KM for 3D plotting
tx_x = (tx_gps(2) - rx_gps(2)) * lon2km;
tx_y = (tx_gps(1) - rx_gps(1)) * lat2km;

% Plot Natick RX (The Origin)
scatter3(ax, 0, 0, 0.2, 150, 'r^', 'filled', 'MarkerEdgeColor', 'w', ...
    'LineWidth', 1.5, 'DisplayName', 'Natick RX');

% Plot TV Tower TX
scatter3(ax, tx_x, tx_y, 0.2, 120, 'bd', 'filled', 'MarkerEdgeColor', 'w', ...
    'LineWidth', 1.5, 'DisplayName', 'TV Tower TX');

% Optional: Label them in 3D space
text(ax, 0, 0, 2, ' \bf Apple Hill (RX)', 'Color', 'r', 'FontSize', 9);
text(ax, tx_x, tx_y, 2, ' \bf TV Tower (TX)', 'Color', 'b', 'FontSize', 9);