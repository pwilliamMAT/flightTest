classdef StageReviewLiveScriptTest < matlab.unittest.TestCase
    %STAGEREVIEWLIVESCRIPTTEST Verify the educational review artifact.

    methods (TestMethodSetup)
        function addProjectPaths(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            projectRoot = fileparts(testFolder);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
        end
    end

    methods (Test)
        function testReviewArtifactsAlign(testCase)
            projectRoot = localProjectRoot();
            review = helperBuildStageReviewArtifacts("ProjectRoot", projectRoot);

            pairCount = size(review.dataset.nextState, 1);
            testCase.verifyEqual(height(review.pairReviewTable), pairCount);
            testCase.verifySize(review.constvelPredictedState, [pairCount, 6]);
            testCase.verifySize(review.nnPredictedNextState, [pairCount, 6]);
            testCase.verifyTrue(all(isfinite(review.constvelPredictedState), "all"));
            testCase.verifyTrue(all(isfinite(review.nnPredictedNextState), "all"));
            testCase.verifySize(review.stage3PredictedNextState, [pairCount, 6]);
            testCase.verifyTrue(isfield(review, "hasStage3B"));
            if review.hasStage3B
                testCase.verifyGreaterThan(height(review.stage3BMetricComparisonTable), 0);
                testCase.verifyGreaterThan(height(review.stage3BPairErrorTable), 0);
            end
            testCase.verifyEqual(review.metricComparisonTable.method(1), "constvel baseline");
            testCase.verifyEqual(review.metricComparisonTable.method(2), "smoke MLP");
            testCase.verifyGreaterThan( ...
                review.metricComparisonTable.positionRMSEMeters(2), ...
                review.metricComparisonTable.positionRMSEMeters(1));
        end

        function testTrajectoryConversionIsFinite(testCase)
            review = helperBuildStageReviewArtifacts("ProjectRoot", localProjectRoot());
            trajectoryData = helperBuildStageReviewTrajectories( ...
                review, ...
                "TrackHex", review.defaultTrackHex, ...
                "MaxPairs", 20);

            testCase.verifyGreaterThan(numel(trajectoryData.timeSeconds), 2);
            testCase.verifyTrue(all(diff(trajectoryData.timeSeconds) > 0));
            testCase.verifyTrue(all(isfinite(trajectoryData.truthLLA), "all"));
            testCase.verifyTrue(all(isfinite(trajectoryData.constvelLLA), "all"));
            testCase.verifyTrue(all(isfinite(trajectoryData.nnSmokeLLA), "all"));
        end


        function testStage3AErrorComparisonHelper(testCase)
            review = helperBuildStageReviewArtifacts("ProjectRoot", localProjectRoot());
            cleanup = onCleanup(@() close("all"));

            errorComparison = helperPlotStageReviewStage3ErrorComparison( ...
                review, ...
                "TrackHex", review.defaultTrackHex, ...
                "MaxPairs", 20);

            if review.hasStage3A
                testCase.verifyEqual(height(errorComparison), 2);
                testCase.verifyEqual(errorComparison.method(1), "constvel");
                testCase.verifyEqual(errorComparison.method(2), "Stage 3A delta MLP");
                testCase.verifyTrue(all(isfinite(errorComparison.trackPositionRMSEMeters)));
            else
                testCase.verifyEqual(height(errorComparison), 1);
                testCase.verifyTrue(isnan(errorComparison.trackPositionRMSEMeters));
            end
        end
        function testLiveScriptRunsWithoutInteractiveGlobe(testCase)
            projectRoot = localProjectRoot();
            scriptPath = fullfile(projectRoot, "stageReviewLiveScript.m");

            testCase.assertEqual(exist(scriptPath, "file"), 2);

            enableInteractiveGlobe = false; %#ok<NASGU>
            run(scriptPath);

            testCase.verifyTrue(exist("review", "var") == 1);
            testCase.verifyTrue(exist("metricComparison", "var") == 1);
            testCase.verifyTrue(exist("maneuverCounts", "var") == 1);
            testCase.verifyTrue(exist("stage3TrackErrorComparison", "var") == 1);
            if review.hasStage3B
                testCase.verifyTrue(exist("stage3BAggregateRMSE", "var") == 1);
                testCase.verifyTrue(exist("stage3BDataReadiness", "var") == 1);
                testCase.verifyTrue(exist("stage3BPositionAbsErrorSummary", "var") == 1);
                testCase.verifyGreaterThan(height(stage3BAggregateRMSE), 0);
                testCase.verifyEqual(height(stage3BPositionAbsErrorSummary), 2);
            else
                testCase.verifyTrue(exist("stage3BStatus", "var") == 1);
            end
            testCase.verifyGreaterThanOrEqual(height(metricComparison), 2);
            testCase.verifyGreaterThan(height(maneuverCounts), 0);
            testCase.verifyGreaterThan(height(stage3TrackErrorComparison), 0);
        end
    end
end

function projectRoot = localProjectRoot()
%LOCALPROJECTROOT Return the adsbForTracking project root.

testFolder = fileparts(mfilename("fullpath"));
projectRoot = fileparts(testFolder);

end
