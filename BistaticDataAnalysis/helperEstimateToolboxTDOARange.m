function [range_excess_m, estimate_info] = helperEstimateToolboxTDOARange( ...
    reference_block, surveillance_block, fs, prf, detection_doppler_hz, ...
    direct_path_delay_s, range_guess_m, varargin)
%HELPERESTIMATETOOLBOXTDOARANGE Estimate bistatic range excess with phased.TDOAEstimator.
%
% Plain-language goal:
%   The custom CAF already gives a coarse delay cell for each detection.
%   This helper asks MATLAB's built-in TDOA estimator to re-measure that
%   delay on the original time-domain block. We keep the existing Doppler
%   estimate and only replace the range-delay measurement, because this
%   stage is meant to evaluate the timing measurement in isolation.
%
% Why Doppler compensation is applied first:
%   A moving target rotates in phase from CPI to CPI. If those CPIs are
%   flattened into one long vector without correcting that phase ramp, the
%   target echo partly decorrelates and the delay peak weakens. Mixing the
%   surveillance block by the detected Doppler aligns the target phase
%   across slow time, so the TDOA estimator sees one coherent delayed copy
%   instead of a smeared one.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'reference_block', @(x) isnumeric(x) && ~isempty(x) && ismatrix(x));
addRequired(p, 'surveillance_block', @(x) isnumeric(x) && ~isempty(x) && ismatrix(x));
addRequired(p, 'fs', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'prf', @(x) isnumeric(x) && isscalar(x) && x > 0);
addRequired(p, 'detection_doppler_hz', @(x) isnumeric(x) && isscalar(x));
addRequired(p, 'direct_path_delay_s', @(x) isnumeric(x) && isscalar(x) && isfinite(x));
addRequired(p, 'range_guess_m', @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'SearchWindowSamples', 6, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'ApplyClutterMitigation', true, @islogical);
addParameter(p, 'ClutterAlignmentLagSamples', [], ...
    @(x) isempty(x) || (isnumeric(x) && isscalar(x) && isfinite(x)));
addParameter(p, 'TDOAEstimator', [], @(x) isempty(x) || isa(x, 'phased.TDOAEstimator'));
addParameter(p, 'Verbose', false, @islogical);
parse(p, reference_block, surveillance_block, fs, prf, detection_doppler_hz, ...
    direct_path_delay_s, range_guess_m, varargin{:});
opts = p.Results;

if ~isequal(size(reference_block), size(surveillance_block))
    error('helperEstimateToolboxTDOARange:sizeMismatch', ...
        'reference_block and surveillance_block must have the same size.');
end

surv_use = surveillance_block;
clutter_alignment_lag_samples = NaN;
if opts.ApplyClutterMitigation
    clutter_alignment_lag_samples = localResolveClutterAlignmentLagSamples( ...
        opts.ClutterAlignmentLagSamples, direct_path_delay_s, fs);
    surv_use = mitigateClutter( ...
        surveillance_block, reference_block, clutter_alignment_lag_samples, false);
elseif ~isempty(opts.ClutterAlignmentLagSamples)
    clutter_alignment_lag_samples = round(opts.ClutterAlignmentLagSamples);
end

t_slow = (0 : size(surv_use, 2) - 1) / prf;
dopp_comp = exp(-1j * 2 * pi * detection_doppler_hz * t_slow);
surv_comp = surv_use .* dopp_comp;

ref_vec = reference_block(:);
surv_vec = surv_comp(:);
signal_pair = zeros(numel(ref_vec), 1, 2, 'like', ref_vec);
signal_pair(:, :, 1) = ref_vec;
signal_pair(:, :, 2) = surv_vec;

[estimator] = localResolveEstimator(fs, opts.TDOAEstimator);
c = physconst('LightSpeed');
tau_guess_s = direct_path_delay_s + range_guess_m / c;
search_half_window_s = opts.SearchWindowSamples / fs;

tau_candidates_s = NaN(0, 1);
peak_response = NaN;
if localEstimatorOutputsResponse(estimator)
    [tau_primary_s, response_values, response_grid_s] = estimator(signal_pair);

    response_values = abs(response_values(:));
    response_grid_s = response_grid_s(:);
    search_mask = abs(response_grid_s - tau_guess_s) <= search_half_window_s;

    tau_selected_s = tau_primary_s;
    if any(search_mask)
        [peak_response, rel_idx] = max(response_values(search_mask));
        candidate_idx = find(search_mask);
        tau_selected_s = response_grid_s(candidate_idx(rel_idx));
    elseif ~isempty(response_values)
        [peak_response, peak_idx] = max(response_values);
        tau_selected_s = response_grid_s(peak_idx);
    end
else
    tau_candidates_s = estimator(signal_pair);
    tau_candidates_s = tau_candidates_s(:);
    tau_candidates_s = tau_candidates_s(isfinite(tau_candidates_s));
    if isempty(tau_candidates_s)
        tau_primary_s = NaN;
        tau_selected_s = NaN;
    else
        tau_primary_s = tau_candidates_s(1);
        [~, best_idx] = min(abs(tau_candidates_s - tau_guess_s));
        tau_selected_s = tau_candidates_s(best_idx);
    end
end

range_excess_m = c * (tau_selected_s - direct_path_delay_s);

estimate_info = struct( ...
    'tau_primary_s', tau_primary_s, ...
    'tau_selected_s', tau_selected_s, ...
    'tau_candidates_s', tau_candidates_s, ...
    'tau_guess_s', tau_guess_s, ...
    'direct_path_delay_s', direct_path_delay_s, ...
    'clutter_alignment_lag_samples', clutter_alignment_lag_samples, ...
    'search_half_window_s', search_half_window_s, ...
    'range_excess_m', range_excess_m, ...
    'peak_response', peak_response);

if opts.Verbose
    fprintf(['[helperEstimateToolboxTDOARange] fd=%+.1f Hz  guess=%.2f km  ' ...
        'estimate=%.2f km\n'], ...
        detection_doppler_hz, range_guess_m / 1e3, range_excess_m / 1e3);
end
end

function estimator = localResolveEstimator(fs, estimator_in)
if isempty(estimator_in)
    estimator = phased.TDOAEstimator( ...
        'SampleRate', fs, ...
        'NumEstimates', 1, ...
        'TDOAResponseOutputPort', true);
else
    estimator = estimator_in;
    if strcmpi(estimator.SampleRateSource, 'Property') && ...
            abs(estimator.SampleRate - fs) > max(1, 1e-9 * abs(fs))
        release(estimator);
        estimator.SampleRate = fs;
    end
end
end

function clutter_alignment_lag_samples = localResolveClutterAlignmentLagSamples( ...
    clutter_alignment_lag_samples_in, direct_path_delay_s, fs)
if isempty(clutter_alignment_lag_samples_in)
    clutter_alignment_lag_samples = round(direct_path_delay_s * fs);
else
    clutter_alignment_lag_samples = round(clutter_alignment_lag_samples_in);
end

if clutter_alignment_lag_samples < 0
    error('helperEstimateToolboxTDOARange:negativeClutterAlignmentLag', ...
        ['Clutter mitigation requires a nonnegative alignment lag. ' ...
         'Pass ClutterAlignmentLagSamples using the createRDM/mitigateClutter lag convention.']);
end
end

function tf = localEstimatorOutputsResponse(estimator)
tf = false;
if isprop(estimator, 'TDOAResponseOutputPort')
    tf = logical(estimator.TDOAResponseOutputPort);
end
end
