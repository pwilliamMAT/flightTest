function integrationSummary = integrateStage4BThreeDayArchive(varargin)
%INTEGRATESTAGE4BTHREEDAYARCHIVE Safely add the Stage 4B campaign archive.
% The transfer ZIP is validated in a temporary folder before any session is
% copied. Existing sessions are never overwritten. A durable CSV freezes
% membership for Legacy-16, the 3-Day Campaign Increment, and Expanded-3Day.

projectRoot = fileparts(mfilename("fullpath"));
flightTestRoot = fileparts(projectRoot);
defaultZipPath = fullfile(projectRoot, "stage4B_adsb_3day.zip");
defaultArchiveRoot = fullfile(projectRoot, "adsb_archive", "adsb_archive");
defaultVersionFolder = fullfile(projectRoot, "adsb_archive", "datasetVersions");
defaultVariantManifestPath = fullfile(defaultVersionFolder, "adsbDatasetVariants.csv");
defaultVariantSummaryPath = fullfile(defaultVersionFolder, "adsbDatasetVariants.md");
defaultArtifactPath = fullfile( ...
    projectRoot, ...
    "artifacts", ...
    "stage4BPostCampaign", ...
    "integration", ...
    "stage4BThreeDayIntegration.mat");
defaultParserFolder = fullfile(flightTestRoot, "BistaticDataAnalysis");

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ProjectRoot", projectRoot);
addParameter(parser, "ZipPath", defaultZipPath);
addParameter(parser, "ArchiveRoot", defaultArchiveRoot);
addParameter(parser, "VariantManifestPath", defaultVariantManifestPath);
addParameter(parser, "VariantSummaryPath", defaultVariantSummaryPath);
addParameter(parser, "ArtifactPath", defaultArtifactPath);
addParameter(parser, "ParserFolder", defaultParserFolder);
addParameter(parser, "CampaignID", "stage4B_3Day_nohup_20260819T132526Z");
addParameter(parser, "ExpectedZipSHA256", ...
    "BE2457298D38768DB950BF0A2EE15DBE5B5264B8532220F4AD6E44B4DA56AF3C");
addParameter(parser, "ExpectedSessionCount", 144);
addParameter(parser, "ExpectedTruthFileCount", 143);
addParameter(parser, "ExpectedLogFileCount", 288);
addParameter(parser, "ExpectedNoTruthSessionCount", 1);
addParameter(parser, "ExpectedNoTruthSessionID", ...
    "stage4B_3Day_nohup_20260819T132526Z_w133_20260822T072740Z");
addParameter(parser, "ExpectedLegacyTruthFileCount", 16);
addParameter(parser, "ExpectedReceiverOriginLLA", [42.2999333, -71.349333, 15.0]);
addParameter(parser, "ValidateTruthImport", true);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});

config = localBuildConfig(parser.Results);
localValidateConfig(config);

if isfolder(config.ParserFolder)
    addpath(config.ParserFolder);
end

if config.ValidateTruthImport && exist("loadADSBTruth", "file") ~= 2
    error("Stage4BPost:MissingParser", ...
        "loadADSBTruth.m was not found under ParserFolder: %s", config.ParserFolder);
end

zipHash = helperComputeFileSHA256(config.ZipPath);

if strlength(config.ExpectedZipSHA256) > 0 && ...
        ~strcmpi(zipHash, config.ExpectedZipSHA256)
    error("Stage4BPost:ZipHashMismatch", ...
        "ZIP SHA-256 mismatch. Expected %s but observed %s.", ...
        config.ExpectedZipSHA256, ...
        zipHash);
end

localValidateZipEntryNames(config.ZipPath);

stagingRoot = string(tempname);
mkdir(stagingRoot);
stagingCleanup = onCleanup(@() localRemoveFolderIfPresent(stagingRoot));
unzip(config.ZipPath, stagingRoot);

stagedCaptureRoot = fullfile(stagingRoot, "captures");

if ~isfolder(stagedCaptureRoot)
    error("Stage4BPost:MissingCaptureRoot", ...
        "The ZIP must contain one captures/ folder at its root.");
end

sessionTable = localInspectCampaignSessions(config, stagedCaptureRoot);
legacyFilesBeforeIntegration = localResolveLegacyFiles(config);
collisionTable = localPreflightCollisions(config, sessionTable);

if config.Verbose
    fprintf("Stage 4B-Post integration preflight\n");
    fprintf("ZIP SHA-256:\t%s\n", zipHash);
    fprintf("Campaign sessions:\t%d\n", height(sessionTable));
    fprintf("Campaign truth files:\t%d\n", sum(sessionTable.truthFileCount));
    fprintf("Legacy truth files:\t%d\n", numel(legacyFilesBeforeIntegration));
    fprintf("Existing identical sessions:\t%d\n", sum(collisionTable.status == "identical"));
end

[copiedSessionCount, identicalSessionCount] = ...
    localCopyValidatedSessions(config, sessionTable, collisionTable);

campaignFiles = localResolveCampaignFiles(config);
variantManifest = localBuildVariantManifest( ...
    config, ...
    legacyFilesBeforeIntegration, ...
    campaignFiles);
localWriteVariantManifest(config, variantManifest);

variantCounts = groupsummary( ...
    stack( ...
        variantManifest, ...
        ["legacy_pre3day_v1", "campaign_3day_increment_v1", "expanded_post3day_v2"], ...
        "NewDataVariableName", ...
        "included", ...
        "IndexVariableName", ...
        "variantID"), ...
    "variantID", ...
    "sum", ...
    "included");
variantCounts.Properties.VariableNames(end) = "sourceFileCount";

integrationSummary = struct();
integrationSummary.generatedAt = datetime("now", "TimeZone", "UTC");
integrationSummary.zipPath = config.ZipPath;
integrationSummary.zipSHA256 = zipHash;
integrationSummary.archiveRoot = config.ArchiveRoot;
integrationSummary.campaignID = config.CampaignID;
integrationSummary.sessionCount = height(sessionTable);
integrationSummary.truthFileCount = sum(sessionTable.truthFileCount);
integrationSummary.noTruthSessionIDs = sessionTable.sessionID(sessionTable.truthFileCount == 0);
integrationSummary.copiedSessionCount = copiedSessionCount;
integrationSummary.identicalSessionCount = identicalSessionCount;
integrationSummary.variantManifestPath = config.VariantManifestPath;
integrationSummary.variantSummaryPath = config.VariantSummaryPath;
integrationSummary.variantManifest = variantManifest;
integrationSummary.variantCounts = variantCounts;
integrationSummary.sessionTable = sessionTable;
integrationSummary.collisionTable = collisionTable;
integrationSummary.truthImportValidated = config.ValidateTruthImport;
integrationSummary.importedAircraftTrackCount = ...
    sum(sessionTable.importedAircraftTrackCount);
integrationSummary.retrainingRun = false;

localSaveIntegrationArtifact(config, integrationSummary);
localWriteVariantSummary(config, integrationSummary);

if config.Verbose
    fprintf("Copied sessions:\t%d\n", copiedSessionCount);
    fprintf("Already-present identical sessions:\t%d\n", identicalSessionCount);
    fprintf("Variant manifest:\t%s\n", config.VariantManifestPath);
end

clear stagingCleanup

end

function config = localBuildConfig(opts)
%LOCALBUILDCONFIG Normalize integration options.

config = struct();
config.ProjectRoot = string(opts.ProjectRoot);
config.ZipPath = string(opts.ZipPath);
config.ArchiveRoot = string(opts.ArchiveRoot);
config.VariantManifestPath = string(opts.VariantManifestPath);
config.VariantSummaryPath = string(opts.VariantSummaryPath);
config.ArtifactPath = string(opts.ArtifactPath);
config.ParserFolder = string(opts.ParserFolder);
config.CampaignID = string(opts.CampaignID);
config.ExpectedZipSHA256 = upper(string(opts.ExpectedZipSHA256));
config.ExpectedSessionCount = double(opts.ExpectedSessionCount);
config.ExpectedTruthFileCount = double(opts.ExpectedTruthFileCount);
config.ExpectedLogFileCount = double(opts.ExpectedLogFileCount);
config.ExpectedNoTruthSessionCount = double(opts.ExpectedNoTruthSessionCount);
config.ExpectedNoTruthSessionID = string(opts.ExpectedNoTruthSessionID);
config.ExpectedLegacyTruthFileCount = double(opts.ExpectedLegacyTruthFileCount);
config.ExpectedReceiverOriginLLA = double(opts.ExpectedReceiverOriginLLA);
config.ValidateTruthImport = logical(opts.ValidateTruthImport);
config.Verbose = logical(opts.Verbose);

end

function localValidateConfig(config)
%LOCALVALIDATECONFIG Validate paths and expected counts.

if exist(config.ZipPath, "file") ~= 2
    error("Stage4BPost:MissingZip", ...
        "Stage 4B transfer ZIP was not found: %s", config.ZipPath);
end

if exist(config.ArchiveRoot, "dir") ~= 7
    error("Stage4BPost:MissingArchiveRoot", ...
        "Archive root was not found: %s", config.ArchiveRoot);
end

if strlength(config.CampaignID) == 0
    error("Stage4BPost:MissingCampaignID", ...
        "CampaignID must be nonempty.");
end

countFields = [ ...
    "ExpectedSessionCount", ...
    "ExpectedTruthFileCount", ...
    "ExpectedLogFileCount", ...
    "ExpectedNoTruthSessionCount", ...
    "ExpectedLegacyTruthFileCount"];

for fieldIdx = 1:numel(countFields)
    fieldName = countFields(fieldIdx);
    validateattributes(config.(fieldName), {'numeric'}, ...
        {'scalar', 'integer', 'nonnegative'}, ...
        mfilename, ...
        fieldName);
end

validateattributes(config.ExpectedReceiverOriginLLA, {'numeric'}, ...
    {'numel', 3, 'real', 'finite'}, ...
    mfilename, ...
    "ExpectedReceiverOriginLLA");

end

function localValidateZipEntryNames(zipPath)
%LOCALVALIDATEZIPENTRYNAMES Reject paths that could escape the staging root.

archive = java.util.zip.ZipFile(char(zipPath));
cleanup = onCleanup(@() archive.close());
entries = archive.entries();
entryNames = strings(0, 1);

while entries.hasMoreElements()
    entry = entries.nextElement();
    entryName = string(char(entry.getName()));
    normalizedName = replace(entryName, "\", "/");
    pathParts = split(normalizedName, "/");
    hasTraversal = any(pathParts == "..");
    hasAbsolutePrefix = startsWith(normalizedName, "/") || ...
        ~isempty(regexp(normalizedName, "^[A-Za-z]:", "once"));

    if hasTraversal || hasAbsolutePrefix
        error("Stage4BPost:UnsafeZipEntry", ...
            "Unsafe ZIP entry path: %s", entryName);
    end

    if strlength(normalizedName) > 0 && ...
            ~startsWith(normalizedName, "captures/")
        error("Stage4BPost:UnexpectedZipEntry", ...
            "ZIP entries must be contained under captures/: %s", entryName);
    end

    if ~entry.isDirectory() && ~localIsAllowedZipFile(normalizedName)
        error("Stage4BPost:UnexpectedZipEntry", ...
            "Unexpected file type or layout in ZIP: %s", entryName);
    end

    entryNames(end + 1, 1) = normalizedName; %#ok<AGROW>
end

if numel(unique(entryNames)) ~= numel(entryNames)
    error("Stage4BPost:DuplicateZipEntry", ...
        "The ZIP contains duplicate entry names.");
end

end

function tf = localIsAllowedZipFile(entryName)
%LOCALISALLOWEDZIPFILE Limit extracted files to the campaign package schema.

sessionPrefix = "captures/[^/]+/";
isManifest = ~isempty(regexp( ...
    entryName, ...
    "^" + sessionPrefix + "session_manifest[.]json$", ...
    "once"));
isLog = ~isempty(regexp( ...
    entryName, ...
    "^" + sessionPrefix + "logs/[^/]+[.]log$", ...
    "once"));
isTruth = ~isempty(regexp( ...
    entryName, ...
    "^" + sessionPrefix + "truth/[^/]+[.]txt[.]gz$", ...
    "once"));
tf = isManifest || isLog || isTruth;

end

function sessionTable = localInspectCampaignSessions(config, stagedCaptureRoot)
%LOCALINSPECTCAMPAIGNSESSIONS Validate packaged session folders and manifests.

sessionInfo = dir(stagedCaptureRoot);
sessionInfo = sessionInfo([sessionInfo.isdir]);
sessionInfo = sessionInfo(~ismember(string({sessionInfo.name}), [".", ".."]));
sessionNames = sort(string({sessionInfo.name}).');

if numel(sessionNames) ~= config.ExpectedSessionCount
    error("Stage4BPost:UnexpectedSessionCount", ...
        "Expected %d campaign sessions but found %d.", ...
        config.ExpectedSessionCount, ...
        numel(sessionNames));
end

if any(~startsWith(sessionNames, config.CampaignID + "_w"))
    unexpectedSession = sessionNames(find( ...
        ~startsWith(sessionNames, config.CampaignID + "_w"), ...
        1, ...
        "first"));
    error("Stage4BPost:UnexpectedSessionFolder", ...
        "Unexpected folder under captures/: %s", unexpectedSession);
end

sessionID = strings(numel(sessionNames), 1);
sourceSessionFolder = strings(numel(sessionNames), 1);
campaignID = strings(numel(sessionNames), 1);
windowID = strings(numel(sessionNames), 1);
actualStartUtc = NaT(numel(sessionNames), 1, "TimeZone", "UTC");
status = strings(numel(sessionNames), 1);
receiverOriginLLA = NaN(numel(sessionNames), 3);
truthFileCount = zeros(numel(sessionNames), 1);
manifestTruthFileCount = zeros(numel(sessionNames), 1);
logFileCount = zeros(numel(sessionNames), 1);
manifestLogFileCount = zeros(numel(sessionNames), 1);
importedAircraftTrackCount = zeros(numel(sessionNames), 1);

for sessionIdx = 1:numel(sessionNames)
    currentSessionID = sessionNames(sessionIdx);
    sessionFolder = fullfile(stagedCaptureRoot, currentSessionID);
    manifestPath = fullfile(sessionFolder, "session_manifest.json");

    if exist(manifestPath, "file") ~= 2
        error("Stage4BPost:MissingSessionManifest", ...
            "Session manifest is missing: %s", manifestPath);
    end

    manifest = jsondecode(fileread(manifestPath));
    localValidateManifest(manifest, currentSessionID, config);

    truthInfo = dir(fullfile(sessionFolder, "truth", "*.txt.gz"));
    truthPaths = string(fullfile({truthInfo.folder}, {truthInfo.name})).';
    declaredTruthFiles = replace(string(manifest.adsb_files(:)), "\", "/");
    actualTruthFiles = "truth/" + string({truthInfo.name}).';
    actualTruthFiles = actualTruthFiles(:);

    if ~isequal(sort(actualTruthFiles), sort(declaredTruthFiles))
        error("Stage4BPost:TruthManifestMismatch", ...
            "Session %s truth files do not match its manifest.", ...
            currentSessionID);
    end

    for declaredIdx = 1:numel(declaredTruthFiles)
        declaredPath = fullfile(sessionFolder, ...
            replace(declaredTruthFiles(declaredIdx), "/", filesep));

        if exist(declaredPath, "file") ~= 2
            error("Stage4BPost:MissingDeclaredTruthFile", ...
                "Manifest-declared truth file is missing: %s", declaredPath);
        end
    end

    logInfo = dir(fullfile(sessionFolder, "logs", "*.log"));
    actualLogFiles = "logs/" + string({logInfo.name}).';
    declaredLogFiles = replace(string(manifest.log_files(:)), "\", "/");

    if ~isequal(sort(actualLogFiles), sort(declaredLogFiles))
        error("Stage4BPost:LogManifestMismatch", ...
            "Session %s log files do not match its manifest.", ...
            currentSessionID);
    end

    if config.ValidateTruthImport
        for truthIdx = 1:numel(truthPaths)
            tracks = loadADSBTruth(cellstr(truthPaths(truthIdx)), "Verbose", false);
            importedAircraftTrackCount(sessionIdx) = ...
                importedAircraftTrackCount(sessionIdx) + numel(tracks);
        end
    end

    sessionID(sessionIdx) = currentSessionID;
    sourceSessionFolder(sessionIdx) = sessionFolder;
    campaignID(sessionIdx) = string(manifest.campaign_id);
    windowID(sessionIdx) = string(manifest.window_id);
    actualStartUtc(sessionIdx) = datetime( ...
        string(manifest.actual_start_utc), ...
        "InputFormat", ...
        "yyyy-MM-dd'T'HH:mm:ss'Z'", ...
        "TimeZone", ...
        "UTC");
    status(sessionIdx) = string(manifest.status);
    receiverOriginLLA(sessionIdx, :) = double(manifest.receiver_origin_lla(:).');
    truthFileCount(sessionIdx) = numel(truthPaths);
    manifestTruthFileCount(sessionIdx) = numel(declaredTruthFiles);
    logFileCount(sessionIdx) = numel(logInfo);
    manifestLogFileCount(sessionIdx) = numel(declaredLogFiles);
end

if sum(truthFileCount) ~= config.ExpectedTruthFileCount
    error("Stage4BPost:UnexpectedTruthFileCount", ...
        "Expected %d truth files but found %d.", ...
        config.ExpectedTruthFileCount, ...
        sum(truthFileCount));
end

if sum(logFileCount) ~= config.ExpectedLogFileCount
    error("Stage4BPost:UnexpectedLogFileCount", ...
        "Expected %d log files but found %d.", ...
        config.ExpectedLogFileCount, ...
        sum(logFileCount));
end

if sum(truthFileCount == 0) ~= config.ExpectedNoTruthSessionCount
    error("Stage4BPost:UnexpectedNoTruthCount", ...
        "Expected %d no-truth sessions but found %d.", ...
        config.ExpectedNoTruthSessionCount, ...
        sum(truthFileCount == 0));
end

if strlength(config.ExpectedNoTruthSessionID) > 0
    noTruthSessionIDs = sessionID(truthFileCount == 0);

    if numel(noTruthSessionIDs) ~= 1 || ...
            noTruthSessionIDs ~= config.ExpectedNoTruthSessionID
        error("Stage4BPost:UnexpectedNoTruthSession", ...
            "Expected no-truth session %s.", ...
            config.ExpectedNoTruthSessionID);
    end
end

sessionTable = table( ...
    sessionID, ...
    sourceSessionFolder, ...
    campaignID, ...
    windowID, ...
    actualStartUtc, ...
    status, ...
    receiverOriginLLA, ...
    truthFileCount, ...
    manifestTruthFileCount, ...
    logFileCount, ...
    manifestLogFileCount, ...
    importedAircraftTrackCount);

end

function localValidateManifest(manifest, sessionID, config)
%LOCALVALIDATEMANIFEST Validate fields needed for versioned truth import.

requiredFields = [ ...
    "session_id", ...
    "campaign_id", ...
    "window_id", ...
    "actual_start_utc", ...
    "capture_type", ...
    "receiver_origin_lla", ...
    "adsb_files", ...
    "log_files", ...
    "status"];

for fieldIdx = 1:numel(requiredFields)
    fieldName = requiredFields(fieldIdx);

    if ~isfield(manifest, fieldName)
        error("Stage4BPost:MissingManifestField", ...
            "Session %s manifest is missing field %s.", ...
            sessionID, ...
            fieldName);
    end
end

if string(manifest.session_id) ~= sessionID
    error("Stage4BPost:SessionIDMismatch", ...
        "Manifest session ID does not match folder %s.", sessionID);
end

if string(manifest.campaign_id) ~= config.CampaignID
    error("Stage4BPost:CampaignIDMismatch", ...
        "Session %s belongs to unexpected campaign %s.", ...
        sessionID, ...
        string(manifest.campaign_id));
end

if string(manifest.capture_type) ~= "adsb_only_holdout"
    error("Stage4BPost:UnexpectedCaptureType", ...
        "Session %s has capture_type %s.", ...
        sessionID, ...
        string(manifest.capture_type));
end

validateattributes(manifest.receiver_origin_lla, {'numeric'}, ...
    {'numel', 3, 'real', 'finite'}, ...
    mfilename, ...
    "receiver_origin_lla");

if any(abs(double(manifest.receiver_origin_lla(:).') - ...
        config.ExpectedReceiverOriginLLA(:).') > 1e-9)
    error("Stage4BPost:UnexpectedReceiverOrigin", ...
        "Session %s has an unexpected receiver origin.", sessionID);
end

end

function legacyFiles = localResolveLegacyFiles(config)
%LOCALRESOLVELEGACYFILES Freeze the pre-campaign truth file set.

if exist(config.VariantManifestPath, "file") == 2
    existingManifest = readtable( ...
        config.VariantManifestPath, ...
        "TextType", ...
        "string");
    legacyMask = logical(existingManifest.legacy_pre3day_v1);
    legacyFiles = localAbsoluteManifestPaths( ...
        config.ProjectRoot, ...
        existingManifest.relativeSourceFile(legacyMask));
    expectedLegacyHashes = string( ...
        existingManifest.sourceFileSHA256(legacyMask));
    localVerifyFrozenLegacyFiles(legacyFiles, expectedLegacyHashes);
else
    allExistingFiles = localDiscoverArchiveTruthFiles(config.ArchiveRoot);
    sessionIDs = strings(numel(allExistingFiles), 1);

    for sourceIdx = 1:numel(allExistingFiles)
        [~, originInfo] = helperResolveADSBReceiverOrigin( ...
            allExistingFiles(sourceIdx), ...
            [0, 0, 0]);
        sessionIDs(sourceIdx) = originInfo.sessionID;
    end

    legacyFiles = allExistingFiles(~startsWith(sessionIDs, config.CampaignID + "_w"));
end

legacyFiles = unique(string(legacyFiles(:)), "stable");

if numel(legacyFiles) ~= config.ExpectedLegacyTruthFileCount
    error("Stage4BPost:UnexpectedLegacyFileCount", ...
        "Expected %d Legacy-16 truth files but resolved %d.", ...
        config.ExpectedLegacyTruthFileCount, ...
        numel(legacyFiles));
end

end

function localVerifyFrozenLegacyFiles(legacyFiles, expectedHashes)
%LOCALVERIFYFROZENLEGACYFILES Refuse silent changes to Legacy-16.

if numel(legacyFiles) ~= numel(expectedHashes)
    error("Stage4BPost:InvalidExistingVariantManifest", ...
        "Legacy source paths and hashes must have equal lengths.");
end

for sourceIdx = 1:numel(legacyFiles)
    if exist(legacyFiles(sourceIdx), "file") ~= 2
        error("Stage4BPost:MissingLegacySource", ...
            "A frozen Legacy-16 source is missing: %s", ...
            legacyFiles(sourceIdx));
    end

    observedHash = helperComputeFileSHA256(legacyFiles(sourceIdx));

    if ~strcmpi(observedHash, expectedHashes(sourceIdx))
        error("Stage4BPost:LegacySourceHashMismatch", ...
            "A frozen Legacy-16 source changed: %s", ...
            legacyFiles(sourceIdx));
    end
end

end

function collisionTable = localPreflightCollisions(config, sessionTable)
%LOCALPREFLIGHTCOLLISIONS Compare all existing destinations before copying.

sessionID = sessionTable.sessionID;
destinationSessionFolder = fullfile( ...
    config.ArchiveRoot, ...
    "testing_machine", ...
    "captures", ...
    sessionID);
status = repmat("new", height(sessionTable), 1);

for sessionIdx = 1:height(sessionTable)
    destinationFolder = destinationSessionFolder(sessionIdx);

    if ~isfolder(destinationFolder)
        continue;
    end

    if localFoldersAreIdentical( ...
            sessionTable.sourceSessionFolder(sessionIdx), ...
            destinationFolder)
        status(sessionIdx) = "identical";
    else
        error("Stage4BPost:SessionCollision", ...
            "Existing session differs from the transfer package: %s", ...
            sessionID(sessionIdx));
    end
end

collisionTable = table(sessionID, destinationSessionFolder, status);

end

function [copiedCount, identicalCount] = localCopyValidatedSessions(config, sessionTable, collisionTable)
%LOCALCOPYVALIDATEDSESSIONS Copy new sessions through verified temp folders.

captureRoot = fullfile(config.ArchiveRoot, "testing_machine", "captures");

if ~isfolder(captureRoot)
    mkdir(captureRoot);
end

copiedCount = 0;
identicalCount = sum(collisionTable.status == "identical");

for sessionIdx = 1:height(sessionTable)
    if collisionTable.status(sessionIdx) == "identical"
        continue;
    end

    sessionID = sessionTable.sessionID(sessionIdx);
    sourceFolder = sessionTable.sourceSessionFolder(sessionIdx);
    destinationFolder = collisionTable.destinationSessionFolder(sessionIdx);
    incomingFolder = fullfile(captureRoot, "." + sessionID + ".incoming");

    if isfolder(incomingFolder)
        error("Stage4BPost:StaleIncomingFolder", ...
            "A stale incoming session folder exists: %s", incomingFolder);
    end

    copyfile(sourceFolder, incomingFolder);
    incomingCleanup = onCleanup(@() localRemoveFolderIfPresent(incomingFolder));

    if ~localFoldersAreIdentical(sourceFolder, incomingFolder)
        error("Stage4BPost:CopyVerificationFailed", ...
            "Copied session failed hash verification: %s", sessionID);
    end

    if isfolder(destinationFolder)
        error("Stage4BPost:ConcurrentSessionCollision", ...
            "Destination appeared after preflight; refusing to overwrite: %s", ...
            destinationFolder);
    end

    [moveSucceeded, moveMessage] = movefile(incomingFolder, destinationFolder);

    if ~moveSucceeded
        error("Stage4BPost:SessionMoveFailed", ...
            "Unable to finalize session %s: %s", ...
            sessionID, ...
            moveMessage);
    end

    clear incomingCleanup
    copiedCount = copiedCount + 1;
end

end

function tf = localFoldersAreIdentical(firstFolder, secondFolder)
%LOCALFOLDERSAREIDENTICAL Compare relative file paths and SHA-256 digests.

firstInventory = localFolderInventory(firstFolder);
secondInventory = localFolderInventory(secondFolder);

tf = isequal(firstInventory.relativePath, secondInventory.relativePath) && ...
    isequal(firstInventory.sha256, secondInventory.sha256);

end

function inventory = localFolderInventory(folderPath)
%LOCALFOLDERINVENTORY Return sorted relative paths and hashes.

fileInfo = dir(fullfile(folderPath, "**", "*"));
fileInfo = fileInfo(~[fileInfo.isdir]);
relativePath = strings(numel(fileInfo), 1);
sha256 = strings(numel(fileInfo), 1);
folderPrefix = char(string(folderPath) + filesep);

for fileIdx = 1:numel(fileInfo)
    absolutePath = fullfile(fileInfo(fileIdx).folder, fileInfo(fileIdx).name);
    relativePath(fileIdx) = replace(erase(string(absolutePath), folderPrefix), "\", "/");
    sha256(fileIdx) = helperComputeFileSHA256(absolutePath);
end

inventory = sortrows(table(relativePath, sha256), "relativePath");

end

function campaignFiles = localResolveCampaignFiles(config)
%LOCALRESOLVECAMPAIGNFILES Discover integrated truth files for this campaign.

campaignCaptureRoot = fullfile( ...
    config.ArchiveRoot, ...
    "testing_machine", ...
    "captures");
truthInfo = dir(fullfile( ...
    campaignCaptureRoot, ...
    config.CampaignID + "_w*", ...
    "truth", ...
    "*.txt.gz"));
campaignFiles = sort(string(fullfile({truthInfo.folder}, {truthInfo.name})).');

if numel(campaignFiles) ~= config.ExpectedTruthFileCount
    error("Stage4BPost:IntegratedTruthCountMismatch", ...
        "Expected %d integrated campaign truth files but found %d.", ...
        config.ExpectedTruthFileCount, ...
        numel(campaignFiles));
end

end

function manifest = localBuildVariantManifest(config, legacyFiles, campaignFiles)
%LOCALBUILDVARIANTMANIFEST Build hash-backed membership for all variants.

sourceFiles = [legacyFiles(:); campaignFiles(:)];
legacyMembership = [true(numel(legacyFiles), 1); false(numel(campaignFiles), 1)];
campaignMembership = ~legacyMembership;
expandedMembership = true(numel(sourceFiles), 1);
relativeSourceFile = localRelativeProjectPaths(config.ProjectRoot, sourceFiles);
sourceFileSHA256 = strings(numel(sourceFiles), 1);
sessionID = strings(numel(sourceFiles), 1);
campaignID = repmat("legacy_pre3day", numel(sourceFiles), 1);
captureTimeUtc = NaT(numel(sourceFiles), 1, "TimeZone", "UTC");
receiverOriginSource = strings(numel(sourceFiles), 1);

for sourceIdx = 1:numel(sourceFiles)
    sourceFileSHA256(sourceIdx) = helperComputeFileSHA256(sourceFiles(sourceIdx));
    [~, originInfo] = helperResolveADSBReceiverOrigin( ...
        sourceFiles(sourceIdx), ...
        [42.2999333, -71.349333, 15.0]);
    sessionID(sourceIdx) = originInfo.sessionID;
    receiverOriginSource(sourceIdx) = originInfo.source;
    captureTimeUtc(sourceIdx) = localCaptureTimeFromSession(originInfo.sessionID);

    if campaignMembership(sourceIdx)
        manifestPath = fullfile(originInfo.sessionRoot, "session_manifest.json");
        sessionManifest = jsondecode(fileread(manifestPath));
        campaignID(sourceIdx) = string(sessionManifest.campaign_id);
        captureTimeUtc(sourceIdx) = datetime( ...
            string(sessionManifest.actual_start_utc), ...
            "InputFormat", ...
            "yyyy-MM-dd'T'HH:mm:ss'Z'", ...
            "TimeZone", ...
            "UTC");
    end
end

manifest = table( ...
    relativeSourceFile, ...
    sourceFileSHA256, ...
    sessionID, ...
    campaignID, ...
    captureTimeUtc, ...
    receiverOriginSource, ...
    legacyMembership, ...
    campaignMembership, ...
    expandedMembership, ...
    'VariableNames', [ ...
        "relativeSourceFile", ...
        "sourceFileSHA256", ...
        "sessionID", ...
        "campaignID", ...
        "captureTimeUtc", ...
        "receiverOriginSource", ...
        "legacy_pre3day_v1", ...
        "campaign_3day_increment_v1", ...
        "expanded_post3day_v2"]);

if numel(unique(lower(relativeSourceFile))) ~= numel(relativeSourceFile)
    error("Stage4BPost:DuplicateVariantSource", ...
        "Dataset variants contain duplicate source paths.");
end

manifest = sortrows(manifest, ["legacy_pre3day_v1", "sessionID"], ...
    ["descend", "ascend"]);

if any(legacyMembership & campaignMembership)
    error("Stage4BPost:VariantOverlap", ...
        "Legacy-16 and the 3-Day Campaign Increment must be disjoint.");
end

if ~isequal(expandedMembership, legacyMembership | campaignMembership)
    error("Stage4BPost:InvalidVariantUnion", ...
        "Expanded-3Day must equal the union of Legacy-16 and the campaign increment.");
end

end

function localWriteVariantManifest(config, variantManifest)
%LOCALWRITEVARIANTMANIFEST Write the durable source-membership table.

manifestFolder = fileparts(config.VariantManifestPath);

if strlength(manifestFolder) > 0 && ~isfolder(manifestFolder)
    mkdir(manifestFolder);
end

writetable(variantManifest, config.VariantManifestPath);

end

function localSaveIntegrationArtifact(config, integrationSummary)
%LOCALSAVEINTEGRATIONARTIFACT Save integration evidence for later review.

artifactFolder = fileparts(config.ArtifactPath);

if strlength(artifactFolder) > 0 && ~isfolder(artifactFolder)
    mkdir(artifactFolder);
end

save(config.ArtifactPath, "integrationSummary", "-v7.3");

end

function localWriteVariantSummary(config, integrationSummary)
%LOCALWRITEVARIANTSUMMARY Explain the immutable dataset variants.

summaryFolder = fileparts(config.VariantSummaryPath);

if strlength(summaryFolder) > 0 && ~isfolder(summaryFolder)
    mkdir(summaryFolder);
end

fid = fopen(config.VariantSummaryPath, "w");

if fid < 0
    error("Stage4BPost:VariantSummaryOpenFailed", ...
        "Unable to open variant summary: %s", config.VariantSummaryPath);
end

cleanup = onCleanup(@() fclose(fid));
manifest = integrationSummary.variantManifest;

fprintf(fid, "# ADS-B Dataset Variants\n\n");
fprintf(fid, "Generated: %s UTC\n\n", ...
    string(integrationSummary.generatedAt, "yyyy-MM-dd HH:mm:ss"));
fprintf(fid, "The raw archive is append-only. This manifest freezes source membership so each evaluation remains independently rerunnable.\n\n");
fprintf(fid, "| Variant ID | Display name | Truth files |\n");
fprintf(fid, "| :--- | :--- | ---: |\n");
fprintf(fid, "| `legacy_pre3day_v1` | Legacy-16 | %d |\n", ...
    sum(manifest.legacy_pre3day_v1));
fprintf(fid, "| `campaign_3day_increment_v1` | 3-Day Campaign Increment | %d |\n", ...
    sum(manifest.campaign_3day_increment_v1));
fprintf(fid, "| `expanded_post3day_v2` | Expanded-3Day | %d |\n\n", ...
    sum(manifest.expanded_post3day_v2));
fprintf(fid, "Transfer ZIP SHA-256: `%s`\n\n", integrationSummary.zipSHA256);
fprintf(fid, "No-truth campaign session retained for provenance: `%s`.\n\n", ...
    strjoin(integrationSummary.noTruthSessionIDs, "`, `"));
fprintf(fid, "Rerun with:\n\n");
fprintf(fid, "```matlab\n");
fprintf(fid, 'legacy = runADSBDatasetVariantEvaluation("legacy_pre3day_v1");\n');
fprintf(fid, 'increment = runADSBDatasetVariantEvaluation("campaign_3day_increment_v1");\n');
fprintf(fid, 'expanded = runADSBDatasetVariantEvaluation("expanded_post3day_v2");\n');
fprintf(fid, "comparison = runStage4BPostCampaignMotionDiversityGate;\n");
fprintf(fid, "```\n");

end

function sourceFiles = localDiscoverArchiveTruthFiles(archiveRoot)
%LOCALDISCOVERARCHIVETRUTHFILES Find packaged ADS-B truth files.

truthInfo = dir(fullfile( ...
    archiveRoot, ...
    "testing_machine", ...
    "captures", ...
    "*", ...
    "truth", ...
    "*.txt*"));
truthInfo = truthInfo(~[truthInfo.isdir]);
sourceFiles = sort(string(fullfile({truthInfo.folder}, {truthInfo.name})).');

end

function absolutePaths = localAbsoluteManifestPaths(projectRoot, relativePaths)
%LOCALABSOLUTEMANIFESTPATHS Resolve portable manifest paths.

relativePaths = replace(string(relativePaths), "/", filesep);
absolutePaths = fullfile(projectRoot, relativePaths);

end

function relativePaths = localRelativeProjectPaths(projectRoot, absolutePaths)
%LOCALRELATIVEPROJECTPATHS Store paths relative to the MATLAB project folder.

projectPrefix = char(string(projectRoot) + filesep);
relativePaths = strings(numel(absolutePaths), 1);

for pathIdx = 1:numel(absolutePaths)
    absolutePath = string(absolutePaths(pathIdx));

    if ~startsWith(lower(absolutePath), lower(projectPrefix))
        error("Stage4BPost:SourceOutsideProject", ...
            "Variant source file is outside the project root: %s", absolutePath);
    end

    relativePaths(pathIdx) = replace(erase(absolutePath, projectPrefix), "\", "/");
end

end

function captureTime = localCaptureTimeFromSession(sessionID)
%LOCALCAPTURETIMEFROMSESSION Parse legacy timestamp-style session IDs.

timestampText = regexp(char(sessionID), "\d{8}T\d{6}Z?", "match");

if isempty(timestampText)
    captureTime = NaT(1, 1, "TimeZone", "UTC");
    return;
end

timestampText = string(timestampText{end});

if endsWith(timestampText, "Z")
    inputFormat = "yyyyMMdd'T'HHmmss'Z'";
else
    inputFormat = "yyyyMMdd'T'HHmmss";
end

captureTime = datetime(timestampText, ...
    "InputFormat", ...
    inputFormat, ...
    "TimeZone", ...
    "UTC");

end

function localRemoveFolderIfPresent(folderPath)
%LOCALREMOVEFOLDERIFPRESENT Remove only the explicitly scoped temp folder.

if isfolder(folderPath)
    rmdir(folderPath, "s");
end

end
