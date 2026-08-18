function dataset = buildLocalADSBStatePairDataset(varargin)
%BUILDLOCALADSBSTATEPAIRDATASET Build Stage 2B local ADS-B state pairs.
% The dataset is a smoke-test artifact for a prediction/time-update neural
% interface. Raw SBS-1 logs stay unchanged; this function only writes derived
% MATLAB artifacts.

projectRoot = fileparts(mfilename("fullpath"));
flightTestRoot = fileparts(projectRoot);
defaultCaptureRoot = fullfile(flightTestRoot, "BistaticDataAnalysis", "captures");
defaultParserFolder = fullfile(flightTestRoot, "BistaticDataAnalysis");
defaultOutputFolder = fullfile(projectRoot, "artifacts", "stage2B");
defaultOutputPath = fullfile(defaultOutputFolder, "localADSBStatePairDataset.mat");
defaultReportPath = fullfile(defaultOutputFolder, "stage2BLocalADSBSmokeSummary.md");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "SourceFiles", strings(0, 1));
addParameter(parser, "SearchRoot", defaultCaptureRoot);
addParameter(parser, "ParserFolder", defaultParserFolder);
addParameter(parser, "OutputPath", defaultOutputPath);
addParameter(parser, "ReportPath", defaultReportPath);
addParameter(parser, "DefaultReceiverOriginLLA", [42.2999333, -71.349333, 15.0]);
addParameter(parser, "CovarianceStdAssumed", [100, 10, 100, 10, 150, 5]);
addParameter(parser, "MaxDtSeconds", 30);
addParameter(parser, "SplitSeed", 42);
addParameter(parser, "SmokeTest", true);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});
opts = parser.Results;

sourceFiles = string(opts.SourceFiles);
sourceFiles = sourceFiles(strlength(strtrim(sourceFiles)) > 0);
searchRoot = string(opts.SearchRoot);
parserFolder = string(opts.ParserFolder);
outputPath = string(opts.OutputPath);
reportPath = string(opts.ReportPath);
defaultReceiverOriginLLA = double(opts.DefaultReceiverOriginLLA);
covarianceStdAssumed = double(opts.CovarianceStdAssumed);
maxDtSeconds = double(opts.MaxDtSeconds);
splitSeed = double(opts.SplitSeed);
verbose = logical(opts.Verbose);

validateattributes(defaultReceiverOriginLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, ...
    mfilename, "DefaultReceiverOriginLLA");
validateattributes(covarianceStdAssumed, {'numeric'}, {'numel', 6, 'real', 'finite', 'positive'}, ...
    mfilename, "CovarianceStdAssumed");
validateattributes(maxDtSeconds, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, "MaxDtSeconds");

stateOrder = ["x", "vx", "y", "vy", "z", "vz"];

if isfolder(parserFolder)
    addpath(parserFolder);
end

if exist("loadADSBTruth", "file") ~= 2
    error("Stage2B:MissingParser", ...
        "loadADSBTruth.m was not found. Set ParserFolder to the BistaticDataAnalysis folder.");
end

if isempty(sourceFiles)
    sourceFiles = helperDiscoverLocalADSBTruthFiles(searchRoot);
end

sourceFiles = unique(sourceFiles(:), "stable");

if isempty(sourceFiles)
    error("Stage2B:NoSourceFiles", ...
        "No local ADS-B SBS-1 truth files were found or provided.");
end

if verbose
    fprintf("Stage 2B local ADS-B state-pair dataset build\n");
    fprintf("Source file count:\t%d\n", numel(sourceFiles));
    fprintf("Maximum dt [s]:\t%.2f\n", maxDtSeconds);
end

sourceFileColumn = strings(numel(sourceFiles), 1);
sourceRoleColumn = strings(numel(sourceFiles), 1);
fileSizeBytesColumn = NaN(numel(sourceFiles), 1);
modifiedTimeColumn = NaT(numel(sourceFiles), 1);
parseStatusColumn = strings(numel(sourceFiles), 1);
aircraftCountColumn = zeros(numel(sourceFiles), 1);
validSampleCountColumn = zeros(numel(sourceFiles), 1);
usablePairCountColumn = zeros(numel(sourceFiles), 1);
sessionIDColumn = strings(numel(sourceFiles), 1);
receiverOriginSourceColumn = strings(numel(sourceFiles), 1);
errorMessageColumn = strings(numel(sourceFiles), 1);

previousState = zeros(0, 6);
nextState = zeros(0, 6);
dtSeconds = zeros(0, 1);
previousCovarianceDiag = zeros(0, 6);
metadata = localEmptyMetadataTable();

duplicateTimestampRecordsRemoved = 0;
totalAdjacentPairCount = 0;
rejectedPairCounts = struct();
rejectedPairCounts.nonfiniteEndpoint = 0;
rejectedPairCounts.nonPositiveDt = 0;
rejectedPairCounts.aboveMaxDt = 0;

for sourceIdx = 1:numel(sourceFiles)
    sourceFile = sourceFiles(sourceIdx);
    sourceFileColumn(sourceIdx) = sourceFile;
    sourceRoleColumn(sourceIdx) = "local_adsb_truth";

    fileInfo = dir(sourceFile);

    if ~isempty(fileInfo)
        fileSizeBytesColumn(sourceIdx) = fileInfo.bytes;
        modifiedTimeColumn(sourceIdx) = datetime(fileInfo.datenum, "ConvertFrom", "datenum");
    end

    [receiverOriginLLA, originInfo] = helperResolveADSBReceiverOrigin( ...
        sourceFile, ...
        defaultReceiverOriginLLA);

    sessionIDColumn(sourceIdx) = originInfo.sessionID;
    receiverOriginSourceColumn(sourceIdx) = originInfo.source;

    if verbose
        fprintf("Parsing source:\t%s\n", sourceFile);
        fprintf("Session ID:\t%s\n", originInfo.sessionID);
        fprintf("Receiver origin source:\t%s\n", originInfo.source);
    end

    try
        adsbTracks = loadADSBTruth(cellstr(sourceFile), "Verbose", false);

        pairData = helperBuildLocalADSBStatePairs( ...
            adsbTracks, ...
            sourceFile, ...
            originInfo.sessionID, ...
            receiverOriginLLA, ...
            covarianceStdAssumed, ...
            maxDtSeconds);

        parseStatusColumn(sourceIdx) = "parsed";
        aircraftCountColumn(sourceIdx) = pairData.aircraftCount;
        validSampleCountColumn(sourceIdx) = pairData.validSampleCount;
        usablePairCountColumn(sourceIdx) = pairData.usablePairCount;

        previousState = [previousState; pairData.previousState]; %#ok<AGROW>
        nextState = [nextState; pairData.nextState]; %#ok<AGROW>
        dtSeconds = [dtSeconds; pairData.dtSeconds]; %#ok<AGROW>
        previousCovarianceDiag = [previousCovarianceDiag; pairData.previousCovarianceDiag]; %#ok<AGROW>
        metadata = [metadata; pairData.metadata]; %#ok<AGROW>

        duplicateTimestampRecordsRemoved = duplicateTimestampRecordsRemoved + ...
            pairData.duplicateTimestampRecordsRemoved;
        totalAdjacentPairCount = totalAdjacentPairCount + pairData.totalAdjacentPairCount;
        rejectedPairCounts.nonfiniteEndpoint = rejectedPairCounts.nonfiniteEndpoint + ...
            pairData.rejectedPairCounts.nonfiniteEndpoint;
        rejectedPairCounts.nonPositiveDt = rejectedPairCounts.nonPositiveDt + ...
            pairData.rejectedPairCounts.nonPositiveDt;
        rejectedPairCounts.aboveMaxDt = rejectedPairCounts.aboveMaxDt + ...
            pairData.rejectedPairCounts.aboveMaxDt;
    catch err
        parseStatusColumn(sourceIdx) = "failed";
        errorMessageColumn(sourceIdx) = string(err.message);

        if verbose
            fprintf("Parse/build failed:\t%s\n", err.message);
        end
    end
end

sourceManifest = table( ...
    sourceFileColumn, ...
    sourceRoleColumn, ...
    fileSizeBytesColumn, ...
    modifiedTimeColumn, ...
    parseStatusColumn, ...
    aircraftCountColumn, ...
    validSampleCountColumn, ...
    usablePairCountColumn, ...
    sessionIDColumn, ...
    receiverOriginSourceColumn, ...
    errorMessageColumn, ...
    'VariableNames', [ ...
        "sourceFile", ...
        "sourceRole", ...
        "fileSizeBytes", ...
        "modifiedTime", ...
        "parseStatus", ...
        "aircraftCount", ...
        "validSampleCount", ...
        "usablePairCount", ...
        "sessionID", ...
        "receiverOriginSource", ...
        "errorMessage"]);

if isempty(dtSeconds)
    error("Stage2B:NoUsablePairs", ...
        "No usable ADS-B one-step state pairs were built from the provided sources.");
end

[metadata, splitManifest] = helperAssignADSBStatePairSplits( ...
    metadata, ...
    splitSeed);

normalization = helperComputeADSBNormalization( ...
    previousState, ...
    previousCovarianceDiag, ...
    dtSeconds, ...
    nextState, ...
    metadata.split);

baselineConstVelMetrics = helperScoreConstVelBaseline( ...
    previousState, ...
    nextState, ...
    dtSeconds);

buildSummary = struct();
buildSummary.generatedAt = datetime("now", "TimeZone", "UTC");
buildSummary.rawFileCount = numel(sourceFiles);
buildSummary.parsedFileCount = sum(sourceManifest.parseStatus == "parsed");
buildSummary.parsedAircraftCount = sum(sourceManifest.aircraftCount);
buildSummary.validSampleCount = sum(sourceManifest.validSampleCount);
buildSummary.usablePairCount = size(previousState, 1);
buildSummary.duplicateTimestampRecordsRemoved = duplicateTimestampRecordsRemoved;
buildSummary.totalAdjacentPairCount = totalAdjacentPairCount;
buildSummary.rejectedPairCounts = rejectedPairCounts;
buildSummary.dtSummary = localSummarizeDt(dtSeconds);
buildSummary.smokeTestFlag = logical(opts.SmokeTest);
buildSummary.outputPath = outputPath;
buildSummary.reportPath = reportPath;
buildSummary.defaultReceiverOriginLLA = defaultReceiverOriginLLA;
buildSummary.maxDtSeconds = maxDtSeconds;

dataset = struct();
dataset.previousState = previousState;
dataset.nextState = nextState;
dataset.dtSeconds = dtSeconds;
dataset.previousCovarianceDiag = previousCovarianceDiag;
dataset.metadata = metadata;
dataset.stateOrder = stateOrder;
dataset.covarianceStdAssumed = covarianceStdAssumed;
dataset.normalization = normalization;
dataset.sourceManifest = sourceManifest;
dataset.splitManifest = splitManifest;
dataset.buildSummary = buildSummary;
dataset.baselineConstVelMetrics = baselineConstVelMetrics;

try
    outputFolder = fileparts(outputPath);

    if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    save(outputPath, ...
        "previousState", ...
        "nextState", ...
        "dtSeconds", ...
        "previousCovarianceDiag", ...
        "metadata", ...
        "stateOrder", ...
        "covarianceStdAssumed", ...
        "normalization", ...
        "sourceManifest", ...
        "splitManifest", ...
        "buildSummary", ...
        "baselineConstVelMetrics", ...
        "dataset", ...
        "-v7.3");
catch err
    error("Stage2B:DatasetSaveFailed", ...
        "Failed to save derived dataset artifact: %s", err.message);
end

helperWriteStage2BReport(reportPath, dataset, []);

if verbose
    fprintf("Usable one-step pairs:\t%d\n", size(previousState, 1));
    fprintf("Median dt [s]:\t%.3f\n", buildSummary.dtSummary.median);
    fprintf("Constvel position RMSE [m]:\t%.3f\n", ...
        baselineConstVelMetrics.positionRMSEMeters);
    fprintf("Constvel velocity RMSE [m/s]:\t%.3f\n", ...
        baselineConstVelMetrics.velocityRMSEMetersPerSecond);
    fprintf("Dataset artifact written:\t%s\n", outputPath);
    fprintf("Summary report written:\t%s\n", reportPath);
end

end

function metadata = localEmptyMetadataTable()
%LOCALEMPTYMETADATATABLE Create the required metadata schema.

metadata = table( ...
    strings(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    strings(0, 1), ...
    NaT(0, 1, "TimeZone", "UTC"), ...
    NaT(0, 1, "TimeZone", "UTC"), ...
    zeros(0, 3), ...
    strings(0, 1), ...
    'VariableNames', [ ...
        "sessionID", ...
        "sourceFile", ...
        "hex", ...
        "callsign", ...
        "timeUtcK", ...
        "timeUtcNext", ...
        "receiverOriginLLA", ...
        "split"]);

end

function dtSummary = localSummarizeDt(dtSeconds)
%LOCALSUMMARIZEDT Return compact dt statistics for review.

dtSummary = struct();
dtSummary.count = numel(dtSeconds);
dtSummary.min = min(dtSeconds);
dtSummary.p25 = prctile(dtSeconds, 25);
dtSummary.median = median(dtSeconds);
dtSummary.p75 = prctile(dtSeconds, 75);
dtSummary.max = max(dtSeconds);

end
