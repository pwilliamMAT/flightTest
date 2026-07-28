function detection = runPlutoMultitoneSlowTimeDetector(source, varargin)
%RUNPLUTOMULTITONESLOWTIMEDETECTOR Comb-locked slow-time detector prototype.
%
% Plain-language concept:
%   A saved multitone capture gives us many artificial pulses: one 10 ms CPI
%   is one slow-time look. For each CPI and each emitted tone, this detector
%   extracts the complex FFT coefficient at the known tone bin. A slow-time
%   FFT across those CPI coefficients then integrates tone energy even when
%   the phase rotates from CPI to CPI. Finally, the detector combines the
%   tone evidence across the comb and looks for slow-time bins where REF and
%   SURV both show energy.
%
% Toolbox-first implementation:
%   The tone-bin extraction is delegated to reviewPlutoMultitoneCpiIntegration,
%   which uses fft on the CPI data cube. This detector then uses findpeaks
%   from Signal Processing Toolbox on the comb-summed slow-time spectrum so
%   the prototype reports a ranked set of candidate slow-time frequencies.
%
% Syntax:
%   detection = runPlutoMultitoneSlowTimeDetector(source)
%   detection = runPlutoMultitoneSlowTimeDetector(source, 'ToneOffsets_Hz', offsets)
%
% See also: reviewPlutoMultitoneCpiIntegration, findpeaks, fft.

arguments
    source {mustBeTextScalar}
end
arguments (Repeating)
    varargin
end

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'ToneOffsets_Hz', [-350 -250 -150 250 350] * 1e3, ...
    @(x) isnumeric(x) && isvector(x) && ~isempty(x));
addParameter(p, 'SampleRate_Hz', 8e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CenterFrequency_Hz', 599e6, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'LOOffset_Hz', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CaptureDuration_s', 1.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'CpiDuration_s', 0.01, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'MaxCandidates', 8, @(x) isnumeric(x) && isscalar(x) && x >= 1);
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

cpiReview = reviewPlutoMultitoneCpiIntegration(captureFile, ...
    'ToneOffsets_Hz', double(opts.ToneOffsets_Hz(:)), ...
    'SampleRate_Hz', double(opts.SampleRate_Hz), ...
    'CenterFrequency_Hz', double(opts.CenterFrequency_Hz), ...
    'LOOffset_Hz', double(opts.LOOffset_Hz), ...
    'CaptureDuration_s', double(opts.CaptureDuration_s), ...
    'CpiDuration_s', double(opts.CpiDuration_s), ...
    'OutputFolder', "", ...
    'PlotFigures', false, ...
    'Verbose', false);

slowTime = localBuildSlowTimeDetection(cpiReview.integration, opts.MaxCandidates);

detection = struct( ...
    'created_utc', string(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd''T''HH:mm:ss''Z')), ...
    'source', char(source), ...
    'capture_file', char(captureFile), ...
    'settings', struct( ...
        'tone_offsets_hz', double(opts.ToneOffsets_Hz(:)), ...
        'sample_rate_hz', double(opts.SampleRate_Hz), ...
        'center_frequency_hz', double(opts.CenterFrequency_Hz), ...
        'lo_offset_hz', double(opts.LOOffset_Hz), ...
        'capture_duration_s', double(opts.CaptureDuration_s), ...
        'cpi_duration_s', double(opts.CpiDuration_s), ...
        'max_candidates', double(opts.MaxCandidates)), ...
    'cpi_review', cpiReview, ...
    'slow_time_detection', slowTime, ...
    'artifact_paths', struct());

if opts.PlotFigures
    detection.figure_handle = localPlotDetection(detection);
end

if strlength(outputFolder) > 0
    detection = localWriteArtifacts(detection, outputFolder);
end

if opts.Verbose
    localPrintSummary(detection);
end
end

function slowTime = localBuildSlowTimeDetection(integration, maxCandidates)
refPower = abs(integration.reference_slow_time_fft).^2;
survPower = abs(integration.surveillance_slow_time_fft).^2;
numTones = size(refPower, 1);

refNormPower = localNormalizeToneSpectra(refPower);
survNormPower = localNormalizeToneSpectra(survPower);

% Sum normalized slow-time power across tones. This is noncoherent across
% the comb, which is appropriate while the channel phase response versus
% frequency is unknown.
refCombPower = sum(refNormPower, 1) / numTones;
survCombPower = sum(survNormPower, 1) / numTones;
jointCombPower = sqrt(refCombPower .* survCombPower);

refCombDb = 10 * log10(refCombPower + eps);
survCombDb = 10 * log10(survCombPower + eps);
jointCombDb = 10 * log10(jointCombPower + eps);

[peakValueDb, peakIdx] = max(jointCombDb);
peakFrequencyHz = integration.slow_time_frequency_hz(peakIdx);
noiseFloorDb = median(jointCombDb, 'omitnan');
peakContrastDb = peakValueDb - noiseFloorDb;

candidateTable = localFindCandidates( ...
    integration.slow_time_frequency_hz(:), ...
    refCombDb(:), ...
    survCombDb(:), ...
    jointCombDb(:), ...
    maxCandidates);

toneSupport = table( ...
    integration.tone_offsets_hz(:) / 1e3, ...
    10 * log10(refNormPower(:, peakIdx) + eps), ...
    10 * log10(survNormPower(:, peakIdx) + eps), ...
    10 * log10(sqrt(refNormPower(:, peakIdx) .* survNormPower(:, peakIdx)) + eps), ...
    'VariableNames', { ...
        'Tone_kHz', ...
        'REF_NormalizedPower_dB', ...
        'SURV_NormalizedPower_dB', ...
        'Joint_NormalizedPower_dB'});

slowTime = struct( ...
    'frequency_hz', integration.slow_time_frequency_hz(:), ...
    'reference_normalized_power', refNormPower, ...
    'surveillance_normalized_power', survNormPower, ...
    'reference_comb_power_db', refCombDb(:), ...
    'surveillance_comb_power_db', survCombDb(:), ...
    'joint_comb_power_db', jointCombDb(:), ...
    'peak_frequency_hz', peakFrequencyHz, ...
    'peak_joint_power_db', peakValueDb, ...
    'joint_noise_floor_db', noiseFloorDb, ...
    'peak_contrast_db', peakContrastDb, ...
    'candidate_table', candidateTable, ...
    'tone_support_at_peak', toneSupport);
end

function normPower = localNormalizeToneSpectra(powerByTone)
numTones = size(powerByTone, 1);
normPower = zeros(size(powerByTone));
for toneIdx = 1:numTones
    floorPower = median(powerByTone(toneIdx, :), 'omitnan');
    normPower(toneIdx, :) = powerByTone(toneIdx, :) ./ max(floorPower, eps);
end
end

function candidateTable = localFindCandidates(frequencyHz, refCombDb, survCombDb, jointCombDb, maxCandidates)
[peakValues, peakLocations] = findpeaks( ...
    jointCombDb, ...
    frequencyHz, ...
    'SortStr', 'descend');

if isempty(peakValues)
    [peakValues, peakIdx] = max(jointCombDb);
    peakLocations = frequencyHz(peakIdx);
end

numCandidates = min(maxCandidates, numel(peakValues));
peakValues = peakValues(1:numCandidates);
peakLocations = peakLocations(1:numCandidates);

refAtPeak = nan(numCandidates, 1);
survAtPeak = nan(numCandidates, 1);
contrastDb = nan(numCandidates, 1);
floorDb = median(jointCombDb, 'omitnan');

for idx = 1:numCandidates
    [~, nearestIdx] = min(abs(frequencyHz - peakLocations(idx)));
    refAtPeak(idx) = refCombDb(nearestIdx);
    survAtPeak(idx) = survCombDb(nearestIdx);
    contrastDb(idx) = peakValues(idx) - floorDb;
end

candidateTable = table( ...
    peakLocations(:), ...
    peakValues(:), ...
    contrastDb(:), ...
    refAtPeak(:), ...
    survAtPeak(:), ...
    'VariableNames', { ...
        'SlowTimeFrequency_Hz', ...
        'JointPower_dB', ...
        'JointContrast_dB', ...
        'REF_CombPower_dB', ...
        'SURV_CombPower_dB'});
end

function captureFile = localResolveCaptureFile(source)
if isfile(source)
    captureFile = source;
    return
end

if ~isfolder(source)
    error('runPlutoMultitoneSlowTimeDetector:sourceNotFound', ...
        'Source must be a capture file or folder: %s', source);
end

files = dir(fullfile(source, '*part1*'));
files = files(~[files.isdir]);
if isempty(files)
    files = dir(fullfile(source, '*'));
    files = files(~[files.isdir]);
end
if isempty(files)
    error('runPlutoMultitoneSlowTimeDetector:noCaptureFiles', ...
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
outputFolder = fullfile(captureFolder, "multitone_slowtime_detector_" + timestamp);
end

function detection = localWriteArtifacts(detection, outputFolder)
resultMat = fullfile(outputFolder, 'result.mat');
summaryTxt = fullfile(outputFolder, 'summary.txt');
summaryPng = fullfile(outputFolder, 'summary.png');

detectionForSave = detection;
if isfield(detectionForSave, 'figure_handle')
    detectionForSave = rmfield(detectionForSave, 'figure_handle');
end
save(resultMat, 'detectionForSave');

fid = fopen(summaryTxt, 'w');
if fid < 0
    error('runPlutoMultitoneSlowTimeDetector:summaryOpenFailed', ...
        'Could not open summary file for writing: %s', summaryTxt);
end
cleanupFile = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', localSummaryLines(detection));
fprintf(fid, '\nTop slow-time candidates:\n');
localWriteNumericTable(fid, detection.slow_time_detection.candidate_table);
fprintf(fid, '\nTone support at selected peak:\n');
localWriteNumericTable(fid, detection.slow_time_detection.tone_support_at_peak);
clear cleanupFile

if isfield(detection, 'figure_handle') && isgraphics(detection.figure_handle)
    exportgraphics(detection.figure_handle, summaryPng, 'Resolution', 150);
end

detection.artifact_paths = struct( ...
    'result_mat', string(resultMat), ...
    'summary_txt', string(summaryTxt), ...
    'summary_png', string(summaryPng));
end

function lines = localSummaryLines(detection)
slowTime = detection.slow_time_detection;
lines = [
    "PLUTO MULTITONE SLOW-TIME DETECTOR"
    "Capture: " + string(detection.capture_file)
    "Tones: " + numel(detection.settings.tone_offsets_hz) + ...
        " | CPIs: " + detection.cpi_review.integration.num_cpis
    "Peak slow-time frequency " + compose("%.3f", slowTime.peak_frequency_hz) + " Hz"
    "Peak joint comb power " + compose("%.1f", slowTime.peak_joint_power_db) + " dB"
    "Median joint floor " + compose("%.1f", slowTime.joint_noise_floor_db) + " dB"
    "Peak contrast " + compose("%.1f", slowTime.peak_contrast_db) + " dB"
    ];
end

function localPrintSummary(detection)
disp(localSummaryLines(detection));
disp(detection.slow_time_detection.candidate_table);
disp(detection.slow_time_detection.tone_support_at_peak);
if isfield(detection, 'artifact_paths') && isfield(detection.artifact_paths, 'summary_txt')
    fprintf('[runPlutoMultitoneSlowTimeDetector] Artifacts written to %s\n', ...
        fileparts(detection.artifact_paths.summary_txt));
end
end

function localWriteNumericTable(fid, tableValue)
variableNames = string(tableValue.Properties.VariableNames);
fprintf(fid, '%s\n', strjoin(variableNames, '\t'));
for rowIdx = 1:height(tableValue)
    rowValues = strings(1, width(tableValue));
    for colIdx = 1:width(tableValue)
        value = tableValue{rowIdx, colIdx};
        if isnumeric(value) && isscalar(value)
            rowValues(colIdx) = compose("%.6g", value);
        else
            rowValues(colIdx) = string(value);
        end
    end
    fprintf(fid, '%s\n', strjoin(rowValues, '\t'));
end
end

function fig = localPlotDetection(detection)
slowTime = detection.slow_time_detection;
toneOffsetsKhz = detection.cpi_review.integration.tone_offsets_hz(:) / 1e3;

fig = figure('Name', 'Pluto multitone slow-time detector', 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pluto multitone slow-time detector');

nexttile(tl, 1);
plot(slowTime.frequency_hz, slowTime.reference_comb_power_db, 'LineWidth', 1.1);
hold on;
plot(slowTime.frequency_hz, slowTime.surveillance_comb_power_db, 'LineWidth', 1.1);
plot(slowTime.frequency_hz, slowTime.joint_comb_power_db, 'k', 'LineWidth', 1.4);
xline(slowTime.peak_frequency_hz, '--');
grid on;
xlabel('Slow-time frequency (Hz)');
ylabel('Normalized comb power (dB)');
title('Comb-summed slow-time spectrum');
legend({'REF', 'SURV', 'Joint'}, 'Location', 'best');

nexttile(tl, 2);
bar(slowTime.tone_support_at_peak.Tone_kHz, ...
    [slowTime.tone_support_at_peak.REF_NormalizedPower_dB, ...
    slowTime.tone_support_at_peak.SURV_NormalizedPower_dB, ...
    slowTime.tone_support_at_peak.Joint_NormalizedPower_dB]);
grid on;
xlabel('Expected tone offset (kHz)');
ylabel('Normalized power at peak (dB)');
title('Tone support at selected peak');
legend({'REF', 'SURV', 'Joint'}, 'Location', 'best');

nexttile(tl, 3);
imagesc(slowTime.frequency_hz, toneOffsetsKhz, ...
    10 * log10(slowTime.reference_normalized_power + eps));
axis xy;
colorbar;
xlabel('Slow-time frequency (Hz)');
ylabel('Tone offset (kHz)');
title('REF tone slow-time power (dB)');

nexttile(tl, 4);
imagesc(slowTime.frequency_hz, toneOffsetsKhz, ...
    10 * log10(slowTime.surveillance_normalized_power + eps));
axis xy;
colorbar;
xlabel('Slow-time frequency (Hz)');
ylabel('Tone offset (kHz)');
title('SURV tone slow-time power (dB)');
end
