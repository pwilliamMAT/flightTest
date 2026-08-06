function h = helperWienerHopfTaps(surv, ref, M)
    % helperWienerHopfTaps  Compute Wiener-Hopf filter coefficients.
    %   h = helperWienerHopfTaps(surv, ref, M) computes M filter taps
    %   by solving the Wiener-Hopf equation using the autocorrelation of
    %   ref and cross-correlation between surv and ref.

    % Compute autocorrelation and cross-correlation with conjugates
    rxx = xcorr(ref, M-1, 'biased');
    rsx = xcorr(surv, ref, M-1, 'biased');

    % Extract centered values (zero lag at index M)
    Rxx = toeplitz(rxx(M:end));
    rsx_vec = conj(rsx(M:end));

    % Solve Wiener-Hopf equation
    h = conj(Rxx \ rsx_vec);
end
