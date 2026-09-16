function sourceInfo = helperResolvePassiveRadarPrecheckSources(source, options)
%HELPERRESOLVEPASSIVERADARPRECHECKSOURCES Resolve offline precheck inputs.
%
% SOURCE may identify one or more capture files, a packaged-session folder,
% a session manifest, or a session ID beneath DatasetRoot.

arguments
    source {mustBeText}
    options.DatasetRoot (1, 1) string = ""
    options.PartIndices (1, :) double {mustBeInteger, mustBePositive} = []
end

source = string(source);
source = source(strlength(source) > 0);
if isempty(source)
    error("runPassiveRadarHardwarePrecheck:missingSource", ...
        "Offline mode requires config.Source.");
end

if numel(source) > 1
    if ~all(isfile(source))
        error("runPassiveRadarHardwarePrecheck:sourceNotFound", ...
            "Every element of a multi-file source must identify an existing capture file.");
    end
    sourceInfo = localDirectFileInfo(source);
    sourceInfo = localSelectParts(sourceInfo, options.PartIndices);
    return
end

sourceText = source(1);
if isfile(sourceText)
    if endsWith(sourceText, ".json", IgnoreCase=true)
        sourceInfo = localManifestInfo(sourceText);
    else
        sourceInfo = localDirectFileInfo(sourceText);
    end
elseif isfolder(sourceText)
    sourceInfo = localManifestInfo(fullfile(sourceText, "session_manifest.json"));
else
    if strlength(options.DatasetRoot) == 0
        error("runPassiveRadarHardwarePrecheck:sourceNotFound", ...
            "Source does not identify an existing file or folder: %s", sourceText);
    end
    manifestPath = fullfile(options.DatasetRoot, sourceText, "session_manifest.json");
    sourceInfo = localManifestInfo(manifestPath);
end

sourceInfo = localSelectParts(sourceInfo, options.PartIndices);
end

function sourceInfo = localDirectFileInfo(filePaths)
nFiles = numel(filePaths);
sourceInfo = repmat(localEmptySourceInfo(), nFiles, 1);
for fileIndex = 1:nFiles
    sourceInfo(fileIndex).File = localAbsolutePath(filePaths(fileIndex));
    sourceInfo(fileIndex).SourceKind = "capture_file";
    sourceInfo(fileIndex).PartIndex = localInferPartIndex(filePaths(fileIndex));
end
end

function partIndex = localInferPartIndex(filePath)
[~, fileName, extension] = fileparts(filePath);
tokens = regexp(char(fileName + extension), ...
    "part(\d+)(?:\.[^\\/.]+)?$", "tokens", "once");
partIndex = 0;
if ~isempty(tokens)
    partIndex = str2double(tokens{1});
end
end

function sourceInfo = localManifestInfo(manifestPath)
manifestPath = localAbsolutePath(manifestPath);
if ~isfile(manifestPath)
    error("runPassiveRadarHardwarePrecheck:missingManifest", ...
        "Session manifest not found: %s", manifestPath);
end

try
    manifest = jsondecode(fileread(manifestPath));
catch exception
    error("runPassiveRadarHardwarePrecheck:invalidManifest", ...
        "Could not parse session manifest %s: %s", manifestPath, exception.message);
end

if ~isfield(manifest, "session_id") || strlength(string(manifest.session_id)) == 0
    error("runPassiveRadarHardwarePrecheck:missingSessionID", ...
        "Session manifest is missing session_id: %s", manifestPath);
end
if ~isfield(manifest, "radar_files") || isempty(manifest.radar_files)
    error("runPassiveRadarHardwarePrecheck:missingRadarFiles", ...
        "Session manifest must list at least one radar file: %s", manifestPath);
end

radarFiles = string(manifest.radar_files);
radarFiles = radarFiles(:);
sessionFolder = string(fileparts(manifestPath));
nFiles = numel(radarFiles);
sourceInfo = repmat(localEmptySourceInfo(), nFiles, 1);

for fileIndex = 1:nFiles
    radarFile = radarFiles(fileIndex);
    if ~localIsAbsolutePath(radarFile)
        radarFile = fullfile(sessionFolder, radarFile);
    end
    if ~isfile(radarFile)
        error("runPassiveRadarHardwarePrecheck:missingRadarFile", ...
            "Radar file listed in the manifest was not found: %s", radarFile);
    end

    sourceInfo(fileIndex).File = localAbsolutePath(radarFile);
    sourceInfo(fileIndex).SourceKind = "packaged_session";
    sourceInfo(fileIndex).SessionID = string(manifest.session_id);
    sourceInfo(fileIndex).PartIndex = fileIndex;
    sourceInfo(fileIndex).ManifestPath = manifestPath;
    sourceInfo(fileIndex).SessionFolder = sessionFolder;
    sourceInfo(fileIndex).Manifest = manifest;
end
end

function selected = localSelectParts(sourceInfo, partIndices)
if isempty(partIndices)
    selected = sourceInfo;
    return
end
if any(partIndices > numel(sourceInfo))
    error("runPassiveRadarHardwarePrecheck:partIndexOutOfRange", ...
        "PartIndices exceed the %d available capture file(s).", numel(sourceInfo));
end
selected = sourceInfo(unique(partIndices, "stable"));
end

function sourceInfo = localEmptySourceInfo()
sourceInfo = struct( ...
    "File", "", ...
    "SourceKind", "", ...
    "SessionID", "", ...
    "PartIndex", 0, ...
    "ManifestPath", "", ...
    "SessionFolder", "", ...
    "Manifest", struct());
end

function absolutePath = localAbsolutePath(filePath)
filePath = string(filePath);
if localIsAbsolutePath(filePath)
    absolutePath = filePath;
else
    absolutePath = string(fullfile(pwd, filePath));
end
end

function tf = localIsAbsolutePath(filePath)
filePath = char(string(filePath));
if ispc
    tf = ~isempty(regexp(filePath, "^[A-Za-z]:[\\/]", "once")) || ...
        startsWith(filePath, "\\");
else
    tf = startsWith(filePath, filesep);
end
end
