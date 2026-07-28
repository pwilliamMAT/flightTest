function [seed_path, resolution_info] = helperSyntheticResolveSeedSourcePath(seed_source_input, varargin)
%HELPERSYNTHETICRESOLVESEEDSOURCEPATH Resolve a user seed spec to one baseband file.
%
% Plain language:
% Some callers still need a single seed waveform path even though the
% capture-backed workflow now reasons about whole sessions. This helper
% keeps that older contract by resolving the input to a normalized session
% context first, then returning the first radar file from that context.

session_context = helperSyntheticResolveSessionContext(seed_source_input, varargin{:});

if isempty(session_context.radar_files)
    seed_path = "";
else
    seed_path = string(session_context.radar_files{1});
end

resolution_info = struct( ...
    'input_kind', session_context.input_kind, ...
    'resolved_from', session_context.resolved_from, ...
    'source_spec_path', session_context.source_spec_path, ...
    'manifest_path', session_context.manifest_path, ...
    'session_folder', session_context.session_folder);
end
