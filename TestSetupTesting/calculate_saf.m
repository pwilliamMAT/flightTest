function [ambg, delays, doppler] = calculate_saf(x, Fs, max_delay_ms, max_doppler_hz)
    % x: your centered IQ data
    % Fs: Sample rate
    % max_delay_ms: Max range to check (e.g. 0.5 ms)
    % max_doppler_hz: Max speed to check (e.g. 500 Hz)

    % 1. Parameters
    N = length(x);
    max_lag = round((max_delay_ms/1000) * Fs);
    doppler_axis = -max_doppler_hz:5:max_doppler_hz; % 5Hz steps
    
    ambg = zeros(length(doppler_axis), max_lag + 1);
    t = (0:N-1)' / Fs;

    fprintf('Calculating SAF (%d Doppler bins)... ', length(doppler_axis));
    
    % 2. The 2D Correlation Loop
    for i = 1:length(doppler_axis)
        % Apply Doppler shift to a copy of the signal
        x_shifted = x .* exp(1j * 2 * pi * doppler_axis(i) * t);
        
        % Cross-correlate original with shifted version
        [r, lags] = xcorr(x, x_shifted, max_lag);
        
        % Keep only positive lags (one side of the correlation)
        % and store the magnitude
        mid = max_lag + 1;
        ambg(i, :) = abs(r(mid:end));
    end
    fprintf('Done.\n');

    % 3. Convert units for plotting
    delays = (0:max_lag) / Fs * 1e6; % microseconds
    doppler = doppler_axis;

    % 4. Visualization
    figure('Name', 'Self-Ambiguity Function');
    surf(delays, doppler, 20*log10(ambg ./ max(ambg(:)) + eps), 'EdgeColor', 'none');
    view(2); % Top-down view
    axis tight; colormap jet; colorbar;
    xlabel('Delay (\mu s)'); ylabel('Doppler (Hz)');
    title('Step 4A: Self-Ambiguity Function - Clutter Characterization (Single Channel)');

    fprintf(['Yagi will eventually be your Surveillance antenna,\n...' ...
        'the SAF you run on it now is actually a Clutter Map. \n...' ...
        'If you see peaks at 0 Doppler but significant delay, \n...' ...
        'those are static objects. In Passive Radar, we often \n...' ...
        'have to "subtract" those peaks out so we can see the \n...' ...
        'much smaller aircraft peaks hiding behind them.'])
end