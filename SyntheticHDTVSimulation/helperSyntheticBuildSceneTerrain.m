function terrain_info = helperSyntheticBuildSceneTerrain(scenario_config)
%HELPERSYNTHETICBUILDSCENETERRAIN Load DTED terrain for the baseline scene.
%
% Plain language:
% The simulation needs to stay anchored to the real Apple Hill / CBS site
% geometry before any signal realism work is attempted. This helper proves
% that the approved DTED file can be loaded, attached to a Radar Toolbox
% earth-centered scene, and shown to cover both the transmitter and the
% receiver locations used by the baseline scenario config.

validateattributes(scenario_config, {'struct'}, {'scalar'}, mfilename, 'scenario_config');

dted_path = char(string(scenario_config.terrain_dted_path));
tx_lla_deg_m = double(scenario_config.tx_lla_deg_m);
rx_lla_deg_m = double(scenario_config.rx_lla_deg_m);
update_rate_hz = max(1, round(1 / scenario_config.part_duration_s));

if exist(dted_path, 'file') ~= 2
    error('helperSyntheticBuildSceneTerrain:missingDTED', ...
        'DTED file not found: %s', dted_path);
end

try
    [terrain_raster, terrain_ref] = readgeoraster(dted_path);
catch ME
    error('helperSyntheticBuildSceneTerrain:readgeorasterFailed', ...
        'Could not load DTED terrain %s: %s', dted_path, ME.message);
end

latitude_limits_deg = double(terrain_ref.LatitudeLimits);
longitude_limits_deg = double(terrain_ref.LongitudeLimits);
terrain_boundary_deg = localResolveTerrainBoundary( ...
    scenario_config, latitude_limits_deg, longitude_limits_deg);

try
    scene = radarScenario('IsEarthCentered', true, 'UpdateRate', update_rate_hz);
    surface = landSurface(scene, ...
        'Terrain', dted_path, ...
        'Boundary', terrain_boundary_deg);
catch ME
    error('helperSyntheticBuildSceneTerrain:sceneBuildFailed', ...
        ['Could not attach DTED terrain %s to a radarScenario for boundary ' ...
         '[%.6f %.6f; %.6f %.6f]: %s'], ...
        dted_path, ...
        terrain_boundary_deg(1, 1), terrain_boundary_deg(1, 2), ...
        terrain_boundary_deg(2, 1), terrain_boundary_deg(2, 2), ...
        ME.message);
end

tx_in_coverage = localPointInCoverage(tx_lla_deg_m, latitude_limits_deg, longitude_limits_deg);
rx_in_coverage = localPointInCoverage(rx_lla_deg_m, latitude_limits_deg, longitude_limits_deg);

terrain_info = struct( ...
    'scene', scene, ...
    'surface', surface, ...
    'dted_path', dted_path, ...
    'latitude_limits_deg', latitude_limits_deg, ...
    'longitude_limits_deg', longitude_limits_deg, ...
    'terrain_boundary_deg', terrain_boundary_deg, ...
    'raster_size', size(terrain_raster), ...
    'tx_in_coverage', tx_in_coverage, ...
    'rx_in_coverage', rx_in_coverage);
end

function tf = localPointInCoverage(lla_deg_m, latitude_limits_deg, longitude_limits_deg)
tf = lla_deg_m(1) >= latitude_limits_deg(1) && ...
    lla_deg_m(1) <= latitude_limits_deg(2) && ...
    lla_deg_m(2) >= longitude_limits_deg(1) && ...
    lla_deg_m(2) <= longitude_limits_deg(2);
end

function terrain_boundary_deg = localResolveTerrainBoundary( ...
    scenario_config, latitude_limits_deg, longitude_limits_deg)
[latitudes_deg, longitudes_deg] = localCollectScenarioLatLon(scenario_config);

lat_span_deg = max(latitudes_deg) - min(latitudes_deg);
lon_span_deg = max(longitudes_deg) - min(longitudes_deg);
lat_padding_deg = max(0.01, 0.15 * max(lat_span_deg, eps));
lon_padding_deg = max(0.01, 0.15 * max(lon_span_deg, eps));

lat_min_deg = max(latitude_limits_deg(1), min(latitudes_deg) - lat_padding_deg);
lat_max_deg = min(latitude_limits_deg(2), max(latitudes_deg) + lat_padding_deg);
lon_min_deg = max(longitude_limits_deg(1), min(longitudes_deg) - lon_padding_deg);
lon_max_deg = min(longitude_limits_deg(2), max(longitudes_deg) + lon_padding_deg);

terrain_boundary_deg = [lat_min_deg, lat_max_deg; lon_min_deg, lon_max_deg];
end

function [latitudes_deg, longitudes_deg] = localCollectScenarioLatLon(scenario_config)
tx_lla_deg_m = double(scenario_config.tx_lla_deg_m);
rx_lla_deg_m = double(scenario_config.rx_lla_deg_m);

latitudes_deg = [tx_lla_deg_m(1); rx_lla_deg_m(1)];
longitudes_deg = [tx_lla_deg_m(2); rx_lla_deg_m(2)];

if isfield(scenario_config, 'targets') && ~isempty(scenario_config.targets)
    for idx = 1 : numel(scenario_config.targets)
        if ~isfield(scenario_config.targets(idx), 'waypoints_lla_deg_m')
            continue
        end

        waypoints_lla_deg_m = double(scenario_config.targets(idx).waypoints_lla_deg_m);
        if isempty(waypoints_lla_deg_m) || size(waypoints_lla_deg_m, 2) < 2
            continue
        end

        latitudes_deg = [latitudes_deg; waypoints_lla_deg_m(:, 1)]; %#ok<AGROW>
        longitudes_deg = [longitudes_deg; waypoints_lla_deg_m(:, 2)]; %#ok<AGROW>
    end
end
end
