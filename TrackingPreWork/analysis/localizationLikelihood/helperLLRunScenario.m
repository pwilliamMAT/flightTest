function result = helperLLRunScenario(cfg)
%HELPERLLRUNSCENARIO Complete one internally consistent terrain/RF scenario.
% A terrain failure restarts BOTH geometry and RF using an explicit fallback;
% no mixture of flat geometry and terrain-aware propagation is accepted.
result.cfg = cfg;
result.grid = helperLLGrid(cfg);
try
    result.terrain = helperLLTerrain(cfg,result.grid);
    for a = 1:numel(cfg.altitudesFtAGL)
        for k = 1:3
            result.rf{a,k} = helperLLRF(cfg,result.grid,result.terrain,k,a);
        end
    end
catch exception
    recoverable = ismember(string(exception.identifier), ...
        ["localizationLikelihood:TerrainUnavailable","localizationLikelihood:PropagationUnavailable"]);
    if recoverable && cfg.allowFallback && cfg.terrainMode=="terrain"
        warning("localizationLikelihood:Fallback", ...
            "Terrain-aware scenario failed: %s. Restarting as flat-free-space.",exception.message);
        fallback = cfg;
        fallback.terrainMode = "flat-free-space";
        fallback.allowFallback = false;
        result = helperLLRunScenario(fallback);
        result.fallbackReason = exception.message;
        result.requestedCfg = cfg;
        return
    end
    rethrow(exception)
end
result.mode = result.terrain.mode;
result.fallbackReason = "";
result.analysis = helperLLAnalyze(cfg,result.grid,result.terrain,result.rf);
[result.summary,result.attribution] = helperLLSummaries(cfg,result.grid,result.analysis);
end
