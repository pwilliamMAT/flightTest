function [corridor_azimuth_deg, boresight_azimuth_deg] = helperTriggerResolveBoresightAzimuth( ...
    rx_lla, corridor_reference_lla, corridor_override_deg, boresight_override_deg)
%HELPERTRIGGERRESOLVEBORESIGHTAZIMUTH Resolve corridor and boresight azimuths.
%
% Plain-language goal:
%   The trigger wrapper gates aircraft in a local ENU frame around the
%   receiver. This helper resolves the corridor center and surveillance
%   boresight independently so the west-facing default is explicit and the
%   legacy corridor reference point is only used when the caller asks for
%   it.

default_azimuth_deg = 270.0;

if isfinite(corridor_override_deg)
    corridor_azimuth_deg = localWrapCompassAzimuth(corridor_override_deg);
elseif localHasExplicitCorridorReference(corridor_reference_lla)
    corridor_azimuth_deg = localResolveReferenceAzimuth(rx_lla, corridor_reference_lla);
else
    corridor_azimuth_deg = default_azimuth_deg;
end

if isfinite(boresight_override_deg)
    boresight_azimuth_deg = localWrapCompassAzimuth(boresight_override_deg);
else
    boresight_azimuth_deg = default_azimuth_deg;
end

end

function tf = localHasExplicitCorridorReference(corridor_reference_lla)
tf = isnumeric(corridor_reference_lla) && numel(corridor_reference_lla) == 3 && ...
    all(isfinite(double(corridor_reference_lla(:))));
end

function azimuth_deg = localResolveReferenceAzimuth(rx_lla, corridor_reference_lla)
spheroid = wgs84Ellipsoid('meter');
[corridor_e, corridor_n, corridor_u] = geodetic2enu( ...
    corridor_reference_lla(1), corridor_reference_lla(2), corridor_reference_lla(3), ...
    rx_lla(1), rx_lla(2), rx_lla(3), spheroid);
[~, corridor_ang_deg] = rangeangle([corridor_e; corridor_n; corridor_u], [0; 0; 0]);
azimuth_deg = localWrapCompassAzimuth(90.0 - corridor_ang_deg(1));
end

function azimuth_deg = localWrapCompassAzimuth(value_deg)
azimuth_deg = mod(double(value_deg), 360.0);
end
