function [reference_channel, surveillance_channel, reference_cube, surveillance_cube] = loadIQData(filepath, numSamples, cpi_duration_s, fs)
% loadIQData  Loads and processes raw IQ data from a USRP N320 binary file.
%
%   [ref_ch, surv_ch, ref_cube, surv_cube] = loadIQData(filepath, numSamples, cpi_duration_s, fs)
%
%   This function reads raw interleaved IQ data from a specified binary file,
%   separates it into reference and surveillance channels, and reshapes it
%   into a data cube for radar processing.
%
%   Inputs:
%   - filepath:       Path to the binary data file.
%   - numSamples:     Total number of complex samples per channel to read.
%   - cpi_duration_s: Desired Coherent Processing Interval (CPI) in seconds.
%   - fs:             The sampling rate in Hz.
%
%   Outputs:
%   - reference_channel:    [numSamples x 1] complex vector for the reference channel.
%   - surveillance_channel: [numSamples x 1] complex vector for the surveillance channel.
%   - reference_cube:       [samples_per_cpi x num_cpis] complex matrix for the reference channel.
%   - surveillance_cube:    [samples_per_cpi x num_cpis] complex matrix for the surveillance channel.
%

%% 1. Define Data Format
precision = 'int16'; % Data format is 16-bit signed integers

%% 2. Open and Read the Binary Data
fprintf('Loading data from: %s\n', filepath);

% Open the file for reading
fileID = fopen(filepath, 'r');
if fileID == -1
    error('Failed to open file. Check the path and permissions.');
end

% Read the raw interleaved data. Since each complex sample has I and Q, and
% we have two channels, we need to read 4 * numSamples values.
rawData = fread(fileID, 4 * numSamples, precision);
fclose(fileID);

fprintf('Successfully loaded %d raw samples.\n', numel(rawData));

%% 3. De-interleave the Data
% The data is interleaved as I_ref, Q_ref, I_surv, Q_surv.

% Extract reference channel data
ref_I = rawData(1:4:end);
ref_Q = rawData(2:4:end);

% Extract surveillance channel data
surv_I = rawData(3:4:end);
surv_Q = rawData(4:4:end);

%% 4. Convert to Complex Values
% Combine I and Q components into complex numbers
reference_channel = complex(double(ref_I), double(ref_Q));
surveillance_channel = complex(double(surv_I), double(surv_Q));

%% 5. Verification
fprintf('\n--- Verification ---\n');
fprintf('Size of Reference Channel data: [%d, %d]\n', size(reference_channel, 1), size(reference_channel, 2));
fprintf('Size of Surveillance Channel data: [%d, %d]\n', size(surveillance_channel, 1), size(surveillance_channel, 2));
if (numel(reference_channel) == numel(surveillance_channel)) && (numel(rawData) / 4 == numel(reference_channel))
    fprintf('Data de-interleaving appears successful.\n');
else
    fprintf('Warning: There might be an issue with the de-interleaving process.\n');
end

%% 6. Reshape Data into Data Cube
% --- Calculations ---
% Samples per CPI (fast-time dimension)
samples_per_cpi = round(cpi_duration_s * fs);

% Total number of samples available in each channel
total_samples = numel(surveillance_channel);

% Number of full CPIs we can form (slow-time dimension)
num_cpis = floor(total_samples / samples_per_cpi);

% --- Reshaping ---
% Truncate the data to fit into an integer number of CPIs
truncated_length = samples_per_cpi * num_cpis;
surv_truncated = surveillance_channel(1:truncated_length);
ref_truncated = reference_channel(1:truncated_length);

% Reshape the truncated vectors into the data cubes
surveillance_cube = reshape(surv_truncated, samples_per_cpi, num_cpis);
reference_cube = reshape(ref_truncated, samples_per_cpi, num_cpis);

fprintf('\n--- Data Cube Creation ---\n');
fprintf('Data reshaped into a %d x %d data cube.\n', samples_per_cpi, num_cpis);
fprintf('This corresponds to %.2f seconds of data per CPI.\n', cpi_duration_s);

end

% --- Truncate and Reshape ---
% We truncate the data to an integer number of CPIs to make reshaping easy.
samples_for_cube = num_cpis * samples_per_cpi;
surv_channel_truncated = surveillance_channel(1:samples_for_cube);
ref_channel_truncated = reference_channel(1:samples_for_cube);

% Reshape the 1D vectors into 2D data cubes.
% Each column is one CPI. The data is filled column-wise.
surveillance_cube = reshape(surv_channel_truncated, samples_per_cpi, num_cpis);
reference_cube = reshape(ref_channel_truncated, samples_per_cpi, num_cpis);

%% 7. Verification of Data Cube
fprintf('\n--- Data Cube Verification ---\n');
fprintf('Sampling Rate (fs): %.2f MHz\n', fs / 1e6);
fprintf('CPI Duration: %.2f ms\n', cpi_duration_s * 1e3);
fprintf('Samples per CPI (Fast-Time): %d\n', samples_per_cpi);
fprintf('Number of CPIs (Slow-Time): %d\n', num_cpis);
fprintf('Size of Surveillance Data Cube: [%d, %d]\n', size(surveillance_cube, 1), size(surveillance_cube, 2));
fprintf('Size of Reference Data Cube: [%d, %d]\n', size(reference_cube, 1), size(reference_cube, 2));

%% 8. Educational Visualization: Waterfall Plot
% This plot helps us "see" the radar data.
% The y-axis is fast-time (related to range).
% The x-axis is slow-time (different CPIs or "looks").
% The color represents the signal strength.
% We expect to see strong horizontal bands, which are the powerful direct
% signals from the HDTV tower.

figure; % Create a new figure window
imagesc(pow2db(abs(surveillance_cube).^2));
title('Waterfall Display of Surveillance Channel');
xlabel('Slow-Time (CPI Number)');
ylabel('Fast-Time (Sample Number in CPI)');
colorbar;
clim_vals = get(gca, 'clim'); % Get the current color limits
set(gca, 'clim', clim_vals + [-20 0]); % Adjust color limits to see weaker signals
fprintf('\nGenerated waterfall plot for visual inspection.\n');
