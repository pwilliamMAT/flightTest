function snapshot_info = helperSaveDetectorReplaySnapshot(replay_input, session_folder, varargin)
%HELPERSAVEDETECTORREPLAYSNAPSHOT Save the detector-replay snapshot for a session.
%
% Plain-language goal:
%   The detector replay bundle is the fast-iteration checkpoint for CFAR
%   retuning. This helper writes that bundle into the packaged session's
%   analysis folder so later sweeps can skip the expensive upstream stages.
%
% Syntax
%   info = helperSaveDetectorReplaySnapshot(replay_input, session_folder)
%
% Name-value options
%   'OutputFolder'  Target folder. Default: <session_folder>/analysis
%   'BaseName'      Output filename stem. Default: 'detector_replay_input'
%   'Verbose'       Print the saved path. Default: true.
%
% Output
%   snapshot_info   Struct with fields:
%     .output_folder
%     .path
%
% See also: saveDetectorReplayInput, runDetectorReplaySweep.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'replay_input');
addRequired(p, 'session_folder', @(x) ischar(x) || isstring(x));
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'BaseName', 'detector_replay_input', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, replay_input, session_folder, varargin{:});
opts = p.Results;

session_folder = char(string(opts.session_folder));
output_folder = char(string(opts.OutputFolder));
if strlength(string(output_folder)) == 0
    output_folder = fullfile(session_folder, 'analysis');
end

base_name = localNormalizeBaseName(opts.BaseName);
output_path = fullfile(output_folder, sprintf('%s.mat', base_name));
saveDetectorReplayInput(replay_input, output_path, 'Verbose', opts.Verbose);

snapshot_info = struct( ...
    'output_folder', string(output_folder), ...
    'path', string(output_path));

end

function base_name = localNormalizeBaseName(value)
base_name = char(string(value));
if isempty(base_name)
    error('helperSaveDetectorReplaySnapshot:emptyBaseName', ...
        'BaseName must not be empty.');
end

if endsWith(lower(base_name), '.mat')
    base_name = base_name(1:end-4);
end
end
