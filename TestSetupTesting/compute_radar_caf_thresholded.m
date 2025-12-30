function [caf_map, detections] = compute_radar_caf_thresholded(fname, Fs)
    % 1. Load & Process
    [caf_map, delays, doppler] = compute_radar_caf(fname, Fs, 'suppressClutter', true);
    
    % Ensure we are working with Magnitude (Absolute Value)
    caf_mag = abs(caf_map);

    % 2. Robust Thresholding Logic
    % Use median for noise floor - it's resistant to being skewed by the targets themselves
    noise_floor = median(caf_mag(:));
    
    % Use 13-15dB as a starting point. 
    threshold_dB = 15; 
    threshold_val = noise_floor * 10^(threshold_dB/20); % Multiplier for Magnitude
    
    % 3. Safe Peak Finding
    % Check if any data actually exceeds the threshold to avoid the findpeaks warning
    if max(caf_mag(:)) > threshold_val
        [pks, locs] = findpeaks(caf_mag(:), 'MinPeakHeight', threshold_val);
        [dopp_idx, delay_idx] = ind2sub(size(caf_mag), locs);
        
        % Calculate SNR based on Magnitude Ratio
        snr_vals = 20*log10(pks/noise_floor);
        
        detections = table(delays(delay_idx)', doppler(dopp_idx)', snr_vals, ...
            'VariableNames', {'Delay_us', 'Doppler_Hz', 'SNR_dB'});
    else
        % Return an empty table with correct variable names if no peaks found
        detections = table([], [], [], 'VariableNames', {'Delay_us', 'Doppler_Hz', 'SNR_dB'});
    end

    % 4. Visualization (Normalize to 0dB peak for consistent display)
    figure('Name', 'Automated Target Tracker');
    display_map = 20*log10(caf_mag ./ max(caf_mag(:)) + eps);
    imagesc(delays, doppler, display_map);
    axis xy; colormap jet; colorbar; hold on;
    caxis([-60 0]); % Lock dynamic range to 60dB for better visibility
    
    if ~isempty(detections)
        plot(detections.Delay_us, detections.Doppler_Hz, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
        title(sprintf('Step 4B: Cross-Ambiguity Function with CFAR - %d Moving Targets Detected', height(detections)));
    else
        title('Step 4B: Cross-Ambiguity Function with CFAR - No Moving Targets Above Threshold');
    end
    
    xlabel('Bistatic Delay (\mu s)'); ylabel('Doppler Shift (Hz)');
    grid on;
    disp(detections);
end