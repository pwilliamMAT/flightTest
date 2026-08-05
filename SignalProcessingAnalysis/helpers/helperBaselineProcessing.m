function [rd, range, doppler] = helperBaselineProcessing(surv, ref, filterFcn, rdFcn)
    % Baseline processing applies a DSI suppression function and then does
    % range-Doppler processing on the filtered output.

    % DSI suppression
    survFiltered = filterFcn(surv, ref);

    % Range-Doppler processing
    [rd, range, doppler] = rdFcn(survFiltered, ref);
end