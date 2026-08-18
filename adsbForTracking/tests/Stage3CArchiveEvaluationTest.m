classdef Stage3CArchiveEvaluationTest < matlab.unittest.TestCase
    %STAGE3CARCHIVEEVALUATIONTEST Verify archived ADS-B evaluation extension.

    properties
        ProjectRoot
        FlightTestRoot
        OutputFolder
        Summary
    end

    methods (TestClassSetup)
        function buildStage3CFixture(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            testCase.ProjectRoot = fileparts(testFolder);
            testCase.FlightTestRoot = fileparts(testCase.ProjectRoot);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(testCase.ProjectRoot));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(testCase.FlightTestRoot, "BistaticDataAnalysis")));

            testCase.OutputFolder = tempname;
            mkdir(testCase.OutputFolder);

            testCase.Summary = runStage3CArchiveADSBEvaluation( ...
                "OutputFolder", ...
                testCase.OutputFolder, ...
                "CreatePlots", ...
                true, ...
                "Verbose", ...
                false);
        end
    end

    methods (Test)
        function testArchiveRootDiscoveryAndPiOnlyEmpty(testCase)
            inventory = testCase.Summary.archiveInventory;
            sourceTable = inventory.sourceFileTable;
            layoutSummary = inventory.layoutSummary;
            piOnlyRow = layoutSummary.layout == "pi_only/truth";

            testCase.verifyEqual(height(sourceTable), 16);
            testCase.verifyTrue(all(sourceTable.sourceRole == "testing_machine"));
            testCase.verifyTrue(any(contains(sourceTable.truthLayout, "testing_machine/captures")));
            testCase.verifyTrue(any(piOnlyRow));
            testCase.verifyEqual(layoutSummary.sourceFileCount(piOnlyRow), 0);
            testCase.verifyEqual(testCase.Summary.archiveSummary.piOnlyTruthFileCount, 0);
        end

        function testDotNetGzipFallbackReadsValidFile(testCase)
            sourceFile = testCase.Summary.archiveInventory.sourceFileTable.originalSourceFile(1);
            fallbackFolder = fullfile(testCase.OutputFolder, "fallbackHelperTest");
            inflatedFile = helperInflateGzipWithDotNet(sourceFile, fallbackFolder);

            testCase.verifyEqual(exist(inflatedFile, "file"), 2);

            fid = fopen(inflatedFile, "r");
            cleanup = onCleanup(@() fclose(fid));
            firstLine = string(fgetl(fid));

            testCase.verifyTrue(startsWith(firstLine, "MSG,"));
        end

        function testStage3CProducesArtifactsReportFiguresAndScoring(testCase)
            summary = testCase.Summary;
            figurePaths = summary.figurePaths;
            expectedFigures = [ ...
                "archiveUsability", ...
                "readinessGates", ...
                "motionUpdateCoverage"];

            testCase.verifyEqual(exist(summary.artifactPath, "file"), 2);
            testCase.verifyEqual(exist(summary.reportPath, "file"), 2);
            testCase.verifyEqual(exist(summary.inventoryTablePath, "file"), 2);
            testCase.verifyEqual(exist(summary.inventoryArtifactPath, "file"), 2);
            testCase.verifyGreaterThan(height(summary.metricComparisonTable), 0);
            testCase.verifyGreaterThan(height(summary.stage3BSummary.pairErrorTable), 0);

            for figureIdx = 1:numel(expectedFigures)
                figureName = expectedFigures(figureIdx);
                testCase.verifyTrue(isfield(figurePaths, figureName));
                testCase.verifyEqual(exist(figurePaths.(figureName), "file"), 2);
            end
        end

        function testArchiveAcceptanceCounts(testCase)
            archiveSummary = testCase.Summary.archiveSummary;

            testCase.verifyEqual(archiveSummary.sourceFileCount, 16);
            testCase.verifyEqual(archiveSummary.usableSessionCount, 16);
            testCase.verifyEqual(archiveSummary.usablePairCount, 15013);
            testCase.verifyEqual(archiveSummary.aircraftTrackCount, 222);
            testCase.verifyTrue(archiveSummary.stage3BReadinessPassed);
            testCase.verifyEqual(archiveSummary.fallbackRecoveredFileCount, archiveSummary.nativeGunzipFailureCount);
        end
    end
end
