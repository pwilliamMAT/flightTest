function [adsb_bistatic, adsb_aligned, projection_table] = ...
    helperProjectADSBTruthToRangeDoppler( ...
    adsb_tracks, txLLA, rxLLA, fc, radar_epoch_utc, query_times_s)
%HELPERPROJECTADSBTRUTHTORANGEDOPPLER Project ADS-B truth to range-Doppler query points.
%
% Plain language:
% This helper keeps the authoritative passive-bistatic math in one place.
% It first projects the ADS-B tracks into bistatic range excess and Doppler
% using adsbToBistatic, then aligns those projected tracks onto the radar
% query-time grid with alignTruthToRadar. The final flat table is intended
% for validation, spot checks, and other consumers that want one row per
% target per query time without reimplementing the shared geometry or
% interpolation logic.

validateattributes(adsb_tracks, {'struct'}, {}, mfilename, 'adsb_tracks');
validateattributes(txLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, mfilename, 'txLLA');
validateattributes(rxLLA, {'numeric'}, {'numel', 3, 'real', 'finite'}, mfilename, 'rxLLA');
validateattributes(fc, {'numeric'}, {'scalar', 'real', 'finite', 'positive'}, mfilename, 'fc');
validateattributes(query_times_s, {'numeric'}, {'vector', 'real', 'finite'}, mfilename, 'query_times_s');

if isdatetime(radar_epoch_utc)
    if isempty(radar_epoch_utc.TimeZone)
        radar_epoch_utc.TimeZone = 'UTC';
    end
    radar_epoch_utc = posixtime(radar_epoch_utc);
end
validateattributes(radar_epoch_utc, {'numeric'}, {'scalar', 'real', 'finite'}, ...
    mfilename, 'radar_epoch_utc');

query_times_s = double(query_times_s(:));

adsb_bistatic = adsbToBistatic( ...
    adsb_tracks, ...
    txLLA, ...
    rxLLA, ...
    double(fc));
adsb_aligned = alignTruthToRadar( ...
    adsb_bistatic, ...
    double(radar_epoch_utc), ...
    query_times_s);
projection_table = localBuildProjectionTable(adsb_aligned, query_times_s);
end

function projection_table = localBuildProjectionTable(adsb_aligned, query_times_s)
n_tracks = numel(adsb_aligned);
n_query_times = numel(query_times_s);
n_rows = n_tracks * n_query_times;

hex = strings(n_rows, 1);
callsign = strings(n_rows, 1);
query_time_s = NaN(n_rows, 1);
R_excess_m = NaN(n_rows, 1);
f_D_hz = NaN(n_rows, 1);
valid = false(n_rows, 1);

row_offset = 0;
for idx = 1 : n_tracks
    row_idx = row_offset + (1 : n_query_times);
    track = adsb_aligned(idx);

    hex(row_idx) = repmat(string(track.hex), n_query_times, 1);
    callsign(row_idx) = repmat(string(track.callsign), n_query_times, 1);
    query_time_s(row_idx) = double(query_times_s);
    R_excess_m(row_idx) = double(track.R_excess_m(:));
    f_D_hz(row_idx) = double(track.f_D_hz(:));
    valid(row_idx) = isfinite(track.R_excess_m(:)) & isfinite(track.f_D_hz(:));

    row_offset = row_offset + n_query_times;
end

projection_table = table( ...
    hex, ...
    callsign, ...
    query_time_s, ...
    R_excess_m, ...
    f_D_hz, ...
    valid, ...
    'VariableNames', { ...
        'hex', ...
        'callsign', ...
        'query_time_s', ...
        'R_excess_m', ...
        'f_D_hz', ...
        'valid'});
end
