function summaryTable = reprocessPlutoAzimuthPulseDebugScans(scanParent, varargin)
%REPROCESSPLUTOAZIMUTHPULSEDEBUGSCANS Re-score az_pulse_*_debug folders.
%
% Plain-language concept:
%   The pulse-duration sweep is most useful when every scan folder is
%   reprocessed with the same current analysis code. This helper finds the
%   `az_pulse_<seconds>_debug` folders, runs the full-pulse Welch and
%   coherent per-tone scoring for each one, and writes a compact comparison
%   table next to the scan folders.
%
% Example on the field computer:
%   summary = reprocessPlutoAzimuthPulseDebugScans( ...
%       "../captures/plutoAzimuthEnvironmentScans");

if nargin < 1 || strlength(string(scanParent)) == 0
    scanParent = fullfile('..', 'captures', 'plutoAzimuthEnvironmentScans');
end

p = inputParser;
p.FunctionName = mfilename;
addParameter(p, 'PlotFigures', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigureVisibility', 'off', @(x) any(strcmpi(string(x), ["on", "off"])));
addParameter(p, 'Verbose', true, @(x) islogical(x) && isscalar(x));
parse(p, varargin{:});
opts = p.Results;

scanParent = string(scanParent);
folders = dir(fullfile(scanParent, 'az_pulse_*_debug'));
folders = folders([folders.isdir]);
[~, order] = sort({folders.name});
folders = folders(order);

rows = repmat(localEmptyPulseSummaryRow(), numel(folders), 1);
for idx = 1:numel(folders)
    scanRoot = fullfile(folders(idx).folder, folders(idx).name);
    rows(idx).ScanID = string(folders(idx).name);
    rows(idx).PulseLabel_s = localPulseLabelFromName(folders(idx).name);

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
writetable(summaryTable, fullfile(scanParent, 'az_pulse_reprocess_summary.csv'));
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
row.ErrorMessage = "";
end

function pulseSeconds = localPulseLabelFromName(folderName)
tokens = regexp(string(folderName), "az_pulse_([0-9.]+)_debug", "tokens", "once");
if isempty(tokens)
    pulseSeconds = NaN;
else
    pulseSeconds = str2double(tokens{1});
end
end
