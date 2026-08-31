function result = helperPlutoToneLoadResult(source)
%HELPERPLUTOTONELOADRESULT Load one saved standalone precheck result.
%
% Accepted sources:
%   - in-memory result struct
%   - run-folder path
%   - result.mat path
%   - result.json path

if isstruct(source)
    result = source;
    result.precheck_summary = helperPlutoToneBuildSummary(result);
    return
end

source_path = char(string(source));
if isempty(source_path)
    error('helperPlutoToneLoadResult:emptySource', ...
        'Source must not be empty.');
end

if isfolder(source_path)
    run_folder = source_path;
    mat_path = fullfile(run_folder, 'result.mat');
    json_path = fullfile(run_folder, 'result.json');
    if exist(mat_path, 'file') == 2
        result = localLoadResultMat(mat_path);
    elseif exist(json_path, 'file') == 2
        result = localLoadResultJSON(json_path);
    else
        error('helperPlutoToneLoadResult:missingRunArtifacts', ...
            'Folder %s does not contain result.mat or result.json.', run_folder);
    end
    result = localPopulateArtifactPaths(result, run_folder, mat_path, json_path);
else
    [folder_path, ~, extension] = fileparts(source_path);
    switch lower(extension)
        case '.mat'
            result = localLoadResultMat(source_path);
            result = localPopulateArtifactPaths(result, folder_path, source_path, "");
        case '.json'
            result = localLoadResultJSON(source_path);
            result = localPopulateArtifactPaths(result, folder_path, "", source_path);
        otherwise
            error('helperPlutoToneLoadResult:unsupportedSource', ...
                'Source %s must be a run folder, result.mat, or result.json.', source_path);
    end
end

localValidateResult(result);
result.precheck_summary = helperPlutoToneBuildSummary(result);
end

function result = localLoadResultMat(mat_path)
try
    loaded = load(mat_path, 'result');
catch me_load
    error('helperPlutoToneLoadResult:matLoadFailed', ...
        'Could not load %s: %s', mat_path, me_load.message);
end

if ~isfield(loaded, 'result') || ~isstruct(loaded.result)
    error('helperPlutoToneLoadResult:missingResultVariable', ...
        'MAT file %s does not contain a struct variable named result.', mat_path);
end

result = loaded.result;
end

function result = localLoadResultJSON(json_path)
try
    result = jsondecode(fileread(json_path));
catch me_json
    error('helperPlutoToneLoadResult:jsonLoadFailed', ...
        'Could not parse %s: %s', json_path, me_json.message);
end

if ~isstruct(result)
    error('helperPlutoToneLoadResult:badJSONStruct', ...
        'JSON file %s did not decode into a struct.', json_path);
end
end

function result = localPopulateArtifactPaths(result, run_folder, mat_path, json_path)
if ~isfield(result, 'artifact_paths') || ~isstruct(result.artifact_paths)
    result.artifact_paths = struct();
end

if ~isempty(run_folder)
    result.artifact_paths.run_folder = string(run_folder);
end
if strlength(string(mat_path)) > 0
    result.artifact_paths.result_mat = string(mat_path);
end
if strlength(string(json_path)) > 0
    result.artifact_paths.result_json = string(json_path);
end
end

function localValidateResult(result)
required_fields = { ...
    'schema_version', ...
    'run_id', ...
    'reference_metrics', ...
    'surveillance_metrics', ...
    'joint_metrics'};

for idx = 1:numel(required_fields)
    field_name = required_fields{idx};
    if ~isfield(result, field_name)
        error('helperPlutoToneLoadResult:missingField', ...
            'Loaded result is missing the field %s.', field_name);
    end
end
end
