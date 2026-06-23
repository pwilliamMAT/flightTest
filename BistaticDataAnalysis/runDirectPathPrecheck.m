function results = runDirectPathPrecheck(source, varargin)
%RUNDIRECTPATHPRECHECK Fast pre-analysis health check for the direct path.
%
%  results = runDirectPathPrecheck(source)
%
%  Plain-language goal:
%  Before spending minutes on the full passive-radar pipeline, confirm that
%  the capture contains a usable direct path. A good capture should show:
%    (a) a reference channel with ATSC-like occupied spectrum and a strong,
%        coherent pilot tone,
%    (b) one dominant correlation peak between surveillance and reference,
%        which means the direct path is easy to identify in lag, and
%    (c) a strong zero-Doppler ridge before ECA-C that is clearly reduced
%        and left close enough to the noise floor after clutter mitigation.
%
%  The function reads only a short slice from one radar file (default 1 s)
%  so it stays fast even when the full session is a long continuous capture.
%
%  SOURCE may be either:
%    - a packaged session ID such as "20260616T090717", or
%    - a direct path to one `.bb` radar file.
%
%  Example:
%    results = runDirectPathPrecheck("20260616T090717", ...
%        'SliceDurationS', 1.0, ...
%        'SwapChannels', false);
%
%  See also:
%    loadIQData, checkRefQuality, createRDM, mitigateClutter

repo_root = fileparts(fileparts(mfilename('fullpath')));

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'source', @(x) ischar(x) || isstring(x));
addParameter(p, 'DatasetRoot', fullfile(repo_root, 'captures'), @(x) ischar(x) || isstring(x));
addParameter(p, 'SessionFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'ManifestPath', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PartIndex', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1 && mod(x, 1) == 0);
addParameter(p, 'SliceDurationS', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CPIDurationS', 0.5e-3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'IlluminatorCenterFrequencyHz', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'PilotSearchHalfWidthHz', 300e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'SwapChannels', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'MaxLagSamples', 500, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'LagCheckCPIs', 32, @(x) isnumeric(x) && isscalar(x) && x >= 1);
addParameter(p, 'CrossCorrelationPeakMinDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CrossCorrelationIsolationMinDB', 6, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'NearRangeLimitM', 5e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'NoiseRegionRangeM', [130e3, 150e3], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'NoiseRegionDopplerHz', [200, 1000], @(x) isnumeric(x) && numel(x) == 2);
addParameter(p, 'DirectPathBeforeMarginMinDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ZeroDopplerSuppressionMinDB', 30, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'ZeroDopplerAfterMarginMaxDB', 15, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'on', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', false, @(x) islogical(x) && isscalar(x));
parse(p, source, varargin{:});
opts = p.Results;

source_info = helperResolveDirectPathPrecheckSource( ...
    opts.source, ...
    'DatasetRoot', opts.DatasetRoot, ...
    'SessionFolder', opts.SessionFolder, ...
    'ManifestPath', opts.ManifestPath, ...
    'PartIndex', opts.PartIndex, ...
    'Verbose', opts.Verbose);

header_reader = comm.BasebandFileReader(char(source_info.radar_file), 'SamplesPerFrame', 1);
header_info = info(header_reader);
file_meta = header_reader.Metadata;
fs = header_reader.SampleRate;
fc = header_reader.CenterFrequency;
release(header_reader);

lo_offset_hz = localGetNumericMetadataField(file_meta, 'LOOffset', 0);
capture_tune_hz = fc + lo_offset_hz;

requested_samples = max(1, round(opts.SliceDurationS * fs));
available_samples = header_info.NumSamplesInData;
samples_to_read = min(requested_samples, available_samples);
samples_per_cpi = round(opts.CPIDurationS * fs);
if samples_to_read < samples_per_cpi
    error('runDirectPathPrecheck:insufficientSlice', ...
        ['SliceDurationS=%.6f s only provides %d sample(s), but one CPI ' ...
         'needs %d sample(s). Increase SliceDurationS or reduce CPIDurationS.'], ...
        opts.SliceDurationS, samples_to_read, samples_per_cpi);
end

fprintf('[runDirectPathPrecheck] Source ......... %s\n', char(source_info.radar_file));
if strlength(source_info.session_id) > 0
    fprintf('[runDirectPathPrecheck] Session ......... %s  (part %d)\n', ...
        source_info.session_id, source_info.part_index);
end
fprintf('[runDirectPathPrecheck] Header ......... Fs=%.3f MSps  Fc=%.1f MHz  Samples=%d\n', ...
    fs / 1e6, fc / 1e6, available_samples);
fprintf('[runDirectPathPrecheck] Frequency ...... Header Fc=%.3f MHz  |  LO=%.3f MHz  |  SDR tune=%.3f MHz\n', ...
    fc / 1e6, lo_offset_hz / 1e6, capture_tune_hz / 1e6);
fprintf('[runDirectPathPrecheck] Precheck slice .. %.3f s requested  ->  %.3f s loaded\n', ...
    opts.SliceDurationS, samples_to_read / fs);

[reference_channel, ~, reference_cube, surveillance_cube] = loadIQData( ...
    char(source_info.radar_file), ...
    samples_to_read, ...
    opts.CPIDurationS, ...
    fs, ...
    struct('swap_channels', opts.SwapChannels, 'verbose', opts.Verbose));

n_fast = size(reference_cube, 1);
n_slow = size(reference_cube, 2);
slice_samples_used = n_fast * n_slow;
slice_duration_used_s = slice_samples_used / fs;
prf = 1 / opts.CPIDurationS;

if n_slow < 16
    warning('runDirectPathPrecheck:shortSlowTime', ...
        ['Only %d CPI(s) are available in the selected slice. ' ...
         'Pilot coherence and zero-Doppler checks may be noisy.'], n_slow);
end

ref_config = struct( ...
    'fs', fs, ...
    'capture_center_frequency_hz', fc, ...
    'capture_tune_frequency_hz', capture_tune_hz, ...
    'capture_lo_offset_hz', lo_offset_hz, ...
    'illuminator_center_frequency_hz', opts.IlluminatorCenterFrequencyHz, ...
    'ref_level_min_dbfs', -30, ...
    'ref_level_max_dbfs', -3, ...
    'ref_pilot_snr_threshold', 10, ...
    'ref_sfm_threshold_db', -15, ...
    'pilot_search_half_width_hz', opts.PilotSearchHalfWidthHz, ...
    'verbose', opts.Verbose);

if isfield(source_info, 'session_manifest_center_frequency_hz')
    ref_config.session_manifest_center_frequency_hz = ...
        source_info.session_manifest_center_frequency_hz;
end
if isfield(source_info, 'session_manifest_lo_offset_hz')
    ref_config.session_manifest_lo_offset_hz = ...
        source_info.session_manifest_lo_offset_hz;
end

reference_quality = checkRefQuality(reference_cube, ref_config);
reference_quality.level_min_dbfs = ref_config.ref_level_min_dbfs;
reference_quality.level_max_dbfs = ref_config.ref_level_max_dbfs;
reference_quality.pilot_threshold_db = ref_config.ref_pilot_snr_threshold;
reference_quality.sfm_threshold_db = ref_config.ref_sfm_threshold_db;
reference_profile = helperMeasurePilotCoherenceProfile( ...
    reference_cube, reference_channel, fs, ...
    'CaptureCenterFrequencyHz', fc, ...
    'CaptureTuneFrequencyHz', reference_quality.frequency_context.capture_tune_frequency_hz, ...
    'LOOffsetHz', reference_quality.frequency_context.capture_lo_offset_hz, ...
    'SessionManifestCenterFrequencyHz', localGetSourceInfoFrequency(source_info, 'session_manifest_center_frequency_hz'), ...
    'SessionManifestLOOffsetHz', localGetSourceInfoFrequency(source_info, 'session_manifest_lo_offset_hz'), ...
    'IlluminatorCenterFrequencyHz', reference_quality.frequency_context.illuminator_center_frequency_hz, ...
    'PilotSearchHalfWidthHz', opts.PilotSearchHalfWidthHz);

cross_correlation = helperMeasureCrossCorrelationPeak( ...
    surveillance_cube, reference_cube, fs, ...
    'MaxLagSamples', opts.MaxLagSamples, ...
    'MaxCPIs', opts.LagCheckCPIs, ...
    'PeakMinDB', opts.CrossCorrelationPeakMinDB, ...
    'IsolationMinDB', opts.CrossCorrelationIsolationMinDB);

zero_doppler = helperMeasureZeroDopplerSuppression( ...
    surveillance_cube, reference_cube, fs, prf, ...
    'NearRangeLimitM', opts.NearRangeLimitM, ...
    'NoiseRegionRangeM', opts.NoiseRegionRangeM, ...
    'NoiseRegionDopplerHz', opts.NoiseRegionDopplerHz, ...
    'BeforeMarginMinDB', opts.DirectPathBeforeMarginMinDB, ...
    'SuppressionMinDB', opts.ZeroDopplerSuppressionMinDB, ...
    'AfterMarginMaxDB', opts.ZeroDopplerAfterMarginMaxDB, ...
    'Verbose', opts.Verbose);

figure_handles = struct('reference', [], 'cross_correlation', [], 'zero_doppler', []);
if opts.PlotFigures
    figure_handles.reference = localPlotReferenceFigure( ...
        source_info, reference_quality, reference_profile, fc, opts);
    figure_handles.cross_correlation = localPlotCrossCorrelationFigure( ...
        source_info, cross_correlation, opts);
    figure_handles.zero_doppler = localPlotZeroDopplerFigure( ...
        source_info, zero_doppler, opts);
end

overall_pass = reference_quality.pass && cross_correlation.pass && zero_doppler.pass;
recommendations = localBuildRecommendations(reference_quality, cross_correlation, zero_doppler);

results = struct( ...
    'source_info', source_info, ...
    'metadata', struct( ...
        'fs_hz', fs, ...
        'fc_hz', fc, ...
        'lo_offset_hz', lo_offset_hz, ...
        'capture_tune_hz', capture_tune_hz, ...
        'illuminator_center_hz', reference_quality.frequency_context.illuminator_center_frequency_hz, ...
        'frequency_context', reference_quality.frequency_context, ...
        'header_metadata', file_meta, ...
        'requested_slice_duration_s', opts.SliceDurationS, ...
        'requested_samples', requested_samples, ...
        'available_samples', available_samples, ...
        'slice_samples_used', slice_samples_used, ...
        'slice_duration_used_s', slice_duration_used_s, ...
        'cpi_duration_s', opts.CPIDurationS, ...
        'prf_hz', prf, ...
        'n_fast', n_fast, ...
        'n_slow', n_slow, ...
        'swap_channels', opts.SwapChannels), ...
    'reference_quality', reference_quality, ...
    'reference_profile', reference_profile, ...
    'cross_correlation', cross_correlation, ...
    'zero_doppler', zero_doppler, ...
    'overall_pass', overall_pass, ...
    'recommendations', {recommendations}, ...
    'figure_handles', figure_handles);

fprintf('[runDirectPathPrecheck] (a) Reference ..... %s\n', reference_quality.message);
fprintf('[runDirectPathPrecheck] Frequency trust . %s\n', reference_quality.frequency_context.message);
fprintf('[runDirectPathPrecheck] Frequency note .. %s\n', reference_profile.pilot_selection.message);
fprintf('[runDirectPathPrecheck] (b) Lag peak ...... %s\n', cross_correlation.message);
fprintf('[runDirectPathPrecheck] (c) ECA-C ridge ... %s\n', zero_doppler.message);
fprintf('[runDirectPathPrecheck] Overall .......... %s\n', localPassString(overall_pass));
if ~isempty(recommendations)
    fprintf('[runDirectPathPrecheck] Follow-up .......\n');
    for k = 1:numel(recommendations)
        fprintf('  - %s\n', recommendations{k});
    end
end
end

function fig = localPlotReferenceFigure(source_info, reference_quality, reference_profile, fc, opts)
fig = figure( ...
    'Name', 'Direct-Path Precheck: Reference Quality', ...
    'NumberTitle', 'off', ...
    'Visible', opts.FigureVisibility);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
pilot_selection = reference_profile.pilot_selection;
capture_center_hz = reference_quality.frequency_context.capture_center_frequency_hz;
if ~isfinite(capture_center_hz)
    capture_center_hz = fc;
end

ax1 = nexttile(tlo);
plot(ax1, reference_profile.psd_freq_axis_hz / 1e6, reference_profile.psd_db_hz, 'k', 'LineWidth', 1.1);
hold(ax1, 'on');
if isfinite(reference_profile.strongest_coherent_freq_hz)
    xl = xline(ax1, reference_profile.strongest_coherent_freq_hz / 1e6, ':', 'Strongest coherent');
    xl.Color = [0.35, 0.35, 0.35];
end
if isfinite(pilot_selection.selected_expected_freq_hz)
    xline(ax1, pilot_selection.selected_expected_freq_hz / 1e6, ':g', 'Expected ATSC');
end
xline(ax1, reference_profile.pilot_freq_hz / 1e6, '--r', 'Selected pilot');
grid(ax1, 'on');
xlabel(ax1, 'Baseband frequency (MHz)');
ylabel(ax1, 'PSD (dB/Hz)');
title(ax1, 'Reference Spectrum');

ax2 = nexttile(tlo);
plot(ax2, reference_profile.coherence_freq_axis_hz / 1e6, reference_profile.coherence_snr_db, ...
    'b', 'LineWidth', 1.1);
hold(ax2, 'on');
if isfinite(reference_profile.strongest_coherent_freq_hz)
    xl = xline(ax2, reference_profile.strongest_coherent_freq_hz / 1e6, ':', 'Strongest coherent');
    xl.Color = [0.35, 0.35, 0.35];
end
if isfinite(pilot_selection.selected_expected_freq_hz)
    xline(ax2, pilot_selection.selected_expected_freq_hz / 1e6, ':g', 'Expected ATSC');
end
xline(ax2, reference_profile.pilot_freq_hz / 1e6, '--r', 'Selected pilot');
yline(ax2, reference_quality.pilot_threshold_db, ':k', 'Threshold');
grid(ax2, 'on');
xlabel(ax2, 'Baseband frequency (MHz)');
ylabel(ax2, 'Pilot coherence SNR (dB)');
title(ax2, 'Coherent Pilot Diagnostic');

sgtitle(tlo, sprintf([ ...
    '%s  |  %s  |  Capture Fc=%.3f MHz  |  Tune=%.3f MHz  |  Selected %.3f MHz  |  ' ...
    'Level %.1f dBFS  |  SFM %.1f dB'], ...
    localPassString(reference_quality.pass), ...
    localSourceLabel(source_info), ...
    capture_center_hz / 1e6, ...
    pilot_selection.capture_tune_frequency_hz / 1e6, ...
    reference_profile.pilot_freq_hz / 1e6, ...
    reference_quality.level_dbfs, ...
    reference_quality.sfm_db));
end

function fig = localPlotCrossCorrelationFigure(source_info, cross_correlation, opts)
fig = figure( ...
    'Name', 'Direct-Path Precheck: Cross-Correlation', ...
    'NumberTitle', 'off', ...
    'Visible', opts.FigureVisibility);
plot(cross_correlation.lags_us, cross_correlation.magnitude_db_rel, ...
    'LineWidth', 1.2, 'Color', [0.12, 0.47, 0.71]);
grid on;
hold on;
xline(cross_correlation.peak_lag_us, '--r', 'Peak lag');
xlabel('Lag (\mus)');
ylabel('Magnitude relative to peak (dB)');
title(sprintf([ ...
    '%s  |  %s  |  Peak %+d samples (%.3f us)  |  ' ...
    'Peak-median %.1f dB  |  Isolation %.1f dB'], ...
    localPassString(cross_correlation.pass), ...
    localSourceLabel(source_info), ...
    cross_correlation.peak_lag_samples, ...
    cross_correlation.peak_lag_us, ...
    cross_correlation.peak_to_median_db, ...
    cross_correlation.peak_to_second_db));
end

function fig = localPlotZeroDopplerFigure(source_info, zero_doppler, opts)
fig = figure( ...
    'Name', 'Direct-Path Precheck: Zero-Doppler Ridge', ...
    'NumberTitle', 'off', ...
    'Visible', opts.FigureVisibility);
tlo = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

plot_range_limit_km = min(max(zero_doppler.range_axis_m) / 1e3, 30);
plot_range_mask = zero_doppler.range_axis_m / 1e3 <= plot_range_limit_km;

ax1 = nexttile(tlo);
plot(ax1, zero_doppler.range_axis_m(plot_range_mask) / 1e3, ...
    zero_doppler.before_zero_cut_db(plot_range_mask), ...
    'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.1, 'DisplayName', 'Before ECA-C');
hold(ax1, 'on');
plot(ax1, zero_doppler.range_axis_m(plot_range_mask) / 1e3, ...
    zero_doppler.after_zero_cut_db(plot_range_mask), ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.1, 'DisplayName', 'After ECA-C');
yline(ax1, zero_doppler.noise_floor_db, ':k', 'Noise floor');
grid(ax1, 'on');
xlabel(ax1, 'Bistatic range excess (km)');
ylabel(ax1, 'Zero-Doppler cut (dB)');
title(ax1, 'Zero-Doppler Cut vs Range');
legend(ax1, 'Location', 'best');

ax2 = nexttile(tlo);
plot(ax2, zero_doppler.doppler_axis_hz, zero_doppler.near_range_doppler_before_db, ...
    'Color', [0.00, 0.45, 0.74], 'LineWidth', 1.1, 'DisplayName', 'Before ECA-C');
hold(ax2, 'on');
plot(ax2, zero_doppler.doppler_axis_hz, zero_doppler.near_range_doppler_after_db, ...
    'Color', [0.85, 0.33, 0.10], 'LineWidth', 1.1, 'DisplayName', 'After ECA-C');
xline(ax2, 0, ':k', '0 Hz');
grid(ax2, 'on');
xlabel(ax2, 'Doppler (Hz)');
ylabel(ax2, 'Near-range mean power (dB)');
title(ax2, sprintf('Near-Range Doppler Mean (0-%.1f km)', zero_doppler.near_range_limit_m / 1e3));
legend(ax2, 'Location', 'best');

sgtitle(tlo, sprintf([ ...
    '%s  |  %s  |  DPI lag %d samples  |  ' ...
    'Before-NF %.1f dB  |  Suppression %.1f dB  |  After-NF %.1f dB'], ...
    localPassString(zero_doppler.pass), ...
    localSourceLabel(source_info), ...
    zero_doppler.dpi_lag_samples, ...
    zero_doppler.before_margin_db, ...
    zero_doppler.suppression_db, ...
    zero_doppler.after_margin_db));
end

function recommendations = localBuildRecommendations(reference_quality, cross_correlation, zero_doppler)
recommendations = {};

if ~reference_quality.level_pass
    if reference_quality.level_dbfs < reference_quality.level_min_dbfs
        recommendations{end + 1} = 'Reference channel is weak. Increase reference gain or inspect the reference antenna path.';
    else
        recommendations{end + 1} = 'Reference channel is clipping. Reduce gain before trusting ECA-C or truth scoring.';
    end
end

if ~reference_quality.pilot_pass
    recommendations{end + 1} = ['Reference channel does not show a coherent ATSC pilot. Check band selection, antenna aim, ' ...
        'capture center frequency, and whether the reference path needs more direct-path gain or an inline LNA.'];
end

if isfield(reference_quality, 'pilot_selection')
    pilot_selection = reference_quality.pilot_selection;
    if isfinite(pilot_selection.header_center_off_raster_hz) && abs(pilot_selection.header_center_off_raster_hz) > 50e3
        recommendations{end + 1} = sprintf( ...
            'Capture header center %.3f MHz is off the ATSC raster. Nearest ATSC center is %.3f MHz; confirm the intended illuminator channel center.', ...
            pilot_selection.capture_center_frequency_hz / 1e6, ...
            pilot_selection.header_center_nearest_atsc_hz / 1e6);
    end
    if pilot_selection.selected_is_mirrored
        recommendations{end + 1} = 'The best ATSC-like pilot is on the mirrored side of baseband. Check for spectral inversion or I/Q sign convention issues before trusting the frequency-axis orientation.';
    end
end

if isfield(reference_quality, 'frequency_context') && ...
        strcmp(reference_quality.frequency_context.illuminator_center_source, 'unresolved')
    recommendations{end + 1} = ['Capture metadata does not lock one ATSC center. ' ...
        'Confirm the stored center frequency or pass IlluminatorCenterFrequencyHz explicitly for a controlled audit.'];
end

if ~reference_quality.sfm_pass
    recommendations{end + 1} = 'Reference spectrum shows deep frequency-selective nulls. A cleaner or more directional reference antenna may help.';
end

if ~cross_correlation.pass
    recommendations{end + 1} = 'Reference/surveillance lag is not dominated by one peak. Check cabling, channel mapping, and direct-path blockage.';
end

if ~zero_doppler.pass
    recommendations{end + 1} = ['Residual zero-Doppler ridge remains too strong after ECA-C on this slice. ' ...
        'Check reference quality, reference-path gain/LNA, illuminator alignment, and CPI stationarity. ' ...
        'Use swap_channels only if pilot coherence improves materially when swapped.'];
end
end

function label = localSourceLabel(source_info)
if strlength(source_info.session_id) > 0
    label = sprintf('session %s part %d', source_info.session_id, source_info.part_index);
else
    label = char(source_info.source_label);
end
end

function txt = localPassString(tf)
if tf
    txt = 'PASS';
else
    txt = 'WARN';
end
end

function value = localGetNumericMetadataField(file_meta, field_name, default_value)
value = default_value;
if ~isstruct(file_meta) || ~isfield(file_meta, field_name)
    return
end

raw_value = file_meta.(field_name);
if isempty(raw_value)
    return
end

raw_value = double(raw_value);
if ~isscalar(raw_value) || ~isfinite(raw_value)
    return
end

value = raw_value;
end

function value = localGetSourceInfoFrequency(source_info, field_name)
value = [];
if isstruct(source_info) && isfield(source_info, field_name)
    value = source_info.(field_name);
end
end
