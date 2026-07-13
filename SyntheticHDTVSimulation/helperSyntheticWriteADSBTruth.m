function helperSyntheticWriteADSBTruth(output_path, adsb_tracks)
%HELPERSYNTHETICWRITEADSBTRUTH Write SBS-1-compatible truth records.

validateattributes(output_path, {'char', 'string'}, {'scalartext'}, mfilename, 'output_path');
validateattributes(adsb_tracks, {'struct'}, {}, mfilename, 'adsb_tracks');

output_path = char(string(output_path));
[parent_dir, ~, ~] = fileparts(output_path);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') ~= 7
    error('helperSyntheticWriteADSBTruth:missingParentFolder', ...
        'Parent folder does not exist: %s', parent_dir);
end

fid = fopen(output_path, 'w');
if fid < 0
    error('helperSyntheticWriteADSBTruth:fileOpenFailed', ...
        'Could not open %s for writing.', output_path);
end

cleanup_fid = onCleanup(@() fclose(fid)); %#ok<NASGU>

for idx = 1 : numel(adsb_tracks)
    track = adsb_tracks(idx);
    if isempty(track.t_utc)
        continue
    end

    [date_str, time_str] = localDateTimeStrings(track.t_utc(1));
    fprintf(fid, 'MSG,1,1,1,%s,1,%s,%s,%s,%s,%s,,,,,,,,,,\n', ...
        track.hex, date_str, time_str, date_str, time_str, track.callsign);

    altitude_ft = round(track.alt_m / 0.3048);
    speed_kts = round(track.speed_mps / 0.5144444);
    track_deg = round(track.track_deg);
    vrate_fpm = round(track.vrate_mps / 0.00508);

    for sample_idx = 1 : numel(track.t_utc)
        [date_str, time_str] = localDateTimeStrings(track.t_utc(sample_idx));

        fprintf(fid, 'MSG,3,1,1,%s,1,%s,%s,%s,%s,,%d,,,%s,%s,,,,%d\n', ...
            track.hex, ...
            date_str, ...
            time_str, ...
            date_str, ...
            time_str, ...
            altitude_ft(sample_idx), ...
            sprintf('%.6f', track.lat_deg(sample_idx)), ...
            sprintf('%.6f', track.lon_deg(sample_idx)), ...
            vrate_fpm(sample_idx));

        fprintf(fid, 'MSG,4,1,1,%s,1,%s,%s,%s,%s,,,%d,%d,,0,,%d\n', ...
            track.hex, ...
            date_str, ...
            time_str, ...
            date_str, ...
            time_str, ...
            speed_kts(sample_idx), ...
            track_deg(sample_idx), ...
            vrate_fpm(sample_idx));
    end
end
end

function [date_str, time_str] = localDateTimeStrings(t_utc)
dt = datetime(t_utc, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
date_str = sprintf('%04d/%02d/%02d', year(dt), month(dt), day(dt));
time_str = sprintf('%02d:%02d:%06.3f', hour(dt), minute(dt), second(dt));
end
