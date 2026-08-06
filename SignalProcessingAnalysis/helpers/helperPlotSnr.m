function helperPlotSnr(testAtten, measuredSnr, requiredSNR, tstr)
    % helperPlotSnr  Plot SNR measurement results.
    %   helperPlotSnr(testAtten, measuredSnr, requiredSNR, tstr) plots the
    %   measured SNR vs target attenuation with the required SNR threshold.

    ax = axes(figure);
    hold(ax, "on");
    plot(ax, testAtten, measuredSnr, DisplayName='Measured SNR');
    yline(ax, requiredSNR, ...
        DisplayName='Required SNR for desired Pd', LineStyle='--');
    title(ax, tstr);
    xlabel(ax, ...
        'Target Attenuation (dB Down From Mean Surveillance Power)');
    ylabel(ax, 'Measured SNR (dB)');
    legend(ax);
end
