function survFiltered = helperBlmsFilter(surv, ref, nTaps)
    % helperBlmsFilter  DSI suppression using Block LMS adaptive filter.
    %   survFiltered = helperBlmsFilter(surv, ref, nTaps) uses the Block
    %   LMS algorithm to adaptively estimate and remove the direct-path
    %   interference from the surveillance channel.
    %
    %   The filter is initialized with Wiener-Hopf coefficients and uses
    %   a step size derived from the surveillance signal covariance to
    %   ensure convergence.
    %
    %   Inputs:
    %       surv  - Surveillance channel data
    %       ref   - Reference channel data
    %       nTaps - Number of filter taps
    %
    %   Output:
    %       survFiltered - Surveillance with DSI removed (error signal)

    % Block size is 10x the filter length
    blockSize = nTaps * 10;

    % Compute step size from surveillance covariance
    covSize = min(1e3, length(surv));
    covMatrix = (surv(1:covSize) * surv(1:covSize)') / covSize;
    stepSize = 1 / (2 * blockSize * max(eig(covMatrix)));

    % Initialize with Wiener-Hopf estimate
    hinit = helperWienerHopfTaps(surv, ref, nTaps);

    % Truncate to a multiple of blockSize
    nSamples = floor(length(surv) / blockSize) * blockSize;
    surv = surv(1:nSamples);
    ref = ref(1:nSamples);

    % Configure BLMS filter
    blms = dsp.BlockLMSFilter( ...
        Length=nTaps, ...
        BlockSize=blockSize, ...
        StepSize=stepSize, ...
        InitialWeights=hinit);

    % Apply filter: ref is input, surv is desired, error is DSI-suppressed
    [~, survFiltered] = blms(ref, surv);
end
