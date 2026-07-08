function [detections, threshold_map, nf_db, detector_debug] = detectTargetsToolboxCFAR2D( ...
    rdm_db, range_axis, doppler_axis, pfa, guard_cells, train_cells, min_range_m, options)
%DETECTTARGETSTOOLBOXCFAR2D Toolbox-backed 2-D CFAR detector wrapper.
%
% Plain-language goal:
%   Benchmark MATLAB's built-in phased.CFARDetector2D object against the
%   current custom detector while preserving the project-specific wrapper
%   logic that lives outside the core CFAR statistic: notch fill, ATSC
%   ghost-range penalties, minimum-SNR gating, and local-max suppression.
%
% Why the wrapper matters:
%   The built-in CFAR object expects one clean statistical problem:
%   threshold a 2-D image. This passive-radar workflow has extra structure
%   around that core detector:
%     1. The ECA-C zero-Doppler notch leaves near-zero bins that would
%        bias the training-cell estimate unless they are filled first.
%     2. ATSC segment-sync harmonics need an extra threshold penalty at
%        known ghost ranges.
%     3. Clustered above-threshold cells should collapse to one detection.
%   Keeping those steps explicit makes the comparison educational and keeps
%   the built-in object focused on the part it is actually meant to solve.
%
% Inputs and outputs follow detectTargets.m closely so benchmark code can
% swap the detector implementation without changing the replay-bundle
% contract.

if nargin < 4 || isempty(pfa),         pfa         = 1e-4;   end
if nargin < 5 || isempty(guard_cells), guard_cells = [4, 2]; end
if nargin < 6 || isempty(train_cells), train_cells = [20, 4]; end
if nargin < 7 || isempty(min_range_m), min_range_m = 5e3;    end
if nargin < 8 || isempty(options),     options     = struct(); end

if ~isfield(options, 'cfar_type'),              options.cfar_type              = 'CA';  end
if ~isfield(options, 'os_rank_fraction'),       options.os_rank_fraction       = 0.75;  end
if ~isfield(options, 'local_maxima'),           options.local_maxima           = false; end
if ~isfield(options, 'lm_range_bins'),          options.lm_range_bins          = 4;     end
if ~isfield(options, 'lm_dopp_bins'),           options.lm_dopp_bins           = 2;     end
if ~isfield(options, 'min_snr_db'),             options.min_snr_db             = 0;     end
if ~isfield(options, 'atsc_guard_ranges_m'),    options.atsc_guard_ranges_m    = [];    end
if ~isfield(options, 'atsc_guard_penalty_db'),  options.atsc_guard_penalty_db  = 10;    end
if ~isfield(options, 'atsc_guard_width_bins'),  options.atsc_guard_width_bins  = 3;     end
if ~isfield(options, 'notch_guard_dopp_bins'),  options.notch_guard_dopp_bins  = 0;     end
if ~isfield(options, 'nci_looks'),              options.nci_looks              = 1;     end
if ~isfield(options, 'verbose'),                options.verbose                = true;  end

verbose = logical(options.verbose);
cfar_type = upper(char(string(options.cfar_type)));
if ~ismember(cfar_type, {'CA', 'OS'})
    error('detectTargetsToolboxCFAR2D:unknownCfarType', ...
        'options.cfar_type must be ''CA'' or ''OS''; got ''%s''.', options.cfar_type);
end

Ng_r = guard_cells(1);
Ng_d = guard_cells(2);
Nt_r = train_cells(1);
Nt_d = train_cells(2);
Ho_r = Ng_r + Nt_r;
Ho_d = Ng_d + Nt_d;
L_nci = max(1, round(options.nci_looks));

if verbose
    fprintf(['Running toolbox 2-D %s-CFAR (Pfa=%.0e, guard=[%d %d], ' ...
        'train=[%d %d], min_range=%.0f km)...\n'], ...
        cfar_type, pfa, Ng_r, Ng_d, Nt_r, Nt_d, min_range_m / 1e3);
end

rdm_linear = 10.^(rdm_db / 10);
[N_range, N_dopp] = size(rdm_linear);

[rdm_cfar, notch_cols] = localApplyNotchFill(rdm_linear, doppler_axis, Nt_d, ...
    options.notch_guard_dopp_bins);

range_bin_min = find(range_axis >= min_range_m, 1, 'first');
if isempty(range_bin_min)
    detections = zeros(0, 3);
    threshold_map = NaN(size(rdm_db));
    nf_db = NaN;
    detector_debug = struct( ...
        'cutidx', zeros(2, 0), ...
        'threshold_factor', NaN, ...
        'noise_power_map', NaN(size(rdm_db)));
    if verbose
        fprintf('  No detections above threshold.\n');
    end
    return
end

[cutidx, cut_mask] = localBuildValidCutIndices( ...
    N_range, N_dopp, range_bin_min, Ho_r, Ho_d);
if isempty(cutidx)
    detections = zeros(0, 3);
    threshold_map = NaN(size(rdm_db));
    nf_db = NaN;
    detector_debug = struct( ...
        'cutidx', zeros(2, 0), ...
        'threshold_factor', NaN, ...
        'noise_power_map', NaN(size(rdm_db)));
    if verbose
        fprintf('  No valid CUTs remain after the geometry exclusions.\n');
    end
    return
end

N_train_nom = localNominalTrainingCellCount(Ho_r, Ho_d, Ng_r, Ng_d);
alpha_scalar = localGammaThresholdFactor(pfa, N_train_nom, L_nci);

detector = localBuildToolboxDetector(cfar_type, guard_cells, train_cells, ...
    N_train_nom, options.os_rank_fraction, alpha_scalar);
cleanup_detector = onCleanup(@() release(detector));

[~, threshold_vals, noise_vals] = detector(rdm_cfar, cutidx);

threshold_linear = NaN(N_range, N_dopp);
noise_power_map = NaN(N_range, N_dopp);
cut_linear_idx = sub2ind([N_range, N_dopp], cutidx(1, :), cutidx(2, :));
threshold_linear(cut_linear_idx) = threshold_vals(:);
noise_power_map(cut_linear_idx) = noise_vals(:);

threshold_linear_eff = threshold_linear;
if ~isempty(options.atsc_guard_ranges_m)
    pen_linear = 10^(options.atsc_guard_penalty_db / 10);
    pen_w = options.atsc_guard_width_bins;
    for k_gz = 1 : numel(options.atsc_guard_ranges_m)
        [~, ghost_bin] = min(abs(range_axis - options.atsc_guard_ranges_m(k_gz)));
        guard_bins = max(1, ghost_bin - pen_w) : min(N_range, ghost_bin + pen_w);
        threshold_linear_eff(guard_bins, :) = threshold_linear_eff(guard_bins, :) * pen_linear;
    end
end

detect_mask = false(N_range, N_dopp);
detect_mask(cut_linear_idx) = rdm_linear(cut_linear_idx) > threshold_linear_eff(cut_linear_idx);

if options.min_snr_db > 0
    snr_factor = 10^(options.min_snr_db / 10);
    detect_mask(cut_linear_idx) = rdm_linear(cut_linear_idx) > ...
        (threshold_linear_eff(cut_linear_idx) * snr_factor);
end

if options.local_maxima
    lm_r = options.lm_range_bins;
    lm_d = options.lm_dopp_bins;
    N_lm = (2 * lm_r + 1) * (2 * lm_d + 1);
    lm_domain = true(2 * lm_r + 1, 2 * lm_d + 1);
    local_max_map = ordfilt2(rdm_linear, N_lm, lm_domain);
    detect_mask = detect_mask & (rdm_linear >= local_max_map);
end

% Mirror the custom detector's final exclusion zones so the comparison
% changes only the CFAR statistic, not the reporting geometry.
if N_range > Ho_r
    detect_mask(N_range - Ho_r + 1 : end, :) = false;
end

dopp_bin_width = localResolveDopplerBinWidth(doppler_axis);
edge_dopp_hz = Ho_d * dopp_bin_width;
suppress_dopp_edge = abs(doppler_axis) > (max(abs(doppler_axis)) - edge_dopp_hz);
detect_mask(:, suppress_dopp_edge) = false;

if options.notch_guard_dopp_bins > 0
    notch_half_hz = (options.notch_guard_dopp_bins + 0.5) * dopp_bin_width;
else
    notch_half_hz = 3.5;
end
suppress_dopp_zero = abs(doppler_axis(:)) <= notch_half_hz;
detect_mask(:, suppress_dopp_zero) = false;

threshold_map = 10 * log10(threshold_linear_eff + eps);

nf_valid_mask = cut_mask;
if ~isempty(notch_cols)
    nf_valid_mask(:, notch_cols) = false;
end
nf_samples = noise_power_map(nf_valid_mask);
nf_samples = nf_samples(isfinite(nf_samples) & nf_samples > 0);
if isempty(nf_samples)
    nf_db = NaN;
else
    nf_db = 10 * log10(max(median(nf_samples, 'all'), eps));
end

[r_idx, d_idx] = find(detect_mask);
if isempty(r_idx)
    detections = zeros(0, 3);
    if verbose
        fprintf('  No detections above threshold.\n');
    end
else
    det_range = range_axis(r_idx);
    det_dopp = doppler_axis(d_idx);
    det_power = rdm_db(sub2ind([N_range, N_dopp], r_idx, d_idx));
    detections = [det_range(:), det_dopp(:), det_power(:)];
    if verbose
        fprintf('  %d detections found.\n', size(detections, 1));
    end
end

detector_debug = struct( ...
    'cutidx', cutidx, ...
    'threshold_factor', alpha_scalar, ...
    'noise_power_map', noise_power_map);

clear cleanup_detector
end

function [rdm_cfar, notch_cols] = localApplyNotchFill(rdm_linear, doppler_axis, Nt_d, notch_guard_dopp_bins)
[N_range, N_dopp] = size(rdm_linear);
rdm_cfar = rdm_linear;
notch_cols = zeros(1, 0);

if notch_guard_dopp_bins <= 0
    return
end

[~, z_bin] = min(abs(doppler_axis));
notch_cols = max(1, z_bin - notch_guard_dopp_bins) : min(N_dopp, z_bin + notch_guard_dopp_bins);
left_ref_cols = max(1, min(notch_cols) - Nt_d) : max(1, min(notch_cols) - 1);
right_ref_cols = min(N_dopp, max(notch_cols) + 1) : min(N_dopp, max(notch_cols) + Nt_d);
ref_cols_cfar = [left_ref_cols, right_ref_cols];
ref_cols_cfar = ref_cols_cfar(ref_cols_cfar >= 1 & ref_cols_cfar <= N_dopp);

if numel(ref_cols_cfar) >= 2
    fill_vals = median(rdm_linear(:, ref_cols_cfar), 2);
else
    fill_vals = repmat(median(rdm_linear(:)), N_range, 1);
end

rdm_cfar(:, notch_cols) = repmat(fill_vals, 1, numel(notch_cols));
end

function [cutidx, cut_mask] = localBuildValidCutIndices( ...
    N_range, N_dopp, range_bin_min, Ho_r, Ho_d)
cut_mask = false(N_range, N_dopp);
row_start = max(range_bin_min, Ho_r + 1);
row_stop = N_range - Ho_r;
col_start = Ho_d + 1;
col_stop = N_dopp - Ho_d;

if row_start > row_stop || col_start > col_stop
    cutidx = zeros(2, 0);
    return
end

[row_grid, col_grid] = ndgrid(row_start:row_stop, col_start:col_stop);
cutidx = [row_grid(:).'; col_grid(:).'];
cut_mask(row_start:row_stop, col_start:col_stop) = true;
end

function detector = localBuildToolboxDetector( ...
    cfar_type, guard_cells, train_cells, N_train_nom, os_rank_fraction, alpha_scalar)
detector_kwargs = { ...
    'Method', cfar_type, ...
    'GuardBandSize', guard_cells(:).', ...
    'TrainingBandSize', train_cells(:).', ...
    'ThresholdFactor', 'Custom', ...
    'CustomThresholdFactor', alpha_scalar, ...
    'OutputFormat', 'CUT result', ...
    'ThresholdOutputPort', true, ...
    'NoisePowerOutputPort', true};

if strcmpi(cfar_type, 'OS')
    rank_value = max(1, min(N_train_nom, floor(os_rank_fraction * N_train_nom)));
    detector_kwargs = [detector_kwargs, {'Rank', rank_value}];
end

detector = phased.CFARDetector2D(detector_kwargs{:});
end

function count = localNominalTrainingCellCount(Ho_r, Ho_d, Ng_r, Ng_d)
outer_count = (2 * Ho_r + 1) * (2 * Ho_d + 1);
inner_count = (2 * Ng_r + 1) * (2 * Ng_d + 1);
count = max(1, outer_count - inner_count);
end

function alpha_value = localGammaThresholdFactor(pfa, n_train, n_looks)
if n_looks <= 1
    alpha_value = n_train * (pfa^(-1 / n_train) - 1);
else
    x_value = betaincinv(1 - pfa, n_looks, n_train * n_looks);
    alpha_value = x_value * n_train / max(1 - x_value, eps);
end
end

function dopp_bin_width = localResolveDopplerBinWidth(doppler_axis)
if numel(doppler_axis) < 2
    dopp_bin_width = 1;
else
    dopp_bin_width = abs(median(diff(doppler_axis)));
end
end
