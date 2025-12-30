function [detections, hFig] = compute_radar_caf_localized_TbxFns(inputSource, Fs, tx_gps, rx_gps,showPlots,useNitro)
% Final robust version: Accepts filename OR raw matrix
c = physconst('LightSpeed');
valid_data = zeros(0, 3);
hFig = []; % Initialize as empty in case showPlots is false

%% 1. Data Intake (The "Bridge" Logic)
if ischar(inputSource) || isstring(inputSource)
    % If called with a filename (e.g. for a single test)
    reader = comm.BasebandFileReader(inputSource);
    %sig = read(reader, floor(0.1 * Fs));
    %release(reader);
    reader.SamplesPerFrame = floor(0.1*Fs);
    sig = reader();

else
    % If called by File 1 with a raw matrix (The Batch Mode)
    sig = inputSource;
end

%% 2. Call File 3 (The Engine)
%[caf_map, delays, doppler] = compute_radar_caf(sig, Fs, 'suppressClutter', true);

%% 2. The Engine Switch
% This chooses which "File 3" to call based on your preference
if nargin > 5 && useNitro
    % CALL NITRO ENGINE
    [caf_map, delays, doppler] = compute_radar_caf_nitro(sig, Fs, 'suppressClutter', true);
else
    % CALL STANDARD ENGINE
    [caf_map, delays, doppler] = compute_radar_caf(sig, Fs, 'suppressClutter', true);
end

%% 3. CFAR Detection (Same as your current logic)
detector = phased.CFARDetector2D('Method', 'CA', 'GuardBandSize', [3 3], ...
    'TrainingBandSize', [5 5], 'ProbabilityFalseAlarm', 1e-6, 'OutputFormat', 'Detection index');

marginRow = 8; marginCol = 8;
rowsToTest = (1 + marginRow) : (size(caf_map,1) - marginRow);
colsToTest = (1 + marginCol) : (size(caf_map,2) - marginCol);
[rowGrid, colGrid] = meshgrid(rowsToTest, colsToTest);
indicesToTest = [rowGrid(:)'; colGrid(:)'];

detIndices = detector(caf_map, indicesToTest);

% ... [Rest of your Localization and Mapping Toolbox logic here] ...
% (Keep your Spline Refinement and Ellipse Plotting exactly as you have them)

% 3. Localization and Refinement
% Calculate baseline using Mapping Toolbox
L = distance(tx_gps(1), tx_gps(2), rx_gps(1), rx_gps(2), referenceEllipsoid('wgs84'));

%valid_data = [];
if ~isempty(detIndices)
    dop_idx = detIndices(1,:);
    del_idx = detIndices(2,:);

    for i = 1:length(del_idx)
        % Apply Guard Zones for site-specific clutter
        if delays(del_idx(i)) > 2.0 && abs(doppler(dop_idx(i))) > 5.0

            % Spline Refinement for sub-sample accuracy
            col = del_idx(i); row = dop_idx(i);
            sub_samples = col-1:0.05:col+1;
            refined_vals = interp1(1:size(caf_map,2), caf_map(row,:), sub_samples, 'spline');
            [~, max_idx] = max(refined_vals);

            ref_delay_us = delays(1) + (sub_samples(max_idx)-1)*(1/Fs)*1e6;
            total_path_m = (ref_delay_us/1e6 * c) + L;

            valid_data = [valid_data; ref_delay_us, doppler(row), total_path_m/1000]; %#ok<AGROW>
        end
    end
end

% Always initialize the table
detections = array2table(valid_data, 'VariableNames', {'Delay_us', 'Doppler_Hz', 'TotalPath_km'});

%% 4. Mapping Toolbox Visualization
if nargin < 5 || showPlots  % Default to true if not specified, otherwise check flag
    hFig = figure('Name', 'N320 Phase-Coherent Radar Display');
    ax = geoaxes;
    geobasemap(ax, 'streets'); hold(ax, 'on');

    % Plot Hardware
    geoplot(ax, tx_gps(1), tx_gps(2), 'r^', 'MarkerSize', 10, 'DisplayName', 'TV Tower');
    geoplot(ax, rx_gps(1), rx_gps(2), 'bs', 'MarkerSize', 10, 'DisplayName', 'N320 Site');

    % Plot Ellipses (only if detections found)
    if ~isempty(detections)
        for i = 1:height(detections)
            [lat_el, lon_el] = calculate_bistatic_ellipse(tx_gps, rx_gps, detections.TotalPath_km(i));
            geoplot(ax, lat_el, lon_el, 'g--', 'LineWidth', 2, 'HandleVisibility', 'off');
        end
        title(ax, sprintf('Detection Active: %d Targets', height(detections)));
    else
        title(ax, 'Scanning... No Targets Above Threshold');
    end
else
    % If showPlots is false, skip figure rendering
end
end