function summaryTable = reprocessPlutoAzimuthPulseDebugScans(scanParent, varargin)
%REPROCESSPLUTOAZIMUTHPULSEDEBUGSCANS Re-score matching azimuth scan folders.
%
% Plain-language concept:
%   Reprocessing is most useful when every scan folder in a comparison set is
%   analyzed with the same current code. This helper searches one parent
%   folder for scan folders whose names match a configurable regular
%   expression, runs the full-pulse Welch and coherent per-tone scoring for
%   each one, and writes a compact comparison table next to the scan folders.
%
% Example on the field computer:
%   summary = reprocessPlutoAzimuthPulseDebugScans( ...
%       "../captures/plutoAzimuthEnvironmentScans");
%
% Reprocess all azimuth scan folders under the parent:
%   summary = reprocessPlutoAzimuthPulseDebugScans( ...
%       "../captures/plutoAzimuthEnvironmentScans", ...
%       "ScanFolderRegex", ".*", ...
%       "SummaryFileName", "azimuth_reprocess_summary.csv");

if nargin < 1 || strlength(string(scanParent)) == 0
    scanParent = fullfile('..', 'captures', 'plutoAzimuthEnvironmentScans');
end

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'ScanFolderRegex', "^az_pulse_([0-9.]+)_debug$", @(x) ischar(x) || isstring(x));
addParameter(p, 'SummaryFileName', "az_pulse_reprocess_summary.csv", @(x) ischar(x) || isstring(x));
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

scanParent = string(scanParent);
folders = localFindMatchingScanFolders(scanParent, opts.ScanFolderRegex);
[~, order] = sort({folders.name});
folders = folders(order);

rows = repmat(localEmptyPulseSummaryRow(), numel(folders), 1);
for idx = 1:numel(folders)
    scanRoot = fullfile(folders(idx).folder, folders(idx).name);
    rows(idx).ScanID = string(folders(idx).name);
    rows(idx).PulseLabel_s = localPulseLabelFromName(folders(idx).name, opts.ScanFolderRegex);

    try
        scan = reprocessPlutoAzimuthEnvironmentalScan( ...
            scanRoot, ...
            'PlotFigures', opts.PlotFigures, ...
            'FigureVisibility', opts.FigureVisibility, ...
            'Verbose', opts.Verbose);
        rows(idx) = localSummaryRowFromScan(scan, rows(idx));
    catch me
        rows(idx).Status = "ERROR";
        rows(idx).ErrorMessage = string(me.message);
        if opts.Verbose
            fprintf('[reprocessPlutoAzimuthPulseDebugScans] %s failed: %s\n', ...
                folders(idx).name, me.message);
        end
    end
end

summaryTable = struct2table(rows);
summaryPath = fullfile(scanParent, string(opts.SummaryFileName));
writetable(summaryTable, summaryPath);
if opts.Verbose
    fprintf('[reprocessPlutoAzimuthPulseDebugScans] Matched %d folder(s) with regex "%s".\n', ...
        numel(folders), string(opts.ScanFolderRegex));
    fprintf('[reprocessPlutoAzimuthPulseDebugScans] Summary: %s\n', summaryPath);
end
end

function folders = localFindMatchingScanFolders(scanParent, scanFolderRegex)
scanParent = string(scanParent);
if ~isfolder(scanParent)
    error('reprocessPlutoAzimuthPulseDebugScans:missingParentFolder', ...
        'Scan parent folder does not exist: %s', scanParent);
end

allEntries = dir(scanParent);
folders = allEntries([allEntries.isdir]);
names = string({folders.name});
keep = names ~= "." & names ~= "..";
for idx = 1:numel(names)
    candidateRoot = fullfile(folders(idx).folder, folders(idx).name);
    keep(idx) = keep(idx) && ...
        ~isempty(regexp(names(idx), string(scanFolderRegex), 'once')) && ...
        isfile(fullfile(candidateRoot, 'scan_result.mat'));
end
folders = folders(keep);
end

function row = localEmptyPulseSummaryRow()
row = struct( ...
    'ScanID', "", ...
    'PulseLabel_s', NaN, ...
    'PulseDuration_s', NaN, ...
    'Status', "", ...
    'NumSteps', NaN, ...
    'DirectionalDetectMedian_dB', NaN, ...
    'ReferenceDetectMedian_dB', NaN, ...
    'DirectionalCoherentMedian_dB', NaN, ...
    'ReferenceCoherentMedian_dB', NaN, ...
    'DirectionalCoherentIntegratedMedian_dB', NaN, ...
    'ReferenceCoherentIntegratedMedian_dB', NaN, ...
    'DirectionalCoherentSpan_dB', NaN, ...
    'ReferenceCoherentSpan_dB', NaN, ...
    'RefSurvResidualMedian_dB', NaN, ...
    'RefSurvZeroLagCorrMedian', NaN, ...
    'RefSurvZeroLagCorrMax', NaN, ...
    'RefSurvPeakCorrMedian', NaN, ...
    'RefSurvPeakLagAtMaxZeroLag_samples', NaN, ...
    'ErrorMessage', "");
end

function row = localSummaryRowFromScan(scan, row)
tbl = scan.calibration_tone_table;
summary = scan.summary_table;
row.PulseDuration_s = double(scan.settings.pulse_duration_s);
row.Status = string(strjoin(unique(string(summary.Status), 'stable'), ','));
row.NumSteps = height(summary);
row.DirectionalDetectMedian_dB = median(tbl.DirectionalDetectMargin_dB, 'omitnan');
row.ReferenceDetectMedian_dB = median(tbl.ReferenceDetectMargin_dB, 'omitnan');
row.DirectionalCoherentMedian_dB = median(tbl.DirectionalCoherentMargin_dB, 'omitnan');
row.ReferenceCoherentMedian_dB = median(tbl.ReferenceCoherentMargin_dB, 'omitnan');
row.DirectionalCoherentIntegratedMedian_dB = ...
    median(summary.DirectionalCalibrationCoherentIntegratedMargin_dB, 'omitnan');
row.ReferenceCoherentIntegratedMedian_dB = ...
    median(summary.ReferenceCalibrationCoherentIntegratedMargin_dB, 'omitnan');
row.DirectionalCoherentSpan_dB = ...
    max(summary.DirectionalCalibrationCoherentIntegratedMargin_dB, [], 'omitnan') - ...
    min(summary.DirectionalCalibrationCoherentIntegratedMargin_dB, [], 'omitnan');
row.ReferenceCoherentSpan_dB = ...
    max(summary.ReferenceCalibrationCoherentIntegratedMargin_dB, [], 'omitnan') - ...
    min(summary.ReferenceCalibrationCoherentIntegratedMargin_dB, [], 'omitnan');
row.RefSurvResidualMedian_dB = median(summary.RefSurvNormalizedRMSError_dB, 'omitnan');
row.RefSurvZeroLagCorrMedian = median(summary.RefSurvZeroLagCorr, 'omitnan');
row.RefSurvZeroLagCorrMax = max(summary.RefSurvZeroLagCorr, [], 'omitnan');
row.RefSurvPeakCorrMedian = median(summary.RefSurvPeakCorr, 'omitnan');
[~, maxZeroIdx] = max(summary.RefSurvZeroLagCorr, [], 'omitnan');
if ~isempty(maxZeroIdx) && isfinite(maxZeroIdx) && maxZeroIdx >= 1
    row.RefSurvPeakLagAtMaxZeroLag_samples = summary.RefSurvPeakLag_samples(maxZeroIdx);
end
row.ErrorMessage = "";
end

function pulseSeconds = localPulseLabelFromName(folderName, scanFolderRegex)
tokens = regexp(string(folderName), string(scanFolderRegex), "tokens", "once");
if isempty(tokens)
    pulseSeconds = NaN;
else
    pulseSeconds = str2double(string(tokens{1}));
end
end
