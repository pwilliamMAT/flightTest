function [study,elapsedSeconds] = helperLLWalkthroughStudy(cfg) %#ok<INUSD,STOUT>
%HELPERLLWALKTHROUGHSTUDY Recompute the full study without report exports.
% The companion Live Script uses the same numerical helpers and scenario
% scope as runLocalizationLikelihoodPOC. Only terrain/RF caches are written.
% Tests, native verification and bulk exports remain in the existing runner.
started = tic;
% Capture the existing helpers' cache-progress messages, not their errors.
% This fixed expression has no user-supplied code. Fallback remains visible
% in each result.mode and fallbackReason, displayed by the walkthrough.
executionLog = evalc("study = computeStudy(cfg);"); %#ok<NASGU>
elapsedSeconds = toc(started);
end

function study = computeStudy(cfg)
study.screen = helperLLScreen(cfg);
study.baseline = helperLLRunScenario(cfg);
study.rfDiagnostics = helperLLRFDiagnostics(study.baseline);
study.sensitivity = helperLLSensitivities(study.baseline);

% Retain the maintained Newton location and evaluate the catalog separately.
catalogCfg = cfg;
catalogCfg.sites(1).latitude = cfg.newtonCatalogLatitude;
catalogCfg.sites(1).longitude = cfg.newtonCatalogLongitude;
study.catalogNewton = helperLLRunScenario(catalogCfg);

% Fine grids use the configured sensitivity altitude, as in the full runner.
gridTables = cell(1,numel(cfg.gridSensitivityDegrees));
for index = 1:numel(cfg.gridSensitivityDegrees)
    fineCfg = cfg;
    fineCfg.gridSpacingDegrees = cfg.gridSensitivityDegrees(index);
    fineCfg.altitudesFtAGL = cfg.sensitivityAltitudeFtAGL;
    fine = helperLLRunScenario(fineCfg);
    study.gridSensitivity(index).cfg = fine.cfg;
    study.gridSensitivity(index).mode = fine.mode;
    study.gridSensitivity(index).grid = fine.grid;
    study.gridSensitivity(index).terrain = fine.terrain;
    study.gridSensitivity(index).rf = fine.rf;
    study.gridSensitivity(index).summary = fine.summary;
    study.gridSensitivity(index).attribution = fine.attribution;
    for configurationIndex = 1:numel(fine.analysis.configurations)
        configuration = fine.analysis.configurations(configurationIndex);
        study.gridSensitivity(index).ideal2D(:,configurationIndex) = configuration.ideal2D.useful;
        study.gridSensitivity(index).ideal3D(:,configurationIndex) = configuration.ideal3D.useful;
        if ~configuration.geometryOnly
            study.gridSensitivity(index).available2D(:,configurationIndex) = configuration.available2D.useful;
            study.gridSensitivity(index).available3D(:,configurationIndex) = configuration.available3D.useful;
        end
    end
    attribution = fine.attribution;
    attribution.GridSpacingDegrees = repmat(fineCfg.gridSpacingDegrees,height(attribution),1);
    gridTables{index} = attribution;
end
study.gridSensitivityTable = vertcat(gridTables{:});
end
