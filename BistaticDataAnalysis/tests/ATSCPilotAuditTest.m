classdef ATSCPilotAuditTest < matlab.unittest.TestCase
    %ATSCPilotAuditTest Regression coverage for the PSD-first ATSC pilot audit.

    properties (Constant, Access = private)
        SessionID = "20260622T102123"
    end

    properties (Access = private)
        AnalysisRoot string
        CaptureRoot string
        CaptureAvailable logical = false
        Part1Result struct = struct()
    end

    methods (TestClassSetup)
        function addSourcePathAndLoadFixture(testCase)
            analysisRoot = string(fileparts(fileparts(mfilename('fullpath'))));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(char(analysisRoot)));

            testCase.AnalysisRoot = analysisRoot;
            testCase.CaptureRoot = string(helperResolvePackagedCaptureRoot());
            sessionFolder = fullfile(char(testCase.CaptureRoot), char(testCase.SessionID));
            testCase.CaptureAvailable = isfolder(sessionFolder);

            if testCase.CaptureAvailable
                testCase.Part1Result = testCase.localRunHeadlessPrecheck(testCase.SessionID, 1);
            end
        end
    end

    methods (TestMethodSetup)
        function resetRandomSeed(testCase)
            originalRng = rng;
            testCase.addTeardown(@() rng(originalRng));
            rng(42, "twister");
        end
    end

    methods (Test, TestTags = {'Unit'})
        function testOnFrequencyPilotPassesWithFiniteOutputs(testCase)
            scenario = testCase.localMakeOnFrequencyScenario();
            evidence = testCase.localRunSyntheticEvidence(scenario);
            selectedRow = testCase.localSelectedRow(evidence.diagnostic_table);

            testCase.verifyTrue(evidence.pilot_presence_pass);
            testCase.verifyEqual(evidence.selected_pilot_freq_hz, scenario.expected_normal_hz, AbsTol = scenario.frequency_tolerance_hz);
            testCase.verifyGreaterThanOrEqual(evidence.selected_peak_prominence_db, evidence.thresholds.prominence_pass_db);
            testCase.verifyLessThanOrEqual(abs(evidence.pilot_freq_error_hz), evidence.thresholds.freq_error_pass_hz);
            testCase.verifyEqual(selectedRow.measured_freq_hz, evidence.selected_pilot_freq_hz, AbsTol = scenario.frequency_tolerance_hz);
            testCase.verifyEqual(selectedRow.psd_prominence_db, evidence.selected_peak_prominence_db, AbsTol = 0.25);
            testCase.verifyEqual(selectedRow.signed_freq_error_hz, evidence.pilot_freq_error_hz, AbsTol = scenario.frequency_tolerance_hz);
        end

        function testOffBinPilotWithFixedCFOPassesAndTracksFrequencyError(testCase)
            scenario = testCase.localMakeOffBinCFOPilotScenario();
            evidence = testCase.localRunSyntheticEvidence(scenario);

            testCase.verifyTrue(evidence.pilot_presence_pass);
            testCase.verifyEqual(evidence.selected_pilot_freq_hz, scenario.pilot_frequency_hz, AbsTol = scenario.frequency_tolerance_hz);
            testCase.verifyEqual(evidence.pilot_freq_error_hz, scenario.pilot_frequency_hz - scenario.expected_normal_hz, AbsTol = scenario.frequency_tolerance_hz);
        end

        function testPhaseDriftStillPassesWhenLegacyCoherenceIsOnlyDiagnostic(testCase)
            driftScenario = testCase.localMakePhaseDriftScenario();
            driftEvidence = testCase.localRunSyntheticEvidence(driftScenario);

            testCase.verifyTrue(driftEvidence.pilot_presence_pass);
            testCase.verifyLessThan(driftEvidence.legacy_coherence_snr_db, driftEvidence.selected_peak_prominence_db - 20);
            testCase.verifyGreaterThanOrEqual(driftEvidence.selected_peak_prominence_db, driftEvidence.thresholds.prominence_pass_db);
        end

        function testAbsentPilotFailsDespiteStrongerOffChannelSpur(testCase)
            scenario = testCase.localMakeAbsentPilotScenario();
            evidence = testCase.localRunSyntheticEvidence(scenario);

            testCase.verifyFalse(evidence.pilot_presence_pass);
            testCase.verifyTrue(evidence.pilot_presence_fail);
            testCase.verifyGreaterThan(abs(evidence.selected_pilot_freq_hz - scenario.offchannel_spur_frequency_hz), 75e3);
        end

        function testMirroredSpurCannotOverrideValidNormalPilot(testCase)
            scenario = testCase.localMakeMirroredSpurScenario();
            evidence = testCase.localRunSyntheticEvidence(scenario);

            testCase.verifyTrue(evidence.pilot_presence_pass);
            testCase.verifyFalse(evidence.selected_candidate.is_mirrored);
            testCase.verifyEqual(evidence.selected_pilot_freq_hz, scenario.expected_normal_hz, AbsTol = scenario.frequency_tolerance_hz);
            testCase.verifyGreaterThan(evidence.best_mirrored_candidate.peak_prominence_db, evidence.selected_peak_prominence_db);
        end

        function testJitteredPilotIncreasesResidualFrequencySpreadButStillPasses(testCase)
            cleanScenario = testCase.localMakeOnFrequencyScenario();
            jitterScenario = testCase.localMakeJitteredPilotScenario();
            cleanEvidence = testCase.localRunSyntheticEvidence(cleanScenario);
            jitterEvidence = testCase.localRunSyntheticEvidence(jitterScenario);

            testCase.verifyTrue(jitterEvidence.pilot_presence_pass);
            testCase.verifyTrue(cleanEvidence.stability_available);
            testCase.verifyTrue(jitterEvidence.stability_available);
            testCase.verifyGreaterThan(jitterEvidence.residual_offset_std_hz, cleanEvidence.residual_offset_std_hz + 5);
        end
    end

    methods (Test, TestTags = {'Integration'})
        function testRunDirectPathPrecheckResolvesPackagedSessionWithoutDatasetRoot(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;
            expectedFolder = fullfile(char(testCase.CaptureRoot), char(testCase.SessionID));

            testCase.verifyEqual(string(result.source_info.session_id), testCase.SessionID);
            testCase.verifyTrue(contains(string(result.source_info.session_folder), expectedFolder));
        end

        function testCaptureBackedPilotEvidenceIncludesNewFields(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;

            testCase.verifyTrue(isfield(result.reference_profile, 'selected_pilot_freq_hz'));
            testCase.verifyTrue(isfield(result.reference_profile, 'selected_peak_prominence_db'));
            testCase.verifyTrue(isfield(result.reference_profile, 'pilot_freq_error_hz'));
            testCase.verifyTrue(isfield(result.reference_profile, 'diagnostic_table'));
            testCase.verifyFalse(isempty(result.pilot_diagnostic_table));
            testCase.verifyTrue(isfinite(result.reference_profile.selected_peak_prominence_db));
            testCase.verifyTrue(isfinite(result.reference_profile.pilot_freq_error_hz));
        end

        function testCaptureBackedSelectedPilotUsesNormalSidePSDPeak(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;

            testCase.verifyFalse(result.reference_profile.selected_candidate.is_mirrored);
            testCase.verifyLessThanOrEqual(abs(result.reference_profile.pilot_freq_error_hz), result.reference_profile.thresholds.freq_error_warn_hz);
            testCase.verifyEqual(sign(result.reference_profile.selected_pilot_freq_hz), sign(result.reference_profile.expected_normal_freq_hz));
        end

        function testCaptureBackedSelectedPeakMatchesDisplayedPSD(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;
            selectedRow = testCase.localSelectedRow(result.pilot_diagnostic_table);
            interpolatedPowerDB = interp1( ...
                result.reference_profile.psd_freq_axis_hz, ...
                result.reference_profile.psd_db_hz, ...
                result.reference_profile.selected_pilot_freq_hz, ...
                'linear');

            testCase.verifyEqual(selectedRow.peak_power_db, result.reference_profile.selected_peak_power_db, AbsTol = 0.25);
            testCase.verifyEqual(selectedRow.peak_power_db, interpolatedPowerDB, AbsTol = 0.5);
        end

        function testCaptureBackedPilotPassIsDrivenByPilotPresence(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;

            testCase.verifyEqual(result.reference_quality.pilot_pass, result.reference_profile.pilot_presence_pass);
            testCase.verifyTrue(isfinite(result.reference_quality.legacy_fft_bin_coherence_db));
        end

        function testCaptureBackedSummaryStringsStayInternallyConsistent(testCase)
            testCase.assumeTrue(testCase.CaptureAvailable, 'Packaged session fixture is not available.');

            result = testCase.Part1Result;
            summary = result.precheck_summary;
            selectedFreqMHz = sprintf('%.3f MHz', result.reference_profile.selected_pilot_freq_hz / 1e6);

            testCase.verifyTrue(contains(summary.selection_summary, summary.selection_path_text));
            testCase.verifyTrue(contains(summary.figure_summary_line_1, selectedFreqMHz));
            testCase.verifyTrue(contains(summary.figure_summary_line_2, "Legacy FFT-bin coherence"));
            testCase.verifyEqual(result.reference_profile.pilot_presence_state, string(summary.pilot_presence_state));
        end
    end

    methods (Access = private)
        function result = localRunHeadlessPrecheck(~, sessionID, partIndex)
            cmd = sprintf(['tmp = runDirectPathPrecheck(''%s'', ' ...
                '''PartIndex'', %d, ''PlotFigures'', false, ''FigureVisibility'', ''off'', ''Verbose'', false);'], ...
                sessionID, partIndex);
            evalc(cmd);
            result = tmp;
        end

        function evidence = localRunSyntheticEvidence(testCase, scenario)
            [reference_channel, reference_cube] = testCase.localSynthesizeReferenceData(scenario);

            evidence = helperMeasureATSCPilotEvidence( ...
                reference_cube, reference_channel, scenario.sample_rate_hz, ...
                'CaptureCenterFrequencyHz', scenario.capture_center_frequency_hz, ...
                'CaptureTuneFrequencyHz', scenario.capture_tune_frequency_hz, ...
                'LOOffsetHz', scenario.lo_offset_hz, ...
                'IlluminatorCenterFrequencyHz', scenario.illuminator_center_frequency_hz, ...
                'LockedSearchHalfWidthHz', scenario.locked_search_half_width_hz, ...
                'FallbackSearchHalfWidthHz', scenario.fallback_search_half_width_hz);
        end

        function row = localSelectedRow(testCase, diagnosticTable)
            selectedMask = diagnosticTable.is_selected;
            testCase.verifyEqual(nnz(selectedMask), 1);
            row = diagnosticTable(selectedMask, :);
        end

        function scenario = localMakeOnFrequencyScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.normal_pilot_frequency_hz = scenario.expected_normal_hz;
            scenario.normal_pilot_amplitude = 5.0;
        end

        function scenario = localMakeOffBinCFOPilotScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.pilot_frequency_hz = scenario.expected_normal_hz + 18.25e3;
            scenario.normal_pilot_frequency_hz = scenario.pilot_frequency_hz;
            scenario.normal_pilot_amplitude = 5.0;
        end

        function scenario = localMakePhaseDriftScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.normal_pilot_frequency_hz = scenario.expected_normal_hz;
            scenario.normal_pilot_amplitude = 5.0;
            scenario.normal_phase_mode = "per_cpi_random";
        end

        function scenario = localMakeAbsentPilotScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.normal_pilot_amplitude = 0.0;
            scenario.offchannel_spur_frequency_hz = scenario.expected_normal_hz + 180e3;
            scenario.offchannel_spur_amplitude = 7.0;
            scenario.noise_sigma = 0.0;
        end

        function scenario = localMakeMirroredSpurScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.normal_pilot_frequency_hz = scenario.expected_normal_hz;
            scenario.normal_pilot_amplitude = 4.5;
            scenario.mirrored_spur_frequency_hz = -scenario.expected_normal_hz;
            scenario.mirrored_spur_amplitude = 7.0;
        end

        function scenario = localMakeJitteredPilotScenario(testCase)
            scenario = testCase.localMakeBaseScenario();
            scenario.normal_pilot_frequency_hz = scenario.expected_normal_hz;
            scenario.normal_pilot_amplitude = 5.0;
            scenario.normal_phase_mode = "piecewise_frequency_jitter";
            scenario.normal_jitter_std_hz = 200;
            scenario.normal_jitter_block_duration_s = 5e-3;
        end

        function scenario = localMakeBaseScenario(~)
            scenario = struct( ...
                'sample_rate_hz', 6.144e6, ...
                'duration_s', 0.04, ...
                'cpi_duration_s', 0.5e-3, ...
                'capture_center_frequency_hz', 599e6, ...
                'capture_tune_frequency_hz', 599e6, ...
                'lo_offset_hz', 0, ...
                'illuminator_center_frequency_hz', 599e6, ...
                'locked_search_half_width_hz', 75e3, ...
                'fallback_search_half_width_hz', 300e3, ...
                'expected_normal_hz', -2.690559e6, ...
                'normal_pilot_frequency_hz', NaN, ...
                'normal_pilot_amplitude', 0.0, ...
                'normal_phase_mode', "constant", ...
                'normal_jitter_std_hz', 0, ...
                'normal_jitter_block_duration_s', 10e-3, ...
                'mirrored_spur_frequency_hz', NaN, ...
                'mirrored_spur_amplitude', 0.0, ...
                'offchannel_spur_frequency_hz', NaN, ...
                'offchannel_spur_amplitude', 0.0, ...
                'noise_sigma', 1.0, ...
                'frequency_tolerance_hz', 2e3);
        end

        function [reference_channel, reference_cube] = localSynthesizeReferenceData(testCase, scenario)
            n_samples = round(scenario.duration_s * scenario.sample_rate_hz);

            reference_channel = scenario.noise_sigma / sqrt(2) * ( ...
                randn(n_samples, 1) + 1j * randn(n_samples, 1));

            reference_channel = reference_channel + testCase.localSynthesizeTone( ...
                n_samples, scenario.sample_rate_hz, scenario.normal_pilot_frequency_hz, ...
                scenario.normal_pilot_amplitude, scenario.normal_phase_mode, ...
                round(scenario.cpi_duration_s * scenario.sample_rate_hz), ...
                scenario.normal_jitter_std_hz, scenario.normal_jitter_block_duration_s);
            reference_channel = reference_channel + testCase.localSynthesizeTone( ...
                n_samples, scenario.sample_rate_hz, scenario.mirrored_spur_frequency_hz, ...
                scenario.mirrored_spur_amplitude, "constant", ...
                round(scenario.cpi_duration_s * scenario.sample_rate_hz), ...
                0, scenario.normal_jitter_block_duration_s);
            reference_channel = reference_channel + testCase.localSynthesizeTone( ...
                n_samples, scenario.sample_rate_hz, scenario.offchannel_spur_frequency_hz, ...
                scenario.offchannel_spur_amplitude, "constant", ...
                round(scenario.cpi_duration_s * scenario.sample_rate_hz), ...
                0, scenario.normal_jitter_block_duration_s);

            samples_per_cpi = round(scenario.cpi_duration_s * scenario.sample_rate_hz);
            num_cpis = floor(n_samples / samples_per_cpi);
            truncated_length = samples_per_cpi * num_cpis;
            reference_channel = reference_channel(1:truncated_length);
            reference_cube = reshape(reference_channel, samples_per_cpi, num_cpis);
        end

        function tone = localSynthesizeTone(~, n_samples, sample_rate_hz, frequency_hz, amplitude, phase_mode, samples_per_cpi, jitter_std_hz, jitter_block_duration_s)
            if ~isfinite(frequency_hz) || amplitude == 0
                tone = complex(zeros(n_samples, 1));
                return
            end

            sample_indices = (0 : n_samples - 1).';
            phase_mode = string(phase_mode);

            switch phase_mode
                case "per_cpi_random"
                    n_blocks = ceil(n_samples / samples_per_cpi);
                    random_phases = 2 * pi * rand(n_blocks, 1);
                    phase_offsets = repelem(random_phases, samples_per_cpi);
                    phase_offsets = phase_offsets(1:n_samples);
                    phase = 2 * pi * frequency_hz * sample_indices / sample_rate_hz + phase_offsets;

                case "piecewise_frequency_jitter"
                    block_length = max(2, round(jitter_block_duration_s * sample_rate_hz));
                    n_blocks = ceil(n_samples / block_length);
                    frequency_offsets_hz = jitter_std_hz * randn(n_blocks, 1);
                    instantaneous_frequency_hz = frequency_hz + repelem(frequency_offsets_hz, block_length);
                    instantaneous_frequency_hz = instantaneous_frequency_hz(1:n_samples);
                    phase = 2 * pi * cumsum(instantaneous_frequency_hz) / sample_rate_hz;

                otherwise
                    phase = 2 * pi * frequency_hz * sample_indices / sample_rate_hz;
            end

            tone = amplitude * exp(1j * phase);
        end
    end
end
