function artifact = generateSyntheticHDTVSession(varargin)
%GENERATESYNTHETICHDTVSESSION Generate one packaged synthetic session.
%
% Plain language:
% The generator creates a deterministic Apple Hill / CBS baseline scenario,
% emits traceable truth, writes a packaged session manifest, and produces
% dual-channel `.bb` files that the current workflow can open. It supports
% both the original zero-channel compatibility mode and the approved
% seed-backed bistatic mode, where a captured HDTV seed drives the
% reference channel and the surveillance echoes.
%
% Where to find things:
% - Scenario-definition defaults live in `buildSyntheticHDTVBaselineScenarioConfig`.
% - Truth generation lives in `helperSyntheticGenerateTruth`.
% - Signal synthesis and `.bb` writing live in
%   `helperSyntheticWriteBasebandParts` and
%   `helperSyntheticSynthesizeSeedBackedChannels`.
% - The user-facing orchestration lives in
%   `seedBackedSyntheticHDTVSessionWalkthrough`.

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'ScenarioConfig', struct(), @isstruct);
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

%% Resolve and validate scenario configuration
helperSyntheticEnsureProjectPaths();
scenario_config = localResolveScenarioConfig(opts);

%% Validate terrain coverage
terrain_info = helperSyntheticBuildSceneTerrain(scenario_config);
if ~terrain_info.tx_in_coverage || ~terrain_info.rx_in_coverage
    error('generateSyntheticHDTVSession:terrainCoverageMismatch', ...
        'The approved transmitter or receiver location falls outside the DTED coverage.');
end

%% Generate truth bundle
truth_bundle = helperSyntheticGenerateTruth(scenario_config);
seed_fixture_summary = helperSyntheticDescribeSeedFixture(scenario_config.seed_source_path);

%% Create packaged-session folder layout
session_folder = fullfile(scenario_config.output_root, scenario_config.session_id);
radar_folder = fullfile(session_folder, 'radar');
truth_folder = fullfile(session_folder, 'truth');
logs_folder = fullfile(session_folder, 'logs');

localCreateFolderIfNeeded(scenario_config.output_root);
if exist(session_folder, 'dir') == 7
    error('generateSyntheticHDTVSession:sessionExists', ...
        ['Synthetic session folder already exists: %s\n' ...
        'Choose a new SessionID, clear the walkthrough auto-generated sessionID, ' ...
        'or remove the existing folder before rerunning.'], ...
        session_folder);
end
localCreateFolderIfNeeded(session_folder);
localCreateFolderIfNeeded(radar_folder);
localCreateFolderIfNeeded(truth_folder);
localCreateFolderIfNeeded(logs_folder);

%% Write compatibility and traceability truth artifacts
adsb_file_name = sprintf('adsb_%s.txt', scenario_config.session_id);
adsb_file_path = fullfile(truth_folder, adsb_file_name);
helperSyntheticWriteADSBTruth(adsb_file_path, truth_bundle.adsb_tracks);
adsb_files_rel = {localManifestPath('truth', adsb_file_name)};

traceability_truth_name = 'scenario_truth.mat';
traceability_truth_path = fullfile(truth_folder, traceability_truth_name);
traceability_truth_rel = localManifestPath('truth', traceability_truth_name);

%% Synthesize and write radar `.bb` artifacts
[radar_files_rel, header_readback, part_start_offsets_s, part_synthesis_summaries] = helperSyntheticWriteBasebandParts( ...
    session_folder, scenario_config, truth_bundle);

try
    save( ...
        traceability_truth_path, ...
        'truth_bundle', ...
        'scenario_config', ...
        'part_start_offsets_s', ...
        'part_synthesis_summaries', ...
        'seed_fixture_summary');
catch ME
    error('generateSyntheticHDTVSession:traceabilitySaveFailed', ...
        'Could not save native traceability truth to %s: %s', ...
        traceability_truth_path, ME.message);
end

%% Build and write session manifest
manifest = helperSyntheticBuildManifest( ...
    scenario_config, radar_files_rel, adsb_files_rel, traceability_truth_rel, ...
    header_readback, truth_bundle);
manifest_path = fullfile(session_folder, 'session_manifest.json');
try
    fid = fopen(manifest_path, 'w');
    if fid < 0
        error('generateSyntheticHDTVSession:manifestOpenFailed', ...
            'Could not open manifest path for writing.');
    end
    cleanup_fid = onCleanup(@() fclose(fid));
    manifest_text = char(jsonencode(manifest, 'PrettyPrint', true));
    fwrite(fid, manifest_text, 'char');
catch ME
    error('generateSyntheticHDTVSession:manifestWriteFailed', ...
        'Could not write session manifest %s: %s', manifest_path, ME.message);
end

%% Return artifact summary
artifact = struct( ...
    'scenario_config', scenario_config, ...
    'session_id', scenario_config.session_id, ...
    'session_folder', session_folder, ...
    'manifest_path', manifest_path, ...
    'radar_files', {radar_files_rel(:).'}, ...
    'adsb_files', {adsb_files_rel(:).'}, ...
    'traceability_truth_path', traceability_truth_path, ...
    'part_start_offsets_s', part_start_offsets_s, ...
    'part_synthesis_summaries', {part_synthesis_summaries(:).'}, ...
    'header_readback', header_readback, ...
    'seed_fixture_summary', seed_fixture_summary, ...
    'terrain_summary', rmfield(terrain_info, {'scene', 'surface'}), ...
    'truth_bundle', truth_bundle);
end

function scenario_config = localResolveScenarioConfig(opts)
scenario_config = opts.ScenarioConfig;
if isempty(fieldnames(scenario_config))
    scenario_config = buildSyntheticHDTVBaselineScenarioConfig( ...
        'OutputRoot', opts.OutputRoot, ...
        'SessionID', opts.SessionID);
    return
end

if strlength(string(opts.OutputRoot)) > 0
    scenario_config.output_root = char(string(opts.OutputRoot));
end
if strlength(string(opts.SessionID)) > 0
    scenario_config.session_id = char(string(opts.SessionID));
end
end

function localCreateFolderIfNeeded(folder_path)
if exist(folder_path, 'dir') == 7
    return
end

[status, message] = mkdir(folder_path);
if ~status
    error('generateSyntheticHDTVSession:mkdirFailed', ...
        'Could not create folder %s: %s', folder_path, message);
end
end

function rel_path = localManifestPath(folder_name, file_name)
rel_path = strrep(fullfile(folder_name, file_name), '\', '/');
end
