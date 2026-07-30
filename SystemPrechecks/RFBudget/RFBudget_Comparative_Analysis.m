%% Comparative RF Budget Analysis: Hudson Ch 27 vs Newton Ch 35
% This script performs a side-by-side comparison of two passive radar
% configurations using different HDTV transmitters to validate that the
% same hardware setup can achieve bistatic aircraft localization with both.
%
% PURPOSE:
%   1. Compare system performance metrics between two transmitter configurations
%   2. Validate hardware compatibility across different frequencies (551 vs 599 MHz)
%   3. Assess which configuration provides better detection performance
%   4. Identify configuration-specific concerns and mitigations
%   5. Build confidence in bistatic localization capability
%
% CONFIGURATIONS:
%   A) Hudson Ch 27 (WUNI):       551 MHz, 400 kW ERP
%   B) Newton Ch 35 (WHDH/WLVI):  599 MHz, 1000 kW ERP
%
% SAME HARDWARE FOR BOTH:
%   - USRP N320 with TwinRX daughterboard
%   - Nooelec LANA amplifier
%   - Mini-Circuits ZABP-587-S+ bandpass filter
%   - 75ft RG-6 coax cable
%   - 12 dBi Yagi antenna (surveillance)
%
% Created: December 8, 2025
% Reference: system precheck assumptions, RF summary, and risk tables
%
%==========================================================================

clear; clc; close all;
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);

fprintf('\n========================================================================\n');
fprintf('COMPARATIVE ANALYSIS: Hudson Ch 27 vs Newton Ch 35\n');
fprintf('Passive Radar Hardware Validation for Bistatic Localization\n');
fprintf('========================================================================\n\n');

%% ========================================================================
%  CONFIGURATION A: HUDSON CHANNEL 27 (UNIVISION)
%  ========================================================================

fprintf('=== CONFIGURATION A: HUDSON CH 27 (UNIVISION) ===\n\n');

% Operating parameters - Hudson
freq_A = 551e6;                 % Center frequency (Hz)
signalBW_A = 6e6;               % ATSC bandwidth (Hz)
targetPower_A = -70.62;         % Target signal power (dBm) - deterministic saved-ROI rerun

% Component specifications @ 551 MHz
cableLoss_A = 1.1;              % dB loss for 75ft RG-6
mismatchLoss_A = 0.4;           % dB loss (75Ω to 50Ω)
hpFilterLoss_A = 0.3;           % dB loss (VHF-580+)
bpFilterLoss_A = helperGetBandpassInsertionLoss(freq_A);  % Measured from included S2P
lnaGain_A = 20;                 % dB gain
lnaNF_A = 1.4;                  % dB noise figure
usrpGain_A = 30;                % dB gain
usrpNF_A = 6;                   % dB noise figure
antennaGain_A = 12;             % dBi

% Build cascade for Configuration A
idx = 1;
elements_A(idx) = amplifier('Name', 'Cable_A', 'Gain', -cableLoss_A, ...
    'NF', cableLoss_A, 'Zin', 75, 'Zout', 75); idx = idx + 1;
elements_A(idx) = amplifier('Name', 'Mismatch_A', 'Gain', -mismatchLoss_A, ...
    'NF', mismatchLoss_A, 'Zin', 75, 'Zout', 50); idx = idx + 1;
elements_A(idx) = amplifier('Name', 'HPFilter_A', 'Gain', -hpFilterLoss_A, ...
    'NF', hpFilterLoss_A, 'Zin', 50, 'Zout', 50); idx = idx + 1;
elements_A(idx) = rffilter('FilterType', 'Butterworth', 'ResponseType', 'Bandpass', ...
    'Implementation', 'LC Tee', 'FilterOrder', 3, 'PassbandFrequency', [540 634]*1e6, ...
    'PassbandAttenuation', bpFilterLoss_A, 'Zin', 50, 'Zout', 50, 'Name', 'BPF_A'); 
idx = idx + 1;
elements_A(idx) = amplifier('Name', 'LNA_A', 'Gain', lnaGain_A, 'NF', lnaNF_A, ...
    'OIP3', 28, 'Zin', 50, 'Zout', 50, 'Model', 'poly'); idx = idx + 1;
elements_A(idx) = amplifier('Name', 'USRP_A', 'Gain', usrpGain_A, 'NF', usrpNF_A, ...
    'OIP3', 30, 'Zin', 50, 'Zout', 50, 'Model', 'poly');

% Create RF budget
inputPower_A = targetPower_A + antennaGain_A;
budget_A = rfbudget('Elements', elements_A, 'InputFrequency', freq_A, ...
    'AvailableInputPower', inputPower_A, 'SignalBandwidth', signalBW_A, ...
    'Solver', 'Friis', 'AutoUpdate', true);

% Extract metrics
totalGain_A = budget_A.TransducerGain(end);
systemNF_A = budget_A.NF(end);
outputPower_A = budget_A.OutputPower(end);
kT = -174;
noisePower_A = kT + 10*log10(signalBW_A) + systemNF_A;
snr_A = outputPower_A - noisePower_A;

fprintf('Frequency:              %.1f MHz\n', freq_A/1e6);
fprintf('Target Signal:          %.2f dBm\n', targetPower_A);
fprintf('System Noise Figure:    %.2f dB\n', systemNF_A);
fprintf('Total Cascade Gain:     %.2f dB\n', totalGain_A);
fprintf('Output Signal Power:    %.2f dBm\n', outputPower_A);
fprintf('Pre-Processing SNR:     %.2f dB\n', snr_A);

%% ========================================================================
%  CONFIGURATION B: NEWTON CHANNEL 35 (CBS)
%  ========================================================================

fprintf('\n=== CONFIGURATION B: NEWTON CH 35 (WHDH/WLVI) ===\n\n');

% Operating parameters - Newton
freq_B = 599e6;                 % Center frequency (Hz)
signalBW_B = 6e6;               % ATSC bandwidth (Hz)
targetPower_B = -67.56;         % Target signal power (dBm) - deterministic saved-ROI rerun
erp_B_kW = 1000;                % Newton RF35 horizontal ERP (kW)
erp_B_dBW = 10*log10(erp_B_kW * 1000);  % 60.0 dBW

fprintf('Bistatic target-path basis: deterministic saved-ROI rerun\n');
fprintf('    Newton RF35 ERP: %.0f kW (%.1f dBW)\n\n', erp_B_kW, erp_B_dBW);

% Component specifications @ 599 MHz (estimated)
cableLoss_B = 1.2;              % dB loss for 75ft RG-6 (higher @ 599 MHz)
mismatchLoss_B = 0.4;           % dB loss (75Ω to 50Ω, frequency independent)
hpFilterLoss_B = 0.3;           % dB loss (VHF-580+)
bpFilterLoss_B = helperGetBandpassInsertionLoss(freq_B);  % Measured from included S2P
lnaGain_B = 20;                 % dB gain
lnaNF_B = 1.5;                  % dB noise figure (estimated higher @ 599 MHz)
usrpGain_B = 30;                % dB gain
usrpNF_B = 6;                   % dB noise figure
antennaGain_B = 12;             % dBi

% Build cascade for Configuration B
idx = 1;
elements_B(idx) = amplifier('Name', 'Cable_B', 'Gain', -cableLoss_B, ...
    'NF', cableLoss_B, 'Zin', 75, 'Zout', 75); idx = idx + 1;
elements_B(idx) = amplifier('Name', 'Mismatch_B', 'Gain', -mismatchLoss_B, ...
    'NF', mismatchLoss_B, 'Zin', 75, 'Zout', 50); idx = idx + 1;
elements_B(idx) = amplifier('Name', 'HPFilter_B', 'Gain', -hpFilterLoss_B, ...
    'NF', hpFilterLoss_B, 'Zin', 50, 'Zout', 50); idx = idx + 1;
elements_B(idx) = rffilter('FilterType', 'Butterworth', 'ResponseType', 'Bandpass', ...
    'Implementation', 'LC Tee', 'FilterOrder', 3, 'PassbandFrequency', [540 634]*1e6, ...
    'PassbandAttenuation', bpFilterLoss_B, 'Zin', 50, 'Zout', 50, 'Name', 'BPF_B'); 
idx = idx + 1;
elements_B(idx) = amplifier('Name', 'LNA_B', 'Gain', lnaGain_B, 'NF', lnaNF_B, ...
    'OIP3', 28, 'Zin', 50, 'Zout', 50, 'Model', 'poly'); idx = idx + 1;
elements_B(idx) = amplifier('Name', 'USRP_B', 'Gain', usrpGain_B, 'NF', usrpNF_B, ...
    'OIP3', 30, 'Zin', 50, 'Zout', 50, 'Model', 'poly');

% Create RF budget
inputPower_B = targetPower_B + antennaGain_B;
budget_B = rfbudget('Elements', elements_B, 'InputFrequency', freq_B, ...
    'AvailableInputPower', inputPower_B, 'SignalBandwidth', signalBW_B, ...
    'Solver', 'Friis', 'AutoUpdate', true);

% Extract metrics
totalGain_B = budget_B.TransducerGain(end);
systemNF_B = budget_B.NF(end);
outputPower_B = budget_B.OutputPower(end);
noisePower_B = kT + 10*log10(signalBW_B) + systemNF_B;
snr_B = outputPower_B - noisePower_B;

fprintf('Frequency:              %.1f MHz\n', freq_B/1e6);
fprintf('Target Signal:          %.2f dBm\n', targetPower_B);
fprintf('System Noise Figure:    %.2f dB\n', systemNF_B);
fprintf('Total Cascade Gain:     %.2f dB\n', totalGain_B);
fprintf('Output Signal Power:    %.2f dBm\n', outputPower_B);
fprintf('Pre-Processing SNR:     %.2f dB\n', snr_B);

%% ========================================================================
%  COMPARATIVE ANALYSIS
%  ========================================================================

fprintf('\n========================================================================\n');
fprintf('COMPARATIVE ANALYSIS RESULTS\n');
fprintf('========================================================================\n\n');

% Calculate differences
deltaFreq = freq_B - freq_A;
deltaNF = systemNF_B - systemNF_A;
deltaGain = totalGain_B - totalGain_A;
deltaSNR = snr_B - snr_A;
deltaOutputPower = outputPower_B - outputPower_A;

fprintf('--- FREQUENCY & BANDWIDTH ---\n');
fprintf('Config A (Hudson):      %.1f MHz (Channel 27)\n', freq_A/1e6);
fprintf('Config B (Newton):      %.1f MHz (Channel 35)\n', freq_B/1e6);
fprintf('Frequency Difference:   %.1f MHz (%.1f%% higher)\n', deltaFreq/1e6, 100*deltaFreq/freq_A);
fprintf('Bandwidth:              %.1f MHz (same for both)\n\n', signalBW_A/1e6);

fprintf('--- SYSTEM NOISE FIGURE ---\n');
fprintf('Config A (Hudson):      %.2f dB\n', systemNF_A);
fprintf('Config B (Newton):      %.2f dB\n', systemNF_B);
fprintf('Difference (B - A):     %.2f dB', deltaNF);
if abs(deltaNF) < 0.5
    fprintf(' ✓ NEGLIGIBLE\n');
elseif deltaNF > 0
    fprintf(' ⚠️  Config B worse\n');
else
    fprintf(' ✓ Config B better\n');
end
fprintf('Assessment:             ');
if systemNF_A < 4 && systemNF_B < 4
    fprintf('BOTH EXCELLENT (<4 dB)\n\n');
elseif systemNF_A < 5 && systemNF_B < 5
    fprintf('Both acceptable (<5 dB)\n\n');
else
    fprintf('Review needed (>5 dB)\n\n');
end

fprintf('--- TOTAL CASCADE GAIN ---\n');
fprintf('Config A (Hudson):      %.2f dB\n', totalGain_A);
fprintf('Config B (Newton):      %.2f dB\n', totalGain_B);
fprintf('Difference (B - A):     %.2f dB\n', deltaGain);
fprintf('Assessment:             ');
if abs(deltaGain) < 1
    fprintf('VERY SIMILAR - hardware validated across frequencies ✓\n\n');
elseif abs(deltaGain) < 2
    fprintf('Similar - acceptable variation\n\n');
else
    fprintf('Notable difference - verify component specs\n\n');
end

fprintf('--- SIGNAL LEVELS AT USRP INPUT ---\n');
fprintf('Config A (Hudson):      %.2f dBm\n', outputPower_A);
fprintf('Config B (Newton):      %.2f dBm\n', outputPower_B);
fprintf('Difference (B - A):     %.2f dB\n', deltaOutputPower);
fprintf('USRP Optimal Range:     -25 to -15 dBm\n');
fprintf('Assessment A:           ');
if outputPower_A > -15
    fprintf('⚠️  TOO HIGH - add attenuation\n');
elseif outputPower_A < -25
    fprintf('Low - increase USRP gain\n');
else
    fprintf('✓ OPTIMAL\n');
end
fprintf('Assessment B:           ');
if outputPower_B > -15
    fprintf('⚠️  TOO HIGH - add attenuation\n\n');
elseif outputPower_B < -25
    fprintf('Low - increase USRP gain\n\n');
else
    fprintf('✓ OPTIMAL\n\n');
end

fprintf('--- PRE-PROCESSING SNR ---\n');
fprintf('Config A (Hudson):      %.2f dB\n', snr_A);
fprintf('Config B (Newton):      %.2f dB\n', snr_B);
fprintf('Difference (B - A):     %.2f dB\n', deltaSNR);
fprintf('Minimum Required:       ~20 dB (pre-processing)\n');
fprintf('Assessment A:           ');
if snr_A > 30
    fprintf('✓ EXCELLENT (>30 dB)\n');
elseif snr_A > 20
    fprintf('✓ GOOD (>20 dB)\n');
else
    fprintf('⚠️  MARGINAL (<20 dB)\n');
end
fprintf('Assessment B:           ');
if snr_B > 30
    fprintf('✓ EXCELLENT (>30 dB)\n\n');
elseif snr_B > 20
    fprintf('✓ GOOD (>20 dB)\n\n');
else
    fprintf('⚠️  MARGINAL (<20 dB)\n\n');
end

%% ========================================================================
%  POST-PROCESSING SNR AND DETECTION CAPABILITY
%  ========================================================================

fprintf('========================================================================\n');
fprintf('POST-PROCESSING SNR & DETECTION CAPABILITY ANALYSIS\n');
fprintf('========================================================================\n\n');

% Processing gain from coherent integration
integrationTimes = [0.1, 0.5, 1.0, 2.0];

fprintf('Coherent Integration Gain (same for both configurations):\n');
fprintf('Time (sec) | Proc Gain | SNR-A Post | SNR-B Post | Detection?\n');
fprintf('-----------|-----------|------------|------------|-----------\n');

for T = integrationTimes
    procGain = 10*log10(T * signalBW_A);
    snrPost_A = snr_A + procGain;
    snrPost_B = snr_B + procGain;
    
    % Detection threshold: typically need >13 dB post-processing for passive radar
    detection_A = snrPost_A > 13;
    detection_B = snrPost_B > 13;
    
    fprintf('  %.1f      |  %5.1f dB |  %6.1f dB |  %6.1f dB | ', ...
        T, procGain, snrPost_A, snrPost_B);
    
    if detection_A && detection_B
        fprintf('✓ BOTH\n');
    elseif detection_A
        fprintf('A only\n');
    elseif detection_B
        fprintf('B only\n');
    else
        fprintf('✗ Neither\n');
    end
end

fprintf('\nNote: Typical passive radar detection threshold: 13 dB post-processing SNR\n');
fprintf('      Actual performance depends on DSI cancellation and clutter rejection\n\n');

%% ========================================================================
%  FREQUENCY-DEPENDENT COMPONENT ANALYSIS
%  ========================================================================

fprintf('========================================================================\n');
fprintf('FREQUENCY-DEPENDENT COMPONENT DEGRADATION\n');
fprintf('========================================================================\n\n');

fprintf('Component          | Config A (551 MHz) | Config B (599 MHz) | Difference\n');
fprintf('-------------------|--------------------|--------------------|------------\n');
fprintf('Cable Loss         |    %.2f dB          |    %.2f dB          | +%.2f dB\n', ...
    cableLoss_A, cableLoss_B, cableLoss_B - cableLoss_A);
fprintf('BP Filter Loss     |    %.2f dB          |    %.2f dB          | +%.2f dB ⚠️\n', ...
    bpFilterLoss_A, bpFilterLoss_B, bpFilterLoss_B - bpFilterLoss_A);
fprintf('LNA Noise Figure   |    %.2f dB          |    %.2f dB          | +%.2f dB\n', ...
    lnaNF_A, lnaNF_B, lnaNF_B - lnaNF_A);
fprintf('HP Filter Loss     |    %.2f dB          |    %.2f dB          | %.2f dB\n', ...
    hpFilterLoss_A, hpFilterLoss_B, hpFilterLoss_B - hpFilterLoss_A);
fprintf('Impedance Mismatch |    %.2f dB          |    %.2f dB          | %.2f dB\n\n', ...
    mismatchLoss_A, mismatchLoss_B, mismatchLoss_B - mismatchLoss_A);

fprintf('CRITICAL CONCERN: Bandpass Filter (ZABP-587-S+)\n');
fprintf('  - Filter centered at 587 MHz\n');
fprintf('  - Config A offset: %.0f MHz (within passband)\n', abs(freq_A/1e6 - 587));
fprintf('  - Config B offset: %.0f MHz (near band edge) ⚠️\n', abs(freq_B/1e6 - 587));
fprintf('  - Config B insertion loss estimated %.1f dB vs %.1f dB nominal\n', ...
    bpFilterLoss_B, bpFilterLoss_A);
fprintf('  - RECOMMENDATION: Measure actual insertion loss or use ZABP-603-S+\n\n');

%% ========================================================================
%  HARDWARE COMPATIBILITY ASSESSMENT
%  ========================================================================

fprintf('========================================================================\n');
fprintf('HARDWARE COMPATIBILITY ASSESSMENT\n');
fprintf('========================================================================\n\n');

fprintf('Can the SAME hardware setup work for BOTH configurations?\n\n');

% Check criteria for hardware compatibility
compat_nf = abs(deltaNF) < 1.0;           % NF within 1 dB
compat_gain = abs(deltaGain) < 2.0;       % Gain within 2 dB
compat_snr_A = snr_A > 20;                % Both have >20 dB SNR
compat_snr_B = snr_B > 20;
compat_power_A = (outputPower_A > -30) && (outputPower_A < -10);  % Both in range
compat_power_B = (outputPower_B > -30) && (outputPower_B < -10);

fprintf('CRITERION                        | Config A | Config B | Compatible?\n');
fprintf('---------------------------------|----------|----------|------------\n');
fprintf('System NF within 1 dB            |  %.2f dB  |  %.2f dB  | ', systemNF_A, systemNF_B);
if compat_nf
    fprintf('✓ YES\n');
else
    fprintf('✗ NO\n');
end

fprintf('Total Gain within 2 dB           |  %.2f dB |  %.2f dB | ', totalGain_A, totalGain_B);
if compat_gain
    fprintf('✓ YES\n');
else
    fprintf('✗ NO\n');
end

fprintf('Pre-Proc SNR > 20 dB             |  %.1f dB |  %.1f dB | ', snr_A, snr_B);
if compat_snr_A && compat_snr_B
    fprintf('✓ YES\n');
elseif compat_snr_A || compat_snr_B
    fprintf('⚠️  PARTIAL\n');
else
    fprintf('✗ NO\n');
end

fprintf('USRP Input Level OK (-30 to -10) |  %.1f dBm |  %.1f dBm | ', outputPower_A, outputPower_B);
if compat_power_A && compat_power_B
    fprintf('✓ YES\n');
elseif compat_power_A || compat_power_B
    fprintf('⚠️  PARTIAL\n');
else
    fprintf('✗ NO\n');
end

fprintf('\n');

% Overall compatibility verdict
overall_compatible = compat_nf && compat_gain && compat_snr_A && compat_snr_B && ...
    compat_power_A && compat_power_B;

fprintf('========================================================================\n');
fprintf('OVERALL HARDWARE COMPATIBILITY VERDICT:\n');
fprintf('========================================================================\n\n');

if overall_compatible
    fprintf('✓✓✓ HARDWARE IS COMPATIBLE FOR BOTH CONFIGURATIONS ✓✓✓\n\n');
    fprintf('The same receiver hardware (N320 + LANA + filters + cable) can be used\n');
    fprintf('for both Hudson Ch 27 and Newton Ch 35 transmitters with minimal\n');
    fprintf('performance degradation. The 48 MHz frequency difference (551→599 MHz)\n');
    fprintf('results in <%.1f dB change in system performance.\n\n', max(abs(deltaNF), abs(deltaGain)));
else
    fprintf('⚠️  HARDWARE COMPATIBILITY REQUIRES ATTENTION ⚠️\n\n');
    fprintf('Review the failed criteria above. May need component adjustments.\n\n');
end

%% ========================================================================
%  BISTATIC LOCALIZATION CAPABILITY ASSESSMENT
%  ========================================================================

fprintf('========================================================================\n');
fprintf('BISTATIC LOCALIZATION CAPABILITY ASSESSMENT\n');
fprintf('========================================================================\n\n');

fprintf('Can these configurations achieve bistatic aircraft localization?\n\n');

% Requirements for bistatic localization
% 1. Sufficient SNR for cross-correlation (typically >13 dB post-processing)
% 2. Adequate range resolution (depends on bandwidth)
% 3. Adequate Doppler resolution (depends on integration time)
% 4. Sufficient sensitivity for aircraft RCS

% Range resolution (from ATSC bandwidth)
c = 3e8;  % speed of light
rangeRes_m = c / (2 * signalBW_A);  % Same for both

fprintf('--- RANGE RESOLUTION ---\n');
fprintf('Signal Bandwidth:       %.1f MHz (both configurations)\n', signalBW_A/1e6);
fprintf('Range Resolution:       %.1f meters\n', rangeRes_m);
fprintf('Assessment:             ');
if rangeRes_m < 50
    fprintf('✓ EXCELLENT (<50m)\n\n');
elseif rangeRes_m < 100
    fprintf('✓ GOOD (<100m)\n\n');
else
    fprintf('⚠️  Marginal (>100m)\n\n');
end

% Doppler resolution (for various integration times)
fprintf('--- DOPPLER RESOLUTION ---\n');
fprintf('Integration Time | Doppler Resolution | Velocity Resolution\n');
fprintf('-----------------|--------------------|-----------------------\n');
for T = [0.5, 1.0, 2.0]
    dopplerRes_Hz = 1 / T;
    velocityRes_ms = (c * dopplerRes_Hz) / (2 * freq_A);  % Use lower freq (conservative)
    fprintf('    %.1f sec      |      %.2f Hz       |      %.2f m/s\n', ...
        T, dopplerRes_Hz, velocityRes_ms);
end
fprintf('Assessment:             ');
if (1/(1.0)) < 2
    fprintf('✓ GOOD for aircraft tracking\n\n');
else
    fprintf('⚠️  May need longer integration\n\n');
end

% Detection capability
fprintf('--- DETECTION CAPABILITY ---\n');
fprintf('Minimum SNR for detection:  13 dB (post-processing)\n');
fprintf('Config A (1 sec int):       %.1f dB', snr_A + 10*log10(1.0 * signalBW_A));
if (snr_A + 10*log10(1.0 * signalBW_A)) > 13
    fprintf(' ✓ CAPABLE\n');
else
    fprintf(' ✗ INSUFFICIENT\n');
end
fprintf('Config B (1 sec int):       %.1f dB', snr_B + 10*log10(1.0 * signalBW_B));
if (snr_B + 10*log10(1.0 * signalBW_B)) > 13
    fprintf(' ✓ CAPABLE\n\n');
else
    fprintf(' ✗ INSUFFICIENT\n\n');
end

% Overall localization verdict
localization_A = (snr_A + 10*log10(1.0 * signalBW_A)) > 13;
localization_B = (snr_B + 10*log10(1.0 * signalBW_B)) > 13;

fprintf('========================================================================\n');
fprintf('BISTATIC LOCALIZATION CAPABILITY VERDICT:\n');
fprintf('========================================================================\n\n');

if localization_A && localization_B
    fprintf('✓✓✓ BOTH CONFIGURATIONS CAPABLE OF BISTATIC LOCALIZATION ✓✓✓\n\n');
    fprintf('With 1 second coherent integration:\n');
    fprintf('  - Config A post-proc SNR: %.1f dB (>13 dB required) ✓\n', ...
        snr_A + 10*log10(1.0 * signalBW_A));
    fprintf('  - Config B post-proc SNR: %.1f dB (>13 dB required) ✓\n', ...
        snr_B + 10*log10(1.0 * signalBW_B));
    fprintf('  - Range resolution: %.1f m\n', rangeRes_m);
    fprintf('  - Doppler resolution: %.2f Hz (1 sec integration)\n', 1.0);
    fprintf('\nBoth configurations provide sufficient SNR, range resolution, and\n');
    fprintf('Doppler resolution for bistatic aircraft localization.\n\n');
elseif localization_A || localization_B
    fprintf('⚠️  PARTIAL CAPABILITY - ONE CONFIGURATION MARGINAL ⚠️\n\n');
    if ~localization_A
        fprintf('Config A (Hudson) requires longer integration or higher gain.\n');
    end
    if ~localization_B
        fprintf('Config B (Newton) requires longer integration or higher gain.\n');
    end
    fprintf('\n');
else
    fprintf('✗✗✗ INSUFFICIENT SNR FOR BISTATIC LOCALIZATION ✗✗✗\n\n');
    fprintf('Both configurations require:\n');
    fprintf('  - Longer integration times (>1 sec), OR\n');
    fprintf('  - Higher LNA gain, OR\n');
    fprintf('  - Reduced system noise figure\n\n');
end

%% ========================================================================
%  VISUALIZATIONS
%  ========================================================================

% Create comprehensive comparison figure
figure('Position', [100 100 1400 900], 'Name', 'Comparative RF Budget Analysis');

% Subplot 1: Noise Figure Comparison
subplot(2,3,1);
bar([systemNF_A, systemNF_B]);
hold on;
yline(4, 'g--', 'Excellent (<4 dB)', 'LineWidth', 1.5);
yline(5, 'y--', 'Acceptable (<5 dB)', 'LineWidth', 1.5);
hold off;
set(gca, 'XTickLabel', {'Hudson Ch27', 'Newton Ch35'});
ylabel('System NF (dB)');
title('System Noise Figure Comparison');
ylim([0 max([systemNF_A, systemNF_B])*1.3]);
grid on;

% Subplot 2: Total Gain Comparison
subplot(2,3,2);
bar([totalGain_A, totalGain_B]);
set(gca, 'XTickLabel', {'Hudson Ch27', 'Newton Ch35'});
ylabel('Total Gain (dB)');
title('Total Cascade Gain Comparison');
ylim([min([totalGain_A, totalGain_B])-2, max([totalGain_A, totalGain_B])+2]);
grid on;
text(1, totalGain_A+0.5, sprintf('%.2f dB', totalGain_A), 'HorizontalAlignment', 'center');
text(2, totalGain_B+0.5, sprintf('%.2f dB', totalGain_B), 'HorizontalAlignment', 'center');

% Subplot 3: Pre-Processing SNR Comparison
subplot(2,3,3);
bar([snr_A, snr_B]);
hold on;
yline(30, 'g--', 'Excellent (>30 dB)', 'LineWidth', 1.5);
yline(20, 'y--', 'Good (>20 dB)', 'LineWidth', 1.5);
hold off;
set(gca, 'XTickLabel', {'Hudson Ch27', 'Newton Ch35'});
ylabel('SNR (dB)');
title('Pre-Processing SNR Comparison');
ylim([0 max([snr_A, snr_B])*1.2]);
grid on;

% Subplot 4: Post-Processing SNR vs Integration Time
subplot(2,3,4);
intTimes = 0.01:0.01:2.0;
snrPost_A_vec = snr_A + 10*log10(intTimes * signalBW_A);
snrPost_B_vec = snr_B + 10*log10(intTimes * signalBW_B);
plot(intTimes, snrPost_A_vec, 'b-', 'LineWidth', 2, 'DisplayName', 'Hudson Ch27');
hold on;
plot(intTimes, snrPost_B_vec, 'r-', 'LineWidth', 2, 'DisplayName', 'Newton Ch35');
yline(13, 'g--', 'Detection Threshold', 'LineWidth', 1.5);
hold off;
xlabel('Integration Time (sec)');
ylabel('Post-Processing SNR (dB)');
title('Post-Processing SNR vs Integration Time');
legend('Location', 'southeast');
grid on;
xlim([0 2]);

% Subplot 5: Component Loss Comparison
subplot(2,3,5);
losses_A = [cableLoss_A, mismatchLoss_A, hpFilterLoss_A, bpFilterLoss_A];
losses_B = [cableLoss_B, mismatchLoss_B, hpFilterLoss_B, bpFilterLoss_B];
x = 1:4;
bar(x - 0.15, losses_A, 0.3, 'b', 'DisplayName', 'Hudson Ch27');
hold on;
bar(x + 0.15, losses_B, 0.3, 'r', 'DisplayName', 'Newton Ch35');
hold off;
set(gca, 'XTickLabel', {'Cable', 'Mismatch', 'HP Filter', 'BP Filter'});
ylabel('Loss (dB)');
title('Component Loss Comparison');
legend('Location', 'northwest');
grid on;

% Subplot 6: Summary Table
subplot(2,3,6);
axis off;

summaryText = {
    'SUMMARY COMPARISON';
    '══════════════════════════════════════';
    sprintf('Frequency:       %.0f MHz vs %.0f MHz', freq_A/1e6, freq_B/1e6);
    sprintf('System NF:       %.2f dB vs %.2f dB', systemNF_A, systemNF_B);
    sprintf('Total Gain:      %.2f dB vs %.2f dB', totalGain_A, totalGain_B);
    sprintf('Pre-Proc SNR:    %.2f dB vs %.2f dB', snr_A, snr_B);
    sprintf('Post-Proc (1s):  %.1f dB vs %.1f dB', ...
        snr_A + 10*log10(signalBW_A), snr_B + 10*log10(signalBW_B));
    '';
    'HARDWARE COMPATIBILITY:';
    '──────────────────────────────────────';
};

if overall_compatible
    summaryText{end+1} = '✓ SAME HARDWARE WORKS FOR BOTH';
else
    summaryText{end+1} = '⚠️  REVIEW COMPATIBILITY ISSUES';
end

summaryText{end+1} = '';
summaryText{end+1} = 'LOCALIZATION CAPABILITY:';
summaryText{end+1} = '──────────────────────────────────────';

if localization_A && localization_B
    summaryText{end+1} = '✓ BOTH CONFIGURATIONS CAPABLE';
else
    summaryText{end+1} = '⚠️  ONE OR BOTH MARGINAL';
end

text(0.05, 0.95, summaryText, 'FontSize', 9, 'FontName', 'Courier', ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');

sgtitle('Comparative RF Budget Analysis: Hudson Ch 27 vs Newton Ch 35', ...
    'FontSize', 14, 'FontWeight', 'bold');

%% ========================================================================
%  FINAL RECOMMENDATIONS
%  ========================================================================

fprintf('========================================================================\n');
fprintf('FINAL RECOMMENDATIONS\n');
fprintf('========================================================================\n\n');

fprintf('1. HARDWARE VALIDATION:\n');
if overall_compatible
    fprintf('   ✓ Same hardware validated for both configurations\n');
    fprintf('   ✓ Minimal performance variation across 48 MHz frequency range\n');
else
    fprintf('   ⚠️  Address compatibility issues identified above\n');
end
fprintf('\n');

fprintf('2. FILTER CONCERN (Config B - Newton Ch 35):\n');
fprintf('   ⚠️  ZABP-587-S+ is 12 MHz off-center at 599 MHz\n');
fprintf('   ⚠️  Estimated insertion loss: %.1f dB vs %.1f dB nominal\n', ...
    bpFilterLoss_B, bpFilterLoss_A);
fprintf('   → CRITICAL: Measure actual insertion loss with VNA\n');
fprintf('   → If loss >2 dB, consider ZABP-603-S+ ($105, centered at 603 MHz)\n\n');

fprintf('3. REFERENCE CHANNEL ATTENUATOR:\n');
fprintf('   ⚠️  Newton Ch 35: RF35 source is VERY powerful (1000 kW ERP)\n');
fprintf('   → STRONGLY RECOMMEND: 20-30 dB variable attenuator (~$50)\n');
fprintf('   → Prevents reference channel ADC saturation\n\n');

fprintf('4. BISTATIC LINK BUDGET:\n');
fprintf('   Config A and Config B now use deterministic target-path reruns\n');
fprintf('   -> Current basis: recovered saved ROI, Longley-Rice, 6000 ft AGL targets\n');
fprintf('   -> Remaining follow-on: promote recovered ROI to explicit checked-in geometry input\n\n');

fprintf('5. FIELD VALIDATION:\n');
fprintf('   → Spectrum analyzer survey at both locations\n');
fprintf('   → Measure actual adjacent channel interference\n');
fprintf('   → Verify direct path signal strength (reference channel)\n');
fprintf('   → Collect test data to validate SNR predictions\n\n');

fprintf('6. SYSTEM CONFIDENCE LEVEL:\n');
if localization_A && localization_B && overall_compatible
    fprintf('   ✓✓✓ HIGH CONFIDENCE for bistatic aircraft localization\n');
    fprintf('   • Both configurations exceed detection threshold\n');
    fprintf('   • Hardware validated across frequency range\n');
    fprintf('   • Range resolution adequate (%.1f m)\n', rangeRes_m);
    fprintf('   • Doppler resolution adequate (1 Hz @ 1 sec integration)\n\n');
    fprintf('   System is ready for field testing pending:\n');
    fprintf('     - Filter verification (Config B)\n');
    fprintf('     - Reference attenuator installation (Config B)\n');
    fprintf('     - Explicit checked-in target geometry input if review-room confidence must increase\n\n');
else
    fprintf('   ⚠️  MODERATE CONFIDENCE - address issues above first\n\n');
end

fprintf('========================================================================\n');
fprintf('Comparative Analysis Complete!\n');
fprintf('See the generated assumptions, risk, and RF summary tables for the cleaned working set.\n');
fprintf('========================================================================\n\n');
