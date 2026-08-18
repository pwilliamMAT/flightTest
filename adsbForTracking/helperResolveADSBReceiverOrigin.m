function [receiverOriginLLA, originInfo] = helperResolveADSBReceiverOrigin(sourceFile, defaultReceiverOriginLLA)
%HELPERRESOLVEADSBRERECEIVERORIGIN Resolve the ENU origin for one source.
% The preferred origin comes from packaged session metadata. If a manifest
% does not contain receiver LLA fields, the caller-provided fallback is used
% and recorded in originInfo.

sourceFile = string(sourceFile);
defaultReceiverOriginLLA = double(defaultReceiverOriginLLA);

validateattributes(defaultReceiverOriginLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, ...
    mfilename, "defaultReceiverOriginLLA");

originInfo = struct();
originInfo.sessionID = localSessionIdFromPath(sourceFile);
originInfo.sessionRoot = localSessionRootFromPath(sourceFile);
originInfo.manifestPath = "";
originInfo.source = "default";
originInfo.fieldName = "";
originInfo.message = "Receiver LLA not found in session metadata; fallback origin used.";

receiverOriginLLA = defaultReceiverOriginLLA(:).';

if strlength(originInfo.sessionRoot) == 0
    return;
end

manifestPath = fullfile(originInfo.sessionRoot, "session_manifest.json");

if exist(manifestPath, "file") ~= 2
    return;
end

originInfo.manifestPath = string(manifestPath);

try
    manifestText = fileread(manifestPath);
    manifest = jsondecode(manifestText);
    [candidateLLA, fieldName] = localFindReceiverLLA(manifest, "");

    if ~isempty(candidateLLA)
        receiverOriginLLA = candidateLLA(:).';
        originInfo.source = "session_manifest";
        originInfo.fieldName = fieldName;
        originInfo.message = "Receiver LLA read from session metadata.";
    end
catch err
    originInfo.source = "default_after_manifest_error";
    originInfo.message = string(err.message);
end

end

function sessionID = localSessionIdFromPath(sourceFile)
%LOCALSESSIONIDFROMPATH Extract captures/<sessionID>/... when present.

sourceFile = string(sourceFile);
pathParts = split(sourceFile, filesep);
captureIdx = find(strcmpi(pathParts, "captures"), 1, "last");

if ~isempty(captureIdx) && captureIdx < numel(pathParts)
    sessionID = pathParts(captureIdx + 1);
    return;
end

truthIdx = find(strcmpi(pathParts, "truth"), 1, "last");

if ~isempty(truthIdx) && truthIdx > 1
    sessionID = pathParts(truthIdx - 1);
    return;
end

sessionID = "unknown";

end

function sessionRoot = localSessionRootFromPath(sourceFile)
%LOCALSESSIONROOTFROMPATH Return the packaged session root when present.

sourceFile = string(sourceFile);
pathParts = split(sourceFile, filesep);
captureIdx = find(strcmpi(pathParts, "captures"), 1, "last");

if ~isempty(captureIdx) && captureIdx < numel(pathParts)
    sessionRootParts = cellstr(pathParts(1:captureIdx + 1));
    sessionRoot = string(fullfile(sessionRootParts{:}));
    return;
end

truthIdx = find(strcmpi(pathParts, "truth"), 1, "last");

if ~isempty(truthIdx) && truthIdx > 1
    sessionRootParts = cellstr(pathParts(1:truthIdx - 1));
    sessionRoot = string(fullfile(sessionRootParts{:}));
    return;
end

sessionRoot = "";

end

function [receiverLLA, fieldName] = localFindReceiverLLA(value, prefix)
%LOCALFINDRECEIVERLLA Recursively search manifest structs for receiver LLA.

receiverLLA = [];
fieldName = "";

if isnumeric(value) && numel(value) == 3 && all(isfinite(value(:)))
    if localLooksLikeReceiverField(prefix)
        receiverLLA = double(value(:).');
        fieldName = string(prefix);
    end

    return;
end

if ~isstruct(value)
    return;
end

fields = string(fieldnames(value));

for fieldIdx = 1:numel(fields)
    field = fields(fieldIdx);
    child = value.(field);

    if strlength(prefix) == 0
        childPrefix = field;
    else
        childPrefix = prefix + "." + field;
    end

    [receiverLLA, fieldName] = localFindReceiverLLA(child, childPrefix);

    if ~isempty(receiverLLA)
        return;
    end
end

end

function tf = localLooksLikeReceiverField(fieldName)
%LOCALLOOKSLIKERECEIVERFIELD Match common receiver-origin field names.

fieldNameLower = lower(string(fieldName));
hasReceiverToken = contains(fieldNameLower, "rx") || contains(fieldNameLower, "receiver");
hasLocationToken = contains(fieldNameLower, "lla") || ...
    contains(fieldNameLower, "origin") || ...
    contains(fieldNameLower, "location");
tf = hasReceiverToken && hasLocationToken;

end
