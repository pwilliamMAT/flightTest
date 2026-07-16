function evidence = helperMeasureATSCPilotEvidence(reference_cube, reference_channel, fs, varargin)
%HELPERMEASUREATSCPILOTEVIDENCE PSD-first ATSC pilot audit with advisory stability.
%
% Plain-language goal:
% The ATSC pilot should be identified from where a narrowband line appears
% in the reference-channel spectrum near the expected transmitted pilot
% location, not from which FFT bin happens to stay phase-aligned across
% CPIs. This helper therefore uses one centered Welch PSD as the primary
% truth source for both pilot selection and plotting. It keeps the old
% FFT-bin coherence metric only as a secondary engineering diagnostic.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'reference_cube', @(x) isnumeric(x) && ~isempty(x));
addRequired(p, 'reference_channel', @(x) isnumeric(x) && ~isempty(x));
addRequired(p, 'fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CaptureCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'CaptureTuneFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'LOOffsetHz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SessionManifestCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'SessionManifestLOOffsetHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'IlluminatorCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'ATSCChannelBandwidthHz', 6e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ATSCPilotOffsetHz', 309.441e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LockedSearchHalfWidthHz', 75e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'FallbackSearchHalfWidthHz', 300e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'PilotPresenceProminencePassDB', 6, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'PilotPresenceProminenceWarnDB', 3, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'PilotPresenceFreqErrorPassHz', 25e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PilotPresenceFreqErrorWarnHz', 75e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'WelchSegmentLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x >= 64));
addParameter(p, 'PeakMinDistanceHz', 5e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'StabilityPassbandHz', 25e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'StabilityResampleRateHz', 200e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'StabilityWindowDurationS', 20e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'StabilityOverlapFraction', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x < 1);
parse(p, reference_cube, reference_channel, fs, varargin{:});
opts = p.Results;

reference_cube = double(reference_cube);
reference_channel = localResolveReferenceVector(reference_cube, reference_channel);

frequency_context = helperResolveCaptureFrequencyContext( ...
    'RequestedIlluminatorCenterHz', opts.IlluminatorCenterFrequencyHz, ...
    'HeaderCenterFrequencyHz', opts.CaptureCenterFrequencyHz, ...
    'HeaderLOOffsetHz', opts.LOOffsetHz, ...
    'SessionManifestCenterFrequencyHz', opts.SessionManifestCenterFrequencyHz, ...
    'SessionManifestLOOffsetHz', opts.SessionManifestLOOffsetHz);

[primary_channel_center_hz, primary_channel_center_source, metadata_locked] = ...
    localResolvePrimaryChannelCenter(frequency_context);

sample_rate_hz = double(fs);
capture_tune_hz = localResolveCaptureTune(opts.CaptureTuneFrequencyHz, frequency_context);
expected_normal_freq_hz = localResolveExpectedPilotFrequency( ...
    primary_channel_center_hz, capture_tune_hz, sample_rate_hz, ...
    opts.ATSCChannelBandwidthHz, opts.ATSCPilotOffsetHz);
expected_mirrored_freq_hz = localWrapToBaseband(-expected_normal_freq_hz, sample_rate_hz);

search_half_width_hz = opts.FallbackSearchHalfWidthHz;
selection_mode = "normal_only_nearest_raster_fallback";
selection_path_text = "Normal-side PSD selection (nearest-raster fallback)";
if metadata_locked
    search_half_width_hz = opts.LockedSearchHalfWidthHz;
    selection_mode = "normal_only_locked_metadata";
    selection_path_text = "Normal-side PSD selection (metadata locked)";
end
if strcmp(primary_channel_center_source, "explicit_override")
    selection_mode = "normal_only_explicit_override";
    selection_path_text = "Normal-side PSD selection (explicit illuminator override)";
end

[psd_freq_axis_hz, psd_linear_hz, psd_db_hz, welch_segment_length] = ...
    localBuildWelchPSD(reference_channel, sample_rate_hz, opts.WelchSegmentLength);

[legacy_freq_axis_hz, legacy_coherence_trace_db, legacy_power_linear, legacy_power_db] = ...
    localBuildLegacyCoherenceTrace(reference_cube, sample_rate_hz);

normal_candidates = localCollectNeighborhoodCandidates( ...
    psd_freq_axis_hz, psd_db_hz, expected_normal_freq_hz, search_half_width_hz, ...
    false, true, primary_channel_center_hz, sample_rate_hz, ...
    legacy_freq_axis_hz, legacy_coherence_trace_db, opts.PeakMinDistanceHz);
mirrored_candidates = localCollectNeighborhoodCandidates( ...
    psd_freq_axis_hz, psd_db_hz, expected_mirrored_freq_hz, search_half_width_hz, ...
    true, false, primary_channel_center_hz, sample_rate_hz, ...
    legacy_freq_axis_hz, legacy_coherence_trace_db, opts.PeakMinDistanceHz);

selected_candidate = localSelectPrimaryCandidate(normal_candidates);
best_normal_candidate = localSelectDiagnosticCandidate(normal_candidates);
best_mirrored_candidate = localSelectDiagnosticCandidate(mirrored_candidates);

selected_pilot_freq_hz = selected_candidate.measured_freq_hz;
selected_peak_prominence_db = selected_candidate.peak_prominence_db;
selected_peak_power_db = selected_candidate.peak_power_db;
pilot_freq_error_hz = selected_candidate.signed_freq_error_hz;
abs_pilot_freq_error_hz = selected_candidate.abs_freq_error_hz;
peak_found = selected_candidate.peak_found;

pilot_presence_pass = peak_found && ...
    isfinite(selected_peak_prominence_db) && ...
    selected_peak_prominence_db >= opts.PilotPresenceProminencePassDB && ...
    isfinite(abs_pilot_freq_error_hz) && ...
    abs_pilot_freq_error_hz <= opts.PilotPresenceFreqErrorPassHz;
pilot_presence_warn = peak_found && ~pilot_presence_pass && ...
    ((isfinite(selected_peak_prominence_db) && ...
    selected_peak_prominence_db >= opts.PilotPresenceProminenceWarnDB && ...
    selected_peak_prominence_db < opts.PilotPresenceProminencePassDB) || ...
    (isfinite(abs_pilot_freq_error_hz) && ...
    abs_pilot_freq_error_hz > opts.PilotPresenceFreqErrorPassHz && ...
    abs_pilot_freq_error_hz <= opts.PilotPresenceFreqErrorWarnHz));
pilot_presence_fail = ~(pilot_presence_pass || pilot_presence_warn);

[legacy_global_peak_snr_db, legacy_global_idx] = max(legacy_coherence_trace_db, [], 'omitnan');
legacy_global_peak_freq_hz = NaN;
if isfinite(legacy_global_idx) && legacy_global_idx >= 1 && legacy_global_idx <= numel(legacy_freq_axis_hz)
    legacy_global_peak_freq_hz = legacy_freq_axis_hz(legacy_global_idx);
end

legacy_coherence_snr_db = NaN;
if isfinite(selected_pilot_freq_hz)
    legacy_coherence_snr_db = interp1( ...
        legacy_freq_axis_hz, legacy_coherence_trace_db, selected_pilot_freq_hz, ...
        'linear', 'extrap');
end

[residual_offset_mean_hz, residual_offset_std_hz, corrected_concentration_db, ...
    residual_offset_time_s, residual_offset_hz, stability_available, stability_message, ...
    stability_error_message] = localMeasureStability( ...
    reference_channel, selected_candidate, sample_rate_hz, opts);

peak_evidence_message = localBuildPeakEvidenceMessage(selected_candidate);
selection_message = localBuildSelectionMessage( ...
    selection_path_text, selected_candidate, best_mirrored_candidate, ...
    peak_evidence_message, stability_message, legacy_coherence_snr_db);

diagnostic_table = localBuildDiagnosticTable(normal_candidates, mirrored_candidates, selected_candidate);
pilot_comparison = localBuildComparisonStruct( ...
    selection_mode, selection_path_text, selected_candidate, best_normal_candidate, ...
    best_mirrored_candidate, legacy_global_peak_freq_hz, legacy_global_peak_snr_db, ...
    expected_normal_freq_hz, expected_mirrored_freq_hz, diagnostic_table, ...
    peak_evidence_message, selection_message);

thresholds = struct( ...
    'locked_search_half_width_hz', opts.LockedSearchHalfWidthHz, ...
    'fallback_search_half_width_hz', opts.FallbackSearchHalfWidthHz, ...
    'prominence_pass_db', opts.PilotPresenceProminencePassDB, ...
    'prominence_warn_db', opts.PilotPresenceProminenceWarnDB, ...
    'freq_error_pass_hz', opts.PilotPresenceFreqErrorPassHz, ...
    'freq_error_warn_hz', opts.PilotPresenceFreqErrorWarnHz, ...
    'stability_passband_hz', opts.StabilityPassbandHz, ...
    'stability_resample_rate_hz', opts.StabilityResampleRateHz, ...
    'stability_window_duration_s', opts.StabilityWindowDurationS, ...
    'stability_overlap_fraction', opts.StabilityOverlapFraction);

evidence = struct( ...
    'psd_freq_axis_hz', psd_freq_axis_hz, ...
    'psd_linear_hz', psd_linear_hz, ...
    'psd_db_hz', psd_db_hz, ...
    'welch_segment_length', welch_segment_length, ...
    'expected_normal_freq_hz', expected_normal_freq_hz, ...
    'expected_mirrored_freq_hz', expected_mirrored_freq_hz, ...
    'primary_channel_center_hz', primary_channel_center_hz, ...
    'primary_channel_center_source', char(primary_channel_center_source), ...
    'capture_tune_frequency_hz', capture_tune_hz, ...
    'search_half_width_hz', search_half_width_hz, ...
    'metadata_locked', metadata_locked, ...
    'selected_pilot_freq_hz', selected_pilot_freq_hz, ...
    'selected_peak_prominence_db', selected_peak_prominence_db, ...
    'selected_peak_power_db', selected_peak_power_db, ...
    'pilot_freq_error_hz', pilot_freq_error_hz, ...
    'abs_pilot_freq_error_hz', abs_pilot_freq_error_hz, ...
    'peak_found', peak_found, ...
    'pilot_presence_pass', pilot_presence_pass, ...
    'pilot_presence_warn', pilot_presence_warn, ...
    'pilot_presence_fail', pilot_presence_fail, ...
    'pilot_presence_state', string(localPresenceState(pilot_presence_pass, pilot_presence_warn)), ...
    'residual_offset_mean_hz', residual_offset_mean_hz, ...
    'residual_offset_std_hz', residual_offset_std_hz, ...
    'corrected_concentration_db', corrected_concentration_db, ...
    'residual_offset_time_s', residual_offset_time_s, ...
    'residual_offset_hz', residual_offset_hz, ...
    'stability_available', stability_available, ...
    'stability_advisory', "advisory_only", ...
    'stability_message', string(stability_message), ...
    'stability_error_message', string(stability_error_message), ...
    'legacy_coherence_freq_axis_hz', legacy_freq_axis_hz, ...
    'legacy_coherence_trace_db', legacy_coherence_trace_db, ...
    'legacy_power_linear', legacy_power_linear, ...
    'legacy_power_db', legacy_power_db, ...
    'legacy_coherence_snr_db', legacy_coherence_snr_db, ...
    'legacy_global_peak_freq_hz', legacy_global_peak_freq_hz, ...
    'legacy_global_peak_snr_db', legacy_global_peak_snr_db, ...
    'selection_mode', string(selection_mode), ...
    'selection_path_text', string(selection_path_text), ...
    'message', string(selection_message), ...
    'peak_evidence_message', string(peak_evidence_message), ...
    'selected_candidate', selected_candidate, ...
    'best_normal_candidate', best_normal_candidate, ...
    'best_mirrored_candidate', best_mirrored_candidate, ...
    'diagnostic_table', diagnostic_table, ...
    'pilot_comparison', pilot_comparison, ...
    'frequency_context', frequency_context, ...
    'thresholds', thresholds);
end

function reference_vector = localResolveReferenceVector(reference_cube, reference_channel)
reference_vector = double(reference_channel(:));
required_length = numel(reference_cube);

if isempty(reference_vector) || required_length < 1
    reference_vector = double(reference_cube(:));
    return
end

if numel(reference_vector) < required_length
    reference_vector = double(reference_cube(:));
    return
end

reference_vector = reference_vector(1:required_length);
end

function capture_tune_hz = localResolveCaptureTune(requested_capture_tune_hz, frequency_context)
capture_tune_hz = NaN;
if ~isempty(requested_capture_tune_hz)
    capture_tune_hz = double(requested_capture_tune_hz);
end
if ~isfinite(capture_tune_hz)
    capture_tune_hz = double(frequency_context.capture_tune_frequency_hz);
end
if ~isfinite(capture_tune_hz)
    capture_tune_hz = NaN;
end
end

function [channel_center_hz, channel_center_source, metadata_locked] = ...
        localResolvePrimaryChannelCenter(frequency_context)
channel_center_hz = NaN;
channel_center_source = "unresolved";
metadata_locked = false;

illuminator_center_hz = double(frequency_context.illuminator_center_frequency_hz);
illuminator_source = string(frequency_context.illuminator_center_source);
if isfinite(illuminator_center_hz)
    channel_center_hz = illuminator_center_hz;
    metadata_locked = illuminator_source ~= "unresolved";
    channel_center_source = illuminator_source;
    return
end

fallback_reference_hz = double(frequency_context.capture_center_frequency_hz);
if ~isfinite(fallback_reference_hz)
    fallback_reference_hz = double(frequency_context.header_center_frequency_hz);
end
if ~isfinite(fallback_reference_hz)
    fallback_reference_hz = double(frequency_context.session_manifest_center_frequency_hz);
end

if isfinite(fallback_reference_hz)
    [channel_center_hz, ~] = localNearestATSCRaster(fallback_reference_hz);
    channel_center_source = "nearest_raster_fallback";
end
end

function expected_freq_hz = localResolveExpectedPilotFrequency(channel_center_hz, capture_tune_hz, sample_rate_hz, atsc_channel_bandwidth_hz, atsc_pilot_offset_hz)
expected_freq_hz = NaN;
if ~isfinite(channel_center_hz) || ~isfinite(capture_tune_hz) || ~isfinite(sample_rate_hz)
    return
end

pilot_rf_hz = channel_center_hz - atsc_channel_bandwidth_hz / 2 + atsc_pilot_offset_hz;
expected_freq_hz = localWrapToBaseband(pilot_rf_hz - capture_tune_hz, sample_rate_hz);
end

function [psd_freq_axis_hz, psd_linear_hz, psd_db_hz, segment_length] = ...
        localBuildWelchPSD(reference_channel, sample_rate_hz, requested_segment_length)
n_samples = numel(reference_channel);
segment_length = localResolveWelchSegmentLength(n_samples, sample_rate_hz, requested_segment_length);

if n_samples < 2 || segment_length < 2
    psd_linear_hz = NaN(0, 1);
    psd_freq_axis_hz = NaN(0, 1);
    psd_db_hz = NaN(0, 1);
    return
end

window = hamming(segment_length, 'periodic');
overlap_length = floor(0.5 * segment_length);
[psd_linear_hz, psd_freq_axis_hz] = pwelch( ...
    reference_channel, window, overlap_length, segment_length, sample_rate_hz, 'centered');
psd_linear_hz = psd_linear_hz(:);
psd_freq_axis_hz = psd_freq_axis_hz(:);
psd_db_hz = 10 * log10(psd_linear_hz + realmin);
end

function segment_length = localResolveWelchSegmentLength(n_samples, sample_rate_hz, requested_segment_length)
if ~isempty(requested_segment_length)
    segment_length = min(n_samples, floor(double(requested_segment_length)));
    segment_length = max(segment_length, 64);
    return
end

target_segment_length = min(round(0.01 * sample_rate_hz), 65536);
target_segment_length = max(target_segment_length, 8192);
segment_length = 2 ^ nextpow2(target_segment_length);
segment_length = min(segment_length, n_samples);
segment_length = max(segment_length, 64);
end

function [freq_axis_hz, coherence_trace_db, power_linear, power_db] = ...
        localBuildLegacyCoherenceTrace(reference_cube, sample_rate_hz)
n_fast = size(reference_cube, 1);
n_slow = size(reference_cube, 2);
n_fft = 2 ^ nextpow2(max(n_fast, 2));

fft_cube = fft(reference_cube, n_fft, 1);
mean_coherent_fft = mean(fft_cube, 2);
power_linear = mean(abs(fft_cube) .^ 2, 2);
coherence_ratio = abs(mean_coherent_fft) .^ 2 ./ max(power_linear, eps);
coherence_trace_db = 10 * log10(coherence_ratio * max(n_slow, 1) + eps);
power_db = 10 * log10(power_linear + eps);

freq_axis_hz = (-n_fft / 2 : n_fft / 2 - 1).' * (sample_rate_hz / n_fft);
coherence_trace_db = fftshift(coherence_trace_db(:));
power_linear = fftshift(power_linear(:));
power_db = fftshift(power_db(:));
end

function candidates = localCollectNeighborhoodCandidates( ...
        psd_freq_axis_hz, psd_db_hz, expected_freq_hz, search_half_width_hz, ...
        is_mirrored, selection_eligible, channel_center_hz, sample_rate_hz, ...
        legacy_freq_axis_hz, legacy_coherence_trace_db, peak_min_distance_hz)
candidates = repmat(localEmptyCandidate(), 0, 1);
if isempty(psd_freq_axis_hz) || ~isfinite(expected_freq_hz) || ~isfinite(search_half_width_hz)
    return
end

distance_hz = abs(localWrapToBaseband(psd_freq_axis_hz - expected_freq_hz, sample_rate_hz));
mask = distance_hz <= search_half_width_hz;
if ~any(mask)
    [~, nearest_idx] = min(distance_hz);
    mask(nearest_idx) = true;
end

freq_neighborhood_hz = psd_freq_axis_hz(mask);
psd_neighborhood_db = psd_db_hz(mask);

min_peak_distance_hz = max(peak_min_distance_hz, 2 * median(diff(freq_neighborhood_hz), 'omitnan'));
if ~isfinite(min_peak_distance_hz) || min_peak_distance_hz <= 0
    min_peak_distance_hz = peak_min_distance_hz;
end

[peak_values_db, peak_freqs_hz, peak_widths_hz, peak_prominences_db] = findpeaks( ...
    psd_neighborhood_db, freq_neighborhood_hz, 'MinPeakDistance', min_peak_distance_hz);

if isempty(peak_values_db)
    [peak_power_db, local_idx] = max(psd_neighborhood_db, [], 'omitnan');
    if isempty(local_idx) || ~isfinite(local_idx)
        return
    end

    candidates(1, 1) = localBuildCandidate( ...
        "neighborhood_max", freq_neighborhood_hz(local_idx), expected_freq_hz, ...
        channel_center_hz, peak_power_db, NaN, NaN, is_mirrored, selection_eligible, ...
        false, sample_rate_hz, legacy_freq_axis_hz, legacy_coherence_trace_db);
    return
end

candidates = repmat(localEmptyCandidate(), numel(peak_values_db), 1);
for idxCandidate = 1 : numel(peak_values_db)
    candidates(idxCandidate, 1) = localBuildCandidate( ...
        "psd_peak", peak_freqs_hz(idxCandidate), expected_freq_hz, channel_center_hz, ...
        peak_values_db(idxCandidate), peak_prominences_db(idxCandidate), peak_widths_hz(idxCandidate), ...
        is_mirrored, selection_eligible, true, sample_rate_hz, ...
        legacy_freq_axis_hz, legacy_coherence_trace_db);
end

candidates = localSortCandidates(candidates);
end

function candidate = localBuildCandidate( ...
        source_name, measured_freq_hz, expected_freq_hz, channel_center_hz, ...
        peak_power_db, peak_prominence_db, peak_width_hz, is_mirrored, ...
        selection_eligible, peak_found, sample_rate_hz, legacy_freq_axis_hz, ...
        legacy_coherence_trace_db)
signed_freq_error_hz = localWrapToBaseband(measured_freq_hz - expected_freq_hz, sample_rate_hz);
abs_freq_error_hz = abs(signed_freq_error_hz);
legacy_fft_bin_coherence_db = interp1( ...
    legacy_freq_axis_hz, legacy_coherence_trace_db, measured_freq_hz, 'linear', 'extrap');

candidate = struct( ...
    'role_name', string(source_name), ...
    'measured_freq_hz', double(measured_freq_hz), ...
    'expected_freq_hz', double(expected_freq_hz), ...
    'signed_freq_error_hz', signed_freq_error_hz, ...
    'abs_freq_error_hz', abs_freq_error_hz, ...
    'peak_power_db', double(peak_power_db), ...
    'peak_prominence_db', double(peak_prominence_db), ...
    'psd_prominence_db', double(peak_prominence_db), ...
    'peak_width_hz', double(peak_width_hz), ...
    'legacy_fft_bin_coherence_db', double(legacy_fft_bin_coherence_db), ...
    'coherence_snr_db', double(legacy_fft_bin_coherence_db), ...
    'is_mirrored', logical(is_mirrored), ...
    'selection_eligible', logical(selection_eligible), ...
    'peak_found', logical(peak_found), ...
    'within_search_neighborhood', true, ...
    'channel_center_hz', double(channel_center_hz), ...
    'combined_score', localCandidateScore(peak_found, peak_prominence_db), ...
    'rank', NaN, ...
    'is_selected', false);
end

function score = localCandidateScore(peak_found, peak_prominence_db)
score = -inf;
if peak_found && isfinite(peak_prominence_db)
    score = double(peak_prominence_db);
end
end

function candidates = localSortCandidates(candidates)
if isempty(candidates)
    return
end

sort_rows = zeros(numel(candidates), 5);
for idxCandidate = 1 : numel(candidates)
    sort_rows(idxCandidate, 1) = double(candidates(idxCandidate).peak_found);
    sort_rows(idxCandidate, 2) = double(candidates(idxCandidate).selection_eligible);
    sort_rows(idxCandidate, 3) = localSortValue(candidates(idxCandidate).peak_prominence_db, -inf);
    sort_rows(idxCandidate, 4) = -localSortValue(candidates(idxCandidate).abs_freq_error_hz, inf);
    sort_rows(idxCandidate, 5) = localSortValue(candidates(idxCandidate).peak_power_db, -inf);
end

[~, order] = sortrows(sort_rows, [-2, -1, -3, -4, -5]);
candidates = candidates(order);
for idxCandidate = 1 : numel(candidates)
    candidates(idxCandidate).rank = idxCandidate;
end
end

function value = localSortValue(candidate_value, default_value)
value = double(candidate_value);
if ~isfinite(value)
    value = default_value;
end
end

function selected_candidate = localSelectPrimaryCandidate(candidates)
selected_candidate = localEmptyCandidate();
if isempty(candidates)
    return
end

peak_mask = [candidates.selection_eligible] & [candidates.peak_found];
if any(peak_mask)
    selected_candidate = localSelectDiagnosticCandidate(candidates(peak_mask));
    selected_candidate.is_selected = true;
    return
end

eligible_mask = [candidates.selection_eligible];
if any(eligible_mask)
    selected_candidate = candidates(find(eligible_mask, 1, 'first'));
    selected_candidate.is_selected = true;
end
end

function diagnostic_candidate = localSelectDiagnosticCandidate(candidates)
diagnostic_candidate = localEmptyCandidate();
if isempty(candidates)
    return
end

candidates = localSortCandidates(candidates);
diagnostic_candidate = candidates(1);
end

function [residual_offset_mean_hz, residual_offset_std_hz, corrected_concentration_db, ...
        residual_offset_time_s, residual_offset_hz, stability_available, stability_message, ...
        stability_error_message] = localMeasureStability(reference_channel, selected_candidate, sample_rate_hz, opts)
residual_offset_mean_hz = NaN;
residual_offset_std_hz = NaN;
corrected_concentration_db = NaN;
residual_offset_time_s = NaN(0, 1);
residual_offset_hz = NaN(0, 1);
stability_available = false;
stability_error_message = "";

if ~selected_candidate.peak_found || ~isfinite(selected_candidate.measured_freq_hz)
    stability_message = "Pilot stability unavailable because no normal-side PSD peak was selected.";
    return
end

try
    n = (0 : numel(reference_channel) - 1).';
    mixed_signal = reference_channel .* exp(-1j * 2 * pi * selected_candidate.measured_freq_hz * n / sample_rate_hz);

    filtered_signal = lowpass(mixed_signal, opts.StabilityPassbandHz, sample_rate_hz);

    [p_ratio, q_ratio] = rat(opts.StabilityResampleRateHz / sample_rate_hz, 1e-12);
    stability_signal = resample(filtered_signal, p_ratio, q_ratio);
    stability_fs_hz = sample_rate_hz * p_ratio / q_ratio;

    window_length = round(opts.StabilityWindowDurationS * stability_fs_hz);
    step_length = max(1, round(window_length * (1 - opts.StabilityOverlapFraction)));
    if window_length < 2 || numel(stability_signal) < window_length
        stability_message = "Pilot stability unavailable because the filtered pilot slice is too short.";
        return
    end

    start_indices = 1 : step_length : (numel(stability_signal) - window_length + 1);
    residual_offset_hz = NaN(numel(start_indices), 1);
    residual_offset_time_s = NaN(numel(start_indices), 1);
    corrected_gain = NaN(numel(start_indices), 1);

    for idxWindow = 1 : numel(start_indices)
        first_index = start_indices(idxWindow);
        last_index = first_index + window_length - 1;
        window_signal = stability_signal(first_index:last_index);

        lag_correlation = xcorr(window_signal, 1, 'biased');
        lag_one_value = lag_correlation(3);
        residual_offset_hz(idxWindow) = angle(lag_one_value) * stability_fs_hz / (2 * pi);
        residual_offset_time_s(idxWindow) = ...
            ((first_index - 1) + 0.5 * (window_length - 1)) / stability_fs_hz;

        time_vector_s = (0 : window_length - 1).' / stability_fs_hz;
        derotated_signal = window_signal .* exp(-1j * 2 * pi * residual_offset_hz(idxWindow) * time_vector_s);
        corrected_gain(idxWindow) = abs(mean(derotated_signal)) .^ 2 / ...
            max(mean(abs(derotated_signal) .^ 2), eps);
    end

    valid_mask = isfinite(residual_offset_hz);
    residual_offset_hz = residual_offset_hz(valid_mask);
    residual_offset_time_s = residual_offset_time_s(valid_mask);
    corrected_gain = corrected_gain(valid_mask);

    if isempty(residual_offset_hz)
        stability_message = "Pilot stability unavailable because no residual-offset windows were valid.";
        return
    end

    residual_offset_mean_hz = mean(residual_offset_hz, 'omitnan');
    residual_offset_std_hz = std(residual_offset_hz, 0, 'omitnan');
    corrected_concentration_db = 10 * log10(mean(corrected_gain, 'omitnan') + eps);
    stability_available = true;
    stability_message = sprintf( ...
        'Advisory only: mean %.1f Hz, std %.1f Hz, concentration %.1f dB.', ...
        residual_offset_mean_hz, residual_offset_std_hz, corrected_concentration_db);
catch ME
    stability_error_message = ME.message;
    stability_message = "Pilot stability unavailable because the advisory analysis failed.";
end
end

function message = localBuildPeakEvidenceMessage(selected_candidate)
if ~selected_candidate.peak_found
    message = "No PSD peak was found in the normal-side pilot neighborhood.";
    return
end

if selected_candidate.peak_prominence_db >= 6
    message = "Selected peak sits on a clear narrowband PSD line.";
elseif selected_candidate.peak_prominence_db >= 3
    message = "Selected peak sits on a weak but still visible PSD line.";
else
    message = "Selected peak is weak in the PSD and should be treated cautiously.";
end
end

function message = localBuildSelectionMessage( ...
        selection_path_text, selected_candidate, best_mirrored_candidate, ...
        peak_evidence_message, stability_message, legacy_coherence_snr_db)
if ~isfinite(selected_candidate.measured_freq_hz)
    message = sprintf('%s could not identify a normal-side pilot candidate.', selection_path_text);
    return
end

mirrored_text = '';
if best_mirrored_candidate.peak_found && isfinite(best_mirrored_candidate.peak_prominence_db)
    mirrored_text = sprintf( ...
        ' Mirrored diagnostic peak %.3f MHz has %.1f dB prominence but cannot win primary selection.', ...
        best_mirrored_candidate.measured_freq_hz / 1e6, ...
        best_mirrored_candidate.peak_prominence_db);
end

legacy_text = '';
if isfinite(legacy_coherence_snr_db)
    legacy_text = sprintf(' Legacy FFT-bin coherence at the selected pilot is %.1f dB.', ...
        legacy_coherence_snr_db);
end

message = sprintf([ ...
    '%s chose %.3f MHz with PSD prominence %.1f dB and frequency error %.1f kHz. ' ...
    '%s %s%s%s'], ...
    selection_path_text, ...
    selected_candidate.measured_freq_hz / 1e6, ...
    selected_candidate.peak_prominence_db, ...
    selected_candidate.abs_freq_error_hz / 1e3, ...
    peak_evidence_message, ...
    stability_message, ...
    mirrored_text, ...
    legacy_text);
end

function diagnostic_table = localBuildDiagnosticTable(normal_candidates, mirrored_candidates, selected_candidate)
all_candidates = [normal_candidates; mirrored_candidates];
if isempty(all_candidates)
    diagnostic_table = table();
    return
end

all_candidates = localSortCandidates(all_candidates);
selected_key = localCandidateKey(selected_candidate);

n_candidates = numel(all_candidates);
rank = zeros(n_candidates, 1);
role_name = strings(n_candidates, 1);
measured_freq_hz = NaN(n_candidates, 1);
expected_freq_hz = NaN(n_candidates, 1);
signed_freq_error_hz = NaN(n_candidates, 1);
abs_freq_error_hz = NaN(n_candidates, 1);
peak_power_db = NaN(n_candidates, 1);
psd_prominence_db = NaN(n_candidates, 1);
peak_width_hz = NaN(n_candidates, 1);
legacy_fft_bin_coherence_db = NaN(n_candidates, 1);
is_mirrored = false(n_candidates, 1);
selection_eligible = false(n_candidates, 1);
peak_found = false(n_candidates, 1);
is_selected = false(n_candidates, 1);

for idxCandidate = 1 : n_candidates
    candidate = all_candidates(idxCandidate);
    rank(idxCandidate) = idxCandidate;
    role_name(idxCandidate) = string(candidate.role_name);
    measured_freq_hz(idxCandidate) = candidate.measured_freq_hz;
    expected_freq_hz(idxCandidate) = candidate.expected_freq_hz;
    signed_freq_error_hz(idxCandidate) = candidate.signed_freq_error_hz;
    abs_freq_error_hz(idxCandidate) = candidate.abs_freq_error_hz;
    peak_power_db(idxCandidate) = candidate.peak_power_db;
    psd_prominence_db(idxCandidate) = candidate.peak_prominence_db;
    peak_width_hz(idxCandidate) = candidate.peak_width_hz;
    legacy_fft_bin_coherence_db(idxCandidate) = candidate.legacy_fft_bin_coherence_db;
    is_mirrored(idxCandidate) = candidate.is_mirrored;
    selection_eligible(idxCandidate) = candidate.selection_eligible;
    peak_found(idxCandidate) = candidate.peak_found;
    is_selected(idxCandidate) = localCandidateKey(candidate) == selected_key;
end

diagnostic_table = table( ...
    rank, role_name, measured_freq_hz, expected_freq_hz, ...
    signed_freq_error_hz, abs_freq_error_hz, peak_power_db, ...
    psd_prominence_db, peak_width_hz, legacy_fft_bin_coherence_db, ...
    is_mirrored, selection_eligible, peak_found, is_selected);
end

function comparison = localBuildComparisonStruct( ...
        selection_mode, selection_path_text, selected_candidate, best_normal_candidate, ...
        best_mirrored_candidate, legacy_global_peak_freq_hz, legacy_global_peak_snr_db, ...
        expected_normal_freq_hz, expected_mirrored_freq_hz, diagnostic_table, ...
        peak_evidence_message, selection_message)
global_coherence_candidate = localEmptyCandidate();
global_coherence_candidate.role_name = "legacy_global_coherence";
global_coherence_candidate.measured_freq_hz = legacy_global_peak_freq_hz;
global_coherence_candidate.coherence_snr_db = legacy_global_peak_snr_db;
global_coherence_candidate.legacy_fft_bin_coherence_db = legacy_global_peak_snr_db;

comparison = struct( ...
    'selection', struct( ...
        'selection_mode', string(selection_mode), ...
        'selection_path_text', string(selection_path_text), ...
        'message', string(selection_message), ...
        'expected_normal_freq_hz', expected_normal_freq_hz, ...
        'expected_mirrored_freq_hz', expected_mirrored_freq_hz), ...
    'selected_candidate', selected_candidate, ...
    'best_normal_candidate', best_normal_candidate, ...
    'best_mirrored_candidate', best_mirrored_candidate, ...
    'runner_up_candidate', best_mirrored_candidate, ...
    'global_coherence_candidate', global_coherence_candidate, ...
    'expected_normal_frequency_hz', expected_normal_freq_hz, ...
    'expected_mirrored_frequency_hz', expected_mirrored_freq_hz, ...
    'selected_psd_visibility_message', string(peak_evidence_message), ...
    'candidate_table', diagnostic_table);
end

function key = localCandidateKey(candidate)
key = string(sprintf('%s|%d|%.3f|%.3f', ...
    char(candidate.role_name), candidate.is_mirrored, ...
    candidate.measured_freq_hz, candidate.expected_freq_hz));
end

function state = localPresenceState(pilot_presence_pass, pilot_presence_warn)
if pilot_presence_pass
    state = 'pass';
elseif pilot_presence_warn
    state = 'warn';
else
    state = 'fail';
end
end

function candidate = localEmptyCandidate()
candidate = struct( ...
    'role_name', "", ...
    'measured_freq_hz', NaN, ...
    'expected_freq_hz', NaN, ...
    'signed_freq_error_hz', NaN, ...
    'abs_freq_error_hz', NaN, ...
    'peak_power_db', NaN, ...
    'peak_prominence_db', NaN, ...
    'psd_prominence_db', NaN, ...
    'peak_width_hz', NaN, ...
    'legacy_fft_bin_coherence_db', NaN, ...
    'coherence_snr_db', NaN, ...
    'is_mirrored', false, ...
    'selection_eligible', false, ...
    'peak_found', false, ...
    'within_search_neighborhood', false, ...
    'channel_center_hz', NaN, ...
    'combined_score', NaN, ...
    'rank', NaN, ...
    'is_selected', false);
end

function [nearest_raster_hz, off_raster_hz] = localNearestATSCRaster(freq_hz)
raster_hz = localATSCRasterCentersHz();
nearest_raster_hz = NaN;
off_raster_hz = NaN;

if ~isfinite(freq_hz)
    return
end

[~, idxNearest] = min(abs(raster_hz - freq_hz));
nearest_raster_hz = raster_hz(idxNearest);
off_raster_hz = freq_hz - nearest_raster_hz;
end

function raster_hz = localATSCRasterCentersHz()
vhf_low_hz = [57, 63, 69, 79, 85] * 1e6;
vhf_high_hz = (177 : 6 : 213) * 1e6;
uhf_hz = (473 : 6 : 803) * 1e6;
raster_hz = [vhf_low_hz, vhf_high_hz, uhf_hz];
end

function wrapped_hz = localWrapToBaseband(freq_hz, sample_rate_hz)
wrapped_hz = mod(freq_hz + sample_rate_hz / 2, sample_rate_hz) - sample_rate_hz / 2;
end
