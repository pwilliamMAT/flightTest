function output_path = saveDetectorReplayInput(replay_input, output_file, varargin)
%SAVEDETECTORREPLAYINPUT Save a detector-replay bundle to MAT.
%
% Syntax
%   output_path = saveDetectorReplayInput(replay_input, output_file)
%
% The input may be either:
%   1. the bundle returned by buildDetectorReplayInput, or
%   2. a struct containing .detector_replay_input
%
% Name-value options
%   'Verbose'  Print the saved path. Default: true.
%
% The file is saved with variable name detector_replay_input so it can be
% loaded directly by runDetectorReplaySweep.
%
% See also: buildDetectorReplayInput, runDetectorReplaySweep.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'replay_input');
addRequired(p, 'output_file', @(x) ischar(x) || isstring(x));
addParameter(p, 'Verbose', true, @islogical);
parse(p, replay_input, output_file, varargin{:});
opts = p.Results;

detector_replay_input = localResolveBundle(opts.replay_input);
output_path = char(string(opts.output_file));

parent_dir = fileparts(output_path);
if ~isempty(parent_dir) && exist(parent_dir, 'dir') ~= 7
    mkdir(parent_dir);
end

save(output_path, 'detector_replay_input', '-v7.3');
if opts.Verbose
    fprintf('[saveDetectorReplayInput] Saved: %s\n', output_path);
end

end

function detector_replay_input = localResolveBundle(replay_input)
if isstruct(replay_input) && isfield(replay_input, 'detector_replay_input')
    detector_replay_input = replay_input.detector_replay_input;
elseif isstruct(replay_input) && isfield(replay_input, 'schema_version') && ...
        isfield(replay_input, 'detector_parts')
    detector_replay_input = replay_input;
else
    error('saveDetectorReplayInput:badInput', ...
        'Input must be a detector replay bundle or a struct containing .detector_replay_input.');
end
end
