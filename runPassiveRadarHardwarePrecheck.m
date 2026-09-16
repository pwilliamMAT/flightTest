function result = runPassiveRadarHardwarePrecheck(config)
%RUNPASSIVERADARHARDWAREPRECHECK Validate a passive-radar acquisition.
%
%   result = runPassiveRadarHardwarePrecheck(config)
%
% CONFIG.Mode is required and must be "offline" or "live". Offline mode
% reads existing comm.BasebandFileWriter captures from CONFIG.Source. Live
% mode is blocked unless CONFIG.Live.EnableHardwareAccess is explicitly
% true. Merely omitting Mode never selects hardware.
%
% Common configuration fields:
%   Mode                "offline" or "live" (required)
%   Source              Capture file(s), manifest, folder, or session ID
%   CenterFrequencyHz   Expected file-header center (default 599e6)
%   SampleRateHz        Expected and requested sample rate (default 6.144e6)
%   LOOffsetHz          Expected and requested LO offset (default 0)
%   AntennaPorts        Two requested receive ports
%   ChannelRoles        One "surveillance" and one "reference" role
%   GainDB              One gain per physical channel (default [16 16])
%   MinimumStableCaptures
%                       Repetitions required for stability (minimum/default 3)
%   CreatePlots         Create a compact diagnostic figure (default false)
%
% Live-only fields are supplied in CONFIG.Live. The precheck passes the
% explicit RF, sample-rate, antenna-port, channel-role, and gain settings
% to runLocalHDTVCapture, then evaluates the returned capture files.

arguments
    config (1, 1) struct
end

mode = localRequireExplicitMode(config);
rootFolder = string(fileparts(mfilename("fullpath")));
originalPath = path;
pathCleanup = onCleanup(@() path(originalPath));
addpath(fullfile(rootFolder, "AcquisitionPrecheck"));

normalizedConfig = helperNormalizePassiveRadarPrecheckConfig(config);
liveCaptureInfo = struct();

if mode == "offline"
    sourceInfo = helperResolvePassiveRadarPrecheckSources( ...
        normalizedConfig.Source, ...
        DatasetRoot=normalizedConfig.DatasetRoot, ...
        PartIndices=normalizedConfig.PartIndices);
else
    localRequireLiveAuthorization(normalizedConfig);
    addpath(fullfile(rootFolder, "TestSetupTesting"));
    liveCaptureInfo = localRunLiveCapture(normalizedConfig);
    sourceInfo = helperResolvePassiveRadarPrecheckSources( ...
        string(liveCaptureInfo.local_capture_files));
end

addpath(fullfile(rootFolder, "BistaticDataAnalysis"));
captureResults = repmat(helperEmptyPassiveRadarCaptureResult(), ...
    numel(sourceInfo), 1);
for captureIndex = 1:numel(sourceInfo)
    capture = helperReadPassiveRadarCapture( ...
        sourceInfo(captureIndex).File, normalizedConfig.AnalysisDurationS);
    captureResults(captureIndex) = helperEvaluatePassiveRadarPrecheckCapture( ...
        capture, sourceInfo(captureIndex), normalizedConfig);
end

controlStability = helperAssessPassiveRadarControlStability( ...
    captureResults, normalizedConfig);
capturePass = [captureResults.Pass];
overallPass = all(capturePass) && controlStability.Pass;
status = "hold";
if overallPass
    status = "pass";
end

result = struct( ...
    "Pass", overallPass, ...
    "SafeForProduction", overallPass, ...
    "Status", status, ...
    "Mode", mode, ...
    "HardwareAccessAuthorized", mode == "live", ...
    "Configuration", normalizedConfig, ...
    "SourceInfo", sourceInfo, ...
    "LiveCaptureInfo", liveCaptureInfo, ...
    "Captures", captureResults, ...
    "ControlStability", controlStability, ...
    "Summary", helperBuildPassiveRadarPrecheckSummary(captureResults));

result.Figure = [];
if normalizedConfig.CreatePlots
    result.Figure = plotPassiveRadarHardwarePrecheck(result);
end
end

function mode = localRequireExplicitMode(config)
if ~isfield(config, "Mode") || isempty(config.Mode)
    error("runPassiveRadarHardwarePrecheck:missingMode", ...
        "config.Mode must be explicitly set to ""offline"" or ""live"".");
end

mode = lower(string(config.Mode));
if ~isscalar(mode) || strlength(mode) == 0 || ...
        ~any(mode == ["offline", "live"])
    error("runPassiveRadarHardwarePrecheck:invalidMode", ...
        "config.Mode must be exactly ""offline"" or ""live"".");
end
end

function localRequireLiveAuthorization(config)
if config.Live.EnableHardwareAccess ~= true
    error("runPassiveRadarHardwarePrecheck:hardwareAccessNotAuthorized", ...
        "Live mode is blocked. Set config.Live.EnableHardwareAccess=true " + ...
        "only on the testing machine when hardware access is intended.");
end
end

function captureInfo = localRunLiveCapture(config)
if exist("runLocalHDTVCapture", "file") ~= 2
    error("runPassiveRadarHardwarePrecheck:missingCaptureInterface", ...
        "runLocalHDTVCapture.m is not available on the MATLAB path.");
end

captureInfo = runLocalHDTVCapture( ...
    "SessionID", config.Live.SessionID, ...
    "CaptureDuration_s", config.Live.CaptureDurationS, ...
    "CaptureFile", config.Live.CaptureFile, ...
    "RadioName", config.Live.RadioName, ...
    "CenterFrequency_Hz", config.CenterFrequencyHz, ...
    "SampleRate_Hz", config.SampleRateHz, ...
    "LOOffset_Hz", config.LOOffsetHz, ...
    "Gain", config.GainDB, ...
    "AntennaPorts", config.AntennaPorts, ...
    "ChannelRoles", config.ChannelRoles, ...
    "Repetitions", config.Live.Repetitions, ...
    "RepetitionSpacing_s", config.Live.RepetitionSpacingS);
end
