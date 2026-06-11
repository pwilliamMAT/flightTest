function manifest = helperLoadSessionManifest(manifest_path)
%HELPERLOADSESSIONMANIFEST Read and normalize one packaged session manifest.

manifest_path = char(string(manifest_path));
if exist(manifest_path, 'file') ~= 2
    error('helperLoadSessionManifest:missingManifest', ...
        'Session manifest not found: %s', manifest_path);
end

try
    manifest = jsondecode(fileread(manifest_path));
catch me_json
    error('helperLoadSessionManifest:badJson', ...
        'Could not parse session manifest %s: %s', manifest_path, me_json.message);
end

if ~isfield(manifest, 'session_id') || strlength(string(manifest.session_id)) == 0
    error('helperLoadSessionManifest:missingSessionID', ...
        'Session manifest %s is missing session_id.', manifest_path);
end

if ~isfield(manifest, 'radar_files')
    error('helperLoadSessionManifest:missingRadarFiles', ...
        'Session manifest %s is missing radar_files.', manifest_path);
end

manifest.session_id = char(string(manifest.session_id));
manifest.radar_files = helperManifestStringsToCell(manifest.radar_files);
if isempty(manifest.radar_files)
    error('helperLoadSessionManifest:emptyRadarFiles', ...
        'Session manifest %s must list at least one radar file.', manifest_path);
end

if isfield(manifest, 'adsb_files')
    manifest.adsb_files = helperManifestStringsToCell(manifest.adsb_files);
else
    manifest.adsb_files = {};
end

if isfield(manifest, 'log_files')
    manifest.log_files = helperManifestStringsToCell(manifest.log_files);
else
    manifest.log_files = {};
end

if isfield(manifest, 'radar_epoch_utc')
    if isempty(manifest.radar_epoch_utc) || (isnumeric(manifest.radar_epoch_utc) && isnan(manifest.radar_epoch_utc))
        manifest.radar_epoch_utc = [];
    elseif ~isnumeric(manifest.radar_epoch_utc)
        manifest.radar_epoch_utc = str2double(string(manifest.radar_epoch_utc));
        if ~isfinite(manifest.radar_epoch_utc)
            manifest.radar_epoch_utc = [];
        end
    end
else
    manifest.radar_epoch_utc = [];
end
end

function values = helperManifestStringsToCell(raw_value)
% Normalize jsondecode string-or-array fields to a cell array of char paths.

if isempty(raw_value)
    values = {};
elseif ischar(raw_value) || (isstring(raw_value) && isscalar(raw_value))
    values = {char(string(raw_value))};
elseif isstring(raw_value)
    values = cellstr(raw_value(:));
elseif iscell(raw_value)
    values = cellfun(@(x) char(string(x)), raw_value(:), 'UniformOutput', false);
else
    error('helperLoadSessionManifest:badStringField', ...
        'Manifest path lists must decode to char, string, or cell arrays of strings.');
end
end
