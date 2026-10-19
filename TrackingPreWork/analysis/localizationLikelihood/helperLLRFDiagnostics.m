function diagnostics = helperLLRFDiagnostics(result)
%HELPERLLRFDIAGNOSTICS Expose signed LR-minus-free-space differences.
% This inherited approach can predict enhancement (negative excess loss),
% especially near a site's ground coordinates. Retain it, but identify gains
% that disappear in a same-geometry free-space reference calculation.
rows = {};
cfg = result.cfg;
for a = 1:numel(cfg.altitudesFtAGL)
    for k = 1:3
        rf = result.rf{a,k};
        reference = helperLLRadarSNR(cfg,cfg.sites(k),rf.rangesM,rf.filterLossDB);
        for r = 1:numel(cfg.rois)
            w = result.grid.areaKm2(:,r);
            inside = w>0;
            loss = sum(rf.excessLossDB,2);
            supported = rf.snrDB>=cfg.snrGateDB;
            referenceSupported = reference.snrDB>=cfg.snrGateDB;
            rows{end+1} = struct("ROI",cfg.rois(r).name, ...
                "AltitudeFtAGL",cfg.altitudesFtAGL(a),"Transmitter",cfg.sites(k).name, ...
                "MinSNRDB",min(rf.snrDB(inside)),"MaxSNRDB",max(rf.snrDB(inside)), ...
                "MaxFreeSpaceSNRDB",max(reference.snrDB(inside)), ...
                "MinExcessLossDB",min(loss(inside)),"MaxExcessLossDB",max(loss(inside)), ...
                "SupportedAreaKm2",sum(w(supported)), ...
                "FreeSpaceSupportedAreaKm2",sum(w(referenceSupported)), ...
                "SupportedOnlyWithEnhancementKm2",sum(w(supported & ~referenceSupported))); %#ok<AGROW>
        end
    end
end
diagnostics = struct2table(vertcat(rows{:}));
end
