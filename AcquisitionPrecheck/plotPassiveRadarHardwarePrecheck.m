function figureHandle = plotPassiveRadarHardwarePrecheck(result)
%PLOTPASSIVERADARHARDWAREPRECHECK Visualize capture levels and checks.

arguments
    result (1, 1) struct
end

summary = result.Summary;
figureHandle = figure(Name="Passive Radar Acquisition Precheck");
layout = tiledlayout(figureHandle, 2, 1, ...
    TileSpacing="compact", Padding="compact");

nexttile(layout);
bar([summary.surveillanceRMSDBFS, summary.referenceRMSDBFS]);
ylabel("RMS level (dBFS)");
xlabel("Capture");
title("Configured channel levels");
legend(["Surveillance", "Reference"], Location="best");
grid on

nexttile(layout);
checkMatrix = [ ...
    summary.metadataPass, summary.integrityPass, summary.headroomPass, ...
    summary.pilotPass, summary.correlationPass, summary.ecaPass];
imagesc(double(checkMatrix.'));
colormap(gca, [0.75, 0.15, 0.15; 0.15, 0.65, 0.25]);
clim([0, 1]);
yticks(1:6);
yticklabels(["Metadata", "Integrity", "Headroom", ...
    "Pilot", "Correlation", "ECA"]);
xticks(1:height(summary));
xlabel("Capture");
title("Required checks (red = hold, green = pass)");
end
