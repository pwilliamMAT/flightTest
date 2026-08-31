function cpiReview = reviewPlutoMultitoneCpiIntegration(source, varargin)
%REVIEWPLUTOMULTITONECPIINTEGRATION Review multitone evidence over CPIs.
%
% Plain-language concept:
%   The multitone smoke test has shown that the planned tone bins are
%   visible in saved Pluto-to-N320 captures. This review asks the next
%   question: does that weak tone-bin evidence add up repeatably over many
%   artificial pulses? Each 10 ms CPI is treated as one slow-time look. For
%   every CPI, this function extracts the complex FFT bin at each known tone
%   offset, then integrates tone-bin power across CPIs and checks whether
%   REF and SURV share a stable complex relationship at those same bins.
%
% Toolbox-first implementation:
%   The capture is read through the existing project helper, preserving the
%   frozen channel mapping. MATLAB's fft is then applied along fast time in
%   the CPI data cube. Because the current tones are integer multiples of
%   the 100 Hz CPI bin spacing, the expected FFT bins are the correct
%   measurement locations for slow-time integration.
%
% Syntax:
%   cpiReview = reviewPlutoMultitoneCpiIntegration(source)
%   cpiReview = reviewPlutoMultitoneCpiIntegration(source, 'ToneOffsets_Hz', offsets)
%
% Inputs:
%   source can be a `.bb` capture file path, or a folder containing a
%   `*part1` capture file.
%
% Outputs:
%   cpiReview contains per-tone, per-CPI margins, cumulative integration
%   curves, and REF/SURV cross-channel coherence at the planned tone bins.
%
% See also: reviewPlutoMultitoneCapture, helperPlutoToneReadCapture, fft.

arguments
    source {mustBeTextScalar}
end
arguments (Repeating)
    varargin
end

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CaptureDuration_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CpiDuration_s', 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'ToneOffsets_Hz', [-350 -250 -150 250 350] * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'FloorHalfWidthHz', 20e3, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'FloorExclusionHalfWidthHz', 2e3, @(x) isnumeric(x) && isscalar(x) && x >= 0);
addParameter(p, 'OutputFolder', "", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

source = string(source);
captureFile = localResolveCaptureFile(source);
outputFolder = localResolveOutputFolder(captureFile, opts.OutputFolder);
if strlength(outputFolder) > 0 && ~isfolder(outputFolder)
    mkdir(outputFolder);
end

captureInfo = struct( ...
    'session_id', char(localSessionIdFromPath(captureFile)), ...
    'local_capture_files', captureFile, ...
    'header_center_frequency_hz', double(opts.CenterFrequency_Hz), ...
    'header_lo_offset_hz', double(opts.LOOffset_Hz), ...
    'header_tune_frequency_hz', double(opts.CenterFrequency_Hz + opts.LOOffset_Hz), ...
    'header_sample_rate_hz', double(opts.SampleRate_Hz), ...
    'sample_rate_hz', double(opts.SampleRate_Hz), ...
    'capture_duration_s', double(opts.CaptureDuration_s));

[referenceSignal, surveillanceSignal, captureInfoOut] = helperPlutoToneReadCapture( ...
    captureInfo, ...
    'ExpectedSampleRateHz', double(opts.SampleRate_Hz), ...
    'CaptureDurationSeconds', double(opts.CaptureDuration_s), ...
    'Verbose', opts.Verbose);

integration = localComputeCpiIntegration( ...
    referenceSignal, ...
    surveillanceSignal, ...
    double(opts.SampleRate_Hz), ...
    double(opts.CpiDuration_s), ...
    double(opts.ToneOffsets_Hz(:)), ...
    double(opts.FloorHalfWidthHz), ...
    double(opts.FloorExclusionHalfWidthHz));

cpiReview = struct( ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'source', char(source), ...
    'capture_file', char(captureFile), ...
    'settings', struct( ...
        'sample_rate_hz', double(opts.SampleRate_Hz), ...
        'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
        'lo_offset_hz', double(opts.LOOffset_Hz), ...
        'capture_duration_s', double(opts.CaptureDuration_s), ...
        'cpi_duration_s', double(opts.CpiDuration_s), ...
        'tone_offsets_hz', double(opts.ToneOffsets_Hz(:)), ...
        'floor_half_width_hz', double(opts.FloorHalfWidthHz), ...
        'floor_exclusion_half_width_hz', double(opts.FloorExclusionHalfWidthHz)), ...
    'capture_info', captureInfoOut, ...
    'integration', integration, ...
    'artifact_paths', struct());

if opts.PlotFigures
    cpiReview.figure_handle = localPlotCpiIntegration(cpiReview);
end

if strlength(outputFolder) > 0
    cpiReview = localWriteArtifacts(cpiReview, outputFolder);
end

if opts.Verbose
    localPrintSummary(cpiReview);
end
end

function integration = localComputeCpiIntegration(referenceSignal, surveillanceSignal, sampleRateHz, ...
        cpiDurationS, toneOffsetsHz, floorHalfWidthHz, floorExclusionHalfWidthHz)
samplesPerCpi = round(sampleRateHz * cpiDurationS);
numSamplesAvailable = min(numel(referenceSignal), numel(surveillanceSignal));
numCpis = floor(numSamplesAvailable / samplesPerCpi);
if numCpis < 2
    error('reviewPlutoMultitoneCpiIntegration:tooFewCpis', ...
        'At least two CPIs are required for slow-time integration.');
end

numSamplesUsed = samplesPerCpi * numCpis;
referenceCube = reshape(referenceSignal(1:numSamplesUsed), samplesPerCpi, numCpis);
surveillanceCube = reshape(surveillanceSignal(1:numSamplesUsed), samplesPerCpi, numCpis);

% Remove the per-CPI DC term so leakage from a DC offset does not pollute
% nearby floor estimates. The planned pilot tones are all far from DC.
referenceCube = referenceCube - mean(referenceCube, 1);
surveillanceCube = surveillanceCube - mean(surveillanceCube, 1);

referenceFft = fft(referenceCube, [], 1) ./ samplesPerCpi;
surveillanceFft = fft(surveillanceCube, [], 1) ./ samplesPerCpi;

[toneBinIndex, toneBinFrequencyHz] = localToneBins(toneOffsetsHz, sampleRateHz, samplesPerCpi);
[referenceCoeff, referenceFloorPower] = localExtractToneBins( ...
    referenceFft, toneBinIndex, sampleRateHz, samplesPerCpi, floorHalfWidthHz, floorExclusionHalfWidthHz);
[surveillanceCoeff, surveillanceFloorPower] = localExtractToneBins( ...
    surveillanceFft, toneBinIndex, sampleRateHz, samplesPerCpi, floorHalfWidthHz, floorExclusionHalfWidthHz);

referencePower = abs(referenceCoeff).^2;
surveillancePower = abs(surveillanceCoeff).^2;
referenceMarginByCpiDb = 10 * log10(referencePower ./ max(referenceFloorPower, eps) + eps);
surveillanceMarginByCpiDb = 10 * log10(surveillancePower ./ max(surveillanceFloorPower, eps) + eps);

referenceCumulativeMarginDb = 10 * log10( ...
    cumsum(referencePower, 2) ./ max(cumsum(referenceFloorPower, 2), eps) + eps);
surveillanceCumulativeMarginDb = 10 * log10( ...
    cumsum(surveillancePower, 2) ./ max(cumsum(surveillanceFloorPower, 2), eps) + eps);

crossChannelProduct = surveillanceCoeff .* conj(referenceCoeff);
crossChannelCoherence = abs(sum(crossChannelProduct, 2)) ./ sqrt( ...
    max(sum(referencePower, 2), eps) .* max(sum(surveillancePower, 2), eps));
crossChannelPhaseDeg = rad2deg(angle(sum(crossChannelProduct, 2)));
crossChannelCumulativeCoherence = abs(cumsum(crossChannelProduct, 2)) ./ sqrt( ...
    max(cumsum(referencePower, 2), eps) .* max(cumsum(surveillancePower, 2), eps));

slowTimeFrequencyHz = localSlowTimeFrequencyAxis(numCpis, cpiDurationS);
referenceSlowTimeFft = fftshift(fft(referenceCoeff, [], 2), 2);
surveillanceSlowTimeFft = fftshift(fft(surveillanceCoeff, [], 2), 2);

[referenceSlowTimePeakPower, referenceSlowTimePeakIdx] = max(abs(referenceSlowTimeFft).^2, [], 2);
[surveillanceSlowTimePeakPower, surveillanceSlowTimePeakIdx] = max(abs(surveillanceSlowTimeFft).^2, [], 2);
referenceSlowTimePeakMarginDb = 10 * log10( ...
    referenceSlowTimePeakPower ./ max(sum(referenceFloorPower, 2), eps) + eps);
surveillanceSlowTimePeakMarginDb = 10 * log10( ...
    surveillanceSlowTimePeakPower ./ max(sum(surveillanceFloorPower, 2), eps) + eps);
referenceSlowTimePeakFrequencyHz = slowTimeFrequencyHz(referenceSlowTimePeakIdx);
surveillanceSlowTimePeakFrequencyHz = slowTimeFrequencyHz(surveillanceSlowTimePeakIdx);
slowTimePeakFrequencyDeltaHz = abs(referenceSlowTimePeakFrequencyHz(:) - surveillanceSlowTimePeakFrequencyHz(:));

perTone = table( ...
    toneOffsetsHz(:) / 1e3, ...
    toneBinFrequencyHz(:) - toneOffsetsHz(:), ...
    median(referenceMarginByCpiDb, 2, 'omitnan'), ...
    localIntegratedMargin(referencePower, referenceFloorPower), ...
    referenceSlowTimePeakMarginDb(:), ...
    referenceSlowTimePeakFrequencyHz(:), ...
    median(surveillanceMarginByCpiDb, 2, 'omitnan'), ...
    localIntegratedMargin(surveillancePower, surveillanceFloorPower), ...
    surveillanceSlowTimePeakMarginDb(:), ...
    surveillanceSlowTimePeakFrequencyHz(:), ...
    slowTimePeakFrequencyDeltaHz(:), ...
    crossChannelCoherence(:), ...
    crossChannelPhaseDeg(:), ...
    'VariableNames', { ...
        'Tone_kHz', ...
        'FftBinError_Hz', ...
        'REF_MedianCpiMargin_dB', ...
        'REF_IntegratedCpiMargin_dB', ...
        'REF_SlowTimePeakMargin_dB', ...
        'REF_SlowTimePeakHz', ...
        'SURV_MedianCpiMargin_dB', ...
        'SURV_IntegratedCpiMargin_dB', ...
        'SURV_SlowTimePeakMargin_dB', ...
        'SURV_SlowTimePeakHz', ...
        'SlowTimePeakDelta_Hz', ...
        'CrossChannelCoherence', ...
        'CrossChannelPhase_deg'});

referenceCombIntegratedMarginDb = 10 * log10(sum(referencePower, 'all') / max(sum(referenceFloorPower, 'all'), eps) + eps);
surveillanceCombIntegratedMarginDb = 10 * log10(sum(surveillancePower, 'all') / max(sum(surveillanceFloorPower, 'all'), eps) + eps);
referenceCombSlowTimePeakMarginDb = 10 * log10( ...
    sum(referenceSlowTimePeakPower, 'all') / max(sum(referenceFloorPower, 'all'), eps) + eps);
surveillanceCombSlowTimePeakMarginDb = 10 * log10( ...
    sum(surveillanceSlowTimePeakPower, 'all') / max(sum(surveillanceFloorPower, 'all'), eps) + eps);
medianCrossChannelCoherence = median(crossChannelCoherence, 'omitnan');

integration = struct( ...
    'samples_per_cpi', double(samplesPerCpi), ...
    'num_cpis', double(numCpis), ...
    'num_samples_used', double(numSamplesUsed), ...
    'cpi_duration_s', double(cpiDurationS), ...
    'slow_time_s', (0:numCpis - 1).' * cpiDurationS, ...
    'tone_offsets_hz', toneOffsetsHz(:), ...
    'tone_bin_index', toneBinIndex(:), ...
    'tone_bin_frequency_hz', toneBinFrequencyHz(:), ...
    'reference_coefficients', referenceCoeff, ...
    'surveillance_coefficients', surveillanceCoeff, ...
    'reference_margin_by_cpi_db', referenceMarginByCpiDb, ...
    'surveillance_margin_by_cpi_db', surveillanceMarginByCpiDb, ...
    'reference_cumulative_margin_db', referenceCumulativeMarginDb, ...
    'surveillance_cumulative_margin_db', surveillanceCumulativeMarginDb, ...
    'slow_time_frequency_hz', slowTimeFrequencyHz(:), ...
    'reference_slow_time_fft', referenceSlowTimeFft, ...
    'surveillance_slow_time_fft', surveillanceSlowTimeFft, ...
    'reference_slow_time_peak_margin_db', referenceSlowTimePeakMarginDb(:), ...
    'surveillance_slow_time_peak_margin_db', surveillanceSlowTimePeakMarginDb(:), ...
    'reference_slow_time_peak_frequency_hz', referenceSlowTimePeakFrequencyHz(:), ...
    'surveillance_slow_time_peak_frequency_hz', surveillanceSlowTimePeakFrequencyHz(:), ...
    'slow_time_peak_frequency_delta_hz', slowTimePeakFrequencyDeltaHz(:), ...
    'cross_channel_coherence', crossChannelCoherence(:), ...
    'cross_channel_phase_deg', crossChannelPhaseDeg(:), ...
    'cross_channel_cumulative_coherence', crossChannelCumulativeCoherence, ...
    'per_tone', perTone, ...
    'summary', struct( ...
        'reference_comb_integrated_margin_db', referenceCombIntegratedMarginDb, ...
        'surveillance_comb_integrated_margin_db', surveillanceCombIntegratedMarginDb, ...
        'reference_comb_slow_time_peak_margin_db', referenceCombSlowTimePeakMarginDb, ...
        'surveillance_comb_slow_time_peak_margin_db', surveillanceCombSlowTimePeakMarginDb, ...
        'median_slow_time_peak_frequency_delta_hz', median(slowTimePeakFrequencyDeltaHz, 'omitnan'), ...
        'median_cross_channel_coherence', medianCrossChannelCoherence, ...
        'ideal_cpi_integration_gain_db', 10 * log10(numCpis), ...
        'ideal_tone_and_cpi_integration_gain_db', 10 * log10(numCpis * numel(toneOffsetsHz))));
end

function integratedMarginDb = localIntegratedMargin(tonePower, floorPower)
integratedMarginDb = 10 * log10(sum(tonePower, 2) ./ max(sum(floorPower, 2), eps) + eps);
end

function slowTimeFrequencyHz = localSlowTimeFrequencyAxis(numCpis, cpiDurationS)
slowTimePrfHz = 1 / cpiDurationS;
if mod(numCpis, 2) == 0
    binIndex = (-numCpis / 2:numCpis / 2 - 1).';
else
    binIndex = (-(numCpis - 1) / 2:(numCpis - 1) / 2).';
end
slowTimeFrequencyHz = binIndex / numCpis * slowTimePrfHz;
end

function [toneBinIndex, toneBinFrequencyHz] = localToneBins(toneOffsetsHz, sampleRateHz, samplesPerCpi)
toneBinIndex = mod(round(toneOffsetsHz(:) / sampleRateHz * samplesPerCpi), samplesPerCpi) + 1;
positiveFrequencyHz = (toneBinIndex - 1) / samplesPerCpi * sampleRateHz;
toneBinFrequencyHz = positiveFrequencyHz;
negativeMask = toneBinFrequencyHz > sampleRateHz / 2;
toneBinFrequencyHz(negativeMask) = toneBinFrequencyHz(negativeMask) - sampleRateHz;
end

function [toneCoeff, floorPower] = localExtractToneBins( ...
        spectrum, toneBinIndex, sampleRateHz, samplesPerCpi, floorHalfWidthHz, floorExclusionHalfWidthHz)
numTones = numel(toneBinIndex);
numCpis = size(spectrum, 2);
toneCoeff = complex(zeros(numTones, numCpis));
floorPower = zeros(numTones, numCpis);

binSpacingHz = sampleRateHz / samplesPerCpi;
floorHalfWidthBins = max(1, round(floorHalfWidthHz / binSpacingHz));
floorExclusionBins = max(1, round(floorExclusionHalfWidthHz / binSpacingHz));

for idx = 1:numTones
    binIdx = toneBinIndex(idx);
    toneCoeff(idx, :) = spectrum(binIdx, :);

    relativeBins = (-floorHalfWidthBins:floorHalfWidthBins).';
    floorRelativeBins = relativeBins(abs(relativeBins) >= floorExclusionBins);
    floorIdx = mod(binIdx - 1 + floorRelativeBins, samplesPerCpi) + 1;
    floorPower(idx, :) = median(abs(spectrum(floorIdx, :)).^2, 1, 'omitnan');
end
end

function captureFile = localResolveCaptureFile(source)
if isfile(source)
    captureFile = source;
    return
end

if ~isfolder(source)
    error('reviewPlutoMultitoneCpiIntegration:sourceNotFound', ...
        'Source must be a capture file or folder: %s', source);
end

files = dir(fullfile(source, '*part1*'));
files = files(~[files.isdir]);
if isempty(files)
    files = dir(fullfile(source, '*'));
    files = files(~[files.isdir]);
end
if isempty(files)
    error('reviewPlutoMultitoneCpiIntegration:noCaptureFiles', ...
        'No capture files were found in %s.', source);
end

[~, newestIdx] = max([files.datenum]);
captureFile = string(fullfile(files(newestIdx).folder, files(newestIdx).name));
end

function outputFolder = localResolveOutputFolder(captureFile, requestedOutputFolder)
requestedOutputFolder = string(requestedOutputFolder);
if strlength(requestedOutputFolder) > 0
    outputFolder = requestedOutputFolder;
    return
end

captureFolder = string(fileparts(captureFile));
timestamp = string(datetime('now', 'Format', 'yyyyMMdd''T''HHmmss'));
outputFolder = fullfile(captureFolder, "multitone_cpi_review_" + timestamp);
end

function sessionId = localSessionIdFromPath(captureFile)
[~, name] = fileparts(captureFile);
sessionId = string(name);
partIdx = strfind(sessionId, "_part");
if ~isempty(partIdx)
    sessionId = extractBefore(sessionId, partIdx(1));
end
end

function cpiReview = localWriteArtifacts(cpiReview, outputFolder)
resultMat = fullfile(outputFolder, 'result.mat');
summaryTxt = fullfile(outputFolder, 'summary.txt');
summaryPng = fullfile(outputFolder, 'summary.png');

reviewForSave = cpiReview;
if isfield(reviewForSave, 'figure_handle')
    reviewForSave = rmfield(reviewForSave, 'figure_handle');
end
save(resultMat, 'reviewForSave');

fid = fopen(summaryTxt, 'w');
if fid < 0
    error('reviewPlutoMultitoneCpiIntegration:summaryOpenFailed', ...
        'Could not open summary file for writing: %s', summaryTxt);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', localSummaryLines(cpiReview));
clear cleanupFile

if isfield(cpiReview, 'figure_handle') && isgraphics(cpiReview.figure_handle)
    exportgraphics(cpiReview.figure_handle, summaryPng, 'Resolution', 150);
end

cpiReview.artifact_paths = struct( ...
    'result_mat', string(resultMat), ...
    'summary_txt', string(summaryTxt), ...
    'summary_png', string(summaryPng));
end

function lines = localSummaryLines(cpiReview)
summary = cpiReview.integration.summary;
lines = [
    "PLUTO MULTITONE CPI INTEGRATION REVIEW"
    "Capture: " + string(cpiReview.capture_file)
    "CPIs: " + cpiReview.integration.num_cpis + ...
        " | CPI duration " + compose("%.3f", cpiReview.integration.cpi_duration_s * 1e3) + " ms"
    "REF comb integrated CPI margin " + ...
        compose("%.1f", summary.reference_comb_integrated_margin_db) + " dB"
    "SURV comb integrated CPI margin " + ...
        compose("%.1f", summary.surveillance_comb_integrated_margin_db) + " dB"
    "REF comb slow-time peak margin " + ...
        compose("%.1f", summary.reference_comb_slow_time_peak_margin_db) + " dB"
    "SURV comb slow-time peak margin " + ...
        compose("%.1f", summary.surveillance_comb_slow_time_peak_margin_db) + " dB"
    "Median REF/SURV slow-time peak frequency delta " + ...
        compose("%.2f", summary.median_slow_time_peak_frequency_delta_hz) + " Hz"
    "Median REF/SURV cross-channel coherence " + ...
        compose("%.3f", summary.median_cross_channel_coherence)
    "Ideal CPI-only integration gain " + ...
        compose("%.1f", summary.ideal_cpi_integration_gain_db) + " dB"
    "Ideal tone-and-CPI integration gain " + ...
        compose("%.1f", summary.ideal_tone_and_cpi_integration_gain_db) + " dB"
    ];
end

function localPrintSummary(cpiReview)
disp(localSummaryLines(cpiReview));
disp(cpiReview.integration.per_tone);
if isfield(cpiReview, 'artifact_paths') && isfield(cpiReview.artifact_paths, 'summary_txt')
    fprintf('[reviewPlutoMultitoneCpiIntegration] Artifacts written to %s\n', ...
        fileparts(cpiReview.artifact_paths.summary_txt));
end
end

function fig = localPlotCpiIntegration(cpiReview)
integration = cpiReview.integration;
toneOffsetsKhz = integration.tone_offsets_hz(:) / 1e3;
slowTimeIndex = 1:integration.num_cpis;

fig = figure('Name', 'Pluto multitone CPI integration review', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto multitone CPI integration');

nexttile(tl, 1);
bar(toneOffsetsKhz, [ ...
    integration.per_tone.REF_IntegratedCpiMargin_dB, ...
    integration.per_tone.SURV_IntegratedCpiMargin_dB, ...
    integration.per_tone.REF_SlowTimePeakMargin_dB, ...
    integration.per_tone.SURV_SlowTimePeakMargin_dB]);
grid on;
xlabel('Expected tone offset (kHz)');
ylabel('Integrated margin (dB)');
title('CPI integration by tone');
legend({'REF noncoh', 'SURV noncoh', 'REF slow peak', 'SURV slow peak'}, 'Location', 'best');

nexttile(tl, 2);
bar(toneOffsetsKhz, integration.cross_channel_coherence);
ylim([0, 1]);
grid on;
xlabel('Expected tone offset (kHz)');
ylabel('Coherence magnitude');
title('REF/SURV coherence at planned bins');

nexttile(tl, 3);
imagesc(slowTimeIndex, toneOffsetsKhz, integration.reference_margin_by_cpi_db);
axis xy;
colorbar;
xlabel('CPI index');
ylabel('Tone offset (kHz)');
title('REF per-CPI tone margin (dB)');

nexttile(tl, 4);
plot(integration.slow_time_frequency_hz, ...
    mean(20 * log10(abs(integration.reference_slow_time_fft) + eps), 1, 'omitnan'), ...
    'LineWidth', 1.2);
hold on;
plot(integration.slow_time_frequency_hz, ...
    mean(20 * log10(abs(integration.surveillance_slow_time_fft) + eps), 1, 'omitnan'), ...
    'LineWidth', 1.2);
grid on;
xlabel('Slow-time frequency (Hz)');
ylabel('Mean slow-time FFT magnitude (dB)');
title('Slow-time coherent search');
legend({'REF', 'SURV'}, 'Location', 'best');
end
