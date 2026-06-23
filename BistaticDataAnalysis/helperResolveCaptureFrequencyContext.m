function frequency_context = helperResolveCaptureFrequencyContext(varargin)
%HELPERRESOLVECAPTUREFREQUENCYCONTEXT Resolve trusted capture frequency metadata.
%
% Plain-language goal:
% The pilot search should lock itself to one ATSC channel center only when
% the stored capture metadata makes that lock credible. If the file header
% clearly names one ATSC-like center frequency, trust it. If the header is
% off the ATSC raster but the packaged session metadata records a plausible
% channel center, use the manifest instead. Otherwise do not guess; leave
% the illuminator center unresolved so downstream code can fall back to a
% broader raster search.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RequestedIlluminatorCenterHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'HeaderCenterFrequencyHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'HeaderLOOffsetHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'SessionManifestCenterFrequencyHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'SessionManifestLOOffsetHz', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'RasterLockToleranceHz', 100e3, ...
    @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, varargin{:});
opts = p.Results;

requested_illuminator_hz = localScalarOrNaN(opts.RequestedIlluminatorCenterHz);
header_center_hz = localScalarOrNaN(opts.HeaderCenterFrequencyHz);
header_lo_offset_hz = localScalarOrNaN(opts.HeaderLOOffsetHz);
manifest_center_hz = localScalarOrNaN(opts.SessionManifestCenterFrequencyHz);
manifest_lo_offset_hz = localScalarOrNaN(opts.SessionManifestLOOffsetHz);

[header_nearest_raster_hz, header_off_raster_hz] = localNearestATSCCenter(header_center_hz);
[manifest_nearest_raster_hz, manifest_off_raster_hz] = localNearestATSCCenter(manifest_center_hz);

header_locked = isfinite(header_off_raster_hz) && ...
    abs(header_off_raster_hz) <= opts.RasterLockToleranceHz;
manifest_locked = isfinite(manifest_off_raster_hz) && ...
    abs(manifest_off_raster_hz) <= opts.RasterLockToleranceHz;

capture_center_hz = NaN;
capture_center_source = "unresolved";
if header_locked
    capture_center_hz = header_nearest_raster_hz;
    capture_center_source = "file_header_locked_raster";
elseif manifest_locked
    capture_center_hz = manifest_nearest_raster_hz;
    capture_center_source = "session_manifest_locked_raster";
elseif isfinite(header_center_hz)
    capture_center_hz = header_center_hz;
    capture_center_source = "file_header_raw";
elseif isfinite(manifest_center_hz)
    capture_center_hz = manifest_center_hz;
    capture_center_source = "session_manifest_raw";
end

capture_lo_offset_hz = 0;
capture_lo_offset_source = "default_zero";
if isfinite(header_lo_offset_hz)
    capture_lo_offset_hz = header_lo_offset_hz;
    capture_lo_offset_source = "file_header";
elseif isfinite(manifest_lo_offset_hz)
    capture_lo_offset_hz = manifest_lo_offset_hz;
    capture_lo_offset_source = "session_manifest";
end

capture_tune_hz = NaN;
if isfinite(capture_center_hz)
    capture_tune_hz = capture_center_hz + capture_lo_offset_hz;
elseif isfinite(header_center_hz)
    capture_tune_hz = header_center_hz + capture_lo_offset_hz;
elseif isfinite(manifest_center_hz)
    capture_tune_hz = manifest_center_hz + capture_lo_offset_hz;
end

illuminator_center_hz = NaN;
illuminator_center_source = "unresolved";
if isfinite(requested_illuminator_hz)
    illuminator_center_hz = requested_illuminator_hz;
    illuminator_center_source = "explicit_override";
elseif header_locked
    illuminator_center_hz = header_nearest_raster_hz;
    illuminator_center_source = "file_header_locked_raster";
elseif manifest_locked
    illuminator_center_hz = manifest_nearest_raster_hz;
    illuminator_center_source = "session_manifest_locked_raster";
end

notes = strings(0, 1);
if header_locked && manifest_locked && abs(header_nearest_raster_hz - manifest_nearest_raster_hz) > 1
    notes(end + 1) = sprintf([ ...
        'File header locks to %.3f MHz while session metadata locks to %.3f MHz. ' ...
        'Using the file header because it belongs to the captured file.'], ...
        header_nearest_raster_hz / 1e6, manifest_nearest_raster_hz / 1e6);
elseif ~header_locked && manifest_locked && isfinite(header_center_hz)
    notes(end + 1) = sprintf([ ...
        'File header center %.3f MHz is %.3f MHz off the ATSC raster. ' ...
        'Using session metadata center %.3f MHz instead.'], ...
        header_center_hz / 1e6, abs(header_off_raster_hz) / 1e6, ...
        manifest_nearest_raster_hz / 1e6);
elseif header_locked && isfinite(manifest_center_hz) && ~manifest_locked
    notes(end + 1) = sprintf([ ...
        'Session metadata center %.3f MHz is off the ATSC raster. ' ...
        'Using file-header center %.3f MHz.'], ...
        manifest_center_hz / 1e6, header_nearest_raster_hz / 1e6);
end

if isfinite(header_center_hz) && isfinite(manifest_center_hz) && ...
        abs(header_center_hz - manifest_center_hz) > 1
    notes(end + 1) = sprintf([ ...
        'File header center %.3f MHz and session metadata center %.3f MHz ' ...
        'differ by %.3f MHz.'], ...
        header_center_hz / 1e6, manifest_center_hz / 1e6, ...
        abs(header_center_hz - manifest_center_hz) / 1e6);
end

if isfinite(header_lo_offset_hz) && isfinite(manifest_lo_offset_hz) && ...
        abs(header_lo_offset_hz - manifest_lo_offset_hz) > 1
    notes(end + 1) = sprintf( ...
        'File header LO offset %.3f MHz and session metadata LO offset %.3f MHz differ.', ...
        header_lo_offset_hz / 1e6, manifest_lo_offset_hz / 1e6);
end

if ~isfinite(illuminator_center_hz)
    notes(end + 1) = "No trusted ATSC center could be locked from metadata. " + ...
        "Pilot selection should fall back to nearby raster candidates.";
end

frequency_context = struct( ...
    'requested_illuminator_center_hz', requested_illuminator_hz, ...
    'header_center_frequency_hz', header_center_hz, ...
    'header_lo_offset_hz', header_lo_offset_hz, ...
    'header_nearest_atsc_hz', header_nearest_raster_hz, ...
    'header_off_raster_hz', header_off_raster_hz, ...
    'session_manifest_center_frequency_hz', manifest_center_hz, ...
    'session_manifest_lo_offset_hz', manifest_lo_offset_hz, ...
    'session_manifest_nearest_atsc_hz', manifest_nearest_raster_hz, ...
    'session_manifest_off_raster_hz', manifest_off_raster_hz, ...
    'capture_center_frequency_hz', capture_center_hz, ...
    'capture_center_source', char(capture_center_source), ...
    'capture_lo_offset_hz', capture_lo_offset_hz, ...
    'capture_lo_offset_source', char(capture_lo_offset_source), ...
    'capture_tune_frequency_hz', capture_tune_hz, ...
    'illuminator_center_frequency_hz', illuminator_center_hz, ...
    'illuminator_center_source', char(illuminator_center_source), ...
    'raster_lock_tolerance_hz', opts.RasterLockToleranceHz, ...
    'notes', {cellstr(notes)}, ...
    'message', localBuildMessage(capture_center_source, illuminator_center_source, ...
        capture_center_hz, capture_tune_hz, illuminator_center_hz, notes));
end

function [nearest_raster_hz, off_raster_hz] = localNearestATSCCenter(freq_hz)
raster_hz = localATSCRasterCentersHz();
nearest_raster_hz = NaN;
off_raster_hz = NaN;

if ~isfinite(freq_hz)
    return
end

[~, idx] = min(abs(raster_hz - freq_hz));
nearest_raster_hz = raster_hz(idx);
off_raster_hz = freq_hz - nearest_raster_hz;
end

function raster_hz = localATSCRasterCentersHz()
vhf_low_hz = [57, 63, 69, 79, 85] * 1e6;
vhf_high_hz = (177:6:213) * 1e6;
uhf_hz = (473:6:803) * 1e6;
raster_hz = [vhf_low_hz, vhf_high_hz, uhf_hz];
end

function value = localScalarOrNaN(value_in)
if isempty(value_in)
    value = NaN;
    return
end

if isnumeric(value_in)
    value = double(value_in);
    value = value(1);
else
    value = str2double(string(value_in));
end
if ~isfinite(value)
    value = NaN;
end
end

function message = localBuildMessage(capture_center_source, illuminator_center_source, capture_center_hz, capture_tune_hz, illuminator_center_hz, notes)
if isfinite(illuminator_center_hz)
    message = sprintf([ ...
        'Using %s for the ATSC center (%.3f MHz). Capture center source: %s; ' ...
        'resolved tune %.3f MHz.'], ...
        strrep(char(illuminator_center_source), '_', ' '), ...
        illuminator_center_hz / 1e6, ...
        strrep(char(capture_center_source), '_', ' '), ...
        capture_tune_hz / 1e6);
elseif isfinite(capture_center_hz)
    message = sprintf([ ...
        'Capture center source: %s (%.3f MHz). No trusted ATSC center lock; ' ...
        'resolved tune %.3f MHz.'], ...
        strrep(char(capture_center_source), '_', ' '), ...
        capture_center_hz / 1e6, capture_tune_hz / 1e6);
elseif isempty(notes)
    message = 'No usable capture frequency metadata was found.';
else
    message = char(notes(1));
end
end
