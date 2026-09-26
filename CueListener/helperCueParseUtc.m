function t = helperCueParseUtc(value)
%HELPERCUEPARSEUTC Parse a cue-message UTC timestamp into a UTC datetime.
%   The ADS-B cue tasker writes ISO 8601 UTC with a Z suffix and milliseconds
%   ("2026-09-26T00:50:38.433Z"). Empty values or JSON null (decoded as [])
%   return NaT, so callers can compare and sort without special cases.
%
%   See also CueListener.

if isempty(value)
    t = NaT('TimeZone', 'UTC');
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
