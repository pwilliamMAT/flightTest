%% PassiveRadarCollection_wPreFlightChecks.m
% Mission Control Wrapper for N320 Passive Radar Collection
% Validates Linux OS, Hardware Health, and Channel Synchronization.

% --- 1. CONFIGURATION ---
test_dur = 10;                % 10 second dry-run
prod_dur = 10; %2 * 3600;          % 2 hour production run (7200s)
output_file = sprintf('n320_dual_capture_%s.bb', datestr(now, 'yyyymmdd_HHMM'));
test_file   = 'preflight_sanity_check.bb';
fs = 6.144e6;                 % Sample Rate

% --- 2. SYSTEM HARDENING (Linux Optimization) ---
if isunix
    fprintf('--- Applying Linux Kernel Optimizations ---\n');
    % Force Network Buffers to 50MB
    system('echo 50000000 | sudo tee /proc/sys/net/core/rmem_max > /dev/null');
    system('echo 50000000 | sudo tee /proc/sys/net/core/wmem_max > /dev/null');
    
    % Force CPU to Performance Mode (3.2GHz+)
    system('echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null');
    
    % Verify rmem_max
    [~, rmem_val] = system('cat /proc/sys/net/core/rmem_max');
    fprintf('Verified rmem_max: %s', rmem_val);
end

% --- 3. RUN DRY-RUN (10s) ---
fprintf('\n>>> STEP 1: Running 10s Pre-Flight Test...\n');
% Calls your existing logger function
log_iq_n320_2antennas('dur', test_dur, 'file', test_file, 'gain', [30, 50]);

% --- 4. ANALYZE DATA INTEGRITY & TIME SYNC ---
fprintf('\n>>> STEP 2: Analyzing Data Integrity & Time-Sync...\n');
reader = comm.BasebandFileReader(test_file);
test_data = reader(); % Read first large block of samples

% A. Check for Zeros (Dropped Packets/Disk Bottleneck)
if any(test_data(:) == 0)
    error('CRITICAL: Zeros detected in data. Check Disk/Network performance!');
end

% B. Channel Count Check
if size(test_data, 2) < 2
    error('CRITICAL: Only %d channel(s) detected. Check USRP ChannelMapping!', size(test_data, 2));
end

% C. Signal Power Check (SNR)
pwr = mean(abs(test_data).^2);
fprintf('Channel 1 (Surv) Power: %.2e | Channel 2 (Ref) Power: %.2e\n', pwr(1), pwr(2));
if any(pwr < 1e-7)
    error('CRITICAL: Signal power too low. Are the antennas connected?');
end

% D. TIME-SYNC CHECK (Cross-Correlation)
% We correlate Ch1 and Ch2 to find the "Direct Path" peak.
% A sharp, stable peak confirms the channels are sample-locked.
[xc, lags] = xcorr(test_data(1:100000, 1), test_data(1:100000, 2), 1000);
[max_val, max_idx] = max(abs(xc));
peak_lag = lags(max_idx);
peak_to_noise = max_val / mean(abs(xc));

fprintf('Sync Check: Peak Lag = %d samples | Peak-to-Noise Ratio = %.1f\n', peak_lag, peak_to_noise);

if peak_to_noise < 10
    warning('SYNC WARNING: Weak correlation peak. Direct path signal may be blocked.');
else
    fprintf('SUCCESS: Channels are phase-locked and synchronized.\n');
end

release(reader);

% --- 5. DISK SPACE CHECK ---
[~, disk_info] = system('df -h . | tail -1 | awk ''{print $4}''');
fprintf('Available Disk Space: %s\n', strtrim(disk_info));

% --- 6. START PRODUCTION RUN ---
fprintf('\n>>> STEP 3: Starting 2-Hour Production Capture: %s\n', output_file);
log_iq_n320_2antennas('dur', prod_dur, 'file', output_file, 'gain', [30, 50]);

fprintf('Mission Complete. File saved as %s\n', output_file);