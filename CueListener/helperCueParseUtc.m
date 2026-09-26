function t = helperCueParseUtc(value)
%HELPERCUEPARSEUTC Convert a cue-message UTC time into a UTC datetime.
%   CT 2.0.0 sends times as integer milliseconds since 1970-01-01T00:00:00Z in
%   *_utc_ms fields (ICD_Messages.md section 1.2); jsondecode gives a double, which
%   holds them exactly. ISO 8601 strings ("2026-09-26T00:50:38.433Z", CT 1.x) are
%   still accepted for old logs. Empty values or JSON null (decoded as []) return NaT,
%   so callers can compare and sort without special cases.
%
%   See also CueListener.

if isempty(value)
    t = NaT('TimeZone', 'UTC');
    return
end
if isnumeric(value)
    t = datetime(double(value) / 1000, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    return
end
text = string(value);
formats = ["yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'"];
for format = formats
    try
        t = datetime(text, 'InputFormat', format, 'TimeZone', 'UTC');
        return
    catch
        % Try the next layout.
    end
end
error('helperCueParseUtc:Format', 'Unrecognized cue timestamp "%s".', text);
end
