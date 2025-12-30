% Visualize Coverage - rough estimate
%% Final High-Visibility Radar Mission Report (Hardware + Ground Track)
rx_gps = [42.3007, -71.3490];    % Natick RX
tx_gps = [42.311389, -71.216111]; % TV Tower
max_range_km = 62;

% Convert TX GPS to relative KM from RX for 3D plotting
% Using approximate scaling for MA latitude
lat2km = 111; 
lon2km = 111 * cosd(rx_gps(1));
tx_rel_x = (tx_gps(2) - rx_gps(2)) * lon2km;
tx_rel_y = (tx_gps(1) - rx_gps(1)) * lat2km;

fig = figure('Name', 'Radar Analysis Report', 'Color', 'w', 'Units', 'normalized', 'Position', [0.05 0.1 0.9 0.7]);

% --- Subplot 1: 2D Geographic Coverage with Flight Track ---
subplot(1,2,1); hold on;
C = load('coastlines.mat');
plot(C.coastlon, C.coastlat, 'Color', [0.4 0.4 0.4]); 

% Draw Coverage Circle
[lat_c, lon_c] = scircle1(rx_gps(1), rx_gps(2), km2deg(max_range_km));
fill(lon_c, lat_c, 'g', 'FaceAlpha', 0.05, 'EdgeColor', 'g', 'DisplayName', 'Coverage Area');

% Add the Ground Track of the Logan Path
% Path starts west of Natick and ends at Logan
logan_gps = [42.3656, -71.0096];
path_lats = linspace(rx_gps(1)-0.2, logan_gps(1), 50);
path_lons = linspace(rx_gps(2)-0.8, logan_gps(2), 50);
plot(path_lons, path_lats, 'r--', 'LineWidth', 2, 'DisplayName', 'Logan Ground Track');

% Hardware Icons
plot(rx_gps(2), rx_gps(1), '^r', 'MarkerFaceColor', 'r', 'MarkerSize', 10, 'DisplayName', 'Natick RX');
plot(tx_gps(2), tx_gps(1), 'bd', 'MarkerFaceColor', 'b', 'MarkerSize', 8, 'DisplayName', 'TV Tower TX');

axis([-72.5 -70 41.5 43.5]); grid on; box on; set(gca, 'Color', [0.95 0.98 1]);
title('\bf Geographic Coverage & Track', 'FontSize', 14);
legend('Location', 'southoutside', 'Orientation', 'horizontal');

% --- Subplot 2: 3D Situation Display with Hardware ---
subplot(1,2,2); hold on;
% Ground Grid
[xg, yg] = meshgrid(-70:10:70);
mesh(xg, yg, zeros(size(xg)), 'EdgeColor', [0.8 0.8 0.8], 'FaceAlpha', 0, 'HandleVisibility', 'off');

% 3D Hardware Locations
scatter3(0, 0, 0.1, 120, 'r^', 'filled', 'DisplayName', 'RX (Natick)'); % At Origin
scatter3(tx_rel_x, tx_rel_y, 0.1, 100, 'bd', 'filled', 'DisplayName', 'TX (Tower)');

% Range Rings
theta_r = linspace(0, 2*pi, 100);
for r = [20 40 60]
    plot3(r*cos(theta_r), r*sin(theta_r), zeros(size(theta_r)), 'k:', 'HandleVisibility', 'off');
    text(r, 2, 0.5, sprintf('\\bf %d km', r), 'FontSize', 9);
end

% Detection Volume
[az, el] = meshgrid(0:10:360, 0:5:90);
surf(max_range_km*cosd(el).*cosd(az), max_range_km*cosd(el).*sind(az), ...
    (max_range_km*sind(el))/4, 'FaceColor', 'g', 'FaceAlpha', 0.15, 'EdgeAlpha', 0.1, 'DisplayName', 'Volume');

% 3D Logan Flight Path
% Coordinates adjusted to match the 2D ground track
x_path = linspace(-60, 32, 50);
y_path = linspace(-10, 10, 50); % Slight diagonal to match Boston's NE position
z_path = tan(deg2rad(3)) * (32 - x_path); z_path(z_path < 0) = 0;
plot3(x_path, y_path, z_path, 'r', 'LineWidth', 4, 'DisplayName', '3D Flight Path');

view(125, 20); grid on; zlim([0 15]);
xlabel('\bf East/West (km)'); ylabel('\bf North/South (km)'); zlabel('\bf Alt (km)');
title('\bf Vertical Detection Volume', 'FontSize', 14);
legend('Location', 'southoutside');