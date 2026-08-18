function helperPlotStageReviewManeuverSummary(review)
%HELPERPLOTSTAGEREVIEWMANEUVERSUMMARY Plot Stage 2C label diagnostics.

counts = review.maneuverCountsTable;
baseline = review.baselineByManeuverClass;
pairs = review.pairReviewTable;

figure("Name", "Stage Review Maneuver Summary");
tiledlayout(2, 2, "TileSpacing", "compact", "Padding", "compact");

nexttile;
bar(categorical(counts.maneuverClass), counts.pairCount);
xlabel("Maneuver class");
ylabel("Pair count");
title("Stage 2C Label Counts");
grid on;

nexttile;
bar(categorical(baseline.maneuverClass), baseline.positionRMSEMeters);
xlabel("Maneuver class");
ylabel("Position RMSE [m]");
title("Constvel Position Error By Class");
grid on;

nexttile;
histogram(pairs.absTurnRateDegreesPerSecond);
xlabel("Absolute turn rate [deg/s]");
ylabel("Pair count");
title("Observed Turn-Rate Distribution");
grid on;

nexttile;
hold on;
histogram(log10(max(pairs.constvelPositionErrorMeters, eps)));
histogram(log10(max(pairs.nnSmokePositionErrorMeters, eps)));
hold off;
xlabel("log10 position error [m]");
ylabel("Pair count");
title("Position Error Scale Separation");
legend(["constvel", "smoke MLP"], "Location", "best");
grid on;

end
