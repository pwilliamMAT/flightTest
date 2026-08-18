classdef Stage3BAggregateEvaluationTest < matlab.unittest.TestCase
    %STAGE3BAGGREGATEEVALUATIONTEST Verify frozen aggregate ADS-B evaluation.

    properties
        ProjectRoot
        OutputFolder
        Summary
    end

    methods (TestClassSetup)
        function buildStage3BFixture(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            testCase.ProjectRoot = fileparts(testFolder);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.ProjectRoot));

            testCase.OutputFolder = tempname;
            mkdir(testCase.OutputFolder);

            testCase.Summary = runStage3BAggregateADSBEvaluation( ...
                "OutputFolder", testCase.OutputFolder, ...
                "AggregateDatasetPath", fullfile(testCase.OutputFolder, "stage3BTestDataset.mat"), ...
                "AggregateDatasetReportPath", fullfile(testCase.OutputFolder, "stage3BTestDatasetReport.md"), ...
                "ArtifactPath", fullfile(testCase.OutputFolder, "stage3BTestEvaluation.mat"), ...
                "ReportPath", fullfile(testCase.OutputFolder, "stage3BTestEvaluationReport.md"), ...
                "CreatePlots", false, ...
                "CreateGlobeSnapshot", false, ...
                "Verbose", false);
        end
    end

    methods (Test)
        function testAggregateArtifactAndReportCreated(testCase)
            summary = testCase.Summary;

            testCase.verifyEqual(exist(summary.artifactPath, "file"), 2);
            testCase.verifyEqual(exist(summary.reportPath, "file"), 2);
            testCase.verifyGreaterThan(size(summary.nextState, 1), 0);
            testCase.verifyEqual(height(summary.metricComparisonTable), 2);
            testCase.verifyEqual(summary.metricComparisonTable.method(1), "constvel baseline");
            testCase.verifyEqual(summary.metricComparisonTable.method(2), "Frozen Stage 3A delta MLP");
        end

        function testFrozenReconstructionAndSameSampleScoring(testCase)
            summary = testCase.Summary;
            pairCount = size(summary.nextState, 1);
            reconstructed = summary.previousState + ...
                summary.predictions.frozenStage3APredictedDelta;
            maxAbsError = max( ...
                abs(reconstructed - summary.predictions.frozenStage3APredictedNextState), ...
                [], ...
                "all");

            testCase.verifyLessThanOrEqual(maxAbsError, 1e-10);
            testCase.verifyTrue(all(summary.metrics.aggregate.sampleCount == pairCount));
            testCase.verifyTrue(all(summary.verificationTable.passed));
        end

        function testCurrentDataFailsRetrainingReadiness(testCase)
            summary = testCase.Summary;

            testCase.verifyFalse(summary.dataReadiness.isReadyForRetraining);
            testCase.verifyEqual(summary.dataReadiness.sessionCount, 1);
            testCase.verifyEqual(summary.dataReadiness.sourceFileCount, 1);
            testCase.verifyTrue(any(~summary.dataReadiness.gateTable.passed));
        end

        function testReviewLoaderAcceptsOptionalStage3BArtifact(testCase)
            review = helperBuildStageReviewArtifacts( ...
                "ProjectRoot", testCase.ProjectRoot, ...
                "Stage3BEvaluationPath", testCase.Summary.artifactPath);

            testCase.verifyTrue(review.hasStage3B);
            testCase.verifyGreaterThan(height(review.stage3BMetricComparisonTable), 0);
            testCase.verifyFalse(review.stage3BDataReadiness.isReadyForRetraining);
            testCase.verifyEqual(height(review.stage3BPairErrorTable), size(testCase.Summary.nextState, 1));
        end
    end
end
