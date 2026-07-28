function mode_info = helperResolveGeographicPlotMode(varargin)
%HELPERRESOLVEGEOGRAPHICPLOTMODE Choose between geoglobe and geoaxes.
%   MODE_INFO = HELPERRESOLVEGEOGRAPHICPLOTMODE(...) returns a small struct
%   describing whether a geographic plot should use a 3-D geoglobe or a
%   2-D geoaxes fallback.
%
%   Name-value options:
%     'Use2DFallback'        Logical scalar. Default: true.
%     'DefaultFigureVisible' Optional override for get(groot, ...).
%     'HasGeoglobe'          Optional logical override for unit tests.

p = inputParser;
p.FunctionName = mfilename;

addParameter(p, 'Use2DFallback', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'DefaultFigureVisible', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'HasGeoglobe', [], @(x) isempty(x) || (islogical(x) && isscalar(x)));

parse(p, varargin{:});
opts = p.Results;

if isempty(opts.HasGeoglobe)
    has_geoglobe = exist('geoglobe', 'file') == 2 || ...
        exist('geoglobe', 'builtin') == 3;
else
    has_geoglobe = logical(opts.HasGeoglobe);
end

default_visibility = string(opts.DefaultFigureVisible);
if strlength(default_visibility) == 0
    default_visibility = string(get(groot, 'DefaultFigureVisible'));
end
default_visibility = lower(strtrim(default_visibility));

if opts.Use2DFallback
    use_globe = false;
    reason = "2-D fallback was requested.";
elseif default_visibility == "off"
    use_globe = false;
    reason = "DefaultFigureVisible is 'off', so avoid WebGL-backed geoglobe windows.";
elseif ~has_geoglobe
    use_globe = false;
    reason = "geoglobe is unavailable in this MATLAB environment.";
else
    use_globe = true;
    reason = "3-D geoglobe rendering is enabled.";
end

if use_globe
    mode_label = "geoglobe 3-D globe";
else
    mode_label = "geoaxes 2-D map";
end

mode_info = struct( ...
    'use_globe', logical(use_globe), ...
    'use_2d_fallback', ~logical(use_globe), ...
    'mode_label', mode_label, ...
    'reason', reason, ...
    'default_figure_visible', default_visibility, ...
    'has_geoglobe', logical(has_geoglobe));
end
