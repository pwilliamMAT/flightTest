function terrain = helperLLTerrain(cfg,grid)
%HELPERLLTERRAIN Height datums before any coordinate transformation.
% Native geographic sites take AGL heights. ENU transforms instead require
% ellipsoidal heights h = terrain_MSL + height_AGL + geoid separation N.
lat = [cfg.receiver.latitude;[cfg.sites.latitude]';grid.latitude];
lon = [cfg.receiver.longitude;[cfg.sites.longitude]';grid.longitude];
key = struct("lat",lat,"lon",lon,"mode",cfg.terrainMode, ...
    "antennaHeights",[cfg.receiver.heightAGL [cfg.sites.heightAGL]], ...
    "altitudesM",cfg.altitudesFtAGL*cfg.metresPerFoot, ...
    "source",cfg.terrainSource,"geoid",cfg.geoidModel,"release",version, ...
    "code",helperLLSourceStamp(string(mfilename("fullpath"))+".m"));
file = helperLLCacheFile(cfg,"terrain",key);
[terrain,hit] = helperLLCache("get",file,key);
if hit && ~cfg.forceRefresh
    terrain.cacheHit = true;
    return
end
terrain = struct("mode",cfg.terrainMode,"key",key,"cacheHit",false);
terrain.geoidM = geoidheight(lat,mod(lon,360),cfg.geoidModel,"Error");
if cfg.terrainMode == "terrain"
    locations = rxsite(Latitude=lat',Longitude=lon');
    try
        terrain.groundMSL = elevation(locations);
    catch exception
        error("localizationLikelihood:TerrainUnavailable", ...
            "Native terrain elevation failed: %s",exception.message);
    end
else
    assert(cfg.terrainMode=="flat-free-space","Unsupported terrain mode.");
    terrain.groundMSL = zeros(size(lat));
end
terrain.groundMSL = terrain.groundMSL(:);
if ~all(isfinite(terrain.groundMSL))
    error("localizationLikelihood:TerrainUnavailable","Terrain has missing elevations.");
end
siteCount = numel(cfg.sites)+1;
siteHeights = [cfg.receiver.heightAGL;[cfg.sites.heightAGL]'];
h = terrain.groundMSL(1:siteCount)+terrain.geoidM(1:siteCount)+siteHeights;
terrain.originLLH = [lat(1) lon(1) h(1)];
[e,n,u] = geodetic2enu(lat(1:siteCount),lon(1:siteCount),h,lat(1),lon(1),h(1),wgs84Ellipsoid);
terrain.receiverENU = [e(1) n(1) u(1)];
terrain.transmitterENU = [e(2:siteCount) n(2:siteCount) u(2:siteCount)];
for a = 1:numel(cfg.altitudesFtAGL)
    targetH = terrain.groundMSL(siteCount+1:end)+terrain.geoidM(siteCount+1:end) ...
        +cfg.altitudesFtAGL(a)*cfg.metresPerFoot;
    [e,n,u] = geodetic2enu(grid.latitude,grid.longitude,targetH, ...
        lat(1),lon(1),h(1),wgs84Ellipsoid);
    terrain.targetENU(:,:,a) = [e n u];
end
% Heights and altitude slices affect the cached ENU positions too.
terrain.cacheHit = false;
helperLLCache("put",file,key,terrain);
end
