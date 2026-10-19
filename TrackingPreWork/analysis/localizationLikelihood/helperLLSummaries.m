function [summary,attribution] = helperLLSummaries(cfg,grid,analysis)
%HELPERLLSUMMARIES Area-weighted summaries, retaining invalid-point counts.
% Quantiles describe observable, accepted-condition cells only. Their count
% and area are printed alongside rank failures, rather than hiding failures.
rows = struct([]);
attr = struct([]);
for a = 1:numel(analysis)
    for r = 1:numel(cfg.rois)
        w = grid.areaKm2(:,r);
        mask = w>0;
        bounds = cfg.rois(r).bounds;
        centerInside = grid.latitude>=bounds(1) & grid.latitude<=bounds(2);
        centerInside = centerInside & grid.longitude>=bounds(3) & grid.longitude<=bounds(4);
        area = sum(w);
        for k = 1:numel(cfg.configurations)
            c = analysis(a).configurations(k);
            for dimension = [2 3]
                if dimension == 2
                    ideal = c.ideal2D;
                    actual = c.available2D;
                    mode = "Known Up";
                else
                    ideal = c.ideal3D;
                    actual = c.available3D;
                    mode = "Unconstrained 3D";
                end
                row = struct("ROI",cfg.rois(r).name,"AltitudeFtAGL",cfg.altitudesFtAGL(a), ...
                    "Configuration",c.name,"Mode",mode,"TerrainMode",cfg.terrainMode, ...
                    "SigmaM",cfg.rangeSigmaM,"GateDB",cfg.snrGateDB, ...
                    "ROIAreaKm2",area,"ROICells",nnz(mask),"GeometryOnly",c.geometryOnly);
                row.IdealObservableAreaKm2 = sum(w(ideal.rank==dimension));
                row.IdealUsefulAreaKm2 = sum(w(ideal.useful));
                good = ideal.rank==dimension;
                good = good & ideal.condition<=cfg.maxCondition;
                row.IdealValidCells = nnz(mask & good);
                row.IdealMedianRMSM = weightedQuantile(ideal.totalRMS,w.*good,0.5);
                row.IdealP95RMSM = weightedQuantile(ideal.totalRMS,w.*good,0.95);
                row.IdealMedianGeometryRMS = weightedQuantile(ideal.geometryRMS,w.*good,0.5);
                row.IdealP95GeometryRMS = weightedQuantile(ideal.geometryRMS,w.*good,0.95);
                row.AnyLinkAreaKm2 = NaN;
                row.Measurement0AreaKm2 = NaN;
                row.Measurement1AreaKm2 = NaN;
                row.Measurement2AreaKm2 = NaN;
                row.Measurement3AreaKm2 = NaN;
                row.UsefulAreaKm2 = NaN;
                row.UsefulPercent = NaN;
                row.UsefulCells = NaN;
                row.ObservableAreaKm2 = NaN;
                row.ValidCells = NaN;
                row.ValidAreaKm2 = NaN;
                row.RankDeficientCells = NaN;
                row.IllConditionedCells = NaN;
                row.AboveLimitCells = NaN;
                row.MedianHorizontalM = NaN;
                row.P95HorizontalM = NaN;
                row.MedianVerticalM = NaN;
                row.P95VerticalM = NaN;
                row.MedianTotalM = NaN;
                row.P95TotalM = NaN;
                row.MedianGeometryRMS = NaN;
                row.P95GeometryRMS = NaN;
                if ~c.geometryOnly
                    count = sum(c.available,2);
                    row.AnyLinkAreaKm2 = sum(w(count>0));
                    row.Measurement0AreaKm2 = sum(w(count==0));
                    row.Measurement1AreaKm2 = sum(w(count==1));
                    row.Measurement2AreaKm2 = sum(w(count==2));
                    row.Measurement3AreaKm2 = sum(w(count==3));
                    row.UsefulAreaKm2 = sum(w(actual.useful));
                    row.UsefulPercent = 100*row.UsefulAreaKm2/area;
                    row.UsefulCells = nnz(mask & actual.useful);
                    row.ObservableAreaKm2 = sum(w(actual.rank==dimension));
                    good = actual.rank==dimension;
                    good = good & actual.condition<=cfg.maxCondition;
                    row.ValidCells = nnz(mask & good);
                    row.ValidAreaKm2 = sum(w(good));
                    row.RankDeficientCells = nnz(mask & actual.rank<dimension);
                    row.IllConditionedCells = nnz(mask & actual.rank==dimension & actual.condition>cfg.maxCondition);
                    row.AboveLimitCells = nnz(mask & good & ~actual.useful);
                    row.MedianHorizontalM = weightedQuantile(actual.horizontalRMS,w.*good,0.5);
                    row.P95HorizontalM = weightedQuantile(actual.horizontalRMS,w.*good,0.95);
                    row.MedianVerticalM = weightedQuantile(actual.verticalRMS,w.*good,0.5);
                    row.P95VerticalM = weightedQuantile(actual.verticalRMS,w.*good,0.95);
                    row.MedianTotalM = weightedQuantile(actual.totalRMS,w.*good,0.5);
                    row.P95TotalM = weightedQuantile(actual.totalRMS,w.*good,0.95);
                    row.MedianGeometryRMS = weightedQuantile(actual.geometryRMS,w.*good,0.5);
                    row.P95GeometryRMS = weightedQuantile(actual.geometryRMS,w.*good,0.95);
                end
                if isempty(rows)
                    rows = row;
                else
                    rows(end+1) = row; %#ok<AGROW>
                end
            end
        end
        baseline = analysis(a).configurations(4);
        added = analysis(a).configurations(5);
        for dimension = [2 3]
            if dimension==2
                b = baseline.available2D; t = added.available2D;
                bi = baseline.ideal2D; ti = added.ideal2D;
                mode = "Known Up";
            else
                b = baseline.available3D; t = added.available3D;
                bi = baseline.ideal3D; ti = added.ideal3D;
                mode = "Unconstrained 3D";
            end
            new = t.useful & ~b.useful;
            both = all(baseline.available,2);
            ar = struct("ROI",cfg.rois(r).name,"AltitudeFtAGL",cfg.altitudesFtAGL(a), ...
                "Mode",mode,"SigmaM",cfg.rangeSigmaM,"GateDB",cfg.snrGateDB, ...
                "BaselineUsefulAreaKm2",sum(w(b.useful)),"WithWLEKUsefulAreaKm2",sum(w(t.useful)), ...
                "AddedUsefulCells",nnz(mask & new),"AddedUsefulAreaKm2",sum(w(new)), ...
                "AddedUsefulCenterInsideCells",nnz(mask & new & centerInside), ...
                "AddedUsefulOutsideCenterAreaKm2",sum(w(new & ~centerInside)), ...
                "LostUsefulCells",nnz(mask & b.useful & ~t.useful), ...
                "AddedWhereBothBaselineSupportedKm2",sum(w(new & both)), ...
                "AddedWhereBaselineMissingConstraintKm2",sum(w(new & ~both)), ...
                "IdealAddedUsefulAreaKm2",sum(w(ti.useful & ~bi.useful)), ...
                "NewAnyLinkAreaKm2",sum(w(any(added.available,2) & ~any(baseline.available,2))), ...
                "WLEKSupportedAreaKm2",sum(w(added.available(:,3))));
            if isempty(attr)
                attr = ar;
            else
                attr(end+1) = ar; %#ok<AGROW>
            end
        end
    end
end
summary = struct2table(rows);
attribution = struct2table(attr);
end

function q = weightedQuantile(x,w,fraction)
% MATLAB prctile does not supply geographic area weights in this workflow.
% Use the inverse weighted empirical CDF; no finite-only averaging.
valid = w>0;
valid = valid & isfinite(x);
if ~any(valid)
    q = NaN;
    return
end
[x,order] = sort(x(valid));
w = w(valid);
w = w(order);
q = x(find(cumsum(w)>=fraction*sum(w),1));
end
