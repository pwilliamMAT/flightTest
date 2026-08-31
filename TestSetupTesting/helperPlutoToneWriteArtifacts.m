function [artifact_paths, result_out] = helperPlutoToneWriteArtifacts(result, varargin)
%HELPERPLUTOTONEWRITEARTIFACTS Write the frozen standalone precheck artifacts.
%
% Plain-language goal:
%   The standalone precheck should leave one self-contained run folder that
%   can be reviewed later without rerunning hardware. This helper writes
%   the MAT bundle, JSON mirror, tight text summary, and summary figure.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'result', @isstruct);
addParameter(p, 'RunFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'CopyCaptureFile', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'WriteSummaryPNG', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, result, varargin{:});
opts = p.Results;

run_id = localRequiredTextField(result, 'run_id');
run_folder = char(string(opts.RunFolder));
if strlength(string(run_folder)) == 0
    run_folder = fullfile(pwd, 'TestSetupTesting', 'plutoPrecheckRuns', run_id);
end

result_out = result;
result_out.precheck_summary = helperPlutoToneBuildSummary(result_out);

artifact_paths = struct( ...
    'run_folder', string(run_folder), ...
    'result_mat', string(fullfile(run_folder, 'result.mat')), ...
    'result_json', string(fullfile(run_folder, 'result.json')), ...
    'summary_txt', string(fullfile(run_folder, 'summary.txt')), ...
    'summary_png', string(fullfile(run_folder, 'summary.png')), ...
    'capture_file', "");

try
    if exist(run_folder, 'dir') ~= 7
        mkdir(run_folder);
    end
catch me_dir
    error('helperPlutoToneWriteArtifacts:mkdirFailed', ...
        'Could not create artifact folder %s: %s', run_folder, me_dir.message);
end

capture_source_path = localCaptureSourcePath(result_out);
if opts.CopyCaptureFile
    if strlength(capture_source_path) == 0 || exist(char(capture_source_path), 'file') ~= 2
        error('helperPlutoToneWriteArtifacts:missingCaptureSource', ...
            'CopyCaptureFile is true, but result.capture_info.capture_file_path is missing or unreadable.');
    end

    capture_folder = fullfile(run_folder, 'capture');
    try
        if exist(capture_folder, 'dir') ~= 7
            mkdir(capture_folder);
        end
        [~, capture_name, capture_ext] = fileparts(char(capture_source_path));
        capture_target_path = fullfile(capture_folder, [capture_name, capture_ext]);
        copyfile(char(capture_source_path), capture_target_path);
        artifact_paths.capture_file = string(capture_target_path);
    catch me_copy
        error('helperPlutoToneWriteArtifacts:captureCopyFailed', ...
            'Could not copy capture file into %s: %s', capture_folder, me_copy.message);
    end
elseif strlength(capture_source_path) > 0
    artifact_paths.capture_file = capture_source_path;
end

result_out.artifact_paths = artifact_paths;
summary_text = char(string(result_out.precheck_summary.text_block));

localWriteTextFile(char(artifact_paths.summary_txt), summary_text, 'helperPlutoToneWriteArtifacts:summaryWriteFailed');

json_ready = helperPlutoTonePrepareForJSON(result_out);
json_text = jsonencode(json_ready);
localWriteTextFile(char(artifact_paths.result_json), json_text, 'helperPlutoToneWriteArtifacts:jsonWriteFailed');

try
    result_struct_for_save = struct('result', result_out);
    save(char(artifact_paths.result_mat), '-struct', 'result_struct_for_save', '-v7.3');
catch me_save
    error('helperPlutoToneWriteArtifacts:matSaveFailed', ...
        'Could not save MAT artifact %s: %s', char(artifact_paths.result_mat), me_save.message);
end

if opts.WriteSummaryPNG
    fig = helperPlutoTonePlotSummary( ...
        result_out, ...
        'FigureVisibility', opts.FigureVisibility, ...
        'SummaryTitle', 'Pluto Tone Precheck Summary');
    try
        exportgraphics(fig, char(artifact_paths.summary_png));
    catch me_png
        localCloseFigure(fig);
        error('helperPlutoToneWriteArtifacts:pngWriteFailed', ...
            'Could not write summary PNG %s: %s', char(artifact_paths.summary_png), me_png.message);
    end
    localCloseFigure(fig);
end

if opts.Verbose
    fprintf('[helperPlutoToneWriteArtifacts] Run folder .. %s\n', char(artifact_paths.run_folder));
    fprintf('[helperPlutoToneWriteArtifacts] MAT ......... %s\n', char(artifact_paths.result_mat));
    fprintf('[helperPlutoToneWriteArtifacts] JSON ........ %s\n', char(artifact_paths.result_json));
    fprintf('[helperPlutoToneWriteArtifacts] Summary ..... %s\n', char(artifact_paths.summary_txt));
    if opts.WriteSummaryPNG
        fprintf('[helperPlutoToneWriteArtifacts] Figure ...... %s\n', char(artifact_paths.summary_png));
    end
end

end

function value = localRequiredTextField(source_struct, field_name)
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    error('helperPlutoToneWriteArtifacts:missingField', ...
        'Result must contain the field %s.', field_name);
end

value = char(string(source_struct.(field_name)));
if isempty(value)
    error('helperPlutoToneWriteArtifacts:emptyField', ...
        'Result field %s must not be empty.', field_name);
end
end

function capture_source_path = localCaptureSourcePath(result)
capture_source_path = "";
if isfield(result, 'capture_info') && isstruct(result.capture_info) && ...
        isfield(result.capture_info, 'capture_file_path') && ...
        strlength(string(result.capture_info.capture_file_path)) > 0
    capture_source_path = string(result.capture_info.capture_file_path);
elseif isfield(result, 'capture_info') && isstruct(result.capture_info) && ...
        isfield(result.capture_info, 'local_capture_files') && ...
        ~isempty(result.capture_info.local_capture_files)
    capture_source_path = string(result.capture_info.local_capture_files(1));
end
end

function localWriteTextFile(output_path, content, error_id)
file_id = -1;
try
    file_id = fopen(output_path, 'w');
    if file_id == -1
        error('helperPlutoToneWriteArtifacts:fileOpenFailed', ...
            'Could not open %s for writing.', output_path);
    end
    fprintf(file_id, '%s', content);
    fclose(file_id);
catch me_write
    if file_id ~= -1
        try
            fclose(file_id);
        catch
        end
    end
    error(error_id, 'Could not write %s: %s', output_path, me_write.message);
end
end

function localCloseFigure(fig)
if ishghandle(fig)
    close(fig);
end
end
