% This is a helper function and may be changed or removed without notice.

%   Copyright 2024 The MathWorks, Inc.

function [tgtLLA,hTgts] = helperRadarCoverageTargetGrid(roi,delta,tgtHgtsMSL,g)
% Returns the target grid for the region of interest used for static
% analysis

ltLim = [floor(min(roi.Vertices(:,1))/delta)*delta ceil(max(roi.Vertices(:,1))/delta)*delta];
lnLim = [floor(min(roi.Vertices(:,2))/delta)*delta ceil(max(roi.Vertices(:,2))/delta)*delta];
tgtLat = ltLim(1):delta:ltLim(2);
tgtLon = lnLim(1):delta:lnLim(2);

[tgtLat, tgtLon] = meshgrid(tgtLat, tgtLon);
tgtLat = tgtLat(:);
tgtLon = tgtLon(:);

% Remove locations outside of the region of interest
isGdRegion = inpolygon(tgtLat, tgtLon, roi.Vertices(:, 1), roi.Vertices(:, 2));
tgtLat = tgtLat(isGdRegion);
tgtLon = tgtLon(isGdRegion);

% Place the targets at the requested heights above mean sea level
% htMSL = egm96geoid(tgtLat,tgtLon);
htGnd = helperGroundAltitude(tgtLat,tgtLon);
tgtAlt = htGnd(:) + tgtHgtsMSL(:).';

tgtLat = repmat(tgtLat,1,numel(tgtHgtsMSL));
tgtLon = repmat(tgtLon,1,numel(tgtHgtsMSL));

tgtLLA = [tgtLat(:) tgtLon(:) tgtAlt(:)];
tgtLLA = shiftdim(reshape(tgtLLA,[],numel(tgtHgtsMSL),3),2);
hTgts = geoplot(g,tgtLLA(1,:),tgtLLA(2,:),'ko', ...
    MarkerSize=0.5,LineWidth=2);
end
