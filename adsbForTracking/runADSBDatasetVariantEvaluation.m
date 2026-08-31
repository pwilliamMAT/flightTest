function summary = runADSBDatasetVariantEvaluation(variantID, varargin)
%RUNADSBDATASETVARIANTEVALUATION Evaluate one frozen ADS-B dataset variant.
% Source membership comes only from the hash-backed dataset-version
% manifest. The selected files are verified before the existing Stage 3C
% evaluation runs with the frozen Stage 3A model; this function never
% retrains the model.

variantID = localValidateVariantID(variantID);
variantDisplayName = localVariantDisplayName(variantID);
defaultProjectRoot = string(fileparts(mfilename("fullpath")));

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "ProjectRoot", defaultProjectRoot);
addParameter(parser, "VariantManifestPath", "");
addParameter(parser, "ArchiveRoot", "");
addParameter(parser, "OutputFolder", "");
addParameter(parser, "Stage3AArtifactPath", "");
addParameter(parser, "CreatePlots", true);
addParameter(parser, "Verbose", true);
parse(parser, varargin{:});

config = localBuildConfig(parser.Results, variantID);
localValidateConfig(config);

[sourceFiles, expectedHashes, manifestRows, manifestRowIndices] = ...
    localResolveVariantSources(config, variantID);

if config.Verbose
    fprintf("ADS-B dataset variant evaluation\n");
    fprintf("Variant:\t%s (%s)\n", variantDisplayName, variantID);
    fprintf("Manifest:\t%s\n", config.VariantManifestPath);
    fprintf("Verified source files:\t%d\n", numel(sourceFiles));
end

summary = runStage3CArchiveADSBEvaluation( ...
    "ProjectRoot", ...
    config.ProjectRoot, ...
    "ArchiveRoot", ...
    config.ArchiveRoot, ...
    "OutputFolder", ...
    config.OutputFolder, ...
    "SourceFiles", ...
    sourceFiles, ...
    "DatasetVariantID", ...
    variantID, ...
    "Stage3AArtifactPath", ...
    config.Stage3AArtifactPath, ...
    "CreatePlots", ...
    config.CreatePlots, ...
    "Verbose", ...
    config.Verbose);

summary.datasetVariantDisplayName = variantDisplayName;
summary.datasetVariantManifestPath = config.VariantManifestPath;
summary.datasetVariantManifestRows = manifestRows;
summary.datasetVariantManifestRowIndices = manifestRowIndices;
summary.datasetVariantSourceFiles = sourceFiles;
summary.datasetVariantSourceFileSHA256 = expectedHashes;
summary.datasetVariantSourceFileCount = numel(sourceFiles);
summary.retrainingRun = false;
summary.config.VariantManifestPath = config.VariantManifestPath;
summary.config.DatasetVariantDisplayName = variantDisplayName;

localUpdateStage3CArtifact(summary);

end

function variantID = localValidateVariantID(value)
%LOCALVALIDATEVARIANTID Require one of the three frozen dataset IDs.

if ~(ischar(value) && (isrow(value) || isempty(value))) && ...
        ~(isstring(value) && isscalar(value))
    error("ADSBDataVersion:InvalidVariantID", ...
        "variantID must be a character vector or string scalar.");
end

variantID = strtrim(string(value));
validVariantIDs = [ ...
    "legacy_pre3day_v1", ...
    "campaign_3day_increment_v1", ...
    "expanded_post3day_v2"];

if ismissing(variantID) || ~any(variantID == validVariantIDs)
    error("ADSBDataVersion:InvalidVariantID", ...
        "variantID must be legacy_pre3day_v1, " + ...
        "campaign_3day_increment_v1, or expanded_post3day_v2.");
end

end

function displayName = localVariantDisplayName(variantID)
%LOCALVARIANTDISPLAYNAME Return the durable human-readable variant name.

switch variantID
    case "legacy_pre3day_v1"
        displayName = "Legacy-16";
    case "campaign_3day_increment_v1"
        displayName = "3-Day Campaign Increment";
    case "expanded_post3day_v2"
        displayName = "Expanded-3Day";
end

end

function config = localBuildConfig(opts, variantID)
%LOCALBUILDCONFIG Resolve dependent defaults from the selected project root.

projectRoot = localTextScalar(opts.ProjectRoot, "ProjectRoot", false);
projectRoot = localCanonicalPath(projectRoot, "ProjectRoot");

config = struct();
config.ProjectRoot = projectRoot;
config.VariantManifestPath = localResolveOptionPath( ...
    projectRoot, ...
    opts.VariantManifestPath, ...
    fullfile("adsb_archive", "datasetVersions", "adsbDatasetVariants.csv"), ...
    "VariantManifestPath");
config.ArchiveRoot = localResolveOptionPath( ...
    projectRoot, ...
    opts.ArchiveRoot, ...
    fullfile("adsb_archive", "adsb_archive"), ...
    "ArchiveRoot");
config.OutputFolder = localResolveOptionPath( ...
    projectRoot, ...
    opts.OutputFolder, ...
    fullfile("artifacts", "stage4BPostCampaign", variantID), ...
    "OutputFolder");
config.Stage3AArtifactPath = localResolveOptionPath( ...
    projectRoot, ...
    opts.Stage3AArtifactPath, ...
    fullfile("artifacts", "stage3", "localADSBMLPStage3Training.mat"), ...
    "Stage3AArtifactPath");
config.CreatePlots = localLogicalScalar(opts.CreatePlots, "CreatePlots");
config.Verbose = localLogicalScalar(opts.Verbose, "Verbose");

end

function value = localTextScalar(value, argumentName, allowEmpty)
%LOCALTEXTSCALAR Normalize one path-like text argument.

isCharacterVector = ischar(value) && (isrow(value) || isempty(value));
isStringScalar = isstring(value) && isscalar(value);

if ~isCharacterVector && ~isStringScalar
    error("ADSBDataVersion:InvalidTextOption", ...
        "%s must be a character vector or string scalar.", argumentName);
end

value = strtrim(string(value));

if ismissing(value) || (~allowEmpty && strlength(value) == 0)
    error("ADSBDataVersion:InvalidTextOption", ...
        "%s must not be empty.", argumentName);
end

end

function value = localLogicalScalar(value, argumentName)
%LOCALLOGICALSCALAR Accept only scalar logical or numeric zero/one options.

isLogicalScalar = islogical(value) && isscalar(value);
isBinaryNumericScalar = isnumeric(value) && isscalar(value) && ...
    isreal(value) && isfinite(value) && (value == 0 || value == 1);

if ~isLogicalScalar && ~isBinaryNumericScalar
    error("ADSBDataVersion:InvalidLogicalOption", ...
        "%s must be a scalar logical value.", argumentName);
end

value = logical(value);

end

function resolvedPath = localResolveOptionPath( ...
        projectRoot, suppliedPath, defaultRelativePath, argumentName)
%LOCALRESOLVEOPTIONPATH Resolve empty and relative options from project root.

suppliedPath = localTextScalar(suppliedPath, argumentName, true);

if strlength(suppliedPath) == 0
    suppliedPath = defaultRelativePath;
end

if localIsAbsolutePath(suppliedPath)
    resolvedPath = suppliedPath;
else
    resolvedPath = fullfile(projectRoot, suppliedPath);
end

resolvedPath = localCanonicalPath(resolvedPath, argumentName);

end

function canonicalPath = localCanonicalPath(pathValue, argumentName)
%LOCALCANONICALPATH Normalize a path without requiring it to exist.

try
    fileObject = java.io.File(char(pathValue));
    canonicalPath = string(fileObject.getCanonicalPath());
catch err
    error("ADSBDataVersion:PathResolutionFailed", ...
        "Unable to resolve %s: %s", argumentName, err.message);
end

end

function tf = localIsAbsolutePath(pathValue)
%LOCALISABSOLUTEPATH Detect rooted Windows and POSIX paths.

normalizedPath = replace(string(pathValue), "\", "/");
tf = startsWith(normalizedPath, "/") || ...
    ~isempty(regexp(char(normalizedPath), "^[A-Za-z]:", "once"));

end

function localValidateConfig(config)
%LOCALVALIDATECONFIG Validate dependencies before hashing source data.

if ~isfolder(config.ProjectRoot)
    error("ADSBDataVersion:MissingProjectRoot", ...
        "Project root was not found: %s", config.ProjectRoot);
end

if exist(config.VariantManifestPath, "file") ~= 2
    error("ADSBDataVersion:MissingVariantManifest", ...
        "Dataset-variant manifest was not found: %s", ...
        config.VariantManifestPath);
end

if ~isfolder(config.ArchiveRoot)
    error("ADSBDataVersion:MissingArchiveRoot", ...
        "Archive root was not found: %s", config.ArchiveRoot);
end

if exist(config.Stage3AArtifactPath, "file") ~= 2
    error("ADSBDataVersion:MissingStage3AArtifact", ...
        "Frozen Stage 3A artifact was not found: %s", ...
        config.Stage3AArtifactPath);
end

if exist("helperComputeFileSHA256", "file") ~= 2
    error("ADSBDataVersion:MissingHashHelper", ...
        "helperComputeFileSHA256.m must be available on the MATLAB path.");
end

end

function [sourceFiles, expectedHashes, selectedManifest, selectedRowIndices] = ...
        localResolveVariantSources(config, variantID)
%LOCALRESOLVEVARIANTSOURCES Select, resolve, and hash-check one variant.

try
    manifest = readtable( ...
        config.VariantManifestPath, ...
        "TextType", ...
        "string");
catch err
    error("ADSBDataVersion:ManifestReadFailed", ...
        "Unable to read dataset-variant manifest %s: %s", ...
        config.VariantManifestPath, ...
        err.message);
end

requiredVariables = ["relativeSourceFile", "sourceFileSHA256", variantID];
manifestVariables = string(manifest.Properties.VariableNames);
missingVariables = requiredVariables(~ismember(requiredVariables, manifestVariables));

if ~isempty(missingVariables)
    error("ADSBDataVersion:InvalidManifestSchema", ...
        "Dataset-variant manifest is missing required column(s): %s", ...
        strjoin(missingVariables, ", "));
end

membership = localMembershipMask(manifest.(char(variantID)), variantID);
manifest.(char(variantID)) = membership;
selectedRowIndices = find(membership);
selectedManifest = manifest(membership, :);

if isempty(selectedRowIndices)
    error("ADSBDataVersion:EmptyVariant", ...
        "Dataset variant %s contains no source files.", variantID);
end

relativePaths = string(selectedManifest.relativeSourceFile);
expectedHashes = upper(strtrim(string(selectedManifest.sourceFileSHA256)));
sourceFiles = localResolveSourcePaths(config, relativePaths);
localValidateSourceUniqueness(relativePaths, sourceFiles, expectedHashes, variantID);
localVerifySourceFiles(sourceFiles, expectedHashes);

end

function membership = localMembershipMask(values, variantID)
%LOCALMEMBERSHIPMASK Convert a CSV membership column to validated logicals.

if islogical(values)
    membership = values;
elseif isnumeric(values)
    if ~isreal(values) || any(~isfinite(values(:))) || ...
            any(values(:) ~= 0 & values(:) ~= 1)
        error("ADSBDataVersion:InvalidMembership", ...
            "Membership column %s must contain only true/false or 1/0.", ...
            variantID);
    end

    membership = logical(values);
elseif isstring(values) || iscellstr(values) || iscategorical(values)
    textValues = lower(strtrim(string(values)));
    isTrue = textValues == "true" | textValues == "1";
    isFalse = textValues == "false" | textValues == "0";

    if any(ismissing(textValues)) || any(~isTrue & ~isFalse)
        error("ADSBDataVersion:InvalidMembership", ...
            "Membership column %s must contain only true/false or 1/0.", ...
            variantID);
    end

    membership = isTrue;
else
    error("ADSBDataVersion:InvalidMembership", ...
        "Membership column %s has an unsupported data type.", variantID);
end

membership = membership(:);

end

function sourceFiles = localResolveSourcePaths(config, relativePaths)
%LOCALRESOLVESOURCEPATHS Resolve portable manifest paths under the archive.

sourceFiles = strings(numel(relativePaths), 1);

for sourceIdx = 1:numel(relativePaths)
    relativePath = strtrim(relativePaths(sourceIdx));

    if ismissing(relativePath) || strlength(relativePath) == 0
        error("ADSBDataVersion:InvalidRelativePath", ...
            "Manifest row %d has an empty relative source path.", sourceIdx);
    end

    normalizedPath = replace(relativePath, "\", "/");
    pathParts = split(normalizedPath, "/");

    if localIsAbsolutePath(normalizedPath) || any(pathParts == "..")
        error("ADSBDataVersion:InvalidRelativePath", ...
            "Manifest source paths must be project-relative: %s", ...
            relativePath);
    end

    candidatePath = fullfile( ...
        config.ProjectRoot, ...
        replace(normalizedPath, "/", filesep));
    sourcePath = localCanonicalPath(candidatePath, "relativeSourceFile");

    if ~localPathIsWithinRoot(sourcePath, config.ProjectRoot)
        error("ADSBDataVersion:SourceOutsideProject", ...
            "Manifest source resolves outside the project root: %s", ...
            relativePath);
    end

    if ~localPathIsWithinRoot(sourcePath, config.ArchiveRoot)
        error("ADSBDataVersion:SourceOutsideArchive", ...
            "Manifest source resolves outside the configured archive: %s", ...
            relativePath);
    end

    sourceFiles(sourceIdx) = sourcePath;
end

end

function tf = localPathIsWithinRoot(pathValue, rootValue)
%LOCALPATHISWITHINROOT Compare canonical paths at a directory boundary.

pathText = string(pathValue);
rootText = string(rootValue);

if ispc
    pathText = lower(pathText);
    rootText = lower(rootText);
end

tf = pathText == rootText || startsWith(pathText, rootText + filesep);

end

function localValidateSourceUniqueness( ...
        relativePaths, sourceFiles, expectedHashes, variantID)
%LOCALVALIDATESOURCEUNIQUENESS Reject duplicate paths or file identities.

relativePathKeys = replace(strtrim(relativePaths), "\", "/");
sourcePathKeys = sourceFiles;

if ispc
    relativePathKeys = lower(relativePathKeys);
    sourcePathKeys = lower(sourcePathKeys);
end

if numel(unique(relativePathKeys)) ~= numel(relativePathKeys) || ...
        numel(unique(sourcePathKeys)) ~= numel(sourcePathKeys)
    error("ADSBDataVersion:DuplicateSourcePath", ...
        "Dataset variant %s contains duplicate source paths.", variantID);
end

for hashIdx = 1:numel(expectedHashes)
    if isempty(regexp(char(expectedHashes(hashIdx)), ...
            "^[0-9A-F]{64}$", "once"))
        error("ADSBDataVersion:InvalidSourceHash", ...
            "Manifest row for %s has an invalid SHA-256 value.", ...
            relativePaths(hashIdx));
    end
end

if numel(unique(expectedHashes)) ~= numel(expectedHashes)
    error("ADSBDataVersion:DuplicateSourceHash", ...
        "Dataset variant %s contains duplicate source-file hashes.", ...
        variantID);
end

end

function localVerifySourceFiles(sourceFiles, expectedHashes)
%LOCALVERIFYSOURCEFILES Require each selected source and its frozen digest.

for sourceIdx = 1:numel(sourceFiles)
    sourceFile = sourceFiles(sourceIdx);

    if exist(sourceFile, "file") ~= 2
        error("ADSBDataVersion:MissingSourceFile", ...
            "Dataset-variant source file was not found: %s", sourceFile);
    end

    observedHash = helperComputeFileSHA256(sourceFile);

    if ~strcmpi(observedHash, expectedHashes(sourceIdx))
        error("ADSBDataVersion:SourceHashMismatch", ...
            "SHA-256 mismatch for %s. Expected %s but observed %s.", ...
            sourceFile, ...
            expectedHashes(sourceIdx), ...
            observedHash);
    end
end

end

function localUpdateStage3CArtifact(summary)
%LOCALUPDATESTAGE3CARTIFACT Persist wrapper metadata in the Stage 3C artifact.

if exist(summary.artifactPath, "file") ~= 2
    error("ADSBDataVersion:MissingStage3CArtifact", ...
        "Stage 3C did not create its expected artifact: %s", ...
        summary.artifactPath);
end

stage3CSummary = summary;

try
    save(summary.artifactPath, "stage3CSummary", "-append");
catch err
    error("ADSBDataVersion:ArtifactUpdateFailed", ...
        "Unable to add dataset-variant metadata to %s: %s", ...
        summary.artifactPath, ...
        err.message);
end

end
