function [max_range_km] = calc_coverage_map(ref_pwr, noise_floor_db, tx_gps, rx_gps, target_rcs)
    % ref_pwr: Linear power of the reference signal (Direct Path)
    % noise_floor_db: Statistical noise floor from calc_detection_threshold
    % tx_gps: [lat, lon] of TV tower
    % rx_gps: [lat, lon] of your Yagi
    % target_rcs: Radar Cross Section in m^2 (e.g., 1.0)
    
    % --- Physical Constants ---
    c = 3e8;
    fc = 540e6; 
    lambda = c/fc;
    SNR_req_db = 13; % Standard requirement for Pd=0.9, Pfa=1e-6
    
    % 1. Calculate Baseline (L)
    % Use distance function from Mapping Toolbox or Haversine
    L_km = deg2km(distance(tx_gps(1), tx_gps(2), rx_gps(1), rx_gps(2)));
    
    % 2. Calculate Maximum Bistatic Constant (K)
    % The product of transmitter-to-target (Rt) and target-to-receiver (Rr)
    % Pr = (PtGtGr * lambda^2 * sigma) / ((4pi)^3 * Rt^2 * Rr^2)
    % We solve for the point where signal drops into the noise floor
    
    min_detectable_pwr_db = noise_floor_db + SNR_req_db;
    min_detectable_pwr_lin = 10^(min_detectable_pwr_db/10);
    
    % In passive radar, PtGt is derived from the measured Direct Path (ref_pwr)
    % ref_pwr = (PtGtGr * lambda^2) / ((4pi)^2 * L^2)
    % Therefore: PtGtGr = (ref_pwr * (4pi*L)^2) / lambda^2
    
    PtGtGr_equiv = (ref_pwr * (4 * pi * (L_km*1000))^2) / (lambda^2);
    
    % Solve for Product Rt*Rr
    RtRr_product = sqrt((PtGtGr_equiv * lambda^2 * target_rcs) / ((4 * pi)^3 * min_detectable_pwr_lin));
    
    % 3. Convert to a "Max Range" estimate 
    % For simplicity, we report the max distance from the receiver (Rr) 
    % assuming the target is on the baseline.
    max_range_km = RtRr_product / 1000; 

    fprintf('\n--- Performance Coverage (Target RCS: %.1f m^2) ---\n', target_rcs);
    fprintf('Bistatic Baseline:     %.2f km\n', L_km);
    fprintf('Max Detection Product: %.2f km^2\n', (RtRr_product/1000)^2);
    fprintf('Estimated Max Range:   ~%.2f km from receiver\n', max_range_km);
end