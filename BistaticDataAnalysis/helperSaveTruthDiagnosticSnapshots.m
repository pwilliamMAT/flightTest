function snapshot_info = helperSaveTruthDiagnosticSnapshots(diag_input, session_folder, varargin)
%HELPERSAVETRUTHDIAGNOSTICSNAPSHOTS Save compact and/or full truth snapshots.
%
% Plain-language goal:
%   The expensive signal-processing stages should only run once per
%   session. After detections and optional cached RDM products exist, we
%   save a narrow post-detection artifact that can be replayed quickly by
%   runDetectionTruthDiagnostics.
%
% Syntax
%   info = helperSaveTruthDiagnosticSnapshots(diag_input, session_folder)
%   info = helperSaveTruthDiagnosticSnapshots(..., 'SnapshotMode', 'both')
%
% Name-value options
%   'SnapshotMode'  One of:
%                   'compact' - save only the smaller default snapshot
%                               without cached RDM images.
%                   'full'    - save only the larger replay snapshot with
%                               cached RDM images.
%                   'both'    - save both compact and full snapshots.
%                   'off'     - do not save anything.
%                   Default: 'compact'
%   'OutputFolder'  Target folder. Default: <session_folder>/analysis
%   'BaseName'      Base filename stem. Default: 'truth_diag_input'
%   'Verbose'       Print saved-path messages. Default: true.
%
% Output
%   snapshot_info   Struct with fields:
%     .mode
%     .output_folder
%     .compact_path
%     .full_path
%
% See also: saveDetectionTruthDiagnosticInput, runDetectionTruthDiagnostics.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'diag_input');
addRequired(p, 'session_folder', @(x) ischar(x) || isstring(x));
addParameter(p, 'SnapshotMode', 'compact', @localIsSnapshotMode);
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'BaseName', 'truth_diag_input', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, diag_input, session_folder, varargin{:});
opts = p.Results;

session_folder = char(string(opts.session_folder));
snapshot_mode = lower(char(string(opts.SnapshotMode)));
base_name = localNormalizeBaseName(opts.BaseName);

output_folder = char(string(opts.OutputFolder));
if strlength(string(output_folder)) == 0
    output_folder = fullfile(session_folder, 'analysis');
end

snapshot_info = struct( ...
    'mode', string(snapshot_mode), ...
    'output_folder', string(output_folder), ...
    'compact_path', "", ...
    'full_path', "");

switch snapshot_mode
    case 'off'
        return

    case 'compact'
        compact_path = fullfile(output_folder, sprintf('%s.mat', base_name));
        saveDetectionTruthDiagnosticInput(diag_input, compact_path, ...
            'IncludeRDMParts', false, ...
            'Verbose', opts.Verbose);
        snapshot_info.compact_path = string(compact_path);

    case 'full'
        full_path = fullfile(output_folder, sprintf('%s_full.mat', base_name));
        saveDetectionTruthDiagnosticInput(diag_input, full_path, ...
            'IncludeRDMParts', true, ...
            'Verbose', opts.Verbose);
        snapshot_info.full_path = string(full_path);

    case 'both'
        compact_path = fullfile(output_folder, sprintf('%s.mat', base_name));
        full_path = fullfile(output_folder, sprintf('%s_full.mat', base_name));

        saveDetectionTruthDiagnosticInput(diag_input, compact_path, ...
            'IncludeRDMParts', false, ...
            'Verbose', opts.Verbose);
        saveDetectionTruthDiagnosticInput(diag_input, full_path, ...
            'IncludeRDMParts', true, ...
            'Verbose', opts.Verbose);

        snapshot_info.compact_path = string(compact_path);
        snapshot_info.full_path = string(full_path);
end

end

function tf = localIsSnapshotMode(value)
mode = char(string(value));
tf = any(strcmpi(mode, {'compact', 'full', 'both', 'off'}));
end

function base_name = localNormalizeBaseName(value)
base_name = char(string(value));
if isempty(base_name)
    error('helperSaveTruthDiagnosticSnapshots:emptyBaseName', ...
        'BaseName must not be empty.');
end

if endsWith(lower(base_name), '.mat')
    base_name = base_name(1:end-4);
end
end
