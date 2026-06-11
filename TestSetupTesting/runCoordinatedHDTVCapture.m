function capture_info = runCoordinatedHDTVCapture(varargin)
%RUNCOORDINATEDHDTVCAPTURE Coordinate Pi ADS-B logging with a local SDR run.
%  The Raspberry Pi ADS-B logger starts first, warms up, and then the local
%  N320 capture runs with the same session ID so the files are easy to pair.
%
%  Example:
%    info = runCoordinatedHDTVCapture( ...
%        'PiHost', '192.168.10.131', ...
%        'LocalCaptureArgs', {'radio', 'My USRP N320', 'gain', [30 50]}, ...
%        'CaptureFile', 'n320_hdtv_capture');

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'PiUser', 'pi2', @(x) ischar(x) || isstring(x));
addParameter(p, 'PiHost', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PiWorkingDir', '/home/pi2/flightTest/ADSB_GPS', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'PiLoggerScript', '/home/pi2/flightTest/ADSB_GPS/gatherTCPcompress.py', ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'SSHExecutable', 'ssh', @(x) ischar(x) || isstring(x));
addParameter(p, 'SCPExecutable', 'scp', @(x) ischar(x) || isstring(x));
addParameter(p, 'SSHOptions', ...
    {'-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=accept-new'}, ...
    @iscell);
addParameter(p, 'SCPOptions', ...
    {'-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', '-o', 'StrictHostKeyChecking=accept-new'}, ...
    @iscell);
addParameter(p, 'CaptureDuration_s', 30, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LeadSeconds_s', 15, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'TailSeconds_s', 5, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'ADSBRunSeconds_s', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CaptureFile', 'n320_hdtv_capture', @(x) ischar(x) || isstring(x));
addParameter(p, 'LocalCaptureArgs', {}, @iscell);
addParameter(p, 'RemoteLoggerArgs', {}, @iscell);
addParameter(p, 'FetchADSBToLocal', true, @islogical);
addParameter(p, 'LocalADSBFolder', fullfile(pwd, 'adsb_capture'), ...
    @(x) ischar(x) || isstring(x));
addParameter(p, 'RemoteWaitTimeout_s', 30, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'RemotePollPeriod_s', 2, @(x) isnumeric(x) && isscalar(x) && x > 0);
parse(p, varargin{:});
opts = p.Results;

if strlength(string(opts.PiHost)) == 0
    error('runCoordinatedHDTVCapture:missingPiHost', ...
        'PiHost must be set to the Raspberry Pi host or IP address.');
end

if strlength(string(opts.SessionID)) == 0
    session_id = string(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
else
    session_id = string(opts.SessionID);
end

if isempty(opts.ADSBRunSeconds_s)
    adsb_run_s = opts.LeadSeconds_s + opts.CaptureDuration_s + opts.TailSeconds_s;
else
    adsb_run_s = opts.ADSBRunSeconds_s;
end

pi_user = char(string(opts.PiUser));
pi_host = char(string(opts.PiHost));
pi_target = sprintf('%s@%s', pi_user, pi_host);
pi_workdir = helperStripTrailingSlash(char(string(opts.PiWorkingDir)));
pi_logger_script = char(string(opts.PiLoggerScript));
ssh_exe = char(string(opts.SSHExecutable));
scp_exe = char(string(opts.SCPExecutable));
ssh_opts = helperStringCell(opts.SSHOptions);
scp_opts = helperStringCell(opts.SCPOptions);
capture_file = string(opts.CaptureFile);
remote_log_file = sprintf('%s/adsb_capture_%s.log', pi_workdir, session_id);

remote_probe_body = sprintf([ ...
    'cd %s && test -f %s && command -v python3 >/dev/null 2>&1 ' ...
    '&& printf READY'], ...
    helperQuotePosixArg(pi_workdir), helperQuotePosixArg(pi_logger_script));
remote_probe_cmd = helperBuildSSHCommand( ...
    ssh_exe, ssh_opts, pi_target, remote_probe_body);
[status_probe, output_probe] = system(remote_probe_cmd);
if status_probe ~= 0 || ~strcmp(strtrim(output_probe), 'READY')
    error('runCoordinatedHDTVCapture:sshProbeFailed', [ ...
        'Could not reach the Raspberry Pi with non-interactive SSH before capture start.\n' ...
        'The usual cause is missing SSH key-based login, an unknown host key, or the Pi being offline.\n' ...
        'Manual test from the same terminal:\n  %s\n' ...
        'Probe command:\n  %s\n' ...
        'Probe output:\n%s'], ...
        helperBuildLocalCommand([{ssh_exe}, ssh_opts, {pi_target, 'echo READY'}]), ...
        remote_probe_cmd, output_probe);
end

remote_logger_tokens = [ ...
    {'--session-id', char(session_id), '--run-seconds', sprintf('%.1f', adsb_run_s)}, ...
    helperStringCell(opts.RemoteLoggerArgs)];
remote_logger_arg_string = helperJoinQuotedArgs(remote_logger_tokens);
remote_logger_body = sprintf( ...
    'exec python3 %s %s > %s 2>&1 < /dev/null', ...
    helperQuotePosixArg(pi_logger_script), ...
    remote_logger_arg_string, ...
    helperQuotePosixArg(remote_log_file));
remote_start_body = sprintf( ...
    ['cd %s && if command -v setsid >/dev/null 2>&1; then ' ...
     'setsid -f bash -lc %s; ' ...
     'else nohup bash -lc %s >/dev/null 2>&1 & ' ...
     'fi; printf STARTED'], ...
    helperQuotePosixArg(pi_workdir), ...
    helperQuotePosixArg(remote_logger_body), ...
    helperQuotePosixArg(remote_logger_body));
remote_start_cmd = helperBuildSSHCommand( ...
    ssh_exe, ssh_opts, pi_target, remote_start_body);

fprintf('[1/5] Starting ADS-B logger on %s for %.1f s...\n', pi_target, adsb_run_s);
[status_start, output_start] = system(remote_start_cmd);
if status_start ~= 0 || ~contains(string(output_start), "STARTED")
    error('runCoordinatedHDTVCapture:remoteStartFailed', ...
        ['Could not start remote ADS-B logger cleanly.\n' ...
         'Command: %s\nOutput:\n%s\n' ...
         'This usually means the remote launch did not detach from SSH cleanly.'], ...
        remote_start_cmd, output_start);
end

fprintf('[2/5] Waiting %.1f s before the SDR capture...\n', opts.LeadSeconds_s);
pause(opts.LeadSeconds_s);

fprintf('[3/5] Running local SDR capture for %.1f s (session %s)...\n', ...
    opts.CaptureDuration_s, session_id);
local_capture_args = [opts.LocalCaptureArgs, ...
    {'dur', opts.CaptureDuration_s, 'file', capture_file, 'session_id', session_id}];
[local_session_id, written_files] = log_iq_n320_2antennas(local_capture_args{:});
if ~strcmp(char(local_session_id), char(session_id))
    error('runCoordinatedHDTVCapture:sessionMismatch', ...
        'Local capture returned session ID %s but %s was requested.', ...
        local_session_id, session_id);
end

remaining_adsb_s = max(0, adsb_run_s - opts.LeadSeconds_s - opts.CaptureDuration_s);
if remaining_adsb_s > 0
    fprintf('[4/5] Waiting %.1f s for ADS-B tail coverage...\n', remaining_adsb_s);
    pause(remaining_adsb_s);
end

remote_running = helperRemoteLoggerRunning( ...
    ssh_exe, ssh_opts, pi_target, char(session_id), opts.RemotePollPeriod_s, opts.RemoteWaitTimeout_s);

remote_adsb_files = strings(0, 1);
local_adsb_files = strings(0, 1);
if opts.FetchADSBToLocal
    if remote_running
        warning('runCoordinatedHDTVCapture:remoteStillRunning', ...
            ['Remote ADS-B logger still appears to be running after the wait timeout. ', ...
             'Skipping file copy; check %s on the Pi.'], remote_log_file);
    else
        fprintf('[5/5] Copying ADS-B files for session %s back to this machine...\n', session_id);
        local_adsb_dir = char(string(opts.LocalADSBFolder));
        if ~exist(local_adsb_dir, 'dir')
            mkdir(local_adsb_dir);
        end
        remote_adsb_files = helperListRemoteADSBFiles( ...
            ssh_exe, ssh_opts, pi_target, pi_workdir, char(session_id));
        if isempty(remote_adsb_files)
            warning('runCoordinatedHDTVCapture:noRemoteFiles', ...
                'No remote ADS-B files matched session %s in %s.', session_id, pi_workdir);
        else
            local_adsb_files = helperCopyRemoteFiles( ...
                scp_exe, scp_opts, pi_target, remote_adsb_files, local_adsb_dir);
        end
    end
end

capture_info = struct( ...
    'session_id',         session_id, ...
    'adsb_run_seconds',   adsb_run_s, ...
    'remote_target',      string(pi_target), ...
    'remote_log_file',    string(remote_log_file), ...
    'remote_adsb_files',  remote_adsb_files, ...
    'local_adsb_files',   local_adsb_files, ...
    'local_capture_files', written_files, ...
    'local_capture_base', capture_file);

fprintf('Coordinated capture complete for session %s.\n', session_id);
end

function remote_running = helperRemoteLoggerRunning( ...
    ssh_exe, ssh_opts, pi_target, session_id, poll_period_s, wait_timeout_s)
% Poll until the remote logger stops or the timeout is reached.

if wait_timeout_s <= 0
    remote_running = helperQueryRemoteLogger(ssh_exe, ssh_opts, pi_target, session_id);
    return
end

stopwatch = tic;
while true
    remote_running = helperQueryRemoteLogger(ssh_exe, ssh_opts, pi_target, session_id);
    if ~remote_running
        return
    end

    elapsed_s = toc(stopwatch);
    if elapsed_s >= wait_timeout_s
        return
    end

    pause(min(poll_period_s, wait_timeout_s - elapsed_s));
end
end

function remote_running = helperQueryRemoteLogger(ssh_exe, ssh_opts, pi_target, session_id)
% Check whether the remote ADS-B logger process is still present.

remote_pattern = sprintf('gatherTCPcompress.py.*%s', session_id);
remote_body = sprintf('pgrep -f %s >/dev/null && printf RUNNING || printf STOPPED', ...
    helperQuotePosixArg(remote_pattern));
remote_cmd = helperBuildSSHCommand(ssh_exe, ssh_opts, pi_target, remote_body);
[status, output] = system(remote_cmd);
if status ~= 0
    warning('runCoordinatedHDTVCapture:remotePollFailed', ...
        'Could not poll the remote ADS-B logger. Assuming it has stopped.\n%s', output);
    remote_running = false;
    return
end

remote_running = strcmp(strtrim(output), 'RUNNING');
end

function remote_files = helperListRemoteADSBFiles(ssh_exe, ssh_opts, pi_target, pi_workdir, session_id)
% Return the list of remote ADS-B files that match this session.

remote_glob = sprintf('%s/*adsb_%s*.txt.gz', pi_workdir, session_id);
remote_body = sprintf('shopt -s nullglob; for f in %s; do printf "%%s\\n" "$f"; done', ...
    remote_glob);
remote_cmd = helperBuildSSHCommand(ssh_exe, ssh_opts, pi_target, remote_body);
[status, output] = system(remote_cmd);
if status ~= 0
    error('runCoordinatedHDTVCapture:listRemoteFailed', ...
        'Could not list remote ADS-B files.\nCommand: %s\nOutput:\n%s', ...
        remote_cmd, output);
end

raw_lines = splitlines(string(output));
remote_files = raw_lines(strlength(strtrim(raw_lines)) > 0);
end

function local_files = helperCopyRemoteFiles(scp_exe, scp_opts, pi_target, remote_files, local_dir)
% Copy concrete remote files with scp after the logger has stopped.

local_files = strings(numel(remote_files), 1);
for k = 1:numel(remote_files)
    remote_file = char(remote_files(k));
    [~, name, ext] = fileparts(remote_file);
    if strcmp(ext, '.gz')
        [~, stem, ext2] = fileparts(name);
        local_name = [stem, ext2, ext];
    else
        local_name = [name, ext];
    end
    scp_cmd = helperBuildLocalCommand( ...
        [{scp_exe}, scp_opts, {sprintf('%s:%s', pi_target, remote_file), local_dir}]);
    [status, output] = system(scp_cmd);
    if status ~= 0
        error('runCoordinatedHDTVCapture:scpFailed', ...
            'Could not copy %s from %s.\nCommand: %s\nOutput:\n%s', ...
            remote_file, pi_target, scp_cmd, output);
    end
    local_files(k) = fullfile(local_dir, local_name);
end
end

function value = helperStripTrailingSlash(value)
% Remove one trailing POSIX slash so path joins stay predictable.

value = char(string(value));
while numel(value) > 1 && value(end) == '/'
    value(end) = [];
end
end

function quoted = helperQuoteLocalArg(value)
% Quote one local shell argument for MATLAB system() calls.

value = char(string(value));
quoted = ['"', strrep(value, '"', '\"'), '"'];
end

function cmd = helperBuildSSHCommand(ssh_exe, ssh_opts, pi_target, remote_body)
% Build one SSH command line with fail-fast options and a remote shell body.

cmd = helperBuildLocalCommand([{ssh_exe}, ssh_opts, ...
    {pi_target, ['bash -lc ', helperQuotePosixArg(remote_body)]}]);
end

function cmd = helperBuildLocalCommand(tokens)
% Quote and join local shell arguments for MATLAB system() calls.

quoted_tokens = cellfun(@helperQuoteLocalArg, helperStringCell(tokens), ...
    'UniformOutput', false);
cmd = strjoin(quoted_tokens, ' ');
end

function joined = helperJoinQuotedArgs(values)
% Quote and join a token cell array for the remote POSIX shell.

if isempty(values)
    joined = '';
    return
end

quoted_values = cellfun(@helperQuotePosixArg, helperStringCell(values), ...
    'UniformOutput', false);
joined = strjoin(quoted_values, ' ');
end

function values = helperStringCell(values)
% Convert mixed scalar values into a flat cell array of chars/strings.

if isempty(values)
    values = {};
    return
end

values = values(:).';
for k = 1:numel(values)
    if isnumeric(values{k})
        values{k} = num2str(values{k});
    else
        values{k} = char(string(values{k}));
    end
end
end
