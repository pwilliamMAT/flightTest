classdef SyntheticHDTVSessionGeneratorTest < matlab.unittest.TestCase
    %SYNTHETICHDTVSESSIONGENERATORTEST Verification-aligned coverage for v1 increment 1.

    properties (Constant)
        ApprovedTxLLA = [42.310278, -71.236667, 431.9];
        ApprovedRxLLA = [42.2999333, -71.349333, 15.0];
    end

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            tests_folder = fileparts(mfilename('fullpath'));
            src_folder = fileparts(tests_folder);
            repo_root = fileparts(src_folder);

            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(src_folder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(repo_root, 'BistaticDataAnalysis')));
        end
    end

    methods (TestMethodSetup)
        function suppressFigures(testCase)
            original_visibility = get(groot, 'DefaultFigureVisible');
            set(groot, 'DefaultFigureVisible', 'off');
            testCase.addTeardown(@() set(groot, 'DefaultFigureVisible', original_visibility));
        end
    end

    methods (Test)
        function testBaselineScenarioConfigDeclaresApprovedSites(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);

            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);

            testCase.verifyEqual(cfg.tx_lla_deg_m, testCase.ApprovedTxLLA, AbsTol=1e-12);
            testCase.verifyEqual(cfg.rx_lla_deg_m, testCase.ApprovedRxLLA, AbsTol=1e-12);
            testCase.verifyEqual(cfg.purpose, 'detector_truth_projection_triage');
            testCase.verifyEqual(cfg.capture_repetitions, 1);
            testCase.verifyGreaterThan(cfg.part_duration_s, 0);
            testCase.verifyEqual(cfg.seed_echo_source_mode, 'not_applicable');
            testCase.verifyFalse(cfg.seed_echo_conditioning.enabled);
        end

        function testTerrainSceneCoversApprovedGeometry(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);

            terrain_info = helperSyntheticBuildSceneTerrain(cfg);

            testCase.verifyTrue(terrain_info.tx_in_coverage);
            testCase.verifyTrue(terrain_info.rx_in_coverage);
            testCase.verifyGreaterThan(terrain_info.raster_size(1), 0);
            testCase.verifyGreaterThan(terrain_info.raster_size(2), 0);
        end

        function testGeneratedTruthIsTraceableAndConventionCompatible(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);
            truth_bundle = helperSyntheticGenerateTruth(cfg);
            truth_path = fullfile(fixture.Folder, 'adsb_test.txt');

            helperSyntheticWriteADSBTruth(truth_path, truth_bundle.adsb_tracks);
            loaded_tracks = loadADSBTruth({truth_path}, 'Verbose', false);
            geometry = helperDeriveTxRxGeometry(cfg.tx_lla_deg_m, cfg.rx_lla_deg_m);

            testCase.verifyEqual(numel(loaded_tracks), numel(truth_bundle.adsb_tracks));
            testCase.verifyEqual( ...
                SyntheticHDTVSessionGeneratorTest.localTrackKeys(loaded_tracks), ...
                SyntheticHDTVSessionGeneratorTest.localTrackKeys(truth_bundle.adsb_tracks));
            testCase.verifyEqual(truth_bundle.bistatic_tracks(1).L_m, ...
                geometry.baseline_3d_m, AbsTol=1e-9);
            testCase.verifyEqual(numel(truth_bundle.targets(1).t_rel_s), ...
                numel(truth_bundle.targets(1).t_utc));
        end

        function testBaselineTargetsStayOutsideNearRangeGuard(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);
            truth_bundle = helperSyntheticGenerateTruth(cfg);

            min_range_excess_m = arrayfun( ...
                @(track) min(track.R_excess_m), ...
                truth_bundle.bistatic_tracks);

            testCase.verifyGreaterThan(min(min_range_excess_m), 5e3);
        end

        function testBasebandArtifactsReadBackAsTwoChannelFiles(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSession( ...
                fixture.Folder, 'bb_readback_session');
            radar_file_path = SyntheticHDTVSessionGeneratorTest.localResolveRelativePath( ...
                artifact.session_folder, artifact.radar_files{1});

            reader = comm.BasebandFileReader(radar_file_path, 'SamplesPerFrame', 32);
            cleanup_reader = onCleanup(@() release(reader));
            samples = reader();
            metadata = reader.Metadata;

            testCase.verifySize(samples, [32, 2]);
            testCase.verifyEqual(double(reader.SampleRate), ...
                artifact.scenario_config.sample_rate_hz, AbsTol=1e-9);
            testCase.verifyEqual(double(reader.CenterFrequency), ...
                artifact.scenario_config.center_frequency_hz, AbsTol=1e-9);
            testCase.verifyEqual(double(metadata.Duration_s), ...
                artifact.scenario_config.part_duration_s, AbsTol=1e-12);
            testCase.verifyEqual(char(string(metadata.SessionID)), artifact.session_id);
        end

        function testProbeSeedHelperCreatesReadableDualChannelFile(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);

            [seed_path, seed_info] = helperSyntheticCreateProbeSeed( ...
                'OutputFolder', fixture.Folder, ...
                'FileName', 'probe_seed.bb');

            reader = comm.BasebandFileReader(seed_path, 'SamplesPerFrame', 64);
            cleanup_reader = onCleanup(@() release(reader));
            samples = reader();
            metadata = reader.Metadata;

            testCase.verifyEqual(seed_info.seed_file_path, seed_path);
            testCase.verifySize(samples, [64, 2]);
            testCase.verifyGreaterThan(rms(double(samples(:, 2))), 0);
            testCase.verifyEqual(char(string(metadata.SignalMode)), 'probe_seed_v1');
        end

        function testSeedWaveformLoadsAndNormalizesToTargetRMS(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            seed_path = SyntheticHDTVSessionGeneratorTest.localCreateProbeSeed(fixture.Folder);
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'SeedSourcePath', seed_path, ...
                'SeedTargetRMS', 0.2);
            n_output_samples = round(cfg.sample_rate_hz * cfg.part_duration_s);

            [seed_waveform, seed_info] = helperSyntheticLoadSeedWaveform(cfg, n_output_samples, 0);

            testCase.verifySize(seed_waveform, [n_output_samples, 1]);
            testCase.verifyEqual(rms(double(seed_waveform)), cfg.seed_target_rms, RelTol=1e-2);
            testCase.verifyEqual(seed_info.seed_path, seed_path);
            testCase.verifyEqual(seed_info.seed_channel_index, cfg.seed_channel_index);
        end

        function testEchoSeedConditioningSuppressesProbePilotAndPreservesRMS(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            probe_seed_folder = fullfile(fixture.Folder, 'probe_seed');
            [seed_path, seed_info] = helperSyntheticCreateProbeSeed( ...
                'OutputFolder', probe_seed_folder, ...
                'FileName', 'probe_seed.bb');
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'SeedSourcePath', seed_path, ...
                'SignalMode', 'seed_backed_bistatic_v1');
            n_output_samples = round(cfg.sample_rate_hz * cfg.part_duration_s);

            [seed_waveform, ~] = helperSyntheticLoadSeedWaveform(cfg, n_output_samples, 0);
            [conditioned_seed, conditioning_summary] = helperSyntheticBuildConditionedEchoSeed( ...
                seed_waveform, ...
                cfg.sample_rate_hz, ...
                cfg.seed_echo_conditioning);

            raw_tone_power_db = SyntheticHDTVSessionGeneratorTest.localMeasureTonePower( ...
                seed_waveform, ...
                cfg.sample_rate_hz, ...
                seed_info.pilot_offset_hz);
            conditioned_tone_power_db = SyntheticHDTVSessionGeneratorTest.localMeasureTonePower( ...
                conditioned_seed, ...
                cfg.sample_rate_hz, ...
                seed_info.pilot_offset_hz);

            testCase.verifyTrue(conditioning_summary.enabled);
            testCase.verifyTrue(conditioning_summary.pilot_suppression_applied);
            testCase.verifyLessThan(conditioned_tone_power_db, raw_tone_power_db - 10);
            testCase.verifyEqual( ...
                rms(double(conditioned_seed)), ...
                rms(double(seed_waveform)), ...
                RelTol=5e-2);
        end

        function testManifestPreservesWorkflowFieldsAndSyntheticProvenance(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSession( ...
                fixture.Folder, 'manifest_session');

            manifest = helperLoadSessionManifest(artifact.manifest_path);
            raw_manifest = jsondecode(fileread(artifact.manifest_path));

            testCase.verifyEqual(manifest.session_id, artifact.session_id);
            testCase.verifyEqual(numel(manifest.radar_files), 1);
            testCase.verifyEqual(numel(manifest.adsb_files), 1);
            testCase.verifyEqual(raw_manifest.data_origin, 'synthetic');
            testCase.verifyEqual(raw_manifest.scenario_id, artifact.scenario_config.scenario_id);
            testCase.verifyEqual(raw_manifest.generator_name, artifact.scenario_config.generator_name);
            testCase.verifyEqual(raw_manifest.truth_source, artifact.scenario_config.truth_source);
        end

        function testSeedBackedBasebandChannelsAreNonzeroAndDistinct(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSeedBackedSession( ...
                fixture.Folder, 'seed_backed_readback_session');
            radar_file_path = SyntheticHDTVSessionGeneratorTest.localResolveRelativePath( ...
                artifact.session_folder, artifact.radar_files{1});

            reader = comm.BasebandFileReader(radar_file_path, 'SamplesPerFrame', 8192);
            cleanup_reader = onCleanup(@() release(reader));
            samples = reader();

            testCase.verifyGreaterThan(rms(double(samples(:, 1))), 0);
            testCase.verifyGreaterThan(rms(double(samples(:, 2))), 0);
            testCase.verifyGreaterThan(norm(double(samples(:, 1) - samples(:, 2))), 0);
        end

        function testSeedBackedManifestIncludesSeedProvenance(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSeedBackedSession( ...
                fixture.Folder, 'seed_backed_manifest_session');

            manifest = jsondecode(fileread(artifact.manifest_path));

            testCase.verifyEqual(manifest.signal_mode, 'seed_backed_bistatic_v1');
            testCase.verifyEqual(manifest.seed_source_path, artifact.scenario_config.seed_source_path);
            testCase.verifyEqual(manifest.seed_channel_index, artifact.scenario_config.seed_channel_index);
            testCase.verifyEqual(manifest.seed_echo_source_mode, artifact.scenario_config.seed_echo_source_mode);
            testCase.verifyTrue(manifest.seed_echo_conditioning.enabled);
            testCase.verifyEqual( ...
                manifest.seed_echo_conditioning.target_echo_source, ...
                artifact.scenario_config.seed_echo_conditioning.target_echo_source);
            testCase.verifyEqual(manifest.reference_gain_db, artifact.scenario_config.reference_gain_db);
            testCase.verifyEqual(manifest.direct_path_gain_db, artifact.scenario_config.direct_path_gain_db);
        end

        function testSeedBackedArtifactKeepsPartSynthesisSummaries(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateValidationSeedBackedSession( ...
                fixture.Folder, 'validation_summary_session');

            testCase.verifyTrue(isfield(artifact, 'part_synthesis_summaries'));
            testCase.verifyEqual(numel(artifact.part_synthesis_summaries), 1);
            testCase.verifyEqual(artifact.part_synthesis_summaries{1}.signal_mode, 'seed_backed_bistatic_v1');
            testCase.verifyEqual( ...
                artifact.part_synthesis_summaries{1}.seed_echo_source_mode, ...
                'conditioned_target_echoes_v1');
            testCase.verifyTrue(artifact.part_synthesis_summaries{1}.echo_seed_conditioning.enabled);
            testCase.verifyTrue( ...
                artifact.part_synthesis_summaries{1}.echo_seed_conditioning.pilot_suppression_applied);
            testCase.verifyEqual( ...
                artifact.part_synthesis_summaries{1}.echo_seed_conditioning.reference_source, ...
                'full_seed');
            testCase.verifyEqual( ...
                artifact.part_synthesis_summaries{1}.echo_seed_conditioning.direct_path_source, ...
                'full_seed');
            testCase.verifyEqual( ...
                numel(artifact.part_synthesis_summaries{1}.track_summaries), ...
                numel(artifact.scenario_config.targets));
            testCase.verifyTrue(all(arrayfun( ...
                @(track) all(isfinite(track.delay_samples_range)), ...
                artifact.part_synthesis_summaries{1}.track_summaries)));
        end

        function testTimingOverridesPropagateAcrossTruthAndManifest(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            capture_duration_s = 0.05;
            capture_repetitions = 3;
            capture_spacing_s = 0.10;
            truth_sample_period_s = 0.01;
            expected_active_window_s = capture_duration_s * capture_repetitions + ...
                (capture_repetitions - 1) * capture_spacing_s;

            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'SessionID', 'timing_override_session', ...
                'CaptureDurationS', capture_duration_s, ...
                'CaptureRepetitions', capture_repetitions, ...
                'CaptureRepetitionSpacingS', capture_spacing_s, ...
                'TruthSamplePeriodS', truth_sample_period_s);
            truth_bundle = helperSyntheticGenerateTruth(cfg);
            artifact = generateSyntheticHDTVSession('ScenarioConfig', cfg);
            manifest = helperLoadSessionManifest(artifact.manifest_path);

            testCase.verifyEqual(cfg.expected_overlap_window_s(2), expected_active_window_s, AbsTol=1e-12);
            testCase.verifyEqual(max(truth_bundle.sample_times_s), expected_active_window_s, AbsTol=1e-12);
            testCase.verifyEqual(artifact.part_start_offsets_s, [0; 0.15; 0.30], AbsTol=1e-12);
            testCase.verifyEqual(numel(artifact.radar_files), capture_repetitions);
            testCase.verifyEqual(manifest.capture_duration_s, capture_duration_s, AbsTol=1e-12);
            testCase.verifyEqual(manifest.capture_repetitions, capture_repetitions);
            testCase.verifyEqual(manifest.capture_repetition_spacing_s, capture_spacing_s, AbsTol=1e-12);
            testCase.verifyEqual(manifest.radar_active_window_s, expected_active_window_s, AbsTol=1e-12);
        end

        function testCustomTargetsDriveSavedTruthAndADSBOutput(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'SessionID', 'custom_target_session');
            custom_targets = cfg.targets;
            capture_window_s = cfg.expected_overlap_window_s(2);

            custom_targets(1).target_id = 'TGT901';
            custom_targets(1).icao_hex = 'ABC901';
            custom_targets(1).callsign = 'EDIT901';
            custom_targets(1).echo_gain_db = -18;
            custom_targets(1).waypoints_lla_deg_m = [ ...
                42.314500, -71.332000, 3100; ...
                42.316000, -71.322000, 3200; ...
                42.317500, -71.312000, 3300];
            custom_targets(1).time_of_arrival_s = [0; capture_window_s / 2; capture_window_s];
            cfg.targets = custom_targets;

            artifact = generateSyntheticHDTVSession('ScenarioConfig', cfg);
            traceability_truth = load(artifact.traceability_truth_path, 'truth_bundle');
            adsb_truth_path = SyntheticHDTVSessionGeneratorTest.localResolveRelativePath( ...
                artifact.session_folder, artifact.adsb_files{1});
            loaded_adsb_tracks = loadADSBTruth({adsb_truth_path}, 'Verbose', false);

            adsb_idx = SyntheticHDTVSessionGeneratorTest.localFindTrackIndexByCallsign( ...
                loaded_adsb_tracks, 'EDIT901');

            testCase.verifyEqual(traceability_truth.truth_bundle.targets(1).target_id, 'TGT901');
            testCase.verifyEqual(traceability_truth.truth_bundle.targets(1).callsign, 'EDIT901');
            testCase.verifyEqual( ...
                traceability_truth.truth_bundle.targets(1).lat_deg(1), ...
                custom_targets(1).waypoints_lla_deg_m(1, 1), AbsTol=1e-9);
            testCase.verifyEqual( ...
                traceability_truth.truth_bundle.targets(1).lon_deg(end), ...
                custom_targets(1).waypoints_lla_deg_m(end, 2), AbsTol=1e-9);
            testCase.verifyEqual(loaded_adsb_tracks(adsb_idx).callsign, 'EDIT901');
            testCase.verifyEqual(loaded_adsb_tracks(adsb_idx).hex, 'ABC901');
            testCase.verifyEqual( ...
                loaded_adsb_tracks(adsb_idx).lat_deg(1), ...
                custom_targets(1).waypoints_lla_deg_m(1, 1), AbsTol=1e-6);
            testCase.verifyEqual( ...
                loaded_adsb_tracks(adsb_idx).lon_deg(end), ...
                custom_targets(1).waypoints_lla_deg_m(end, 2), AbsTol=1e-6);
        end

        function testPackagedSessionReplaysThroughCurrentWrapper(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSession( ...
                fixture.Folder, 'wrapper_session');

            out = runBistaticAnalysisSession(artifact.session_id, ...
                'DatasetRoot', fixture.Folder, ...
                'Verbose', false, ...
                'SaveTruthDiagnosticSnapshot', false, ...
                'SaveDetectorReplaySnapshot', false);

            testCase.verifyEqual(char(out.session_id), artifact.session_id);
            testCase.verifyEqual(numel(out.radar_files), 1);
            testCase.verifyEqual(numel(out.adsb_files), 1);
            testCase.verifyTrue(isfield(out, 'adsb_aligned'));
        end

        function testSeedBackedPackagedSessionReplaysThroughCurrentWrapper(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateSeedBackedSession( ...
                fixture.Folder, 'seed_backed_wrapper_session');

            out = runBistaticAnalysisSession(artifact.session_id, ...
                'DatasetRoot', fixture.Folder, ...
                'Verbose', false, ...
                'SaveTruthDiagnosticSnapshot', false, ...
                'SaveDetectorReplaySnapshot', false);

            n_aligned_tracks = sum(arrayfun(@(track) any(isfinite(track.R_excess_m)), out.adsb_aligned));

            testCase.verifyEqual(char(out.session_id), artifact.session_id);
            testCase.verifyEqual(numel(out.radar_files), 1);
            testCase.verifyEqual(numel(out.adsb_files), 1);
            testCase.verifyGreaterThanOrEqual(n_aligned_tracks, 1);
        end

        function testScenarioSummaryHelperReportsWaypointEndpoints(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'CaptureDurationS', 0.08, ...
                'CaptureRepetitions', 2, ...
                'CaptureRepetitionSpacingS', 0.12);

            [scenario_summary, target_summary_table] = helperSyntheticSummarizeScenarioConfig(cfg);

            testCase.verifyEqual(scenario_summary.part_duration_s, 0.08, AbsTol=1e-12);
            testCase.verifyEqual(scenario_summary.capture_repetitions, 2);
            testCase.verifyEqual(scenario_summary.capture_repetition_spacing_s, 0.12, AbsTol=1e-12);
            testCase.verifyEqual(scenario_summary.radar_active_window_s, 0.28, AbsTol=1e-12);
            testCase.verifyEqual(scenario_summary.n_targets, numel(cfg.targets));
            testCase.verifyEqual(target_summary_table.TargetID(1), string(cfg.targets(1).target_id));
            testCase.verifyEqual(target_summary_table.Callsign(2), string(cfg.targets(2).callsign));
            testCase.verifyEqual( ...
                target_summary_table.StartLatDeg(1), ...
                cfg.targets(1).waypoints_lla_deg_m(1, 1), AbsTol=1e-12);
            testCase.verifyEqual( ...
                target_summary_table.EndLonDeg(2), ...
                cfg.targets(2).waypoints_lla_deg_m(end, 2), AbsTol=1e-12);
        end

        function testScenarioOverviewPlotHelperRunsForConfiguredTruth(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);
            truth_bundle = helperSyntheticGenerateTruth(cfg);
            plot_handles = helperSyntheticPlotScenarioOverview(cfg, truth_bundle);
            testCase.addTeardown(@() close(plot_handles.figure));

            testCase.verifyTrue(isgraphics(plot_handles.figure));
            testCase.verifyTrue(isgraphics(plot_handles.geometry_axes, 'axes'));
            testCase.verifyTrue(isgraphics(plot_handles.altitude_axes, 'axes'));
            testCase.verifyTrue(isgraphics(plot_handles.range_axes, 'axes'));
            testCase.verifyTrue(isgraphics(plot_handles.doppler_axes, 'axes'));
        end

        function testScenarioOverviewPlotUsesSyntheticTruthLabels(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = SyntheticHDTVSessionGeneratorTest.localBuildValidationSeedBackedConfig( ...
                fixture.Folder, 'preview_label_session');
            truth_bundle = helperSyntheticGenerateTruth(cfg);
            plot_handles = helperSyntheticPlotScenarioOverview(cfg, truth_bundle);
            testCase.addTeardown(@() close(plot_handles.figure));

            geometry_title = string(plot_handles.geometry_axes.Title.String);
            range_lines = findobj(plot_handles.range_axes, 'Type', 'line');
            range_labels = string(get(range_lines, 'DisplayName'));

            testCase.verifyTrue(any(contains(geometry_title, "Sampled Target Motion")));
            testCase.verifyTrue(any(contains(range_labels, "Synthetic Truth:")));
        end

        function testValidationFigureOverlaysTruthOnBothRDMs(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateValidationSeedBackedSession( ...
                fixture.Folder, 'validation_overlay_session');

            validation_summary = helperSyntheticValidateGeneratedIQ( ...
                artifact, ...
                'PlotFigures', true, ...
                'PrecheckFigures', false, ...
                'FigureVisibility', 'off', ...
                'Verbose', false);
            testCase.addTeardown(@() close(validation_summary.figure_handles.validation));

            axes_handles = findobj(validation_summary.figure_handles.validation, 'Type', 'axes');
            axis_titles = arrayfun(@(ax) string(ax.Title.String), axes_handles);

            before_axis = axes_handles(find(contains(axis_titles, "Before ECA-C"), 1, 'first'));
            after_axis = axes_handles(find(contains(axis_titles, "After ECA-C"), 1, 'first'));

            before_display_names = arrayfun( ...
                @(line_handle) string(line_handle.DisplayName), ...
                findobj(before_axis, 'Type', 'line'));
            after_display_names = arrayfun( ...
                @(line_handle) string(line_handle.DisplayName), ...
                findobj(after_axis, 'Type', 'line'));

            testCase.verifyTrue(any(contains(before_display_names, "Synthetic Truth:")));
            testCase.verifyTrue(any(contains(after_display_names, "Synthetic Truth:")));
            testCase.verifyEqual(before_axis.YLim(1), 0, AbsTol=1e-12);
            testCase.verifyEqual(after_axis.YLim(1), 0, AbsTol=1e-12);
            testCase.verifyEqual(before_axis.YLim(2), 30, AbsTol=1e-9);
            testCase.verifyEqual(after_axis.YLim(2), 30, AbsTol=1e-9);

            colorbars = findall(validation_summary.figure_handles.validation, 'Type', 'ColorBar');
            colorbar_labels = strings(1, numel(colorbars));

            for idx = 1 : numel(colorbars)
                colorbar_labels(idx) = string(colorbars(idx).Label.String);
            end

            testCase.verifyNumElements(colorbars, 2);
            testCase.verifyTrue(all(colorbar_labels == "CAF Magnitude [dB]"));
        end

        function testWalkthroughSessionIDHelperRefreshesPriorAutoIDOnRerun(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            prior_auto_session_id = 'seed_demo_old';
            mkdir(fullfile(fixture.Folder, prior_auto_session_id));

            [session_id, last_auto_generated_session_id, resolution_info] = ...
                helperSyntheticResolveWalkthroughSessionID( ...
                    'OutputRoot', fixture.Folder, ...
                    'SessionID', prior_auto_session_id, ...
                    'PreviousAutoSessionID', prior_auto_session_id, ...
                    'PreferredAutoSessionID', 'seed_demo_new');

            testCase.verifyEqual(session_id, 'seed_demo_new');
            testCase.verifyEqual(last_auto_generated_session_id, 'seed_demo_new');
            testCase.verifyTrue(resolution_info.used_auto_session_id);
            testCase.verifyTrue(resolution_info.refreshed_previous_auto_session_id);
            testCase.verifyFalse(resolution_info.preserved_requested_session_id);
        end

        function testWalkthroughSessionIDHelperRefreshesLegacyAutoIDWithoutSentinel(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            legacy_auto_session_id = 'seed_demo_20260714T080355';
            mkdir(fullfile(fixture.Folder, legacy_auto_session_id));

            [session_id, last_auto_generated_session_id, resolution_info] = ...
                helperSyntheticResolveWalkthroughSessionID( ...
                    'OutputRoot', fixture.Folder, ...
                    'SessionID', legacy_auto_session_id, ...
                    'PreferredAutoSessionID', 'seed_demo_20260715T100700000');

            testCase.verifyEqual(session_id, 'seed_demo_20260715T100700000');
            testCase.verifyEqual(last_auto_generated_session_id, 'seed_demo_20260715T100700000');
            testCase.verifyTrue(resolution_info.used_auto_session_id);
            testCase.verifyTrue(resolution_info.refreshed_previous_auto_session_id);
            testCase.verifyFalse(resolution_info.preserved_requested_session_id);
        end

        function testWalkthroughSessionIDHelperPreservesPinnedSessionID(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);

            [session_id, last_auto_generated_session_id, resolution_info] = ...
                helperSyntheticResolveWalkthroughSessionID( ...
                    'OutputRoot', fixture.Folder, ...
                    'SessionID', 'manual_session', ...
                    'PreviousAutoSessionID', 'seed_demo_old', ...
                    'PreferredAutoSessionID', 'seed_demo_new');

            testCase.verifyEqual(session_id, 'manual_session');
            testCase.verifyEqual(last_auto_generated_session_id, "");
            testCase.verifyFalse(resolution_info.used_auto_session_id);
            testCase.verifyFalse(resolution_info.refreshed_previous_auto_session_id);
            testCase.verifyTrue(resolution_info.preserved_requested_session_id);
        end

        function testWalkthroughSessionIDHelperAddsSuffixForAutoIDCollision(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            mkdir(fullfile(fixture.Folder, 'seed_demo_candidate'));

            [session_id, last_auto_generated_session_id, resolution_info] = ...
                helperSyntheticResolveWalkthroughSessionID( ...
                    'OutputRoot', fixture.Folder, ...
                    'PreferredAutoSessionID', 'seed_demo_candidate');

            testCase.verifyEqual(session_id, 'seed_demo_candidate_rerun_01');
            testCase.verifyEqual(last_auto_generated_session_id, 'seed_demo_candidate_rerun_01');
            testCase.verifyTrue(resolution_info.used_auto_session_id);
            testCase.verifyFalse(resolution_info.refreshed_previous_auto_session_id);
        end

        function testGenerateSyntheticHDTVSessionReportsSessionCollisionRecovery(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            SyntheticHDTVSessionGeneratorTest.localGenerateSession( ...
                fixture.Folder, 'existing_session');
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', fixture.Folder, ...
                'SessionID', 'existing_session');

            caught_error = [];
            try
                generateSyntheticHDTVSession('ScenarioConfig', cfg);
            catch ME
                caught_error = ME;
            end

            testCase.verifyEqual(caught_error.identifier, ...
                'generateSyntheticHDTVSession:sessionExists');
            testCase.verifyTrue(contains( ...
                caught_error.message, ...
                'clear the walkthrough auto-generated sessionID'));
        end

        function testValidationHelperReturnsClosedLoopSummary(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateValidationSeedBackedSession( ...
                fixture.Folder, 'closed_loop_validation_session');

            validation_summary = helperSyntheticValidateGeneratedIQ( ...
                artifact, ...
                'PlotFigures', false, ...
                'PrecheckFigures', false, ...
                'Verbose', false);

            n_finite_observed_targets = sum(arrayfun( ...
                @(target) isfinite(target.observed_peak_range_m) && isfinite(target.observed_peak_doppler_hz), ...
                validation_summary.target_summaries));

            testCase.verifyTrue(validation_summary.integrity.overall_pass);
            testCase.verifyEqual( ...
                validation_summary.direct_path.comparison_delay_samples, ...
                round(artifact.scenario_config.direct_path_delay_samples));
            testCase.verifyEqual( ...
                numel(validation_summary.target_summaries), ...
                numel(artifact.scenario_config.targets));
            testCase.verifyGreaterThanOrEqual(n_finite_observed_targets, 1);
            testCase.verifyGreaterThan(validation_summary.readiness.range_bin_spacing_m, 0);
            testCase.verifyGreaterThan(validation_summary.readiness.doppler_bin_spacing_hz, 0);
            testCase.verifyFalse(any([validation_summary.readiness.target_readiness.inside_detector_near_range_guard]));
        end

        function testValidationHelperClearsTruthAlignedDopplerColumnAdvisory(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateValidationSeedBackedSession( ...
                fixture.Folder, 'validation_column_advisory_session');

            validation_summary = helperSyntheticValidateGeneratedIQ( ...
                artifact, ...
                'PlotFigures', false, ...
                'PrecheckFigures', false, ...
                'Verbose', false);

            per_target = validation_summary.doppler_column_advisory.per_target;
            present_mask = [per_target.present_in_dwell];

            testCase.verifyEqual( ...
                validation_summary.doppler_column_advisory.metric_name, ...
                'target_aligned_doppler_column_check');
            testCase.verifyTrue(validation_summary.doppler_column_advisory.all_targets_clear);
            testCase.verifyFalse(any([per_target(present_mask).flagged]));
        end

        function testValidationHelperReportsFiniteLocalProminenceForVisibleTargets(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            artifact = SyntheticHDTVSessionGeneratorTest.localGenerateValidationSeedBackedSession( ...
                fixture.Folder, 'validation_prominence_session');

            validation_summary = helperSyntheticValidateGeneratedIQ( ...
                artifact, ...
                'PlotFigures', false, ...
                'PrecheckFigures', false, ...
                'Verbose', false);

            present_mask = arrayfun(@(target) target.present_in_dwell, validation_summary.target_summaries);
            finite_prominence_mask = present_mask & arrayfun( ...
                @(target) isfinite(target.local_prominence_db), ...
                validation_summary.target_summaries);
            finite_targets = validation_summary.target_summaries(finite_prominence_mask);

            testCase.verifyEqual( ...
                validation_summary.target_prominence_summary.metric_name, ...
                'local_caf_prominence_db');
            testCase.verifyGreaterThanOrEqual(sum(finite_prominence_mask), 1);
            testCase.verifyTrue(all(arrayfun( ...
                @(target) target.local_background_cell_count > 0, ...
                finite_targets)));
            testCase.verifyTrue(all(arrayfun( ...
                @(target) isfinite(target.local_background_level_db), ...
                finite_targets)));
        end

        function testTruthAndMetadataRepeatAcrossReruns(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            run_a_root = fullfile(fixture.Folder, 'run_a');
            run_b_root = fullfile(fixture.Folder, 'run_b');
            session_id = 'repeatable_session';

            artifact_a = SyntheticHDTVSessionGeneratorTest.localGenerateSession(run_a_root, session_id);
            artifact_b = SyntheticHDTVSessionGeneratorTest.localGenerateSession(run_b_root, session_id);
            truth_text_a = fileread(SyntheticHDTVSessionGeneratorTest.localResolveRelativePath( ...
                artifact_a.session_folder, artifact_a.adsb_files{1}));
            truth_text_b = fileread(SyntheticHDTVSessionGeneratorTest.localResolveRelativePath( ...
                artifact_b.session_folder, artifact_b.adsb_files{1}));
            manifest_a = jsondecode(fileread(artifact_a.manifest_path));
            manifest_b = jsondecode(fileread(artifact_b.manifest_path));

            testCase.verifyEqual(truth_text_a, truth_text_b);
            testCase.verifyEqual( ...
                jsonencode(SyntheticHDTVSessionGeneratorTest.localCanonicalizeManifest(manifest_a)), ...
                jsonencode(SyntheticHDTVSessionGeneratorTest.localCanonicalizeManifest(manifest_b)));
        end

        function testBaselineScenarioIntentAndOverlapRemainExplicit(testCase)
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            cfg = buildSyntheticHDTVBaselineScenarioConfig('OutputRoot', fixture.Folder);
            truth_bundle = helperSyntheticGenerateTruth(cfg);

            testCase.verifyEqual(cfg.expected_overlap_window_s(1), 0, AbsTol=1e-12);
            testCase.verifyEqual(cfg.expected_overlap_window_s(2), cfg.part_duration_s, AbsTol=1e-12);
            testCase.verifyGreaterThanOrEqual(min(truth_bundle.sample_times_s), 0);
            testCase.verifyLessThanOrEqual(max(truth_bundle.sample_times_s), cfg.expected_overlap_window_s(2));
        end
    end

    methods (Static, Access = private)
        function artifact = localGenerateSession(output_root, session_id)
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', output_root, ...
                'SessionID', session_id);
            artifact = generateSyntheticHDTVSession('ScenarioConfig', cfg);
        end

        function artifact = localGenerateSeedBackedSession(output_root, session_id)
            seed_path = SyntheticHDTVSessionGeneratorTest.localCreateProbeSeed(output_root);
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', output_root, ...
                'SessionID', session_id, ...
                'SeedSourcePath', seed_path, ...
                'SignalMode', 'seed_backed_bistatic_v1');
            artifact = generateSyntheticHDTVSession('ScenarioConfig', cfg);
        end

        function artifact = localGenerateValidationSeedBackedSession(output_root, session_id)
            cfg = SyntheticHDTVSessionGeneratorTest.localBuildValidationSeedBackedConfig( ...
                output_root, session_id);
            artifact = generateSyntheticHDTVSession('ScenarioConfig', cfg);
        end

        function cfg = localBuildValidationSeedBackedConfig(output_root, session_id)
            seed_path = SyntheticHDTVSessionGeneratorTest.localCreateProbeSeed(output_root);
            cfg = buildSyntheticHDTVBaselineScenarioConfig( ...
                'OutputRoot', output_root, ...
                'SessionID', session_id, ...
                'SeedSourcePath', seed_path, ...
                'SignalMode', 'seed_backed_bistatic_v1', ...
                'CaptureDurationS', 0.20, ...
                'TruthSamplePeriodS', 0.01, ...
                'DirectPathDelaySamples', 1.0, ...
                'UseStochasticNoise', false);

            active_window_s = cfg.expected_overlap_window_s(2);
            cfg.targets = helperSyntheticBuildValidationConfidenceTargets( ...
                cfg.tx_lla_deg_m, ...
                cfg.rx_lla_deg_m, ...
                active_window_s);
        end

        function seed_path = localCreateProbeSeed(output_root)
            seed_folder = fullfile(output_root, 'seed_fixture');
            [seed_path, ~] = helperSyntheticCreateProbeSeed( ...
                'OutputFolder', seed_folder, ...
                'FileName', 'synthetic_probe_seed.bb');
        end

        function keys = localTrackKeys(track_struct)
            n_tracks = numel(track_struct);
            keys = strings(n_tracks, 1);
            for idx = 1 : n_tracks
                keys(idx) = string(track_struct(idx).hex) + "|" + string(track_struct(idx).callsign);
            end
            keys = sort(keys);
        end

        function abs_path = localResolveRelativePath(session_folder, rel_path)
            abs_path = fullfile(session_folder, strrep(rel_path, '/', filesep));
        end

        function manifest = localCanonicalizeManifest(manifest_in)
            manifest = manifest_in;
            if isfield(manifest, 'generation_time_utc')
                manifest = rmfield(manifest, 'generation_time_utc');
            end
        end

        function idx = localFindTrackIndexByCallsign(track_struct, callsign)
            idx = find(arrayfun(@(track) strcmp(track.callsign, callsign), track_struct), 1, 'first');
        end

        function tone_power_db = localMeasureTonePower(waveform, sample_rate_hz, tone_freq_hz)
            waveform = double(waveform(:));
            analysis_sample_count = min(numel(waveform), 65536);
            analysis_waveform = waveform(1:analysis_sample_count);
            nfft = max(4096, 2 ^ nextpow2(max(analysis_sample_count, 2)));
            [psd_linear, freq_hz] = periodogram( ...
                analysis_waveform, ...
                [], ...
                nfft, ...
                sample_rate_hz, ...
                'centered', ...
                'power');
            [~, tone_idx] = min(abs(freq_hz - tone_freq_hz));
            tone_power_db = 10 * log10(psd_linear(tone_idx) + eps);
        end
    end
end
