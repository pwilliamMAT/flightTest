function grid = helperLLGrid(cfg)
%HELPERLLGRID Common geographic cells with exact clipped ROI area weights.
% A boundary cell contributes only its intersection with an ROI. Sampling
% its center approximates the within-cell field, not the geographic area.
b = vertcat(cfg.rois.bounds);
s = cfg.gridSpacingDegrees;
lat = floor(min(b(:,1))/s)*s:s:ceil(max(b(:,2))/s)*s;
lon = floor(min(b(:,3))/s)*s:s:ceil(max(b(:,4))/s)*s;
[grid.lon,grid.lat] = meshgrid(lon,lat);
grid.size = size(grid.lat);
grid.latitude = grid.lat(:);
grid.longitude = grid.lon(:);
grid.areaKm2 = zeros(numel(grid.lat),numel(cfg.rois));
earth = wgs84Ellipsoid("km");
for k = 1:numel(cfg.rois)
    south = max(grid.latitude-s/2,b(k,1));
    north = min(grid.latitude+s/2,b(k,2));
    west = max(grid.longitude-s/2,b(k,3));
    east = min(grid.longitude+s/2,b(k,4));
    inside = north>south;
    inside = inside & east>west;
    grid.areaKm2(inside,k) = areaquad(south(inside),west(inside), ...
        north(inside),east(inside),earth);
end
grid.mask = any(grid.areaKm2>0,2);
end
