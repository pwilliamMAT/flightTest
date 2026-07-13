function path_info = helperSyntheticEnsureProjectPaths()
%HELPERSYNTHETICENSUREPROJECTPATHS Add required repo folders for generation.
%
% Plain language:
% The synthetic generator depends on the existing bistatic-analysis helpers
% for truth projection and packaged-session replay. This helper adds the
% required repo folders to the MATLAB path so the generator can be called
% directly from a live script or command window without manual path setup.

this_folder = fileparts(mfilename('fullpath'));
repo_root = fileparts(this_folder);
required_folders = { ...
    this_folder, ...
    fullfile(repo_root, 'BistaticDataAnalysis')};

added_folders = strings(0, 1);
for idx = 1 : numel(required_folders)
    folder_path = required_folders{idx};
    if exist(folder_path, 'dir') ~= 7
        error('helperSyntheticEnsureProjectPaths:missingFolder', ...
            'Required project folder is missing: %s', folder_path);
    end

    if ~localPathContains(folder_path)
        addpath(folder_path);
        added_folders(end + 1, 1) = string(folder_path); %#ok<AGROW>
    end
end

path_info = struct( ...
    'repo_root', repo_root, ...
    'synthetic_folder', this_folder, ...
    'added_folders', {cellstr(added_folders)});
end

function tf = localPathContains(folder_path)
path_entries = strsplit(path, pathsep);
tf = any(strcmpi(path_entries, folder_path));
end
