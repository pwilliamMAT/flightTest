%% Seed-Backed Synthetic HDTV Session Walkthrough
% Plain language:
% Edit the timing knobs and the `targets` struct array in this walkthrough
% when you want packaged synthetic sessions with specific target geometry,
% cadence, and per-target echo strengths. The walkthrough keeps the
% baseline builder as the default source of site geometry and signal
% defaults, then applies your edits as the authoritative scenario used for
% truth preview, packaging, and optional wrapper replay.

%% Collect Inputs
pathInfo = helperSyntheticEnsureProjectPaths();
repoRoot = pathInfo.repo_root;

if ~exist("outputRoot", "var") || strlength(string(outputRoot)) == 0
    outputRoot = fullfile(repoRoot, "captures");
end

if ~exist("sessionID", "var") || strlength(string(sessionID)) == 0
    sessionID = "seed_demo_" + string(datetime("now", "Format", "yyyyMMdd'T'HHmmss"));
end

if ~exist("dtedPath", "var") || strlength(string(dtedPath)) == 0
    dtedPath = fullfile(repoRoot, "n42_w072_1arc_v3.dt2");
end

if ~exist("seedSourcePath", "var")
    seedSourcePath = "";
end

if ~exist("seedChannelIndex", "var")
    seedChannelIndex = 2;
end

if ~exist("signalMode", "var") || strlength(string(signalMode)) == 0
    signalMode = "seed_backed_bistatic_v1";
end

if ~exist("captureDurationS", "var")
    captureDurationS = 0.10;
end

if ~exist("captureRepetitions", "var")
    captureRepetitions = 1;
end

if ~exist("captureRepetitionSpacingS", "var")
    captureRepetitionSpacingS = 0.0;
end

if ~exist("truthSamplePeriodS", "var")
    truthSamplePeriodS = 0.02;
end

if ~exist("referenceGainDB", "var")
    referenceGainDB = 0;
end

if ~exist("directPathGainDB", "var")
    directPathGainDB = -3;
end

if ~exist("directPathDelaySamples", "var")
    directPathDelaySamples = 0.75;
end

if ~exist("useStochasticNoise", "var")
    useStochasticNoise = false;
end

if ~exist("runWrapperReplay", "var")
    runWrapperReplay = false;
end

%% Resolve The Illuminator Seed
% A real field capture is preferred because it preserves the occupied
% bandwidth and pilot structure that the passive-radar chain sees in
% practice. The fallback probe seed is only for smoke tests, packaging
% checks, and quick regression runs.
if strlength(string(seedSourcePath)) == 0
    probeSeedFolder = fullfile(repoRoot, "tmp_probe");
    probeSeedName = "synthetic_probe_seed_" + sessionID + ".bb";
    [seedSourcePath, seedInfo] = helperSyntheticCreateProbeSeed( ...
        'OutputFolder', probeSeedFolder, ...
        'FileName', probeSeedName);
else
    seedInfo = struct( ...
        'seed_file_path', char(string(seedSourcePath)), ...
        'source', 'field_capture');
end

fprintf("Seed file:\t%s\n", string(seedSourcePath));

%% Build Baseline Defaults
% The baseline builder remains the default source of site geometry,
% manifest-friendly packaging settings, and the two-target starting
% template used below.
baselineScenarioConfig = buildSyntheticHDTVBaselineScenarioConfig( ...
    'OutputRoot', outputRoot, ...
    'SessionID', sessionID, ...
    'DTEDPath', dtedPath, ...
    'SeedSourcePath', seedSourcePath, ...
    'SeedChannelIndex', seedChannelIndex, ...
    'SignalMode', signalMode, ...
    'ReferenceGainDB', referenceGainDB, ...
    'DirectPathGainDB', directPathGainDB, ...
    'DirectPathDelaySamples', directPathDelaySamples, ...
    'UseStochasticNoise', useStochasticNoise, ...
    'CaptureDurationS', captureDurationS, ...
    'CaptureRepetitions', captureRepetitions, ...
    'CaptureRepetitionSpacingS', captureRepetitionSpacingS, ...
    'TruthSamplePeriodS', truthSamplePeriodS);

activeWindowS = captureDurationS * captureRepetitions + ...
    max(captureRepetitions - 1, 0) * captureRepetitionSpacingS;

%% Edit Target Definitions
% Edit these target structs directly when you want to change waypoint
% geometry, target timing, or per-target echo strength. If `targets`
% already exists in your workspace, this section keeps your edited value
% instead of rebuilding the template.
if ~exist("targets", "var") || isempty(targets)
    baselineTargets = baselineScenarioConfig.targets;

    targets(1) = struct( ...
        'target_id', baselineTargets(1).target_id, ...
        'icao_hex', baselineTargets(1).icao_hex, ...
        'callsign', baselineTargets(1).callsign, ...
        'echo_gain_db', baselineTargets(1).echo_gain_db, ...
        'waypoints_lla_deg_m', baselineTargets(1).waypoints_lla_deg_m, ...
        'time_of_arrival_s', baselineTargets(1).time_of_arrival_s);

    targets(2) = struct( ...
        'target_id', baselineTargets(2).target_id, ...
        'icao_hex', baselineTargets(2).icao_hex, ...
        'callsign', baselineTargets(2).callsign, ...
        'echo_gain_db', baselineTargets(2).echo_gain_db, ...
        'waypoints_lla_deg_m', baselineTargets(2).waypoints_lla_deg_m, ...
        'time_of_arrival_s', baselineTargets(2).time_of_arrival_s);
end

%% Configure The Scenario For Generation
% The walkthrough-edited timing values and `targets` array are authoritative
% here, even though the baseline builder remains the source of defaults.
scenarioConfig = baselineScenarioConfig;
scenarioConfig.output_root = char(string(outputRoot));
scenarioConfig.session_id = char(string(sessionID));
scenarioConfig.terrain_dted_path = char(string(dtedPath));
scenarioConfig.seed_source_path = char(string(seedSourcePath));
scenarioConfig.seed_channel_index = double(seedChannelIndex);
scenarioConfig.signal_mode = char(string(signalMode));
scenarioConfig.part_duration_s = double(captureDurationS);
scenarioConfig.capture_repetitions = double(captureRepetitions);
scenarioConfig.capture_repetition_spacing_s = double(captureRepetitionSpacingS);
scenarioConfig.truth_sample_period_s = double(truthSamplePeriodS);
scenarioConfig.reference_gain_db = double(referenceGainDB);
scenarioConfig.direct_path_gain_db = double(directPathGainDB);
scenarioConfig.direct_path_delay_samples = double(directPathDelaySamples);
scenarioConfig.use_stochastic_noise = logical(useStochasticNoise);
scenarioConfig.expected_overlap_window_s = [0, activeWindowS];
scenarioConfig.targets = targets;

[scenarioSummary, targetSummaryTable] = helperSyntheticSummarizeScenarioConfig(scenarioConfig);

fprintf("\nScenario summary\n");
fprintf("\tSession ID:\t%s\n", string(scenarioSummary.session_id));
fprintf("\tSignal mode:\t%s\n", string(scenarioSummary.signal_mode));
fprintf("\tPart duration:\t%.3f [s]\n", scenarioSummary.part_duration_s);
fprintf("\tRepetitions:\t%d\n", scenarioSummary.capture_repetitions);
fprintf("\tSpacing:\t%.3f [s]\n", scenarioSummary.capture_repetition_spacing_s);
fprintf("\tActive window:\t%.3f [s]\n", scenarioSummary.radar_active_window_s);
fprintf("\tTruth sample period:\t%.3f [s]\n", scenarioSummary.truth_sample_period_s);
fprintf("\tTarget count:\t%d\n", scenarioSummary.n_targets);
fprintf("\tTargets:\t%s\n", join(scenarioSummary.target_labels, ", "));
disp(targetSummaryTable)

%% Preview The Static Site And Truth Geometry
% This preview uses the walkthrough-edited target definitions. It is a fast
% way to confirm that the site geometry, waypoint timing, and bistatic
% truth all match the scenario you intend to package.
truthPreview = helperSyntheticGenerateTruth(scenarioConfig);
previewPlotHandles = helperSyntheticPlotScenarioOverview(scenarioConfig, truthPreview);

%% Generate The Synthetic Session
% This step writes the packaged-session artifact set under
% `captures/<session_id>`, including `radar/*.bb`,
% `truth/adsb_<session_id>.txt`, `truth/scenario_truth.mat`, and
% `session_manifest.json`.
artifact = generateSyntheticHDTVSession('ScenarioConfig', scenarioConfig);

artifactSummary = struct( ...
    'session_folder', artifact.session_folder, ...
    'manifest_path', artifact.manifest_path, ...
    'radar_files', {artifact.radar_files}, ...
    'adsb_files', {artifact.adsb_files});

fprintf("\nGenerated artifacts\n");
fprintf("\tSession folder:\t%s\n", string(artifactSummary.session_folder));
fprintf("\tManifest:\t%s\n", string(artifactSummary.manifest_path));
for idx = 1 : numel(artifactSummary.radar_files)
    fprintf("\tRadar file %d:\t%s\n", idx, string(artifactSummary.radar_files{idx}));
end
for idx = 1 : numel(artifactSummary.adsb_files)
    fprintf("\tADSB file %d:\t%s\n", idx, string(artifactSummary.adsb_files{idx}));
end

%% Inspect The First Synthetic Radar File
% CH1 is surveillance and CH2 is reference. This spectrum check confirms
% that the generated file is nonzero and that the two channels are not
% identical.
firstRadarFile = fullfile(artifact.session_folder, strrep(artifact.radar_files{1}, "/", filesep));
reader = comm.BasebandFileReader(firstRadarFile, 'SamplesPerFrame', 65536);
radarSamples = reader();
release(reader)

nfft = 4096;
[surveillancePsd, freqHz] = periodogram( ...
    radarSamples(:, 1), [], nfft, scenarioConfig.sample_rate_hz, "centered", "power");
[referencePsd, ~] = periodogram( ...
    radarSamples(:, 2), [], nfft, scenarioConfig.sample_rate_hz, "centered", "power");

figure('Name', 'Synthetic Radar Spectrum Check', 'Color', 'w');
layout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile(layout)
plot(freqHz ./ 1e6, pow2db(surveillancePsd + eps), 'LineWidth', 1.2)
grid on
xlabel("Baseband Frequency [MHz]")
ylabel("PSD [dB]")
title("Synthetic Surveillance Channel Spectrum")

nexttile(layout)
plot(freqHz ./ 1e6, pow2db(referencePsd + eps), 'LineWidth', 1.2)
grid on
xlabel("Baseband Frequency [MHz]")
ylabel("PSD [dB]")
title("Synthetic Reference Channel Spectrum")

%% Replay Through The Existing Session Wrapper
% Leave `runWrapperReplay` at `false` while you iterate on generation
% settings, then flip it to `true` when you want to run the existing
% packaged-session wrapper and inspect downstream truth alignment.
if runWrapperReplay
    originalVisibility = get(groot, "DefaultFigureVisible");
    set(groot, "DefaultFigureVisible", "off")
    cleanupVisibility = onCleanup(@() set(groot, "DefaultFigureVisible", originalVisibility));

    analysisOutput = runBistaticAnalysisSession( ...
        scenarioConfig.session_id, ...
        'DatasetRoot', scenarioConfig.output_root, ...
        'Verbose', false, ...
        'SaveTruthDiagnosticSnapshot', false, ...
        'SaveDetectorReplaySnapshot', false);

    nAlignedTruthTracks = sum(arrayfun( ...
        @(track) any(isfinite(track.R_excess_m)), analysisOutput.adsb_aligned));

    fprintf("\nWrapper replay summary\n");
    fprintf("\tSession ID:\t%s\n", string(analysisOutput.session_id));
    fprintf("\tRadar files:\t%d\n", numel(analysisOutput.radar_files));
    fprintf("\tTruth files:\t%d\n", numel(analysisOutput.adsb_files));
    fprintf("\tAligned truth tracks:\t%d\n", nAlignedTruthTracks);
else
    fprintf("\nSet runWrapperReplay = true to execute runBistaticAnalysisSession.\n");
end

%% Next Step For Detector Tuning
% Replace the probe seed with a real Apple Hill or CBS-compatible field
% seed before drawing detector conclusions. The probe path is useful for
% packaging and regression checks, but the field seed is the right
% starting point for delay, gain, and truth-alignment tuning.
