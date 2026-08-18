function archiveInventory = helperBuildStage3CArchiveInventory(varargin)
%HELPERBUILDSTAGE3CARCHIVEINVENTORY Classify archived ADS-B truth files.
% The inventory separates archive discovery from scoring. It tests native
% gunzip first, uses the .NET fallback only after native failure, and records
% which source file path should be handed to the frozen Stage 3B evaluator.

projectRoot = fileparts(mfilename("fullpath"));
flightTestRoot = fileparts(projectRoot);
defaultArchiveRoot = fullfile(projectRoot, "adsb_archive", "adsb_archive");
defaultOutputFolder = fullfile(projectRoot, "artifacts", "stage3C");
defaultParserFolder = fullfile(flightTestRoot, "BistaticDataAnalysis");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ArchiveRoot", defaultArchiveRoot);
addParameter(parser, "OutputFolder", defaultOutputFolder);
addParameter(parser, "ParserFolder", defaultParserFolder);
addParameter(parser, "UseGzipFallback", true);
addParameter(parser, "FallbackFolder", fullfile(defaultOutputFolder, "fallback_truth"));
addParameter(parser, "DefaultReceiverOriginLLA", [42.2999333, -71.349333, 15.0]);
addParameter(parser, "CovarianceStdAssumed", [100, 10, 100, 10, 150, 5]);
addParameter(parser, "MaxDtSeconds", 30);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});

config = localBuildConfig(parser.Results);
localValidateConfig(config);

if isfolder(config.ParserFolder)
    addpath(config.ParserFolder);
end

sourceFiles = localDiscoverArchiveTruthFiles(config.ArchiveRoot);
sourceFileTable = localBuildSourceFileTable(config, sourceFiles);
layoutSummary = localBuildLayoutSummary(config, sourceFileTable);
selectedMask = sourceFileTable.selectedForEvaluation;

archiveInventory = struct();
archiveInventory.generatedAt = datetime("now", "TimeZone", "UTC");
archiveInventory.archiveRoot = config.ArchiveRoot;
archiveInventory.outputFolder = config.OutputFolder;
archiveInventory.fallbackFolder = config.FallbackFolder;
archiveInventory.useGzipFallback = config.UseGzipFallback;
archiveInventory.sourceFileTable = sourceFileTable;
archiveInventory.layoutSummary = layoutSummary;
archiveInventory.sourceFilesForEvaluation = sourceFileTable.evaluationSourceFile(selectedMask);
archiveInventory.originalSourceFilesForEvaluation = sourceFileTable.originalSourceFile(selectedMask);
archiveInventory.zeroUseSourceFiles = sourceFileTable.originalSourceFile(sourceFileTable.usablePairCount == 0);

if config.Verbose
    fprintf("Stage 3C archive inventory complete\n");
    fprintf("Archive source files:\t%d\n", height(sourceFileTable));
    fprintf("Evaluation source files:\t%d\n", numel(archiveInventory.sourceFilesForEvaluation));
    fprintf("Fallback recovered files:\t%d\n", sum(sourceFileTable.fallbackStatus == "succeeded"));
    fprintf("Usable one-step pairs in inventory probe:\t%d\n", sum(sourceFileTable.usablePairCount));
end

end

function config = localBuildConfig(opts)
%LOCALBUILDCONFIG Normalize inventory options.

config = struct();
config.ArchiveRoot = string(opts.ArchiveRoot);
config.OutputFolder = string(opts.OutputFolder);
config.ParserFolder = string(opts.ParserFolder);
config.UseGzipFallback = logical(opts.UseGzipFallback);
config.FallbackFolder = string(opts.FallbackFolder);
config.DefaultReceiverOriginLLA = double(opts.DefaultReceiverOriginLLA);
config.CovarianceStdAssumed = double(opts.CovarianceStdAssumed);
config.MaxDtSeconds = double(opts.MaxDtSeconds);
config.Verbose = logical(opts.Verbose);

end

function localValidateConfig(config)
%LOCALVALIDATECONFIG Validate inventory configuration.

if exist(config.ArchiveRoot, "dir") ~= 7
    error("Stage3C:MissingArchiveRoot", ...
        "ArchiveRoot was not found: %s", config.ArchiveRoot);
end

if exist(config.ParserFolder, "dir") ~= 7
    error("Stage3C:MissingParserFolder", ...
        "ParserFolder was not found: %s", config.ParserFolder);
end

validateattributes(config.DefaultReceiverOriginLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, ...
    mfilename, "DefaultReceiverOriginLLA");
validateattributes(config.CovarianceStdAssumed, {'numeric'}, {'numel', 6, 'real', 'finite', 'positive'}, ...
    mfilename, "CovarianceStdAssumed");
validateattributes(config.MaxDtSeconds, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, ...
    mfilename, "MaxDtSeconds");

end

function sourceFiles = localDiscoverArchiveTruthFiles(archiveRoot)
%LOCALDISCOVERARCHIVETRUTHFILES Find truth files in the known archive layouts.

testingTruthInfo = dir(fullfile( ...
    archiveRoot, ...
    "testing_machine", ...
    "captures", ...
    "*", ...
    "truth", ...
    "*.txt*"));
piTruthInfo = dir(fullfile( ...
    archiveRoot, ...
    "pi_only", ...
    "truth", ...
    "*.txt*"));
candidateInfo = [testingTruthInfo; piTruthInfo];

if isempty(candidateInfo)
    sourceFiles = strings(0, 1);
    return;
end

isFile = ~[candidateInfo.isdir].';
candidateInfo = candidateInfo(isFile);

if isempty(candidateInfo)
    sourceFiles = strings(0, 1);
    return;
end

candidatePaths = strings(numel(candidateInfo), 1);

for fileIdx = 1:numel(candidateInfo)
    candidatePaths(fileIdx) = string(fullfile(candidateInfo(fileIdx).folder, candidateInfo(fileIdx).name));
end

fileNames = string({candidateInfo.name}).';
lowerPaths = lower(candidatePaths);
isTruthText = endsWith(lowerPaths, ".txt") | endsWith(lowerPaths, ".txt.gz");
isMetadataSidecar = startsWith(fileNames, "._");
sourceFiles = sort(candidatePaths(isTruthText & ~isMetadataSidecar));
sourceFiles = unique(sourceFiles(:), "stable");

end

function sourceFileTable = localBuildSourceFileTable(config, sourceFiles)
%LOCALBUILDSOURCEFILETABLE Probe every archive source file.

sourceCount = numel(sourceFiles);
originalSourceFile = strings(sourceCount, 1);
sourceRole = strings(sourceCount, 1);
sessionID = strings(sourceCount, 1);
truthLayout = strings(sourceCount, 1);
truthFolder = strings(sourceCount, 1);
fileExists = false(sourceCount, 1);
fileSizeBytes = NaN(sourceCount, 1);
modifiedTime = NaT(sourceCount, 1);
isGzip = false(sourceCount, 1);
nativeGzipStatus = strings(sourceCount, 1);
fallbackStatus = strings(sourceCount, 1);
fallbackSourceFile = strings(sourceCount, 1);
evaluationSourceFile = strings(sourceCount, 1);
selectedForEvaluation = false(sourceCount, 1);
parseStatus = strings(sourceCount, 1);
aircraftCount = zeros(sourceCount, 1);
validSampleCount = zeros(sourceCount, 1);
usablePairCount = zeros(sourceCount, 1);
receiverOriginSource = strings(sourceCount, 1);
gzipErrorMessage = strings(sourceCount, 1);
fallbackErrorMessage = strings(sourceCount, 1);
parseErrorMessage = strings(sourceCount, 1);
zeroUseReason = strings(sourceCount, 1);

for sourceIdx = 1:sourceCount
    sourceFile = sourceFiles(sourceIdx);
    [role, fileSessionID, fileLayout, fileTruthFolder] = localClassifyArchivePath( ...
        config.ArchiveRoot, ...
        sourceFile);
    [receiverOriginLLA, originInfo] = helperResolveADSBReceiverOrigin( ...
        sourceFile, ...
        config.DefaultReceiverOriginLLA);
    [evaluationFile, nativeStatus, fallbackState, fallbackFile, gzipError, fallbackError] = ...
        localResolveEvaluationSource(config, sourceFile);

    originalSourceFile(sourceIdx) = sourceFile;
    sourceRole(sourceIdx) = role;
    sessionID(sourceIdx) = fileSessionID;
    truthLayout(sourceIdx) = fileLayout;
    truthFolder(sourceIdx) = fileTruthFolder;
    isGzip(sourceIdx) = endsWith(lower(sourceFile), ".gz");
    nativeGzipStatus(sourceIdx) = nativeStatus;
    fallbackStatus(sourceIdx) = fallbackState;
    fallbackSourceFile(sourceIdx) = fallbackFile;
    evaluationSourceFile(sourceIdx) = evaluationFile;
    gzipErrorMessage(sourceIdx) = gzipError;
    fallbackErrorMessage(sourceIdx) = fallbackError;
    receiverOriginSource(sourceIdx) = string(originInfo.source);

    fileInfo = dir(sourceFile);

    if ~isempty(fileInfo)
        fileExists(sourceIdx) = true;
        fileSizeBytes(sourceIdx) = fileInfo.bytes;
        modifiedTime(sourceIdx) = datetime(fileInfo.datenum, "ConvertFrom", "datenum");
    end

    selectedForEvaluation(sourceIdx) = strlength(evaluationFile) > 0 && ...
        exist(evaluationFile, "file") == 2;

    if ~selectedForEvaluation(sourceIdx)
        parseStatus(sourceIdx) = "not_selected";
        zeroUseReason(sourceIdx) = localZeroUseReason( ...
            parseStatus(sourceIdx), ...
            usablePairCount(sourceIdx), ...
            gzipError, ...
            fallbackError, ...
            "");
        continue;
    end

    try
        adsbTracks = loadADSBTruth(cellstr(evaluationFile), "Verbose", false);
        pairData = helperBuildLocalADSBStatePairs( ...
            adsbTracks, ...
            sourceFile, ...
            fileSessionID, ...
            receiverOriginLLA, ...
            config.CovarianceStdAssumed, ...
            config.MaxDtSeconds);
        parseStatus(sourceIdx) = "parsed";
        aircraftCount(sourceIdx) = pairData.aircraftCount;
        validSampleCount(sourceIdx) = pairData.validSampleCount;
        usablePairCount(sourceIdx) = pairData.usablePairCount;
    catch err
        parseStatus(sourceIdx) = "failed";
        parseErrorMessage(sourceIdx) = string(err.message);
    end

    zeroUseReason(sourceIdx) = localZeroUseReason( ...
        parseStatus(sourceIdx), ...
        usablePairCount(sourceIdx), ...
        gzipError, ...
        fallbackError, ...
        parseErrorMessage(sourceIdx));
end

sourceFileTable = table( ...
    originalSourceFile, ...
    sourceRole, ...
    sessionID, ...
    truthLayout, ...
    truthFolder, ...
    fileExists, ...
    fileSizeBytes, ...
    modifiedTime, ...
    isGzip, ...
    nativeGzipStatus, ...
    fallbackStatus, ...
    fallbackSourceFile, ...
    evaluationSourceFile, ...
    selectedForEvaluation, ...
    parseStatus, ...
    aircraftCount, ...
    validSampleCount, ...
    usablePairCount, ...
    receiverOriginSource, ...
    gzipErrorMessage, ...
    fallbackErrorMessage, ...
    parseErrorMessage, ...
    zeroUseReason, ...
    'VariableNames', [ ...
        "originalSourceFile", ...
        "sourceRole", ...
        "sessionID", ...
        "truthLayout", ...
        "truthFolder", ...
        "fileExists", ...
        "fileSizeBytes", ...
        "modifiedTime", ...
        "isGzip", ...
        "nativeGzipStatus", ...
        "fallbackStatus", ...
        "fallbackSourceFile", ...
        "evaluationSourceFile", ...
        "selectedForEvaluation", ...
        "parseStatus", ...
        "aircraftCount", ...
        "validSampleCount", ...
        "usablePairCount", ...
        "receiverOriginSource", ...
        "gzipErrorMessage", ...
        "fallbackErrorMessage", ...
        "parseErrorMessage", ...
        "zeroUseReason"]);

end

function [sourceRole, sessionID, truthLayout, truthFolder] = localClassifyArchivePath(archiveRoot, sourceFile)
%LOCALCLASSIFYARCHIVEPATH Identify archive source and session layout.

relativePath = localRelativePath(archiveRoot, sourceFile);
pathParts = split(relativePath, filesep);
sourceRole = "unknown";
sessionID = "unknown";
truthLayout = "unknown";
truthFolder = string(fileparts(sourceFile));

if any(strcmpi(pathParts, "testing_machine"))
    sourceRole = "testing_machine";
    captureIdx = find(strcmpi(pathParts, "captures"), 1, "first");

    if ~isempty(captureIdx) && captureIdx < numel(pathParts)
        sessionID = pathParts(captureIdx + 1);
        truthLayout = "testing_machine/captures/<session_id>/truth";
    end

    return;
end

if any(strcmpi(pathParts, "pi_only"))
    sourceRole = "pi_only";
    sessionID = "pi_only";
    truthLayout = "pi_only/truth";
end

end

function [evaluationFile, nativeStatus, fallbackState, fallbackFile, gzipError, fallbackError] = localResolveEvaluationSource(config, sourceFile)
%LOCALRESOLVEEVALUATIONSOURCE Choose original or staged file for scoring.

evaluationFile = "";
nativeStatus = "not_gzip";
fallbackState = "not_needed";
fallbackFile = "";
gzipError = "";
fallbackError = "";

if ~endsWith(lower(sourceFile), ".gz")
    evaluationFile = sourceFile;
    return;
end

nativeStatus = "failed";
nativeProbeFolder = string(tempname) + "_stage3C_native_gunzip";

try
    mkdir(nativeProbeFolder);
    gunzip(sourceFile, nativeProbeFolder);
    nativeStatus = "succeeded";
    evaluationFile = sourceFile;
catch err
    gzipError = string(err.message);
end

if isfolder(nativeProbeFolder)
    try
        rmdir(nativeProbeFolder, "s");
    catch
    end
end

if nativeStatus == "succeeded"
    return;
end

if ~config.UseGzipFallback
    fallbackState = "disabled";
    return;
end

fallbackState = "failed";
relativeTextPath = localRemoveGzipExtension(localRelativePath(config.ArchiveRoot, sourceFile));
fallbackFile = fullfile(config.FallbackFolder, relativeTextPath);
fallbackFolder = fileparts(fallbackFile);

try
    inflatedFile = helperInflateGzipWithDotNet(sourceFile, fallbackFolder);
    fallbackFile = string(inflatedFile);
    fallbackState = "succeeded";
    evaluationFile = fallbackFile;
catch err
    fallbackError = string(err.message);
end

end

function relativePath = localRelativePath(rootFolder, filePath)
%LOCALRELATIVEPATH Return path relative to the archive root when possible.

rootText = string(rootFolder);
fileText = string(filePath);

if ~endsWith(rootText, filesep)
    rootText = rootText + filesep;
end

if startsWith(lower(fileText), lower(rootText))
    relativePath = extractAfter(fileText, strlength(rootText));
else
    [~, fileName, fileExtension] = fileparts(fileText);
    relativePath = fileName + fileExtension;
end

end

function relativeTextPath = localRemoveGzipExtension(relativePath)
%LOCALREMOVEGZIPEXTENSION Remove only the final .gz suffix.

[relativeFolder, fileName, fileExtension] = fileparts(relativePath);

if strcmpi(fileExtension, ".gz")
    outputName = string(fileName);
else
    outputName = string(fileName) + string(fileExtension);
end

if strlength(relativeFolder) > 0
    relativeTextPath = fullfile(relativeFolder, outputName);
else
    relativeTextPath = outputName;
end

end

function reason = localZeroUseReason(parseStatus, usablePairCount, gzipError, fallbackError, parseError)
%LOCALZER0USEREASON Explain why a source did not contribute state pairs.

if usablePairCount > 0
    reason = "";
    return;
end

if parseStatus == "not_selected"
    if strlength(fallbackError) > 0
        reason = "not selected after gzip fallback failure: " + fallbackError;
    elseif strlength(gzipError) > 0
        reason = "not selected after native gunzip failure: " + gzipError;
    else
        reason = "not selected for evaluation";
    end

    return;
end

if parseStatus == "failed"
    reason = "parse failed: " + parseError;
    return;
end

reason = "parsed but produced zero usable state pairs";

end

function layoutSummary = localBuildLayoutSummary(config, sourceFileTable)
%LOCALBUILDLAYOUTSUMMARY Summarize expected archive folders.

layout = [ ...
    "testing_machine/captures/<session_id>/truth"; ...
    "pi_only/truth"];
folderPath = [ ...
    fullfile(config.ArchiveRoot, "testing_machine", "captures"); ...
    fullfile(config.ArchiveRoot, "pi_only", "truth")];
folderExists = isfolder(folderPath);
sourceFileCount = [ ...
    sum(sourceFileTable.sourceRole == "testing_machine"); ...
    sum(sourceFileTable.sourceRole == "pi_only")];
usablePairCount = [ ...
    sum(sourceFileTable.usablePairCount(sourceFileTable.sourceRole == "testing_machine")); ...
    sum(sourceFileTable.usablePairCount(sourceFileTable.sourceRole == "pi_only"))];
sessionCount = [ ...
    numel(unique(sourceFileTable.sessionID(sourceFileTable.sourceRole == "testing_machine"))); ...
    numel(unique(sourceFileTable.sessionID(sourceFileTable.sourceRole == "pi_only")))];
status = strings(numel(layout), 1);

for rowIdx = 1:numel(layout)
    if ~folderExists(rowIdx)
        status(rowIdx) = "missing";
    elseif sourceFileCount(rowIdx) == 0
        status(rowIdx) = "empty";
    else
        status(rowIdx) = "populated";
    end
end

layoutSummary = table( ...
    layout, ...
    folderPath, ...
    folderExists, ...
    status, ...
    sourceFileCount, ...
    sessionCount, ...
    usablePairCount, ...
    'VariableNames', [ ...
        "layout", ...
        "folderPath", ...
        "folderExists", ...
        "status", ...
        "sourceFileCount", ...
        "sessionCount", ...
        "usablePairCount"]);

end
