function dataset_root = helperResolvePackagedCaptureRoot(varargin)
%HELPERRESOLVEPACKAGEDCAPTUREROOT Resolve the default packaged-session root.
%
% Plain-language goal:
% Packaged capture sessions may live either under the analysis folder
% itself (`BistaticDataAnalysis/captures`) or, in older layouts, at the
% repository root (`captures`). This helper picks the in-repo location used
% by the current project while remaining compatible with legacy layouts.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'RequireExisting', false, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

analysis_root = fileparts(mfilename('fullpath'));
repo_root = fileparts(analysis_root);

preferred_root = fullfile(analysis_root, 'captures');
legacy_root = fullfile(repo_root, 'captures');

if exist(preferred_root, 'dir') == 7
    dataset_root = preferred_root;
    return
end

if exist(legacy_root, 'dir') == 7
    dataset_root = legacy_root;
    return
end

if opts.RequireExisting
    error('helperResolvePackagedCaptureRoot:missingCapturesRoot', ...
        ['No packaged-session folder was found at either:\n' ...
         '  %s\n' ...
         '  %s'], preferred_root, legacy_root);
end

dataset_root = preferred_root;
end
