function [survest, h] = helperWienerHopfFilter(surv, ref, M)
    % helperWienerHopfFilter  DSI suppression using Wiener-Hopf filter.
    %   [survest, h] = helperWienerHopfFilter(surv, ref, M) computes M
    %   Wiener-Hopf filter taps and removes the filtered reference from
    %   the surveillance channel.

    % Get filter taps
    h = helperWienerHopfTaps(surv, ref, M);

    % Remove the filtered reference from surveillance
    survest = helperFilterSurv(surv, ref, h);
end
