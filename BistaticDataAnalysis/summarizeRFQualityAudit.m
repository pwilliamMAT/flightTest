function audit = summarizeRFQualityAudit(precheck_results, varargin)
%SUMMARIZERFQUALITYAUDIT Summarize per-part direct-path prechecks into a session audit.
%
% Plain-language goal:
%   `runDirectPathPrecheck` tells you whether one slice of one radar file
%   looks healthy. For a real capture session, that is not enough. This
%   helper converts an array of those per-part checks into one auditable
%   scorecard that answers:
%     1. Is the reference channel consistently usable?
%     2. Is the direct path consistently observable?
%     3. Is clutter cancellation consistently working?
%     4. Is the session stable enough for aircraft detection or tracking?
%
% Syntax
%   audit = summarizeRFQualityAudit(precheck_results)
%   audit = summarizeRFQualityAudit(precheck_results, 'Goal', 'tracking_validation')
%
% Input
%   precheck_results  Struct array returned by runDirectPathPrecheck.
%
% Name-value options
%   'Goal'                   'aircraft_detection' (default) or
%                            'tracking_validation'
%   'RequiredPassFraction'   Override the per-category pass fraction.
%   'LagSpanMaxSamples'      Maximum allowed part-to-part lag spread.
%   'PilotFreqSpanMaxHz'     Maximum allowed pilot-frequency spread.
%   'Verbose'                Print the scorecard. Default: true.
%
% Output
%   audit   Struct containing:
%     .part_table
%     .summary
%     .assessment
%
% See also: runDirectPathPrecheck, runSessionRFQualityAudit.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'precheck_results', @(x) isstruct(x) && ~isempty(x));
addParameter(p, 'Goal', 'aircraft_detection', @(x) any(strcmpi(string(x), ["aircraft_detection", "tracking_validation"])));
addParameter(p, 'RequiredPassFraction', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x > 0 && x <= 1));
addParameter(p, 'LagSpanMaxSamples', 2, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'PilotFreqSpanMaxHz', 25e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'Verbose', true, @islogical);
parse(p, precheck_results, varargin{:});
opts = p.Results;

goal = lower(char(string(opts.Goal)));
required_pass_fraction = opts.RequiredPassFraction;
if isempty(required_pass_fraction)
    switch goal
        case 'tracking_validation'
            required_pass_fraction = 1.0;
        otherwise
            required_pass_fraction = 0.8;
    end
end

part_table = localBuildPartTable(precheck_results);
summary = localBuildSummary(part_table, required_pass_fraction, opts, goal);
assessment = localBuildAssessment(summary, required_pass_fraction, opts, goal);

audit = struct( ...
    'part_table', part_table, ...
    'summary', summary, ...
    'assessment', assessment);

if opts.Verbose
    fprintf('\n[summarizeRFQualityAudit] Goal ........... %s\n', goal);
    fprintf('[summarizeRFQualityAudit] Required pass .. %.0f%% of parts\n', 100 * required_pass_fraction);
    disp(part_table);
    fprintf('[summarizeRFQualityAudit] Summary:\n');
    disp(struct2table(rmfield(summary, 'session_id')));
    if ~isempty(assessment.notes)
        fprintf('[summarizeRFQualityAudit] Assessment:\n');
        for iNote = 1 : numel(assessment.notes)
            fprintf('  - %s\n', char(assessment.notes(iNote)));
        end
    end
end

end

function part_table = localBuildPartTable(precheck_results)
n_parts = numel(precheck_results);

session_id = strings(n_parts, 1);
part_index = zeros(n_parts, 1);
overall_pass = false(n_parts, 1);

level_dbfs = NaN(n_parts, 1);
level_pass = false(n_parts, 1);
pilot_snr_db = NaN(n_parts, 1);
pilot_pass = false(n_parts, 1);
pilot_freq_hz = NaN(n_parts, 1);
sfm_db = NaN(n_parts, 1);
sfm_pass = false(n_parts, 1);
pilot_mirrored = false(n_parts, 1);
header_center_off_raster_hz = NaN(n_parts, 1);

peak_lag_samples = NaN(n_parts, 1);
peak_to_median_db = NaN(n_parts, 1);
peak_to_second_db = NaN(n_parts, 1);
lag_pass = false(n_parts, 1);

before_margin_db = NaN(n_parts, 1);
suppression_db = NaN(n_parts, 1);
after_margin_db = NaN(n_parts, 1);
after_margin_max_db = NaN(n_parts, 1);
after_margin_pass = false(n_parts, 1);
after_at_noise_floor = false(n_parts, 1);
zero_doppler_pass = false(n_parts, 1);

for k = 1 : n_parts
    result = precheck_results(k);

    if isfield(result, 'source_info') && isstruct(result.source_info)
        if isfield(result.source_info, 'session_id')
            session_id(k) = string(result.source_info.session_id);
        end
        if isfield(result.source_info, 'part_index')
            part_index(k) = double(result.source_info.part_index);
        else
            part_index(k) = k;
        end
    else
        part_index(k) = k;
    end

    if isfield(result, 'overall_pass')
        overall_pass(k) = logical(result.overall_pass);
    end

    ref = localGetStructField(result, 'reference_quality');
    level_dbfs(k) = localGetNumericField(ref, 'level_dbfs', NaN);
    level_pass(k) = localGetLogicalField(ref, 'level_pass', false);
    pilot_snr_db(k) = localGetNumericField(ref, 'pilot_snr_db', NaN);
    pilot_pass(k) = localGetLogicalField(ref, 'pilot_pass', false);
    pilot_freq_hz(k) = localGetNumericField(ref, 'pilot_freq_hz', NaN);
    sfm_db(k) = localGetNumericField(ref, 'sfm_db', NaN);
    sfm_pass(k) = localGetLogicalField(ref, 'sfm_pass', false);
    pilot_mirrored(k) = localGetLogicalField(ref, 'pilot_is_mirrored', false);

    pilot_sel = localGetStructField(ref, 'pilot_selection');
    header_center_off_raster_hz(k) = abs(localGetNumericField(pilot_sel, 'header_center_off_raster_hz', NaN));

    lag = localGetStructField(result, 'cross_correlation');
    peak_lag_samples(k) = localGetNumericField(lag, 'peak_lag_samples', NaN);
    peak_to_median_db(k) = localGetNumericField(lag, 'peak_to_median_db', NaN);
    peak_to_second_db(k) = localGetNumericField(lag, 'peak_to_second_db', NaN);
    lag_pass(k) = localGetLogicalField(lag, 'pass', false);

    zd = localGetStructField(result, 'zero_doppler');
    before_margin_db(k) = localGetNumericField(zd, 'before_margin_db', NaN);
    suppression_db(k) = localGetNumericField(zd, 'suppression_db', NaN);
    after_margin_db(k) = localGetNumericField(zd, 'after_margin_db', NaN);
    after_margin_max_db(k) = localGetNumericField(zd, 'after_margin_max_db', NaN);
    after_margin_pass(k) = localGetLogicalField(zd, 'after_margin_pass', false);
    after_at_noise_floor(k) = localGetLogicalField(zd, 'after_at_noise_floor', false);
    zero_doppler_pass(k) = localGetLogicalField(zd, 'pass', false);
end

part_table = table( ...
    session_id, part_index, overall_pass, ...
    level_dbfs, level_pass, ...
    pilot_snr_db, pilot_pass, pilot_freq_hz, sfm_db, sfm_pass, ...
    pilot_mirrored, header_center_off_raster_hz, ...
    peak_lag_samples, peak_to_median_db, peak_to_second_db, lag_pass, ...
    before_margin_db, suppression_db, after_margin_db, after_margin_max_db, ...
    after_margin_pass, after_at_noise_floor, zero_doppler_pass);
end

function summary = localBuildSummary(part_table, required_pass_fraction, opts, goal)
summary = struct( ...
    'session_id', localResolveSessionID(part_table), ...
    'goal', string(goal), ...
    'required_pass_fraction', required_pass_fraction, ...
    'n_parts', height(part_table), ...
    'overall_pass_fraction', mean(part_table.overall_pass), ...
    'reference_pass_fraction', mean(part_table.level_pass & part_table.pilot_pass & part_table.sfm_pass), ...
    'level_pass_fraction', mean(part_table.level_pass), ...
    'pilot_pass_fraction', mean(part_table.pilot_pass), ...
    'sfm_pass_fraction', mean(part_table.sfm_pass), ...
    'lag_pass_fraction', mean(part_table.lag_pass), ...
    'zero_doppler_pass_fraction', mean(part_table.zero_doppler_pass), ...
    'median_level_dbfs', median(part_table.level_dbfs, 'omitnan'), ...
    'median_pilot_snr_db', median(part_table.pilot_snr_db, 'omitnan'), ...
    'median_sfm_db', median(part_table.sfm_db, 'omitnan'), ...
    'median_peak_to_median_db', median(part_table.peak_to_median_db, 'omitnan'), ...
    'median_peak_to_second_db', median(part_table.peak_to_second_db, 'omitnan'), ...
    'median_before_margin_db', median(part_table.before_margin_db, 'omitnan'), ...
    'median_suppression_db', median(part_table.suppression_db, 'omitnan'), ...
    'median_after_margin_db', median(part_table.after_margin_db, 'omitnan'), ...
    'after_margin_pass_fraction', mean(part_table.after_margin_pass), ...
    'after_margin_target_db', median(part_table.after_margin_max_db, 'omitnan'), ...
    'lag_span_samples', localFiniteSpan(part_table.peak_lag_samples), ...
    'pilot_freq_span_hz', localFiniteSpan(part_table.pilot_freq_hz), ...
    'any_pilot_mirrored', any(part_table.pilot_mirrored), ...
    'max_header_center_off_raster_hz', max(part_table.header_center_off_raster_hz, [], 'omitnan'));

if isempty(summary.max_header_center_off_raster_hz) || ~isfinite(summary.max_header_center_off_raster_hz)
    summary.max_header_center_off_raster_hz = NaN;
end

summary.reference_chain_ok = summary.reference_pass_fraction >= required_pass_fraction;
summary.direct_path_ok = summary.lag_pass_fraction >= required_pass_fraction;
summary.clutter_cancel_ok = summary.zero_doppler_pass_fraction >= required_pass_fraction;
summary.frequency_consistency_ok = ~summary.any_pilot_mirrored && ...
    (~isfinite(summary.max_header_center_off_raster_hz) || summary.max_header_center_off_raster_hz <= 50e3);
summary.session_stable_ok = ...
    (~isfinite(summary.lag_span_samples) || summary.lag_span_samples <= opts.LagSpanMaxSamples) && ...
    (~isfinite(summary.pilot_freq_span_hz) || summary.pilot_freq_span_hz <= opts.PilotFreqSpanMaxHz);
summary.sufficient_for_goal = summary.reference_chain_ok && summary.direct_path_ok && ...
    summary.clutter_cancel_ok && summary.frequency_consistency_ok && summary.session_stable_ok;
end

function assessment = localBuildAssessment(summary, required_pass_fraction, opts, goal)
notes = strings(0, 1);

if summary.reference_chain_ok
    notes(end + 1) = sprintf('Reference-chain checks pass on %.0f%% of parts.', 100 * summary.reference_pass_fraction);
else
    notes(end + 1) = sprintf( ...
        'Reference-chain checks pass on only %.0f%% of parts; target is %.0f%%.', ...
        100 * summary.reference_pass_fraction, 100 * required_pass_fraction);
end

if summary.direct_path_ok
    notes(end + 1) = sprintf('Direct-path lag dominance passes on %.0f%% of parts.', 100 * summary.lag_pass_fraction);
else
    notes(end + 1) = sprintf( ...
        'Direct-path lag dominance passes on only %.0f%% of parts; the direct path is not consistently isolated.', ...
        100 * summary.lag_pass_fraction);
end

if summary.clutter_cancel_ok
    notes(end + 1) = sprintf('Zero-Doppler suppression passes on %.0f%% of parts.', 100 * summary.zero_doppler_pass_fraction);
else
    notes(end + 1) = sprintf( ...
        'Zero-Doppler suppression passes on only %.0f%% of parts; ECA-C is not consistently driving the ridge down.', ...
        100 * summary.zero_doppler_pass_fraction);
end

if isfinite(summary.after_margin_target_db) && summary.after_margin_pass_fraction < required_pass_fraction
    notes(end + 1) = sprintf( ...
        ['Post-ECA residual ridge clears the <= %.1f dB-after-noise-floor bar on only %.0f%% of parts; ' ...
         'median residual ridge is %.1f dB above the floor.'], ...
        summary.after_margin_target_db, 100 * summary.after_margin_pass_fraction, summary.median_after_margin_db);
end

if summary.level_pass_fraction >= required_pass_fraction && summary.pilot_pass_fraction < required_pass_fraction
    notes(end + 1) = ['Reference ADC levels are healthy, but coherent pilot margin is not. ' ...
        'That points to insufficient direct-path coherence/SNR rather than gross clipping or underflow. ' ...
        'A stronger/better-aimed reference antenna or a reference-side LNA/preamplifier is a valid hardware adjustment.'];
end

if summary.any_pilot_mirrored
    notes(end + 1) = 'At least one part selected a mirrored ATSC-like pilot. Check spectral inversion or I/Q sign convention.';
end

if isfinite(summary.max_header_center_off_raster_hz) && summary.max_header_center_off_raster_hz > 50e3
    notes(end + 1) = sprintf( ...
        'Header center frequency is off the ATSC raster by as much as %.0f kHz. Confirm the intended illuminator center frequency.', ...
        summary.max_header_center_off_raster_hz / 1e3);
end

if isfinite(summary.lag_span_samples) && summary.lag_span_samples > opts.LagSpanMaxSamples
    notes(end + 1) = sprintf( ...
        'Direct-path lag varies by %.0f samples across parts; expected span is at most %.0f sample(s).', ...
        summary.lag_span_samples, opts.LagSpanMaxSamples);
end

if isfinite(summary.pilot_freq_span_hz) && summary.pilot_freq_span_hz > opts.PilotFreqSpanMaxHz
    notes(end + 1) = sprintf( ...
        'Selected pilot frequency varies by %.1f kHz across parts; expected span is at most %.1f kHz.', ...
        summary.pilot_freq_span_hz / 1e3, opts.PilotFreqSpanMaxHz / 1e3);
end

if summary.sufficient_for_goal
    notes(end + 1) = sprintf('Session appears sufficient for %s based on the RF prechecks.', goal);
else
    notes(end + 1) = sprintf('Session does not yet clear the RF sufficiency bar for %s.', goal);
end

assessment = struct( ...
    'reference_chain_ok', summary.reference_chain_ok, ...
    'direct_path_ok', summary.direct_path_ok, ...
    'clutter_cancel_ok', summary.clutter_cancel_ok, ...
    'frequency_consistency_ok', summary.frequency_consistency_ok, ...
    'session_stable_ok', summary.session_stable_ok, ...
    'sufficient_for_goal', summary.sufficient_for_goal, ...
    'notes', notes);
end

function session_id = localResolveSessionID(part_table)
valid_ids = unique(part_table.session_id(part_table.session_id ~= ""));
if isempty(valid_ids)
    session_id = "";
elseif isscalar(valid_ids)
    session_id = valid_ids;
else
    session_id = strjoin(valid_ids, ",");
end
end

function value = localFiniteSpan(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x) - min(x);
end
end

function value = localGetNumericField(source_struct, field_name, default_value)
value = default_value;
if isstruct(source_struct) && isfield(source_struct, field_name) && ...
        isnumeric(source_struct.(field_name)) && isscalar(source_struct.(field_name))
    value = double(source_struct.(field_name));
end
end

function value = localGetLogicalField(source_struct, field_name, default_value)
value = default_value;
if isstruct(source_struct) && isfield(source_struct, field_name) && ...
        ~isempty(source_struct.(field_name))
    value = logical(source_struct.(field_name));
end
end

function value = localGetStructField(source_struct, field_name)
value = struct();
if isstruct(source_struct) && isfield(source_struct, field_name) && ...
        isstruct(source_struct.(field_name))
    value = source_struct.(field_name);
end
end
