%% IQDataProcessing_Production.m
% High-speed batch processor for N320 Passive Radar datasets

% --- Production Settings ---
useNitro      = true;   
showPlots     = false;  
saveConsolidated = true; 

% --- Configuration ---
bigFile = 'n320_dual_capture_Dec29_230pm.bb';
fs = 6.144e6;
cpi_duration = 0.1; 
tx_gps = [42.311389, -71.216111];
rx_gps = [42.3007, -71.3490];

% --- Initialize Reader & Progress Tracking ---
reader = comm.BasebandFileReader(bigFile);
reader.SamplesPerFrame = round(cpi_duration * fs); 

% CORRECTED: Get file info using the info() method
file_info = info(reader); 
total_samples = file_info.NumSamplesInData; 
total_slices = floor(total_samples / reader.SamplesPerFrame);

allDetections = table(); 
sliceCount = 0;
tic; 

fprintf('Starting Production Run on: %s\n', bigFile);
fprintf('Total slices to process: %d\n', total_slices);

while ~isDone(reader)
    % 1. Read raw IQ
    sigSlice = reader(); 
    
    sliceCount = sliceCount + 1;
    currentTime = (sliceCount - 1) * cpi_duration;
    
    % 2. Process through Wrapper
    [detections, hFig] = compute_radar_caf_localized_TbxFns(sigSlice, fs, tx_gps, rx_gps, showPlots, useNitro);
    
    % 3. Collect Data
    if ~isempty(detections)
        detections.TimeOffset = repmat(currentTime, height(detections), 1);
        allDetections = [allDetections; detections]; 
    end
    
    % 4. PROGRESS BAR
    if mod(sliceCount, 10) == 0 || isDone(reader)
        elapsed = toc;
        avg_time_per_slice = elapsed / sliceCount;
        remaining_slices = total_slices - sliceCount;
        eta_seconds = remaining_slices * avg_time_per_slice;
        
        if eta_seconds > 3600
            eta_str = sprintf('%.2f hours', eta_seconds/3600);
        elseif eta_seconds > 60
            eta_str = sprintf('%.1f minutes', eta_seconds/60);
        else
            eta_str = sprintf('%d seconds', round(eta_seconds));
        end
        
        fprintf('--- Progress: %.1f%% | ETA: %s ---\n', ...
            (sliceCount/total_slices)*100, eta_str);
    end
    
    if ~isempty(hFig) && isvalid(hFig), close(hFig); end
end

% --- Finalize ---
release(reader);
if saveConsolidated && ~isempty(allDetections)
    outputName = ['Results_', bigFile(1:end-3), '.csv'];
    writetable(allDetections, outputName);
    fprintf('Processing Complete! Results saved to %s\n', outputName);
else
    fprintf('Processing Complete. No targets found in %d slices.\n', sliceCount);
end