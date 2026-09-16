function operator_setup_notes = helperResolveOperatorSetupNotes(operator_setup_notes, varargin)
%HELPERRESOLVEOPERATORSETUPNOTES Require the manual physical-setup record.
%
% Plain-language goal:
%   Radio metadata can report a requested N320 port and gain, but it cannot
%   discover which antenna, cable, polarization, or pointing the operator
%   actually installed. This helper records that physical context before a
%   capture can begin.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'Interactive', localIsInteractiveMATLAB(), ...
    @(value) islogical(value) && isscalar(value));
addParameter(p, 'PromptFunction', @localPromptForSetupNotes, ...
    @(value) isa(value, 'function_handle'));
parse(p, varargin{:});
options = p.Results;

operator_setup_notes = string(operator_setup_notes);
if strlength(strtrim(operator_setup_notes)) == 0 && options.Interactive
    operator_setup_notes = string(options.PromptFunction(localPromptText()));
end

if strlength(strtrim(operator_setup_notes)) == 0
    error('helperResolveOperatorSetupNotes:missingOperatorSetupNotes', ...
        ['OperatorSetupNotes is required before capture. Include CH1 port/role ' ...
        'antenna and inline chain; CH2 port/role antenna and inline chain; ' ...
        'polarization; approximate azimuth/elevation/height; mapping-proof ' ...
        'method/result; and setup anomalies, weather, or deviations.']);
end
end

function tf = localIsInteractiveMATLAB()
tf = usejava('desktop');
end

function notes = localPromptForSetupNotes(prompt_text)
notes = input(prompt_text, 's');
end

function prompt_text = localPromptText()
prompt_text = sprintf([ ...
    'Operator setup notes are required. Enter one record identifying:\n' ...
    '- CH1 port, role, antenna, and inline chain\n' ...
    '- CH2 port, role, antenna, and inline chain\n' ...
    '- polarization and approximate azimuth/elevation/height\n' ...
    '- mapping-proof method and result\n' ...
    '- anomalies, weather, or deviations\n' ...
    'Notes: ']);
end
