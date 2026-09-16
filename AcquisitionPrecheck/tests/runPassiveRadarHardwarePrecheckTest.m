classdef runPassiveRadarHardwarePrecheckTest < matlab.unittest.TestCase
    %RUNPASSIVERADARHARDWAREPRECHECKTEST Offline acquisition-precheck tests.

    methods (TestClassSetup)
        function addProjectPaths(testCase)
            testFolder = fileparts(mfilename("fullpath"));
            acquisitionFolder = fileparts(testFolder);
            projectFolder = fileparts(acquisitionFolder);
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                projectFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                acquisitionFolder));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(projectFolder, "BistaticDataAnalysis")));
        end
    end

    methods (TestMethodSetup)
        function createWorkingFolderAndSeed(testCase)
            testCase.applyFixture( ...
                matlab.unittest.fixtures.WorkingFolderFixture);
            previousState = rng;
            testCase.addTeardown(@() rng(previousState));
            rng(42, "twister");
        end
    end

    methods (Test)
        function modeIsRequired(testCase)
            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(struct()), ...
                "runPassiveRadarHardwarePrecheck:missingMode");
        end

        function invalidModeIsRejected(testCase)
            config = struct("Mode", "automatic");

            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(config), ...
                "runPassiveRadarHardwarePrecheck:invalidMode");
        end

        function liveModeRequiresExplicitAuthorization(testCase)
            config = struct("Mode", "live");

            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(config), ...
                "runPassiveRadarHardwarePrecheck:hardwareAccessNotAuthorized");
        end

        function liveAuthorizationMustBeLogical(testCase)
            config = struct( ...
                "Mode", "live", ...
                "Live", struct("EnableHardwareAccess", -1));

            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(config), ...
                "runPassiveRadarHardwarePrecheck:invalidConfiguration");
        end

        function offlineModeRequiresSource(testCase)
            config = struct("Mode", "offline");

            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(config), ...
                "runPassiveRadarHardwarePrecheck:missingSource");
        end

        function stabilityRequirementCannotBeReducedBelowThree(testCase)
            config = struct( ...
                "Mode", "offline", ...
                "Source", "unused.bb", ...
                "MinimumStableCaptures", 2);

            testCase.verifyError( ...
                @() runPassiveRadarHardwarePrecheck(config), ...
                "runPassiveRadarHardwarePrecheck:invalidConfiguration");
        end

        function validOfflineCapturePasses(testCase)
            files = ["valid_part1.bb", "valid_part2.bb", "valid_part3.bb"];
            config = testCase.baseConfig(files);
            testCase.writeRepeatedCaptures(files, config);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyTrue(result.Pass);
            testCase.verifyTrue(result.SafeForProduction);
            testCase.verifyEqual(result.Status, "pass");
            testCase.verifyFalse(result.HardwareAccessAuthorized);
        end

        function oneCaptureIsNotProductionSafe(testCase)
            config = testCase.baseConfig("single_capture.bb");
            testCase.writeCapture(config.Source, config, struct());

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.ControlStability.IsAssessable);
            testCase.verifyFalse(result.SafeForProduction);
            testCase.verifyEqual(result.Status, "hold");
        end

        function directPartFileUsesRecordedPartNumber(testCase)
            config = testCase.baseConfig("direct_part13.bb");
            testCase.writeCapture(config.Source, config, ...
                struct("Repetition", 13));

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyEqual(result.SourceInfo.PartIndex, 13);
            testCase.verifyTrue( ...
                result.Captures.Checks.Metadata.RepetitionMatchPass);
        end

        function missingMetadataProducesHold(testCase)
            config = testCase.baseConfig("missing_metadata.bb");
            options = struct("IncludeMetadata", false);
            testCase.writeCapture(config.Source, config, options);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.Metadata.Pass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function reversedMetadataRolesProduceHold(testCase)
            config = testCase.baseConfig("reversed_metadata.bb");
            options = struct("ReverseMetadataRoles", true);
            testCase.writeCapture(config.Source, config, options);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse( ...
                result.Captures.Checks.Metadata.ChannelRolesPass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function manifestMismatchProducesHold(testCase)
            sessionFolder = fullfile(pwd, "packaged_session");
            mkdir(sessionFolder);
            captureFile = fullfile(sessionFolder, "capture_part1.bb");
            config = testCase.baseConfig(string(sessionFolder));
            testCase.writeCapture(captureFile, config, struct());
            testCase.writeManifest( ...
                sessionFolder, config, "capture_part1.bb", [10, 16]);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse( ...
                result.Captures.Checks.Metadata.ManifestPass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function oneChannelPayloadProducesHold(testCase)
            config = testCase.baseConfig("one_channel.bb");
            options = struct("ChannelCount", 1);
            testCase.writeCapture(config.Source, config, options);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.Integrity.Pass);
            testCase.verifyEqual(result.Captures.Checks.Integrity.ChannelCount, 1);
            testCase.verifyEqual(result.Status, "hold");
        end

        function swappedSignalContentIsAdvisoryAndNotApplied(testCase)
            config = testCase.baseConfig("reversed.bb");
            config.Thresholds.RoleSwapPilotMarginDB = 1;
            options = struct("ReverseSignalRoles", true);
            testCase.writeCapture(config.Source, config, options);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyEqual( ...
                result.Captures.ConfiguredReferenceChannel, 2);
            testCase.verifyTrue( ...
                result.Captures.Advisory.ReviewChannelMapping);
            testCase.verifyEqual( ...
                result.Captures.Advisory.Recommendation, ...
                "review_channel_mapping");
        end

        function weakPilotProducesHold(testCase)
            config = testCase.baseConfig("weak_pilot.bb");
            config.Thresholds.PilotSNRMinDB = 1e6;
            testCase.writeCapture(config.Source, config, struct());

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.Pilot.Pass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function railContactProducesHeadroomHold(testCase)
            config = testCase.baseConfig("rail.bb");
            options = struct("AddRailContact", true);
            testCase.writeCapture(config.Source, config, options);

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.Headroom.Pass);
            testCase.verifyGreaterThan( ...
                result.Captures.Checks.Headroom.ExactRailFraction(1), 0);
        end

        function integerScaleSamplesUseAutomaticFullScale(testCase)
            samples = int16([10000; -10000; 8000]);

            result = helperMeasureChannelHeadroom(samples);

            testCase.verifyEqual(result.FullScale, 32768, AbsTol=0);
            testCase.verifyTrue(result.Pass);
        end

        function correlationFailureProducesHold(testCase)
            config = testCase.baseConfig("correlation.bb");
            config.Thresholds.CorrelationPeakMinDB = 1e6;
            testCase.writeCapture(config.Source, config, struct());

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.Correlation.Pass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function ecaFailureProducesHold(testCase)
            config = testCase.baseConfig("eca.bb");
            config.Thresholds.ECABeforeMarginMinDB = 1e6;
            testCase.writeCapture(config.Source, config, struct());

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.Captures.Checks.ECA.Pass);
            testCase.verifyEqual(result.Status, "hold");
        end

        function unstableControlProducesNamedAssessment(testCase)
            files = ["part1.bb", "part2.bb", "part3.bb"];
            config = testCase.baseConfig(files);
            config.Thresholds.ControlLevelSpanMaxDB = 6;
            testCase.writeCapture(files(1), config, ...
                struct("AmplitudeScale", 1, "Repetition", 1));
            testCase.writeCapture(files(2), config, ...
                struct("AmplitudeScale", 0.3, "Repetition", 2));
            testCase.writeCapture(files(3), config, ...
                struct("AmplitudeScale", 0.1, "Repetition", 3));

            result = runPassiveRadarHardwarePrecheck(config);

            testCase.verifyFalse(result.ControlStability.Pass);
            testCase.verifyEqual(result.ControlStability.Assessment, ...
                "configuration not controlled");
            testCase.verifyEqual(result.Status, "hold");
        end

        function missingRoleLevelMakesStabilityUnassessable(testCase)
            config = helperNormalizePassiveRadarPrecheckConfig( ...
                struct("Mode", "offline"));
            validCapture = localStabilityCapture([-20, -15]);
            invalidCapture = localStabilityCapture([NaN, -15]);
            captures = [validCapture; validCapture; invalidCapture];

            result = helperAssessPassiveRadarControlStability( ...
                captures, config);

            testCase.verifyFalse(result.IsAssessable);
            testCase.verifyFalse(result.Pass);
        end
    end

    methods (Static, Access=private)
        function writeRepeatedCaptures(files, config)
            for fileIndex = 1:numel(files)
                runPassiveRadarHardwarePrecheckTest.writeCapture( ...
                    files(fileIndex), config, ...
                    struct("Repetition", fileIndex));
            end
        end

        function config = baseConfig(source)
            thresholds = struct( ...
                "ReferenceLevelMinDBFS", -100, ...
                "ReferenceLevelMaxDBFS", 0, ...
                "PilotSNRMinDB", -100, ...
                "SpectralFlatnessMinDB", -100, ...
                "CorrelationPeakMinDB", -100, ...
                "CorrelationIsolationMinDB", -100, ...
                "CorrelationMaximumLagSamples", 32, ...
                "ECABeforeMarginMinDB", -100, ...
                "ECASuppressionMinDB", -100, ...
                "ECAAfterMarginMaxDB", 1e6, ...
                "MinimumPeakHeadroomDB", 0, ...
                "MinimumPercentileHeadroomDB", 0, ...
                "NearRailFraction", 0.999, ...
                "MaximumNearRailFraction", 0, ...
                "ControlLevelSpanMaxDB", 100);
            config = struct( ...
                "Mode", "offline", ...
                "Source", source, ...
                "CenterFrequencyHz", 599e6, ...
                "SampleRateHz", 512e3, ...
                "LOOffsetHz", 0, ...
                "AntennaPorts", ["RF0:RX2", "RF1:RX2"], ...
                "ChannelRoles", ["surveillance", "reference"], ...
                "GainDB", [16, 16], ...
                "AnalysisDurationS", 0.02, ...
                "CPIDurationS", 0.5e-3, ...
                "MinimumCPIs", 12, ...
                "IlluminatorCenterFrequencyHz", 599e6, ...
                "Thresholds", thresholds);
        end

        function writeManifest( ...
                sessionFolder, config, relativeCaptureFile, gainDB)
            channelMapping = [ ...
                struct( ...
                    "channel_index", 1, ...
                    "antenna_port", config.AntennaPorts(1), ...
                    "role", config.ChannelRoles(1)), ...
                struct( ...
                    "channel_index", 2, ...
                    "antenna_port", config.AntennaPorts(2), ...
                    "role", config.ChannelRoles(2))];
            rfSettings = struct( ...
                "center_frequency_hz", config.CenterFrequencyHz, ...
                "sample_rate_hz", config.SampleRateHz, ...
                "lo_offset_hz", config.LOOffsetHz);
            manifest = struct( ...
                "manifest_version", 1, ...
                "session_id", "synthetic-precheck", ...
                "gain_db", gainDB, ...
                "channel_mapping", channelMapping, ...
                "sdr_defaults", rfSettings, ...
                "header_readback", rfSettings, ...
                "radar_files", string(relativeCaptureFile));
            writelines(jsonencode(manifest, PrettyPrint=true), ...
                fullfile(sessionFolder, "session_manifest.json"));
        end

        function writeCapture(filePath, config, options)
            options = runPassiveRadarHardwarePrecheckTest.applyDefaults(options);
            nFast = round(config.SampleRateHz * config.CPIDurationS);
            nSlow = 16;
            sampleIndex = (0:nFast - 1).';
            pilotBasebandHz = mod(-2.690559e6 + ...
                config.SampleRateHz / 2, config.SampleRateHz) - ...
                config.SampleRateHz / 2;
            pilotBin = round(pilotBasebandHz * nFast / config.SampleRateHz);
            pilot = exp(1j * 2 * pi * pilotBin * sampleIndex / nFast);
            pilotCube = repmat(pilot, 1, nSlow);
            reference = 0.04 * complex(randn(nFast, nSlow), ...
                randn(nFast, nSlow)) + 0.06 * pilotCube;
            surveillance = 0.2 * circshift(reference, [4, 0]) + ...
                0.08 * complex(randn(nFast, nSlow), randn(nFast, nSlow));
            samples = [surveillance(:), reference(:)];
            if options.ReverseSignalRoles
                samples = samples(:, [2, 1]);
            end
            samples = options.AmplitudeScale * samples;
            if options.ChannelCount == 1
                samples = samples(:, 1);
            end
            if options.AddRailContact
                samples(10, 1) = complex(1, 0);
            end

            metadata = struct();
            if options.IncludeMetadata
                metadataRoles = config.ChannelRoles;
                if options.ReverseMetadataRoles
                    metadataRoles = metadataRoles([2, 1]);
                end
                metadata = struct( ...
                    "LOOffset", config.LOOffsetHz, ...
                    "RecordingUTC", 1.8e9, ...
                    "SessionID", "synthetic-precheck", ...
                    "Repetition", options.Repetition, ...
                    "Antenna1", config.AntennaPorts(1), ...
                    "Antenna2", config.AntennaPorts(2), ...
                    "Channel1Role", metadataRoles(1), ...
                    "Channel2Role", metadataRoles(2), ...
                    "GainDB", config.GainDB);
            end

            writer = comm.BasebandFileWriter(char(filePath), ...
                "SampleRate", config.SampleRateHz, ...
                "CenterFrequency", config.CenterFrequencyHz, ...
                "Metadata", metadata);
            cleanup = onCleanup(@() release(writer));
            writer(single(samples));
        end

        function options = applyDefaults(options)
            defaults = struct( ...
                "IncludeMetadata", true, ...
                "ChannelCount", 2, ...
                "ReverseSignalRoles", false, ...
                "ReverseMetadataRoles", false, ...
                "AddRailContact", false, ...
                "AmplitudeScale", 1, ...
                "Repetition", 1);
            names = fieldnames(defaults);
            for index = 1:numel(names)
                name = names{index};
                if ~isfield(options, name)
                    options.(name) = defaults.(name);
                end
            end
        end
    end
end

function capture = localStabilityCapture(roleLevelsDBFS)
capture = helperEmptyPassiveRadarCaptureResult();
capture.ConfiguredSurveillanceChannel = 1;
capture.ConfiguredReferenceChannel = 2;
capture.Checks = struct( ...
    "Headroom", struct("RMSDBFS", roleLevelsDBFS));
end
