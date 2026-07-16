function results = checkRefQuality(reference_cube, config)
%CHECKREFQUALITY Three-check ATSC reference-channel quality audit.
%
%   results = checkRefQuality(reference_cube, config)
%
% Plain-language goal:
% A good passive-radar reference should use a healthy fraction of the ADC,
% contain the ATSC pilot at the expected transmitted location in the
% spectrum, and avoid deep frequency-selective nulls. The pilot decision
% is now PSD-first: a narrow spectral line near the expected ATSC pilot is
% the gating metric. The older FFT-bin coherence metric is still reported,
% but only as a legacy engineering diagnostic.
%
% Inputs:
%   reference_cube   [N_fast x N_slow] complex reference-channel slice
%   config           Optional fields:
%                      .fs
%                      .reference_channel
%                      .ref_level_min_dbfs
%                      .ref_level_max_dbfs
%                      .ref_pilot_prominence_threshold_db
%                      .ref_pilot_warn_prominence_threshold_db
%                      .ref_pilot_freq_error_threshold_hz
%                      .ref_pilot_freq_error_warn_hz
%                      .ref_sfm_threshold_db
%                      .pilot_search_half_width_locked_hz
%                      .pilot_search_half_width_fallback_hz
%                      .capture_center_frequency_hz
%                      .capture_tune_frequency_hz
%                      .capture_lo_offset_hz
%                      .session_manifest_center_frequency_hz
%                      .session_manifest_lo_offset_hz
%                      .illuminator_center_frequency_hz
%
% Outputs:
%   results   Struct with reference level, PSD-based pilot evidence,
%             advisory pilot stability, spectral flatness, and legacy
%             coherence diagnostics.

if nargin < 2 || isempty(config)
    config = struct();
end

if ~isfield(config, 'fs')
    config.fs = 5e6;
end
if ~isfield(config, 'ref_level_min_dbfs')
    config.ref_level_min_dbfs = -30;
end
if ~isfield(config, 'ref_level_max_dbfs')
    config.ref_level_max_dbfs = -3;
end
if ~isfield(config, 'ref_pilot_prominence_threshold_db')
    if isfield(config, 'ref_pilot_snr_threshold')
        config.ref_pilot_prominence_threshold_db = config.ref_pilot_snr_threshold;
    else
        config.ref_pilot_prominence_threshold_db = 6;
    end
end
if ~isfield(config, 'ref_pilot_warn_prominence_threshold_db')
    config.ref_pilot_warn_prominence_threshold_db = 3;
end
if ~isfield(config, 'ref_pilot_freq_error_threshold_hz')
    config.ref_pilot_freq_error_threshold_hz = 25e3;
end
if ~isfield(config, 'ref_pilot_freq_error_warn_hz')
    config.ref_pilot_freq_error_warn_hz = 75e3;
end
if ~isfield(config, 'ref_sfm_threshold_db')
    config.ref_sfm_threshold_db = -15;
end
if ~isfield(config, 'pilot_search_half_width_locked_hz')
    config.pilot_search_half_width_locked_hz = 75e3;
end
if ~isfield(config, 'pilot_search_half_width_fallback_hz')
    if isfield(config, 'pilot_search_half_width_hz')
        config.pilot_search_half_width_fallback_hz = config.pilot_search_half_width_hz;
    else
        config.pilot_search_half_width_fallback_hz = 300e3;
    end
end

if isfield(config, 'ref_snr_threshold_db')
    config.ref_pilot_prominence_threshold_db = config.ref_snr_threshold_db;
end

verbose = isfield(config, 'verbose') && config.verbose;
if verbose
    fprintf('Checking reference channel quality...\n');
end

reference_cube = double(reference_cube);
reference_channel = localResolveReferenceChannel(reference_cube, config);
reference_flat = reference_channel(:);

%% CHECK 1: ADC level
max_abs_value = max(abs(reference_flat), [], 'omitnan');
if max_abs_value > 2.0
    adc_full_scale = 32768;
else
    adc_full_scale = 1.0;
end

level_dbfs = 10 * log10(mean(abs(reference_flat) .^ 2) / adc_full_scale ^ 2);
level_pass = (level_dbfs >= config.ref_level_min_dbfs) && ...
    (level_dbfs <= config.ref_level_max_dbfs);

%% CHECK 2: PSD-first ATSC pilot evidence
pilot_evidence = helperMeasureATSCPilotEvidence( ...
    reference_cube, reference_channel, config.fs, ...
    'CaptureCenterFrequencyHz', localNumericField(config, 'capture_center_frequency_hz', []), ...
    'CaptureTuneFrequencyHz', localNumericField(config, 'capture_tune_frequency_hz', []), ...
    'LOOffsetHz', localNumericField(config, 'capture_lo_offset_hz', 0), ...
    'SessionManifestCenterFrequencyHz', localNumericField(config, 'session_manifest_center_frequency_hz', []), ...
    'SessionManifestLOOffsetHz', localNumericField(config, 'session_manifest_lo_offset_hz', []), ...
    'IlluminatorCenterFrequencyHz', localNumericField(config, 'illuminator_center_frequency_hz', []), ...
    'LockedSearchHalfWidthHz', config.pilot_search_half_width_locked_hz, ...
    'FallbackSearchHalfWidthHz', config.pilot_search_half_width_fallback_hz, ...
    'PilotPresenceProminencePassDB', config.ref_pilot_prominence_threshold_db, ...
    'PilotPresenceProminenceWarnDB', config.ref_pilot_warn_prominence_threshold_db, ...
    'PilotPresenceFreqErrorPassHz', config.ref_pilot_freq_error_threshold_hz, ...
    'PilotPresenceFreqErrorWarnHz', config.ref_pilot_freq_error_warn_hz);

pilot_prominence_db = pilot_evidence.selected_peak_prominence_db;
pilot_peak_power_db = pilot_evidence.selected_peak_power_db;
pilot_freq_hz = pilot_evidence.selected_pilot_freq_hz;
pilot_freq_error_hz = pilot_evidence.pilot_freq_error_hz;
pilot_pass = pilot_evidence.pilot_presence_pass;
pilot_warn = pilot_evidence.pilot_presence_warn;
pilot_fail = pilot_evidence.pilot_presence_fail;

%% CHECK 3: Spectral flatness
psd_positive = max(pilot_evidence.legacy_power_linear, eps);
sfm_db = 10 * log10(exp(mean(log(psd_positive))) / mean(psd_positive));
sfm_pass = sfm_db >= config.ref_sfm_threshold_db;

%% Build results struct
results = struct();
results.level_dbfs = level_dbfs;
results.level_pass = level_pass;

results.pilot_evidence = pilot_evidence;
results.pilot_prominence_db = pilot_prominence_db;
results.pilot_peak_power_db = pilot_peak_power_db;
results.pilot_freq_hz = pilot_freq_hz;
results.pilot_freq_error_hz = pilot_freq_error_hz;
results.pilot_presence_state = char(pilot_evidence.pilot_presence_state);
results.pilot_presence_warn = pilot_warn;
results.pilot_presence_fail = pilot_fail;
results.pilot_pass = pilot_pass;
results.pilot_threshold_db = config.ref_pilot_prominence_threshold_db;
results.pilot_prominence_threshold_db = config.ref_pilot_prominence_threshold_db;
results.pilot_freq_error_threshold_hz = config.ref_pilot_freq_error_threshold_hz;
results.pilot_candidate_table = pilot_evidence.diagnostic_table;
results.pilot_selection = pilot_evidence;
results.pilot_expected_freq_hz = pilot_evidence.expected_normal_freq_hz;
results.pilot_channel_center_hz = pilot_evidence.primary_channel_center_hz;
results.pilot_is_mirrored = pilot_evidence.selected_candidate.is_mirrored;
results.pilot_detection_mode = char(pilot_evidence.selection_mode);
results.pilot_selection_mode = char(pilot_evidence.selection_mode);
results.pilot_psd_visibility_message = char(pilot_evidence.peak_evidence_message);
results.residual_offset_mean_hz = pilot_evidence.residual_offset_mean_hz;
results.residual_offset_std_hz = pilot_evidence.residual_offset_std_hz;
results.corrected_concentration_db = pilot_evidence.corrected_concentration_db;
results.stability_message = char(pilot_evidence.stability_message);
results.stability_available = pilot_evidence.stability_available;
results.legacy_fft_bin_coherence_db = pilot_evidence.legacy_coherence_snr_db;
results.legacy_coherence_snr_db = pilot_evidence.legacy_coherence_snr_db;
results.strongest_coherent_freq_hz = pilot_evidence.legacy_global_peak_freq_hz;
results.strongest_coherent_snr_db = pilot_evidence.legacy_global_peak_snr_db;
results.frequency_context = pilot_evidence.frequency_context;

results.sfm_db = sfm_db;
results.sfm_pass = sfm_pass;
results.pass = level_pass && pilot_pass && sfm_pass;

% Legacy aliases preserved for older callers.
results.pilot_snr_db = pilot_prominence_db;
results.snr_db = pilot_prominence_db;
results.snr_pass = pilot_pass;

level_str = sprintf( ...
    'ADC level = %.1f dBFS (range %.0f to %.0f) [%s]', ...
    level_dbfs, config.ref_level_min_dbfs, config.ref_level_max_dbfs, ...
    localPassString(level_pass));
pilot_str = sprintf( ...
    'Pilot evidence %s: %.1f dB prominence @ %.3f MHz (error %.1f kHz)', ...
    upper(char(pilot_evidence.pilot_presence_state)), ...
    pilot_prominence_db, pilot_freq_hz / 1e6, abs(pilot_freq_error_hz) / 1e3);
stability_str = sprintf('Stability advisory: %s', char(pilot_evidence.stability_message));
legacy_str = sprintf('Legacy FFT-bin coherence = %.1f dB', pilot_evidence.legacy_coherence_snr_db);
sfm_str = sprintf( ...
    'SFM = %.1f dB (threshold %.0f dB) [%s]', ...
    sfm_db, config.ref_sfm_threshold_db, localPassString(sfm_pass));
results.message = sprintf('%s  |  %s  |  %s  |  %s  |  %s', ...
    level_str, pilot_str, stability_str, legacy_str, sfm_str);

if verbose
    fprintf('  %s\n', level_str);
    fprintf('  %s\n', pilot_str);
    fprintf('  %s\n', stability_str);
    fprintf('  %s\n', legacy_str);
    fprintf('  %s\n', sfm_str);
end

if ~results.pass
    if ~level_pass
        if level_dbfs < config.ref_level_min_dbfs
            fprintf(['  WARNING: Reference signal too weak (%.1f dBFS < %.0f dBFS).\n' ...
                     '    Increase RX gain or check antenna/cable connection.\n'], ...
                     level_dbfs, config.ref_level_min_dbfs);
        else
            fprintf(['  WARNING: Reference signal clipping (%.1f dBFS > %.0f dBFS).\n' ...
                     '    Reduce RX gain to prevent ADC saturation.\n'], ...
                     level_dbfs, config.ref_level_max_dbfs);
        end
    end

    if ~pilot_pass
        fprintf(['  WARNING: ATSC pilot evidence is %s.\n' ...
                 '    Prominence %.1f dB, |frequency error| %.1f kHz.\n' ...
                 '    Pass thresholds require prominence >= %.1f dB and |error| <= %.1f kHz.\n'], ...
                 upper(char(pilot_evidence.pilot_presence_state)), ...
                 pilot_prominence_db, abs(pilot_freq_error_hz) / 1e3, ...
                 config.ref_pilot_prominence_threshold_db, ...
                 config.ref_pilot_freq_error_threshold_hz / 1e3);
        fprintf('    %s\n', char(pilot_evidence.peak_evidence_message));
        if level_pass
            fprintf(['    Total reference power can still look acceptable while the transmitted pilot remains weak or misplaced.\n' ...
                     '    A better-aimed reference path or a reference-side LNA remains a valid hardware adjustment.\n']);
        end
        if isfinite(pilot_evidence.frequency_context.header_off_raster_hz) && ...
                abs(pilot_evidence.frequency_context.header_off_raster_hz) > 50e3
            fprintf('    Header center is %.1f kHz off the nearest ATSC raster.\n', ...
                abs(pilot_evidence.frequency_context.header_off_raster_hz) / 1e3);
        end
        if pilot_evidence.best_mirrored_candidate.peak_found && ...
                isfinite(pilot_evidence.best_mirrored_candidate.peak_prominence_db) && ...
                (~isfinite(pilot_prominence_db) || ...
                pilot_evidence.best_mirrored_candidate.peak_prominence_db > pilot_prominence_db)
            fprintf(['    Mirrored-side PSD evidence is stronger (%.1f dB at %.3f MHz), but it is diagnostic-only under the normal-side policy.\n' ...
                     '    Check spectral inversion or I/Q sign convention if that mirrored line looks more plausible.\n'], ...
                     pilot_evidence.best_mirrored_candidate.peak_prominence_db, ...
                     pilot_evidence.best_mirrored_candidate.measured_freq_hz / 1e6);
        end
        if ~isempty(results.frequency_context.notes)
            fprintf('    Frequency context: %s\n', results.frequency_context.message);
        end
    end

    if ~sfm_pass
        fprintf(['  WARNING: SFM = %.1f dB; deep spectral nulls detected.\n' ...
                 '    Frequency-selective multipath on the reference path can corrupt\n' ...
                 '    per-bin ECA channel estimates and raise the clutter floor.\n'], sfm_db);
    end
else
    fprintf('  Reference channel quality: PASS\n');
end
end

function reference_channel = localResolveReferenceChannel(reference_cube, config)
if isfield(config, 'reference_channel') && ~isempty(config.reference_channel)
    reference_channel = double(config.reference_channel(:));
else
    reference_channel = double(reference_cube(:));
end

required_length = numel(reference_cube);
if numel(reference_channel) < required_length
    reference_channel = double(reference_cube(:));
else
    reference_channel = reference_channel(1:required_length);
end
end

function value = localNumericField(source_struct, field_name, default_value)
value = default_value;
if ~isstruct(source_struct) || ~isfield(source_struct, field_name)
    return
end

candidate_value = source_struct.(field_name);
if isempty(candidate_value)
    return
end

candidate_value = double(candidate_value);
if ~isscalar(candidate_value) || ~isfinite(candidate_value)
    return
end

value = candidate_value;
end

function txt = localPassString(tf)
if tf
    txt = 'PASS';
else
    txt = 'WARN';
end
end
