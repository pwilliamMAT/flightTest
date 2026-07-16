function selection = helperSelectATSCPilotCandidate(coherence_freq_axis_hz, coherence_snr_db, varargin)
%HELPERSELECTATSCPILOTCANDIDATE Choose an ATSC-consistent pilot candidate.
%
%  Plain-language goal:
%  The strongest coherent FFT bin is not automatically the ATSC pilot.
%  A passive-radar reference can contain other coherent lines from leakage,
%  interference, or imaging artefacts. This helper uses ATSC channel
%  geometry together with the capture tune frequency to predict where the
%  lower-edge pilot should appear in baseband after wrap-around, then it
%  searches only near those physically plausible bins.
%
%  selection = helperSelectATSCPilotCandidate(freq_axis_hz, coherence_snr_db)
%  selection = helperSelectATSCPilotCandidate(..., 'SampleRateHz', fs, ...)
%
%  Inputs:
%    coherence_freq_axis_hz    Frequency axis for the coherence trace.
%    coherence_snr_db          Coherence SNR trace on the same grid.
%
%  Name-value options:
%    'SampleRateHz'                Sample rate. If omitted, infer from axis.
%    'CaptureCenterFrequencyHz'    Header/BasebandFileWriter center frequency.
%    'CaptureTuneFrequencyHz'      Actual SDR RF tune. If omitted, use
%                                  CaptureCenterFrequencyHz + LOOffsetHz.
%    'LOOffsetHz'                  LO offset stored in metadata.
%    'IlluminatorCenterFrequencyHz'
%                                  Explicit ATSC channel center to test.
%    'ATSCChannelBandwidthHz'      Default 6e6.
%    'ATSCPilotOffsetHz'           Default 309.441e3 from lower edge.
%    'SearchHalfWidthHz'           Half-width around each expected pilot.
%    'SpectralPowerDB'             Incoherent spectral power trace (dB) on
%                                  the same axis as the coherence trace, or
%                                  supplied through SpectralPowerFreqAxisHz.
%    'SpectralPowerFreqAxisHz'     Frequency axis for SpectralPowerDB.
%    'ProminenceWeight'            Weight for narrow-line prominence score.
%    'DeltaPenaltyWeight'          Penalty weight for frequency mismatch.
%    'ProminenceInnerHz'           Guard region around the line.
%    'ProminenceOuterHz'           Outer shoulder region for baseline.
%    'MaxRasterCandidates'         Number of nearest ATSC centers to test
%                                  when the illuminator center is unknown.
%
%  Output:
%    selection   struct with both the global strongest coherent line and
%                the best ATSC-consistent candidate.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'coherence_freq_axis_hz', @(x) isnumeric(x) && isvector(x));
addRequired(p, 'coherence_snr_db', @(x) isnumeric(x) && isvector(x));
addParameter(p, 'SampleRateHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0));
addParameter(p, 'CaptureCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'CaptureTuneFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'LOOffsetHz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'IlluminatorCenterFrequencyHz', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'ATSCChannelBandwidthHz', 6e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ATSCPilotOffsetHz', 309.441e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SearchHalfWidthHz', 300e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SpectralPowerDB', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'SpectralPowerFreqAxisHz', [], @(x) isempty(x) || isnumeric(x));
addParameter(p, 'ProminenceWeight', 1.0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'DeltaPenaltyWeight', 2.0, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'ProminenceInnerHz', 20e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ProminenceOuterHz', 120e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxRasterCandidates', 3, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x, 1) == 0);
parse(p, coherence_freq_axis_hz, coherence_snr_db, varargin{:});
opts = p.Results;

freq_axis_hz = double(opts.coherence_freq_axis_hz(:));
snr_db = double(opts.coherence_snr_db(:));

if numel(freq_axis_hz) ~= numel(snr_db)
    error('helperSelectATSCPilotCandidate:sizeMismatch', ...
        'coherence_freq_axis_hz and coherence_snr_db must have the same length.');
end

[spectral_power_db, spectral_available] = localResolveSpectralPower(freq_axis_hz, opts);

[global_peak_snr_db, global_idx] = max(snr_db);
global_peak_freq_hz = freq_axis_hz(global_idx);

sample_rate_hz = localResolveSampleRateHz(freq_axis_hz, opts.SampleRateHz);
capture_center_hz = localScalarOrNaN(opts.CaptureCenterFrequencyHz);
capture_tune_hz = localScalarOrNaN(opts.CaptureTuneFrequencyHz);
if ~isfinite(capture_tune_hz) && isfinite(capture_center_hz)
    capture_tune_hz = capture_center_hz + opts.LOOffsetHz;
end

[header_nearest_raster_hz, header_off_raster_hz, candidate_centers_hz, candidate_source] = ...
    localResolveCandidateCenters(capture_center_hz, capture_tune_hz, opts);

selection = struct( ...
    'global_peak_freq_hz', global_peak_freq_hz, ...
    'global_peak_snr_db', global_peak_snr_db, ...
    'selected_freq_hz', global_peak_freq_hz, ...
    'selected_snr_db', global_peak_snr_db, ...
    'selected_source', "global_peak", ...
    'selected_expected_freq_hz', NaN, ...
    'selected_channel_center_hz', NaN, ...
    'selected_is_mirrored', false, ...
    'used_atsc_geometry', false, ...
    'sample_rate_hz', sample_rate_hz, ...
    'capture_center_frequency_hz', capture_center_hz, ...
    'capture_tune_frequency_hz', capture_tune_hz, ...
    'lo_offset_hz', opts.LOOffsetHz, ...
    'illuminator_center_frequency_hz', NaN, ...
    'header_center_nearest_atsc_hz', header_nearest_raster_hz, ...
    'header_center_off_raster_hz', header_off_raster_hz, ...
    'search_half_width_hz', opts.SearchHalfWidthHz, ...
    'prominence_weight', opts.ProminenceWeight, ...
    'delta_penalty_weight', opts.DeltaPenaltyWeight, ...
    'prominence_inner_hz', opts.ProminenceInnerHz, ...
    'prominence_outer_hz', opts.ProminenceOuterHz, ...
    'atsc_channel_bandwidth_hz', opts.ATSCChannelBandwidthHz, ...
    'atsc_pilot_offset_hz', opts.ATSCPilotOffsetHz, ...
    'candidate_source', string(candidate_source), ...
    'best_nonmirrored_score', NaN, ...
    'best_nonmirrored_freq_hz', NaN, ...
    'best_nonmirrored_candidate', localEmptyCandidate(), ...
    'best_mirrored_score', NaN, ...
    'best_mirrored_freq_hz', NaN, ...
    'best_mirrored_candidate', localEmptyCandidate(), ...
    'mirrored_minus_nonmirrored_score', NaN, ...
    'selected_candidate', localEmptyCandidate(), ...
    'expected_candidates', repmat(localEmptyCandidate(), 0, 1), ...
    'message', "");

if ~isfinite(sample_rate_hz) || ~isfinite(capture_tune_hz) || isempty(candidate_centers_hz)
    selection.message = sprintf('Strongest coherent line at %.3f MHz.', global_peak_freq_hz / 1e6);
    return
end

candidates = repmat(localEmptyCandidate(), 0, 1);
for idx_center = 1:numel(candidate_centers_hz)
    channel_center_hz = candidate_centers_hz(idx_center);
    pilot_rf_hz = channel_center_hz - opts.ATSCChannelBandwidthHz / 2 + opts.ATSCPilotOffsetHz;
    expected_freq_hz = localWrapToBaseband(pilot_rf_hz - capture_tune_hz, sample_rate_hz);

    normal_candidate = localEvaluateCandidate( ...
        freq_axis_hz, snr_db, spectral_power_db, spectral_available, ...
        expected_freq_hz, false, channel_center_hz, sample_rate_hz, opts);
    mirror_candidate = localEvaluateCandidate( ...
        freq_axis_hz, snr_db, spectral_power_db, spectral_available, ...
        -expected_freq_hz, true, channel_center_hz, sample_rate_hz, opts);

    candidates(end + 1, 1) = normal_candidate; %#ok<AGROW>
    candidates(end + 1, 1) = mirror_candidate; %#ok<AGROW>
end

selection.expected_candidates = candidates;
selection.used_atsc_geometry = ~isempty(candidates);
selection = localAttachOrientationSummary(selection, candidates);

if isempty(candidates)
    selection.message = sprintf('Strongest coherent line at %.3f MHz.', global_peak_freq_hz / 1e6);
    return
end

[~, best_idx] = max([candidates.combined_score]);
best_candidate = candidates(best_idx);

selection.selected_freq_hz = best_candidate.measured_freq_hz;
selection.selected_snr_db = best_candidate.measured_snr_db;
selection.selected_source = "atsc_geometry";
selection.selected_expected_freq_hz = best_candidate.expected_freq_hz;
selection.selected_channel_center_hz = best_candidate.channel_center_hz;
selection.selected_is_mirrored = best_candidate.is_mirrored;
selection.illuminator_center_frequency_hz = best_candidate.channel_center_hz;
selection.selected_candidate = best_candidate;
selection.message = localBuildSelectionMessage(best_candidate, selection);
end

function candidate = localEvaluateCandidate(freq_axis_hz, snr_db, spectral_power_db, spectral_available, expected_freq_hz, is_mirrored, channel_center_hz, sample_rate_hz, opts)
distance_hz = abs(localWrapToBaseband(freq_axis_hz - expected_freq_hz, sample_rate_hz));
mask = distance_hz <= opts.SearchHalfWidthHz;
if ~any(mask)
    [~, nearest_idx] = min(distance_hz);
    mask(nearest_idx) = true;
end

masked_indices = find(mask);
[candidate_scores, line_prominence_db] = localScoreCandidateBins( ...
    freq_axis_hz, snr_db, spectral_power_db, spectral_available, masked_indices, ...
    distance_hz, sample_rate_hz, opts);
[combined_score, local_idx] = max(candidate_scores);
measured_idx = masked_indices(local_idx);
measured_snr_db = snr_db(measured_idx);
measured_freq_hz = freq_axis_hz(measured_idx);

candidate = struct( ...
    'channel_center_hz', channel_center_hz, ...
    'expected_freq_hz', expected_freq_hz, ...
    'measured_freq_hz', measured_freq_hz, ...
    'measured_snr_db', measured_snr_db, ...
    'coherence_snr_db', measured_snr_db, ...
    'line_prominence_db', line_prominence_db(local_idx), ...
    'psd_prominence_db', line_prominence_db(local_idx), ...
    'combined_score', combined_score, ...
    'score', combined_score, ...
    'delta_freq_hz', localWrapToBaseband(measured_freq_hz - expected_freq_hz, sample_rate_hz), ...
    'abs_delta_freq_hz', abs(localWrapToBaseband(measured_freq_hz - expected_freq_hz, sample_rate_hz)), ...
    'is_mirrored', is_mirrored, ...
    'orientation', localOrientationString(is_mirrored));
end

function [candidate_scores, line_prominence_db] = localScoreCandidateBins(freq_axis_hz, snr_db, spectral_power_db, spectral_available, masked_indices, distance_hz, sample_rate_hz, opts)
candidate_scores = -inf(numel(masked_indices), 1);
line_prominence_db = zeros(numel(masked_indices), 1);

for idx = 1:numel(masked_indices)
    bin_idx = masked_indices(idx);
    delta_penalty_db = opts.DeltaPenaltyWeight * (distance_hz(bin_idx) / max(opts.SearchHalfWidthHz, eps));
    prominence_db = 0;
    if spectral_available
        prominence_db = localMeasureLineProminence( ...
            freq_axis_hz, spectral_power_db, bin_idx, sample_rate_hz, ...
            opts.ProminenceInnerHz, opts.ProminenceOuterHz);
    end
    line_prominence_db(idx) = prominence_db;
    candidate_scores(idx) = snr_db(bin_idx) + opts.ProminenceWeight * max(prominence_db, 0) - delta_penalty_db;
end
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

function [spectral_power_db, spectral_available] = localResolveSpectralPower(freq_axis_hz, opts)
spectral_power_db = zeros(size(freq_axis_hz));
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
    spectral_available = true;
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

function [nearest_raster_hz, off_raster_hz, candidate_centers_hz, candidate_source] = localResolveCandidateCenters(capture_center_hz, capture_tune_hz, opts)
raster_hz = localATSCRasterCentersHz();
candidate_centers_hz = [];
candidate_source = "";
nearest_raster_hz = NaN;
off_raster_hz = NaN;

explicit_center_hz = localRowVectorOrEmpty(opts.IlluminatorCenterFrequencyHz);
if ~isempty(explicit_center_hz)
    candidate_centers_hz = unique(explicit_center_hz, 'stable');
    candidate_source = "explicit_illuminator_center";
end

reference_center_hz = NaN;
if isfinite(capture_center_hz)
    reference_center_hz = capture_center_hz;
elseif isfinite(capture_tune_hz)
    reference_center_hz = capture_tune_hz - opts.LOOffsetHz;
end

if isfinite(reference_center_hz)
    [~, raster_idx] = min(abs(raster_hz - reference_center_hz));
    nearest_raster_hz = raster_hz(raster_idx);
    off_raster_hz = reference_center_hz - nearest_raster_hz;

    if isempty(candidate_centers_hz)
        [~, order] = sort(abs(raster_hz - reference_center_hz), 'ascend');
        keep_count = min(opts.MaxRasterCandidates, numel(order));
        candidate_centers_hz = raster_hz(order(1:keep_count));
        candidate_source = "nearest_atsc_raster";
    else
        nearest_delta_hz = []; %#ok<NASGU>
    end
end
end

function raster_hz = localATSCRasterCentersHz()
vhf_low_hz = [57, 63, 69, 79, 85] * 1e6;
vhf_high_hz = (177:6:213) * 1e6;
uhf_hz = (473:6:803) * 1e6;
raster_hz = [vhf_low_hz, vhf_high_hz, uhf_hz];
end

function wrapped_hz = localWrapToBaseband(freq_hz, sample_rate_hz)
wrapped_hz = mod(freq_hz + sample_rate_hz / 2, sample_rate_hz) - sample_rate_hz / 2;
end

function sample_rate_hz = localResolveSampleRateHz(freq_axis_hz, sample_rate_hz)
sample_rate_hz = localScalarOrNaN(sample_rate_hz);
if isfinite(sample_rate_hz)
    return
end

if numel(freq_axis_hz) < 2
    sample_rate_hz = NaN;
    return
end

freq_step_hz = median(diff(freq_axis_hz));
sample_rate_hz = freq_step_hz * numel(freq_axis_hz);
end

function value = localScalarOrNaN(value_in)
if isempty(value_in)
    value = NaN;
else
    value = double(value_in);
    value = value(1);
end
if ~isfinite(value)
    value = NaN;
end
end

function values = localRowVectorOrEmpty(values_in)
if isempty(values_in)
    values = [];
    return
end
values = double(values_in(:)).';
values = values(isfinite(values));
end

function candidate = localEmptyCandidate()
candidate = struct( ...
    'channel_center_hz', NaN, ...
    'expected_freq_hz', NaN, ...
    'measured_freq_hz', NaN, ...
    'measured_snr_db', -Inf, ...
    'coherence_snr_db', -Inf, ...
    'line_prominence_db', NaN, ...
    'psd_prominence_db', NaN, ...
    'combined_score', -Inf, ...
    'score', -Inf, ...
    'delta_freq_hz', NaN, ...
    'abs_delta_freq_hz', NaN, ...
    'is_mirrored', false, ...
    'orientation', "normal");
end

function selection = localAttachOrientationSummary(selection, candidates)
if isempty(candidates)
    return
end

mirror_mask = [candidates.is_mirrored];
nonmirror_mask = ~mirror_mask;

if any(nonmirror_mask)
    nonmirrored_candidates = candidates(nonmirror_mask);
    [selection.best_nonmirrored_score, idx] = max([nonmirrored_candidates.combined_score]);
    selection.best_nonmirrored_freq_hz = nonmirrored_candidates(idx).measured_freq_hz;
    selection.best_nonmirrored_candidate = nonmirrored_candidates(idx);
end

if any(mirror_mask)
    mirrored_candidates = candidates(mirror_mask);
    [selection.best_mirrored_score, idx] = max([mirrored_candidates.combined_score]);
    selection.best_mirrored_freq_hz = mirrored_candidates(idx).measured_freq_hz;
    selection.best_mirrored_candidate = mirrored_candidates(idx);
end

if isfinite(selection.best_mirrored_score) && isfinite(selection.best_nonmirrored_score)
    selection.mirrored_minus_nonmirrored_score = ...
        selection.best_mirrored_score - selection.best_nonmirrored_score;
end
end

function message = localBuildSelectionMessage(best_candidate, selection)
mirror_str = '';
if best_candidate.is_mirrored
    mirror_str = ', mirrored candidate';
end

orientation_str = '';
if isfinite(selection.mirrored_minus_nonmirrored_score)
    orientation_str = sprintf(', mirror-minus-normal score %.1f dB', ...
        selection.mirrored_minus_nonmirrored_score);
end

message = sprintf([ ...
    'ATSC candidate %.3f MHz (expected %.3f MHz, channel center %.3f MHz%s, ' ...
    'coherence %.1f dB, line prominence %.1f dB%s). Strongest line anywhere is %.3f MHz.'], ...
    best_candidate.measured_freq_hz / 1e6, ...
    best_candidate.expected_freq_hz / 1e6, ...
    best_candidate.channel_center_hz / 1e6, ...
    mirror_str, ...
    best_candidate.measured_snr_db, ...
    best_candidate.line_prominence_db, ...
    orientation_str, ...
    selection.global_peak_freq_hz / 1e6);
end

function orientation = localOrientationString(is_mirrored)
if is_mirrored
    orientation = "mirrored";
else
    orientation = "normal";
end
end
