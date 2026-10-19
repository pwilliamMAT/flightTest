function view = helperLLWalkthroughView(study,altitudeFtAGL,roiIndex)
%HELPERLLWALKTHROUGHVIEW Small labeled tables from the current study.
% Presentation-only selection: all arrays and summaries remain in study.
% No numerical model, threshold, propagation result or conclusion is cached.
result = study.baseline;
cfg = result.cfg;
view.roiName = string(cfg.rois(roiIndex).name);
[found,view.altitudeIndex] = ismember(altitudeFtAGL,cfg.altitudesFtAGL);
assert(found,"Choose a walkthrough altitude present in cfg.altitudesFtAGL.");
view.altitudeFtAGL = altitudeFtAGL;
representative = cfg.contourPointLatLon(roiIndex,:);
offsets = [result.grid.latitude-representative(1), ...
    (result.grid.longitude-representative(2))*cosd(representative(1))];
[~,view.pointIndex] = min(sum(offsets.^2,2));

% Coordinates and RF inputs come from configuration, not copied prose.
siteCount = numel(cfg.sites)+1;
groundMSL = result.terrain.groundMSL(1:siteCount);
heightAGL = [cfg.receiver.heightAGL;[cfg.sites.heightAGL]'];
view.sites = table([string(cfg.receiver.name);string({cfg.sites.name})'], ...
    [cfg.receiver.latitude;[cfg.sites.latitude]'], ...
    [cfg.receiver.longitude;[cfg.sites.longitude]'],heightAGL,groundMSL, ...
    groundMSL+heightAGL+result.terrain.geoidM(1:siteCount), ...
    VariableNames=["Site","Latitude_deg","Longitude_deg","AGL_m","GroundMSL_m","Ellipsoid_m"]);
% Fix display precision without changing the numeric coordinates used above.
view.sites.Latitude_deg = compose("%.6f",view.sites.Latitude_deg);
view.sites.Longitude_deg = compose("%.6f",view.sites.Longitude_deg);
view.transmitters = table(string({cfg.sites.name})',[cfg.sites.frequencyHz]'/1e6, ...
    [cfg.sites.erpW]'/1e3,VariableNames=["Transmitter","Frequency_MHz","ERP_kW"]);
view.measurements = table( ...
    ["Independent range error";"SNR gate";"Known-Up RMS limit";"3D RMS limit";"Whitened H condition limit"], ...
    [cfg.rangeSigmaM;cfg.snrGateDB;cfg.horizontalLimitM;cfg.totalLimitM;cfg.maxCondition], ...
    ["m (one standard deviation)";"dB";"m";"m";"dimensionless"], ...
    VariableNames=["Assumption","Value","Units"]);
rf = cfg.rf;
view.rfAssumptions = table( ...
    ["RCS";"Receive gain";"Effective noise figure";"Reference temperature"; ...
    "Equivalent interval";"Input noise bandwidth";"ERP to EIRP";"Additional loss";"Apply component loss"], ...
    [rf.rcsM2;rf.receiveGainDBi;rf.noiseFigureDB;rf.referenceTemperatureK; ...
    rf.equivalentIntervalS*1e6;rf.bandwidthHz/1e6;rf.erpToEirpDB;rf.additionalLossDB;double(rf.applyBandpassLoss)], ...
    ["m^2";"dBi";"dB";"K";"microseconds";"MHz";"dB";"dB";"1=yes, 0=no"], ...
    VariableNames=["Assumption","Value","Units"]);
view.newton = table(["Maintained";"Catalog sensitivity"], ...
    [cfg.sites(1).latitude;cfg.newtonCatalogLatitude], ...
    [cfg.sites(1).longitude;cfg.newtonCatalogLongitude], ...
    VariableNames=["NewtonCase","Latitude_deg","Longitude_deg"]);
view.newton.Latitude_deg = compose("%.6f",view.newton.Latitude_deg);
view.newton.Longitude_deg = compose("%.6f",view.newton.Longitude_deg);
screen = study.screen.table;
view.screen = screen(screen.DistanceKm<=cfg.screen.radiusKm, ...
    ["Location","RFChannel","MinimumSeparationDeg","FullChannelMaxLossDB","Eligible","Selected"]);
view.screen.Properties.VariableNames = ...
    ["Location","RFChannel","Separation_deg","ChannelLoss_dB","Eligible","Selected"];

% Keep counts next to areas: conditional quantiles alone hide invalid cells.
summary = result.summary;
main = summary.ROI==view.roiName;
main = main & summary.AltitudeFtAGL==altitudeFtAGL;
pair = ismember(summary.Configuration,cfg.configurationNames(4:5));
view.ideal = summary(main & pair, ...
    ["Configuration","Mode","IdealValidCells","IdealUsefulAreaKm2","IdealMedianRMSM","IdealMedianGeometryRMS"]);
view.ideal.Properties.VariableNames = ...
    ["Configuration","Mode","ValidCells","Useful_km2","MedianRMS_m","MedianGeometry"];
view.coverage = summary(main & pair, ...
    ["Configuration","Mode","ROICells","ValidCells","UsefulCells","UsefulAreaKm2"]);
view.coverage.Properties.VariableNames{6} = 'Useful_km2';
view.cochesett = summary(main & ismember(summary.Configuration,cfg.configurationNames(5:6)), ...
    ["Configuration","Mode","IdealValidCells","IdealUsefulAreaKm2","IdealMedianRMSM"]);
view.cochesett.Properties.VariableNames = ...
    ["Configuration","Mode","ValidCells","Useful_km2","MedianRMS_m"];
diagnostics = study.rfDiagnostics;
view.rfComparison = diagnostics(diagnostics.ROI==view.roiName & diagnostics.AltitudeFtAGL==altitudeFtAGL, ...
    ["Transmitter","MinExcessLossDB","MaxSNRDB","SupportedAreaKm2","FreeSpaceSupportedAreaKm2"]);
view.rfComparison.Properties.VariableNames = ...
    ["Transmitter","MinExcess_dB","MaxSNR_dB","Supported_km2","ZeroExcess_km2"];

attribution = result.attribution;
view.altitudes = attribution(:,["ROI","AltitudeFtAGL","Mode","IdealAddedUsefulAreaKm2","AddedUsefulAreaKm2"]);
coarse = attribution(attribution.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL,:);
coarse.GridSpacingDegrees = repmat(cfg.gridSpacingDegrees,height(coarse),1);
resolution = [coarse;study.gridSensitivityTable];
threeD = resolution.Mode=="Unconstrained 3D";
view.grid = resolution(threeD,["ROI","GridSpacingDegrees","AddedUsefulCells", ...
    "AddedUsefulCenterInsideCells","AddedUsefulAreaKm2","AddedUsefulOutsideCenterAreaKm2"]);
view.grid.Properties.VariableNames = ...
    ["ROI","Step_deg","NewCells","CenterInsideCells","Added_km2","OutsideCenter_km2"];

% Side-by-side ROI values keep the nine error/gate cases readable.
sensitivity = study.sensitivity.attribution;
slice = sensitivity.AltitudeFtAGL==altitudeFtAGL;
slice = slice & sensitivity.Mode=="Unconstrained 3D";
north = sensitivity(slice & sensitivity.ROI==string(cfg.rois(1).name),:);
west = sensitivity(slice & sensitivity.ROI==string(cfg.rois(2).name),:);
view.sensitivity = table(north.SigmaM,north.GateDB,north.AddedUsefulAreaKm2,west.AddedUsefulAreaKm2, ...
    VariableNames=["RangeSigma_m","Gate_dB","NorthAdded3D_km2","WestAdded3D_km2"]);
catalog = study.catalogNewton.attribution;
catalogRows = catalog.AltitudeFtAGL==altitudeFtAGL;
view.catalog = catalog(catalogRows,["ROI","Mode","AddedUsefulCells","AddedUsefulAreaKm2"]);
view.catalog.Properties.VariableNames = ["ROI","Mode","NewCells","Added_km2"];

% Show the actual physical mode for every run; mixed scenario fallbacks
% cannot silently be compared as a terrain-aware sensitivity result.
view.modes = table(["Maintained";"Catalog Newton"], ...
    [string(result.mode);string(study.catalogNewton.mode)], ...
    [string(result.fallbackReason);string(study.catalogNewton.fallbackReason)], ...
    VariableNames=["Scenario","PhysicalMode","FallbackReason"]);
for index = 1:numel(study.gridSensitivity)
    fine = study.gridSensitivity(index);
    view.modes(end+1,:) = {"Grid "+fine.cfg.gridSpacingDegrees+" deg",string(fine.mode),""};
end

% Conditional language responds to current results, including changed gates.
row = attribution.ROI==view.roiName;
row = row & attribution.AltitudeFtAGL==altitudeFtAGL;
row = row & attribution.Mode=="Unconstrained 3D";
current = attribution(row,:);
view.conclusion = compose("%s at %.0f ft AGL: WLEK adds %.4f km^2 of modeled useful 3D area; ideal gain is %.1f km^2.", ...
    view.roiName,altitudeFtAGL,current.AddedUsefulAreaKm2,current.IdealAddedUsefulAreaKm2);
if altitudeFtAGL==cfg.sensitivityAltitudeFtAGL
    fineRows = study.gridSensitivityTable.ROI==view.roiName;
    fineRows = fineRows & study.gridSensitivityTable.Mode=="Unconstrained 3D";
    fineGains = study.gridSensitivityTable.AddedUsefulAreaKm2(fineRows);
    if isempty(fineGains)
        view.conclusion(end+1) = "No refinement cases were configured; spatial stability is untested.";
    elseif any(fineGains==0)
        view.conclusion(end+1) = "At least one finer grid has zero added 3D area. A persistent gain across grids is not demonstrated.";
    else
        view.conclusion(end+1) = "All tested finer grids retain some added 3D area. Assess its size and variation; these samples do not prove convergence.";
    end
else
    view.conclusion(end+1) = "Grid refinement applies to the configured sensitivity altitude, not this displayed slice.";
end
if any(view.modes.PhysicalMode~="terrain")
    view.conclusion(end+1) = "This execution includes flat-terrain/free-space cases. Read the mode table before comparing sensitivities.";
end
view.conclusion(end+1) = "These are conditional local-uncertainty results; validate echo/reference support and propagation behavior before extending localization.";
end
