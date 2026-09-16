function figure_handle = plotManualADSBOpportunities(opportunity_table, varargin)
%PLOTMANUALADSBOPPORTUNITIES Show ranked aircraft in range-Doppler space.
%
%   figure_handle = plotManualADSBOpportunities(opportunity_table)
%
%   Marker color shows the explicit assumption-based BiSNR estimate. Labels
%   show manual rank and aircraft ID. This function only visualizes an
%   already-built table; it cannot trigger or start an acquisition.

p = inputParser;
p.FunctionName = mfilename;
addRequired(p, 'opportunity_table', @istable);
addParameter(p, 'Visible', 'on', ...
    @(x) any(strcmpi(string(x), ["on", "off"])));
parse(p, opportunity_table, varargin{:});
opts = p.Results;

required_variables = [ ...
    "AircraftID", "ExcessRange_m", "Doppler_Hz", ...
    "BiSNR_dB", "BiSNRRank"];
if ~all(ismember(required_variables, ...
        string(opportunity_table.Properties.VariableNames)))
    error('plotManualADSBOpportunities:badTable', ...
        'Input must come from buildManualADSBOpportunityTable.');
end

figure_handle = figure( ...
    'Name', 'Manual ADS-B Opportunity Ranking', ...
    'Color', 'white', ...
    'Visible', char(opts.Visible));
axes_handle = axes(figure_handle);

if isempty(opportunity_table)
    axis(axes_handle, 'off');
    text(axes_handle, 0.5, 0.5, 'No ADS-B opportunities available', ...
        'HorizontalAlignment', 'center');
    title(axes_handle, 'Manual ADS-B Opportunity Ranking');
    return
end

scatter(axes_handle, ...
    opportunity_table.Doppler_Hz, ...
    opportunity_table.ExcessRange_m ./ 1e3, ...
    70, opportunity_table.BiSNR_dB, 'filled');
grid(axes_handle, 'on');
xlabel(axes_handle, 'Bistatic Doppler (Hz)');
ylabel(axes_handle, 'Bistatic excess range (km)');
title(axes_handle, 'Manual opportunities at observed receiver CPA');
colorbar_handle = colorbar(axes_handle);
colorbar_handle.Label.String = 'Assumption-based BiSNR (dB)';

labels = compose('%d: %s', ...
    opportunity_table.BiSNRRank, opportunity_table.AircraftID);
text(axes_handle, ...
    opportunity_table.Doppler_Hz, ...
    opportunity_table.ExcessRange_m ./ 1e3, ...
    "  " + labels, ...
    'Interpreter', 'none', ...
    'VerticalAlignment', 'middle');

end
