function survest = helperFilterSurv(surv, ref, h)
    % helperFilterSurv  Remove filtered reference from surveillance.
    %   survest = helperFilterSurv(surv, ref, h) applies the filter
    %   coefficients h to ref and subtracts the result from surv.

    survest = surv - filter(h, 1, ref);
end
