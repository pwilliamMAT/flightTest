%% RF Budget Analysis - Passive Radar System (Newton - WHDH/WLVI RF35 source)
% Signals of Opportunity Aircraft Tracking using HDTV (ATSC) Transmissions
%
% SYSTEM CONFIGURATION:
%   - Transmitter: WHDH/WLVI shared RF35 source (596-602 MHz, center: 599 MHz)
%   - Location: N 42° 18' 37", W 71° 14' 12" (NAD83)
%   - ERP: 1000 kW horizontal (60.0 dBW), 316 kW vertical (55.0 dBW)
%   - Operational status: Licensed as of 2026-07-17
%   - Antenna: RF Systems PEP70E-O5-2-T with 0.75° electrical beam tilt
%   - Coverage: 64.9 mile contour, Est. Pop. 7.7M
%   - Receiver: Dual-channel (Reference + Surveillance)
%   - Hardware: USRP N320 with TwinRX daughterboard
%   - Architecture: Direct sampling (no external mixer/IF stages)
%
% SIGNAL CHAIN (Surveillance Channel):
%   1. Yagi Antenna (75Ω, 12 dBi gain)
%   2. 75ft RG-6 Coax Cable (75Ω, ~1.2 dB loss @ 599 MHz)
%   3. 75Ω-to-50Ω impedance transition (~0.4 dB mismatch loss)
%   4. High-Pass Filter VHF-580+ (optional, fc=580 MHz, -0.3 dB insertion loss)
%   5. Bandpass Filter ZABP-587-S+ (center: 587 MHz, BW: 540-634 MHz)
%      ⚠️  NOTE: Filter is 12 MHz off-center (587 vs 599 MHz)
%           Insertion loss may be 1.5-2.0 dB vs nominal 1.0 dB
%   6. Nooelec LANA amplifier (20 dB gain, 1.5 dB NF @ 599 MHz est.)
%   7. USRP N320 TwinRX (0-93 dB gain, 6 dB NF, direct sampling)
%
% ACTUAL COMPONENT SPECIFICATIONS:
%   - Antenna: TV Yagi (typical gain 12 dBi, 75Ω impedance)
%   - Cable: 75ft RG-6, loss = 1.6 dB/100ft @ 599 MHz
%   - Filter: Mini-Circuits ZABP-587-S+ (⚠️ 12 MHz off-center)
%   - LNA: Nooelec LANA (estimated: gain=20dB±1dB, NF=1.5dB @ 599 MHz)
%   - USRP: N320 with TwinRX daughterboard
%
% ⚠️  CRITICAL NOTES FOR CHANNEL 35:
%   1. Newton RF35 is VERY POWERFUL (1000 kW horizontal ERP)
%   2. Reference channel will likely need 20-30 dB attenuator
%   3. Bandpass filter is 12 MHz off-center - verify insertion loss
%   4. All component specs are estimated at 599 MHz - verify datasheets
%   5. Target-path power now comes from a deterministic Longley-Rice rerun
%
% Updated: December 8, 2025
% Author: RF Budget Analysis Tool
% Reference: System precheck working-set assumptions table and RF summary
%
%==========================================================================

clear; clc; close all;
projectRoot = fileparts(fileparts(mfilename("fullpath")));
addpath(projectRoot);

%% ========================================================================
%  SECTION 1: INPUT PARAMETERS
%  ========================================================================

% Operating frequency and bandwidth
InputFreq = 599e6;              % Channel 35 Newton RF35 center frequency (Hz)
PilotTone = 596.3e6;            % ATSC pilot tone frequency (Hz)
SignalBW = 6e6;                 % ATSC signal bandwidth (Hz)
FreqRange = [596 602];          % Channel 35 frequency range (MHz)

% WHDH/WLVI RF35 transmitter parameters
Tx_ERP_Horizontal_kW = 1000;    % Horizontal ERP (kW)
Tx_ERP_Vertical_kW = 316;       % Vertical ERP (kW)
Tx_ERP_Horizontal_dBW = 10*log10(Tx_ERP_Horizontal_kW * 1000);  % 60.0 dBW
Tx_Latitude = 42.310280;        % degrees N
Tx_Longitude = -71.236670;      % degrees W

% Target signal power from deterministic bistatic rerun
% ⚠️  TODO: Calculate based on Newton RF35 parameters and bistatic geometry
% Mean power over the recovered saved-ROI rerun
TargetPathPower = -67.56;       % dBm (mean power over recovered saved-ROI rerun)
fprintf('Bistatic target-path basis: deterministic saved-ROI rerun.\n');
fprintf('   Current value comes from the deterministic saved-ROI rerun.\n\n');

% Cable specifications
CableLength_ft = 75;            % Cable length in feet
CableType = 'RG-6';             % Coax type (75 ohm)
Cable_Loss_per_100ft = 1.6;     % Loss in dB/100ft @ 599 MHz (higher than @ 551 MHz)

% Impedance mismatch (75 ohm antenna/cable to 50 ohm components)
Mismatch_Loss_dB = 0.4;         % Calculated from VSWR = 1.5:1

% Component gain and noise figure specifications (estimated at 599 MHz)
% ⚠️  NOTE: These values are estimates - verify from datasheets
Antenna_Gain_dB = 12;           % Yagi antenna gain (verify at 599 MHz)
LNA_Gain_dB = 20;               % Nooelec LANA measured gain
LNA_NF_dB = 1.5;                % Nooelec LANA noise figure @ 599 MHz (estimated)
LNA_OIP3_dBm = 28;              % Output IP3 from datasheet

USRP_Gain_dB = 30;              % N320 TwinRX nominal gain setting
USRP_NF_dB = 6;                 % N320 TwinRX noise figure @ 599 MHz (estimated)
USRP_OIP3_dBm = 30;             % Typical for TwinRX

% Filter specifications
% ⚠️  CRITICAL: ZABP-587-S+ is centered at 587 MHz, target is 599 MHz (12 MHz offset)
BP_Filter_Loss_dB = helperGetBandpassInsertionLoss(InputFreq);  % Measured from included S2P
BP_Filter_Center_MHz = 587;     % Actual filter center frequency
BP_Filter_Offset_MHz = abs(InputFreq/1e6 - BP_Filter_Center_MHz);  % 12 MHz offset
HP_Filter_Loss_dB = 0.3;        % VHF-580+ insertion loss (optional)
Include_HP_Filter = isempty(getenv('SYSTEM_PRECHECK_DISABLE_HP_FILTER'));

fprintf('⚠️  FILTER OFFSET WARNING:\n');
fprintf('   ZABP-587-S+ centered at %d MHz, target is %.0f MHz\n', ...
    BP_Filter_Center_MHz, InputFreq/1e6);
fprintf('   Offset: %.0f MHz - measured insertion loss is %.1f dB at 25 C\n', ...
    BP_Filter_Offset_MHz, BP_Filter_Loss_dB);
fprintf('   Consider verifying this against the assembled hardware chain.\n\n');

%% ========================================================================
%  SECTION 2: BUILD RF CASCADE USING PROPER MATLAB RF TOOLBOX FUNCTIONS
%  ========================================================================

fprintf('========================================\n');
fprintf('RF Budget Analysis - Passive Radar\n');
fprintf('WHDH/WLVI RF35 Newton path @ 599 MHz\n');
fprintf('========================================\n\n');

% Display Newton transmitter information
fprintf('--- NEWTON RF35 TRANSMITTER ---\n');
fprintf('Location: N %.6f°, W %.6f°\n', Tx_Latitude, abs(Tx_Longitude));
fprintf('ERP (Horizontal): %.0f kW (%.1f dBW)\n', Tx_ERP_Horizontal_kW, Tx_ERP_Horizontal_dBW);
fprintf('ERP (Vertical): %.0f kW (%.1f dBW)\n', Tx_ERP_Vertical_kW, ...
    10*log10(Tx_ERP_Vertical_kW * 1000));
fprintf('Frequency: %.1f-%.1f MHz (Channel 35)\n', FreqRange(1), FreqRange(2));
fprintf('Pilot Tone: %.1f MHz\n\n', PilotTone/1e6);

% Calculate actual cable loss for given length
Cable_Loss_dB = Cable_Loss_per_100ft * (CableLength_ft / 100);
fprintf('Cable Loss: %.2f dB (%.0f ft of %s @ 599 MHz)\n', ...
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
% ⚠️  NOTE: This filter is 12 MHz off-center for Ch 35 (599 MHz)
% This filter model approximates the ZABP-587-S+ response
elements(idx) = rffilter( ...
    'FilterType', 'Butterworth', ...
    'ResponseType', 'Bandpass', ...
    'Implementation', 'LC Tee', ...
    'FilterOrder', 3, ...
    'PassbandFrequency', [540 634]*1e6, ...
    'PassbandAttenuation', BP_Filter_Loss_dB, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Name', 'BPF_ZABP587_OffCenter');
idx = idx + 1;

% Element 5: Low Noise Amplifier (Nooelec LANA)
% Gain: 20 dB, NF: 1.5 dB @ 599 MHz (estimated), OIP3: 28 dBm
% Includes built-in bias tee for antenna power
elements(idx) = amplifier( ...
    'Name', 'LNA_Nooelec_LANA', ...
    'Gain', LNA_Gain_dB, ...
    'NF', LNA_NF_dB, ...
    'OIP3', LNA_OIP3_dBm, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Model', 'poly');
idx = idx + 1;

% Element 6: USRP N320 with TwinRX Daughterboard
% Direct sampling SDR (no external mixer or IF stages needed)
% Gain: 0-93 dB software controlled (using 30 dB nominal)
% NF: 6 dB typical @ 599 MHz
elements(idx) = amplifier( ...
    'Name', 'USRP_N320_TwinRX', ...
    'Gain', USRP_Gain_dB, ...
    'NF', USRP_NF_dB, ...
    'OIP3', USRP_OIP3_dBm, ...
    'Zin', 50, ...
    'Zout', 50, ...
    'Model', 'poly');

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
figure('Position', [100 100 1200 800], 'Name', 'RF Budget Analysis - Newton Ch 35');

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
sgtitle(sprintf('RF Budget Analysis - Newton RF35 path (599 MHz)\nSystem NF: %.2f dB | Total Gain: %.2f dB | SNR: %.2f dB', ...
    SystemNF, TotalGain, SNR_dB), 'FontSize', 12, 'FontWeight', 'bold');

%% ========================================================================
%  SECTION 8: RECOMMENDATIONS AND WARNINGS
%  ========================================================================

fprintf('\n========================================\n');
fprintf('RECOMMENDATIONS FOR CHANNEL 35\n');
fprintf('========================================\n');

% Check if high-pass filter is included
if ~Include_HP_Filter
    fprintf('⚠️  RECOMMENDATION: Add high-pass filter (VHF-580+)\n');
    fprintf('   - Rejects FM broadcast and out-of-band interference\n');
    fprintf('   - Cost: ~$40, Loss: 0.3 dB\n');
    fprintf('   - Set Include_HP_Filter = true to model\n\n');
end

% Filter offset warning
fprintf('⚠️  CRITICAL: Bandpass Filter Offset\n');
fprintf('   - ZABP-587-S+ centered at 587 MHz, Ch 35 is 599 MHz\n');
fprintf('   - Offset: %.0f MHz from center\n', BP_Filter_Offset_MHz);
fprintf('   - Insertion loss from the included 25 C S2P file: %.1f dB\n', BP_Filter_Loss_dB);
fprintf('   - RECOMMENDATION: Verify the assembled chain against this baseline\n');
fprintf('   - Alternative: ZABP-603-S+ (centered at 603 MHz, only 4 MHz offset)\n\n');

% Newton RF35 high power warning
fprintf('⚠️  CRITICAL: Very High Transmitter Power\n');
fprintf('   - Newton RF35 ERP: %.0f kW (%.1f dBW horizontal)\n', ...
    Tx_ERP_Horizontal_kW, Tx_ERP_Horizontal_dBW);
fprintf('   - Direct path signal will be VERY strong\n');
fprintf('   - STRONGLY RECOMMEND: 20-30 dB attenuator on reference channel\n');
fprintf('   - Without attenuator, reference ADC may saturate\n');
fprintf('   - Consider: Mini-Circuits ZX73-2500+ variable attenuator (~$50)\n\n');

% Check adjacent channel interference
fprintf('Adjacent Channel Considerations:\n');
fprintf('  - Channel 34: 590-596 MHz (immediately below)\n');
fprintf('  - Channel 36: 602-608 MHz (immediately above)\n');
fprintf('  - ZABP-587-S+ provides minimal adjacent channel rejection\n');
fprintf('  - Recommend field measurement with spectrum analyzer\n');
fprintf('  - May need additional filtering if adjacents are strong\n\n');

% Bistatic target-path note
fprintf('Bistatic Target-Path Basis:\n');
fprintf('   - Current TargetPathPower (%.2f dBm) comes from the deterministic precheck rerun\n', TargetPathPower);
fprintf('   - Method: Longley-Rice over recovered saved ROI, 6000 ft AGL targets, 0.5 m^2 RCS\n');
fprintf('     * Newton RF35 location: %.6f°N, %.6f°W\n', Tx_Latitude, abs(Tx_Longitude));
fprintf('     * ERP: %.0f kW horizontal, %.0f kW vertical\n', ...
    Tx_ERP_Horizontal_kW, Tx_ERP_Vertical_kW);
fprintf('   - Follow-on if confidence must increase: promote ROI to explicit checked-in geometry input\n\n');

% Component verification warning
fprintf('⚠️  TODO: Verify Component Specs at 599 MHz\n');
fprintf('   - LNA NF: Assumed %.1f dB (verify Nooelec datasheet)\n', LNA_NF_dB);
fprintf('   - Cable loss: Assumed %.2f dB (verify RG-6 specs)\n', Cable_Loss_dB);
fprintf('   - USRP NF: Assumed %.1f dB (verify TwinRX specs)\n', USRP_NF_dB);
fprintf('   - Antenna gain: Assumed %.1f dB (verify at 599 MHz)\n\n', Antenna_Gain_dB);

fprintf('========================================\n');
fprintf('Analysis Complete!\n');
fprintf('Newton RF35 working set aligned to the assumptions table.\n');
fprintf('========================================\n\n');
