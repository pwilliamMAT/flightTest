function result = reviewPlutoTonePrecheckResult(source, varargin)
%REVIEWPLUTOTONEPRECHECKRESULT Reload and reprint a saved standalone precheck result.
%
% Syntax
%   result = reviewPlutoTonePrecheckResult(source)
%   result = reviewPlutoTonePrecheckResult(source, 'PlotFigures', true)
%
% Accepted source values:
%   - run-folder path
%   - result.mat path
%   - result.json path
%   - in-memory result struct
%
% Name-value options
%   'PlotFigures'       Regenerate the summary figure. Default: true.
%   'FigureVisibility'  'on' or 'off'. Default: 'on'.
%   'Verbose'           Print the tight summary text. Default: true.
%
% See also: helperPlutoToneLoadResult, helperPlutoTonePlotSummary.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source');
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'on', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, source, varargin{:});
opts = p.Results;

result = helperPlutoToneLoadResult(opts.source);
result.precheck_summary = helperPlutoToneBuildSummary(result);

if opts.Verbose
    fprintf('%s\n', char(string(result.precheck_summary.text_block)));
end

if opts.PlotFigures
    helperPlutoTonePlotSummary( ...
        result, ...
        'FigureVisibility', opts.FigureVisibility, ...
        'SummaryTitle', 'Pluto Tone Precheck Summary');
end
end
