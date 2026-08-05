function helperPlotSnrComparison( ...
        testAtten, snrMatrix, requiredSNR, legendValues, tstr, legendPrefix)
    % helperPlotSnrComparison  Plot multiple SNR curves for comparison.
    %   helperPlotSnrComparison(testAtten, snrMatrix, requiredSNR,
    %   legendValues, tstr, legendPrefix) plots one SNR curve per column
    %   of snrMatrix, labeled with legendPrefix + legendValues.
    %
    %   Inputs:
    %       testAtten    - Attenuation levels (x-axis)
    %       snrMatrix    - SNR values (nAttenuation x nCurves)
    %       requiredSNR  - Required SNR threshold (scalar)
    %       legendValues - Values to label each curve
    %       tstr         - Plot title
    %       legendPrefix - Prefix for legend entries

    ax = axes(figure);
    hold(ax, "on");
    nCurves = size(snrMatrix, 2);
    for iCurve = 1:nCurves
        plot(ax, testAtten, snrMatrix(:, iCurve), ...
            DisplayName=legendPrefix + string(legendValues(iCurve)));
    end
    yline(ax, requiredSNR, ...
        DisplayName='Required SNR for desired Pd', LineStyle='--');
    title(ax, tstr);
    xlabel(ax, ...
        'Target Attenuation (dB Down From Mean Surveillance Power)');
    ylabel(ax, 'Measured SNR (dB)');
    legend(ax);
end
