classdef Stage2CManeuverCharacterizationTest < matlab.unittest.TestCase
    %STAGE2CMANEUVERCHARACTERIZATIONTEST Focused Stage 2C acceptance tests.

    methods (TestMethodSetup)
        function addProjectPaths(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            projectRoot = fileparts(testFolder);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(projectRoot));
        end
    end

    methods (Test)
        function testSyntheticManeuverLabelAssignment(testCase)
            previousState = [ ...
                0, 100, 0, 0, 1000, 0; ...
                0, 100, 0, 0, 1000, 0; ...
                0, 100, 0, 0, 1000, 0; ...
                0, 100, 0, 0, 1000, 2; ...
                0, 100, 0, 0, 1000, 0];
            nextState = previousState;
            nextState(2, 2) = 105;
            nextState(3, 2) = 100 * sind(92);
            nextState(3, 4) = 100 * cosd(92);
            nextState(4, 6) = 4;
            dtSeconds = [1; 1; 1; 1; 6];

            [pairTable, labelSummary] = helperAssignADSBManeuverLabels( ...
                previousState, ...
                nextState, ...
                dtSeconds);

            testCase.verifyEqual(string(pairTable.maneuverClass(1)), "constvel_like");
            testCase.verifyEqual(string(pairTable.maneuverClass(2)), "constacc_like");
            testCase.verifyEqual(string(pairTable.maneuverClass(3)), "constturn_like");
            testCase.verifyEqual(string(pairTable.maneuverClass(4)), "constacc_like");
            testCase.verifyEqual(string(pairTable.maneuverClass(5)), "mixed_or_sparse");
            testCase.verifyEqual(string(pairTable.verticalStatus(4)), "climb");
            testCase.verifyEqual(string(pairTable.dtRegime(5)), "sparse_update");
            testCase.verifyEqual(sum(labelSummary.countsByManeuverClass.pairCount), height(pairTable));
        end

        function testRealDataProducesStage2CReport(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            projectRoot = fileparts(testFolder);
            datasetPath = fullfile( ...
                projectRoot, ...
                "artifacts", ...
                "stage2B", ...
                "localADSBStatePairDataset.mat");
            tempFixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);

            testCase.assertEqual(exist(datasetPath, "file"), 2, ...
                "The Stage 2B dataset artifact must exist before Stage 2C can run.");

            characterization = runStage2CManeuverCharacterization( ...
                "DatasetPath", datasetPath, ...
                "OutputFolder", tempFixture.Folder, ...
                "Verbose", false);

            testCase.verifyEqual(exist(characterization.reportPath, "file"), 2);
            testCase.verifyEqual(exist(characterization.artifactPath, "file"), 2);
            testCase.verifyEqual(exist(characterization.figurePath, "file"), 2);
            testCase.verifyEqual( ...
                sum(characterization.labelSummary.countsByManeuverClass.pairCount), ...
                height(characterization.maneuverPairTable));
            testCase.verifyGreaterThan(height(characterization.baselineByManeuverClass), 0);
            testCase.verifyGreaterThanOrEqual( ...
                characterization.diversityAssessment.constvelPercent, ...
                0);

            reportText = fileread(characterization.reportPath);
            testCase.verifyTrue(contains(reportText, "constvel"));
            testCase.verifyTrue(contains(lower(reportText), "lacks diversity"));
        end
    end
end
