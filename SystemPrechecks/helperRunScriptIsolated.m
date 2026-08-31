function helperRunScriptIsolated(scriptPath)
%helperRunScriptIsolated Run a MATLAB script from a function workspace.

arguments
    scriptPath (1, 1) string
end

if ~isfile(scriptPath)
    error("helperRunScriptIsolated:MissingFile", "Script not found: %s", scriptPath);
end

scriptPathValue = char(scriptPath);

try
    run(scriptPathValue);
catch runException
    error( ...
        "helperRunScriptIsolated:ExecutionFailed", ...
        "Could not execute script %s: %s", ...
        scriptPath, ...
        runException.message);
end
end
