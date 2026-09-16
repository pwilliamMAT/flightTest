function result = runADSBReadinessTest(source, varargin)
%RUNADSBREADINESSTEST Decide whether archived ADS-B supports manual selection.
%
%   result = runADSBReadinessTest(source)
%   result = runADSBReadinessTest(source, Name=Value)
%
%   SOURCE may be a packaged-session folder, a session_manifest.json file,
%   or any source accepted by loadADSBRemoterArchive. A packaged session uses
%   its radar epoch and active-window duration. For a raw archive, provide
%   WindowStartUTC and WindowDurationS to test a planned collection window.
%
%   This is an offline, fail-closed readiness gate. It never connects to an
%   ADS-B source and never starts radar acquisition. PASS requires readable
%   truth, coverage at both window edges, adequate fix density and velocity,
%   and at least one manually selectable aircraft whose observed receiver
%   CPA lies inside (not at an endpoint of) the analysis window.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source');
addParameter(p, 'WindowStartUTC', [], @localValidTime);
addParameter(p, 'WindowDurationS', [], @localEmptyOrPositiveScalar);
addParameter(p, 'MinTrackCount', 3, @localPositiveInteger);
addParameter(p, 'MinPositionFixCount', 30, @localPositiveInteger);
addParameter(p, 'MaxWindowEdgeGapS', 2.0, @localNonnegativeScalar);
addParameter(p, 'MaxMedianUpdateGapS', 2.0, @localPositiveScalar);
addParameter(p, 'MinVelocityFixFraction', 0.8, @localFraction);
addParameter(p, 'MinCandidateFixCount', 5, @localPositiveInteger);
addParameter(p, 'MaxCandidateMedianUpdateGapS', 2.0, @localPositiveScalar);
addParameter(p, 'MaxCandidateEdgeGapS', 2.0, @localNonnegativeScalar);
addParameter(p, 'MinCandidateWindowCoverage', 0.8, @localFraction);
addParameter(p, 'MinCandidateVelocityFixFraction', 0.8, @localFraction);
addParameter(p, 'MaxCandidateCount', 10, @localPositiveInteger);
addParameter(p, 'CreatePlot', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Visible', 'on', ...
    @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, source, varargin{:});
opts = p.Results;

source_info = localEmptySourceInfo();
try
    [archive_source, source_info] = localResolveSource(source);
    [adsb_tracks, import_info] = loadADSBRemoterArchive( ...
        archive_source, 'Verbose', false);
catch cause
    result = localImportFailureResult(source_info, cause);
    if opts.Verbose
        localPrintResult(result);
    end
    return
end

[window_start_s, window_end_s, window_source] = localResolveWindow( ...
    adsb_tracks, source_info, opts);
[window_tracks, fixes] = localCropTracks( ...
    adsb_tracks, window_start_s, window_end_s);

metrics = localMeasureWindow( ...
    window_tracks, fixes, window_start_s, window_end_s);
[candidates, eligible_count] = localBuildCandidates( ...
    window_tracks, window_start_s, window_end_s, opts);
gates = localBuildGates(metrics, eligible_count, opts);
truth_ready = all(gates.Passed( ...
    gates.Gate ~= "defensible_manual_candidate"));
manual_selection_ready = truth_ready && all(gates.Passed);
status = localStatus(manual_selection_ready);

top_aircraft_id = "";
top_bisnr_db = NaN;
eligible_rows = find(candidates.CandidateEligible);
if ~isempty(eligible_rows)
    top_aircraft_id = candidates.AircraftID(eligible_rows(1));
    top_bisnr_db = candidates.BiSNR_dB(eligible_rows(1));
end

session_id = source_info.SessionID;
summary = table( ...
    session_id, status, truth_ready, manual_selection_ready, window_source, ...
    localPosixToDatetime(window_start_s), ...
    localPosixToDatetime(window_end_s), ...
    metrics.TrackCount, metrics.PositionFixCount, ...
    metrics.MedianUpdateGapS, metrics.VelocityFixFraction, ...
    eligible_count, top_aircraft_id, top_bisnr_db, ...
    'VariableNames', { ...
        'SessionID', 'Status', 'TruthReady', 'ManualSelectionReady', ...
        'WindowSource', ...
        'WindowStartUTC', 'WindowEndUTC', ...
        'TrackCount', 'PositionFixCount', ...
        'MedianUpdateGap_s', 'VelocityFixFraction', ...
        'EligibleCandidateCount', 'TopEligibleAircraftID', ...
        'TopEligibleBiSNR_dB'});

result = struct( ...
    'Status', status, ...
    'TruthReady', truth_ready, ...
    'ReadyForManualSelection', manual_selection_ready, ...
    'Summary', summary, ...
    'Gates', gates, ...
    'Candidates', candidates( ...
        1:min(height(candidates), opts.MaxCandidateCount), :), ...
    'Fixes', fixes, ...
    'ImportInfo', import_info, ...
    'SourceInfo', source_info, ...
    'ErrorIdentifier', "", ...
    'ErrorMessage', "", ...
    'Figure', matlab.ui.Figure.empty);

if opts.CreatePlot
    result.Figure = plotADSBReadiness(result, 'Visible', opts.Visible);
end

if opts.Verbose
    localPrintResult(result);
end

end

function [archive_source, source_info] = localResolveSource(source)
source_info = localEmptySourceInfo();
archive_source = source;

if ~(ischar(source) || (isstring(source) && isscalar(source)))
    return
end

source_path = string(source);
if isfolder(source_path)
    manifest_path = fullfile(source_path, 'session_manifest.json');
    if ~isfile(manifest_path)
        return
    end
elseif isfile(source_path) && endsWith( ...
        lower(source_path), "session_manifest.json")
    manifest_path = source_path;
else
    return
end

try
    manifest = jsondecode(fileread(manifest_path));
catch cause
    failure = MException( ...
        'runADSBReadinessTest:badManifest', ...
        'Could not parse session manifest %s.', manifest_path);
    failure = addCause(failure, cause);
    throwAsCaller(failure);
end

if ~isfield(manifest, 'adsb_files') || isempty(manifest.adsb_files)
    error('runADSBReadinessTest:missingADSBFiles', ...
        'Session manifest %s does not list ADS-B truth files.', manifest_path);
end

manifest_folder = fileparts(manifest_path);
archive_source = localResolveManifestPaths( ...
    manifest_folder, localTextList(manifest.adsb_files));
source_info.ManifestPath = string(manifest_path);
if isfield(manifest, 'session_id')
    source_info.SessionID = string(manifest.session_id);
end
if isfield(manifest, 'radar_epoch_utc')
    source_info.ManifestWindowStartS = ...
        localNumericScalar(manifest.radar_epoch_utc);
end
if isfield(manifest, 'radar_active_window_s')
    source_info.ManifestWindowDurationS = ...
        localNumericScalar(manifest.radar_active_window_s);
end
end

function source_info = localEmptySourceInfo()
source_info = struct( ...
    'SessionID', "", ...
    'ManifestPath', "", ...
    'ManifestWindowStartS', NaN, ...
    'ManifestWindowDurationS', NaN);
end

function resolved = localResolveManifestPaths(folder, relative_paths)
resolved = strings(size(relative_paths));
for path_idx = 1:numel(relative_paths)
    candidate = string(relative_paths(path_idx));
    if localIsAbsolutePath(candidate)
        resolved(path_idx) = candidate;
    else
        resolved(path_idx) = fullfile(folder, candidate);
    end
end
end

function tf = localIsAbsolutePath(path_text)
if ispc
    tf = ~isempty(regexp(path_text, '^[A-Za-z]:[\\/]', 'once')) || ...
        startsWith(path_text, "\\");
else
    tf = startsWith(path_text, filesep);
end
end

function values = localTextList(raw_value)
if ischar(raw_value)
    values = string({raw_value});
elseif isstring(raw_value)
    values = raw_value(:);
elseif iscell(raw_value)
    values = string(raw_value(:));
else
    error('runADSBReadinessTest:badADSBFiles', ...
        'Manifest adsb_files must contain text paths.');
end
end

function value = localNumericScalar(raw_value)
if isnumeric(raw_value)
    value = double(raw_value(1));
else
    value = str2double(string(raw_value));
end
if ~(isscalar(value) && isfinite(value))
    value = NaN;
end
end

function [window_start_s, window_end_s, source_name] = ...
        localResolveWindow(adsb_tracks, source_info, opts)
all_times_s = vertcat(adsb_tracks.t_utc);
if isempty(all_times_s)
    window_start_s = NaN;
    window_end_s = NaN;
    source_name = "unavailable";
    return
end

explicit_start_s = localTimeToPosix(opts.WindowStartUTC);
explicit_duration_s = opts.WindowDurationS;

if isfinite(explicit_start_s)
    window_start_s = explicit_start_s;
    source_name = "explicit";
elseif isfinite(source_info.ManifestWindowStartS)
    window_start_s = source_info.ManifestWindowStartS;
    source_name = "session_manifest";
elseif ~isempty(explicit_duration_s)
    window_start_s = max(all_times_s) - explicit_duration_s;
    source_name = "archive_tail";
else
    window_start_s = min(all_times_s);
    source_name = "archive_extent";
end

if ~isempty(explicit_duration_s)
    window_duration_s = double(explicit_duration_s);
elseif source_name == "session_manifest" && ...
        isfinite(source_info.ManifestWindowDurationS) && ...
        source_info.ManifestWindowDurationS > 0
    window_duration_s = source_info.ManifestWindowDurationS;
else
    window_duration_s = max(all_times_s) - window_start_s;
end

window_end_s = window_start_s + window_duration_s;
if ~(isfinite(window_start_s) && isfinite(window_end_s) && ...
        window_end_s > window_start_s)
    error('runADSBReadinessTest:badWindow', ...
        'The resolved ADS-B analysis window must have positive duration.');
end
end

function [window_tracks, fixes] = localCropTracks( ...
        adsb_tracks, window_start_s, window_end_s)
window_tracks = adsb_tracks;
keep_track = false(size(adsb_tracks));
fix_aircraft_id = strings(0, 1);
fix_time_s = zeros(0, 1);
fix_has_velocity = false(0, 1);
sample_fields = { ...
    't_utc', 'lat_deg', 'lon_deg', 'alt_m', ...
    'speed_mps', 'track_deg', 'vrate_mps'};

for track_idx = 1:numel(adsb_tracks)
    in_window = adsb_tracks(track_idx).t_utc >= window_start_s & ...
        adsb_tracks(track_idx).t_utc <= window_end_s;
    if ~any(in_window)
        continue
    end

    keep_track(track_idx) = true;
    for field_idx = 1:numel(sample_fields)
        field_name = sample_fields{field_idx};
        if isfield(window_tracks, field_name)
            values = adsb_tracks(track_idx).(field_name);
            window_tracks(track_idx).(field_name) = values(in_window);
        end
    end

    fix_count = sum(in_window);
    fix_aircraft_id = [fix_aircraft_id; ...
        repmat(upper(string(adsb_tracks(track_idx).hex)), fix_count, 1)]; %#ok<AGROW>
    fix_time_s = [fix_time_s; ...
        adsb_tracks(track_idx).t_utc(in_window)]; %#ok<AGROW>
    fix_has_velocity = [fix_has_velocity; ...
        isfinite(adsb_tracks(track_idx).speed_mps(in_window)) & ...
        isfinite(adsb_tracks(track_idx).track_deg(in_window))]; %#ok<AGROW>
end

window_tracks = window_tracks(keep_track);
fixes = table( ...
    fix_aircraft_id, localPosixToDatetime(fix_time_s), fix_has_velocity, ...
    'VariableNames', {'AircraftID', 'FixTimeUTC', 'HasVelocity'});
fixes = sortrows(fixes, {'FixTimeUTC', 'AircraftID'});
end

function metrics = localMeasureWindow( ...
        window_tracks, fixes, window_start_s, window_end_s)
all_gaps_s = zeros(0, 1);
for track_idx = 1:numel(window_tracks)
    all_gaps_s = [all_gaps_s; diff(window_tracks(track_idx).t_utc)]; %#ok<AGROW>
end

metrics = struct( ...
    'TrackCount', numel(window_tracks), ...
    'PositionFixCount', height(fixes), ...
    'StartEdgeGapS', Inf, ...
    'EndEdgeGapS', Inf, ...
    'MedianUpdateGapS', Inf, ...
    'VelocityFixFraction', 0);

if ~isempty(fixes)
    fix_times_s = posixtime(fixes.FixTimeUTC);
    metrics.StartEdgeGapS = max(0, min(fix_times_s) - window_start_s);
    metrics.EndEdgeGapS = max(0, window_end_s - max(fix_times_s));
    metrics.VelocityFixFraction = mean(fixes.HasVelocity);
end
if ~isempty(all_gaps_s)
    metrics.MedianUpdateGapS = median(all_gaps_s, 'omitmissing');
end
end

function [candidates, eligible_count] = localBuildCandidates( ...
        window_tracks, window_start_s, window_end_s, opts)
if isempty(window_tracks)
    candidates = localEmptyCandidateTable();
    eligible_count = 0;
    return
end

% The existing opportunity builder remains the geometry and BiSNR authority.
% Capture its educational trace so this gate can emit one concise summary.
evalc(['opportunities = buildManualADSBOpportunityTable(' ...
    'window_tracks, helperADSBRemoter599MHzConfig());']);

row_count = height(opportunities);
first_fix_utc = NaT(row_count, 1, 'TimeZone', 'UTC');
last_fix_utc = NaT(row_count, 1, 'TimeZone', 'UTC');
start_edge_gap_s = NaN(row_count, 1);
end_edge_gap_s = NaN(row_count, 1);
window_coverage_fraction = NaN(row_count, 1);
median_update_gap_s = Inf(row_count, 1);
max_update_gap_s = Inf(row_count, 1);
velocity_fix_fraction = zeros(row_count, 1);

track_ids = upper(string({window_tracks.hex}));
window_duration_s = window_end_s - window_start_s;
for row_idx = 1:row_count
    track_idx = find(track_ids == opportunities.AircraftID(row_idx), 1);
    track = window_tracks(track_idx);
    track_times_s = track.t_utc(:);
    gaps_s = diff(track_times_s);

    first_fix_utc(row_idx) = localPosixToDatetime(track_times_s(1));
    last_fix_utc(row_idx) = localPosixToDatetime(track_times_s(end));
    start_edge_gap_s(row_idx) = track_times_s(1) - window_start_s;
    end_edge_gap_s(row_idx) = window_end_s - track_times_s(end);
    window_coverage_fraction(row_idx) = ...
        (track_times_s(end) - track_times_s(1)) / window_duration_s;
    if ~isempty(gaps_s)
        median_update_gap_s(row_idx) = median(gaps_s, 'omitmissing');
        max_update_gap_s(row_idx) = max(gaps_s);
    end
    velocity_fix_fraction(row_idx) = mean( ...
        isfinite(track.speed_mps) & isfinite(track.track_deg));
end

candidate_eligible = ...
    opportunities.PositionFixCount >= opts.MinCandidateFixCount & ...
    median_update_gap_s <= opts.MaxCandidateMedianUpdateGapS & ...
    start_edge_gap_s <= opts.MaxCandidateEdgeGapS & ...
    end_edge_gap_s <= opts.MaxCandidateEdgeGapS & ...
    window_coverage_fraction >= opts.MinCandidateWindowCoverage & ...
    velocity_fix_fraction >= opts.MinCandidateVelocityFixFraction & ...
    ~opportunities.CPAIsTrackEndpoint;

hold_reason = strings(row_count, 1);
for row_idx = 1:row_count
    reasons = strings(0, 1);
    if opportunities.PositionFixCount(row_idx) < opts.MinCandidateFixCount
        reasons(end + 1) = "too_few_fixes"; %#ok<AGROW>
    end
    if median_update_gap_s(row_idx) > opts.MaxCandidateMedianUpdateGapS
        reasons(end + 1) = "slow_updates"; %#ok<AGROW>
    end
    if start_edge_gap_s(row_idx) > opts.MaxCandidateEdgeGapS
        reasons(end + 1) = "stale_at_window_start"; %#ok<AGROW>
    end
    if end_edge_gap_s(row_idx) > opts.MaxCandidateEdgeGapS
        reasons(end + 1) = "stale_at_window_end"; %#ok<AGROW>
    end
    if window_coverage_fraction(row_idx) < opts.MinCandidateWindowCoverage
        reasons(end + 1) = "insufficient_window_coverage"; %#ok<AGROW>
    end
    if velocity_fix_fraction(row_idx) < opts.MinCandidateVelocityFixFraction
        reasons(end + 1) = "missing_velocity"; %#ok<AGROW>
    end
    if opportunities.CPAIsTrackEndpoint(row_idx)
        reasons(end + 1) = "cpa_at_window_endpoint"; %#ok<AGROW>
    end
    hold_reason(row_idx) = strjoin(reasons, ";");
end

candidates = addvars( ...
    opportunities, first_fix_utc, last_fix_utc, ...
    start_edge_gap_s, end_edge_gap_s, window_coverage_fraction, ...
    median_update_gap_s, max_update_gap_s, velocity_fix_fraction, ...
    candidate_eligible, hold_reason, ...
    'NewVariableNames', { ...
        'FirstFixUTC', 'LastFixUTC', ...
        'StartEdgeGap_s', 'EndEdgeGap_s', 'WindowCoverageFraction', ...
        'MedianUpdateGap_s', 'MaxUpdateGap_s', 'VelocityFixFraction', ...
        'CandidateEligible', 'HoldReason'});
candidates = sortrows( ...
    candidates, {'CandidateEligible', 'BiSNR_dB', 'AircraftID'}, ...
    {'descend', 'descend', 'ascend'});
eligible_count = sum(candidates.CandidateEligible);
end

function gates = localBuildGates(metrics, eligible_count, opts)
gate = [ ...
    "archive_integrity"; ...
    "window_edge_coverage"; ...
    "position_track_count"; ...
    "position_fix_count"; ...
    "median_update_gap"; ...
    "velocity_coverage"; ...
    "defensible_manual_candidate"];
passed = [ ...
    true; ...
    metrics.StartEdgeGapS <= opts.MaxWindowEdgeGapS && ...
        metrics.EndEdgeGapS <= opts.MaxWindowEdgeGapS; ...
    metrics.TrackCount >= opts.MinTrackCount; ...
    metrics.PositionFixCount >= opts.MinPositionFixCount; ...
    metrics.MedianUpdateGapS <= opts.MaxMedianUpdateGapS; ...
    metrics.VelocityFixFraction >= opts.MinVelocityFixFraction; ...
    eligible_count >= 1];
observed = [ ...
    "readable"; ...
    compose("start %.2f s, end %.2f s", ...
        metrics.StartEdgeGapS, metrics.EndEdgeGapS); ...
    string(metrics.TrackCount); ...
    string(metrics.PositionFixCount); ...
    compose("%.3f s", metrics.MedianUpdateGapS); ...
    compose("%.1f%%", 100 .* metrics.VelocityFixFraction); ...
    string(eligible_count)];
criterion = [ ...
    "gzip/CSV import succeeds"; ...
    compose("both edges <= %.2f s", opts.MaxWindowEdgeGapS); ...
    compose(">= %d tracks", opts.MinTrackCount); ...
    compose(">= %d fixes", opts.MinPositionFixCount); ...
    compose("<= %.2f s", opts.MaxMedianUpdateGapS); ...
    compose(">= %.0f%%", 100 .* opts.MinVelocityFixFraction); ...
    ">= 1 eligible candidate"];
detail = [ ...
    "Original archive is used; no repair or partial recovery."; ...
    "ADS-B positions bracket the requested analysis window."; ...
    "Distinct aircraft with position fixes in the window."; ...
    "All aircraft position fixes in the window."; ...
    "Median within-track interval between position fixes."; ...
    "Fraction of position fixes with interpolated speed and course."; ...
    "Candidate passes freshness, density, velocity, coverage, and CPA checks."];

gates = table(gate, passed, observed, criterion, detail, ...
    'VariableNames', {'Gate', 'Passed', 'Observed', 'Criterion', 'Detail'});
end

function result = localImportFailureResult(source_info, cause)
gates = table( ...
    "archive_integrity", false, "unreadable", ...
    "gzip/CSV import succeeds", ...
    "Archive is corrupt, truncated, missing, or otherwise unreadable.", ...
    'VariableNames', {'Gate', 'Passed', 'Observed', 'Criterion', 'Detail'});
summary = table( ...
    source_info.SessionID, "hold", false, false, "unavailable", ...
    NaT(1, 1, 'TimeZone', 'UTC'), NaT(1, 1, 'TimeZone', 'UTC'), ...
    0, 0, Inf, 0, 0, "", NaN, ...
    'VariableNames', { ...
        'SessionID', 'Status', 'TruthReady', 'ManualSelectionReady', ...
        'WindowSource', ...
        'WindowStartUTC', 'WindowEndUTC', ...
        'TrackCount', 'PositionFixCount', ...
        'MedianUpdateGap_s', 'VelocityFixFraction', ...
        'EligibleCandidateCount', 'TopEligibleAircraftID', ...
        'TopEligibleBiSNR_dB'});
result = struct( ...
    'Status', "hold", ...
    'TruthReady', false, ...
    'ReadyForManualSelection', false, ...
    'Summary', summary, ...
    'Gates', gates, ...
    'Candidates', localEmptyCandidateTable(), ...
    'Fixes', table( ...
        strings(0, 1), NaT(0, 1, 'TimeZone', 'UTC'), false(0, 1), ...
        'VariableNames', {'AircraftID', 'FixTimeUTC', 'HasVelocity'}), ...
    'ImportInfo', struct(), ...
    'SourceInfo', source_info, ...
    'ErrorIdentifier', string(cause.identifier), ...
    'ErrorMessage', string(cause.message), ...
    'Figure', matlab.ui.Figure.empty);
end

function candidates = localEmptyCandidateTable()
base = buildManualADSBOpportunityTable(struct( ...
    'hex', {}, 'callsign', {}, 't_utc', {}, 'lat_deg', {}, ...
    'lon_deg', {}, 'alt_m', {}, 'speed_mps', {}, ...
    'track_deg', {}, 'vrate_mps', {}));
candidates = addvars( ...
    base, ...
    NaT(0, 1, 'TimeZone', 'UTC'), ...
    NaT(0, 1, 'TimeZone', 'UTC'), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    zeros(0, 1), zeros(0, 1), zeros(0, 1), ...
    false(0, 1), strings(0, 1), ...
    'NewVariableNames', { ...
        'FirstFixUTC', 'LastFixUTC', ...
        'StartEdgeGap_s', 'EndEdgeGap_s', 'WindowCoverageFraction', ...
        'MedianUpdateGap_s', 'MaxUpdateGap_s', 'VelocityFixFraction', ...
        'CandidateEligible', 'HoldReason'});
end

function localPrintResult(result)
fprintf('\n[runADSBReadinessTest] Status: %s\n', upper(result.Status));
disp(result.Summary)
disp(result.Gates)
if ~isempty(result.Candidates)
    disp(result.Candidates(:, { ...
        'AircraftID', 'Callsign', 'BiSNR_dB', 'CandidateEligible', ...
        'CPAIsTrackEndpoint', 'PositionFixCount', ...
        'MedianUpdateGap_s', 'VelocityFixFraction', 'HoldReason'}))
end
if strlength(result.ErrorIdentifier) > 0
    fprintf('  %s: %s\n', result.ErrorIdentifier, result.ErrorMessage);
end
end

function status = localStatus(passed)
if passed
    status = "pass";
else
    status = "hold";
end
end

function value = localTimeToPosix(raw_time)
if isempty(raw_time)
    value = NaN;
elseif isa(raw_time, 'datetime')
    time_value = raw_time;
    if strlength(time_value.TimeZone) == 0
        time_value.TimeZone = 'UTC';
    end
    value = posixtime(time_value);
else
    value = double(raw_time);
end
end

function value = localPosixToDatetime(posix_seconds)
value = datetime( ...
    posix_seconds, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
end

function tf = localValidTime(value)
tf = isempty(value) || ...
    (isnumeric(value) && isscalar(value) && isfinite(value)) || ...
    (isa(value, 'datetime') && isscalar(value) && ~isnat(value));
end

function tf = localEmptyOrPositiveScalar(value)
tf = isempty(value) || localPositiveScalar(value);
end

function tf = localPositiveScalar(value)
tf = isnumeric(value) && isscalar(value) && isreal(value) && ...
    isfinite(value) && value > 0;
end

function tf = localNonnegativeScalar(value)
tf = isnumeric(value) && isscalar(value) && isreal(value) && ...
    isfinite(value) && value >= 0;
end

function tf = localPositiveInteger(value)
tf = localPositiveScalar(value) && value == floor(value);
end

function tf = localFraction(value)
tf = isnumeric(value) && isscalar(value) && isreal(value) && ...
    isfinite(value) && value >= 0 && value <= 1;
end
