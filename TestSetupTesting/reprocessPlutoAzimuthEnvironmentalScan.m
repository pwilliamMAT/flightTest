function scan = reprocessPlutoAzimuthEnvironmentalScan(scanRoot, varargin)
%REPROCESSPLUTOAZIMUTHENVIRONMENTALSCAN Re-score an existing azimuth scan.
%
% Plain-language concept:
%   A Pluto azimuth scan stores two kinds of data: the small report products
%   and the large raw N320 baseband captures. If the raw captures are still
%   present on the field computer, this helper can re-run the analysis with
%   improved scoring logic without collecting any new RF data.
%
% Example:
%   scan = reprocessPlutoAzimuthEnvironmentalScan( ...
%       "captures/plutoAzimuthEnvironmentScans/az_pulse_1.0_debug");
%
% See also: runPlutoAzimuthEnvironmentalScan.

if nargin < 1
    error('reprocessPlutoAzimuthEnvironmentalScan:missingScanRoot', ...
        'Provide the existing scan folder to reprocess.');
end

scan = runPlutoAzimuthEnvironmentalScan( ...
    'ReprocessScanRoot', scanRoot, ...
    varargin{:});
end
