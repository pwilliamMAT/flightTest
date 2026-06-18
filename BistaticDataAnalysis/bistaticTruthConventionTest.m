classdef bistaticTruthConventionTest < matlab.unittest.TestCase
    %BISTATICTRUTHCONVENTIONTEST Focused regression coverage for shared conventions.

    properties (Constant)
        TxLLA = [42.310278, -71.236667, 431.9];
        RxLLA = [42.2999333, -71.349333, 15.0];
        Fc = 599e6;
        Fs = 8e6;
    end

    properties (TestParameter)
        rangeRateCase = struct( ...
            'approaching', struct('rdot_mps', -120), ...
            'receding', struct('rdot_mps', 95));
    end

    methods (Test)
        function testSharedConstantsMatchCAFAxes(testCase)
            cfg = struct( ...
                'fc', testCase.Fc, ...
                'fs', testCase.Fs, ...
                'N_slow_cpi', 200, ...
                'cpi_duration_s', 0.5e-3);

            consts = helperDeriveBistaticConstants(cfg);
            ref_cube = repmat(localReferenceWaveform(64), 1, cfg.N_slow_cpi);
            surv_cube = ref_cube;
            [~, doppler_axis, range_axis, ~] = createRDM( ...
                surv_cube, ref_cube, cfg.fs, 1 / cfg.cpi_duration_s, 0, false);

            testCase.verifyEqual(consts.alpha, testCase.Fc / physconst('LightSpeed'), ...
                AbsTol=1e-12);
            testCase.verifyEqual(consts.range_cell_m, median(diff(range_axis)), ...
                AbsTol=1e-9);
            testCase.verifyEqual(consts.doppler_bin_hz, median(diff(doppler_axis)), ...
                AbsTol=1e-12);
            testCase.verifyEqual(consts.doppler_bin_hz, 10, AbsTol=1e-12);
        end

        function testCreateRDMMatchesPassiveCAFDopplerConvention(testCase, rangeRateCase)
            fs = 1e6;
            prf = 1000;
            n_fast = 64;
            n_slow = 128;
            delay_samp = 5;
            c_light = physconst('LightSpeed');

            ref_wave = localReferenceWaveform(n_fast);
            ref_cube = repmat(ref_wave, 1, n_slow);
            t_slow = (0:n_slow-1) / prf;
            phase_ramp = exp(-1j * 2 * pi * (testCase.Fc / c_light) * ...
                rangeRateCase.rdot_mps * t_slow);
            delayed = [zeros(delay_samp, 1); ref_wave(1:end-delay_samp)];
            surv_cube = delayed .* phase_ramp;

            [rdm, doppler_axis, range_axis, ~] = createRDM( ...
                surv_cube, ref_cube, fs, prf, 0, false);
            [~, r_idx] = min(abs(range_axis - delay_samp * c_light / fs));
            [~, d_idx] = max(rdm(r_idx, :));

            expected_fd = helperBistaticDopplerFromRangeRate( ...
                rangeRateCase.rdot_mps, testCase.Fc);
            testCase.verifyEqual(doppler_axis(d_idx), expected_fd, ...
                AbsTol=median(abs(diff(doppler_axis))));
        end

        function testTruthProjectionUsesThreeDimensionalBaseline(testCase)
            testCase.assumeNotEmpty(which('geodetic2enu'));

            t0 = posixtime(datetime(2026, 6, 16, 16, 7, 2, 'TimeZone', 'UTC'));
            ac_track = struct( ...
                'hex', "ABC123", ...
                'callsign', "TEST123", ...
                't_utc', [t0; t0 + 2], ...
                'lat_deg', [42.3600; 42.3600], ...
                'lon_deg', [-71.2800; -71.2800], ...
                'alt_m', [3200; 3200]);

            bist = adsbToBistatic(ac_track, testCase.TxLLA, testCase.RxLLA, testCase.Fc);
            geom = helperDeriveTxRxGeometry(testCase.TxLLA, testCase.RxLLA);

            [ac_e_rx, ac_n_rx, ac_u_rx] = geodetic2enu( ...
                ac_track.lat_deg(1), ac_track.lon_deg(1), ac_track.alt_m(1), ...
                testCase.RxLLA(1), testCase.RxLLA(2), testCase.RxLLA(3), geom.spheroid);
            [ac_e_tx, ac_n_tx, ac_u_tx] = geodetic2enu( ...
                ac_track.lat_deg(1), ac_track.lon_deg(1), ac_track.alt_m(1), ...
                testCase.TxLLA(1), testCase.TxLLA(2), testCase.TxLLA(3), geom.spheroid);

            expected_r = norm([ac_e_rx, ac_n_rx, ac_u_rx]) + ...
                norm([ac_e_tx, ac_n_tx, ac_u_tx]) - geom.baseline_3d_m;

            testCase.verifyEqual(bist.L_m, geom.baseline_3d_m, AbsTol=1e-9);
            testCase.verifyGreaterThan(geom.baseline_3d_m - geom.baseline_horizontal_m, 1);
            testCase.verifyEqual(bist.R_excess_m(1), expected_r, AbsTol=1e-6);
        end

        function testRangeRateRoundTripAndTrackHistoryShareTheSameConvention(testCase)
            rdot_mps = -87.5;
            fd_hz = helperBistaticDopplerFromRangeRate(rdot_mps, testCase.Fc);
            rdot_roundtrip = helperBistaticRangeRateFromDoppler(fd_hz, testCase.Fc);

            snapshot = struct( ...
                'time', 12.5, ...
                'tracks', struct( ...
                    'TrackID', 42, ...
                    'State', [15000; rdot_mps], ...
                    'StateCovariance', eye(2)), ...
                'n_confirmed', 1);

            history = helperTracksLogToHistories(snapshot, testCase.Fc);

            testCase.verifyEqual(rdot_roundtrip, rdot_mps, AbsTol=1e-12);
            testCase.verifyEqual(history.f_D_hz, fd_hz, AbsTol=1e-12);
            testCase.verifyEqual(history.Rdot_mps, rdot_mps, AbsTol=1e-12);
        end

        function testInitMeasurementSpaceKFUsesSharedConversions(testCase)
            testCase.assumeNotEmpty(which('objectDetection'));
            testCase.assumeNotEmpty(which('trackingKF'));

            rdot_mps = -95;
            fd_hz = helperBistaticDopplerFromRangeRate(rdot_mps, testCase.Fc);
            det = objectDetection(0, [12000; fd_hz], 'MeasurementNoise', eye(2));

            filter = initMeasurementSpaceKF(det, testCase.Fc, testCase.Fs, 10);
            alpha = helperBistaticDopplerCoupling(testCase.Fc);

            testCase.verifyEqual(filter.State(2), rdot_mps, AbsTol=1e-12);
            testCase.verifyEqual(filter.MeasurementModel(2, 2), -alpha, AbsTol=1e-12);
            testCase.verifyEqual(filter.MeasurementNoise(1, 1), ...
                (3 * physconst('LightSpeed') / testCase.Fs)^2, AbsTol=1e-6);
        end
    end
end

function ref_wave = localReferenceWaveform(n_fast)
t = (0:n_fast-1).';
ref_wave = exp(1j * 2 * pi * (0.17 * t + 0.013 * t.^2 / max(n_fast, 1)));
end
