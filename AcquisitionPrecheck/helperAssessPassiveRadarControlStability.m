function result = helperAssessPassiveRadarControlStability(captures, config)
%HELPERASSESSPASSIVERADARCONTROLSTABILITY Compare role levels across parts.
%
% A repeated precheck is controlled only when each configured role remains
% within the allowed RMS-level span. This detects changes in the unchanged
% path without treating the absolute REF/SURV ordering as a requirement.

arguments
    captures (:, 1) struct
    config (1, 1) struct
end

nCaptures = numel(captures);
roleLevelsDBFS = nan(nCaptures, 2);
for captureIndex = 1:nCaptures
    if isfield(captures(captureIndex).Checks, "Headroom")
        channelLevels = captures(captureIndex).Checks.Headroom.RMSDBFS;
        roleLevelsDBFS(captureIndex, 1) = localChannelValue( ...
            channelLevels, captures(captureIndex).ConfiguredSurveillanceChannel);
        roleLevelsDBFS(captureIndex, 2) = localChannelValue( ...
            channelLevels, captures(captureIndex).ConfiguredReferenceChannel);
    end
end

levelSpanDB = localFiniteSpan(roleLevelsDBFS);
minimumCaptures = config.MinimumStableCaptures;
isAssessable = nCaptures >= minimumCaptures && ...
    all(isfinite(roleLevelsDBFS), "all") && ...
    all(isfinite(levelSpanDB));
pass = false;
assessment = sprintf( ...
    "not assessed (need at least %d valid captures)", minimumCaptures);
if isAssessable
    pass = all(levelSpanDB <= config.Thresholds.ControlLevelSpanMaxDB);
    assessment = sprintf( ...
        "controlled within %.1f dB", ...
        config.Thresholds.ControlLevelSpanMaxDB);
    if ~pass
        assessment = "configuration not controlled";
    end
end

result = struct( ...
    "Pass", pass, ...
    "IsAssessable", isAssessable, ...
    "RoleNames", ["surveillance", "reference"], ...
    "RoleLevelsDBFS", roleLevelsDBFS, ...
    "LevelSpanDB", levelSpanDB, ...
    "MinimumCaptureCount", minimumCaptures, ...
    "MaximumAllowedSpanDB", ...
        config.Thresholds.ControlLevelSpanMaxDB, ...
    "Assessment", assessment);
end

function value = localChannelValue(values, channelIndex)
value = NaN;
if isfinite(channelIndex) && channelIndex >= 1 && channelIndex <= numel(values)
    value = values(channelIndex);
end
end

function span = localFiniteSpan(values)
span = nan(1, size(values, 2));
for columnIndex = 1:size(values, 2)
    finiteValues = values(isfinite(values(:, columnIndex)), columnIndex);
    if numel(finiteValues) >= 2
        span(columnIndex) = max(finiteValues) - min(finiteValues);
    end
end
end
