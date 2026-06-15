function output_path = saveDetectionTruthDiagnosticInput(diag_input, output_file, varargin)
%SAVEDETECTIONTRUTHDIAGNOSTICINPUT Save a standalone truth-diagnostic bundle.
%
% Syntax
%   output_path = saveDetectionTruthDiagnosticInput(diag_input, output_file)
%   output_path = saveDetectionTruthDiagnosticInput(..., 'IncludeRDMParts', false)
%
% The input may be either:
%   1. the bundle returned by buildDetectionTruthDiagnosticInput, or
%   2. an analysis output struct that contains .truth_diag_input
%
% Name-value options
%   'IncludeRDMParts'  When false, drop cached per-part RDM imagery before
%                      saving. This produces a smaller snapshot that still
%                      supports truth alignment and detection-vs-truth
%                      plots, but it cannot recreate standalone RDM
%                      overlay figures. Default: true.
%   'Verbose'          Print the saved path. Default: true.
%
% The file is saved as a MAT-file with variable name truth_diag_input so it
% can be loaded directly by runDetectionTruthDiagnostics.
%
% See also: buildDetectionTruthDiagnosticInput, runDetectionTruthDiagnostics.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'diag_input');
addRequired(p, 'output_file', @(x) ischar(x) || isstring(x));
addParameter(p, 'IncludeRDMParts', true, @islogical);
addParameter(p, 'Verbose', true, @islogical);
parse(p, diag_input, output_file, varargin{:});
opts = p.Results;

truth_diag_input = localResolveBundle(opts.diag_input);
truth_diag_input = localPrepareBundleForSave(truth_diag_input, opts.IncludeRDMParts);
output_path = char(string(opts.output_file));

parent_dir = fileparts(output_path);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') ~= 7
    mkdir(parent_dir);
end

save(output_path, 'truth_diag_input', '-v7.3');
if opts.Verbose
    fprintf('[saveDetectionTruthDiagnosticInput] Saved: %s\n', output_path);
end

end

function truth_diag_input = localResolveBundle(diag_input)
if isstruct(diag_input) && isfield(diag_input, 'truth_diag_input')
    truth_diag_input = diag_input.truth_diag_input;
elseif isstruct(diag_input) && isfield(diag_input, 'schema_version')
    truth_diag_input = diag_input;
else
    error('saveDetectionTruthDiagnosticInput:badInput', ...
        'Input must be a diagnostic bundle or a struct containing .truth_diag_input.');
end
end

function truth_diag_input = localPrepareBundleForSave(truth_diag_input, include_rdm_parts)
if include_rdm_parts
    return
end

if isfield(truth_diag_input, 'rdm_parts')
    truth_diag_input = rmfield(truth_diag_input, 'rdm_parts');
end
end
