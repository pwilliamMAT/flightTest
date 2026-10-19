function [files,figures] = helperLLPlots(result,options)
%HELPERLLPLOTS Explain signal support, local information, and their overlap.
% A strong signal is not a position fix. These figures keep the three
% questions separate: what geometry could resolve, which links pass the RF
% gate, and which available subsets meet the chosen uncertainty limit.
% All comparison maps use the same cells, ROI mask, and fixed color limits.
% Gray missing uncertainty means deficient rank, never zero uncertainty.
% helperLLPlots(result) exports the original twelve PNGs and closes only its
% own figures. Display="inline" leaves requested figures open and writes no
% files. Figures are returned as the second output for inspection/cleanup.
% Plots: 1 sites, 2 contours, 3/4 ideal known-Up/3D, 5 transitions,
% 6 transmitter SNR, 7 configuration SNR, 8/9 useful known-Up/3D,
% 10 failure modes, 11 altitude areas, 12 Cochesett geometry.
% AltitudesFtAGL selects existing slices; ROI selects map bounds only.
arguments
    result (1,1) struct
    options.Plots (1,:) {mustBeNumeric,mustBeReal,mustBeInteger,mustBeMember(options.Plots,1:12)} = 1:12
    options.AltitudesFtAGL (1,:) {mustBeNumeric,mustBeReal,mustBeFinite,mustBeNonempty} = result.cfg.altitudesFtAGL
    options.Display (1,1) string {mustBeMember(options.Display,["export","inline"])} = "export"
    options.ROI (1,1) string = "all"
end
cfg = result.cfg;
[found,altitudeIndices] = ismember(options.AltitudesFtAGL,cfg.altitudesFtAGL);
assert(all(found),"Choose altitude slices present in this result.");
cfg.altitudesFtAGL = cfg.altitudesFtAGL(altitudeIndices);
result.analysis = result.analysis(altitudeIndices);
result.terrain.targetENU = result.terrain.targetENU(:,:,altitudeIndices);
grid = result.grid;
if options.ROI ~= "all"
    roiIndex = find(string({cfg.rois.name})==options.ROI,1);
    assert(~isempty(roiIndex),"ROI must match a configured ROI name or all.");
    grid.mask = grid.areaKm2(:,roiIndex)>0;
    grid.viewBounds = cfg.rois(roiIndex).bounds;
    cfg.contourPointLatLon = cfg.contourPointLatLon(roiIndex,:);
end
if options.Display == "export"
    if ~isfolder(cfg.outputDir)
        mkdir(cfg.outputDir);
    end
end
% At most twelve selected figures and four contour legend entries are built.
files = strings(0,1);
figures = gobjects(0,1);
siteColors = lines(4);
[~,midAltitude] = min(abs(cfg.altitudesFtAGL-cfg.sensitivityAltitudeFtAGL));
altCount = numel(cfg.altitudesFtAGL);
modeText = string(result.terrain.mode);
if modeText == "flat-free-space"
    modeText = "FLAT TERRAIN / FREE SPACE FALLBACK";
end
context = modeText + " | assumed range sigma " + cfg.rangeSigmaM + " m";

% Geographic context includes the otherwise excluded southern transmitter.
if any(options.Plots==1)
    f = newFigure([1100 750],options.Display,1);
    tl = tiledlayout(f,1,1,TileSpacing="compact",Padding="compact");
    ax = nexttile(tl);
    hold(ax,"on");
    for r = 1:numel(cfg.rois)
        b = cfg.rois(r).bounds;
        patch(ax,b([3 4 4 3]),b([1 1 2 2]),siteColors(r,:), ...
            FaceAlpha=0.10,EdgeColor=siteColors(r,:),LineWidth=1.5, ...
            DisplayName=cfg.rois(r).name);
    end
    plot(ax,cfg.loganIllustrativeLatLon(:,2),cfg.loganIllustrativeLatLon(:,1), ...
        "k--",LineWidth=1.3,DisplayName="Illustrative Logan approach (schematic)");
    plot(ax,cfg.receiver.longitude,cfg.receiver.latitude,"kp", ...
        MarkerFaceColor="k",MarkerSize=12,DisplayName="Apple Hill receiver");
    for k = 1:numel(cfg.sites)
        plot(ax,cfg.sites(k).longitude,cfg.sites(k).latitude,"^", ...
            Color=siteColors(k,:),MarkerFaceColor=siteColors(k,:),MarkerSize=9, ...
            DisplayName=cfg.sites(k).name);
        text(ax,cfg.sites(k).longitude+0.008,cfg.sites(k).latitude, ...
            cfg.sites(k).name,FontSize=10,Interpreter="none");
    end
    hold(ax,"off");
    xlabel(ax,"Longitude (degrees)");
    ylabel(ax,"Latitude (degrees)");
    daspect(ax,[1 cosd(mean(grid.latitude)) 1]); gridOn(ax);
    legend(ax,Location="southoutside",NumColumns=2);
    title(tl,["Study geography and retained ROIs";context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"01_site_roi_overview",options.Display);
end

% An excess-range measurement confines the target to an ellipsoid. At a
% known Up coordinate its intersection with a horizontal plane is a curve.
% Dashed +/- sigma curves delimit the one-measurement uncertainty band;
% the covariance ellipse describes only local joint horizontal information.
if any(options.Plots==2)
    f = newFigure([1300 980],options.Display,2);
    tl = tiledlayout(f,2,size(cfg.contourPointLatLon,1), ...
        TileSpacing="compact",Padding="compact");
    for q = 1:size(cfg.contourPointLatLon,1)
        representative = cfg.contourPointLatLon(q,:);
        offsets = [grid.latitude-representative(1), ...
            (grid.longitude-representative(2))*cosd(representative(1))];
        [~,nearest] = min(sum(offsets.^2,2));
        p = result.terrain.targetENU(nearest,:,midAltitude);
        [dx,dy] = meshgrid(linspace(-cfg.plot.contourSpanM,cfg.plot.contourSpanM,cfg.plot.contourSamples));
        localPoints = [p(1)+dx(:),p(2)+dy(:),repmat(p(3),numel(dx),1)];
        rx = result.terrain.receiverENU;
        tx = result.terrain.transmitterENU(1:3,:);
        g = helperLLGeometry(p,tx,rx,cfg.rangeSigmaM^2*eye(3),1:2, ...
            true(1,3),cfg.maxCondition,cfg.horizontalLimitM);
        ax = nexttile(tl,q); hold(ax,"on");
        handles = gobjects(0); labels = strings(0);
        receiverRanges = vecnorm(localPoints-rx,2,2);
        for k = 1:3
            excess = vecnorm(localPoints-tx(k,:),2,2) + receiverRanges ...
                - norm(tx(k,:)-rx);
            residual = reshape(excess-g.rho(k),size(dx));
            [~,central] = contour(ax,dx/1000,dy/1000,residual,[0 0], ...
                LineColor=siteColors(k,:),LineWidth=1.8);
            contour(ax,dx/1000,dy/1000,residual, ...
                [-cfg.rangeSigmaM cfg.rangeSigmaM],LineColor=siteColors(k,:), ...
                LineStyle="--",LineWidth=0.8);
            handles(end+1) = central; labels(end+1) = cfg.sites(k).name; %#ok<AGROW>
        end
        if g.rank==2
            % This ellipse has Mahalanobis radius one (~39% joint probability
            % in 2D); it is deliberately not mislabeled a 68% or 95% region.
            angles = linspace(0,2*pi,cfg.plot.ellipseSamples);
            ellipse = chol(g.covariance(:,:,1),"lower")*[cos(angles);sin(angles)];
            handles(end+1) = plot(ax,ellipse(1,:)/1000,ellipse(2,:)/1000, ...
                "k-",LineWidth=2); %#ok<AGROW>
            labels(end+1) = "Local covariance ellipse, radius 1"; %#ok<AGROW>
        end
        plot(ax,0,0,"ko",MarkerFaceColor="k",HandleVisibility="off");
        hold(ax,"off"); axis(ax,"equal");
        xlim(ax,[-1 1]*cfg.plot.contourSpanM/1000);
        ylim(ax,[-1 1]*cfg.plot.contourSpanM/1000);
        xlabel(ax,"East offset from representative point (km)");
        ylabel(ax,"North offset from representative point (km)"); gridOn(ax);
        title(ax,sprintf("Lat %.3f, lon %.3f | Up fixed at %.0f m", ...
            grid.latitude(nearest),grid.longitude(nearest),p(3)));
        legend(ax,handles,labels,Location="southoutside",FontSize=8);
        % A second, enlarged view makes the tens-of-metres bands visible beside
        % the kilometre-scale ellipsoid geometry without changing their widths.
        detail = nexttile(tl,q+size(cfg.contourPointLatLon,1));
        copyobj(ax.Children,detail);
        extentKm = cfg.plot.detailMinimumExtentKm;
        if g.rank==2
            extentKm = max(extentKm,4*sqrt(max(diag(g.covariance(:,:,1))))/1000);
        end
        axis(detail,"equal"); xlim(detail,[-extentKm extentKm]);
        ylim(detail,[-extentKm extentKm]); gridOn(detail);
        xlabel(detail,"East offset (km)"); ylabel(detail,"North offset (km)");
        title(detail,"Enlarged local bands and covariance ellipse");
    end
    title(tl,["Constant excess range: solid nominal, dashed +/- range sigma"; ...
        cfg.altitudesFtAGL(midAltitude)+"-ft AGL slice; curves retain full 3D slant ranges | " + context], ...
        Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"02_excess_range_contours",options.Display);
end

% Ideal geometry assumes every selected transmitter supplies a measurement.
for dimension = [2 3]
    if ~any(options.Plots==dimension+1)
        continue
    end
    f = newFigure([1250 max(650,310*altCount)],options.Display,dimension+1);
    tl = tiledlayout(f,altCount,2,TileSpacing="compact",Padding="compact");
    for a = 1:altCount
        for k = [4 5]
            g = geometry(result.analysis(a).configurations(k),dimension,false);
            values = g.totalRMS; values(g.rank<dimension) = NaN;
            ax = nexttile(tl);
            drawMap(ax,grid,cfg,values,uncertaintyLimits(cfg,dimension),turbo(256));
            title(ax,altTitle(cfg,a,k));
            cb = colorbar(ax); cb.Label.String = "Position RMS (m; color saturates)";
            annotateRank(ax,nnz(grid.mask & g.rank<dimension),nnz(grid.mask));
        end
    end
    title(tl,["Ideal geometry: " + modeName(dimension) + " | gray = rank deficient";context], ...
        Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"0"+(dimension+1)+"_ideal_geometry_"+dimension+"D",options.Display); %#ok<AGROW>
end

% Subtract only finite observable uncertainties. In 3D the baseline is
% deficient, so rank transitions have categorical colors instead of Inf-Inf.
if any(options.Plots==5)
    f = newFigure([1250 max(650,310*altCount)],options.Display,5);
    tl = tiledlayout(f,altCount,2,TileSpacing="compact",Padding="compact");
    for a = 1:altCount
        base = result.analysis(a).configurations(4);
        added = result.analysis(a).configurations(5);
        finite = isfinite(base.ideal2D.totalRMS) & isfinite(added.ideal2D.totalRMS);
        gain = nan(size(grid.mask));
        gain(finite) = base.ideal2D.totalRMS(finite)-added.ideal2D.totalRMS(finite);
        ax = nexttile(tl);
        drawMap(ax,grid,cfg,gain,cfg.plot.improvementLimitsM,parula(256));
        title(ax,cfg.altitudesFtAGL(a)+" ft AGL | Known Up RMS reduction");
        cb = colorbar(ax); cb.Label.String = "Baseline minus with WLEK (m)";
        before = base.ideal3D.rank==3; after = added.ideal3D.rank==3;
        transition = zeros(size(before));
        transition(~before & after) = 1; transition(before & after) = 2;
        ax = nexttile(tl);
        drawMap(ax,grid,cfg,transition,[-0.5 2.5], ...
            [0.72 0.72 0.72;0.12 0.65 0.62;0.1 0.3 0.75]);
        title(ax,cfg.altitudesFtAGL(a)+" ft AGL | Ideal 3D rank transition");
        cb = colorbar(ax); cb.Ticks = 0:2;
        cb.TickLabels = ["Still deficient","Newly rank 3","Both rank 3"];
    end
    title(tl,["Incremental ideal geometry from WLEK";context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"05_geometry_improvement_transitions",options.Display);
end

if any(options.Plots==6)
    f = newFigure([1450 max(650,300*altCount)],options.Display,6);
    tl = tiledlayout(f,altCount,3,TileSpacing="compact",Padding="compact");
    for a = 1:altCount
        for k = 1:3
            ax = nexttile(tl);
            drawMap(ax,grid,cfg,result.analysis(a).snrDB(:,k),cfg.plot.snrLimitsDB,turbo(256));
            title(ax,cfg.sites(k).name+" | "+cfg.altitudesFtAGL(a)+" ft AGL");
            cb = colorbar(ax); cb.Label.String = "Modeled SNR (dB; color saturates)";
        end
    end
    title(tl,["Per-transmitter modeled signal support | gate = "+cfg.snrGateDB+" dB";context], ...
        Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"06_per_transmitter_snr",options.Display);
end

if any(options.Plots==7)
    f = newFigure([1650 max(650,300*altCount)],options.Display,7);
    tl = tiledlayout(f,altCount,4,TileSpacing="compact",Padding="compact");
    for a = 1:altCount
        for k = [4 5]
            snr = result.analysis(a).snrDB(:,cfg.configurations{k});
            for statistic = ["strongest","weakest"]
                if statistic=="strongest"
                    values = max(snr,[],2);
                else
                    values = min(snr,[],2);
                end
                ax = nexttile(tl);
                drawMap(ax,grid,cfg,values,cfg.plot.snrLimitsDB,turbo(256));
                title(ax,[altTitle(cfg,a,k);statistic+" selected link"]);
                cb = colorbar(ax); cb.Label.String = "Modeled SNR (dB)";
            end
        end
    end
    title(tl,["Configuration signal diagnostics: strongest is any-link support; weakest is all-link support"; ...
        "These are link extrema, not coherently combined SNR | "+context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"07_configuration_snr",options.Display);
end

for dimension = [2 3]
    if ~any(options.Plots==dimension+6)
        continue
    end
    f = newFigure([1250 max(650,300*altCount)],options.Display,dimension+6);
    tl = tiledlayout(f,altCount,2,TileSpacing="compact",Padding="compact");
    for a = 1:altCount
        for k = [4 5]
            g = geometry(result.analysis(a).configurations(k),dimension,true);
            ax = nexttile(tl);
            drawMap(ax,grid,cfg,double(g.useful),[-0.5 1.5], ...
                [0.88 0.88 0.88;0.08 0.58 0.46]);
            title(ax,altTitle(cfg,a,k));
            cb = colorbar(ax); cb.Ticks = [0 1];
            cb.TickLabels = ["Not useful","Useful"];
        end
    end
    if dimension==2
        limit = cfg.horizontalLimitM;
    else
        limit = cfg.totalLimitM;
    end
    title(tl,["Available-subset localization: "+modeName(dimension)+" | RMS <= "+limit+" m"; ...
        "Gate "+cfg.snrGateDB+" dB; rank and condition checked | "+context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"0"+(dimension+6)+"_useful_localization_"+dimension+"D",options.Display); %#ok<AGROW>
end

if any(options.Plots==10)
    f = newFigure([1550 max(650,300*altCount)],options.Display,10);
    tl = tiledlayout(f,altCount,3,TileSpacing="compact",Padding="compact");
    diagnosticColors = [0.97 0.97 0.97;0.67 0.67 0.67;0.91 0.52 0.12; ...
        0.62 0.37 0.70;0.08 0.58 0.46];
    for a = 1:altCount
        c = result.analysis(a).configurations(5);
        count = sum(c.available,2);
        ax = nexttile(tl);
        drawMap(ax,grid,cfg,count,[-0.5 3.5], ...
            [0.97 0.97 0.97;0.99 0.77 0.30;0.2 0.65 0.75;0.12 0.3 0.7]);
        title(ax,cfg.altitudesFtAGL(a)+" ft | signal-supported ranges");
        cb = colorbar(ax); cb.Ticks = 0:3; cb.Label.String = "Number passing SNR gate";
        for dimension = [2 3]
            g = geometry(c,dimension,true);
            category = ones(size(count)); category(count==0) = 0;
            category(g.rank==dimension & g.condition>cfg.maxCondition) = 2;
            category(g.rank==dimension & g.condition<=cfg.maxCondition) = 3;
            category(g.useful) = 4;
            ax = nexttile(tl);
            drawMap(ax,grid,cfg,category,[-0.5 4.5],diagnosticColors);
            title(ax,cfg.altitudesFtAGL(a)+" ft | "+modeName(dimension));
            cb = colorbar(ax); cb.Ticks = 0:4;
            cb.TickLabels = ["No links","Rank deficient","Condition fails","RMS fails","Useful"];
        end
    end
    title(tl,["Newton + Hudson + WLEK: signal count and localization failure modes";context], ...
        Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"10_signal_geometry_diagnostics",options.Display);
end

% Areas use the same correctly clipped geographic cell weights as tables.
% A line between altitude slices is visual interpolation, not a volume.
if any(options.Plots==11)
    f = newFigure([1450 800],options.Display,11);
    tl = tiledlayout(f,numel(cfg.rois),3,TileSpacing="compact",Padding="compact");
    for r = 1:numel(cfg.rois)
        for dimension = [2 3]
            ax = nexttile(tl); hold(ax,"on");
            for k = [4 5]
                for actual = [false true]
                    area = zeros(1,altCount);
                    for a = 1:altCount
                        g = geometry(result.analysis(a).configurations(k),dimension,actual);
                        area(a) = sum(grid.areaKm2(g.useful,r));
                    end
                    if actual
                        style = "-o"; prefix = "Available: ";
                    else
                        style = "--s"; prefix = "Ideal: ";
                    end
                    plot(ax,cfg.altitudesFtAGL,area,style,LineWidth=1.6, ...
                        Color=siteColors(k-3,:),DisplayName=prefix+shortConfiguration(k));
                end
            end
            hold(ax,"off"); gridOn(ax);
            ylim(ax,[0 max(1,sum(grid.areaKm2(:,r)))]);
            xlabel(ax,"Aircraft altitude (ft AGL)"); ylabel(ax,"Useful area (km^2)");
            title(ax,cfg.rois(r).name+" | "+modeName(dimension));
            legend(ax,Location="best",FontSize=8);
        end
        ax = nexttile(tl); hold(ax,"on");
        for k = [4 5]
            area = zeros(1,altCount);
            for a = 1:altCount
                count = sum(result.analysis(a).configurations(k).available,2);
                area(a) = sum(grid.areaKm2(count>0,r));
            end
            plot(ax,cfg.altitudesFtAGL,area,"-o",LineWidth=1.6, ...
                Color=siteColors(k-3,:),DisplayName=shortConfiguration(k));
        end
        hold(ax,"off"); gridOn(ax);
        ylim(ax,[0 max(1,sum(grid.areaKm2(:,r)))]);
        xlabel(ax,"Aircraft altitude (ft AGL)"); ylabel(ax,"Any-link area (km^2)");
        title(ax,cfg.rois(r).name+" | Any-link signal support");
        legend(ax,Location="best",FontSize=8);
    end
    title(tl,["Area by altitude: geometry potential, useful localization, and signal support"; ...
        "Separate ROI areas; three slices do not define a volume | "+context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"11_area_versus_altitude",options.Display);
end

if any(options.Plots==12)
    f = newFigure([1250 760],options.Display,12);
    tl = tiledlayout(f,2,2,TileSpacing="compact",Padding="compact");
    for dimension = [2 3]
        for k = [5 6]
            g = geometry(result.analysis(midAltitude).configurations(k),dimension,false);
            values = g.totalRMS; values(g.rank<dimension) = NaN;
            ax = nexttile(tl);
            drawMap(ax,grid,cfg,values,uncertaintyLimits(cfg,dimension),turbo(256));
            title(ax,[cfg.configurationNames(k);modeName(dimension)]);
            cb = colorbar(ax); cb.Label.String = "Ideal position RMS (m)";
        end
    end
    title(tl,["Compact Cochesett geometry-only reference | "+cfg.altitudesFtAGL(midAltitude)+" ft AGL"; ...
        "All three ranges assumed available; Cochesett has no RF-supported result | "+context],Interpreter="none");
    [files(end+1),figures(end+1)] = finishFigure(f,cfg,"12_cochesett_geometry_reference",options.Display);
end
files(files=="") = [];
figures = figures(isgraphics(figures));
end

function f = newFigure(positionSize,displayMode,plotNumber)
visibility = "off";
if displayMode == "inline"
    visibility = "on";
    positionSize = [1100 min(850,positionSize(2))];
end
f = figure(Visible=visibility,Color="w",Units="pixels", ...
    Position=[80 80 positionSize],Name="Localization-likelihood POC", ...
    NumberTitle="off",Tag="LocalizationWalkthrough_"+plotNumber);
% Scope the report's light theme to this owned figure. The user's desktop
% theme otherwise supplies pale text on our explicitly white export page.
theme(f,"light");
end

function [file,f] = finishFigure(f,cfg,name,displayMode)
if displayMode == "inline"
    file = "";
    drawnow;
    return
end
% Close exactly the figure owned here even if export fails; preserve all
% user figures and leave the original export exception visible to callers.
cleanup = onCleanup(@()close(f));
file = fullfile(cfg.outputDir,name+".png");
exportgraphics(f,file,Resolution=cfg.plot.resolution);
end

function drawMap(ax,grid,cfg,values,limits,colors)
values = double(values(:));
values(~grid.mask) = NaN;
values(~isfinite(values)) = NaN;
values = reshape(values,grid.size);
im = imagesc(ax,grid.lon(1,:),grid.lat(:,1),values);
im.AlphaData = isfinite(values);
set(ax,YDir="normal",Color=[0.78 0.78 0.78],FontSize=9);
colormap(ax,colors); clim(ax,limits);
hold(ax,"on");
for r = 1:numel(cfg.rois)
    b = cfg.rois(r).bounds;
    plot(ax,b([3 4 4 3 3]),b([1 1 2 2 1]),"k-",LineWidth=0.65);
end
hold(ax,"off");
xlabel(ax,"Longitude (degrees)");
ylabel(ax,"Latitude (degrees)");
xlim(ax,[min(grid.longitude)-cfg.gridSpacingDegrees/2 max(grid.longitude)+cfg.gridSpacingDegrees/2]);
ylim(ax,[min(grid.latitude)-cfg.gridSpacingDegrees/2 max(grid.latitude)+cfg.gridSpacingDegrees/2]);
if isfield(grid,"viewBounds")
    xlim(ax,grid.viewBounds(3:4));
    ylim(ax,grid.viewBounds(1:2));
end
daspect(ax,[1 cosd(mean(grid.latitude)) 1]);
end

function annotateRank(ax,failed,count)
if failed>0
    text(ax,0.02,0.96,sprintf("Rank deficient: %d / %d cells",failed,count), ...
        Units="normalized",VerticalAlignment="top",FontSize=8, ...
        BackgroundColor="w",Margin=2);
end
end

function g = geometry(configuration,dimension,actual)
if dimension==2
    if actual
        g = configuration.available2D;
    else
        g = configuration.ideal2D;
    end
else
    if actual
        g = configuration.available3D;
    else
        g = configuration.ideal3D;
    end
end
end

function limits = uncertaintyLimits(cfg,dimension)
if dimension==2
    limits = cfg.plot.horizontalLimitsM;
else
    limits = cfg.plot.totalLimitsM;
end
end

function name = modeName(dimension)
if dimension==2
    name = "Known Up (horizontal)";
else
    name = "Unconstrained 3D";
end
end

function name = shortConfiguration(k)
if k==4
    name = "Newton + Hudson";
else
    name = "Newton + Hudson + WLEK";
end
end

function text = altTitle(cfg,a,k)
text = cfg.altitudesFtAGL(a)+" ft AGL | "+shortConfiguration(k);
end

function gridOn(ax)
grid(ax,"on"); box(ax,"on"); set(ax,FontSize=10);
end
