function sensitivity = helperLLSensitivities(result)
%HELPERLLSENSITIVITIES Change error/gate assumptions without repeating RF.
% Range uncertainty is independent of SNR here: one controls covariance;
% the other controls which scalar constraints are available at all.
cfg = result.cfg;
allSummary = {};
allAttribution = {};
k = 0;
for sigma = cfg.rangeSigmaSensitivityM
    for gate = cfg.snrGateSensitivityDB
        k = k+1;
        changed = cfg;
        changed.rangeSigmaM = sigma;
        changed.snrGateDB = gate;
        analysis = helperLLAnalyze(changed,result.grid,result.terrain,result.rf);
        [s,a] = helperLLSummaries(changed,result.grid,analysis);
        allSummary{k} = s; %#ok<AGROW>
        allAttribution{k} = a; %#ok<AGROW>
        sensitivity.cases(k).sigmaM = sigma;
        sensitivity.cases(k).gateDB = gate;
        for altitude = 1:numel(analysis)
            baseline = analysis(altitude).configurations(4);
            third = analysis(altitude).configurations(5);
            sensitivity.cases(k).useful2D(:,:,altitude) = ...
                [baseline.available2D.useful third.available2D.useful];
            sensitivity.cases(k).useful3D(:,:,altitude) = ...
                [baseline.available3D.useful third.available3D.useful];
        end
    end
end
sensitivity.summary = vertcat(allSummary{:});
sensitivity.attribution = vertcat(allAttribution{:});
end
