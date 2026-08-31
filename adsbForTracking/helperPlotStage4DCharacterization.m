function output = helperPlotStage4DCharacterization(results, varargin)
%HELPERPLOTSTAGE4DCHARACTERIZATION Plot transition and robustness evidence.

parser = inputParser;
parser.FunctionName = mfilename;
addRequired(parser, "results");
addParameter(parser, "SavePath", "");
parse(parser, results, varargin{:});

savePath = strtrim(string(parser.Results.SavePath));
localValidateResults(results);
modelOrder = [ ...
    "expanded_warm_mean_v1"; ...
    "constvel"; ...
    "constacc"; ...
    "constturn"];
displayNames = [ ...
    "Frozen warm"; ...
    "constvel"; ...
    "constacc"; ...
    "constturn"];
colors = [ ...
    0.8500, 0.3250, 0.0980; ...
    0.0000, 0.4470, 0.7410; ...
    0.4660, 0.6740, 0.1880; ...
    0.4940, 0.1840, 0.5560];

figureHandle = figure( ...
    Name="Stage 4D Frozen Warm Characterization", ...
    Color="w", ...
    Position=[100, 100, 1400, 620]);
tiledlayout( ...
    figureHandle, ...
    1, ...
    2, ...
    TileSpacing="compact", ...
    Padding="compact");

nexttile
transitionAxes = gca;
transitionAxes.Color = "w";
transitionAxes.XColor = "k";
transitionAxes.YColor = "k";
transitionRows = results.transitionMetricTable( ...
    results.transitionMetricTable.domain == ...
    "synthetic_in_distribution" & ...
    results.transitionMetricTable.profile == "degraded" & ...
    results.transitionMetricTable.comparisonFamily == "causal_history", :);
hold on

for modelIdx = 1:numel(modelOrder)
    modelRows = sortrows( ...
        transitionRows( ...
        transitionRows.modelID == modelOrder(modelIdx), :), ...
        "transitionBinCenterSeconds");
    plot( ...
        modelRows.transitionBinCenterSeconds, ...
        modelRows.positionRMSEMeters, ...
        "-o", ...
        Color=colors(modelIdx, :), ...
        LineWidth=1.5, ...
        DisplayName=displayNames(modelIdx));
end

xline( ...
    0, ...
    "--k", ...
    "Transition", ...
    LabelVerticalAlignment="bottom", ...
    HandleVisibility="off");
hold off
grid on
xlabel("Time from nearest motion transition (s)", Color="k")
ylabel("Position RMSE (m)", Color="k")
title("Degraded synthetic transition response", Color="k")
transitionLegend = legend(Location="best");
transitionLegend.Color = "w";
transitionLegend.TextColor = "k";

nexttile
robustnessAxes = gca;
robustnessAxes.Color = "w";
robustnessAxes.XColor = "k";
robustnessAxes.YColor = "k";
robustnessRows = results.robustnessTable( ...
    results.robustnessTable.comparisonFamily == "same_information" & ...
    ismember(results.robustnessTable.domain, [ ...
    "synthetic_in_distribution", ...
    "real_adsb"]) & ...
    ismember(results.robustnessTable.modelID, modelOrder(1:2)), :);
[groupTable, groupLabels] = localRobustnessGroups(robustnessRows);
bar(categorical(groupLabels, groupLabels), groupTable)
robustnessAxes.Color = "w";
robustnessAxes.XColor = "k";
robustnessAxes.YColor = "k";
grid on
ylabel("Position RMSE (m)", Color="k")
title("Same-information robustness", Color="k")
robustnessLegend = legend(displayNames(1:2), Location="northwest");
robustnessLegend.Color = "w";
robustnessLegend.TextColor = "k";
xtickangle(25)

if strlength(savePath) > 0
    saveFolder = string(fileparts(savePath));

    if strlength(saveFolder) > 0 && ~isfolder(saveFolder)
        mkdir(saveFolder);
    end

    exportgraphics(figureHandle, savePath, Resolution=160);
end

output = struct();
output.figure = figureHandle;
output.savePath = savePath;
output.transitionRows = transitionRows;
output.robustnessRows = robustnessRows;

end

function [values, labels] = localRobustnessGroups(robustnessRows)
%LOCALROBUSTNESSGROUPS Arrange warm and constvel bars in stable profile order.

domainOrder = ["synthetic_in_distribution", "real_adsb"];
profileOrder = [ ...
    "ideal", ...
    "empirical_timing", ...
    "degraded", ...
    "baseline", ...
    "random_dropout_10", ...
    "random_dropout_25", ...
    "burst_outage"];
modelOrder = ["expanded_warm_mean_v1", "constvel"];
values = zeros(0, 2);
labels = strings(0, 1);

for domainIdx = 1:numel(domainOrder)
    domainName = domainOrder(domainIdx);

    for profileIdx = 1:numel(profileOrder)
        profileName = profileOrder(profileIdx);
        rowMask = ...
            robustnessRows.domain == domainName & ...
            robustnessRows.profile == profileName;

        if any(rowMask)
            nextValues = NaN(1, 2);

            for modelIdx = 1:numel(modelOrder)
                modelMask = rowMask & ...
                    robustnessRows.modelID == modelOrder(modelIdx);
                nextValues(modelIdx) = ...
                    robustnessRows.positionRMSEMeters(modelMask);
            end

            values(end + 1, :) = nextValues; %#ok<AGROW>
            labels(end + 1, 1) = localDomainLabel(domainName) + ...
                " / " + localProfileLabel(profileName); %#ok<AGROW>
        end
    end
end

end

function label = localProfileLabel(profileName)
%LOCALPROFILELABEL Shorten observation profiles for the x-axis.

switch profileName
    case "ideal"
        label = "ideal";
    case "empirical_timing"
        label = "empirical";
    case "degraded"
        label = "degraded";
    case "baseline"
        label = "baseline";
    case "random_dropout_10"
        label = "10% drop";
    case "random_dropout_25"
        label = "25% drop";
    case "burst_outage"
        label = "burst";
    otherwise
        label = replace(profileName, "_", " ");
end

end

function label = localDomainLabel(domainName)
%LOCALDOMAINLABEL Shorten domain names for the x-axis.

if domainName == "synthetic_in_distribution"
    label = "Synthetic ID";
else
    label = "Real ADS-B";
end

end

function localValidateResults(results)
%LOCALVALIDATERESULTS Require the two plotted result tables.

if ~isstruct(results) || ...
        ~isfield(results, "transitionMetricTable") || ...
        ~isfield(results, "robustnessTable") || ...
        isempty(results.transitionMetricTable) || ...
        isempty(results.robustnessTable)
    error("Stage4D:InvalidPlotResults", ...
        "Completed Stage 4D transition and robustness tables are required.");
end

end
