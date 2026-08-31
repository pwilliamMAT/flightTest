function screenshotPath = helperOpenSystemPrecheckRfAnalyzer(pathName)
%helperOpenSystemPrecheckRfAnalyzer Open the native RF Budget Analyzer for manual capture.
%
% Plain-language concept:
% The technical deck can include one native RF Budget Analyzer component view,
% but that view is best treated as a manual screenshot artifact. This helper
% rebuilds the cleaned RF budget for the requested path, opens show(budget),
% and prints the fixed screenshot path that the deck expects.

arguments
    pathName (1, 1) string {mustBeMember(pathName, ["Newton", "Hudson"])} = "Newton"
end

projectRoot = fileparts(mfilename("fullpath"));
figuresDir = fullfile(projectRoot, "Artifacts", "Figures");
screenshotPath = fullfile(figuresDir, "SystemPrecheck_RFBudgetAnalyzer_" + pathName + ".png");

[~, stationSummary] = helperBuildSystemPrecheckAssumptions();
stationIndex = find(stationSummary.Path == pathName, 1, "first");
station = table2struct(stationSummary(stationIndex, :));

wgs84 = wgs84Ellipsoid("meter");
lightSpeed = physconst("LightSpeed");
centerFrequencyHz = station.CenterFrequency_MHz * 1e6;
wavelength_m = lightSpeed / centerFrequencyHz;
directPathDistance_m = distance( ...
    station.TowerLatitude_deg, ...
    station.TowerLongitude_deg, ...
    station.ReceiverLatitude_deg, ...
    station.ReceiverLongitude_deg, ...
    wgs84);
freeSpacePathLoss_dB = fspl(directPathDistance_m, wavelength_m);
eirp_dBm = 10 * log10(station.ERPHorizontal_kW * 1e6) + 2.15;
directPathPowerAfterAntenna_dBm = ...
    eirp_dBm + station.ReceiverAntennaGain_dBi - freeSpacePathLoss_dB;

rfResult = helperBuildRfBudgetCase(station, directPathPowerAfterAntenna_dBm);

try
    show(rfResult.TargetBudget);
catch analyzerException
    error( ...
        "helperOpenSystemPrecheckRfAnalyzer:ShowFailed", ...
        "Could not open the RF Budget Analyzer for %s: %s", ...
        pathName, ...
        analyzerException.message);
end

fprintf("Opened the native RF Budget Analyzer for %s.\n", pathName);
fprintf("Capture the component view manually and save it to:\n%s\n", screenshotPath);
end
