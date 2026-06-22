%% test_rfQualityAudit.m
% Synthetic coverage for the session-level RF quality audit.

clear; clc;

% Regression for the session wrapper's part-result accumulation.
cell_results = cell(1, 3);
for k = 1 : 3
    tmp = localMakeResult();
    tmp.source_info.session_id = "wrapper_regression";
    tmp.source_info.part_index = k;
    cell_results{k} = tmp;
end

wrapper_style_results = [cell_results{:}];
assert(numel(wrapper_style_results) == 3);
assert(wrapper_style_results(3).source_info.part_index == 3);

good_results = repmat(localMakeResult(), 1, 3);
for k = 1 : 3
    good_results(k).source_info.session_id = "good_session";
    good_results(k).source_info.part_index = k;
    good_results(k).reference_quality.level_dbfs = -18 + 0.2 * k;
    good_results(k).reference_quality.pilot_snr_db = 18 + k;
    good_results(k).reference_quality.sfm_db = -4 - 0.5 * k;
    good_results(k).reference_quality.pilot_freq_hz = -2.800e6 + 800 * k;
    good_results(k).cross_correlation.peak_lag_samples = 3;
    good_results(k).cross_correlation.peak_to_median_db = 24 + k;
    good_results(k).cross_correlation.peak_to_second_db = 11 + 0.5 * k;
    good_results(k).zero_doppler.before_margin_db = 32 + k;
    good_results(k).zero_doppler.suppression_db = 31 + k;
    good_results(k).zero_doppler.after_margin_db = 2 + 0.5 * k;
end

good_audit = summarizeRFQualityAudit(good_results, 'Verbose', false);
assert(height(good_audit.part_table) == 3);
assert(good_audit.summary.reference_chain_ok);
assert(good_audit.summary.direct_path_ok);
assert(good_audit.summary.clutter_cancel_ok);
assert(good_audit.summary.after_margin_pass_fraction == 1);
assert(good_audit.summary.session_stable_ok);
assert(good_audit.assessment.sufficient_for_goal);

bad_results = repmat(localMakeResult(), 1, 3);
for k = 1 : 3
    bad_results(k).source_info.session_id = "bad_session";
    bad_results(k).source_info.part_index = k;
    bad_results(k).overall_pass = false;
    bad_results(k).reference_quality.level_dbfs = -35;
    bad_results(k).reference_quality.level_pass = false;
    bad_results(k).reference_quality.pilot_snr_db = 3;
    bad_results(k).reference_quality.pilot_pass = false;
    bad_results(k).reference_quality.sfm_db = -22;
    bad_results(k).reference_quality.sfm_pass = false;
    bad_results(k).reference_quality.pilot_freq_hz = (-2.8e6) + 80e3 * k;
    bad_results(k).reference_quality.pilot_is_mirrored = (k == 2);
    bad_results(k).reference_quality.pilot_selection.header_center_off_raster_hz = 120e3;
    bad_results(k).cross_correlation.peak_lag_samples = 2 + 4 * (k - 1);
    bad_results(k).cross_correlation.peak_to_median_db = 7;
    bad_results(k).cross_correlation.peak_to_second_db = 1.5;
    bad_results(k).cross_correlation.pass = false;
    bad_results(k).zero_doppler.before_margin_db = 8;
    bad_results(k).zero_doppler.suppression_db = 10;
    bad_results(k).zero_doppler.after_margin_db = 12;
    bad_results(k).zero_doppler.after_at_noise_floor = false;
    bad_results(k).zero_doppler.pass = false;
end

bad_audit = summarizeRFQualityAudit(bad_results, ...
    'Goal', 'tracking_validation', ...
    'Verbose', false);
assert(~bad_audit.summary.reference_chain_ok);
assert(~bad_audit.summary.direct_path_ok);
assert(~bad_audit.summary.clutter_cancel_ok);
assert(~bad_audit.summary.frequency_consistency_ok);
assert(~bad_audit.summary.session_stable_ok);
assert(~bad_audit.assessment.sufficient_for_goal);

residual_results = repmat(localMakeResult(), 1, 3);
for k = 1 : 3
    residual_results(k).source_info.session_id = "residual_session";
    residual_results(k).source_info.part_index = k;
    residual_results(k).reference_quality.level_dbfs = -21;
    residual_results(k).reference_quality.level_pass = true;
    residual_results(k).reference_quality.pilot_snr_db = 8.5;
    residual_results(k).reference_quality.pilot_pass = false;
    residual_results(k).zero_doppler.suppression_db = 35;
    residual_results(k).zero_doppler.after_margin_db = 28;
    residual_results(k).zero_doppler.after_margin_pass = false;
    residual_results(k).zero_doppler.after_at_noise_floor = false;
    residual_results(k).zero_doppler.pass = false;
end

residual_audit = summarizeRFQualityAudit(residual_results, 'Verbose', false);
assert(residual_audit.summary.after_margin_pass_fraction == 0);
assert(any(contains(residual_audit.assessment.notes, "residual ridge")));
assert(any(contains(residual_audit.assessment.notes, "LNA/preamplifier")));

fprintf('test_rfQualityAudit passed.\n');

function result = localMakeResult()
result = struct( ...
    'source_info', struct( ...
        'session_id', "", ...
        'part_index', 1), ...
    'overall_pass', true, ...
    'reference_quality', struct( ...
        'level_dbfs', -20, ...
        'level_pass', true, ...
        'pilot_snr_db', 15, ...
        'pilot_pass', true, ...
        'pilot_freq_hz', -2.8e6, ...
        'sfm_db', -5, ...
        'sfm_pass', true, ...
        'pilot_is_mirrored', false, ...
        'pilot_selection', struct( ...
            'header_center_off_raster_hz', 0)), ...
    'cross_correlation', struct( ...
        'peak_lag_samples', 3, ...
        'peak_to_median_db', 20, ...
        'peak_to_second_db', 8, ...
        'pass', true), ...
    'zero_doppler', struct( ...
        'before_margin_db', 28, ...
        'suppression_db', 31, ...
        'after_margin_db', 3, ...
        'after_margin_max_db', 15, ...
        'after_margin_pass', true, ...
        'after_at_noise_floor', true, ...
        'pass', true));
end
