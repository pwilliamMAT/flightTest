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

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'ScenarioConfig', struct(), @isstruct);
addParameter(p, 'OutputRoot', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionID', "", @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

helperSyntheticEnsureProjectPaths();
scenario_config = localResolveScenarioConfig(opts);
terrain_info = helperSyntheticBuildSceneTerrain(scenario_config);
if ~terrain_info.tx_in_coverage || ~terrain_info.rx_in_coverage
    error('generateSyntheticHDTVSession:terrainCoverageMismatch', ...
        'The approved transmitter or receiver location falls outside the DTED coverage.');
end

truth_bundle = helperSyntheticGenerateTruth(scenario_config);
session_folder = fullfile(scenario_config.output_root, scenario_config.session_id);
radar_folder = fullfile(session_folder, 'radar');
truth_folder = fullfile(session_folder, 'truth');
logs_folder = fullfile(session_folder, 'logs');

localCreateFolderIfNeeded(scenario_config.output_root);
if exist(session_folder, 'dir') == 7
    error('generateSyntheticHDTVSession:sessionExists', ...
        'Synthetic session folder already exists: %s', session_folder);
end
localCreateFolderIfNeeded(session_folder);
localCreateFolderIfNeeded(radar_folder);
localCreateFolderIfNeeded(truth_folder);
localCreateFolderIfNeeded(logs_folder);

adsb_file_name = sprintf('adsb_%s.txt', scenario_config.session_id);
adsb_file_path = fullfile(truth_folder, adsb_file_name);
helperSyntheticWriteADSBTruth(adsb_file_path, truth_bundle.adsb_tracks);
adsb_files_rel = {localManifestPath('truth', adsb_file_name)};

traceability_truth_name = 'scenario_truth.mat';
traceability_truth_path = fullfile(truth_folder, traceability_truth_name);
try
    save(traceability_truth_path, 'truth_bundle');
catch ME
    error('generateSyntheticHDTVSession:traceabilitySaveFailed', ...
        'Could not save native traceability truth to %s: %s', ...
        traceability_truth_path, ME.message);
end
traceability_truth_rel = localManifestPath('truth', traceability_truth_name);

[radar_files_rel, header_readback, part_start_offsets_s] = helperSyntheticWriteBasebandParts( ...
    session_folder, scenario_config, truth_bundle);

manifest = helperSyntheticBuildManifest( ...
    scenario_config, radar_files_rel, adsb_files_rel, traceability_truth_rel, header_readback);
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

artifact = struct( ...
    'scenario_config', scenario_config, ...
    'session_id', scenario_config.session_id, ...
    'session_folder', session_folder, ...
    'manifest_path', manifest_path, ...
    'radar_files', {radar_files_rel(:).'}, ...
    'adsb_files', {adsb_files_rel(:).'}, ...
    'traceability_truth_path', traceability_truth_path, ...
    'part_start_offsets_s', part_start_offsets_s, ...
    'header_readback', header_readback, ...
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
