%% Passive Radar Engine Benchmark
% Compares Standard (xcorr) vs Nitro (FFT) engines for speed and accuracy

% 1. Setup
fname = 'n320_dual_capture_Dec29_1pm.bb';
Fs = 6.144e6;
tx_gps = [42.311389, -71.216111];
rx_gps = [42.3007, -71.3490];

% 2. Get a single slice of data
reader = comm.BasebandFileReader(fname);
reader.SamplesPerFrame = round(0.1 * Fs);
sigSlice = reader();
release(reader);

fprintf('--- Starting Benchmark (0.1s CPI) ---\n');

% 3. Test Standard Engine
tic;
[det_std, ~] = compute_radar_caf_localized_TbxFns(sigSlice, Fs, tx_gps, rx_gps, false, false);
t_std = toc;
fprintf('Standard Engine Time: %.4f seconds\n', t_std);

% 4. Test Nitro Engine
tic;
[det_nitro, ~] = compute_radar_caf_localized_TbxFns(sigSlice, Fs, tx_gps, rx_gps, false, true);
t_nitro = toc;
fprintf('Nitro Engine Time:    %.4f seconds\n', t_nitro);

% 5. Performance Report
speedup = t_std / t_nitro;
fprintf('-------------------------------------\n');
fprintf('Nitro Speedup:        %.2fx faster\n', speedup);

% 6. Numerical Validation
if height(det_std) == height(det_nitro)
    fprintf('Validation:           PASS (Same number of targets)\n');
else
    fprintf('Validation:           WARNING (Target count mismatch!)\n');
end