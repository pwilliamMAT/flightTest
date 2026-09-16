function summary = helperBuildPassiveRadarPrecheckSummary(captures)
%HELPERBUILDPASSIVERADARPRECHECKSUMMARY Build one row per capture.

arguments
    captures (:, 1) struct
end

nCaptures = numel(captures);
captureIndex = (1:nCaptures).';
file = strings(nCaptures, 1);
metadataPass = false(nCaptures, 1);
integrityPass = false(nCaptures, 1);
headroomPass = false(nCaptures, 1);
pilotPass = false(nCaptures, 1);
correlationPass = false(nCaptures, 1);
ecaPass = false(nCaptures, 1);
capturePass = false(nCaptures, 1);
surveillanceRMSDBFS = nan(nCaptures, 1);
referenceRMSDBFS = nan(nCaptures, 1);
referenceMinusSurveillanceDB = nan(nCaptures, 1);
roleRecommendation = strings(nCaptures, 1);

for index = 1:nCaptures
    current = captures(index);
    file(index) = current.File;
    metadataPass(index) = current.Checks.Metadata.Pass;
    integrityPass(index) = current.Checks.Integrity.Pass;
    headroomPass(index) = current.Checks.Headroom.Pass;
    pilotPass(index) = current.Checks.Pilot.Pass;
    correlationPass(index) = current.Checks.Correlation.Pass;
    ecaPass(index) = current.Checks.ECA.Pass;
    capturePass(index) = current.Pass;
    surveillanceRMSDBFS(index) = localChannelValue( ...
        current.Checks.Headroom.RMSDBFS, ...
        current.ConfiguredSurveillanceChannel);
    referenceRMSDBFS(index) = localChannelValue( ...
        current.Checks.Headroom.RMSDBFS, ...
        current.ConfiguredReferenceChannel);
    referenceMinusSurveillanceDB(index) = ...
        current.Advisory.ReferencePowerMinusSurveillanceDB;
    roleRecommendation(index) = current.Advisory.Recommendation;
end

summary = table( ...
    captureIndex, file, metadataPass, integrityPass, headroomPass, ...
    pilotPass, correlationPass, ecaPass, capturePass, ...
    surveillanceRMSDBFS, referenceRMSDBFS, ...
    referenceMinusSurveillanceDB, roleRecommendation);
end

function value = localChannelValue(values, channelIndex)
value = NaN;
if isfinite(channelIndex) && channelIndex >= 1 && channelIndex <= numel(values)
    value = values(channelIndex);
end
end
