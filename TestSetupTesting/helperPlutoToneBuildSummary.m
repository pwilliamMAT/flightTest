function summary = helperPlutoToneBuildSummary(result, varargin)
%HELPERPLUTOTONEBUILDSUMMARY Build the tight operator summary text block.
%
% Plain-language goal:
%   Both saved run artifacts and commissioned baselines need one compact,
%   stable summary format. This helper turns the frozen result-schema
%   fields into the four-line summary used for operator review.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'result', @isstruct);
addParameter(p, 'HeadlinePrefix', 'PLUTO PRECHECK', @(x) ischar(x) || isstring(x));
parse(p, result, varargin{:});
opts = p.Results;

reference_metrics = localRequiredField(result, 'reference_metrics');
surveillance_metrics = localRequiredField(result, 'surveillance_metrics');
joint_metrics = localRequiredField(result, 'joint_metrics');

status = localResolveStatus(result);
baseline_id = localResolveBaselineID(result);
headline = sprintf('%s: %s | baseline %s', char(string(opts.HeadlinePrefix)), status, baseline_id);

reference_line = sprintf( ...
    'REF  (CH2/RX2): detect %s | freq err %s | level %s %s', ...
    localFormatDetectMargin(reference_metrics.detect_margin_db), ...
    localFormatFrequencyError(reference_metrics.frequency_error_hz), ...
    localFormatLevel(reference_metrics.level_dbfs), ...
    localFormatBaselineDelta(reference_metrics.level_delta_vs_baseline_db));

surveillance_line = sprintf( ...
    'SURV (CH1/RX1): detect %s | freq err %s | level %s %s', ...
    localFormatDetectMargin(surveillance_metrics.detect_margin_db), ...
    localFormatFrequencyError(surveillance_metrics.frequency_error_hz), ...
    localFormatLevel(surveillance_metrics.level_dbfs), ...
    localFormatBaselineDelta(surveillance_metrics.level_delta_vs_baseline_db));

if isfinite(joint_metrics.channel_frequency_delta_hz)
    joint_line = sprintf('JOINT: channel freq delta %.1f kHz', joint_metrics.channel_frequency_delta_hz / 1e3);
else
    joint_line = 'JOINT: channel freq delta n/a';
end

reason_line = '';
codes = [localCodes(result, 'fail_codes'); localCodes(result, 'warn_codes')];
if ~strcmp(status, 'PASS') && ~isempty(codes)
    reason_line = sprintf('REASONS: %s', strjoin(codes.', ', '));
end

lines = {headline, reference_line, surveillance_line, joint_line};
if strlength(string(reason_line)) > 0
    lines{end + 1} = reason_line;
end

summary = struct( ...
    'headline', headline, ...
    'reference_line', reference_line, ...
    'surveillance_line', surveillance_line, ...
    'joint_line', joint_line, ...
    'reason_line', reason_line, ...
    'text_block', strjoin(lines, newline));
end

function value = localRequiredField(source_struct, field_name)
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    error('helperPlutoToneBuildSummary:missingField', ...
        'Input struct must contain the field %s.', field_name);
end
value = source_struct.(field_name);
end

function status = localResolveStatus(result)
if isfield(result, 'status') && strlength(string(result.status)) > 0
    status = char(string(result.status));
    return
end

fail_codes = localCodes(result, 'fail_codes');
warn_codes = localCodes(result, 'warn_codes');
if ~isempty(fail_codes)
    status = 'FAIL';
elseif ~isempty(warn_codes)
    status = 'WARN';
else
    status = 'PASS';
end
end

function baseline_id = localResolveBaselineID(result)
baseline_id = "(none)";
if isfield(result, 'baseline_comparison') && isstruct(result.baseline_comparison) && ...
        isfield(result.baseline_comparison, 'baseline_id') && ...
        strlength(string(result.baseline_comparison.baseline_id)) > 0
    baseline_id = char(string(result.baseline_comparison.baseline_id));
end
end

function txt = localFormatBaselineDelta(delta_db)
if isfinite(delta_db)
    txt = sprintf('(dBase %+0.1f dB)', delta_db);
else
    txt = '(dBase n/a)';
end
end

function txt = localFormatDetectMargin(value)
if isfinite(value)
    txt = sprintf('%+0.1f dB', value);
else
    txt = 'n/a';
end
end

function txt = localFormatFrequencyError(value)
if isfinite(value)
    txt = sprintf('%.1f kHz', abs(value) / 1e3);
else
    txt = 'n/a';
end
end

function txt = localFormatLevel(value)
if isfinite(value)
    txt = sprintf('%.1f dBFS', value);
else
    txt = 'n/a';
end
end

function codes = localCodes(result, field_name)
codes = cell(0, 1);
if isfield(result, field_name) && ~isempty(result.(field_name))
    raw_codes = result.(field_name);
    if isstring(raw_codes)
        codes = cellstr(raw_codes(:));
    elseif ischar(raw_codes)
        codes = {raw_codes};
    elseif iscell(raw_codes)
        codes = cellfun(@(x) char(string(x)), raw_codes(:), 'UniformOutput', false);
    end
end
end
