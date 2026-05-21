function [reference_channel, surveillance_channel, reference_cube, surveillance_cube] = loadIQData(filepath, numSamples, cpi_duration_s, fs, options)
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

%% 0. Options
if nargin < 5 || isempty(options), options = struct(); end
if ~isfield(options, 'swap_channels'), options.swap_channels = false; end

%% 1. Read IQ data
% Use comm.BasebandFileReader first — it reads the .bb header, determines the
% stored data type (double/single/int16), and returns correctly-typed complex
% data.  This is the format produced by comm.BasebandFileWriter (used in
% log_iq_n320_2antennas.m and PassiveRadarCollection_wPreFlightChecks.m).
%
% If the file is raw binary (e.g. captured by a UHD C++ utility as sc16),
% the reader throws an error and we fall back to the original int16 fread.
fprintf('Loading data from: %s\n', filepath);
try
    reader   = comm.BasebandFileReader(filepath, 'SamplesPerFrame', numSamples);
    raw_data = reader();    % [numSamples × num_channels] complex
    release(reader);
    if size(raw_data, 2) < 2
        error('loadIQData:insufficientChannels', ...
            'File has %d channel(s); 2-channel (surv + ref) capture expected.', ...
            size(raw_data, 2));
    end
    ch1_raw  = double(raw_data(:, 1));   % CH1 — RX1  (default: Surveillance)
    ch2_raw  = double(raw_data(:, 2));   % CH2 — RX2  (default: Reference)
    n_actual = size(raw_data, 1);
    fprintf('  BasebandFileReader: %d samples × %d channels (complex %s).\n', ...
        n_actual, size(raw_data, 2), class(raw_data));
catch me_bbr
    fprintf('  comm.BasebandFileReader failed: %s\n', me_bbr.message);
    fprintf('  Falling back to raw int16 binary read (sc16 format)...\n');
    fileID = fopen(filepath, 'r');
    if fileID == -1
        error('loadIQData:fileNotFound', ...
            'Cannot open ''%s''. Check path and permissions.', filepath);
    end
    rawInt16 = fread(fileID, 4 * numSamples, 'int16');
    fclose(fileID);
    fprintf('  Raw int16 read: %d values.\n', numel(rawInt16));
    % sc16 layout: I_ch1, Q_ch1, I_ch2, Q_ch2 repeating
    ch1_raw  = complex(double(rawInt16(1:4:end)), double(rawInt16(2:4:end)));
    ch2_raw  = complex(double(rawInt16(3:4:end)), double(rawInt16(4:4:end)));
    n_actual = numel(ch1_raw);
end
fprintf('  %d complex samples available per channel.\n', n_actual);

%% 2b. Per-channel power diagnostic
% Compare mean signal power of CH1 (RX1) and CH2 (RX2).
% The reference antenna (aimed at the ATSC tower) should be the stronger channel.
% If CH1 is significantly stronger, the cables may be swapped.
ch1_pwr      = mean(abs(ch1_raw).^2);
ch2_pwr      = mean(abs(ch2_raw).^2);
pwr_ratio_db = 10 * log10(ch1_pwr / max(ch2_pwr, eps));
fprintf('  CH1 (RX1) mean power: %.3e\n', ch1_pwr);
fprintf('  CH2 (RX2) mean power: %.3e\n', ch2_pwr);
fprintf('  CH1 / CH2 power ratio: %+.1f dB\n', pwr_ratio_db);
if pwr_ratio_db > 10
    fprintf(['  CHANNEL DIAGNOSTIC: CH1 is %.0f dB stronger than CH2.\n' ...
             '  Default: CH1=Surveillance, CH2=Reference.\n' ...
             '  If the reference antenna is on RX1, set config.swap_channels = true.\n'], ...
             pwr_ratio_db);
elseif pwr_ratio_db < -10
    fprintf('  Channel powers nominal: CH2 (Reference) is %.0f dB stronger than CH1.\n', -pwr_ratio_db);
end

%% 3. Channel assignment
if options.swap_channels
    surveillance_channel = ch2_raw;   % CH2 (RX2) → Surveillance
    reference_channel    = ch1_raw;   % CH1 (RX1) → Reference
    fprintf('  Channel assignment SWAPPED: CH2→Surveillance, CH1→Reference.\n');
else
    surveillance_channel = ch1_raw;   % CH1 (RX1) → Surveillance (default)
    reference_channel    = ch2_raw;   % CH2 (RX2) → Reference (default)
end

%% 4. Verification
fprintf('\n--- Verification ---\n');
fprintf('Size of Reference Channel data: [%d, %d]\n', size(reference_channel, 1), size(reference_channel, 2));
fprintf('Size of Surveillance Channel data: [%d, %d]\n', size(surveillance_channel, 1), size(surveillance_channel, 2));
if numel(reference_channel) == numel(surveillance_channel)
    fprintf('Channel assignment successful.\n');
else
    fprintf('Warning: channel size mismatch (%d vs %d).\n', numel(reference_channel), numel(surveillance_channel));
end

%% 5. Reshape Data into Data Cube
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
fprintf('CPI duration: %.2f ms  |  PRF: %.0f Hz  |  N_fast: %d  |  N_slow: %d\n', ...
    cpi_duration_s*1e3, 1/cpi_duration_s, samples_per_cpi, num_cpis);

end
