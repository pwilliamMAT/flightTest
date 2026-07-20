function snr = helperMeasureSNR(surv,ref,attenuation,fs,fc,minRange,maxRange,minSpeed,maxSpeed,nGuard,nTrain,nRuns,rNum,testFcn)
    % Measure the SNR in range-Doppler space when a target is injected into
    % the surveillance channel at the attenuation level, where the baseline
    % is the magnitude of the signal.

    % Set rng so test is always the same
    rng(rNum);

    nAttenuation = length(attenuation);
    snr = zeros(nAttenuation,1);
    for iAttenuation = 1:nAttenuation
        % Run tests for each attenuation level
        tAttenuation = attenuation(iAttenuation);
        
        % Measure SNR repeatedly in magnitude units
        allSnr = zeros(nRuns,1);
        for iRun = 1:nRuns
            % Create surveillance channel with synthetic target
            tRange = rand*(maxRange-minRange)+minRange;
            tSpeed = (rand*(maxSpeed-minSpeed)+minSpeed)*sign((rand-0.5));
            survWithTarget = injectSyntheticTarget(surv,ref,fs,fc,tRange,tSpeed,tAttenuation);

            % Use test function to generate rd map
            [rd,range,speed] = testFcn(survWithTarget,ref);

            % Get position of nearest range-Doppler cell
            [~,rangeIdx] = min(abs(range-tRange));
            [~,speedIdx] = min(abs(speed-tSpeed));

            % Get position of noise cells
            noiseCells = getNoiseCells(range,speed,rangeIdx,speedIdx,nGuard,nTrain);

            % Get magnitude of nearest range-Doppler cell
            sigMag = rms(rd(rangeIdx,speedIdx));

            % Measure noise of nearest range-Doppler cell
            noiseMag = rms(rd(noiseCells));

            % Record snr
            allSnr(iRun) = sigMag/noiseMag;
        end

        % Record snr for all runs
        snr(iAttenuation) = mean(allSnr);
    end

    function cells = getNoiseCells(range,speed,rangeIdx,speedIdx,nGuard,nTrain)
        % Get the cells to test for noise
        nRange = length(range);
        nSpeed = length(speed);

        % Initialize indices
        cells = false(nRange,nSpeed);

        % Get the upper and lower training regions for range and speed
        [rGuardLower,rGuardUpper,rTrainLower,rTrainUpper] = getTrainIndicies(rangeIdx,nRange,nGuard,nTrain);
        [sGuardLower,sGuardUpper,sTrainLower,sTrainUpper] = getTrainIndicies(speedIdx,nSpeed,nGuard,nTrain);

        % Set training cells to true
        cells(rTrainLower:rTrainUpper,sTrainLower:sTrainUpper) = true;
        cells(rGuardLower:rGuardUpper,sGuardLower:sGuardUpper) = false;
        
        function [guardLower,guardUpper,trainLower,trainUpper] = getTrainIndicies(cutIdx,nCells,nGuard,nTrain)
            guardLower = max(cutIdx-nGuard,1);
            guardUpper = min(cutIdx+nGuard,nCells);
            trainLower = max(cutIdx-nGuard-nTrain,1);
            trainUpper = min(cutIdx+nGuard+nTrain,nCells);
        end
    end    
end