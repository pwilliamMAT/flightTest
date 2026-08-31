function cache = helperTriggerUpdateTrackCache(cache, stage_dir, varargin)
%HELPERTRIGGERUPDATETRACKCACHE Ingest any newly staged ADS-B files.
%
% Plain-language goal:
%   The shell coordinator keeps copying completed ADS-B files into a local
%   staging folder. MATLAB polls that folder, loads only the files it has
%   not seen before, and merges the resulting tracks into one rolling cache.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'cache', @isstruct);
addRequired(p, 'stage_dir', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', false, @islogical);
parse(p, cache, stage_dir, varargin{:});
opts = p.Results;

stage_dir = string(stage_dir);
cache = localEnsureCacheShape(cache);
cache.last_ingested_files = strings(0, 1);
cache.last_errors = strings(0, 1);
cache.stage_dir = stage_dir;

if strlength(stage_dir) == 0 || exist(stage_dir, 'dir') ~= 7
    cache.last_stage_files = strings(0, 1);
    cache.stage_file_count = 0;
    return
end

pattern_hits = [ ...
    dir(fullfile(stage_dir, '*adsb_*.txt')); ...
    dir(fullfile(stage_dir, '*adsb_*.txt.gz'))];

if isempty(pattern_hits)
    cache.last_stage_files = strings(0, 1);
    cache.stage_file_count = 0;
    return
end

stage_files = string(fullfile(stage_dir, {pattern_hits.name}));
stage_files = unique(stage_files(:), 'stable');

cache.last_stage_files = stage_files;
cache.stage_file_count = numel(stage_files);

new_files = stage_files(~ismember(stage_files, cache.processed_files));
if isempty(new_files)
    return
end

for idx = 1:numel(new_files)
    adsb_file = new_files(idx);
    try
        loaded_tracks = loadADSBTruth({char(adsb_file)}, 'Verbose', opts.Verbose);
        cache.adsb_tracks = helperTriggerMergeTracks(cache.adsb_tracks, loaded_tracks);
        cache.processed_files(end + 1, 1) = adsb_file; %#ok<AGROW>
        cache.last_ingested_files(end + 1, 1) = adsb_file; %#ok<AGROW>
    catch me_load
        cache.last_errors(end + 1, 1) = string(me_load.message); %#ok<AGROW>
        if opts.Verbose
            warning('helperTriggerUpdateTrackCache:loadFailed', ...
                'Could not load %s: %s', char(adsb_file), me_load.message);
        end
    end
end

cache.updated_utc = datetime('now', 'TimeZone', 'UTC');

end

function cache = localEnsureCacheShape(cache)
if ~isfield(cache, 'processed_files') || isempty(cache.processed_files)
    cache.processed_files = strings(0, 1);
end
if ~isfield(cache, 'adsb_tracks') || isempty(cache.adsb_tracks)
    cache.adsb_tracks = struct([]);
end
if ~isfield(cache, 'last_stage_files')
    cache.last_stage_files = strings(0, 1);
end
if ~isfield(cache, 'last_ingested_files')
    cache.last_ingested_files = strings(0, 1);
end
if ~isfield(cache, 'last_errors')
    cache.last_errors = strings(0, 1);
end
if ~isfield(cache, 'stage_file_count')
    cache.stage_file_count = 0;
end
if ~isfield(cache, 'updated_utc')
    cache.updated_utc = datetime.empty(0, 1);
end
end
