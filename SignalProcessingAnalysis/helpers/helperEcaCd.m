function [x,ref] = helperEcaCd(surv,ref,nCancelBins,nPulse)
    % Rearrange the surveillance and reference channel into nPulses. Clip
    % the input data to fit nPulses.
    ns = length(surv);
    nSamplePerPulse = floor(ns/nPulse);
    ns = nSamplePerPulse*nPulse;
    surv = surv(1:ns);
    ref = ref(1:ns);
    survMat = reshape(surv,[nSamplePerPulse nPulse]);
    refMat = reshape(ref,[nSamplePerPulse nPulse]);
    
    % Convert time-domain signal in frequency domain
    X = fft(survMat,[],1);
    Xref = fft(refMat,[],1);
    
    % Doppler spread matrix
    dopres = 1/nPulse;
    dopSpreadMatrix = dopsteeringvec((-nCancelBins*dopres:dopres:nCancelBins*dopres),nPulse);
    
    % Interference mitigation in slow-time
    Xcancel = zeros(nSamplePerPulse,nPulse);
    for iSample = 1:nSamplePerPulse
        % Signals over slow-time
        xRefSlow = Xref(iSample,:).';
        xSlow = X(iSample,:).';
    
        % If interference has Doppler spread, consider these spreaded Doppler
        % for interference nulling
        xRefSlow = dopSpreadMatrix.*xRefSlow;
    
        % Projection matrix onto the interference subspace
        projectMatrix = xRefSlow/(xRefSlow'*xRefSlow)*xRefSlow';
    
        % Cancel interference 
        Xcancel(iSample,:) = xSlow - projectMatrix*xSlow;
    end
    
    % Convert signal back to time-domain
    x = ifft(Xcancel);
    x = reshape(x,[ns 1]);
end