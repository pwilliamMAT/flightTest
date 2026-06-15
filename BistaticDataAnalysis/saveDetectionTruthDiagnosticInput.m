function output_path = saveDetectionTruthDiagnosticInput(diag_input, output_file)
%SAVEDETECTIONTRUTHDIAGNOSTICINPUT Save a standalone truth-diagnostic bundle.
%
% Syntax
%   output_path = saveDetectionTruthDiagnosticInput(diag_input, output_file)
%
% The input may be either:
%   1. the bundle returned by buildDetectionTruthDiagnosticInput, or
%   2. an analysis output struct that contains .truth_diag_input
%
% The file is saved as a MAT-file with variable name truth_diag_input so it
% can be loaded directly by runDetectionTruthDiagnostics.
%
% See also: buildDetectionTruthDiagnosticInput, runDetectionTruthDiagnostics.

validateattributes(output_file, {'char', 'string'}, {'scalartext'}, mfilename, 'output_file');

truth_diag_input = localResolveBundle(diag_input);
output_path = char(string(output_file));

parent_dir = fileparts(output_path);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') ~= 7
    mkdir(parent_dir);
end

save(output_path, 'truth_diag_input', '-v7.3');
fprintf('[saveDetectionTruthDiagnosticInput] Saved: %s\n', output_path);

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
