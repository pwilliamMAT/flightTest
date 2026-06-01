function filter = initMeasurementSpaceKF(detection, fc, fs, doppler_bin_hz)
%INITMEASUREMENTSPACEKF  Initialize a 2-state linear Kalman filter for
%  passive bistatic radar tracking in the Range–Doppler measurement space.
%
%  fc             [Hz]  carrier frequency  (default 600 MHz — legacy)
%  fs             [Hz]  sample rate        (default 5 Msps  — legacy)
%  doppler_bin_hz [Hz]  Doppler bin size   (default 10 Hz  — legacy)
%
%  Called via a closure in trackTargets:
%    init_fcn = @(det) initMeasurementSpaceKF( ...
%        det, config.fc, config.fs, doppler_bin_hz);
%
% ── STATE VECTOR ─────────────────────────────────────────────────────────
%   x = [R (m);  Ṙ (m/s)]
%       bistatic range excess,  bistatic range rate
%
%   Bistatic Doppler (Hz) and bistatic range rate (m/s) are related by the
%   carrier frequency and a sign that follows from the passive-radar CAF:
%
%       f_D  =  −(2·fc / c) · Ṙ  =  −α · Ṙ        (monostatic approx.)
%
%   SIGN CONVENTION (verified from createRDM.m):
%     createRDM builds the RDM as fftshift(fft(IFFT(FFT_surv × conj(FFT_ref)))).
%     A target whose bistatic path is DECREASING (approaching) produces a
%     POSITIVE f_D in the RDM.  Therefore:
%
%         positive f_D  →  approaching  →  Ṙ < 0
%
%     The measurement model must be  f_D = −α · Ṙ.
%     Using +α (the active-radar convention) inverts predicted range motion
%     relative to measured Doppler, causing tracks to diverge immediately.
%
%   Tracking a 4-state [R; Ṙ; D; Ḋ] model would double-count Ṙ under two
%   names.  Instead, this 2-state model uses a coupled measurement matrix H
%   so that BOTH the range cell AND the Doppler cell independently constrain
%   the single Ṙ state.
%
% ── MEASUREMENT MODEL ────────────────────────────────────────────────────
%   z = H · x     where     H = [1,   0  ]
%                                [0,  −α  ]
%
%   z(1) = R_meas  (m)   — direct range measurement from RDM y-axis
%   z(2) = D_meas  (Hz)  — direct Doppler measurement from RDM x-axis
%
%   The −α term encodes the CAF sign convention: approaching target gives
%   positive f_D but negative Ṙ (range decreasing).
%
% ── MOTION MODEL ─────────────────────────────────────────────────────────
%   Constant-velocity in bistatic range.  Using trackingKF with built-in
%   'constvel' MotionModel gives automatic variable-Δt behaviour:
%
%     F(Δt) = [1  Δt]     Q(Δt) = q · [Δt³/3   Δt²/2]
%             [0   1]                  [Δt²/2   Δt   ]
%
%   where q = σ_a² is the acceleration power spectral density.  MATLAB's
%   trackingKF recomputes F and Q at each predict(filter, dt) call, so the
%   tracker natively handles both the 100 ms within-part block intervals
%   AND the hardcoded 10 s inter-part gap without any manual adjustment.
%
% ── SYSTEM CONSTANTS (passed via closure; defaults are legacy 5 Msps/600 MHz)
%   fc         → α = 2·fc/c   (Doppler coupling)
%   fs         → range bin = c/(2·fs)
%   N_slow_cpi = 200,  T_cpi = 0.5 ms  → Doppler bin = 1/(200·0.5e-3) = 10 Hz
%
% ── USAGE ─────────────────────────────────────────────────────────────────
%   Called automatically by trackerGNN via its FilterInitializationFcn.
%   The detection must be an objectDetection with:
%     Measurement       = [R_m (m);  D_hz (Hz)]
%     MeasurementNoise  = diag([(3·range_bin)², (2·dopp_bin)²])  — must match R_meas here
%
% ── TOOLBOX ──────────────────────────────────────────────────────────────
%   Sensor Fusion and Tracking Toolbox  (trackingKF, objectDetection)
%   Signal Processing Toolbox           (physconst)

% ── System constants (passed from config via closure in trackTargets) ─────
if nargin < 2 || isempty(fc),             fc = 600e6; end   % legacy default
if nargin < 3 || isempty(fs),             fs = 5e6;   end   % legacy default
if nargin < 4 || isempty(doppler_bin_hz), doppler_bin_hz = 10; end
c_light = physconst('LightSpeed');    % speed of light  [m/s]
alpha   = 2 * fc / c_light;           % Doppler coupling [Hz/(m/s)]

% ── Resolution cell sizes ────────────────────────────────────────────────
range_bin_m  = c_light / (2 * fs);   % range bin [m] — depends on sample rate
dopp_bin_hz  = doppler_bin_hz;

% ── Measurement model  H : z = H · x ────────────────────────────────────
%   Negative α: passive-radar CAF sign convention (positive f_D = approaching
%   = Ṙ < 0).  Using +α inverts predicted range motion vs measured Doppler.
H = [1,      0    ;   % z(1) = R
     0,  -alpha   ];  % z(2) = −α·Ṙ = f_D  (positive for approaching)

% ── Measurement noise covariance  R_meas ─────────────────────────────────
%   Variance = (N bins)² to account for:
%     Range:   3 bins — CFAR centroid accuracy ±0.5 bin, target smear across
%              2–3 bins, bistatic-geometry projection residuals.
%     Doppler: 2 bins — Kaiser window broadens the 3 dB width; interpolation
%              errors ±0.5 bin; Doppler walk within the 100 ms block.
%   Must match the R_meas passed as MeasurementNoise in trackTargets.
R_meas = diag([(3 * range_bin_m)^2, (2 * dopp_bin_hz)^2]);

% ── Process noise intensity  q ────────────────────────────────────────────
%   'constvel' MotionModel interprets ProcessNoise as the continuous-time
%   acceleration PSD  q [m²/s³].  Discrete Q is computed as:
%     Q(Δt) = q · [Δt³/3  Δt²/2; Δt²/2  Δt]
%
%   σ_a = 50 m/s²  covers commercial aircraft manoeuvres and bistatic
%   acceleration (range-rate changes due to changing geometry, not just
%   aircraft G-loading).  At the Natick deployment geometry, a 1 g turn
%   can produce bistatic range-rate changes of 30–80 m/s².
%     Δt = 0.1 s  →  σ_R_added = √(q·Δt³/3) ≈ 0.9 m   (within-part)
%     Δt = 3.0 s  →  σ_R_added = √(q·Δt³/3) ≈ 150 m  (inter-part gap, 8 bins)
sigma_a = 50;          % [m/s²]
q_psd   = sigma_a^2;   % [m²/s³] — ProcessNoise scalar for 'constvel'

% ── Initial state from first detection ───────────────────────────────────
z0    = detection.Measurement;   % [R_m (m); D_hz (Hz)]
R0    = z0(1);                   % initial bistatic range  [m]
%   Ṙ₀ = -f_D / α.  Sign is critical: positive f_D = approaching = Ṙ < 0.
%   Using +f_D/α would seed range-rate with the wrong sign, making the
%   filter predict range moving in the opposite direction to all measurements.
Rdot0 = -z0(2) / alpha;          % seed Ṙ₀: Ṙ = -f_D / α  [m/s]
x0    = [R0; Rdot0];

% ── Initial state covariance  P₀ ─────────────────────────────────────────
%   Range:      1 bin² variance — range measurement is well-localised.
%   Range rate: wide uncertainty (±50 bins) — we trust the Doppler seed
%               but allow for bistatic geometry effects not captured by the
%               monostatic approximation.
P0 = diag([range_bin_m^2, (50 * range_bin_m / alpha)^2]);

% ── Construct trackingKF ──────────────────────────────────────────────────
%   MotionModel = '1D Constant Velocity' with a 2-element State → 1-D
%   constant-velocity filter.  MeasurementModel overrides the default 1-D
%   H = [1 0] to enable the joint 2-measurement [R; D_hz] observation vector.
filter = trackingKF( ...
    'MotionModel',      '1D Constant Velocity',  ...
    'State',            x0,          ...
    'StateCovariance',  P0,          ...
    'ProcessNoise',     q_psd,       ...
    'MeasurementModel', H,           ...
    'MeasurementNoise', R_meas);

end
