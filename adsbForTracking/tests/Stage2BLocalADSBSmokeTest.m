classdef Stage2BLocalADSBSmokeTest < matlab.unittest.TestCase
    %STAGE2BLOCALADSBSMOKETEST Focused acceptance tests for Stage 2B.

    methods (TestMethodSetup)
        function addProjectPaths(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            projectRoot = fileparts(testFolder);
            parserRoot = fullfile(fileparts(projectRoot), "BistaticDataAnalysis");

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(parserRoot));
        end
    end

    methods (Test)
        function testStateOrderAndVelocityConversionSynthetic(testCase)
            receiverOriginLLA = [42.2999333, -71.349333, 15.0];
            t0 = posixtime(datetime(2026, 6, 22, 10, 21, 24, "TimeZone", "UTC"));

            syntheticTrack = struct();
            syntheticTrack.hex = "ABC123";
            syntheticTrack.callsign = "TST001";
            syntheticTrack.t_utc = [t0; t0 + 5];
            syntheticTrack.lat_deg = [42.3000; 42.3001];
            syntheticTrack.lon_deg = [-71.3490; -71.3489];
            syntheticTrack.alt_m = [1000; 1005];
            syntheticTrack.speed_mps = [100; 100];
            syntheticTrack.track_deg = [90; 90];
            syntheticTrack.vrate_mps = [5; 5];

            pairData = helperBuildLocalADSBStatePairs( ...
                syntheticTrack, ...
                "synthetic_adsb.txt", ...
                "synthetic_session", ...
                receiverOriginLLA, ...
                [100, 10, 100, 10, 150, 5], ...
                30);

            testCase.verifySize(pairData.previousState, [1, 6]);
            testCase.verifyEqual(pairData.previousState(1, 2), 100, "AbsTol", 1e-10);
            testCase.verifyEqual(pairData.previousState(1, 4), 0, "AbsTol", 1e-10);
            testCase.verifyEqual(pairData.previousState(1, 6), 5, "AbsTol", 1e-10);
            testCase.verifyEqual(pairData.nextState(1, 2), 100, "AbsTol", 1e-10);
            testCase.verifyEqual(pairData.nextState(1, 4), 0, "AbsTol", 1e-10);
            testCase.verifyEqual(pairData.nextState(1, 6), 5, "AbsTol", 1e-10);
        end

        function testRealDataSmokeDatasetBuild(testCase)
            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            datasetPath = fullfile(tempFixture.Folder, "stage2BLocalADSBDatasetTest.mat");
            reportPath = fullfile(tempFixture.Folder, "stage2BLocalADSBDatasetTest.md");

            dataset = buildLocalADSBStatePairDataset( ...
                "SourceFiles", localTruthFile(testCase), ...
                "OutputPath", datasetPath, ...
                "ReportPath", reportPath, ...
                "Verbose", false);

            testCase.verifyGreaterThanOrEqual(size(dataset.previousState, 1), 1000);
            testCase.verifyEqual(dataset.stateOrder, ["x", "vx", "y", "vy", "z", "vz"]);
            testCase.verifyTrue(all(isfinite(dataset.previousState), "all"));
            testCase.verifyTrue(all(isfinite(dataset.nextState), "all"));
            testCase.verifyTrue(all(dataset.dtSeconds > 0));
            testCase.verifyTrue(all(dataset.dtSeconds <= 30));
            testCase.verifyTrue(all(dataset.previousCovarianceDiag > 0, "all"));
            testCase.verifyTrue(dataset.splitManifest.leakageCheckPassed);
            testCase.verifyTrue(dataset.splitManifest.aircraftSplitCheckPassed);
            testCase.verifyTrue(isfield(dataset.baselineConstVelMetrics, "positionRMSEMeters"));
            testCase.verifyTrue(isfinite(dataset.baselineConstVelMetrics.positionRMSEMeters));
            testCase.verifyEqual(exist(datasetPath, "file"), 2);
            testCase.verifyEqual(exist(reportPath, "file"), 2);
        end

        function testMLPSmokeTraining(testCase)
            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            datasetPath = fullfile(tempFixture.Folder, "stage2BLocalADSBDatasetTrainTest.mat");
            trainingPath = fullfile(tempFixture.Folder, "stage2BLocalADSBMLPTrainTest.mat");
            reportPath = fullfile(tempFixture.Folder, "stage2BLocalADSBTrainTest.md");

            dataset = buildLocalADSBStatePairDataset( ...
                "SourceFiles", localTruthFile(testCase), ...
                "OutputPath", datasetPath, ...
                "ReportPath", reportPath, ...
                "Verbose", false);

            trainingSummary = trainLocalADSBMLPSmoke( ...
                datasetPath, ...
                "OutputPath", trainingPath, ...
                "ReportPath", reportPath, ...
                "NumEpochs", 2, ...
                "MiniBatchSize", 256, ...
                "Verbose", false);

            testCase.verifyTrue(trainingSummary.finiteLoss);
            testCase.verifyEqual(trainingSummary.outputSize, [size(dataset.previousState, 1), 12]);
            testCase.verifyTrue(trainingSummary.correctOutputDimensions);
            testCase.verifyTrue(trainingSummary.positivePredictedVariances);
            testCase.verifyGreaterThan(trainingSummary.minimumPredictedVariance, 0);
            testCase.verifyEqual(exist(trainingPath, "file"), 2);
        end
    end
end

function truthFile = localTruthFile(testCase)
%LOCALTRUTHFILE Return the verified Stage 2B source file.

testFolder = fileparts(mfilename("fullpath"));
projectRoot = fileparts(testFolder);
truthFile = fullfile( ...
    fileparts(projectRoot), ...
    "BistaticDataAnalysis", ...
    "captures", ...
    "20260622T102123", ...
    "truth", ...
    "0_20260622_102124_adsb_20260622T102123.txt.gz");

testCase.assertEqual(exist(truthFile, "file"), 2, ...
    "The verified local ADS-B truth file must exist for the smoke test.");

end
