% FlightTest localization-likelihood POC (MATLAB R2026a).
% From the flightTest root:
% run("TrackingPreWork/analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m")
%
% Read docs/localizationLikelihood/repositorySurvey.md first. This script
% creates deterministic study products; it does not run the IQ pipeline.
studyFolder = fileparts(mfilename("fullpath"));
previousPath = path;
restorePath = onCleanup(@() path(previousPath));
addpath(studyFolder);
cfg = localizationLikelihoodConfig();
if ~isfolder(cfg.outputDir)
    mkdir(cfg.outputDir);
end

%% 1. Verify conventions before constructing the physical study.
% A range is a constraint on position. Several accurately measured but
% similarly directed ranges can still leave position highly uncertain.
testResults = runtests(fullfile(studyFolder,"tests"));
study.tests = table(string({testResults.Name})',[testResults.Passed]', ...
    [testResults.Failed]',[testResults.Incomplete]',[testResults.Duration]', ...
    VariableNames=["Name","Passed","Failed","Incomplete","DurationS"]);
writetable(study.tests,fullfile(cfg.outputDir,"testResults.csv"));
assert(all([testResults.Passed]),"Resolve failing tests before running the study.");
study.screen = helperLLScreen(cfg);

%% 2. Geometry, signal support, then information from the available subset.
% All three layers share the same cells and height datum. Terrain-service
% failures trigger a visibly labeled, internally consistent fallback.
study.baseline = helperLLRunScenario(cfg);
study.nativeVerification = helperLLNativeVerification(study.baseline);
study.rfDiagnostics = helperLLRFDiagnostics(study.baseline);
assert(all(study.baseline.attribution.LostUsefulCells==0), ...
    "Adding WLEK unexpectedly removed useful cells; inspect conditioning.");

%% 3. Test the assumptions that could change the conclusion.
% Measurement-error/gate sensitivities reuse the physical RF arrays.
study.sensitivity = helperLLSensitivities(study.baseline);
catalogCfg = cfg;
catalogCfg.sites(1).latitude = cfg.newtonCatalogLatitude;
catalogCfg.sites(1).longitude = cfg.newtonCatalogLongitude;
study.catalogNewton = helperLLRunScenario(catalogCfg);
% Boundary-only gains on a coarse grid warrant bounded resolution checks.
for resolutionIndex = 1:numel(cfg.gridSensitivityDegrees)
    fineCfg = cfg;
    fineCfg.gridSpacingDegrees = cfg.gridSensitivityDegrees(resolutionIndex);
    fineCfg.altitudesFtAGL = cfg.sensitivityAltitudeFtAGL;
    fine = helperLLRunScenario(fineCfg);
    study.gridSensitivity(resolutionIndex).cfg = fine.cfg;
    study.gridSensitivity(resolutionIndex).mode = fine.mode;
    study.gridSensitivity(resolutionIndex).grid = fine.grid;
    study.gridSensitivity(resolutionIndex).terrain = fine.terrain;
    study.gridSensitivity(resolutionIndex).rf = fine.rf;
    study.gridSensitivity(resolutionIndex).summary = fine.summary;
    study.gridSensitivity(resolutionIndex).attribution = fine.attribution;
    for k = 1:numel(fine.analysis.configurations)
        c = fine.analysis.configurations(k);
        study.gridSensitivity(resolutionIndex).ideal2D(:,k) = c.ideal2D.useful;
        study.gridSensitivity(resolutionIndex).ideal3D(:,k) = c.ideal3D.useful;
        if ~c.geometryOnly
            study.gridSensitivity(resolutionIndex).available2D(:,k) = c.available2D.useful;
            study.gridSensitivity(resolutionIndex).available3D(:,k) = c.available3D.useful;
        end
    end
end
assert(all(study.sensitivity.attribution.LostUsefulCells==0), ...
    "A sensitivity lost previously useful cells.");

%% 4. Preserve reproducible evidence, not historical pipeline outputs.
study.createdUTC = string(datetime("now",TimeZone="UTC",Format="yyyy-MM-dd HH:mm:ss z"));
study.matlabVersion = version;
study.products = ver;
sourceFiles = dir(fullfile(studyFolder,"**","*.m"));
sourcePaths = string(fullfile({sourceFiles.folder},{sourceFiles.name}));
externalPaths = fullfile(cfg.repositoryRoot,[ ...
    "SystemPrechecks/helperBuildDeterministicCoverageData.m", ...
    "SystemPrechecks/LinkBudget/Radio_Tower_List.txt", ...
    "SystemPrechecks/Artifacts/Tables/SystemPrecheckAssumptions.csv", ...
    "BistaticDataAnalysis/adsbToBistatic.m", ...
    "BistaticDataAnalysis/helperDeriveTxRxGeometry.m"]);
study.sourceStamps = helperLLSourceStamp([sourcePaths externalPaths cfg.filterPath]);
study.figureFiles = helperLLPlots(study.baseline);
writetable(study.screen.table,fullfile(cfg.outputDir,"candidateScreen.csv"));
writetable(study.baseline.summary,fullfile(cfg.outputDir,"configurationSummary.csv"));
writetable(study.baseline.attribution,fullfile(cfg.outputDir,"tx3Attribution.csv"));
writetable(study.rfDiagnostics,fullfile(cfg.outputDir,"rfDiagnostics.csv"));
writetable(study.sensitivity.summary,fullfile(cfg.outputDir,"sensitivitySummary.csv"));
writetable(study.sensitivity.attribution,fullfile(cfg.outputDir,"sensitivityAttribution.csv"));
writetable(study.catalogNewton.summary,fullfile(cfg.outputDir,"catalogNewtonSummary.csv"));
writetable(study.catalogNewton.attribution,fullfile(cfg.outputDir,"catalogNewtonAttribution.csv"));
gridTables = cell(1,numel(study.gridSensitivity));
for resolutionIndex = 1:numel(study.gridSensitivity)
    t = study.gridSensitivity(resolutionIndex).attribution;
    t.GridSpacingDegrees = repmat(study.gridSensitivity(resolutionIndex).cfg.gridSpacingDegrees,height(t),1);
    gridTables{resolutionIndex} = t;
end
study.gridSensitivityTable = vertcat(gridTables{:});
writetable(study.gridSensitivityTable,fullfile(cfg.outputDir,"gridSensitivity.csv"));
save(fullfile(cfg.outputDir,"localizationLikelihoodResults.mat"),"study","-v7.3");
helperLLWriteReport(study);
fprintf("Study complete: %s\n",fullfile(cfg.docsDir,"report.md"));
fprintf("Result mode: %s. Tests passed: %d/%d.\n",study.baseline.mode, ...
    nnz(study.tests.Passed),height(study.tests));
clear restorePath
