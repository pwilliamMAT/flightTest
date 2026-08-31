function finalize_info = helperTriggerFinalizeCoordinator(control_dir, varargin)
%HELPERTRIGGERFINALIZECOORDINATOR Ask the shell coordinator to stop cleanly.
%
% Plain-language goal:
%   MATLAB does not talk to the Pi directly. It signals the shell
%   coordinator through a stop-request flag, then waits for the shell to
%   finish the final ADS-B fetch before packaging the session artifacts.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'control_dir', @(x) ischar(x) || isstring(x));
addParameter(p, 'StatusFile', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'WaitTimeout_s', 45, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PollPeriod_s', 0.25, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, control_dir, varargin{:});
opts = p.Results;

control_dir = string(control_dir);
status_path = string(opts.StatusFile);
stop_request_path = "";
stopped_flag_path = "";

finalize_info = struct( ...
    'control_dir', control_dir, ...
    'status_file', status_path, ...
    'stop_request_path', stop_request_path, ...
    'stopped_flag_path', stopped_flag_path, ...
    'requested', false, ...
    'stopped', false, ...
    'timed_out', false, ...
    'status', helperTriggerReadCoordinatorStatus(status_path));

if strlength(control_dir) == 0 || exist(control_dir, 'dir') ~= 7
    return
end

stop_request_path = fullfile(control_dir, 'stop_request.flag');
stopped_flag_path = fullfile(control_dir, 'adsb_stopped.flag');
finalize_info.stop_request_path = string(stop_request_path);
finalize_info.stopped_flag_path = string(stopped_flag_path);

try
    file_id = fopen(stop_request_path, 'w');
    if file_id == -1
        error('helperTriggerFinalizeCoordinator:fileOpenFailed', ...
            'Could not open %s for writing.', stop_request_path);
    end
    fprintf(file_id, 'STOP_REQUEST_UTC=%s\n', char(string(datetime('now', ...
        'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z'''))));
    fclose(file_id);
    finalize_info.requested = true;
catch me_stop
    finalize_info.status.status = "error";
    finalize_info.status.message = "Could not write stop request: " + string(me_stop.message);
    return
end

if opts.WaitTimeout_s <= 0
    finalize_info.status = helperTriggerReadCoordinatorStatus(status_path);
    return
end

wait_timer = tic;
while toc(wait_timer) < opts.WaitTimeout_s
    if exist(stopped_flag_path, 'file') == 2
        finalize_info.stopped = true;
        break
    end
    pause(min(opts.PollPeriod_s, opts.WaitTimeout_s - toc(wait_timer)));
end

if ~finalize_info.stopped
    finalize_info.timed_out = true;
end

finalize_info.status = helperTriggerReadCoordinatorStatus(status_path);

end
