function results = checkRefQuality(reference_cube, config)
% checkRefQuality  Three-check ATSC reference-channel quality audit.
%
%   results = checkRefQuality(reference_cube, config)
%
%   Designed for 8-VSB ATSC passive-radar references captured at baseband.
%   ATSC data carriers are deliberately spectrally flat (randomised MPEG-2
%   data), so metrics based on PSD mean / noise-floor ratio give false
%   warnings even for a perfect reference.  Three appropriate checks:
%
%   CHECK 1 — ADC level (dBFS)
%     Is the signal using a healthy fraction of the ADC dynamic range?
%     Auto-detects int16 scale (values >> 2) vs. normalised float.
%       < -30 dBFS: too weak — quantisation noise dominates, ECA will fail
%       -30 to -3 dBFS: healthy range
%       > -3 dBFS: clipping — nonlinear distortion, ECA will fail
%
%   CHECK 2 — ATSC pilot-tone coherence
%     8-VSB contains a continuous coherent CW pilot at the channel lower
%     edge + 0.31 MHz.  Data carriers are incoherent (random phase per CPI).
%     The pilot is detected by comparing COHERENT integration
%     (|mean_complex_FFT|^2) to INCOHERENT power (mean(|FFT|^2)):
%
%       coherence_ratio = |mean_k FFT[n,k]|^2 / mean_k(|FFT[n,k]|^2)
%         → 1           at the pilot bin      (coherent source)
%         → 1/N_slow    elsewhere             (incoherent / random)
%
%     Pilot coherence SNR = 10*log10(max_ratio × N_slow).
%     Good ATSC: ~10*log10(N_slow) ≈ 33 dB for N_slow=2000.
%     No signal:  ~0–4 dB.    Threshold: 10 dB.
%
%   CHECK 3 — Spectral flatness (multipath fading)
%     ATSC data carriers produce SFM ≈ 0 dB (flat broadband noise). Deep
%     frequency-domain nulls from selective multipath push SFM well below
%     0 dB and corrupt the per-bin ECA channel estimate.  Threshold: -15 dB.
%
%   Inputs:
%     reference_cube   [N_fast × N_slow] complex — reference channel data
%     config           struct with optional fields:
%                        .fs                     sample rate Hz (default 5e6)
%                        .ref_level_min_dbfs     (default -30)
%                        .ref_level_max_dbfs     (default -3)
%                        .ref_pilot_snr_threshold dB (default 10)
%                        .ref_sfm_threshold_db   (default -15)
%                        .ref_snr_threshold_db   legacy alias for pilot threshold
%                        .capture_center_frequency_hz  header center
%                        .capture_tune_frequency_hz    actual SDR tune
%                        .capture_lo_offset_hz         metadata LO offset
%                        .session_manifest_center_frequency_hz
%                        .session_manifest_lo_offset_hz
%                        .illuminator_center_frequency_hz optional ATSC
%                        .pilot_search_half_width_hz   search half-width
%
%   Outputs:
%     results   struct with fields:
%       .level_dbfs          ADC level in dBFS
%       .pilot_snr_db        pilot coherence SNR in dB
%       .pilot_freq_hz       frequency of the selected ATSC-consistent
%                            coherent component (Hz)
%       .sfm_db              spectral flatness in dB  (0 = flat)
%       .level_pass / .pilot_pass / .sfm_pass / .pass
%       .snr_db / .snr_pass  legacy aliases → pilot_snr_db / pilot_pass
%       .message             one-line summary string

% --- Defaults -----------------------------------------------------------
if ~isfield(config, 'fs'),                    config.fs                    = 5e6;  end
if ~isfield(config, 'ref_level_min_dbfs'),    config.ref_level_min_dbfs    = -30;  end
if ~isfield(config, 'ref_level_max_dbfs'),    config.ref_level_max_dbfs    = -3;   end
if ~isfield(config, 'ref_pilot_snr_threshold'), config.ref_pilot_snr_threshold = 10; end
if ~isfield(config, 'ref_sfm_threshold_db'),  config.ref_sfm_threshold_db  = -15; end
if ~isfield(config, 'pilot_search_half_width_hz'), config.pilot_search_half_width_hz = 300e3; end
% Legacy alias: ref_snr_threshold_db → pilot threshold
if isfield(config, 'ref_snr_threshold_db')
    config.ref_pilot_snr_threshold = config.ref_snr_threshold_db;
end

verbose = isfield(config, 'verbose') && config.verbose;
if verbose, fprintf('Checking reference channel quality...\n'); end

ref_flat = double(reference_cube(:));
N_slow   = size(reference_cube, 2);

%% CHECK 1: ADC level -------------------------------------------------------
% Auto-detect scale: int16 values reach ~32767; normalised float stays in ±1.
max_abs_val = max(abs(ref_flat));
if max_abs_val > 2.0
    adc_full_scale = 32768;   % int16
else
    adc_full_scale = 1.0;     % normalised float
end
level_dbfs  = 10 * log10(mean(abs(ref_flat).^2) / adc_full_scale^2);
level_pass  = (level_dbfs >= config.ref_level_min_dbfs) && ...
              (level_dbfs <= config.ref_level_max_dbfs);

%% CHECK 2: ATSC pilot-tone coherence ---------------------------------------
% FFT along fast-time (range) dimension for every CPI.
N_fft_coh = 2^nextpow2(size(reference_cube, 1));
FFT_cube  = fft(double(reference_cube), N_fft_coh, 1);  % [N_fft × N_slow]

mean_coh_fft   = mean(FFT_cube, 2);                      % [N_fft × 1] complex
mean_incoh_pwr = mean(abs(FFT_cube).^2, 2);              % [N_fft × 1] real

coherence_ratio = abs(mean_coh_fft).^2 ./ max(mean_incoh_pwr, eps);
coherence_snr_db = 10 * log10(coherence_ratio * N_slow + eps);
freq_axis = (-N_fft_coh/2 : N_fft_coh/2 - 1).' * (config.fs / N_fft_coh);
coherence_snr_db = fftshift(coherence_snr_db);
spectral_power_db = fftshift(10 * log10(mean_incoh_pwr + eps));

capture_center_hz = NaN;
if isfield(config, 'capture_center_frequency_hz') && ~isempty(config.capture_center_frequency_hz)
    capture_center_hz = double(config.capture_center_frequency_hz);
elseif isfield(config, 'fc') && ~isempty(config.fc)
    capture_center_hz = double(config.fc);
end

lo_offset_hz = 0;
if isfield(config, 'capture_lo_offset_hz') && ~isempty(config.capture_lo_offset_hz)
    lo_offset_hz = double(config.capture_lo_offset_hz);
elseif isfield(config, 'lo_offset_hz') && ~isempty(config.lo_offset_hz)
    lo_offset_hz = double(config.lo_offset_hz);
elseif isfield(config, 'LOOffset') && ~isempty(config.LOOffset)
    lo_offset_hz = double(config.LOOffset);
end

illuminator_center_hz = [];
if isfield(config, 'illuminator_center_frequency_hz') && ~isempty(config.illuminator_center_frequency_hz)
    illuminator_center_hz = double(config.illuminator_center_frequency_hz);
end

session_manifest_center_hz = [];
if isfield(config, 'session_manifest_center_frequency_hz') && ...
        ~isempty(config.session_manifest_center_frequency_hz)
    session_manifest_center_hz = double(config.session_manifest_center_frequency_hz);
end

session_manifest_lo_offset_hz = [];
if isfield(config, 'session_manifest_lo_offset_hz') && ...
        ~isempty(config.session_manifest_lo_offset_hz)
    session_manifest_lo_offset_hz = double(config.session_manifest_lo_offset_hz);
end

frequency_context = helperResolveCaptureFrequencyContext( ...
    'RequestedIlluminatorCenterHz', illuminator_center_hz, ...
    'HeaderCenterFrequencyHz', capture_center_hz, ...
    'HeaderLOOffsetHz', lo_offset_hz, ...
    'SessionManifestCenterFrequencyHz', session_manifest_center_hz, ...
    'SessionManifestLOOffsetHz', session_manifest_lo_offset_hz);

pilot_selection = helperSelectATSCPilotCandidate( ...
    freq_axis, coherence_snr_db, ...
    'SampleRateHz', config.fs, ...
    'CaptureCenterFrequencyHz', capture_center_hz, ...
    'CaptureTuneFrequencyHz', frequency_context.capture_tune_frequency_hz, ...
    'LOOffsetHz', frequency_context.capture_lo_offset_hz, ...
    'IlluminatorCenterFrequencyHz', frequency_context.illuminator_center_frequency_hz, ...
    'SpectralPowerDB', spectral_power_db, ...
    'SearchHalfWidthHz', config.pilot_search_half_width_hz);

pilot_snr_db = pilot_selection.selected_snr_db;
pilot_freq_hz = pilot_selection.selected_freq_hz;

% Pilot SNR: for ATSC ≈ 10*log10(N_slow); for noise ≈ 0–4 dB.

pilot_pass = pilot_snr_db >= config.ref_pilot_snr_threshold;

%% CHECK 3: Spectral flatness (multipath fading detector) -------------------
% Use the incoherent-average PSD already computed above.
PSD     = mean_incoh_pwr;
PSD_pos = max(PSD, eps);
sfm_db  = 10 * log10(exp(mean(log(PSD_pos))) / mean(PSD_pos));
sfm_pass = sfm_db >= config.ref_sfm_threshold_db;

%% Build results struct -----------------------------------------------------
results.level_dbfs    = level_dbfs;
results.pilot_snr_db  = pilot_snr_db;
results.pilot_freq_hz = pilot_freq_hz;
results.pilot_selection = pilot_selection;
results.pilot_expected_freq_hz = pilot_selection.selected_expected_freq_hz;
results.pilot_channel_center_hz = pilot_selection.selected_channel_center_hz;
results.pilot_is_mirrored = pilot_selection.selected_is_mirrored;
results.pilot_detection_mode = char(pilot_selection.selected_source);
results.strongest_coherent_freq_hz = pilot_selection.global_peak_freq_hz;
results.strongest_coherent_snr_db = pilot_selection.global_peak_snr_db;
results.frequency_context = frequency_context;
results.sfm_db        = sfm_db;
results.level_pass    = level_pass;
results.pilot_pass    = pilot_pass;
results.sfm_pass      = sfm_pass;
results.pass          = level_pass && pilot_pass && sfm_pass;
% Legacy aliases
results.snr_db   = pilot_snr_db;
results.snr_pass = pilot_pass;

level_str = sprintf('ADC level = %.1f dBFS (range %.0f to %.0f) [%s]', ...
    level_dbfs, config.ref_level_min_dbfs, config.ref_level_max_dbfs, passstr(level_pass));
pilot_str = sprintf('Pilot coherence SNR = %.1f dB @ %.3f MHz (%s, threshold %.0f dB) [%s]', ...
    pilot_snr_db, pilot_freq_hz/1e6, localPilotModeString(pilot_selection), ...
    config.ref_pilot_snr_threshold, passstr(pilot_pass));
sfm_str   = sprintf('SFM = %.1f dB (threshold %.0f dB) [%s]', ...
    sfm_db, config.ref_sfm_threshold_db, passstr(sfm_pass));
results.message = sprintf('%s  |  %s  |  %s', level_str, pilot_str, sfm_str);

if verbose
    fprintf('  %s\n', level_str);
    fprintf('  %s\n', pilot_str);
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
        fprintf(['  WARNING: No ATSC pilot tone detected (%.1f dB < %.0f dB).\n' ...
                 '    Reference antenna may not be aimed at the ATSC tower,\n' ...
                 '    or the ATSC channel centre frequency does not match config.fc.\n'], ...
                 pilot_snr_db, config.ref_pilot_snr_threshold);
        if level_pass
            fprintf(['    Total reference power can still look acceptable while the coherent pilot remains weak.\n' ...
                     '    For a small or unamplified omni reference, a better-aimed reference path or a low-noise amplifier\n' ...
                     '    on the reference channel is a valid hardware adjustment.\n']);
        end
        if isfinite(pilot_selection.header_center_off_raster_hz) && abs(pilot_selection.header_center_off_raster_hz) > 50e3
            fprintf('    Capture header center %.3f MHz is %.3f MHz from nearest ATSC center %.3f MHz.\n', ...
                pilot_selection.capture_center_frequency_hz / 1e6, ...
                pilot_selection.header_center_off_raster_hz / 1e6, ...
                pilot_selection.header_center_nearest_atsc_hz / 1e6);
        end
        if ~isempty(results.frequency_context.notes)
            fprintf('    Frequency context: %s\n', results.frequency_context.message);
        end
    end
    if ~sfm_pass
        fprintf(['  WARNING: SFM = %.1f dB — deep spectral nulls detected.\n' ...
                 '    Frequency-selective multipath on reference path corrupts\n' ...
                 '    per-bin ECA channel estimates and produces a non-Rayleigh\n' ...
                 '    noise floor.  Consider a higher-gain directional antenna.\n'], sfm_db);
    end
else
    fprintf('  Reference channel quality: PASS\n');
end

end % checkRefQuality

%% ── Local helper ──────────────────────────────────────────────────────────
function s = passstr(tf)
if tf; s = 'PASS'; else; s = 'WARN'; end
end

function txt = localPilotModeString(pilot_selection)
if strcmp(pilot_selection.selected_source, "atsc_geometry")
    txt = 'ATSC candidate';
    if pilot_selection.selected_is_mirrored
        txt = 'ATSC mirrored candidate';
    end
else
    txt = 'strongest coherent line';
end
end

