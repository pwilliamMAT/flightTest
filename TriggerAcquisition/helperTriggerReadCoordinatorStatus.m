function coordinator_status = helperTriggerReadCoordinatorStatus(status_path)
%HELPERTRIGGERREADCOORDINATORSTATUS Read the shell coordinator status file.
%
% Plain-language goal:
%   The shell wrapper owns the Raspberry Pi and file-staging lifecycle.
%   MATLAB reads the most recent coordinator status through one small text
%   file so it can surface orchestration failures in the session artifacts.

if nargin < 1
    status_path = "";
end

status_path = string(status_path);
coordinator_status = struct( ...
    'path', status_path, ...
    'available', false, ...
    'timestamp_utc', "", ...
    'status', "unknown", ...
    'message', "", ...
    'remote_log_local_path', "", ...
    'adsb_stage_dir', "", ...
    'session_id', "", ...
    'fields', struct());

if strlength(status_path) == 0 || exist(status_path, 'file') ~= 2
    return
end

try
    raw_lines = splitlines(string(fileread(status_path)));
catch me_read
    coordinator_status.status = "error";
    coordinator_status.message = "Could not read coordinator status file: " + string(me_read.message);
    return
end

field_struct = struct();
for idx = 1:numel(raw_lines)
    line_text = strtrim(raw_lines(idx));
    if strlength(line_text) == 0 || ~contains(line_text, "=")
        continue
    end

    tokens = split(line_text, "=", 2);
    field_name = matlab.lang.makeValidName(lower(strtrim(tokens(1))));
    field_value = strtrim(tokens(2));
    field_struct.(field_name) = field_value;
end

coordinator_status.available = true;
coordinator_status.fields = field_struct;

if isfield(field_struct, 'timestamp_utc')
    coordinator_status.timestamp_utc = string(field_struct.timestamp_utc);
end
if isfield(field_struct, 'status')
    coordinator_status.status = lower(string(field_struct.status));
end
if isfield(field_struct, 'message')
    coordinator_status.message = string(field_struct.message);
end
if isfield(field_struct, 'remote_log_local_path')
    coordinator_status.remote_log_local_path = string(field_struct.remote_log_local_path);
end
if isfield(field_struct, 'adsb_stage_dir')
    coordinator_status.adsb_stage_dir = string(field_struct.adsb_stage_dir);
end
if isfield(field_struct, 'session_id')
    coordinator_status.session_id = string(field_struct.session_id);
end

end
