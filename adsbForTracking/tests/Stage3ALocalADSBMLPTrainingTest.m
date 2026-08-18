classdef Stage3ALocalADSBMLPTrainingTest < matlab.unittest.TestCase
    %STAGE3ALOCALADSBMLPTRAININGTEST Focused Stage 3A acceptance tests.

    methods (TestMethodSetup)
        function addProjectPaths(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            projectRoot = fileparts(testFolder);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
        end
    end

    methods (Test)
        function testPreflightReportAndArtifactCreation(testCase)
            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifactPath = fullfile(tempFixture.Folder, "stage3APreflightOnly.mat");
            reportPath = fullfile(tempFixture.Folder, "stage3APreflightOnly.md");

            summary = trainLocalADSBMLPStage3( ...
                "OutputFolder", tempFixture.Folder, ...
                "ArtifactPath", artifactPath, ...
                "ReportPath", reportPath, ...
                "PreflightOnly", true, ...
                "CreatePlots", false, ...
                "Verbose", false);

            testCase.verifyEqual(exist(artifactPath, "file"), 2);
            testCase.verifyEqual(exist(reportPath, "file"), 2);
            testCase.verifyTrue(summary.config.PreflightOnly);
            testCase.verifyGreaterThan(height(summary.preflightAudit.splitByManeuverClass), 0);
            testCase.verifyGreaterThan(height(summary.preflightAudit.splitByVerticalStatus), 0);
            testCase.verifyGreaterThan(height(summary.preflightAudit.constvelMetricsBySplit), 0);
            testCase.verifyEqual(summary.preflightAudit.previousCovarianceUniqueRowCount, 1);

            reportText = fileread(reportPath);
            testCase.verifyTrue(contains(reportText, "Preflight Audit"));
            testCase.verifyTrue(contains(reportText, "previousCovarianceDiag"));
            testCase.verifyTrue(contains(reportText, "Constvel Metrics By Split"));
        end

        function testShortRealDataStage3ATrainingAndDeltaReconstruction(testCase)
            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifactPath = fullfile(tempFixture.Folder, "stage3AShortTraining.mat");
            reportPath = fullfile(tempFixture.Folder, "stage3AShortTraining.md");

            summary = trainLocalADSBMLPStage3( ...
                "OutputFolder", tempFixture.Folder, ...
                "ArtifactPath", artifactPath, ...
                "ReportPath", reportPath, ...
                "TinyEpochs", 1, ...
                "ShortEpochs", 1, ...
                "MiniBatchSize", 512, ...
                "RunCovariancePhase", "never", ...
                "RunLongTraining", false, ...
                "CreatePlots", false, ...
                "ExecutionEnvironment", "cpu", ...
                "Verbose", false);

            testCase.verifyEqual(exist(artifactPath, "file"), 2);
            testCase.verifyEqual(exist(reportPath, "file"), 2);
            testCase.verifyTrue(isfinite(summary.trainingLadder.shortPhysicsFinalLoss));
            testCase.verifyTrue(all(isfinite(summary.predictions.predictedNextState), "all"));
            testCase.verifyTrue(all(summary.predictions.predictedCovarianceDiag > 0, "all"));
            testCase.verifyEqual( ...
                summary.targetDelta, ...
                summary.nextState - summary.previousState, ...
                "AbsTol", 1e-10);
            testCase.verifyEqual( ...
                summary.predictions.predictedNextState, ...
                summary.previousState + summary.predictions.predictedDelta, ...
                "AbsTol", 1e-10);
            testCase.verifyTrue(contains(reportPath, "stage3AShortTraining.md"));
        end

        function testStage3ATrainerUsesTrainnetWithoutCustomAdamLoop(testCase)
            projectRoot = localProjectRoot();
            sourceText = fileread(fullfile(projectRoot, "trainLocalADSBMLPStage3.m"));

            testCase.verifyTrue(contains(sourceText, "trainnet"));
            testCase.verifyTrue(contains(sourceText, "trainingOptions"));
            testCase.verifyFalse(contains(sourceText, "adamupdate"));
            testCase.verifyFalse(contains(sourceText, "dlfeval"));
        end
    end
end

function projectRoot = localProjectRoot()
%LOCALPROJECTROOT Return the adsbForTracking project root.

testFolder = fileparts(mfilename("fullpath"));
projectRoot = fileparts(testFolder);

end