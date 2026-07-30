function snr = helperMeasureSNR(surv, ref, cfg, testFcn)
    % helperMeasureSNR  Measure SNR in range-Doppler space with injected targets.
    %   snr = helperMeasureSNR(surv, ref, cfg, testFcn) injects synthetic
    %   targets into the surveillance channel at each attenuation level in
    %   cfg.Attenuation and measures the resulting SNR after processing
    %   with testFcn.
    %
    %   Inputs:
    %       surv    - Surveillance channel data
    %       ref     - Reference channel data
    %       cfg     - SignalProcessingConfig object
    %       testFcn - Function handle: [rd,range,speed] = testFcn(surv,ref)
    %
    %   Output:
    %       snr     - Mean SNR for each attenuation level

    % Set rng so test is always the same
    rng(cfg.RngSeed);

    nAttenuation = length(cfg.Attenuation);
    snr = zeros(nAttenuation, 1);
    for iAttenuation = 1:nAttenuation
        % Run tests for each attenuation level
        tAttenuation = cfg.Attenuation(iAttenuation);

        % Measure SNR repeatedly in magnitude units
        allSnr = zeros(cfg.NRuns, 1);
        for iRun = 1:cfg.NRuns
            % Create surveillance channel with synthetic target
            tRange = rand * (cfg.MaxRange - cfg.MinRange) + cfg.MinRange;
            tSpeed = (rand * (cfg.MaxSpeed - cfg.MinSpeed) ...
                + cfg.MinSpeed) * sign((rand - 0.5));
            survWithTarget = injectSyntheticTarget( ...
                surv, ref, cfg.Fs, cfg.Fc, tRange, tSpeed, tAttenuation);

            % Use test function to generate rd map
            [rd, range, speed] = testFcn(survWithTarget, ref);

            % Get position of nearest range-Doppler cell
            [~, rangeIdx] = min(abs(range - tRange));
            [~, speedIdx] = min(abs(speed - tSpeed));

            % Get position of noise cells
            noiseCells = getNoiseCells( ...
                range, speed, rangeIdx, speedIdx, ...
                cfg.NGuard, cfg.NTrain);

            % Get magnitude of nearest range-Doppler cell
            sigMag = rms(rd(rangeIdx, speedIdx));

            % Measure noise of nearest range-Doppler cell
            noiseMag = rms(rd(noiseCells));

            % Record snr
            allSnr(iRun) = sigMag / noiseMag;
        end

        % Record snr for all runs
        snr(iAttenuation) = mean(allSnr);
    end

    function cells = getNoiseCells( ...
            range, speed, rangeIdx, speedIdx, nGuard, nTrain)
        % Get the cells to test for noise
        nRange = length(range);
        nSpeed = length(speed);

        % Initialize indices
        cells = false(nRange, nSpeed);

        % Get the upper and lower training regions
        [rGuardLower, rGuardUpper, rTrainLower, rTrainUpper] = ...
            getTrainIndicies(rangeIdx, nRange, nGuard, nTrain);
        [sGuardLower, sGuardUpper, sTrainLower, sTrainUpper] = ...
            getTrainIndicies(speedIdx, nSpeed, nGuard, nTrain);

        % Set training cells to true
        cells(rTrainLower:rTrainUpper, sTrainLower:sTrainUpper) = true;
        cells(rGuardLower:rGuardUpper, sGuardLower:sGuardUpper) = false;

        function [guardLower, guardUpper, trainLower, trainUpper] = ...
                getTrainIndicies(cutIdx, nCells, nGuard, nTrain)
            guardLower = max(cutIdx - nGuard, 1);
            guardUpper = min(cutIdx + nGuard, nCells);
            trainLower = max(cutIdx - nGuard - nTrain, 1);
            trainUpper = min(cutIdx + nGuard + nTrain, nCells);
        end
    end
end
