function repo_info = helperTriggerAddProjectPaths()
%HELPERTRIGGERADDPROJECTPATHS Add the trigger-wrapper source folders.
%
% Plain-language goal:
%   The trigger wrapper reuses the established ADS-B parsing, bistatic
%   geometry, and local-capture entrypoints that already live elsewhere in
%   the repo. This helper makes those folders visible without modifying the
%   existing manual capture path.

trigger_root = fileparts(mfilename('fullpath'));
repo_root = fileparts(trigger_root);

path_roots = [ ...
    string(trigger_root), ...
    string(fullfile(repo_root, 'TestSetupTesting')), ...
    string(fullfile(repo_root, 'BistaticDataAnalysis'))];

for idx = 1:numel(path_roots)
    if exist(path_roots(idx), 'dir') == 7
        addpath(char(path_roots(idx)));
    end
end

repo_info = struct( ...
    'repo_root', string(repo_root), ...
    'trigger_root', string(trigger_root));

end
