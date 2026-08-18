function summary = runStage2OpenSkyProbe(sampleDurationSeconds, sampleCadenceSeconds)
%RUNSTAGE2OPENSKYPROBE Execute the bounded Stage 2A OpenSky go/no-go probe.
% The probe intentionally stops at data-source feasibility. It does not build
% a training dataset and does not train any neural network.

arguments
    sampleDurationSeconds (1, 1) double {mustBePositive} = 10 * 60
    sampleCadenceSeconds (1, 1) double {mustBePositive} = 15
end

projectRoot = fileparts(mfilename("fullpath"));
reportPath = fullfile(projectRoot, "stage2OpenSkyGoNoGoReport.md");

datasetsUrl = "https://opensky-network.org/datasets/";
stateUrl = "https://opensky-network.org/api/states/all?lamin=41.83&lomin=-71.96&lamax=42.73&lomax=-70.74";

config = struct();
config.centerLatDeg = 42.2833;
config.centerLonDeg = -71.3495;
config.centerAltMeters = 0;
config.radiusMeters = 50000;
config.stateOrder = ["x", "vx", "y", "vy", "z", "vz"];
config.covarianceStd = [100, 10, 100, 10, 150, 5];
config.sampleDurationSeconds = sampleDurationSeconds;
config.sampleCadenceSeconds = sampleCadenceSeconds;
config.datasetsUrl = datasetsUrl;
config.stateUrl = stateUrl;

fprintf("Stage 2A OpenSky go/no-go probe\n");
fprintf("Sample duration [s]:\t%.0f\n", sampleDurationSeconds);
fprintf("Sample cadence [s]:\t%.0f\n", sampleCadenceSeconds);
fprintf("Natick center [deg]:\t%.4f, %.4f\n", config.centerLatDeg, config.centerLonDeg);
fprintf("Radius [m]:\t%.0f\n", config.radiusMeters);

datasetsAccess = helperFetchOpenSkyMetadata(datasetsUrl, "OpenSky datasets page");
stateAccess = helperFetchOpenSkyMetadata(stateUrl, "Natick current-state endpoint");

targetSnapshotCount = floor(sampleDurationSeconds / sampleCadenceSeconds) + 1;
snapshots = cell(targetSnapshotCount, 1);
retrievalTimes = NaT(targetSnapshotCount, 1, "TimeZone", "UTC");
snapshotSuccess = false(targetSnapshotCount, 1);
snapshotMessages = strings(targetSnapshotCount, 1);
snapshotRawRecordCounts = zeros(targetSnapshotCount, 1);

probeStartTime = datetime("now", "TimeZone", "UTC");
options = weboptions("Timeout", 30, "ContentType", "text");

fprintf("Starting current-state sampling at %s\n", string(probeStartTime));

for snapshotIdx = 1:targetSnapshotCount
    scheduledTime = probeStartTime + seconds((snapshotIdx - 1) * sampleCadenceSeconds);
    waitSeconds = seconds(scheduledTime - datetime("now", "TimeZone", "UTC"));

    if waitSeconds > 0
        pause(waitSeconds);
    end

    retrievalTimes(snapshotIdx) = datetime("now", "TimeZone", "UTC");

    try
        rawJson = webread(stateUrl, options);
        snapshots{snapshotIdx} = jsondecode(rawJson);
        snapshotSuccess(snapshotIdx) = true;
        snapshotMessages(snapshotIdx) = "OK";

        if isfield(snapshots{snapshotIdx}, "states") && ~isempty(snapshots{snapshotIdx}.states)
            snapshotRawRecordCounts(snapshotIdx) = numel(snapshots{snapshotIdx}.states);
        end
    catch err
        snapshots{snapshotIdx} = [];
        snapshotSuccess(snapshotIdx) = false;
        snapshotMessages(snapshotIdx) = string(err.message);
    end

    fprintf("Snapshot\t%d/%d\t%s\trecords\t%d\t%s\n", ...
        snapshotIdx, ...
        targetSnapshotCount, ...
        string(retrievalTimes(snapshotIdx)), ...
        snapshotRawRecordCounts(snapshotIdx), ...
        snapshotMessages(snapshotIdx));
end

probeEndTime = datetime("now", "TimeZone", "UTC");

rawTable = helperParseOpenSkyStates(snapshots, retrievalTimes, snapshotSuccess);
analysis = helperBuildOpenSkyStatePairs(rawTable, config);

summary = struct();
summary.generatedAt = datetime("now", "TimeZone", "UTC");
summary.probeStartTime = probeStartTime;
summary.probeEndTime = probeEndTime;
summary.datasetsAccess = datasetsAccess;
summary.stateAccess = stateAccess;
summary.snapshotSuccess = snapshotSuccess;
summary.snapshotMessages = snapshotMessages;
summary.snapshotRawRecordCounts = snapshotRawRecordCounts;
summary.retrievalTimes = retrievalTimes;
summary.rawTable = rawTable;
summary.analysis = analysis;
summary.config = config;

helperWriteOpenSkyGoNoGoReport(reportPath, summary);

fprintf("Report written:\t%s\n", reportPath);
fprintf("Final decision:\t%s\n", analysis.decision);

end
