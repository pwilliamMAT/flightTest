function helperLLWriteReport(study)
%HELPERLLWRITEREPORT Ten-section narrative generated from executed results.
cfg = study.baseline.cfg;
file = fullfile(cfg.docsDir,"report.md");
fid = fopen(file,"w","n","UTF-8");
assert(fid>=0,"Cannot write report.");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid,"# FlightTest localization-likelihood POC\n\nGenerated %s with %s. Mode: **%s**.\n\n", ...
    study.createdUTC,study.matlabVersion,study.baseline.mode);
fprintf(fid,"## 1. Objective and result\n\n");
fprintf(fid,"Measure the incremental value of WLEK-LD RF31 while separating ideal range geometry, modeled signal support, and useful localization. The recovered northern ROI is the headline comparison; the west corridor is independent supporting evidence.\n\n");
% Derive the conclusion from the computed headline cases, not an assumed win.
refined = study.gridSensitivityTable;
north = refined.ROI==cfg.rois(1).name;
northGain = max(refined.AddedUsefulAreaKm2(north));
fprintf(fid,"**Headline: %.4f km² maximum added useful area in the northern ROI across the executed refined-grid cases at %.0f ft AGL.** ",northGain,cfg.sensitivityAltitudeFtAGL);
if northGain==0
    fprintf(fid,"WLEK improves ideal geometry but does not demonstrate a robust northern localization-coverage benefit under these RF assumptions. ");
else
    fprintf(fid,"A modeled northern gain remains on the refined grids; its size and assumptions must be assessed below. ");
end
fprintf(fid,"The coarse-grid results, including partial boundary cells, remain visible in the tables. This is a local Gaussian information/uncertainty study, not a measured likelihood of detection or a global position-uniqueness proof.\n\n");
fprintf(fid,"## 2. Sources and configuration\n\n");
fprintf(fid,"See [repository survey](repositorySurvey.md) and [assumptions](assumptions.md). The original verbatim ten-section narrative was unavailable; this report reconstructs the technical coverage transparently. Maintained Newton/Hudson precheck inputs govern; historical live scripts and reports are preserved. All authored changes are under TrackingPreWork. SHA-256 source stamps, configuration, MATLAB products, arrays, masks, and metrics are saved in the MAT result.\n\n");
fprintf(fid,"Grid %.3f°; heights %s ft AGL; range sigma %.0f m; gate %.1f dB; useful limits %.0f m known-Up horizontal RMS and %.0f m 3D total RMS; condition of whitened H <= %.0f.\n\n", ...
    cfg.gridSpacingDegrees,strjoin(string(cfg.altitudesFtAGL),", "),cfg.rangeSigmaM, ...
    cfg.snrGateDB,cfg.horizontalLimitM,cfg.totalLimitM,cfg.maxCondition);
fprintf(fid,"Candidate screen: %d catalog records, %d distinct coordinate pairs, %d within %.0f km. Complex S21 is linearly interpolated; full-channel maxima include interior segment minima of |S21|.\n\n", ...
    study.screen.catalogRows,study.screen.uniqueLocations,study.screen.withinRadius,cfg.screen.radiusKm);
writeTable(fid,study.screen.table(study.screen.table.DistanceKm<=cfg.screen.radiusKm, ...
    ["Location","RFChannel","DistanceKm","MinimumSeparationDeg","FullChannelMaxLossDB","Eligible","Selected"]));
fprintf(fid,"## 3. Measurement and height conventions\n\n");
fprintf(fid,"rho_i = ||p-Tx_i|| + ||p-Rx|| - ||Tx_i-Rx||, in meters, without a factor of one half. H_i is the sum of the two target-directed unit vectors. Terrain MSL plus antenna/aircraft AGL plus EGM96 geoid separation gives WGS84 ellipsoidal height before receiver-centered ENU conversion. Supplied NAD83 horizontal coordinates are treated as WGS84-compatible, an explicit approximation.\n\n");
fprintf(fid,"Whiten H using chol(R,'lower'), then use SVD for rank, singular values, conditioning, and covariance. No information-matrix inverse or deficient pseudoinverse confidence is used. Known Up retains 3D slant distances and fixes only the receiver-frame Up coordinate locally. GeometryRMS is sqrt(sum(1/svd(H)^2)) with unit range variance. Full rank is local: separate ellipsoidal intersections can remain.\n\n");
fprintf(fid,"Native examples read and adapted: [Tracking Using Bistatic Range Detections](https://www.mathworks.com/help/fusion/ug/track-using-bistatic-range-detections.html) supplies the excess-range/ellipsoid convention; [Object Tracking Using TDOA](https://www.mathworks.com/help/fusion/ug/object-tracking-using-time-difference-of-arrival.html) motivates constant-measurement contours (ellipsoids here, rather than TDOA hyperboloids); [CRLB for Bistatic Position Estimation](https://www.mathworks.com/help/phased/ug/crlb-for-bistatic-position-estimation.html) supplies sqrt(trace(C)) presentation and fixed color limits. Its angle measurement is deliberately removed. Verification uses crlb, tsoaposest and radareqsnr; no Doppler, detections, fuser, or tracker is added. Public example pages were read on 2026-10-13; installed R2026a syntax and execution provide version verification.\n\n");
fprintf(fid,"## 4. Ideal geometry and uncertainty\n\n");
fprintf(fid,"A single transmitter is deficient in both modes. Newton+Hudson is always deficient for unconstrained 3D. Three independent usable ranges can produce full local 3D rank, while two can support known-Up horizontal localization. The following %.0f ft results include all configurations, including the geometry-only Cochesett reference. Medians and P95 are area-weighted over full-rank, accepted-condition cells; counts disclose their limited domain.\n\n",cfg.sensitivityAltitudeFtAGL);
s = study.baseline.summary;
atHeight = s.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL;
writeTable(fid,s(atHeight,["ROI","Configuration","Mode","ROICells","IdealValidCells", ...
    "IdealUsefulAreaKm2","IdealMedianRMSM","IdealP95RMSM", ...
    "IdealMedianGeometryRMS","IdealP95GeometryRMS"]));
fprintf(fid,"## 5. Modeled signal support\n\n");
fprintf(fid,"ERP-to-EIRP correction %.3g dB; explicit gains [0,%.3g] dB; Ts=%.4g K; RCS=%.3g m²; bandwidth=%.3g MHz; equivalent interval=%.3g microseconds. Both propagation legs use the respective transmitter frequency. The interval is counted once. ApplyBandpassLoss=%s; the default uses the component response for screening without subtracting it again from the effective system-NF model.\n\n", ...
    cfg.rf.erpToEirpDB,cfg.rf.receiveGainDBi,cfg.rf.referenceTemperatureK*10^(cfg.rf.noiseFigureDB/10), ...
    cfg.rf.rcsM2,cfg.rf.bandwidthHz/1e6,cfg.rf.equivalentIntervalS*1e6,string(cfg.rf.applyBandpassLoss));
fprintf(fid,"The inherited signed Longley–Rice-minus-free-space difference is preserved. Negative values predict enhancement, and are not silently clipped. The same-geometry zero-excess-loss reference below exposes support that depends on that enhancement. This is a model sensitivity, not a second measured RF dataset.\n\n");
d = study.rfDiagnostics;
writeTable(fid,d(d.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL, ...
    ["ROI","Transmitter","MaxSNRDB","MaxFreeSpaceSNRDB","SupportedAreaKm2", ...
    "SupportedOnlyWithEnhancementKm2"]));
fprintf(fid,"## 6. Combined opportunity and Tx3 attribution\n\n");
fprintf(fid,"Each point uses only ranges with SNR >= gate, then recomputes information. Any-link coverage and number of supported ranges are saved separately. Useful coverage requires full rank, accepted condition, and the selected RMS limit. Areas use WGS84 cell/ROI intersections; the field is sampled at cell centers. Three altitude slices are not a volume.\n\n");
writeTable(fid,study.baseline.attribution(:,["ROI","AltitudeFtAGL","Mode", ...
    "BaselineUsefulAreaKm2","WithWLEKUsefulAreaKm2","AddedUsefulCells", ...
    "AddedUsefulAreaKm2","IdealAddedUsefulAreaKm2"]));
fprintf(fid,"Attribution at the baseline altitude distinguishes already-supported baseline links from a missing usable constraint. These logical categories do not exclude overlapping physical causes such as geometry and RF support. LostUsefulCells is zero in the executed baseline and error/gate sensitivities.\n\n");
a = study.baseline.attribution;
writeTable(fid,a(a.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL, ...
    ["ROI","Mode","AddedWhereBothBaselineSupportedKm2", ...
    "AddedWhereBaselineMissingConstraintKm2","NewAnyLinkAreaKm2", ...
    "AddedUsefulCenterInsideCells","AddedUsefulOutsideCenterAreaKm2"]));
fprintf(fid,"Actual uncertainty statistics at %.0f ft (NaN means no valid sample; it is not zero uncertainty):\n\n",cfg.sensitivityAltitudeFtAGL);
selected = atHeight & ismember(s.Configuration,cfg.configurationNames(4:5));
writeTable(fid,s(selected,["ROI","Configuration","Mode","ROICells","ValidCells", ...
    "RankDeficientCells","IllConditionedCells","MedianHorizontalM","P95HorizontalM", ...
    "MedianVerticalM","P95VerticalM","MedianTotalM","P95TotalM"]));
fprintf(fid,"## 7. Sensitivities and recommendation stability\n\n");
fprintf(fid,"Range sigma %s m and SNR gates %s dB were crossed on the same physical arrays. Full results are in sensitivitySummary.csv and sensitivityAttribution.csv. The following %.0f ft table retains every error/gate case.\n\n", ...
    strjoin(string(cfg.rangeSigmaSensitivityM),", "),strjoin(string(cfg.snrGateSensitivityDB),", "),cfg.sensitivityAltitudeFtAGL);
a = study.sensitivity.attribution;
writeTable(fid,a(a.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL, ...
    ["ROI","Mode","SigmaM","GateDB","AddedUsefulAreaKm2","AddedUsefulCenterInsideCells"]));
fprintf(fid,"Refining the grid checks whether a small coarse-grid gain is caused by boundary sampling. Maximum refined northern added area is %.5g km². West-corridor areas vary with refinement and are not claimed converged.\n\n",northGain);
writeTable(fid,study.gridSensitivityTable(:,["ROI","Mode","GridSpacingDegrees", ...
    "BaselineUsefulAreaKm2","AddedUsefulAreaKm2","AddedUsefulCenterInsideCells"]));
fprintf(fid,"Newton catalog sensitivity uses %.6f°, %.6f° while retaining its RF parameters and height. Compare with section 6; this changes baseline horizontal coverage but does not rescue broad WLEK signal support.\n\n",cfg.newtonCatalogLatitude,cfg.newtonCatalogLongitude);
a = study.catalogNewton.attribution;
writeTable(fid,a(a.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL, ...
    ["ROI","Mode","BaselineUsefulAreaKm2","AddedUsefulAreaKm2","IdealAddedUsefulAreaKm2"]));
fprintf(fid,"## 8. Verification and reproducibility\n\n");
fprintf(fid,"**%d/%d tests passed; %d failed; %d incomplete.** Native crlb covariance relative error at a well-conditioned study point: %.3g; information-matrix error: %.3g. Native tsoaposest noiseless synthetic position error: %.3g m.\n\n", ...
    nnz(study.tests.Passed),height(study.tests),nnz(study.tests.Failed),nnz(study.tests.Incomplete), ...
    study.nativeVerification.crlbRelativeError,study.nativeVerification.informationRelativeError, ...
    study.nativeVerification.tsoaPositionErrorM);
fprintf(fid,"The original ten sanity-check labels were unavailable. Executed coverage maps to ten engineering categories: (1) excess range/baseline, (2) analytic Jacobian/finite differences, (3) rank and degeneracy, (4) fixed-Up 3D slants, (5) covariance scaling/independent information, (6) availability and weak-Tx3 preservation, (7) native crlb/tsoaposest units, (8) explicit RF hand reference and parameter effects, (9) height datum/geographic area, (10) cache invalidation, fresh equality, explicit fallback labels, and summary/attribution partitions. See testResults.csv for individual checks.\n\n");
fprintf(fid,"Fresh-versus-cached native checks: maximum terrain-position difference %.3g m and WLEK SNR difference %.3g dB.\n\n", ...
    study.nativeVerification.freshTerrainMaximumDifferenceM,study.nativeVerification.freshRFMaximumDifferenceDB);
fprintf(fid,"Cache keys contain relevant configuration, source digests, release, coordinates/heights and propagation mode. Changing unrelated measurement sigma/gate reuses RF; changing a relevant physical input invalidates it. Native elevation/propagation service failures restart the scenario as flat-free-space; programming/configuration failures are rethrown. Explicit fallback execution is tested; no network outage was induced.\n\n");
fprintf(fid,"Rerun from the repository root:\n\n```matlab\nrun(""TrackingPreWork/analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m"")\n```\n\n");
fprintf(fid,"## 9. Limitations\n\n");
fprintf(fid,"This study assumes unbiased independent %.3g m range errors, constant RCS/gains and effective NF, synchronized valid ranges, and no false association or clutter. SNR is an equivalent-observation model and is not a calibrated range-error law. At the baseline altitude the maximum coarse-grid WLEK SNR margin over the gate is %.3g dB. Consult section 5 for support that requires negative signed excess loss; that behavior needs physical validation. Coarse boundary-cell sampling can assign a cell-center result to a small ROI intersection even when its center is outside. Refined west results are not claimed converged.\n\n", ...
    cfg.rangeSigmaM,max(d.MaxSNRDB(d.Transmitter=="WLEK-LD" & d.AltitudeFtAGL==cfg.sensitivityAltitudeFtAGL))-cfg.snrGateDB);
fprintf(fid,"The catalog/Newton conflict, NAD83/WGS84 approximation, antenna patterns, optional high-pass response, terrain dataset revisions, and global multi-solution ambiguity remain. Known Up is an exact local condition; operational altitude errors would weaken it. No detection, tracking, or field-acquisition capability was demonstrated.\n\n");
fprintf(fid,"**Hardware-acquisition caveat:** Realizing modeled benefit requires simultaneous coherent acquisition and suitable references for separate RF channels, with synchronized/calibrated measurements. Installed receive-chain response, optional high-pass filter, available channel count/bandwidth, reference quality, and timing integrity are unresolved. This POC does not qualify hardware or approve acquisition changes; conclusions remain conditional on modeled RF support and measurement quality.\n\n");
fprintf(fid,"## 10. Deliverables and next decision\n\n");
fprintf(fid,"The screen selects WLEK among the frozen UHF candidates. ");
if northGain==0
    fprintf(fid,"Its ideal geometric value does not translate into a demonstrated material northern localization-coverage gain. The catalog Newton alternative does not change the lack of broad WLEK signal support in this execution. ");
else
    fprintf(fid,"A modeled refined-grid northern benefit remains; use the sensitivity tables to assess whether it is material and stable. ");
end
fprintf(fid,"Retain Cochesett as geometry-only because of the filter result. The most useful next engineering step is to validate the per-channel echo SNR/reference quality and signed excess-loss behavior before expanding localization implementation.\n\n");
fprintf(fid,"Authored code: one runner, one configuration function, focused helpers for screen/grid/datum/range information/RF/cache/attribution/plots/report/native checks, and one class-based test suite. Documentation: survey, assumptions, this generated report, scoped concepts index, skill-use summary, and concise PROJECT_STATE. Generated products: PNG figures, configuration/attribution/RF/sensitivity/grid/candidate/test CSVs, and localizationLikelihoodResults.mat. Existing reports and link budgets were preserved.\n\n");
fprintf(fid,"Created source files (paths relative to TrackingPreWork):\n\n");
for k = 1:numel(study.sourceStamps)
    source = replace(string(study.sourceStamps(k).path),char(92),"/");
    root = replace(string(cfg.studyRoot),char(92),"/")+"/";
    if startsWith(source,root)
        relative = extractAfter(source,strlength(root));
        fprintf(fid,"- [%s](../../%s)\n",relative,relative);
    end
end
fprintf(fid,"\nAdditional created files: `README.md`, `PROJECT_STATE.md`, `concepts.md`, `sftt_skillUseSummary.md`, `analysis/localizationLikelihood/.gitignore`, and `docs/localizationLikelihood/{repositorySurvey,assumptions,report}.md`. No pre-existing tracked source file was modified.\n\n");
fprintf(fid,"Figure index (all generated under analysis/localizationLikelihood/results):\n\n");
for k = 1:numel(study.figureFiles)
    [~,name,ext] = fileparts(study.figureFiles(k));
    fprintf(fid,"- [%s](../../analysis/localizationLikelihood/results/%s%s)\n",name,name,ext);
end
fprintf(fid,"\n[CSV/MAT result folder](../../analysis/localizationLikelihood/results/) contains the detailed evidence. Generated MAT/cache products are reproducible and should be reviewed for size before a manual Git checkpoint. No Git writes were performed.\n");
end

function writeTable(fid,t)
names = string(t.Properties.VariableNames);
fprintf(fid,"| %s |\n",strjoin(names," | "));
fprintf(fid,"| %s |\n",strjoin(repmat("---",size(names))," | "));
for row = 1:height(t)
    values = strings(1,width(t));
    for column = 1:width(t)
        value = t{row,column};
        if islogical(value)
            values(column) = string(value);
        elseif isnumeric(value)
            values(column) = compose("%.5g",value);
        else
            values(column) = replace(string(value),"|","/");
        end
    end
    fprintf(fid,"| %s |\n",strjoin(values," | "));
end
fprintf(fid,"\n");
end
