function [lat_e, lon_e] = calculate_bistatic_ellipse(f1, f2, range_sum_km)
    % Helper: Generates lat/lon points for a bistatic ellipse
    % f1, f2 are [lat, lon] foci. range_sum_km is the total path length.
    
    % Use Radar Toolbox logic: find center and orientation
    [dist_baseline, az_baseline] = distance(f1(1), f1(2), f2(1), f2(2), referenceEllipsoid('wgs84'));
    [ctr_lat, ctr_lon] = intermediate(f1(1), f1(2), f2(1), f2(2), 0.5, referenceEllipsoid('wgs84'));
    
    % Semi-major axis (a) and Semi-minor axis (b)
    a = (range_sum_km * 1000) / 2;
    c_dist = dist_baseline / 2;
    b = sqrt(a^2 - c_dist^2);
    
    % Parametric points
    theta = linspace(0, 2*pi, 100);
    x = a * cos(theta);
    y = b * sin(theta);
    
    % Rotate and translate to geographic coordinates
    % This approximates the ellipse on the WGS84 ellipsoid
    [lat_e, lon_e] = reckon(ctr_lat, ctr_lon, sqrt(x.^2 + y.^2), ...
        az_baseline + 90 + rad2deg(atan2(y, x)), referenceEllipsoid('wgs84'));
end