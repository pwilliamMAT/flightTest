classdef VisualizationControlsTest < matlab.unittest.TestCase
    %VISUALIZATIONCONTROLSTEST Tests for graphics-profile normalization.

    methods (TestClassSetup)
        function addSourceFolder(testCase)
            srcFolder = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(srcFolder));
        end
    end

    methods (Test)
        function testCoreProfileKeepsOnlyHighValueViews(testCase)
            visualization = helperResolveVisualizationProfile( ...
                'VisualizationProfile', 'core', ...
                'ExpectedPartCount', 15);

            testCase.verifyEqual(visualization.profile, "core");
            testCase.verifyFalse(visualization.plot_assessment_figures);
            testCase.verifyFalse(visualization.plot_per_part_rdm);
            testCase.verifyFalse(visualization.plot_ellipse_globe);
            testCase.verifyFalse(visualization.plot_tracker_globe);
            testCase.verifyFalse(visualization.plot_track_legend);
            testCase.verifyTrue(visualization.plot_interactive_rdm_viewer);
            testCase.verifyTrue(visualization.plot_truth_diagnostics);
            testCase.verifyEqual(visualization.max_expected_open_figure_count, 3);
            testCase.verifyFalse(visualization.ranked_crash_causes.active_in_profile(1));
        end

        function testFullProfileUsesSingleWindowPerPartViewer(testCase)
            visualization = helperResolveVisualizationProfile( ...
                'VisualizationProfile', 'full', ...
                'ExpectedPartCount', 12);

            testCase.verifyTrue(visualization.plot_per_part_rdm);
            testCase.verifyEqual(visualization.max_expected_open_figure_count, 12);

            viewer_row = visualization.figure_inventory( ...
                visualization.figure_inventory.figure_group == "Per-part RDM viewer", :);
            testCase.verifyEqual(height(viewer_row), 1);
            testCase.verifyEqual(viewer_row.figure_count_when_enabled, 1);
            testCase.verifyTrue(contains(lower(viewer_row.notes), "single-window"));
        end

        function testHeadlessProfileDisablesAllInteractiveFigures(testCase)
            visualization = helperResolveVisualizationProfile( ...
                'VisualizationProfile', 'headless', ...
                'ExpectedPartCount', 4);

            testCase.verifyEqual(visualization.profile, "headless");
            testCase.verifyEqual(visualization.max_expected_open_figure_count, 0);
            testCase.verifyFalse(any(visualization.figure_inventory.enabled));
            testCase.verifyFalse(any(visualization.ranked_crash_causes.active_in_profile));
        end

        function testGeoAxesFallbackCanBeForcedExplicitly(testCase)
            visualization = helperResolveVisualizationProfile( ...
                'VisualizationProfile', 'core', ...
                'PlotTrackerGlobe', true, ...
                'Force2DGeographicFallback', true, ...
                'ExpectedPartCount', 3);

            tracker_row = visualization.figure_inventory( ...
                visualization.figure_inventory.figure_group == "Tracker geographic view", :);

            testCase.verifyTrue(visualization.plot_tracker_globe);
            testCase.verifyTrue(visualization.force_2d_geographic_fallback);
            testCase.verifyTrue(contains(tracker_row.renderer_type, "geoaxes"));
            testCase.verifyFalse(visualization.ranked_crash_causes.active_in_profile(1));
        end

        function testRestartCommandsPreferSavedSnapshots(testCase)
            truth_snapshot = struct( ...
                'compact_path', "C:\tmp\truth_diag_input.mat", ...
                'full_path', "C:\tmp\truth_diag_input_full.mat");
            detector_snapshot = struct( ...
                'path', "C:\tmp\detector_replay_input.mat");

            commands = helperBuildSessionRestartCommands( ...
                '20260611T101530', truth_snapshot, detector_snapshot, ...
                'VisualizationProfile', 'core');

            testCase.verifyTrue(contains(commands.full_session, ...
                "runBistaticAnalysisSession('20260611T101530'"));
            testCase.verifyTrue(contains(commands.full_session, ...
                "'VisualizationProfile', 'core'"));
            testCase.verifyTrue(contains(commands.truth_only, ...
                "runDetectionTruthDiagnostics('C:\tmp\truth_diag_input.mat'"));
            testCase.verifyTrue(contains(commands.truth_only, "'PlotRDMOverlays', false"));
            testCase.verifyTrue(contains(commands.detector_only, ...
                "runDetectorReplaySweep('C:\tmp\detector_replay_input.mat'"));
            testCase.verifyTrue(contains(commands.detector_only, ...
                "'Cases', struct('Name', 'baseline')"));
        end

        function testRestartCommandsHandleMissingSnapshots(testCase)
            commands = helperBuildSessionRestartCommands( ...
                '20260611T101530', struct(), struct(), ...
                'VisualizationProfile', 'headless');

            testCase.verifyTrue(contains(commands.full_session, ...
                "'VisualizationProfile', 'headless'"));
            testCase.verifyEqual(commands.truth_only, "");
            testCase.verifyEqual(commands.detector_only, "");
        end
    end
end
