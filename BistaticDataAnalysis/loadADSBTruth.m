function adsb_tracks = loadADSBTruth(filenames, varargin)
%LOADADSBTRUTH  Parse SBS-1/BaseStation ADS-B files (dump1090 TCP port 30003)
%  into a per-aircraft struct array ready for bistatic truth comparison.
%
% ── BACKGROUND ──────────────────────────────────────────────────────────
%  dump1090 (or dump1090-fa) outputs ADS-B decoded data on TCP port 30003
%  in the SBS-1 / BaseStation comma-separated format.  The logger
%  gatherTCPcompress.py captures this stream to rotating text files
%  (optionally gzip-compressed) named adsb_YYYYMMDD_HHMMSS.txt[.gz].
%
%  Each line is a MSG record with up to 22 comma-separated fields.
%  The three most useful message transmission types are:
%
%    MSG,1 — Aircraft identification: callsign
%    MSG,3 — Airborne position: latitude, longitude, barometric altitude
%    MSG,4 — Airborne velocity: groundspeed, track angle, vertical rate
%
%  Position (MSG,3) and velocity (MSG,4) messages arrive on separate
%  transponder squitter cycles (~0.5–2 Hz each for cooperative targets).
%  This function merges them onto a common time grid per aircraft.
%
% ── SBS-1 FIELD MAP ─────────────────────────────────────────────────────
%   Field   Content (MSG,3 / MSG,4 where relevant)
%   ─────   ───────────────────────────────────────
%    1      "MSG" (literal)
%    2      Transmission type  (1=ID, 3=position+alt, 4=velocity)
%    5      ICAO hex address   (24-bit aircraft identifier)
%    7      Date generated     (YYYY/MM/DD)
%    8      Time generated     (HH:MM:SS.mmm)
%   11      Callsign           (MSG,1)
%   12      Altitude [ft]      (MSG,3, barometric)
%   13      Groundspeed [kts]  (MSG,4)
%   14      Track angle [deg]  (MSG,4, true North)
%   15      Latitude [deg]     (MSG,3)
%   16      Longitude [deg]    (MSG,3)
%   17      Vertical rate [ft/min] (MSG,4, positive = climbing)
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   adsb_tracks = loadADSBTruth(filenames)
%   adsb_tracks = loadADSBTruth(filenames, 'Verbose', true)
%
% ── INPUTS ──────────────────────────────────────────────────────────────
%   filenames   String, char array, or cell array of strings.
%               Each element is a path to an SBS-1 file (.txt or .txt.gz).
%               Gzip-compressed files are decompressed automatically to a
%               system temp directory and cleaned up after loading.
%
% ── OUTPUTS ─────────────────────────────────────────────────────────────
%   adsb_tracks   Struct array [1 × N_aircraft].  One element per unique
%                 ICAO hex address found in the input files.  Fields:
%
%     .hex           char   — 6-hex-digit ICAO 24-bit address
%     .callsign      char   — most recent callsign (empty if never seen)
%     .t_utc         [M×1]  — UTC epoch seconds (posixtime) at each fix
%     .lat_deg       [M×1]  — WGS-84 latitude  [°]
%     .lon_deg       [M×1]  — WGS-84 longitude [°]
%     .alt_m         [M×1]  — barometric altitude [m MSL]
%     .speed_mps     [M×1]  — groundspeed [m/s], NaN if MSG,4 absent
%     .track_deg     [M×1]  — true-North track angle [°], NaN if absent
%     .vrate_mps     [M×1]  — vertical rate [m/s], NaN if absent
%
%   Returns an empty struct array (0×0) if no valid position fixes are found.
%
% ── UNIT CONVERSIONS ────────────────────────────────────────────────────
%   altitude  : ft  → m    via × 0.3048
%   speed     : kts → m/s  via × 0.5144
%   vert rate : ft/min → m/s via × 0.00508
%
% ── TOOLBOX REQUIREMENTS ────────────────────────────────────────────────
%   Base MATLAB only (no toolboxes required).
%
% ── EXAMPLE ─────────────────────────────────────────────────────────────
%   tracks = loadADSBTruth({'adsb_20260705_142500.txt.gz', ...
%                           'adsb_20260705_145500.txt.gz'});
%   fprintf('%d aircraft found.\n', numel(tracks));
%   fprintf('  %s  %s  %d fixes\n', tracks(1).hex, tracks(1).callsign, ...
%           numel(tracks(1).t_utc));
%
% See also: getRadarEpoch, adsbToBistatic, alignTruthToRadar.

% =========================================================================
%  0.  Input normalisation
% =========================================================================
p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'filenames');
addParameter(p, 'Verbose', true, @islogical);
parse(p, filenames, varargin{:});

filenames = p.Results.filenames;
vb        = p.Results.Verbose;

if ischar(filenames) || isstring(filenames)
    filenames = {char(filenames)};
elseif iscell(filenames)
    filenames = cellfun(@char, filenames, 'UniformOutput', false);
else
    error('loadADSBTruth:badInput', ...
        'filenames must be a string, char array, or cell array of file paths.');
end

% =========================================================================
%  1.  Raw record accumulation across all input files
% =========================================================================
% Pre-allocate dynamic arrays using a growth-factor buffer.  SBS-1 streams
% produce roughly 5–20 position fixes per second per aircraft; a 1-hour file
% can easily contain 500 000+ lines.
BLOCK = 50000;                    % pre-allocation block size
n_raw = 0;                        % total records accumulated so far

% Raw columns: [t_utc, type, alt_ft, speed_kt, track_d, lat, lon, vrate_fpm]
% Type: 1=ID, 3=position, 4=velocity
raw_data  = zeros(BLOCK, 8);      % numeric fields
raw_hex   = cell(BLOCK, 1);       % ICAO hex string per row
raw_call  = cell(BLOCK, 1);       % callsign (filled for type-1 only)

ft2m      = 0.3048;               % ft  → m
kt2mps    = 0.5144444;            % kts → m/s
fpm2mps   = 0.00508;              % ft/min → m/s

for f_idx = 1 : numel(filenames)
    fname = filenames{f_idx};
    if vb
        fprintf('[loadADSBTruth] Reading: %s\n', fname);
    end

    % ── Gzip decompression ───────────────────────────────────────────────
    cleanup_tmp = false;
    actual_file = fname;
    if length(fname) > 3 && strcmpi(fname(end-2:end), '.gz')
        tmp_dir = [tempname, '_adsb'];
        mkdir(tmp_dir);
        try
            out = gunzip(fname, tmp_dir);
            actual_file  = out{1};
            cleanup_tmp  = true;
        catch ME
            warning('loadADSBTruth:gunzipFailed', ...
                'Could not decompress %s: %s', fname, ME.message);
            if exist(tmp_dir, 'dir'), rmdir(tmp_dir, 's'); end
            continue
        end
    end

    % ── Open file ────────────────────────────────────────────────────────
    fid = fopen(actual_file, 'r');
    if fid < 0
        warning('loadADSBTruth:openFailed', ...
            'Cannot open file: %s', actual_file);
        if cleanup_tmp, rmdir(fileparts(actual_file), 's'); end
        continue
    end

    line_count  = 0;
    parse_count = 0;
    skip_premsg = 0;  skip_fields = 0;  skip_type = 0;
    skip_hex   = 0;  skip_ts    = 0;  skip_dtprs = 0;  skip_nopos = 0;
    first_dtprs_err = '';  % capture first datetime error message

    % ── Parse lines ──────────────────────────────────────────────────────
    while true
        line = fgetl(fid);
        if ~ischar(line), break; end    % EOF
        line_count = line_count + 1;

        % Fast pre-filter: all valid MSG lines start with "MSG,"
        if numel(line) < 4 || ~strncmpi(line, 'MSG,', 4)
            skip_premsg = skip_premsg + 1;  continue
        end

        parts = strsplit(line, ',', 'CollapseDelimiters', false);
        if numel(parts) < 16
            skip_fields = skip_fields + 1;  continue     % malformed line
        end

        msg_type = str2double(parts{2});
        if ~ismember(msg_type, [1, 3, 4])
            skip_type = skip_type + 1;  continue
        end

        hex_id = strtrim(parts{5});
        if isempty(hex_id)
            skip_hex = skip_hex + 1;  continue
        end

        % Parse timestamp from fields 7 (date) and 8 (time).
        % Format: "2026/07/05" and "14:25:33.123"
        date_str = strtrim(parts{7});
        time_str = strtrim(parts{8});
        if isempty(date_str) || isempty(time_str)
            skip_ts = skip_ts + 1;  continue
        end
        dt_str = [date_str, ' ', time_str];
        try
            % Handle times with or without milliseconds
            if numel(time_str) > 8
                dt = datetime(dt_str, 'InputFormat', 'yyyy/MM/dd HH:mm:ss.SSS', ...
                    'TimeZone', 'UTC');
            else
                dt = datetime(dt_str, 'InputFormat', 'yyyy/MM/dd HH:mm:ss', ...
                    'TimeZone', 'UTC');
            end
            t_unix = posixtime(dt);
        catch ME
            skip_dtprs = skip_dtprs + 1;
            if isempty(first_dtprs_err)
                first_dtprs_err = sprintf('dt_str=|%s|  err=%s', dt_str, ME.message);
            end
            continue     % unparseable timestamp — skip
        end

        % ── Extract type-specific fields ─────────────────────────────────
        call_str  = '';
        alt_ft    = NaN;
        spd_kt    = NaN;
        trk_d     = NaN;
        lat_d     = NaN;
        lon_d     = NaN;
        vrt_fpm   = NaN;

        switch msg_type
            case 1   % Identification — callsign in field 11
                if numel(parts) >= 11
                    call_str = strtrim(parts{11});
                end

            case 3   % Airborne position — fields 12 (alt), 15 (lat), 16 (lon)
                if numel(parts) >= 16
                    alt_ft = str2double(parts{12});
                    lat_d  = str2double(parts{15});
                    lon_d  = str2double(parts{16});
                end
                % Some MSG,3 records also carry a vertical rate (field 17)
                if numel(parts) >= 17
                    vrt_fpm = str2double(parts{17});
                end

            case 4   % Airborne velocity — fields 13 (speed), 14 (track), 17 (vrate)
                if numel(parts) >= 17
                    spd_kt  = str2double(parts{13});
                    trk_d   = str2double(parts{14});
                    vrt_fpm = str2double(parts{17});
                end
        end

        % Require a valid position for type-3 records (lat/lon must be finite)
        if msg_type == 3 && (isnan(lat_d) || isnan(lon_d))
            skip_nopos = skip_nopos + 1;  continue
        end

        % ── Store in pre-allocated buffers ───────────────────────────────
        n_raw = n_raw + 1;
        if n_raw > size(raw_data, 1)
            % Grow buffers by another BLOCK
            raw_data  = [raw_data;  zeros(BLOCK, 8)]; %#ok<AGROW>
            raw_hex   = [raw_hex;   cell(BLOCK, 1)];  %#ok<AGROW>
            raw_call  = [raw_call;  cell(BLOCK, 1)];  %#ok<AGROW>
        end

        raw_data(n_raw, :) = [t_unix, msg_type, alt_ft, spd_kt, trk_d, ...
                               lat_d, lon_d, vrt_fpm];
        raw_hex{n_raw}  = upper(hex_id);
        raw_call{n_raw} = call_str;

        parse_count = parse_count + 1;
    end   % while true (line loop)

    fclose(fid);
    if cleanup_tmp
        delete(actual_file);
        try, rmdir(fileparts(actual_file), 's'); catch, end
    end

    if vb
        fprintf('[loadADSBTruth]   %d lines read, %d MSG records parsed.\n', ...
            line_count, parse_count);
        if parse_count == 0 && line_count > 0
            fprintf('[loadADSBTruth]   Skip breakdown: pre-MSG=%d  <16fields=%d  bad-type=%d  no-hex=%d  no-ts=%d  dt-parse=%d  no-pos=%d\n', ...
                skip_premsg, skip_fields, skip_type, skip_hex, skip_ts, skip_dtprs, skip_nopos);
            if ~isempty(first_dtprs_err)
                fprintf('[loadADSBTruth]   First dt-parse fail: %s\n', first_dtprs_err);
            end
        end
    end
end   % for f_idx

% Trim to actual size
raw_data  = raw_data(1:n_raw, :);
raw_hex   = raw_hex(1:n_raw);
raw_call  = raw_call(1:n_raw);

if n_raw == 0
    warning('loadADSBTruth:noData', 'No valid SBS-1 records found.');
    adsb_tracks = struct( ...
        'hex', {}, 'callsign', {}, 't_utc', {}, 'lat_deg', {}, ...
        'lon_deg', {}, 'alt_m', {}, 'speed_mps', {}, ...
        'track_deg', {}, 'vrate_mps', {});
    return
end

% =========================================================================
%  2.  Group records by ICAO hex address
% =========================================================================
% Use unique(...,'stable') to preserve chronological ordering within groups
% (since files are fed in time order).
unique_hex = unique(raw_hex, 'stable');
N_aircraft = numel(unique_hex);
if vb
    fprintf('[loadADSBTruth] Grouping %d records into %d aircraft tracks...\n', ...
        n_raw, N_aircraft);
end

% Pre-build a lookup from hex → row indices for fast grouping
hex_to_rows = containers.Map(unique_hex, repmat({[]}, 1, N_aircraft));
for r = 1 : n_raw
    h = raw_hex{r};
    hex_to_rows(h) = [hex_to_rows(h), r];
end

% =========================================================================
%  3.  Build per-aircraft struct: merge MSG3 and MSG4 onto MSG3 time base
% =========================================================================
% Strategy: for each aircraft, sort all rows by timestamp.
%   MSG,3 rows   → position fixes; form the primary timeline
%   MSG,4 rows   → velocity fixes; interpolated onto MSG,3 timestamps
%   MSG,1 rows   → callsign; use the last (most recent) value
%
% Interpolation rationale: MSG,3 and MSG,4 are broadcast on separate 1090ES
% squitter bursts, so their timestamps differ by up to ~0.5 s.  Linear
% interpolation of MSG,4 velocity fields (speed, track, vrate) onto the
% MSG,3 time grid fuses the two message streams into a single synchronised
% track without duplicating timestamps.

adsb_tracks = struct( ...
    'hex',       unique_hex(:)', ...     % [1×N_aircraft] cell array → char fields
    'callsign',  repmat({''}, 1, N_aircraft), ...
    't_utc',     cell(1, N_aircraft), ...
    'lat_deg',   cell(1, N_aircraft), ...
    'lon_deg',   cell(1, N_aircraft), ...
    'alt_m',     cell(1, N_aircraft), ...
    'speed_mps', cell(1, N_aircraft), ...
    'track_deg', cell(1, N_aircraft), ...
    'vrate_mps', cell(1, N_aircraft));

n_pos_total = 0;

for k = 1 : N_aircraft
    rows = hex_to_rows(unique_hex{k});

    % Separate into type-1, type-3, and type-4 subsets
    type_col  = raw_data(rows, 2);
    rows_id   = rows(type_col == 1);
    rows_pos  = rows(type_col == 3);
    rows_vel  = rows(type_col == 4);

    % ── Callsign: most recent type-1 record ──────────────────────────────
    if ~isempty(rows_id)
        [~, last_idx] = max(raw_data(rows_id, 1));   % index of latest timestamp
        adsb_tracks(k).callsign = raw_call{rows_id(last_idx)};
    end

    % ── Position records (MSG,3) — primary timeline ───────────────────────
    if isempty(rows_pos)
        % Aircraft seen only via velocity or ID — no position fixes available
        continue
    end

    t_pos  = raw_data(rows_pos, 1);           % [N_pos×1] Unix seconds
    alt_ft = raw_data(rows_pos, 3);
    lat    = raw_data(rows_pos, 6);
    lon    = raw_data(rows_pos, 7);

    % Sort position fixes by time (files may not be perfectly time-ordered)
    [t_pos, sort_idx] = sort(t_pos);
    alt_ft = alt_ft(sort_idx);
    lat    = lat(sort_idx);
    lon    = lon(sort_idx);

    % Remove duplicate timestamps (can arise when multiple files overlap)
    [t_pos, unique_idx] = unique(t_pos, 'last');
    alt_ft = alt_ft(unique_idx);
    lat    = lat(unique_idx);
    lon    = lon(unique_idx);

    N_pos = numel(t_pos);

    % ── Velocity records (MSG,4) — interpolated onto MSG,3 time grid ─────
    spd_mps  = nan(N_pos, 1);
    trk_deg  = nan(N_pos, 1);
    vrt_mps  = nan(N_pos, 1);

    if ~isempty(rows_vel)
        t_vel   = raw_data(rows_vel, 1);
        spd_kt  = raw_data(rows_vel, 4);
        trk_d   = raw_data(rows_vel, 5);
        vrt_fpm = raw_data(rows_vel, 8);

        [t_vel, vi] = sort(t_vel);
        spd_kt  = spd_kt(vi);
        trk_d   = trk_d(vi);
        vrt_fpm = vrt_fpm(vi);
        [t_vel, vi2] = unique(t_vel, 'last');
        spd_kt  = spd_kt(vi2);
        trk_d   = trk_d(vi2);
        vrt_fpm = vrt_fpm(vi2);

        % Only interpolate within the velocity-data time span (no extrapolation)
        if numel(t_vel) >= 2
            in_span = t_pos >= t_vel(1) & t_pos <= t_vel(end);
            if any(in_span)
                spd_mps(in_span)  = interp1(t_vel, spd_kt  * kt2mps,  t_pos(in_span), 'linear');
                trk_deg(in_span)  = interp1(t_vel, trk_d,              t_pos(in_span), 'linear');
                vrt_mps(in_span)  = interp1(t_vel, vrt_fpm * fpm2mps, t_pos(in_span), 'linear');
            end
        end

        % Also absorb vrate carried directly in MSG,3 (field 17) where available
        vrt_msg3 = raw_data(rows_pos(sort_idx(unique_idx)), 8);
        use_msg3 = ~isnan(vrt_msg3) & isnan(vrt_mps);
        vrt_mps(use_msg3) = vrt_msg3(use_msg3) * fpm2mps;
    end

    % ── Store ─────────────────────────────────────────────────────────────
    adsb_tracks(k).t_utc     = t_pos;
    adsb_tracks(k).lat_deg   = lat;
    adsb_tracks(k).lon_deg   = lon;
    adsb_tracks(k).alt_m     = alt_ft * ft2m;
    adsb_tracks(k).speed_mps = spd_mps;
    adsb_tracks(k).track_deg = trk_deg;
    adsb_tracks(k).vrate_mps = vrt_mps;

    n_pos_total = n_pos_total + N_pos;
end   % for k = 1 : N_aircraft

% Remove aircraft with no position data (seen only via MSG,1 or MSG,4)
has_pos = ~cellfun(@isempty, {adsb_tracks.t_utc});
adsb_tracks = adsb_tracks(has_pos);

if vb
    fprintf('[loadADSBTruth] Complete: %d aircraft with position data (%d total fixes).\n\n', ...
        numel(adsb_tracks), n_pos_total);
    if numel(adsb_tracks) > 0
        fprintf('  %-8s  %-10s  %6s  %20s  %20s\n', ...
            'ICAO', 'Callsign', 'Fixes', 'T_start (UTC)', 'T_end (UTC)');
        for k = 1 : numel(adsb_tracks)
            t_start_dt = datetime(adsb_tracks(k).t_utc(1),   'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            t_end_dt   = datetime(adsb_tracks(k).t_utc(end), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
            fprintf('  %-8s  %-10s  %6d  %20s  %20s\n', ...
                adsb_tracks(k).hex, adsb_tracks(k).callsign, ...
                numel(adsb_tracks(k).t_utc), ...
                datestr(t_start_dt, 'yyyy-mm-dd HH:MM:SS'), ...
                datestr(t_end_dt,   'yyyy-mm-dd HH:MM:SS'));
        end
        fprintf('\n');
    end
end

end  % ════════════════════ end loadADSBTruth ════════════════════
