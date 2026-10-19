function status = helperLLWalkthroughExport(studyFolder) %#ok<INUSD>
%HELPERLLWALKTHROUGHEXPORT Run existing verification/export in private scope.
% The runner rereads localizationLikelihoodConfig.m. Variables such as cfg,
% study and its cleanup objects never replace the Live Script's variables.
% Existing progress/test output is captured; execution failures propagate.
executionLog = evalc('run(fullfile(studyFolder,"runLocalizationLikelihoodPOC.m"));'); %#ok<NASGU>
status = table(nnz(study.tests.Passed),height(study.tests), ...
    string(study.baseline.mode),numel(study.figureFiles),string(study.baseline.cfg.outputDir), ...
    VariableNames=["TestsPassed","TestsRun","PhysicalMode","FiguresExported","ResultsFolder"]);
end
