function screen = helperLLScreen(cfg)
%HELPERLLSCREEN Reproduce the preliminary geometric/component filter screen.
path = fullfile(cfg.repositoryRoot,"SystemPrechecks","LinkBudget","Radio_Tower_List.txt");
tokens = regexp(fileread(path), ...
    'Processing station:\s*station_8_(\d+)[\s\S]*?LatLon:\s*([-\d.]+),\s*([-\d.]+)',"tokens");
facility = cellfun(@(x) str2double(x{1}),tokens)';
lat = cellfun(@(x) str2double(x{2}),tokens)';
lon = cellfun(@(x) str2double(x{3}),tokens)';
[locations,~,group] = unique([lat lon],"rows","stable");
distanceKm = distance(cfg.receiver.latitude,cfg.receiver.longitude, ...
    locations(:,1),locations(:,2),wgs84Ellipsoid("km"));
bearing = azimuth(cfg.receiver.latitude,cfg.receiver.longitude, ...
    locations(:,1),locations(:,2),wgs84Ellipsoid);
baselineBearing = azimuth(cfg.receiver.latitude,cfg.receiver.longitude, ...
    [cfg.sites(1:2).latitude],[cfg.sites(1:2).longitude],wgs84Ellipsoid);
separation = min(abs(mod(bearing-baselineBearing+180,360)-180),[],2);
net = sparameters(cfg.filterPath);
s21 = squeeze(net.Parameters(2,1,:));
name = repmat("Outside-radius catalog site",size(distanceKm));
channel = nan(size(distanceKm));
centerLossDB = nan(size(distanceKm));
channelLossDB = nan(size(distanceKm));
existing = false(size(distanceKm));
for k = 1:numel(cfg.screen.facility)
    row = find(facility==cfg.screen.facility(k),1);
    assert(~isempty(row),"Channel mapping facility absent from catalog.");
    j = group(row);
    name(j) = cfg.screen.name(k);
    channel(j) = cfg.screen.channel(k);
    frequency = (473+6*(channel(j)-14))*1e6;
    if channel(j)==10
        frequency = 195e6;
    end
    centerLossDB(j) = -20*log10(abs(interp1(net.Frequencies,s21,frequency)));
    edges = frequency+[-1;1]*cfg.screen.channelBandwidthHz/2;
    inside = net.Frequencies>edges(1) & net.Frequencies<edges(2);
    knots = [edges;net.Frequencies(inside)];
    % On a complex linear segment, |S21| can reach an interior minimum.
    % Include that minimum analytically so the full-channel test is exact
    % for the chosen interpolation, rather than sampling only endpoints.
    knots = sort(knots);
    response = interp1(net.Frequencies,s21,knots);
    delta = diff(response);
    fraction = max(0,min(1,-real(response(1:end-1).*conj(delta))./abs(delta).^2));
    fraction(~isfinite(fraction)) = 0;
    response = [response;response(1:end-1)+fraction.*delta];
    channelLossDB(j) = max(-20*log10(abs(response)));
    existing(j) = cfg.screen.existing(k);
end
eligible = distanceKm<=cfg.screen.radiusKm;
eligible = eligible & channelLossDB<cfg.screen.maximumChannelLossDB;
eligible = eligible & ~existing;
score = separation;
score(~eligible) = -Inf;
[~,best] = max(score);
assert(any(eligible),"No candidate passes screen.");
selected = false(size(eligible));
selected(best) = true;
screen.table = table(name,locations(:,1),locations(:,2),channel,distanceKm,bearing, ...
    separation,centerLossDB,channelLossDB,existing,eligible,selected, ...
    VariableNames=["Location","Latitude","Longitude","RFChannel","DistanceKm", ...
    "BearingDeg","MinimumSeparationDeg","CenterLossDB","FullChannelMaxLossDB", ...
    "ExistingOrRedundant","Eligible","Selected"]);
screen.table = sortrows(screen.table,"MinimumSeparationDeg","descend");
screen.catalogRows = numel(facility);
screen.uniqueLocations = size(locations,1);
screen.withinRadius = nnz(distanceKm<=cfg.screen.radiusKm);
screen.sources = helperLLSourceStamp([string(path),cfg.filterPath]);
screen.channelSource = cfg.screen.channelSource;
end
