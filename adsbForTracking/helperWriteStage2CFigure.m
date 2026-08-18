function helperWriteStage2CFigure(figurePath, maneuverPairTable, labelSummary)
%HELPERWRITESTAGE2CFIGURE Save a compact maneuver-characterization figure.

figurePath = string(figurePath);

try
    figureFolder = fileparts(figurePath);

    if strlength(figureFolder) > 0 && ~isfolder(figureFolder)
        mkdir(figureFolder);
    end

    classCounts = labelSummary.countsByManeuverClass;

    fig = figure( ...
        "Visible", "off", ...
        "Color", "w", ...
        "Position", [100, 100, 1100, 800], ...
        "Name", "Stage 2C Maneuver Characterization");
    cleanup = onCleanup(@() close(fig));

    layout = tiledlayout(fig, 2, 2, ...
        "TileSpacing", "compact", ...
        "Padding", "compact");

    nexttile(layout);
    bar(1:height(classCounts), classCounts.pairCount);
    set(gca, "XTick", 1:height(classCounts));
    set(gca, "XTickLabel", classCounts.maneuverClass);
    xtickangle(30);
    xlabel("Maneuver class");
    ylabel("Pair count");
    title("Maneuver-class counts");

    nexttile(layout);
    histogram(maneuverPairTable.absTurnRateDegreesPerSecond);
    xlabel("Absolute turn rate [deg/s]");
    ylabel("Pair count");
    title("Turn-rate distribution");

    nexttile(layout);
    histogram(abs(maneuverPairTable.horizontalAccelerationMetersPerSecondSquared));
    xlabel("Absolute horizontal acceleration [m/s^2]");
    ylabel("Pair count");
    title("Speed-change distribution");

    nexttile(layout);
    histogram(maneuverPairTable.dtSeconds);
    xlabel("dt [s]");
    ylabel("Pair count");
    title("Update-spacing distribution");

    exportgraphics(fig, figurePath, "Resolution", 150);
catch err
    error("Stage2C:FigureWriteFailed", ...
        "Failed to write Stage 2C figure: %s", err.message);
end

end
