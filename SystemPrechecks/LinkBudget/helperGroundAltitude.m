% This is a helper function and may be changed or removed without notice.

%   Copyright 2024 The MathWorks, Inc.

function alt = helperGroundAltitude(lat,lon)
% Use this function to get the ground altitude above the reference geoid at
% points of interest

if all(lat(:)==lat(1))
    latlim = lat(1)*(1+1e-3*[-1 1]);
else
    latlim = [min(lat(:)) max(lat(:))];
end

if all(lon(:)==lon(1))
    lonlim = lon(1)*(1+1e-3*[1 -1]);
else
    lonlim = [min(lon(:)) max(lon(:))];
end

layers = wmsfind("mathworks","SearchField","serverurl");
elevation = refine(layers,"elevation");
[A,R] = wmsread(elevation,Latlim=latlim,Lonlim=lonlim, ...
    ImageFormat="image/bil");
A = double(A);

% Convert heights from EGM96 to WGS84
alt = geointerp(A,R,lat(:),lon(:)) + egm96geoid(lat(:),lon(:));
end