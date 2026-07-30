function merged_tracks = helperTriggerMergeTracks(existing_tracks, new_tracks)
%HELPERTRIGGERMERGETRACKS Merge incremental ADS-B track updates by ICAO hex.
%
% Plain-language goal:
%   The trigger loop reads short rotating ADS-B files. This helper keeps a
%   rolling cache so each poll only needs to merge in the newly arrived
%   fixes instead of reparsing the full session history every time.

if isempty(existing_tracks)
    merged_tracks = new_tracks;
    return
end

if isempty(new_tracks)
    merged_tracks = existing_tracks;
    return
end

merged_tracks = existing_tracks;
track_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
for idx = 1:numel(merged_tracks)
    track_map(char(string(merged_tracks(idx).hex))) = idx;
end

for idx = 1:numel(new_tracks)
    track_hex = char(string(new_tracks(idx).hex));
    if ~isKey(track_map, track_hex)
        merged_tracks(end + 1) = new_tracks(idx); %#ok<AGROW>
        track_map(track_hex) = numel(merged_tracks);
        continue
    end

    merged_idx = track_map(track_hex);
    merged_tracks(merged_idx) = localMergeOneTrack(merged_tracks(merged_idx), new_tracks(idx));
end

end

function merged_track = localMergeOneTrack(track_a, track_b)
merged_track = track_a;

if strlength(string(track_b.callsign)) > 0
    merged_track.callsign = track_b.callsign;
end

vector_fields = {'t_utc', 'lat_deg', 'lon_deg', 'alt_m', 'speed_mps', 'track_deg', 'vrate_mps'};
merged_fields = struct();
for idx = 1:numel(vector_fields)
    field_name = vector_fields{idx};
    merged_fields.(field_name) = [track_a.(field_name)(:); track_b.(field_name)(:)];
end

[sorted_time, sort_order] = sort(merged_fields.t_utc(:));
merged_fields.t_utc = sorted_time;
for idx = 2:numel(vector_fields)
    field_name = vector_fields{idx};
    merged_fields.(field_name) = merged_fields.(field_name)(sort_order);
end

[~, unique_idx] = unique(merged_fields.t_utc, 'stable');
for idx = 1:numel(vector_fields)
    field_name = vector_fields{idx};
    merged_track.(field_name) = merged_fields.(field_name)(unique_idx);
end

end
