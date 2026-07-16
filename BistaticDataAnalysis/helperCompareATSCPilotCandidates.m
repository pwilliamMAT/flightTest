function comparison = helperCompareATSCPilotCandidates(coherence_freq_axis_hz, coherence_snr_db, varargin)
%HELPERCOMPAREATSCPILOTCANDIDATES Compare ATSC pilot candidates on one slice.
%
% Plain-language goal:
% The ATSC pilot selector already picks a geometry-aware winner, but an
% operator still needs to know how that winner compares against the best
% normal-orientation candidate, the best mirrored candidate, the global
% coherence maximum, and a PSD-based baseline inside the ATSC search
% neighborhood. This helper builds that shared comparison once so the
% plots, tests, and console summary all consume the same truth source.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'coherence_freq_axis_hz', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'coherence_snr_db', @(x) isnumeric(x) && isvector(x));
addParameter(p, 'PilotSelection', struct(), @isstruct);
addParameter(p, 'SpectralPowerDB', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'SpectralPowerFreqAxisHz', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'CoherenceThresholdDB', 10, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FallbackWeakCoherenceMaxDB', 8, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FallbackWeakProminenceMaxDB', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'FallbackMinScoreDeltaDB', 3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'FallbackMinCoherenceDeltaDB', 2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'FallbackMinProminenceDeltaDB', 3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
parse(p, coherence_freq_axis_hz, coherence_snr_db, varargin{:});
opts = p.Results;

freq_axis_hz = double(opts.coherence_freq_axis_hz(:));
snr_db = double(opts.coherence_snr_db(:));

if numel(freq_axis_hz) ~= numel(snr_db)
    error('helperCompareATSCPilotCandidates:sizeMismatch', ...
        'coherence_freq_axis_hz and coherence_snr_db must have the same length.');
end

selection_in = opts.PilotSelection;

[spectral_power_db, spectral_available] = localResolveSpectralPower(freq_axis_hz, opts);
sample_rate_hz = localGetFieldOrDefault(selection_in, 'sample_rate_hz', localResolveSampleRateHz(freq_axis_hz, NaN));
search_half_width_hz = localGetFieldOrDefault(selection_in, 'search_half_width_hz', 300e3);
prominence_inner_hz = localGetFieldOrDefault(selection_in, 'prominence_inner_hz', 20e3);
prominence_outer_hz = localGetFieldOrDefault(selection_in, 'prominence_outer_hz', 120e3);
prominence_weight = localGetFieldOrDefault(selection_in, 'prominence_weight', 1.0);
delta_penalty_weight = localGetFieldOrDefault(selection_in, 'delta_penalty_weight', 2.0);

hypotheses = localBuildHypotheses(selection_in);
union_mask = localBuildNeighborhoodMask(freq_axis_hz, hypotheses, sample_rate_hz, search_half_width_hz);

geometry_selected_candidate = localBuildCandidateRecord( ...
    localGetFieldOrDefault(selection_in, 'selected_freq_hz', NaN), ...
    "geometry_selected", "Geometry-aware selected", ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

best_normal_candidate = localBuildCandidateRecord( ...
    localGetFieldOrDefault(selection_in, 'best_nonmirrored_freq_hz', NaN), ...
    "best_normal", "Best normal candidate", ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

best_mirrored_candidate = localBuildCandidateRecord( ...
    localGetFieldOrDefault(selection_in, 'best_mirrored_freq_hz', NaN), ...
    "best_mirrored", "Best mirrored candidate", ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

global_coherence_candidate = localBuildCandidateRecord( ...
    localGetFieldOrDefault(selection_in, 'global_peak_freq_hz', NaN), ...
    "global_coherence_max", "Global coherence max", ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

psd_local_baseline_candidate = localBuildNeighborhoodExtremum( ...
    "psd_local_baseline", "PSD local baseline", union_mask, ...
    freq_axis_hz, spectral_power_db, spectral_available, snr_db, ...
    spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

coherence_local_candidate = localBuildNeighborhoodExtremum( ...
    "coherence_local_peak", "Coherence local peak", union_mask, ...
    freq_axis_hz, snr_db, true, snr_db, ...
    spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);

[expected_normal_frequency_hz, expected_mirrored_frequency_hz] = ...
    localResolveOrientationExpectations(geometry_selected_candidate, best_normal_candidate, best_mirrored_candidate);

fallback_applied = localShouldApplyFallback( ...
    geometry_selected_candidate, psd_local_baseline_candidate, opts);

selected_candidate = geometry_selected_candidate;
selection_mode = "geometry_aware_normal";
selected_source = "atsc_geometry";
if geometry_selected_candidate.is_mirrored
    selection_mode = "geometry_aware_mirrored";
end
if fallback_applied
    selected_candidate = psd_local_baseline_candidate;
    selection_mode = "validated_fallback";
    selected_source = "validated_fallback";
end

runner_up_candidate = localResolveRunnerUpCandidate( ...
    selected_candidate, best_normal_candidate, best_mirrored_candidate);
winner_minus_runner_up_score_db = localCandidateScoreDelta(selected_candidate, runner_up_candidate);
selected_psd_visibility_message = localBuildPSDVisibilityMessage(selected_candidate, spectral_available);
broader_search_used = localBroaderSearchUsed(selection_in, hypotheses);
broader_search_message = localBuildSearchMessage(broader_search_used);

selection_out = selection_in;
selection_out.expected_normal_freq_hz = expected_normal_frequency_hz;
selection_out.expected_mirrored_freq_hz = expected_mirrored_frequency_hz;
selection_out.geometry_selected_candidate = geometry_selected_candidate;
selection_out.best_nonmirrored_candidate = best_normal_candidate;
selection_out.best_mirrored_candidate = best_mirrored_candidate;
selection_out.global_coherence_candidate = global_coherence_candidate;
selection_out.psd_local_baseline_candidate = psd_local_baseline_candidate;
selection_out.coherence_local_candidate = coherence_local_candidate;
selection_out.runner_up_candidate = runner_up_candidate;
selection_out.selection_mode = char(selection_mode);
selection_out.selection_path_text = char(localSelectionPathText(selection_mode));
selection_out.fallback_applied = fallback_applied;
selection_out.broader_search_used = broader_search_used;
selection_out.broader_search_message = char(broader_search_message);
selection_out.selected_psd_visibility_message = char(selected_psd_visibility_message);
selection_out.winner_minus_runner_up_score_db = winner_minus_runner_up_score_db;
selection_out.selected_source = string(selected_source);

if localCandidateIsValid(selected_candidate)
    selection_out.selected_freq_hz = selected_candidate.measured_freq_hz;
    selection_out.selected_snr_db = selected_candidate.coherence_snr_db;
    selection_out.selected_expected_freq_hz = selected_candidate.expected_freq_hz;
    selection_out.selected_channel_center_hz = selected_candidate.channel_center_hz;
    selection_out.selected_is_mirrored = selected_candidate.is_mirrored;
    selection_out.illuminator_center_frequency_hz = selected_candidate.channel_center_hz;
end
selection_out.message = localBuildSelectionMessage( ...
    selection_out, selected_candidate, runner_up_candidate, global_coherence_candidate, ...
    broader_search_message, selected_psd_visibility_message);

candidate_records = [ ...
    geometry_selected_candidate; ...
    best_normal_candidate; ...
    best_mirrored_candidate; ...
    global_coherence_candidate; ...
    psd_local_baseline_candidate; ...
    coherence_local_candidate; ...
    runner_up_candidate; ...
    selected_candidate];

candidate_table = localBuildCandidateTable(candidate_records);
candidate_table = localAnnotateCandidateTable(candidate_table, ...
    selected_candidate, geometry_selected_candidate, best_normal_candidate, best_mirrored_candidate, ...
    runner_up_candidate, global_coherence_candidate, psd_local_baseline_candidate, coherence_local_candidate);

comparison = struct( ...
    'selection', selection_out, ...
    'geometry_selected_candidate', geometry_selected_candidate, ...
    'selected_candidate', selected_candidate, ...
    'best_normal_candidate', best_normal_candidate, ...
    'best_mirrored_candidate', best_mirrored_candidate, ...
    'runner_up_candidate', runner_up_candidate, ...
    'global_coherence_candidate', global_coherence_candidate, ...
    'psd_local_baseline_candidate', psd_local_baseline_candidate, ...
    'coherence_local_candidate', coherence_local_candidate, ...
    'expected_normal_frequency_hz', expected_normal_frequency_hz, ...
    'expected_mirrored_frequency_hz', expected_mirrored_frequency_hz, ...
    'winner_minus_runner_up_score_db', winner_minus_runner_up_score_db, ...
    'selected_psd_visibility_message', string(selected_psd_visibility_message), ...
    'broader_search_used', broader_search_used, ...
    'broader_search_message', string(broader_search_message), ...
    'fallback_applied', fallback_applied, ...
    'candidate_table', candidate_table);
end

function candidate = localBuildNeighborhoodExtremum(role_name, role_label, union_mask, freq_axis_hz, extremum_metric, metric_available, snr_db, spectral_power_db, spectral_available, hypotheses, sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, prominence_weight, delta_penalty_weight)
if ~metric_available || ~any(union_mask)
    candidate = localEmptyCandidate();
    candidate.role_name = role_name;
    candidate.role_label = role_label;
    return
end

masked_indices = find(union_mask);
[~, local_idx] = max(extremum_metric(masked_indices), [], 'omitnan');
if isempty(local_idx) || ~isfinite(local_idx)
    candidate = localEmptyCandidate();
    candidate.role_name = role_name;
    candidate.role_label = role_label;
    return
end

candidate = localBuildCandidateRecord( ...
    freq_axis_hz(masked_indices(local_idx)), role_name, role_label, ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, ...
    sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, ...
    prominence_weight, delta_penalty_weight);
end

function candidate = localBuildCandidateRecord(measured_freq_hz, role_name, role_label, freq_axis_hz, snr_db, spectral_power_db, spectral_available, hypotheses, sample_rate_hz, search_half_width_hz, prominence_inner_hz, prominence_outer_hz, prominence_weight, delta_penalty_weight)
candidate = localEmptyCandidate();
candidate.role_name = role_name;
candidate.role_label = role_label;

if ~isfinite(measured_freq_hz)
    return
end

[measured_freq_hz, bin_index] = localSnapToAxis(measured_freq_hz, freq_axis_hz, sample_rate_hz);
coherence_snr_db = snr_db(bin_index);

psd_prominence_db = NaN;
spectral_power_at_bin_db = NaN;
if spectral_available
    psd_prominence_db = localMeasureLineProminence( ...
        freq_axis_hz, spectral_power_db, bin_index, sample_rate_hz, ...
        prominence_inner_hz, prominence_outer_hz);
    spectral_power_at_bin_db = spectral_power_db(bin_index);
end

[expected_freq_hz, is_mirrored, channel_center_hz, signed_freq_error_hz, abs_freq_error_hz, within_search_neighborhood] = ...
    localMatchHypothesis(measured_freq_hz, hypotheses, sample_rate_hz, search_half_width_hz);

combined_score = coherence_snr_db;
if isfinite(abs_freq_error_hz)
    delta_penalty_db = delta_penalty_weight * (abs_freq_error_hz / max(search_half_width_hz, eps));
else
    delta_penalty_db = 0;
end
if isfinite(psd_prominence_db)
    combined_score = combined_score + prominence_weight * max(psd_prominence_db, 0);
end
combined_score = combined_score - delta_penalty_db;

candidate = struct( ...
    'role_name', role_name, ...
    'role_label', role_label, ...
    'measured_freq_hz', measured_freq_hz, ...
    'coherence_snr_db', coherence_snr_db, ...
    'spectral_power_db', spectral_power_at_bin_db, ...
    'psd_prominence_db', psd_prominence_db, ...
    'expected_freq_hz', expected_freq_hz, ...
    'signed_freq_error_hz', signed_freq_error_hz, ...
    'abs_freq_error_hz', abs_freq_error_hz, ...
    'combined_score', combined_score, ...
    'is_mirrored', is_mirrored, ...
    'orientation', localOrientationString(is_mirrored), ...
    'channel_center_hz', channel_center_hz, ...
    'within_search_neighborhood', within_search_neighborhood, ...
    'bin_index', bin_index);
end

function hypotheses = localBuildHypotheses(selection_in)
hypotheses = repmat(localEmptyHypothesis(), 0, 1);
if ~isstruct(selection_in) || ~isfield(selection_in, 'expected_candidates')
    return
end

expected_candidates = selection_in.expected_candidates;
for k = 1 : numel(expected_candidates)
    candidate = expected_candidates(k);
    if ~isfield(candidate, 'expected_freq_hz') || ~isfinite(candidate.expected_freq_hz)
        continue
    end

    hypothesis = struct( ...
        'expected_freq_hz', double(candidate.expected_freq_hz), ...
        'is_mirrored', logical(candidate.is_mirrored), ...
        'channel_center_hz', double(candidate.channel_center_hz));

    if localHasHypothesis(hypotheses, hypothesis)
        continue
    end

    hypotheses(end + 1, 1) = hypothesis; %#ok<AGROW>
end
end

function tf = localHasHypothesis(hypotheses, hypothesis)
tf = false;
for k = 1 : numel(hypotheses)
    tf = hypotheses(k).is_mirrored == hypothesis.is_mirrored && ...
        localNearlyEqual(hypotheses(k).expected_freq_hz, hypothesis.expected_freq_hz) && ...
        localNearlyEqual(hypotheses(k).channel_center_hz, hypothesis.channel_center_hz);
    if tf
        return
    end
end
end

function union_mask = localBuildNeighborhoodMask(freq_axis_hz, hypotheses, sample_rate_hz, search_half_width_hz)
union_mask = false(size(freq_axis_hz));
if isempty(hypotheses)
    return
end

expected_freqs_hz = reshape([hypotheses.expected_freq_hz], 1, []);
distance_hz = abs(localWrapToBaseband(freq_axis_hz - expected_freqs_hz, sample_rate_hz));
union_mask = any(distance_hz <= search_half_width_hz, 2);
end

function [expected_freq_hz, is_mirrored, channel_center_hz, signed_freq_error_hz, abs_freq_error_hz, within_search_neighborhood] = localMatchHypothesis(measured_freq_hz, hypotheses, sample_rate_hz, search_half_width_hz)
expected_freq_hz = NaN;
is_mirrored = false;
channel_center_hz = NaN;
signed_freq_error_hz = NaN;
abs_freq_error_hz = NaN;
within_search_neighborhood = false;

if isempty(hypotheses) || ~isfinite(measured_freq_hz)
    return
end

expected_freqs_hz = reshape([hypotheses.expected_freq_hz], 1, []);
signed_errors_hz = localWrapToBaseband(measured_freq_hz - expected_freqs_hz, sample_rate_hz);
abs_errors_hz = abs(signed_errors_hz);
abs_errors_hz(~isfinite(abs_errors_hz)) = inf;
if all(isinf(abs_errors_hz))
    return
end

[abs_freq_error_hz, idx] = min(abs_errors_hz);
signed_freq_error_hz = signed_errors_hz(idx);
expected_freq_hz = hypotheses(idx).expected_freq_hz;
is_mirrored = hypotheses(idx).is_mirrored;
channel_center_hz = hypotheses(idx).channel_center_hz;
within_search_neighborhood = abs_freq_error_hz <= search_half_width_hz;
end

function [expected_normal_frequency_hz, expected_mirrored_frequency_hz] = localResolveOrientationExpectations(geometry_selected_candidate, best_normal_candidate, best_mirrored_candidate)
expected_normal_frequency_hz = NaN;
expected_mirrored_frequency_hz = NaN;

if localCandidateIsValid(best_normal_candidate)
    expected_normal_frequency_hz = best_normal_candidate.expected_freq_hz;
end
if localCandidateIsValid(best_mirrored_candidate)
    expected_mirrored_frequency_hz = best_mirrored_candidate.expected_freq_hz;
end

if ~isfinite(expected_normal_frequency_hz) && localCandidateIsValid(geometry_selected_candidate) && ~geometry_selected_candidate.is_mirrored
    expected_normal_frequency_hz = geometry_selected_candidate.expected_freq_hz;
end
if ~isfinite(expected_mirrored_frequency_hz) && localCandidateIsValid(geometry_selected_candidate) && geometry_selected_candidate.is_mirrored
    expected_mirrored_frequency_hz = geometry_selected_candidate.expected_freq_hz;
end

if isfinite(expected_normal_frequency_hz) && ~isfinite(expected_mirrored_frequency_hz)
    expected_mirrored_frequency_hz = -expected_normal_frequency_hz;
elseif isfinite(expected_mirrored_frequency_hz) && ~isfinite(expected_normal_frequency_hz)
    expected_normal_frequency_hz = -expected_mirrored_frequency_hz;
end
end

function fallback_applied = localShouldApplyFallback(geometry_selected_candidate, psd_local_baseline_candidate, opts)
fallback_applied = false;
if ~localCandidateIsValid(geometry_selected_candidate) || ~localCandidateIsValid(psd_local_baseline_candidate)
    return
end

if localSameCandidate(geometry_selected_candidate, psd_local_baseline_candidate)
    return
end

geometry_weak = geometry_selected_candidate.coherence_snr_db <= opts.FallbackWeakCoherenceMaxDB && ...
    geometry_selected_candidate.psd_prominence_db <= opts.FallbackWeakProminenceMaxDB;
baseline_more_coherent = psd_local_baseline_candidate.coherence_snr_db - geometry_selected_candidate.coherence_snr_db >= ...
    opts.FallbackMinCoherenceDeltaDB;
baseline_more_prominent = psd_local_baseline_candidate.psd_prominence_db - geometry_selected_candidate.psd_prominence_db >= ...
    opts.FallbackMinProminenceDeltaDB;
baseline_score_not_much_worse = psd_local_baseline_candidate.combined_score >= ...
    geometry_selected_candidate.combined_score - opts.FallbackMinScoreDeltaDB;

fallback_applied = geometry_weak && ...
    psd_local_baseline_candidate.within_search_neighborhood && ...
    baseline_more_coherent && baseline_more_prominent && baseline_score_not_much_worse;
end

function runner_up_candidate = localResolveRunnerUpCandidate(selected_candidate, best_normal_candidate, best_mirrored_candidate)
runner_up_candidate = localEmptyCandidate();
if ~localCandidateIsValid(selected_candidate)
    return
end

if selected_candidate.is_mirrored
    if localCandidateIsValid(best_normal_candidate)
        runner_up_candidate = best_normal_candidate;
        return
    end
else
    if localCandidateIsValid(best_mirrored_candidate)
        runner_up_candidate = best_mirrored_candidate;
        return
    end
end

if localCandidateIsValid(best_normal_candidate) && ~localSameCandidate(best_normal_candidate, selected_candidate)
    runner_up_candidate = best_normal_candidate;
    return
end

if localCandidateIsValid(best_mirrored_candidate) && ~localSameCandidate(best_mirrored_candidate, selected_candidate)
    runner_up_candidate = best_mirrored_candidate;
end
end

function delta_db = localCandidateScoreDelta(a, b)
delta_db = NaN;
if ~localCandidateIsValid(a) || ~localCandidateIsValid(b)
    return
end
delta_db = a.combined_score - b.combined_score;
end

function message = localBuildPSDVisibilityMessage(selected_candidate, spectral_available)
if ~spectral_available
    message = 'PSD visibility was not available for this pilot audit.';
    return
end

if ~localCandidateIsValid(selected_candidate)
    message = 'No ATSC candidate was available for PSD visibility assessment.';
    return
end

if selected_candidate.psd_prominence_db >= 3
    message = 'Selected candidate sits on a clear narrow PSD line.';
elseif selected_candidate.psd_prominence_db >= 1
    message = 'Selected candidate sits on a weak but still visible PSD line.';
else
    message = 'Selected candidate is driven mainly by coherence; the PSD line is weak or ambiguous.';
end
end

function tf = localBroaderSearchUsed(selection_in, hypotheses)
tf = false;
if ~isstruct(selection_in)
    return
end

candidate_source = string(localGetFieldOrDefault(selection_in, 'candidate_source', ""));
tf = candidate_source == "nearest_atsc_raster" && ~isempty(hypotheses);
end

function message = localBuildSearchMessage(broader_search_used)
if broader_search_used
    message = 'Metadata did not lock one ATSC center, so a broader nearby-raster search was used.';
else
    message = 'Pilot comparison used the metadata-locked ATSC center.';
end
end

function txt = localSelectionPathText(selection_mode)
switch string(selection_mode)
    case "geometry_aware_mirrored"
        txt = "Geometry-aware mirrored-orientation selection";
    case "validated_fallback"
        txt = "Validated fallback to the PSD-local baseline";
    case "geometry_aware_normal"
        txt = "Geometry-aware normal-orientation selection";
    otherwise
        txt = "Geometry-aware pilot selection";
end
end

function message = localBuildSelectionMessage(selection_out, selected_candidate, runner_up_candidate, global_coherence_candidate, broader_search_message, psd_visibility_message)
if ~localCandidateIsValid(selected_candidate)
    message = sprintf('No ATSC candidate was available. %s', broader_search_message);
    return
end

runner_up_text = '';
if localCandidateIsValid(runner_up_candidate)
    runner_up_text = sprintf(', winner-runner-up %.1f dB', selection_out.winner_minus_runner_up_score_db);
end

message = sprintf([ ...
    '%s selected %.3f MHz (expected %.3f MHz, %s orientation, coherence %.1f dB, ' ...
    'PSD prominence %.1f dB%s). Global coherence max is %.3f MHz. %s %s'], ...
    selection_out.selection_path_text, ...
    selected_candidate.measured_freq_hz / 1e6, ...
    selected_candidate.expected_freq_hz / 1e6, ...
    char(selected_candidate.orientation), ...
    selected_candidate.coherence_snr_db, ...
    selected_candidate.psd_prominence_db, ...
    runner_up_text, ...
    global_coherence_candidate.measured_freq_hz / 1e6, ...
    psd_visibility_message, ...
    broader_search_message);
end

function candidate_table = localBuildCandidateTable(candidate_records)
candidate_table = table();
valid_mask = false(numel(candidate_records), 1);
for k = 1 : numel(candidate_records)
    valid_mask(k) = localCandidateIsValid(candidate_records(k));
end
candidate_records = candidate_records(valid_mask);

if isempty(candidate_records)
    return
end

merged_records = repmat(localEmptyCandidate(), 0, 1);
merged_tags = strings(0, 1);
merged_keys = strings(0, 1);

for k = 1 : numel(candidate_records)
    candidate = candidate_records(k);
    key = localCandidateKey(candidate);
    match_idx = find(merged_keys == key, 1, 'first');
    if isempty(match_idx)
        merged_records(end + 1, 1) = candidate; %#ok<AGROW>
        merged_tags(end + 1, 1) = candidate.role_name; %#ok<AGROW>
        merged_keys(end + 1, 1) = key; %#ok<AGROW>
    else
        merged_tags(match_idx) = strjoin(unique([split(merged_tags(match_idx), ','); candidate.role_name], 'stable'), ',');
    end
end

sort_score = zeros(numel(merged_records), 1);
abs_error = zeros(numel(merged_records), 1);
for k = 1 : numel(merged_records)
    sort_score(k) = merged_records(k).combined_score;
    abs_error(k) = merged_records(k).abs_freq_error_hz;
    if ~isfinite(sort_score(k))
        sort_score(k) = -inf;
    end
    if ~isfinite(abs_error(k))
        abs_error(k) = inf;
    end
end

candidate_table = table( ...
    merged_tags, ...
    [merged_records.measured_freq_hz].', ...
    [merged_records.expected_freq_hz].', ...
    [merged_records.signed_freq_error_hz].', ...
    [merged_records.abs_freq_error_hz].', ...
    [merged_records.coherence_snr_db].', ...
    [merged_records.psd_prominence_db].', ...
    [merged_records.combined_score].', ...
    [merged_records.is_mirrored].', ...
    string({merged_records.orientation}).', ...
    [merged_records.channel_center_hz].', ...
    [merged_records.within_search_neighborhood].', ...
    [merged_records.bin_index].', ...
    sort_score, abs_error, ...
    'VariableNames', { ...
        'roles', ...
        'measured_freq_hz', ...
        'expected_freq_hz', ...
        'signed_freq_error_hz', ...
        'abs_freq_error_hz', ...
        'coherence_snr_db', ...
        'psd_prominence_db', ...
        'combined_score', ...
        'is_mirrored', ...
        'orientation', ...
        'channel_center_hz', ...
        'within_search_neighborhood', ...
        'bin_index', ...
        'sort_score', ...
        'sort_abs_error_hz'});

candidate_table = sortrows(candidate_table, {'sort_score', 'sort_abs_error_hz', 'measured_freq_hz'}, {'descend', 'ascend', 'ascend'});
candidate_table.rank = (1 : height(candidate_table)).';
candidate_table = movevars(candidate_table, 'rank', 'Before', 'roles');
candidate_table = removevars(candidate_table, {'sort_score', 'sort_abs_error_hz'});
end

function candidate_table = localAnnotateCandidateTable(candidate_table, selected_candidate, geometry_selected_candidate, best_normal_candidate, best_mirrored_candidate, runner_up_candidate, global_coherence_candidate, psd_local_baseline_candidate, coherence_local_candidate)
if isempty(candidate_table)
    return
end

candidate_table.is_selected = localTableRoleMask(candidate_table, selected_candidate);
candidate_table.is_geometry_selected = localTableRoleMask(candidate_table, geometry_selected_candidate);
candidate_table.is_best_normal = localTableRoleMask(candidate_table, best_normal_candidate);
candidate_table.is_best_mirrored = localTableRoleMask(candidate_table, best_mirrored_candidate);
candidate_table.is_runner_up = localTableRoleMask(candidate_table, runner_up_candidate);
candidate_table.is_global_coherence_max = localTableRoleMask(candidate_table, global_coherence_candidate);
candidate_table.is_psd_local_baseline = localTableRoleMask(candidate_table, psd_local_baseline_candidate);
candidate_table.is_coherence_local_peak = localTableRoleMask(candidate_table, coherence_local_candidate);
end

function mask = localTableRoleMask(candidate_table, candidate)
mask = false(height(candidate_table), 1);
if ~localCandidateIsValid(candidate) || isempty(candidate_table)
    return
end

candidate_key = localCandidateKey(candidate);
for k = 1 : height(candidate_table)
    row_candidate = localEmptyCandidate();
    row_candidate.measured_freq_hz = candidate_table.measured_freq_hz(k);
    row_candidate.expected_freq_hz = candidate_table.expected_freq_hz(k);
    row_candidate.is_mirrored = candidate_table.is_mirrored(k);
    row_candidate.channel_center_hz = candidate_table.channel_center_hz(k);
    row_candidate.bin_index = candidate_table.bin_index(k);
    mask(k) = localCandidateKey(row_candidate) == candidate_key;
end
end

function key = localCandidateKey(candidate)
key = string(sprintf('%d|%d|%.3f|%.3f', ...
    candidate.bin_index, candidate.is_mirrored, candidate.measured_freq_hz, candidate.expected_freq_hz));
end

function tf = localCandidateIsValid(candidate)
tf = isstruct(candidate) && isfield(candidate, 'measured_freq_hz') && ...
    isfield(candidate, 'coherence_snr_db') && ...
    isfinite(candidate.measured_freq_hz) && isfinite(candidate.coherence_snr_db);
end

function tf = localSameCandidate(a, b)
tf = false;
if ~localCandidateIsValid(a) || ~localCandidateIsValid(b)
    return
end
tf = localCandidateKey(a) == localCandidateKey(b);
end

function [snapped_freq_hz, bin_index] = localSnapToAxis(freq_hz, freq_axis_hz, sample_rate_hz)
distance_hz = abs(localWrapToBaseband(freq_axis_hz - freq_hz, sample_rate_hz));
[~, bin_index] = min(distance_hz);
snapped_freq_hz = freq_axis_hz(bin_index);
end

function [spectral_power_db, spectral_available] = localResolveSpectralPower(freq_axis_hz, opts)
spectral_power_db = NaN(size(freq_axis_hz));
spectral_available = false;

if isempty(opts.SpectralPowerDB)
    return
end

spectral_values_db = double(opts.SpectralPowerDB(:));
if isempty(opts.SpectralPowerFreqAxisHz)
    if numel(spectral_values_db) ~= numel(freq_axis_hz)
        return
    end
    spectral_power_db = spectral_values_db;
    spectral_available = all(isfinite(spectral_power_db));
    return
end

spectral_freq_hz = double(opts.SpectralPowerFreqAxisHz(:));
if numel(spectral_freq_hz) ~= numel(spectral_values_db)
    return
end

[spectral_freq_hz, unique_idx] = unique(spectral_freq_hz, 'stable');
spectral_values_db = spectral_values_db(unique_idx);
spectral_power_db = interp1(spectral_freq_hz, spectral_values_db, freq_axis_hz, 'linear', 'extrap');
spectral_available = all(isfinite(spectral_power_db));
end

function prominence_db = localMeasureLineProminence(freq_axis_hz, spectral_power_db, center_idx, sample_rate_hz, inner_hz, outer_hz)
delta_hz = abs(localWrapToBaseband(freq_axis_hz - freq_axis_hz(center_idx), sample_rate_hz));
shoulder_mask = delta_hz >= inner_hz & delta_hz <= outer_hz;
if ~any(shoulder_mask)
    prominence_db = 0;
    return
end

baseline_db = median(spectral_power_db(shoulder_mask), 'omitnan');
prominence_db = spectral_power_db(center_idx) - baseline_db;
end

function wrapped_hz = localWrapToBaseband(freq_hz, sample_rate_hz)
wrapped_hz = mod(freq_hz + sample_rate_hz / 2, sample_rate_hz) - sample_rate_hz / 2;
end

function sample_rate_hz = localResolveSampleRateHz(freq_axis_hz, sample_rate_hz)
if isfinite(sample_rate_hz)
    return
end

if numel(freq_axis_hz) < 2
    sample_rate_hz = NaN;
    return
end

sample_rate_hz = median(diff(freq_axis_hz)) * numel(freq_axis_hz);
end

function candidate = localEmptyCandidate()
candidate = struct( ...
    'role_name', "", ...
    'role_label', "", ...
    'measured_freq_hz', NaN, ...
    'coherence_snr_db', NaN, ...
    'spectral_power_db', NaN, ...
    'psd_prominence_db', NaN, ...
    'expected_freq_hz', NaN, ...
    'signed_freq_error_hz', NaN, ...
    'abs_freq_error_hz', NaN, ...
    'combined_score', NaN, ...
    'is_mirrored', false, ...
    'orientation', "normal", ...
    'channel_center_hz', NaN, ...
    'within_search_neighborhood', false, ...
    'bin_index', NaN);
end

function hypothesis = localEmptyHypothesis()
hypothesis = struct( ...
    'expected_freq_hz', NaN, ...
    'is_mirrored', false, ...
    'channel_center_hz', NaN);
end

function orientation = localOrientationString(is_mirrored)
if is_mirrored
    orientation = "mirrored";
else
    orientation = "normal";
end
end

function value = localGetFieldOrDefault(source_struct, field_name, default_value)
value = default_value;
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    return
end

candidate_value = source_struct.(field_name);
if isempty(candidate_value)
    return
end

if isnumeric(candidate_value) || islogical(candidate_value)
    candidate_value = double(candidate_value);
    if isscalar(candidate_value) && isfinite(candidate_value)
        value = candidate_value;
    end
elseif isstring(candidate_value) || ischar(candidate_value)
    value = string(candidate_value);
else
    value = candidate_value;
end
end

function tf = localNearlyEqual(a, b)
tf = abs(a - b) <= 1;
end
