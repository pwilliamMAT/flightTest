function evaluation = helperTriggerEvaluateGeometryField( ...
    latest_positions_enu_m, velocities_enu_mps, config, assets, varargin)
%HELPERTRIGGEREVALUATEGEOMETRYFIELD Evaluate trigger geometry for points.
%
% Plain-language goal:
%   The runtime trigger and the preview map must use the same geometry and
%   proxy-scoring math. This helper evaluates one or more ENU points,
%   optionally with kinematics, and returns the gates, scores, and best
%   start offset used by both paths.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'latest_positions_enu_m', @isnumeric);
addRequired(p, 'velocities_enu_mps', @isnumeric);
addRequired(p, 'config', @isstruct);
addRequired(p, 'assets', @isstruct);
addParameter(p, 'FixAge_s', [], @isnumeric);
addParameter(p, 'FixCount', [], @isnumeric);
addParameter(p, 'ApplyFreshnessGate', true, @islogical);
parse(p, latest_positions_enu_m, velocities_enu_mps, config, assets, varargin{:});
opts = p.Results;

latest_positions_enu_m = localNormalizeVector3Matrix(latest_positions_enu_m);
point_count = size(latest_positions_enu_m, 2);
velocities_enu_mps = localNormalizeVector3Matrix(velocities_enu_mps, point_count);

window_offsets_s = double(config.WindowOffsetGrid_s(:).');
if isempty(window_offsets_s)
    window_offsets_s = 0.0;
end

geometry = helperDeriveTxRxGeometry(config.TxLLA, config.RxLLA);
evaluation = localEmptyEvaluation(point_count, numel(window_offsets_s), geometry);
evaluation.window_offsets_s = window_offsets_s;

if point_count == 0
    return
end

fix_age_s = localExpandVector(opts.FixAge_s, point_count, 0.0);
fix_count = localExpandVector(opts.FixCount, point_count, config.MinimumTrackFixCount);

tx_enu_m = geometry.tx_enu_m(:);
latest_positions_flat = latest_positions_enu_m;
[receiver_range_m, receiver_angles_deg] = rangeangle(latest_positions_flat, [0; 0; 0]);
latest_azimuth_deg = localToCompassAzimuth(receiver_angles_deg(1, :)).';
latest_elevation_deg = receiver_angles_deg(2, :).';
latest_altitude_m = config.RxLLA(3) + latest_positions_flat(3, :).';

latest_positions_pages = reshape(latest_positions_flat, 3, point_count, 1);
velocity_pages = reshape(velocities_enu_mps, 3, point_count, 1);
offset_pages = reshape(window_offsets_s, 1, 1, []);
predicted_positions = latest_positions_pages + velocity_pages .* offset_pages;
predicted_positions_flat = reshape(predicted_positions, 3, []);

[predicted_ranges_flat, predicted_angles_flat] = rangeangle(predicted_positions_flat, [0; 0; 0]);
predicted_ranges_m = reshape(predicted_ranges_flat, point_count, []);
predicted_azimuth_deg = reshape(localToCompassAzimuth(predicted_angles_flat(1, :)), point_count, []);
predicted_elevation_deg = reshape(predicted_angles_flat(2, :), point_count, []);
predicted_altitudes_m = reshape(config.RxLLA(3) + predicted_positions_flat(3, :), point_count, []);

predicted_tx_vectors = tx_enu_m - predicted_positions_flat;
predicted_rx_vectors = -predicted_positions_flat;
predicted_bistatic_angle_flat = real(acosd( ...
    sum(predicted_tx_vectors .* predicted_rx_vectors, 1) ./ ...
    max(vecnorm(predicted_tx_vectors, 2, 1) .* vecnorm(predicted_rx_vectors, 2, 1), eps)));
predicted_bistatic_angle_deg = reshape(predicted_bistatic_angle_flat, point_count, []);
predicted_bistatic_excess_m = reshape( ...
    vecnorm(predicted_tx_vectors, 2, 1) + predicted_ranges_flat - norm(tx_enu_m), ...
    point_count, []);

latest_corridor_error_deg = wrapTo180(latest_azimuth_deg - config.CorridorAzimuthCenter_deg);
latest_boresight_az_error_deg = wrapTo180(latest_azimuth_deg - config.SurveillanceBoresightAzimuth_deg);
latest_boresight_el_error_deg = latest_elevation_deg - config.SurveillanceBoresightElevation_deg;

corridor_errors_deg = wrapTo180(predicted_azimuth_deg - config.CorridorAzimuthCenter_deg);
boresight_az_errors_deg = wrapTo180(predicted_azimuth_deg - config.SurveillanceBoresightAzimuth_deg);
boresight_el_errors_deg = predicted_elevation_deg - config.SurveillanceBoresightElevation_deg;

range_center_m = mean(config.ReceiverRangeBand_m);
range_halfspan_m = diff(config.ReceiverRangeBand_m) ./ 2.0;
coverage_range_m = assets.proxy_prior.coverage_range_m;
window_max_s = max(window_offsets_s);

corridor_score = localClamp01(1.0 - abs(corridor_errors_deg) ./ max(config.CorridorAzimuthHalfWidth_deg, eps));
boresight_az_score = localClamp01(1.0 - abs(boresight_az_errors_deg) ./ max(config.BoresightAzimuthHalfWidth_deg, eps));
boresight_el_score = localClamp01(1.0 - abs(boresight_el_errors_deg) ./ max(config.BoresightElevationHalfWidth_deg, eps));
boresight_score = 0.7 .* boresight_az_score + 0.3 .* boresight_el_score;
range_score = localClamp01(1.0 - abs(predicted_ranges_m - range_center_m) ./ max(range_halfspan_m, eps));
bistatic_score = localClamp01(cosd(predicted_bistatic_angle_deg ./ 2.0));

if window_max_s > 0
    time_to_window_score = 1.0 - window_offsets_s ./ window_max_s;
else
    time_to_window_score = ones(size(window_offsets_s));
end
time_to_window_score = repmat(time_to_window_score, point_count, 1);

geometry_sequence = ...
    0.30 .* corridor_score + ...
    0.30 .* boresight_score + ...
    0.20 .* range_score + ...
    0.20 .* bistatic_score;
geometry_sequence = 0.85 .* geometry_sequence + 0.15 .* time_to_window_score;
[geometry_score, best_idx] = max(geometry_sequence, [], 2);
best_linear_idx = sub2ind(size(geometry_sequence), (1:point_count).', best_idx);

best_predicted_range_m = predicted_ranges_m(best_linear_idx);
best_bistatic_angle_deg = predicted_bistatic_angle_deg(best_linear_idx);
best_bistatic_excess_m = predicted_bistatic_excess_m(best_linear_idx);
predicted_start_offset_s = window_offsets_s(best_idx).';

rf_range_support = localClamp01( ...
    1.0 - max(best_predicted_range_m - coverage_range_m, 0.0) ./ max(coverage_range_m, eps));
rf_bistatic_support = localClamp01( ...
    1.0 - max(best_bistatic_excess_m, 0.0) ./ max(2.0 .* coverage_range_m, eps));
rf_raw_score = min(1.0, max(0.05, mean([rf_range_support, rf_bistatic_support], 2) .* assets.proxy_prior.rf_chain_scale));
rf_proxy_score = 0.60 + 0.40 .* rf_raw_score;
trigger_score = geometry_score .* rf_proxy_score;

proxy_pd = NaN(point_count, 1);
if isfinite(config.ReferenceChainPenalty_dB)
    proxy_margin_db = 20.0 .* log10(max(trigger_score, 1e-6)) - config.ReferenceChainPenalty_dB;
    proxy_pd = 1.0 ./ (1.0 + exp(-(proxy_margin_db + 12.0) ./ 3.0));
end

altitude_gate_pass = latest_altitude_m >= config.AltitudeBand_m(1) & ...
    latest_altitude_m <= config.AltitudeBand_m(2);
range_gate_pass = receiver_range_m(:) >= config.ReceiverRangeBand_m(1) & ...
    receiver_range_m(:) <= config.ReceiverRangeBand_m(2);
corridor_gate_pass = abs(latest_corridor_error_deg) <= config.CorridorAzimuthHalfWidth_deg;
boresight_gate_pass = abs(latest_boresight_az_error_deg) <= config.BoresightAzimuthHalfWidth_deg & ...
    abs(latest_boresight_el_error_deg) <= config.BoresightElevationHalfWidth_deg;
geometry_gate_pass = altitude_gate_pass & range_gate_pass & corridor_gate_pass & boresight_gate_pass;

if opts.ApplyFreshnessGate
    freshness_gate_pass = fix_age_s <= config.MaxFixAge_s & fix_count >= config.MinimumTrackFixCount;
else
    freshness_gate_pass = true(point_count, 1);
end

hard_gate_pass = geometry_gate_pass & freshness_gate_pass;
qualified = hard_gate_pass & trigger_score >= config.QualifiedTriggerScore;

evaluation.latest_positions_enu_m = latest_positions_flat.';
evaluation.velocity_enu_mps = velocities_enu_mps.';
evaluation.latest_receiver_range_m = receiver_range_m(:);
evaluation.latest_azimuth_deg = latest_azimuth_deg;
evaluation.latest_elevation_deg = latest_elevation_deg;
evaluation.latest_altitude_m = latest_altitude_m;
evaluation.latest_corridor_error_deg = latest_corridor_error_deg;
evaluation.latest_boresight_az_error_deg = latest_boresight_az_error_deg;
evaluation.latest_boresight_el_error_deg = latest_boresight_el_error_deg;
evaluation.fix_age_s = fix_age_s;
evaluation.fix_count = fix_count;
evaluation.predicted_ranges_m = predicted_ranges_m;
evaluation.predicted_azimuth_deg = predicted_azimuth_deg;
evaluation.predicted_elevation_deg = predicted_elevation_deg;
evaluation.predicted_altitudes_m = predicted_altitudes_m;
evaluation.predicted_bistatic_angle_deg = predicted_bistatic_angle_deg;
evaluation.predicted_bistatic_excess_m = predicted_bistatic_excess_m;
evaluation.corridor_score = corridor_score;
evaluation.boresight_score = boresight_score;
evaluation.range_score = range_score;
evaluation.bistatic_score = bistatic_score;
evaluation.geometry_sequence = geometry_sequence;
evaluation.geometry_score = geometry_score;
evaluation.best_window_index = best_idx;
evaluation.predicted_start_offset_s = predicted_start_offset_s;
evaluation.best_predicted_range_m = best_predicted_range_m;
evaluation.best_bistatic_angle_deg = best_bistatic_angle_deg;
evaluation.best_bistatic_excess_m = best_bistatic_excess_m;
evaluation.rf_raw_score = rf_raw_score;
evaluation.rf_proxy_score = rf_proxy_score;
evaluation.trigger_score = trigger_score;
evaluation.proxy_pd = proxy_pd;
evaluation.altitude_gate_pass = altitude_gate_pass;
evaluation.range_gate_pass = range_gate_pass;
evaluation.corridor_gate_pass = corridor_gate_pass;
evaluation.boresight_gate_pass = boresight_gate_pass;
evaluation.geometry_gate_pass = geometry_gate_pass;
evaluation.freshness_gate_pass = freshness_gate_pass;
evaluation.hard_gate_pass = hard_gate_pass;
evaluation.qualified = qualified;
evaluation.proxy_only = ~isfinite(config.ReferenceChainPenalty_dB);

end

function evaluation = localEmptyEvaluation(point_count, offset_count, geometry)
evaluation = struct( ...
    'geometry', geometry, ...
    'window_offsets_s', zeros(1, offset_count), ...
    'latest_positions_enu_m', zeros(point_count, 3), ...
    'velocity_enu_mps', zeros(point_count, 3), ...
    'latest_receiver_range_m', zeros(point_count, 1), ...
    'latest_azimuth_deg', zeros(point_count, 1), ...
    'latest_elevation_deg', zeros(point_count, 1), ...
    'latest_altitude_m', zeros(point_count, 1), ...
    'latest_corridor_error_deg', zeros(point_count, 1), ...
    'latest_boresight_az_error_deg', zeros(point_count, 1), ...
    'latest_boresight_el_error_deg', zeros(point_count, 1), ...
    'fix_age_s', zeros(point_count, 1), ...
    'fix_count', zeros(point_count, 1), ...
    'predicted_ranges_m', zeros(point_count, offset_count), ...
    'predicted_azimuth_deg', zeros(point_count, offset_count), ...
    'predicted_elevation_deg', zeros(point_count, offset_count), ...
    'predicted_altitudes_m', zeros(point_count, offset_count), ...
    'predicted_bistatic_angle_deg', zeros(point_count, offset_count), ...
    'predicted_bistatic_excess_m', zeros(point_count, offset_count), ...
    'corridor_score', zeros(point_count, offset_count), ...
    'boresight_score', zeros(point_count, offset_count), ...
    'range_score', zeros(point_count, offset_count), ...
    'bistatic_score', zeros(point_count, offset_count), ...
    'geometry_sequence', zeros(point_count, offset_count), ...
    'geometry_score', zeros(point_count, 1), ...
    'best_window_index', ones(point_count, 1), ...
    'predicted_start_offset_s', zeros(point_count, 1), ...
    'best_predicted_range_m', zeros(point_count, 1), ...
    'best_bistatic_angle_deg', zeros(point_count, 1), ...
    'best_bistatic_excess_m', zeros(point_count, 1), ...
    'rf_raw_score', zeros(point_count, 1), ...
    'rf_proxy_score', zeros(point_count, 1), ...
    'trigger_score', zeros(point_count, 1), ...
    'proxy_pd', NaN(point_count, 1), ...
    'altitude_gate_pass', false(point_count, 1), ...
    'range_gate_pass', false(point_count, 1), ...
    'corridor_gate_pass', false(point_count, 1), ...
    'boresight_gate_pass', false(point_count, 1), ...
    'geometry_gate_pass', false(point_count, 1), ...
    'freshness_gate_pass', false(point_count, 1), ...
    'hard_gate_pass', false(point_count, 1), ...
    'qualified', false(point_count, 1), ...
    'proxy_only', true);
end

function matrix_out = localNormalizeVector3Matrix(matrix_in, expected_count)
if nargin < 2
    expected_count = [];
end

if isempty(matrix_in)
    if isempty(expected_count)
        matrix_out = zeros(3, 0);
    else
        matrix_out = zeros(3, expected_count);
    end
    return
end

matrix_in = double(matrix_in);
if size(matrix_in, 1) == 3
    matrix_out = matrix_in;
elseif size(matrix_in, 2) == 3
    matrix_out = matrix_in.';
else
    error('helperTriggerEvaluateGeometryField:badVectorShape', ...
        'Expected a 3xN or Nx3 array.');
end

if ~isempty(expected_count) && size(matrix_out, 2) ~= expected_count
    error('helperTriggerEvaluateGeometryField:countMismatch', ...
        'Vector count mismatch between positions and velocities.');
end
end

function values_out = localExpandVector(values_in, point_count, default_value)
if isempty(values_in)
    values_out = repmat(double(default_value), point_count, 1);
    return
end

values_out = double(values_in(:));
if isscalar(values_out)
    values_out = repmat(values_out, point_count, 1);
elseif numel(values_out) ~= point_count
    error('helperTriggerEvaluateGeometryField:vectorLengthMismatch', ...
        'Expected either a scalar or one value per point.');
end
end

function azimuth_compass_deg = localToCompassAzimuth(azimuth_rangeangle_deg)
azimuth_compass_deg = mod(90.0 - azimuth_rangeangle_deg, 360.0);
end

function values_out = localClamp01(values_in)
values_out = max(0.0, min(1.0, values_in));
end
