function [caf_map, detections] = compute_radar_caf_interpolated(fname, Fs)
% compute_radar_caf_interpolated: Adds sub-sample precision to targets

% 1. Run the standard CAF (clutter suppression ON)
[caf_map, delays, doppler] = compute_radar_caf(fname, Fs, 'suppressClutter', true);

% 2. Standard Thresholding
% 15dB is an "industry standard" - target peak is 31times more powerful
% than the average noise surrounding it
noise_floor = median(caf_map(:));
threshold_val = noise_floor * 10^(15/20); % 15dB Threshold
[pks, locs] = findpeaks(caf_map(:), 'MinPeakHeight', threshold_val);
[dop_idx, del_idx] = ind2sub(size(caf_map), locs);

% 3. Sub-Sample Interpolation
refined_delays = zeros(size(del_idx));
refined_doppler = zeros(size(dop_idx));

for i = 1:length(pks)
    row = dop_idx(i);
    col = del_idx(i);
    
    % Ensure we aren't at the very edge of the map
    if row > 1 && row < size(caf_map,1) && col > 1 && col < size(caf_map,2)
        
        % --- Delay Interpolation ---
        y = caf_map(row, col-1:col+1);
        delta_del = 0.5 * (y(1) - y(3)) / (y(1) - 2*y(2) + y(3));
        refined_delays(i) = delays(col) + (delta_del * (1/Fs) * 1e6);
        
        % --- Doppler Interpolation ---
        y = caf_map(row-1:row+1, col).';
        delta_dop = 0.5 * (y(1) - y(3)) / (y(1) - 2*y(2) + y(3));
        % Assume doppler_step from original script was 2Hz
        refined_doppler(i) = doppler(row) + (delta_dop * 2);
    else
        refined_delays(i) = delays(col);
        refined_doppler(i) = doppler(row);
    end
end

detections = table(refined_delays, refined_doppler, 20*log10(pks/noise_floor), ...
    'VariableNames', {'Delay_us', 'Doppler_Hz', 'SNR_dB'});

% 4. Plotting (Same as before but with refined coordinates)
figure;
imagesc(delays, doppler, 20*log10(caf_map ./ max(caf_map(:)) + eps));
axis xy; colormap jet; hold on;
if ~isempty(detections)
    plot(detections.Delay_us, detections.Doppler_Hz, 'rx', 'MarkerSize', 12, 'LineWidth', 2);
end
title(sprintf('Step 5B: Spline Interpolation Demo - Sub-Sample Peak Refinement (%d targets)', height(detections)));
disp(detections);
end