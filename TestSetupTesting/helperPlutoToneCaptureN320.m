function capture_info = helperPlutoToneCaptureN320(varargin)
%HELPERPLUTOTONECAPTUREN320 Reuse the standard N320 capture path for one standalone precheck run.
%
% Plain-language goal:
%   The standalone precheck should not invent a second N320 capture stack.
%   This helper simply adapts the frozen precheck settings to the existing
%   runLocalHDTVCapture wrapper so later integration is one call-site
%   change, not a reimplementation.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureRoot', fullfile(pwd, 'TestSetupTesting', 'plutoPrecheckCaptures'), @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureFileBase', "pluto_tone_precheck", @(x) ischar(x) || isstring(x));
addParameter(p, 'RadioName', "My USRP N320", @(x) ischar(x) || isstring(x));
addParameter(p, 'CenterFrequencyHz', 540e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SampleRateHz', 6.144e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffsetHz', 200e3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'Gain', [30 50], @(x) isnumeric(x) && (isscalar(x) || numel(x) == 2));
addParameter(p, 'CaptureDurationSeconds', 0.25, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

capture_root = char(string(opts.CaptureRoot));
try
    if exist(capture_root, 'dir') ~= 7
        mkdir(capture_root);
    end
catch me_dir
    error('helperPlutoToneCaptureN320:mkdirFailed', ...
        'Could not create capture root %s: %s', capture_root, me_dir.message);
end

capture_file = fullfile(capture_root, char(string(opts.CaptureFileBase)));

try
    capture_info = runLocalHDTVCapture( ...
        'SessionID', char(string(opts.SessionID)), ...
        'CaptureDuration_s', double(opts.CaptureDurationSeconds), ...
        'CaptureFile', capture_file, ...
        'RadioName', char(string(opts.RadioName)), ...
        'CenterFrequency_Hz', double(opts.CenterFrequencyHz), ...
        'SampleRate_Hz', double(opts.SampleRateHz), ...
        'LOOffset_Hz', double(opts.LOOffsetHz), ...
        'Gain', double(opts.Gain(:).'));
catch me_capture
    error('helperPlutoToneCaptureN320:captureFailed', ...
        'N320 capture failed: %s', me_capture.message);
end

if opts.Verbose
    fprintf('[helperPlutoToneCaptureN320] Session ....... %s\n', char(string(capture_info.session_id)));
    fprintf('[helperPlutoToneCaptureN320] First file ..... %s\n', ...
        localFirstCaptureFile(capture_info.local_capture_files));
end
end

function first_file = localFirstCaptureFile(local_capture_files)
first_file = "(none)";
if ~isempty(local_capture_files)
    first_file = char(string(local_capture_files(1)));
end
end
