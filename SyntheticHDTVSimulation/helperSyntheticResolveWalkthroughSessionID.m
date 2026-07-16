function [session_id, last_auto_generated_session_id, resolution_info] = helperSyntheticResolveWalkthroughSessionID(varargin)
%HELPERSYNTHETICRESOLVEWALKTHROUGHSESSIONID Resolve a safe walkthrough session ID.
%
% Plain language:
% The walkthrough auto-generates a fresh session ID when you do not pin one
% yourself. That is convenient for iterative runs, but MATLAB scripts keep
% workspace variables between reruns, so a previously auto-generated ID can
% accidentally be reused. This helper refreshes only that prior
% auto-generated ID while preserving a user-requested session ID.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PreviousAutoSessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PreferredAutoSessionID', "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

output_root = char(string(opts.OutputRoot));
requested_session_id = string(opts.SessionID);
previous_auto_session_id = string(opts.PreviousAutoSessionID);
preferred_auto_session_id = string(opts.PreferredAutoSessionID);

if strlength(strtrim(preferred_auto_session_id)) == 0
    preferred_auto_session_id = "seed_demo_" + ...
        string(datetime("now", "Format", "yyyyMMdd'T'HHmmssSSS"));
end

has_requested_session_id = strlength(strtrim(requested_session_id)) > 0;
requested_session_folder_exists = has_requested_session_id && ...
    exist(fullfile(output_root, char(requested_session_id)), 'dir') == 7;
looks_like_walkthrough_auto_session_id = has_requested_session_id && ...
    localLooksLikeWalkthroughAutoSessionID(requested_session_id);
rerun_reuses_previous_auto_folder = has_requested_session_id && ...
    requested_session_folder_exists && ...
    ((strlength(strtrim(previous_auto_session_id)) > 0 && ...
    requested_session_id == previous_auto_session_id) || ...
    (strlength(strtrim(previous_auto_session_id)) == 0 && ...
    looks_like_walkthrough_auto_session_id));

if ~has_requested_session_id || rerun_reuses_previous_auto_folder
    session_id = localResolveAvailableSessionID(output_root, preferred_auto_session_id);
    last_auto_generated_session_id = session_id;
    resolution_info = struct( ...
        'used_auto_session_id', true, ...
        'refreshed_previous_auto_session_id', rerun_reuses_previous_auto_folder, ...
        'preserved_requested_session_id', false, ...
        'requested_session_folder_exists', requested_session_folder_exists, ...
        'resolved_session_id', char(session_id));
    return
end

session_id = char(requested_session_id);
last_auto_generated_session_id = "";
resolution_info = struct( ...
    'used_auto_session_id', false, ...
    'refreshed_previous_auto_session_id', false, ...
    'preserved_requested_session_id', true, ...
    'requested_session_folder_exists', requested_session_folder_exists, ...
    'resolved_session_id', session_id);
end

function available_session_id = localResolveAvailableSessionID(output_root, preferred_session_id)
available_session_id = char(string(preferred_session_id));

if strlength(strtrim(string(available_session_id))) == 0
    error('helperSyntheticResolveWalkthroughSessionID:missingPreferredSessionID', ...
        'PreferredAutoSessionID must be nonempty.');
end

if exist(fullfile(output_root, available_session_id), 'dir') ~= 7
    return
end

suffix_index = 1;
while true
    candidate_session_id = sprintf('%s_rerun_%02d', available_session_id, suffix_index);
    if exist(fullfile(output_root, candidate_session_id), 'dir') ~= 7
        available_session_id = candidate_session_id;
        return
    end
    suffix_index = suffix_index + 1;
end
end

function tf = localLooksLikeWalkthroughAutoSessionID(session_id)
session_token = char(string(session_id));
tf = ~isempty(regexp(session_token, '^seed_demo_\d{8}T\d{6}(\d{3})?$', 'once'));
end
