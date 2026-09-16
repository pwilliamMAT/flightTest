classdef ADSBReadinessTest < matlab.unittest.TestCase
    %ADSBREADINESSTEST Regression tests for the offline PASS/HOLD gate.

    properties (SetAccess = private)
        AnalysisFolder
    end

    methods (TestClassSetup)
        function addAnalysisPath(testCase)
            test_folder = fileparts(mfilename('fullpath'));
            testCase.AnalysisFolder = string(fileparts(test_folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                testCase.AnalysisFolder));
        end
    end

    methods (Test)
        function testHealthyArchivePasses(testCase)
            fixture = localCreateFixture("interior", true, false);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));

            result = localRunFixture(fixture.Archive, fixture.StartUTC);

            testCase.verifyEqual(result.Status, "pass");
            testCase.verifyTrue(result.TruthReady);
            testCase.verifyTrue(result.ReadyForManualSelection);
            testCase.verifyTrue(all(result.Gates.Passed));
            testCase.verifyTrue(result.Candidates.CandidateEligible(1));
            testCase.verifyFalse(result.Candidates.CPAIsTrackEndpoint(1));
        end

        function testEndpointCPAProducesHold(testCase)
            fixture = localCreateFixture("endpoint", true, false);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));

            result = localRunFixture(fixture.Archive, fixture.StartUTC);

            testCase.verifyEqual(result.Status, "hold");
            testCase.verifyTrue(result.TruthReady);
            testCase.verifyFalse(result.ReadyForManualSelection);
            testCase.verifyFalse(result.Candidates.CandidateEligible(1));
            testCase.verifySubstring( ...
                result.Candidates.HoldReason(1), ...
                "cpa_at_window_endpoint");
        end

        function testMissingVelocityProducesHold(testCase)
            fixture = localCreateFixture("interior", false, false);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));

            result = localRunFixture(fixture.Archive, fixture.StartUTC);

            testCase.verifyEqual(result.Status, "hold");
            testCase.verifyFalse(result.TruthReady);
            velocity_gate = result.Gates.Gate == "velocity_coverage";
            testCase.verifyFalse(result.Gates.Passed(velocity_gate));
            testCase.verifySubstring( ...
                result.Candidates.HoldReason(1), "missing_velocity");
        end

        function testAbsentWindowOverlapProducesHold(testCase)
            fixture = localCreateFixture("interior", true, false);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));
            future_start = fixture.StartUTC + seconds(100);

            result = localRunFixture(fixture.Archive, future_start);

            testCase.verifyEqual(result.Status, "hold");
            testCase.verifyFalse(result.TruthReady);
            overlap_gate = result.Gates.Gate == "window_edge_coverage";
            testCase.verifyFalse(result.Gates.Passed(overlap_gate));
            testCase.verifyEmpty(result.Candidates);
        end

        function testCorruptGzipReturnsDiagnosticHold(testCase)
            fixture = localCreateFixture("interior", true, true);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));

            result = localRunFixture(fixture.Archive, fixture.StartUTC);

            testCase.verifyEqual(result.Status, "hold");
            testCase.verifyFalse(result.TruthReady);
            testCase.verifyEqual( ...
                result.ErrorIdentifier, ...
                "loadADSBRemoterArchive:invalidGzipArchive");
            testCase.verifySubstring(result.ErrorMessage, "truncated or corrupt");
            testCase.verifyFalse(result.Gates.Passed(1));
        end

        function testManifestSuppliesWindow(testCase)
            fixture = localCreateFixture("interior", true, false);
            testCase.addTeardown(@() localRemoveFolder(fixture.Folder));
            manifest_path = localWriteManifest(fixture);

            result = localRunFixture(manifest_path, []);

            testCase.verifyEqual(result.Status, "pass");
            testCase.verifyEqual( ...
                result.Summary.WindowSource, "session_manifest");
            testCase.verifyEqual(result.Summary.SessionID, "synthetic-session");
            testCase.verifyEqual( ...
                result.Summary.WindowStartUTC, fixture.StartUTC);
        end
    end
end

function result = localRunFixture(source, start_utc)
args = { ...
    'WindowDurationS', 10, ...
    'MinTrackCount', 1, ...
    'MinPositionFixCount', 5, ...
    'MaxWindowEdgeGapS', 1, ...
    'MaxMedianUpdateGapS', 2, ...
    'MinCandidateFixCount', 5, ...
    'MaxCandidateMedianUpdateGapS', 2, ...
    'MaxCandidateEdgeGapS', 1, ...
    'MinCandidateWindowCoverage', 0.8, ...
    'Verbose', false};
if ~isempty(start_utc)
    args = [{'WindowStartUTC', start_utc}, args];
end
result = runADSBReadinessTest(source, args{:});
end

function fixture = localCreateFixture(cpa_kind, include_velocity, corrupt_gzip)
folder = string(tempname) + "_adsb_readiness";
mkdir(folder);
plain_path = fullfile(folder, 'adsb_synthetic.txt');

start_utc = datetime(2026, 9, 1, 12, 0, 0, 'TimeZone', 'UTC');
sample_times = start_utc + seconds(0:10);
if cpa_kind == "interior"
    longitudes = linspace(-71.36, -71.34, numel(sample_times));
else
    longitudes = linspace(-71.39, -71.37, numel(sample_times));
end
latitudes = repmat(42.2999333, size(longitudes));
lines = localSBSLines( ...
    sample_times, latitudes, longitudes, include_velocity);
writelines(lines, plain_path);

gzip(plain_path, folder);
delete(plain_path);
archive_path = plain_path + ".gz";
if corrupt_gzip
    localTruncateFile(archive_path);
end

fixture = struct( ...
    'Folder', folder, ...
    'Archive', archive_path, ...
    'StartUTC', start_utc);
end

function lines = localSBSLines( ...
        sample_times, latitudes, longitudes, include_velocity)
line_count = numel(sample_times) .* (1 + double(include_velocity));
lines = strings(line_count, 1);
line_idx = 0;
for sample_idx = 1:numel(sample_times)
    date_text = string(sample_times(sample_idx), 'yyyy/MM/dd');
    time_text = string(sample_times(sample_idx), 'HH:mm:ss.SSS');

    if include_velocity
        line_idx = line_idx + 1;
        fields = repmat("", 1, 22);
        fields([1, 2, 5, 7, 8, 9, 10, 13, 14, 17]) = [ ...
            "MSG", "4", "ABC123", ...
            date_text, time_text, date_text, time_text, ...
            "220", "90", "0"];
        lines(line_idx) = strjoin(fields, ",");
    end

    line_idx = line_idx + 1;
    fields = repmat("", 1, 22);
    fields([1, 2, 5, 7, 8, 9, 10, 12, 15, 16, 17]) = [ ...
        "MSG", "3", "ABC123", ...
        date_text, time_text, date_text, time_text, ...
        "5000", string(latitudes(sample_idx)), ...
        string(longitudes(sample_idx)), "0"];
    lines(line_idx) = strjoin(fields, ",");
end
end

function manifest_path = localWriteManifest(fixture)
manifest = struct( ...
    'session_id', 'synthetic-session', ...
    'radar_epoch_utc', posixtime(fixture.StartUTC), ...
    'radar_active_window_s', 10, ...
    'adsb_files', {{char("adsb_synthetic.txt.gz")}});
manifest_path = fullfile(fixture.Folder, 'session_manifest.json');
fid = fopen(manifest_path, 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(manifest, PrettyPrint=true));
clear cleanup
end

function localTruncateFile(file_path)
fid = fopen(file_path, 'r');
read_cleanup = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
clear read_cleanup

fid = fopen(file_path, 'w');
write_cleanup = onCleanup(@() fclose(fid));
fwrite(fid, bytes(1:max(1, floor(numel(bytes) / 2))), 'uint8');
clear write_cleanup
end

function localRemoveFolder(folder)
if isfolder(folder)
    rmdir(folder, 's');
end
end
