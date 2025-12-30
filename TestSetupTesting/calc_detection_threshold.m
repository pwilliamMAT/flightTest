function [thresholddB, pnr] = calc_detection_threshold(ambg_map, pfa)
    % Convert to power
    map_pwr = abs(ambg_map).^2;
    noise_floor = median(map_pwr(:)); 
    
    % Theoretical alpha for CA-CFAR to achieve Pfa
    % Threshold = Noise * (Pfa^(-1/N) - 1) * N
    % For a simpler, standard approach:
    alpha = -log(pfa); 
    thresholddB = 10*log10(alpha);
    
    % Peak-to-Noise Ratio
    pnr = 10*log10(max(map_pwr(:)) / noise_floor);

    fprintf('--- Detection Statistics ---\n');
    fprintf('Target Threshold:  +%.2f dB above noise\n', thresholddB);
    fprintf('Current Max PNR:    %.2f dB\n', pnr);
end