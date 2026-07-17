%% RF Budget Analysis - Passive Radar System (Hudson - WUNI RF27 source)
% Signals of Opportunity Aircraft Tracking using HDTV (ATSC) Transmissions
%
% SYSTEM CONFIGURATION:
%   - Transmitter: WUNI alternate source path (548-554 MHz, center: 551 MHz)
%   - Operational status: Licensed as of 2026-07-17
%   - Receiver: Dual-channel (Reference + Surveillance)
%   - Hardware: USRP N320 with TwinRX daughterboard
%   - Architecture: Direct sampling (no external mixer/IF stages)
%
% SIGNAL CHAIN (Surveillance Channel):
%   1. Yagi Antenna (75Ω, 12 dBi gain)
%   2. 75ft RG-6 Coax Cable (75Ω, ~1.1 dB loss @ 551 MHz)
%   3. 75Ω-to-50Ω impedance transition (~0.4 dB mismatch loss)
%   4. High-Pass Filter VHF-580+ (optional, fc=580 MHz, -0.3 dB insertion loss)
%   5. Bandpass Filter ZABP-587-S+ (center: 587 MHz, BW: 540-634 MHz)
%   6. Nooelec LANA amplifier (20 dB gain, 1.4 dB NF)
%   7. USRP N320 TwinRX (0-93 dB gain, 6 dB NF, direct sampling)
%
% ACTUAL COMPONENT SPECIFICATIONS:
%   - Antenna: TV Yagi (typical gain 12 dBi, 75Ω impedance)
%   - Cable: 75ft RG-6, loss = 1.5 dB/100ft @ 551 MHz
%   - Filter: Mini-Circuits ZABP-587-S+ (measured 25 C S2P file included in repo)
%   - LNA: Nooelec LANA (datasheet: gain=20dB±1dB, NF=1.4dB typ @ 551 MHz)
%   - USRP: N320 with TwinRX daughterboard
%
% Updated: December 8, 2025
% Author: RF Budget Analysis Tool
% Reference: System precheck working-set assumptions table and RF summary
%
%==========================================================================

clear; clc; close all;

%% ========================================================================
%  SECTION 1: INPUT PARAMETERS
%  ========================================================================

% Operating frequency and bandwidth
InputFreq = 551e6;              % Channel 27 WUNI center frequency (Hz)
SignalBW = 6e6;                 % ATSC signal bandwidth (Hz)
FreqRange = [548 554];          % Channel 27 frequency range (MHz)

% Target signal power from bistatic link budget analysis
% This value includes: Transmitter ERP, bistatic path losses, and aircraft RCS
TargetPathPower = -67.37;       % dBm (conservative RCS assumption)

% Cable specifications
CableLength_ft = 75;            % Cable length in feet
CableType = 'RG-6';             % Coax type (75 ohm)
Cable_Loss_per_100ft = 1.5;     % Loss in dB/100ft @ 551 MHz

% Impedance mismatch (75 ohm antenna/cable to 50 ohm components)
Mismatch_Loss_dB = 0.4;         % Calculated from VSWR = 1.5:1

% Component gain and noise figure specifications (from datasheets)
Antenna_Gain_dB = 12;           % Yagi antenna gain
LNA_Gain_dB = 20;               % Nooelec LANA measured gain
LNA_NF_dB = 1.4;                % Nooelec LANA noise figure @ 551 MHz
LNA_OIP3_dBm = 28;              % Output IP3 from datasheet

USRP_Gain_dB = 30;              % N320 TwinRX nominal gain setting
USRP_NF_dB = 6;                 % N320 TwinRX noise figure @ 551 MHz
USRP_OIP3_dBm = 30;             % Typical for TwinRX

% Filter specifications
BP_Filter_Loss_dB = helperGetBandpassInsertionLoss(InputFreq);  % Measured from included S2P
HP_Filter_Loss_dB = 0.3;        % VHF-580+ insertion loss (optional)
Include_HP_Filter = isempty(getenv('SYSTEM_PRECHECK_DISABLE_HP_FILTER'));

%% ========================================================================
%  SECTION 2: BUILD RF CASCADE USING PROPER MATLAB RF TOOLBOX FUNCTIONS
%  ========================================================================

fprintf('\n========================================\n');
fprintf('RF Budget Analysis - Passive Radar\n');
fprintf('WUNI alternate RF27 path @ 551 MHz\n');
fprintf('========================================\n\n');

% Calculate actual cable loss for given length
Cable_Loss_dB = Cable_Loss_per_100ft * (CableLength_ft / 100);
fprintf('Cable Loss: %.2f dB (%.0f ft of %s @ 551 MHz)\n', ...
    Cable_Loss_dB, CableLength_ft, CableType);

% Calculate effective input power after antenna
% The antenna receives TargetPathPower and adds its gain
Input_After_Antenna_dBm = TargetPathPower + Antenna_Gain_dB;
fprintf('Input Power (after antenna gain): %.2f dBm\n', Input_After_Antenna_dBm);

% Element counter
idx = 1;

% NOTE: We start the cascade AFTER the antenna since rfantenna doesn't 
% accept AvailableInputPower. The antenna gain is accounted for in the
% Input_After_Antenna_dBm value used as AvailableInputPower for the budget.

% Element 1: Cable Loss (75 ohm RG-6, 75 ft)
% NOTE: rfdevice is NOT a valid MATLAB function
% Use amplifier with negative gain and NF equal to absolute value of gain
elements(idx) = amplifier( ...
    'Name', 'Cable_RG6_75ft', ...
    'Gain', -Cable_Loss_dB, ...
    'NF', Cable_Loss_dB, ...      % For passive element: NF = -Gain
    'Zin', 75, ...
    'Zout', 75);
idx = idx + 1;

% Element 2: Impedance Mismatch (75 ohm to 50 ohm transition)
% This represents the VSWR loss at the interface
elements(idx) = amplifier( ...
    'Name', 'Impedance_Mismatch_75_to_50', ...
    'Gain', -Mismatch_Loss_dB, ...
    'NF', Mismatch_Loss_dB, ...
    'Zin', 75, ...
    'Zout', 50);
idx = idx + 1;

% Element 3: High-Pass Filter (optional - VHF-580+, fc=580 MHz)
% Rejects out-of-band interference (FM, VHF TV, LTE)
if Include_HP_Filter
    elements(idx) = amplifier( ...
        'Name', 'HighPass_VHF580', ...
        'Gain', -HP_Filter_Loss_dB, ...
        'NF', HP_Filter_Loss_dB, ...
        'Zin', 50, ...
        'Zout', 50);
    idx = idx + 1;
end

% Element 4: RF Bandpass Filter (Mini-Circuits ZABP-587-S+)
% Center: 587 MHz, 3dB BW: 540-634 MHz
% This filter model uses the measured 25 C insertion loss at 551 MHz.
elements(idx) = rffilter( ...
    'FilterType', 'Butterworth', ...
    'ResponseType', 'Bandpass', ...
    'Implementation', 'LC Tee', ...
    'FilterOrder', 3, ...
    'PassbandFrequency', [540 634]*1e6, ...
    'PassbandAttenuation', BP_Filter_Loss_dB, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Name', 'BPF_ZABP587');
idx = idx + 1;

% Element 5: Low Noise Amplifier (Nooelec LANA)
% Gain: 20 dB, NF: 1.4 dB, OIP3: 28 dBm
% Includes built-in bias tee for antenna power
elements(idx) = amplifier( ...
    'Name', 'LNA_Nooelec_LANA', ...
    'Gain', LNA_Gain_dB, ...
    'NF', LNA_NF_dB, ...
    'OIP3', LNA_OIP3_dBm, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Model', 'cubic');
idx = idx + 1;

% Element 6: USRP N320 with TwinRX Daughterboard
% Direct sampling SDR (no external mixer or IF stages needed)
% Gain: 0-93 dB software controlled (using 30 dB nominal)
% NF: 6 dB typical @ 551 MHz
elements(idx) = amplifier( ...
    'Name', 'USRP_N320_TwinRX', ...
    'Gain', USRP_Gain_dB, ...
    'NF', USRP_NF_dB, ...
    'OIP3', USRP_OIP3_dBm, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Model', 'cubic');

%% ========================================================================
%  SECTION 3: CONSTRUCT RF BUDGET OBJECT AND ANALYZE
%  ========================================================================

% Create RF budget object using Friis cascade analysis
% Note: Starting cascade after antenna; antenna gain included in AvailableInputPower
budget = rfbudget( ...
    'Elements', elements, ...
    'InputFrequency', InputFreq, ...
    'AvailableInputPower', Input_After_Antenna_dBm, ...
    'SignalBandwidth', SignalBW, ...
    'Solver', 'Friis', ...
    'AutoUpdate', true);

% Display budget table
fprintf('\n--- RF CASCADE ANALYSIS ---\n');
fprintf('Note: Antenna gain (%.1f dB) already included in input power\n', Antenna_Gain_dB);
fprintf('      Target signal power: %.2f dBm\n', TargetPathPower);
fprintf('      After antenna: %.2f dBm\n\n', Input_After_Antenna_dBm);
disp(budget);

%% ========================================================================
%  SECTION 4: EXTRACT AND DISPLAY KEY METRICS
%  ========================================================================

% Extract key performance metrics from rfbudget object
% Note: rfbudget returns arrays for each stage, we want the final values
OutputPower = budget.OutputPower(end);     % Signal power at USRP ADC (dBm)
TotalGain = budget.TransducerGain(end);    % Total cascade gain (dB)
SystemNF = budget.NF(end);                 % System noise figure (dB)
SystemIIP3 = budget.IIP3(end);             % Input 3rd order intercept point (dBm)
SystemOIP3 = budget.OIP3(end);             % Output 3rd order intercept point (dBm)

% Calculate noise and SNR
kT = -174;                                 % Thermal noise floor (dBm/Hz)
NoisePower_dBm = kT + 10*log10(SignalBW) + SystemNF;  % Total noise power (dBm)
SNR_dB = OutputPower - NoisePower_dBm;     % Signal-to-noise ratio (dB)

% Display key results
fprintf('\n========================================\n');
fprintf('KEY PERFORMANCE METRICS\n');
fprintf('========================================\n');
fprintf('Input Signal Power:        %.2f dBm\n', TargetPathPower);
fprintf('Output Signal Power:       %.2f dBm\n', OutputPower);
fprintf('Total Cascade Gain:        %.2f dB\n', TotalGain);
fprintf('System Noise Figure:       %.2f dB\n', SystemNF);
fprintf('System IIP3:               %.2f dBm\n', SystemIIP3);
fprintf('System OIP3:               %.2f dBm\n', SystemOIP3);
fprintf('\n--- NOISE AND SNR ---\n');
fprintf('Thermal Noise Floor:       -174 dBm/Hz\n');
fprintf('Signal Bandwidth:          %.1f MHz\n', SignalBW/1e6);
fprintf('Noise Power:               %.2f dBm\n', NoisePower_dBm);
fprintf('SNR (before processing):   %.2f dB\n', SNR_dB);
fprintf('--- SIGNAL LEVELS AT KEY POINTS ---\n');

% Calculate signal levels at various points in the chain
% Extract from budget.OutputPower array (one value per stage)
% Note: Stage 1 is now Cable (antenna is accounted for before cascade)
stage_idx = 1;
fprintf('At Antenna Output:         %.2f dBm\n', Input_After_Antenna_dBm);
Power_AfterCable = budget.OutputPower(stage_idx); stage_idx = stage_idx + 1;
Power_AfterMismatch = budget.OutputPower(stage_idx); stage_idx = stage_idx + 1;
Power_AfterHP = budget.OutputPower(stage_idx); stage_idx = stage_idx + 1;
Power_AfterBP = budget.OutputPower(stage_idx); stage_idx = stage_idx + 1;
Power_AfterLNA = budget.OutputPower(stage_idx); stage_idx = stage_idx + 1;

fprintf('After Cable:               %.2f dBm\n', Power_AfterCable);
fprintf('After Impedance Match:     %.2f dBm\n', Power_AfterMismatch);
fprintf('After High-Pass Filter:    %.2f dBm\n', Power_AfterHP);
fprintf('After Bandpass Filter:     %.2f dBm\n', Power_AfterBP);
fprintf('After LNA:                 %.2f dBm\n', Power_AfterLNA);
fprintf('At USRP N320 Input:        %.2f dBm\n', OutputPower);

%% ========================================================================
%  SECTION 5: PROCESSING GAIN AND POST-PROCESSING SNR
%  ========================================================================

fprintf('\n========================================\n');
fprintf('PASSIVE RADAR PROCESSING ANALYSIS\n');
fprintf('========================================\n');

% Processing gain from coherent integration
% For passive radar, cross-correlation provides integration gain
IntegrationTimes = [0.1, 0.5, 1.0, 2.0];  % Integration times in seconds

fprintf('\nCoherent Integration Gain:\n');
fprintf('Integration Time | Processing Gain | Post-Proc SNR\n');
fprintf('----------------+----------------+--------------\n');

for T = IntegrationTimes
    ProcessingGain_dB = 10*log10(T * SignalBW);
    PostProcessing_SNR_dB = SNR_dB + ProcessingGain_dB;
    fprintf('   %.1f sec       |   %.1f dB       |   %.1f dB\n', ...
        T, ProcessingGain_dB, PostProcessing_SNR_dB);
end

fprintf('\nNote: Actual SNR will be degraded by:\n');
fprintf('  - Direct Signal Interference (DSI)\n');
fprintf('  - Multipath and clutter\n');
fprintf('  - Quantization noise\n');
fprintf('  - Processing losses\n');
fprintf('Typical passive radar requires >13 dB post-processing SNR\n');

%% ========================================================================
%  SECTION 6: DYNAMIC RANGE ANALYSIS
%  ========================================================================

fprintf('\n========================================\n');
fprintf('DYNAMIC RANGE ANALYSIS\n');
fprintf('========================================\n');

% USRP N320 specifications
USRP_MaxInput_dBm = -15;        % Recommended max continuous input
USRP_AbsMaxInput_dBm = 10;      % Absolute maximum (damage threshold)
USRP_ADC_Bits = 14;             % ADC resolution
USRP_ADC_SFDR_dB = 74;          % Spurious-free dynamic range (theoretical)

fprintf('USRP N320 Input Specifications:\n');
fprintf('  Recommended Max Input:   %.0f dBm\n', USRP_MaxInput_dBm);
fprintf('  Absolute Max Input:      %.0f dBm\n', USRP_AbsMaxInput_dBm);
fprintf('  ADC Resolution:          %d bits\n', USRP_ADC_Bits);
fprintf('  ADC SFDR:                %.0f dB (theoretical)\n', USRP_ADC_SFDR_dB);
fprintf('\nCurrent Signal Level:      %.2f dBm\n', OutputPower);

if OutputPower > USRP_MaxInput_dBm
    fprintf('⚠️  WARNING: Signal level exceeds recommended input!\n');
    fprintf('   Consider adding attenuation or reducing LNA gain.\n');
elseif OutputPower < (USRP_MaxInput_dBm - 20)
    fprintf('ℹ️  Signal level is low. Consider increasing USRP gain setting.\n');
else
    fprintf('✓ Signal level is within optimal range (%.0f to %.0f dBm)\n', ...
        USRP_MaxInput_dBm - 10, USRP_MaxInput_dBm);
end

% Headroom calculation
Headroom_dB = USRP_MaxInput_dBm - OutputPower;
fprintf('\nHeadroom to Max Input:     %.2f dB\n', Headroom_dB);

%% ========================================================================
%  SECTION 7: PLOT CASCADE PERFORMANCE
%  ========================================================================

% Create visualization
figure('Position', [100 100 1200 800], 'Name', 'RF Budget Analysis');

% Subplot 1: Gain vs Stage
subplot(2,2,1);
% Extract individual stage gains from TransducerGain differences
stage_gains = zeros(1, length(budget.Elements));
stage_gains(1) = budget.TransducerGain(1);
for i = 2:length(budget.Elements)
    stage_gains(i) = budget.TransducerGain(i) - budget.TransducerGain(i-1);
end
stages = 1:length(budget.Elements);
bar(stages, stage_gains);
hold on;
plot(stages, budget.TransducerGain, 'r-o', 'LineWidth', 2, 'MarkerSize', 8);
hold off;
grid on;
xlabel('Stage Number');
ylabel('Gain (dB)');
title('Gain Distribution');
legend('Stage Gain', 'Cumulative Gain', 'Location', 'best');
set(gca, 'XTick', stages);

% Subplot 2: Noise Figure vs Stage
subplot(2,2,2);
% Use the NF array directly from budget analysis
nf_values = budget.NF;
plot(stages, nf_values, 'y-o', 'LineWidth', 2, 'MarkerSize', 8);
grid on
xlabel('Stage Number');
ylabel('Cumulative NF (dB)');
title('Noise Figure Accumulation');
set(gca, 'XTick', stages);

% Subplot 3: Power Level Through Cascade
subplot(2,2,3);
plot(stages, budget.OutputPower, 'g-o', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
yline(USRP_MaxInput_dBm, 'r--', 'USRP Max Input', 'LineWidth', 1.5);
yline(USRP_MaxInput_dBm - 10, 'y--', 'Optimal Range', 'LineWidth', 1);
hold off;
grid on;
xlabel('Stage Number');
ylabel('Signal Power (dBm)');
title('Signal Level Through Cascade');
set(gca, 'XTick', stages);
legend('Signal Power', 'USRP Max', 'Optimal Min', 'Location', 'best');

% Subplot 4: Component Summary Table
subplot(2,2,4);
axis off;
component_names = {budget.Elements.Name};
% Calculate gains from TransducerGain differences
component_gains = stage_gains;
component_text = cell(length(component_names)+2, 1);
component_text{1} = sprintf('COMPONENT SUMMARY');
component_text{2} = sprintf('─────────────────────────────────');
for i = 1:length(component_names)
    component_text{i+2} = sprintf('%d. %s: %.1f dB', ...
        i, component_names{i}, component_gains(i));
end
text(0.1, 0.9, component_text, 'FontSize', 9, 'FontName', 'Courier', ...
    'VerticalAlignment', 'top', 'Interpreter', 'none');

% Overall title
sgtitle(sprintf('RF Budget Analysis - WUNI RF27 alternate path (551 MHz)\nSystem NF: %.2f dB | Total Gain: %.2f dB | SNR: %.2f dB', ...
    SystemNF, TotalGain, SNR_dB), 'FontSize', 12, 'FontWeight', 'bold');

%% ========================================================================
%  SECTION 8: RECOMMENDATIONS AND WARNINGS
%  ========================================================================

fprintf('\n========================================\n');
fprintf('RECOMMENDATIONS\n');
fprintf('========================================\n');

% Check if high-pass filter is included
if ~Include_HP_Filter
    fprintf('⚠️  RECOMMENDATION: Add high-pass filter (VHF-580+)\n');
    fprintf('   - Rejects FM broadcast and out-of-band interference\n');
    fprintf('   - Cost: ~$40, Loss: 0.3 dB\n');
    fprintf('   - Set Include_HP_Filter = true to model\n\n');
end

% Check adjacent channel interference
fprintf('Adjacent Channel Considerations:\n');
fprintf('  - Channel 26: 542-548 MHz (immediately below)\n');
fprintf('  - Channel 28: 554-560 MHz (immediately above)\n');
fprintf('  - ZABP-587-S+ provides minimal adjacent channel rejection\n');
fprintf('  - Recommend field measurement with spectrum analyzer\n');
fprintf('  - May need additional filtering if adjacents are strong\n\n');

% Check for reference channel
fprintf('Reference Channel Notes:\n');
fprintf('  - Direct path signal will be 30-50 dB stronger\n');
fprintf('  - May need attenuator (20-30 dB) on reference channel\n');
fprintf('  - Same components as surveillance channel otherwise\n\n');

fprintf('========================================\n');
fprintf('Analysis Complete!\n');
fprintf('Hudson RF27 working set aligned to the assumptions table.\n');
fprintf('========================================\n\n');
