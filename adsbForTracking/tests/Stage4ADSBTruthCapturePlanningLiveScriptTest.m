classdef Stage4ADSBTruthCapturePlanningLiveScriptTest < matlab.unittest.TestCase
    %STAGE4ADSBTRUTHCAPTUREPLANNINGLIVESCRIPTTEST Verify Stage 4A planning.

    properties
        ProjectRoot
        OutputFolder
        CapturePlan
        PlotOutput
    end

    methods (TestClassSetup)
        function buildStage4AFixture(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            testCase.ProjectRoot = fileparts(testFolder);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.ProjectRoot));

            testCase.OutputFolder = tempname;
            mkdir(testCase.OutputFolder);

            testCase.CapturePlan = helperBuildStage4ADSBTruthCapturePlan( ...
                "ProjectRoot", ...
                testCase.ProjectRoot);
            testCase.PlotOutput = helperPlotStage4ADSBTruthCapturePlan( ...
                testCase.CapturePlan, ...
                "OutputFolder", ...
                testCase.OutputFolder, ...
                "Visible", ...
                "off", ...
                "SaveFigures", ...
                true, ...
                "CloseFigures", ...
                false);
        end
    end

    methods (TestClassTeardown)
        function closeStage4AFigures(~)
            close("all");
        end
    end

    methods (Test)
        function testStage3CArtifactPreferredWhenPresent(testCase)
            plan = testCase.CapturePlan;
            summary = plan.summary;

            testCase.verifyTrue(plan.hasStage3C);
            testCase.verifyTrue(summary.hasStage3C);
            testCase.verifyEqual(exist(plan.stage3CArtifactPath, "file"), 2);
            testCase.verifyEqual(summary.minimumGateShortfall.sessions, 0);
            testCase.verifyEqual(summary.minimumGateShortfall.files, 0);
            testCase.verifyEqual(summary.currentCounts.sessions, 16);
            testCase.verifyEqual(summary.currentCounts.sourceFiles, 16);
            testCase.verifyTrue(summary.isReadyForRetraining);
            localVerifyContains(testCase, summary.collectionDecision, "Basic Stage 3B gates pass");
            localVerifyContains(testCase, summary.collectionDecision, "Do not retrain in Stage 4A");
        end

        function testStage3BFallbackWhenStage3CAbsent(testCase)
            missingStage3CPath = fullfile(tempname, "missingStage3C.mat");
            fallbackPlan = helperBuildStage4ADSBTruthCapturePlan( ...
                "ProjectRoot", ...
                testCase.ProjectRoot, ...
                "Stage3CArtifactPath", ...
                missingStage3CPath);
            shortfall = fallbackPlan.summary.minimumGateShortfall;

            testCase.verifyFalse(fallbackPlan.hasStage3C);
            testCase.verifyFalse(fallbackPlan.summary.hasStage3C);
            testCase.verifyEqual(shortfall.sessions, 2);
            testCase.verifyEqual(shortfall.files, 2);
            testCase.verifyEqual(shortfall.sourceFiles, 2);
        end

        function testPiOnlyEmptyArchiveIsExplicitCollectionPriority(testCase)
            plan = testCase.CapturePlan;
            priorityTable = plan.collectionPriorityTable;
            rowMask = priorityTable.priority == "independent Pi-only holdout";

            testCase.assertTrue(any(rowMask));
            testCase.verifyEqual(plan.summary.piOnlyTruthFileCount, 0);
            testCase.verifyFalse(priorityTable.passed(rowMask));
            testCase.verifyEqual(priorityTable.status(rowMask), "collect_holdout");
            localVerifyContains(testCase, plan.summary.independentHoldoutRecommendation, "Pi-only");
            localVerifyContains(testCase, plan.summary.collectionDecision, "independent Pi-only holdout");
        end

        function testDefaultReceiverOriginIsMetadataPriority(testCase)
            plan = testCase.CapturePlan;
            metadataTable = plan.receiverMetadataTable;
            priorityTable = plan.collectionPriorityTable;
            metadataRow = priorityTable.priority == "receiver-origin metadata";

            testCase.assertTrue(any(metadataRow));
            testCase.verifyEqual(plan.summary.defaultReceiverOriginFileCount, 16);
            testCase.verifyEqual(plan.summary.sessionManifestOriginFileCount, 0);
            testCase.verifyEqual( ...
                metadataTable.fileCount(metadataTable.originSource == "default_receiver_origin"), ...
                16);
            testCase.verifyFalse(priorityTable.passed(metadataRow));
            testCase.verifyEqual(priorityTable.status(metadataRow), "preserve_metadata");
            localVerifyContains(testCase, plan.summary.metadataPreservationRecommendation, "session_manifest.json");
        end

        function testExpectedFigureOutputsCreated(testCase)
            figurePaths = testCase.PlotOutput.figurePaths;
            expectedFigures = [ ...
                "readinessGates", ...
                "motionCoverage", ...
                "modelDataProblem", ...
                "splitCoverage", ...
                "captureCampaign"];

            for figureIdx = 1:numel(expectedFigures)
                figureName = expectedFigures(figureIdx);
                testCase.verifyTrue(isfield(figurePaths, figureName));
                testCase.verifyEqual(exist(figurePaths.(figureName), "file"), 2);
            end
        end

        function testEveryStage4PlotHasLabelsAndTitle(testCase)
            figureHandles = testCase.PlotOutput.figureHandles;
            figureNames = string(fieldnames(figureHandles));

            for figureIdx = 1:numel(figureNames)
                figureName = figureNames(figureIdx);
                figureHandle = figureHandles.(figureName);
                axesHandles = findall(figureHandle, "Type", "axes");

                testCase.verifyNotEmpty(axesHandles, ...
                    "No axes found for " + figureName);

                for axesIdx = 1:numel(axesHandles)
                    axisHandle = axesHandles(axesIdx);
                    testCase.verifyNotEmpty(localGraphicsText(axisHandle.XLabel), ...
                        "Missing xlabel for " + figureName);
                    testCase.verifyNotEmpty(localGraphicsText(axisHandle.YLabel), ...
                        "Missing ylabel for " + figureName);
                    testCase.verifyNotEmpty(localGraphicsText(axisHandle.Title), ...
                        "Missing title for " + figureName);
                end
            end
        end

        function testLiveScriptRunsWithoutNewCaptures(testCase)
            scriptPath = fullfile( ...
                testCase.ProjectRoot, ...
                "stage4ADSBTruthCapturePlanningLiveScript.m");
            liveOutputFolder = fullfile(testCase.OutputFolder, "liveScript");

            testCase.assertEqual(exist(scriptPath, "file"), 2);

            stage4OutputFolder = liveOutputFolder; %#ok<NASGU>
            run(scriptPath);

            testCase.verifyTrue(exist("stage4Plan", "var") == 1);
            testCase.verifyTrue(exist("stage4CaptureCommandTemplate", "var") == 1);
            testCase.verifyTrue(exist("stage4TruthFolderLayout", "var") == 1);
            testCase.verifyTrue(exist("stage4CollectionPriorityTable", "var") == 1);
            testCase.verifyTrue(stage4Plan.hasStage3C);
            testCase.verifyEqual(stage4Plan.summary.minimumGateShortfall.sessions, 0);
            testCase.verifyEqual(stage4Plan.summary.piOnlyTruthFileCount, 0);
            localVerifyContains(testCase, stage4Decision, "Pi-only");
            localVerifyContains(testCase, stage4MetadataPreservationRecommendation, "session_manifest.json");

            expectedFiles = [ ...
                "stage4A_readiness_gates.png", ...
                "stage4A_motion_coverage_shortfall.png", ...
                "stage4A_model_vs_data_problem.png", ...
                "stage4A_split_coverage.png", ...
                "stage4A_capture_campaign_progress.png"];

            for fileIdx = 1:numel(expectedFiles)
                figurePath = fullfile(liveOutputFolder, expectedFiles(fileIdx));
                testCase.verifyEqual(exist(figurePath, "file"), 2);
            end
        end
    end
end

function textValue = localGraphicsText(textHandle)
%LOCALGRAPHICSTEXT Normalize graphics label text.

textValue = strtrim(strjoin(string(textHandle.String), " "));

end

function localVerifyContains(testCase, textValue, expectedText)
%LOCALVERIFYCONTAINS Compatibility wrapper for string containment checks.

testCase.verifyTrue(contains(string(textValue), expectedText), ...
    "Expected text to contain: " + expectedText);

end
