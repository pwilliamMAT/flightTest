function dataset_mode = helperSyntheticDescribeTargetEchoDatasetMode(signal_mode, seed_echo_source_mode)
%HELPERSYNTHETICDESCRIBETARGETECHODATASETMODE Describe the target-echo dataset policy.
%
% Plain language:
% The same seed-backed generator can emit two useful synthetic dataset
% flavors. Conditioned target echoes are the recommended intermediate
% algorithm-test output because they suppress the pilot-driven vertical
% Doppler-column artifact. Full-seed target echoes remain available as a
% comparison/reference output for seed-preservation and artifact studies.

validateattributes(signal_mode, {'char', 'string'}, {'scalartext'}, ...
    mfilename, 'signal_mode');
validateattributes(seed_echo_source_mode, {'char', 'string'}, {'scalartext'}, ...
    mfilename, 'seed_echo_source_mode');

signal_mode = char(string(signal_mode));
seed_echo_source_mode = char(string(seed_echo_source_mode));

dataset_mode = struct( ...
    'mode_id', 'not_applicable', ...
    'label', 'not_applicable', ...
    'recommended_intermediate_algorithm_test_mode', false, ...
    'comparison_reference_mode', false, ...
    'seed_echo_source_mode', seed_echo_source_mode, ...
    'note', 'Zero-channel mode does not produce a seed-backed target-echo dataset.');

if ~strcmp(signal_mode, 'seed_backed_bistatic_v1')
    return
end

switch seed_echo_source_mode
    case 'conditioned_target_echoes_v1'
        dataset_mode.mode_id = 'conditioned_target_echo_dataset_v1';
        dataset_mode.label = ...
            'conditioned target-echo dataset (recommended intermediate algorithm-test mode)';
        dataset_mode.recommended_intermediate_algorithm_test_mode = true;
        dataset_mode.note = ['Recommended for algorithm plumbing, truth alignment, ' ...
            'mitigation debugging, detector integration, and tracker integration ' ...
            'while the full-seed vertical-column artifact persists.'];

    case 'full_seed_target_echoes_v1'
        dataset_mode.mode_id = 'full_seed_comparison_dataset_v1';
        dataset_mode.label = 'full-seed comparison dataset';
        dataset_mode.comparison_reference_mode = true;
        dataset_mode.note = ['Useful for seed-preservation studies and explicit ' ...
            'vertical-column artifact comparisons, but not recommended for ' ...
            'downstream algorithm scoring while the artifact persists.'];

    otherwise
        dataset_mode.mode_id = 'seed_backed_target_echo_dataset_v1';
        dataset_mode.label = 'seed-backed target-echo dataset';
        dataset_mode.note = ['Seed-backed mode is active, but the target-echo source ' ...
            'mode was not recognized.'];
end
end
