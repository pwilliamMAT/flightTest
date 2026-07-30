function [package_info, capture_info_out] = helperTriggerPackageSession( ...
    session_id, session_root, stage_dir, capture_info_in, varargin)
%HELPERTRIGGERPACKAGESESSION Package local trigger-session inputs on disk.
%
% Plain-language goal:
%   Trigger sessions should land in the same shareable folder layout as the
%   manual coordinator whenever radar data exists, while still preserving
%   truth-only shadow or no-trigger runs under the same session folder.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'session_id', @(x) ischar(x) || isstring(x));
addRequired(p, 'session_root', @(x) ischar(x) || isstring(x));
addRequired(p, 'stage_dir', @(x) ischar(x) || isstring(x));
addRequired(p, 'capture_info_in', @isstruct);
addParameter(p, 'RemoteLogLocalPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ExtraLogPaths', strings(0, 1), @(x) ischar(x) || isstring(x) || iscellstr(x));
addParameter(p, 'Verbose', false, @islogical);
parse(p, session_id, session_root, stage_dir, capture_info_in, varargin{:});
opts = p.Results;

session_id = string(session_id);
session_root = string(opts.session_root);
stage_dir = string(opts.stage_dir);
remote_log_local_path = string(opts.RemoteLogLocalPath);
extra_log_paths = string(opts.ExtraLogPaths);
capture_info_out = capture_info_in;

session_dir = fullfile(session_root, session_id);
radar_dir = fullfile(session_dir, 'radar');
truth_dir = fullfile(session_dir, 'truth');
log_dir = fullfile(session_dir, 'logs');

package_info = struct( ...
    'session_dir', string(session_dir), ...
    'radar_dir', string(radar_dir), ...
    'truth_dir', string(truth_dir), ...
    'log_dir', string(log_dir), ...
    'packaged_radar_rel', strings(0, 1), ...
    'packaged_radar_abs', strings(0, 1), ...
    'packaged_adsb_rel', strings(0, 1), ...
    'packaged_adsb_abs', strings(0, 1), ...
    'packaged_log_rel', strings(0, 1), ...
    'packaged_log_abs', strings(0, 1));

for folder_path = [session_dir, radar_dir, truth_dir, log_dir]
    if exist(folder_path, 'dir') ~= 7
        mkdir(folder_path);
    end
end

capture_files = strings(0, 1);
if isfield(capture_info_in, 'local_capture_files') && ~isempty(capture_info_in.local_capture_files)
    capture_files = string(capture_info_in.local_capture_files(:));
end

for idx = 1:numel(capture_files)
    if exist(capture_files(idx), 'file') ~= 2
        continue
    end

    [dest_rel, dest_abs] = localMoveIntoFolder(capture_files(idx), radar_dir, 'radar');
    package_info.packaged_radar_rel(end + 1, 1) = dest_rel;
    package_info.packaged_radar_abs(end + 1, 1) = dest_abs;
end

if ~isempty(package_info.packaged_radar_abs)
    capture_info_out.local_capture_files = package_info.packaged_radar_abs;
    capture_info_out.capture_file_path = package_info.packaged_radar_abs(1);
end

stage_patterns = [ ...
    dir(fullfile(stage_dir, '*adsb_*.txt')); ...
    dir(fullfile(stage_dir, '*adsb_*.txt.gz'))];
for idx = 1:numel(stage_patterns)
    source_path = string(fullfile(stage_dir, stage_patterns(idx).name));
    if exist(source_path, 'file') ~= 2
        continue
    end

    [dest_rel, dest_abs] = localMoveIntoFolder(source_path, truth_dir, 'truth');
    package_info.packaged_adsb_rel(end + 1, 1) = dest_rel;
    package_info.packaged_adsb_abs(end + 1, 1) = dest_abs;
end

candidate_logs = [remote_log_local_path; extra_log_paths(:)];
candidate_logs = candidate_logs(strlength(candidate_logs) > 0);
candidate_logs = unique(candidate_logs, 'stable');
for idx = 1:numel(candidate_logs)
    if exist(candidate_logs(idx), 'file') ~= 2
        continue
    end

    [dest_rel, dest_abs] = localCopyIntoFolder(candidate_logs(idx), log_dir, 'logs');
    package_info.packaged_log_rel(end + 1, 1) = dest_rel;
    package_info.packaged_log_abs(end + 1, 1) = dest_abs;
end

if opts.Verbose
    fprintf('[helperTriggerPackageSession] Session folder .. %s\n', char(package_info.session_dir));
    fprintf('[helperTriggerPackageSession] Radar files .... %d\n', numel(package_info.packaged_radar_rel));
    fprintf('[helperTriggerPackageSession] ADS-B files .... %d\n', numel(package_info.packaged_adsb_rel));
    fprintf('[helperTriggerPackageSession] Log files ..... %d\n', numel(package_info.packaged_log_rel));
end

end

function [dest_rel, dest_abs] = localMoveIntoFolder(source_path, dest_dir, rel_prefix)
source_path = string(source_path);
dest_dir = string(dest_dir);
[~, base_name, ext] = fileparts(char(source_path));
file_name = string([base_name, ext]);

dest_abs = fullfile(dest_dir, file_name);
if strcmpi(dest_abs, source_path)
    dest_rel = fullfile(rel_prefix, file_name);
    return
end

movefile(source_path, dest_abs, 'f');
dest_rel = fullfile(rel_prefix, file_name);
end

function [dest_rel, dest_abs] = localCopyIntoFolder(source_path, dest_dir, rel_prefix)
source_path = string(source_path);
dest_dir = string(dest_dir);
[~, base_name, ext] = fileparts(char(source_path));
file_name = string([base_name, ext]);
dest_abs = fullfile(dest_dir, file_name);
copyfile(source_path, dest_abs, 'f');
dest_rel = fullfile(rel_prefix, file_name);
end
