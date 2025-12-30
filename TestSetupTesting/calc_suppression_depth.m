function [stats] = calc_suppression_depth(raw_signal, ambg_map)
    % raw_signal: The IQ data before heavy processing
    % ambg_map: The 2D Range-Doppler map (power)
    
    % 1. Calculate Raw Peak (The Direct Path signal strength)
    raw_pwr = abs(raw_signal).^2;
    peak_raw = max(raw_pwr);
    
    % 2. Calculate the Processed Noise Floor
    % We use the median of the map to avoid being biased by the DPI peak
    processed_map_pwr = abs(ambg_map).^2;
    noise_floor = median(processed_map_pwr(:));
    
    % 3. Calculate Suppression/Dynamic Range
    % This tells us the 'depth' into the noise we can see
    stats.dynamic_range = 10*log10(max(processed_map_pwr(:)) / noise_floor);
    
    % 4. Estimate the "Blind Zone"
    % High DPI creates a ridge at zero-doppler. We measure its width.
    [~, zero_dop_idx] = min(abs(0)); % Simplified: find the 0 Hz index
    zero_dop_profile = processed_map_pwr(:, floor(size(processed_map_pwr,2)/2));
    
    fprintf('\n--- Suppression & Dynamic Range ---\n');
    fprintf('Suppression Depth:    %.2f dB\n', stats.dynamic_range);
    
    if stats.dynamic_range < 40
        warning('LOW SUPPRESSION: Targets near the TV tower may be masked.');
    elseif stats.dynamic_range > 70
        fprintf('EXCELLENT SUPPRESSION: System is highly sensitive.\n');
    end
end