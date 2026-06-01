function t_epoch_utc = getRadarEpoch(data_file_path, varargin)
%GETRADAREPOCH  Extract or estimate the UTC start epoch of a radar IQ recording.
%
%  Returns the Unix timestamp (seconds since 1970-01-01 00:00:00 UTC) for
%  the first sample of the specified radar file.  This epoch is used by
%  alignTruthToRadar to convert ADS-B wall-clock timestamps into the
%  radar pipeline's relative t_abs_s coordinate.
%
% ── EXTRACTION STRATEGY (in priority order) ─────────────────────────────
%
%  1. FILENAME — YYYYMMDDHHMMSS pattern  (14 consecutive digits)
%     The May-2026 collection naming convention embeds the full UTC start
%     timestamp directly in the filename, e.g.:
%       n320_540_5Msps_2m_1s_garge_20260521151344_906_1
%     Pattern `20260521151344` → 2026/05/21 15:13:44 UTC.
%
%  2. FILENAME — M_D_YYYY date-only pattern
%     The Newton July-2026 recordings use a human-readable date without a
%     clock time, e.g.:
%       n320_600_5Msps_pt1s_garage_5_7_2026_Newton_part1
%     Pattern `5_7_2026` → July 5, 2026.  Time is set to 00:00:00 UTC
%     with a warning — the caller should override via the 'ManualEpoch'
%     parameter if the exact start second is known.
%
%  3. BasebandFileReader METADATA
%     If the file is a .bb Baseband File (Wireless Testbench / Communications
%     Toolbox), attempt to read its info() struct for a 'RecordingTime' or
%     'Timestamp' field written by comm.BasebandFileWriter.
%     Custom metadata may appear either as top-level info() fields or inside
%     info().Metadata, depending on MATLAB release.
%
%  4. MANUAL OVERRIDE — 'ManualEpoch' name-value parameter
%     If the above attempts fail, or if the caller knows the exact time,
%     pass a datetime or Unix scalar directly:
%       t = getRadarEpoch(file, 'ManualEpoch', datetime(2026,7,5,14,32,11,'TimeZone','UTC'))
%       t = getRadarEpoch(file, 'ManualEpoch', 1751726331)
%
% ── SYNTAX ──────────────────────────────────────────────────────────────
%   t_epoch_utc = getRadarEpoch(data_file_path)
%   t_epoch_utc = getRadarEpoch(data_file_path, 'ManualEpoch', epoch_dt)
%   t_epoch_utc = getRadarEpoch(data_file_path, 'Verbose', true)
%
% ── INPUTS ──────────────────────────────────────────────────────────────
%   data_file_path   Path to the radar IQ data file (string or char).
%                    Can be a .bb Baseband File or a raw binary; only the
%                    filename (not the binary content) is inspected by
%                    strategies 1–2.
%
% ── OPTIONAL NAME-VALUE PARAMETERS ─────────────────────────────────────
%   'ManualEpoch'    datetime (with TimeZone) or scalar Unix seconds.
%                    Overrides ALL automatic extraction strategies.
%                    Use when the filename contains no time and the
%                    recording time is known from field notes or logs.
%
%   'Verbose'        Logical.  Default: true.  Print the extraction method
%                    used and the resulting epoch.
%
% ── OUTPUT ──────────────────────────────────────────────────────────────
%   t_epoch_utc   Scalar double — Unix epoch seconds for the first sample
%                 of the recording.  Returns NaN if all strategies fail and
%                 no ManualEpoch is provided.
%
% ── METADATA RECOMMENDATION ─────────────────────────────────────────────
%   log_iq_n320_2antennas.m now writes meta.RecordingUTC alongside the
%   human-readable DateTime string. Keep that metadata field present in
%   future collection scripts so getRadarEpoch can recover the exact start
%   time regardless of filename convention.
%
% See also: loadADSBTruth, alignTruthToRadar, adsbToBistatic.

% =========================================================================
%  0.  Parse inputs
% =========================================================================
p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'data_file_path', @(x) ischar(x) || isstring(x));
addParameter(p, 'ManualEpoch', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)) || isdatetime(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, data_file_path, varargin{:});
opts = p.Results;
vb   = opts.Verbose;

data_file_path = char(data_file_path);

% ── Helper: posixtime from a datetime struct ───────────────────────────
    function t = dt2unix(dt_in)
        if ~strcmp(dt_in.TimeZone, 'UTC') && ~isempty(dt_in.TimeZone)
            dt_in.TimeZone = 'UTC';
        elseif isempty(dt_in.TimeZone)
            dt_in.TimeZone = 'UTC';
        end
        t = posixtime(dt_in);
    end

t_epoch_utc = NaN;
method_used = '';

% =========================================================================
%  Strategy 0: Manual override (highest priority, checked first)
% =========================================================================
if ~isempty(opts.ManualEpoch)
    if isdatetime(opts.ManualEpoch)
        t_epoch_utc = dt2unix(opts.ManualEpoch);
        method_used = 'ManualEpoch (datetime)';
    else
        t_epoch_utc = double(opts.ManualEpoch);
        method_used = 'ManualEpoch (Unix seconds)';
    end
end

% =========================================================================
%  Strategy 1: Parse YYYYMMDDHHMMSS (14 digits) from the filename
% =========================================================================
if isnan(t_epoch_utc)
    [~, fname, fext] = fileparts(data_file_path);
    fname_full = [fname, fext];

    tok = regexp(fname_full, '(\d{14})', 'tokens', 'once');
    if ~isempty(tok)
        s14 = tok{1};
        yr  = str2double(s14(1:4));
        mo  = str2double(s14(5:6));
        dy  = str2double(s14(7:8));
        hr  = str2double(s14(9:10));
        mn  = str2double(s14(11:12));
        sc  = str2double(s14(13:14));
        if ~any(isnan([yr, mo, dy, hr, mn, sc]))
            dt_parsed = datetime(yr, mo, dy, hr, mn, sc, 'TimeZone', 'UTC');
            t_epoch_utc = dt2unix(dt_parsed);
            method_used = sprintf('Filename YYYYMMDDHHMMSS: %s', ...
                datestr(dt_parsed, 'yyyy-mm-dd HH:MM:SS'));
        end
    end
end

% =========================================================================
%  Strategy 2: Parse M_D_YYYY date (no time) from the filename
%  Matches patterns like "5_7_2026" → month=5, day=7, year=2026
%  Assumed US date order: M_D_YYYY  (month first)
% =========================================================================
if isnan(t_epoch_utc)
    [~, fname, fext] = fileparts(data_file_path);
    fname_full = [fname, fext];

    % Match an isolated M_D_YYYY or MM_DD_YYYY surrounded by non-digit chars
    tok = regexp(fname_full, '(?<!\d)(\d{1,2})_(\d{1,2})_(\d{4})(?!\d)', ...
        'tokens', 'once');
    if ~isempty(tok)
        mo = str2double(tok{1});
        dy = str2double(tok{2});
        yr = str2double(tok{3});
        if ~any(isnan([mo, dy, yr])) && mo >= 1 && mo <= 12 && dy >= 1 && dy <= 31
            dt_parsed = datetime(yr, mo, dy, 0, 0, 0, 'TimeZone', 'UTC');
            t_epoch_utc = dt2unix(dt_parsed);
            method_used = sprintf( ...
                'Filename M_D_YYYY (date only, time set to 00:00:00 UTC): %s', ...
                datestr(dt_parsed, 'yyyy-mm-dd'));
            warning('getRadarEpoch:noTime', ...
                ['Date extracted from filename but no clock time was found.\n', ...
                 'Epoch set to midnight UTC on %s.\n', ...
                 'Pass ''ManualEpoch'' with the actual recording start time for accurate ADS-B alignment.\n', ...
                 'Recommended fix: add meta.RecordingUTC to the BasebandFileWriter call in log_iq_n320_2antennas.m.'], ...
                datestr(dt_parsed, 'yyyy-mm-dd'));
        end
    end
end

% =========================================================================
%  Strategy 3: BasebandFileReader metadata
% =========================================================================
if isnan(t_epoch_utc)
    if exist('BasebandFileReader', 'file') || exist('BasebandFileReader', 'builtin')
        try
            reader = BasebandFileReader(data_file_path);
            s = info(reader);
            release(reader);
            % Field name varies by MATLAB version and whether the writer
            % exposes custom fields at the top level or inside Metadata.
            candidate_fields = {'RecordingUTC', 'RecordingTime', 'Timestamp', ...
                                 'StartTime', 'CaptureTime'};
            search_structs = {s};
            search_labels  = {'BasebandFileReader'};
            if isfield(s, 'Metadata') && isstruct(s.Metadata)
                search_structs{end + 1} = s.Metadata; %#ok<AGROW>
                search_labels{end + 1}  = 'BasebandFileReader.Metadata'; %#ok<AGROW>
            end

            for si = 1 : numel(search_structs)
                source_struct = search_structs{si};
                source_label  = search_labels{si};

                for cf = candidate_fields
                    if ~isfield(source_struct, cf{1}) || isempty(source_struct.(cf{1}))
                        continue
                    end

                    val = source_struct.(cf{1});
                    if isnumeric(val) && isscalar(val)
                        t_epoch_utc = double(val);
                        method_used = sprintf('%s.%s (numeric)', source_label, cf{1});
                    elseif isdatetime(val) && isscalar(val)
                        t_epoch_utc = dt2unix(val);
                        method_used = sprintf('%s.%s (datetime)', source_label, cf{1});
                    elseif ischar(val) || (isstring(val) && isscalar(val))
                        val_num = str2double(char(val));
                        if isfinite(val_num)
                            t_epoch_utc = val_num;
                            method_used = sprintf('%s.%s (numeric string)', source_label, cf{1});
                        end
                    end

                    if ~isnan(t_epoch_utc)
                        break
                    end
                end

                if ~isnan(t_epoch_utc)
                    break
                end
            end
        catch
            % File may not be .bb format; silently skip
        end
    end
end

% =========================================================================
%  Report
% =========================================================================
if isnan(t_epoch_utc)
    warning('getRadarEpoch:epochUnknown', ...
        ['Could not determine radar epoch from: %s\n', ...
         'Tried: filename YYYYMMDDHHMMSS, M_D_YYYY, BasebandFileReader metadata.\n', ...
         'Provide the recording UTC start time via ''ManualEpoch'' parameter.\n', ...
         'Example: getRadarEpoch(file, ''ManualEpoch'', datetime(2026,7,5,14,25,0,''TimeZone'',''UTC''))'], ...
        data_file_path);
    if vb
        fprintf('[getRadarEpoch] FAILED — epoch unknown.  Returning NaN.\n');
    end
    return
end

if vb
    epoch_dt_str = datestr(datetime(t_epoch_utc, 'ConvertFrom', 'posixtime', ...
        'TimeZone', 'UTC'), 'yyyy-mm-dd HH:MM:SS UTC');
    fprintf('[getRadarEpoch] Epoch: %s  (Unix %.0f)\n', epoch_dt_str, t_epoch_utc);
    fprintf('[getRadarEpoch] Method: %s\n\n', method_used);
end

end  % ════════════════════ end getRadarEpoch ════════════════════
