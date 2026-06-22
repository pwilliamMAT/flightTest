function audit = runSessionRFQualityAudit(source, varargin)
%RUNSESSIONRFQUALITYAUDIT Run RF-quality prechecks across a full packaged session.
%
% Plain-language goal:
%   The single-part direct-path precheck is good for spot checks, but a
%   capture session can still fail if only one file looks healthy and the
%   rest drift, clip, lose the pilot, or stop cancelling cleanly. This
%   wrapper runs the precheck across multiple parts and converts the result
%   into one session-level sufficiency audit.
%
% Syntax
%   audit = runSessionRFQualityAudit('20260616T160702')
%   audit = runSessionRFQualityAudit('20260616T160702', ...
%       'PartIndices', [1 5 10], 'Goal', 'tracking_validation')
%
% Input
%   source  Packaged session ID or direct path to one radar file.
%
% Name-value options
%   'DatasetRoot'
%   'SessionFolder'
%   'ManifestPath'               Same meaning as runDirectPathPrecheck.
%   'PartIndices'                Part indices to audit. Default: all parts
%                                when SOURCE is a session, otherwise part 1.
%   'Goal'                       'aircraft_detection' (default) or
%                                'tracking_validation'
%   'PlotFigures'                Forwarded to runDirectPathPrecheck.
%   'FigureVisibility'           Forwarded to runDirectPathPrecheck.
%   'Verbose'                    Print progress and summary. Default: true.
%
%   Plus all key runDirectPathPrecheck options:
%   'SliceDurationS', 'CPIDurationS', 'IlluminatorCenterFrequencyHz',
%   'PilotSearchHalfWidthHz', 'SwapChannels', 'MaxLagSamples',
%   'LagCheckCPIs', 'CrossCorrelationPeakMinDB',
%   'CrossCorrelationIsolationMinDB', 'NearRangeLimitM',
%   'NoiseRegionRangeM', 'NoiseRegionDopplerHz',
%   'DirectPathBeforeMarginMinDB', 'ZeroDopplerSuppressionMinDB',
%   'ZeroDopplerAfterMarginMaxDB'
%
% Output
%   audit   Struct containing:
%     .source
%     .session_id
%     .part_indices
%     .per_part_results
%     .part_table
%     .summary
%     .assessment
%
% See also: runDirectPathPrecheck, summarizeRFQualityAudit.

if nargin < 1
    source = "";
end

repo_root = fileparts(fileparts(mfilename('fullpath')));

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source', @(x) ischar(x) || isstring(x));
addParameter(p, 'DatasetRoot', fullfile(repo_root, 'captures'), @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PartIndices', [], @(x) isempty(x) || (isnumeric(x) && isvector(x) && all(x >= 1) && all(mod(x,1)==0)));
addParameter(p, 'Goal', 'aircraft_detection', @(x) any(strcmpi(string(x), ["aircraft_detection", "tracking_validation"])));
addParameter(p, 'SliceDurationS', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CPIDurationS', 0.5e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'IlluminatorCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'PilotSearchHalfWidthHz', 300e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SwapChannels', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MaxLagSamples', 500, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'LagCheckCPIs', 32, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'CrossCorrelationPeakMinDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CrossCorrelationIsolationMinDB', 6, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'NearRangeLimitM', 5e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'NoiseRegionRangeM', [130e3, 150e3], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'NoiseRegionDopplerHz', [200, 1000], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'DirectPathBeforeMarginMinDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ZeroDopplerSuppressionMinDB', 30, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ZeroDopplerAfterMarginMaxDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'PlotFigures', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'on', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, source, varargin{:});
opts = p.Results;

source_str = char(string(opts.source));
is_file_source = exist(source_str, 'file') == 2;

session_id = "";
if is_file_source
    part_indices = 1;
else
    analysis_setup = helperResolveSessionAnalysisSetup( ...
        source_str, ...
        'DatasetRoot', opts.DatasetRoot, ...
        'SessionFolder', opts.SessionFolder, ...
        'ManifestPath', opts.ManifestPath, ...
        'Verbose', false);
    session_id = string(analysis_setup.session_id);
    available_part_count = numel(analysis_setup.data_parts);
    if isempty(opts.PartIndices)
        part_indices = 1 : available_part_count;
    else
        part_indices = unique(opts.PartIndices(:).');
        if any(part_indices > available_part_count)
            error('runSessionRFQualityAudit:partIndexOutOfRange', ...
                'PartIndices exceed the %d available radar file(s).', available_part_count);
        end
    end
end

if isempty(opts.PartIndices) && is_file_source
    part_indices = 1;
elseif ~isempty(opts.PartIndices) && is_file_source && ~isequal(unique(opts.PartIndices(:).'), 1)
    error('runSessionRFQualityAudit:fileSourcePartIndex', ...
        'When SOURCE is a direct radar file path, only PartIndices = 1 is valid.');
end

if opts.Verbose
    fprintf('\n[runSessionRFQualityAudit] Source ......... %s\n', source_str);
    if session_id ~= ""
        fprintf('[runSessionRFQualityAudit] Session ........ %s\n', char(session_id));
    end
    fprintf('[runSessionRFQualityAudit] Parts .......... %s\n', mat2str(part_indices));
end

% Use a cell accumulator first. Assigning a fielded struct into a
% preallocated zero-field struct array throws "Subscripted assignment
% between dissimilar structures" on MATLAB, which is exactly what a
% session audit does on its first part.
per_part_results = cell(1, numel(part_indices));
for k = 1 : numel(part_indices)
    part_idx = part_indices(k);
    if opts.Verbose
        fprintf('[runSessionRFQualityAudit] Part %d/%d ....... precheck part %d\n', ...
            k, numel(part_indices), part_idx);
    end

    per_part_results{k} = runDirectPathPrecheck(source_str, ...
        'DatasetRoot', opts.DatasetRoot, ...
        'SessionFolder', opts.SessionFolder, ...
        'ManifestPath', opts.ManifestPath, ...
        'PartIndex', part_idx, ...
        'SliceDurationS', opts.SliceDurationS, ...
        'CPIDurationS', opts.CPIDurationS, ...
        'IlluminatorCenterFrequencyHz', opts.IlluminatorCenterFrequencyHz, ...
        'PilotSearchHalfWidthHz', opts.PilotSearchHalfWidthHz, ...
        'SwapChannels', opts.SwapChannels, ...
        'MaxLagSamples', opts.MaxLagSamples, ...
        'LagCheckCPIs', opts.LagCheckCPIs, ...
        'CrossCorrelationPeakMinDB', opts.CrossCorrelationPeakMinDB, ...
        'CrossCorrelationIsolationMinDB', opts.CrossCorrelationIsolationMinDB, ...
        'NearRangeLimitM', opts.NearRangeLimitM, ...
        'NoiseRegionRangeM', opts.NoiseRegionRangeM, ...
        'NoiseRegionDopplerHz', opts.NoiseRegionDopplerHz, ...
        'DirectPathBeforeMarginMinDB', opts.DirectPathBeforeMarginMinDB, ...
        'ZeroDopplerSuppressionMinDB', opts.ZeroDopplerSuppressionMinDB, ...
        'ZeroDopplerAfterMarginMaxDB', opts.ZeroDopplerAfterMarginMaxDB, ...
        'PlotFigures', opts.PlotFigures, ...
        'FigureVisibility', opts.FigureVisibility, ...
        'Verbose', false);
end
per_part_results = [per_part_results{:}];

rf_audit = summarizeRFQualityAudit(per_part_results, ...
    'Goal', opts.Goal, ...
    'Verbose', opts.Verbose);

audit = struct( ...
    'source', string(source_str), ...
    'session_id', session_id, ...
    'part_indices', part_indices(:), ...
    'per_part_results', per_part_results, ...
    'part_table', rf_audit.part_table, ...
    'summary', rf_audit.summary, ...
    'assessment', rf_audit.assessment);

end
