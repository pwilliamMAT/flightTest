%[text] # What does another transmitter contribute?
%[text] **A 25-minute engineering walkthrough of the localization POC.** A third transmitter can improve position geometry, yet its echo must support a measurement before that improvement is usable. We compare Newton + Hudson with Newton + Hudson + WLEK-LD RF31, using the recovered northern region at 6,000 ft AGL as the main thread.
%[text] The result is a local uncertainty study under stated measurement assumptions. It does not demonstrate detected aircraft, a unique global position, a working tracker, or qualified acquisition hardware. The [executed report](../../docs/localizationLikelihood/report.md), [source survey](../../docs/localizationLikelihood/repositorySurvey.md), and [assumptions](../../docs/localizationLikelihood/assumptions.md) preserve the full supporting context.
%%
%[text] ## 1. Separate the three engineering questions (2 minutes)
%[text:table]
%[text] | Question | Calculation | What it establishes |
%[text] | --- | --- | --- |
%[text] | Could the ranges constrain position? | Ideal range Jacobian and covariance | Local geometric potential |
%[text] | Which echoes support a range measurement? | Per-channel modeled SNR and gate | Conditional measurement availability |
%[text] | Does the available subset localize usefully? | Recompute information with supported ranges | Rank, conditioning, and RMS limits together |
%[text:table]
%[text] Open this file in the MATLAB R2026a Live Editor and use **Run All**, or run the sections in order. Setup accepts the flightTest repository root, TrackingPreWork, or this analysis folder as the current folder. The helpers retain the study's native geographic, propagation, and radar functions; the visible matrix calculation explains the existing local-information model.
walkthroughFolder = helperWalkthroughSetup();
cfg = localizationLikelihoodConfig();
% Edit these inputs before the next section; this example is optional:
% cfg.rangeSigmaM = 100;
% cfg.snrGateDB = 10;
% cfg.terrainMode = "flat-free-space";
mainAltitudeFtAGL = 6000;
mainROI = 1; % Recovered north; use 2 to inspect the west corridor.
%%
%[text] ## 2. Establish the physical scenario (2 minutes)
%[text] Recompute the complete existing scope: both regions of interest (ROIs), all altitude slices, range-error and SNR-gate sensitivities, catalog Newton, and finer grids. Terrain/RF caches avoid repeating propagation calculations when their inputs match. This section writes only relevant caches; report export and verification are optional at the end.
[walkthroughStudy,computationSeconds] = helperLLWalkthroughStudy(cfg);
result = walkthroughStudy.baseline;
% Use the effective configuration if a terrain-service failure caused fallback.
cfg = result.cfg;
view = helperLLWalkthroughView(walkthroughStudy,mainAltitudeFtAGL,mainROI);
altitudeIndex = view.altitudeIndex;
pointIndex = view.pointIndex;
disp(view.modes)
%[text] **Read the physical-mode table first.** Terrain-service failure restarts the affected scenario consistently as flat terrain/free space. Such cases are labeled on the figures. Computation time is measured separately from the guided discussion.
disp(compose("Full cached study computation: %.1f seconds.",computationSeconds))
helperLLPlots(result,Plots=1,Display="inline");
%[text] The two rectangles are retained study regions; the dashed Logan approach is illustrative, not an observed flight trajectory. Cochesett lies south of the receiver and supplies a useful contrasting direction, but its RF10 service is rejected by the component-filter screen.
%%
%[text] ## 2a. Why WLEK, and why retain Cochesett?
%[text] The preliminary screen looks within the configured radius, rejects redundant baseline sites and excessive loss anywhere across the channel, then favors angular separation from the baseline bearings. This is a candidate screen; it does not optimize localization accuracy or establish echo reception. The frozen service mapping and unresolved installed-chain response are documented in the survey.
disp(compose("Screen: radius %.0f km; full-channel component loss < %.1f dB.", ...
    cfg.screen.radiusKm,cfg.screen.maximumChannelLossDB))
disp(view.screen)
%[text] WLEK is the selected added site for this POC. Cochesett remains a **geometry-only** comparison: assuming its range is available illustrates a direction change, without implying an RF-supported result.
%%
%[text] ## 3. Make coordinates and height datums explicit (2 minutes)
%[text] Geometry must use compatible coordinates. Above ground level (AGL) is measured from local terrain; mean sea level (MSL) is an orthometric height; the geographic-to-ENU conversion needs ellipsoidal height. East, North, and Up (ENU) are measured in the receiver's local frame.
%[text] $h_{\\mathrm{ellipsoid}}=h_{\\mathrm{terrain,MSL}}+h_{\\mathrm{AGL}}+N_{\\mathrm{geoid}}$
disp(view.sites)
%[text] The helper uses `elevation` and the configured geoid model before `geodetic2enu`. An altitude slice is constant **AGL**, so its local Up coordinate can vary across the terrain and curved Earth. The known-Up calculation conditions on each target's exact local Up; it is not a flat-Earth range calculation.
disp(view.newton)
%[text] The maintained Newton coordinate and catalog coordinate disagree. We retain the maintained location as the baseline, evaluate the catalog location separately, and do not silently choose a new truth. The survey also records the NAD83/WGS84 approximation; these inputs are not surveyed field calibration.
%%
%[text] ## 3a. State measurement and RF assumptions before interpreting a map
%[text] Range error is a one-standard-deviation uncertainty for each independent scalar excess range. The SNR gate controls whether a range is available; there is no calibrated SNR-to-range-error relationship here. A useful result requires full local rank, an acceptable condition number, and the appropriate RMS limit.
disp(view.measurements)
disp(view.transmitters)
%[text] Effective noise figure describes the modeled system reference plane. The component filter is used for screening; applying its loss again to the RF calculation is off by default to avoid double counting. Receive gain, bistatic radar cross section (RCS), and the equivalent observation interval are assumptions, not measured aircraft or installed-chain values.
disp(view.rfAssumptions)
%%
%[text] ## 4. Understand one bistatic excess range (2 minutes)
%[text] An echo travels from transmitter to target to receiver. Subtracting the direct transmitter-to-receiver distance gives **excess range**. One measured value confines a target to an ellipsoid; it does not identify a point. Here `p`, `t`, and `r` are three-dimensional ENU positions in metres.
%[text] $\\rho_i(\\mathbf p)=\\|\\mathbf p-\\mathbf t_i\\|+\\|\\mathbf p-\\mathbf r\\|-\\|\\mathbf t_i-\\mathbf r\\|$
targetENU_m = result.terrain.targetENU(pointIndex,:,altitudeIndex);
receiverENU_m = result.terrain.receiverENU;
transmitterENU_m = result.terrain.transmitterENU(1:3,:);
% Full 3D slant distances are retained, including target and site heights.
txRange_m = vecnorm(targetENU_m-transmitterENU_m,2,2);
rxRange_m = norm(targetENU_m-receiverENU_m);
baselineRange_m = vecnorm(transmitterENU_m-receiverENU_m,2,2);
excessRange_m = txRange_m + rxRange_m - baselineRange_m;
disp(table(string({cfg.sites(1:3).name})',txRange_m, ...
    repmat(rxRange_m,3,1),baselineRange_m,excessRange_m, ...
    VariableNames=["Transmitter","TxTarget_m","TargetRx_m","Direct_m","Excess_m"]))
%[text] This representative location is the nearest study-grid point to the selected ROI's configured contour point. It illustrates geometry, not an observed target. The direct-path subtraction changes the measured range value but contributes no target-position derivative.
disp(table(result.grid.latitude(pointIndex),result.grid.longitude(pointIndex), ...
    mainAltitudeFtAGL,targetENU_m(3), ...
    VariableNames=["Latitude_deg","Longitude_deg","Altitude_ftAGL","LocalUp_m"]))
%%
%[text] ## 4a. See why intersecting range directions matter
%[text] Each solid curve is a nominal excess range in a plane of known Up. Dashed curves mark plus/minus one range standard deviation. If curves nearly touch in direction, small range errors can move their intersection a long way. The enlarged view makes metre-scale uncertainty visible beside kilometre-scale geometry.
helperLLPlots(result,Plots=2,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
%[text] The ellipse is the local joint horizontal covariance contour at Mahalanobis radius one. Under a Gaussian two-dimensional approximation it contains about 39% probability; it is not a 68% or 95% joint confidence region. The local ellipse does not prove there is only one global range intersection.
%%
%[text] ## 5. Turn range sensitivity into position uncertainty (3 minutes)
%[text] A Jacobian row tells us how a small East, North, or Up displacement changes one range. Adding the unit vectors from transmitter and receiver to target gives that row. Stacking the three rows exposes which spatial directions the measurements constrain.
%[text] $\\mathbf H_i=\\frac{(\\mathbf p-\\mathbf t_i)^T}{\\|\\mathbf p-\\mathbf t_i\\|}+\\frac{(\\mathbf p-\\mathbf r)^T}{\\|\\mathbf p-\\mathbf r\\|}$
rangeJacobian = (targetENU_m-transmitterENU_m)./txRange_m ...
    + (targetENU_m-receiverENU_m)/rxRange_m;
disp(array2table(rangeJacobian,VariableNames=["East","North","Up"], ...
    RowNames=cellstr(string({cfg.sites(1:3).name}))))
%[text] `R` is measurement covariance in square metres. Cholesky whitening expresses each range direction relative to its error. Singular value decomposition (SVD) then separates independent position directions: a missing singular direction means the full position is unobservable.
%[text] $\\mathbf R=\\mathbf L\\mathbf L^T,\\quad\\mathbf A=\\mathbf L^{-1}\\mathbf H=\\mathbf U\\mathbf S\\mathbf V^T$
rangeCovariance_m2 = cfg.rangeSigmaM^2*eye(3);
noiseFactor = chol(rangeCovariance_m2,"lower");
whitenedJacobian = noiseFactor\rangeJacobian;
[~,singularMatrix,positionDirections] = svd(whitenedJacobian,"econ");
singularValues = diag(singularMatrix);
rankTolerance = max(size(rangeJacobian))*eps(max(singularValues));
positionRank = nnz(singularValues>rankTolerance);
disp(table((1:3)',singularValues,VariableNames=["Direction","SingularValue_perM"]))
%[text] For full rank only, covariance is `V diag(1/s^2) V'`. Small singular values produce large uncertainty. We use matrix factors rather than explicitly inverting the information matrix, and we do not interpret a pseudoinverse as certainty in missing directions.
positionCovariance_m2 = inf(3);
conditionNumber = Inf;
if positionRank==3
    covarianceFactor = positionDirections./singularValues';
    positionCovariance_m2 = covarianceFactor*covarianceFactor';
    conditionNumber = singularValues(1)/singularValues(end);
end
positionRMS_m = sqrt(trace(positionCovariance_m2));
disp(table(positionRank,conditionNumber,positionRMS_m, ...
    VariableNames=["Rank","Condition","PositionRMS_m"]))
%%
%[text] ## 5a. Compare unconstrained 3D with known Up
%[text] Two scalar ranges can supply at most two independent directions, so Newton + Hudson alone cannot resolve unconstrained 3D position here. With **exactly known local Up**, only East and North are unknown: select the first two Jacobian columns, while retaining the same three-dimensional target-to-site ranges.
% Two-transmitter 3D: two nonzero singular values still leave a third unknown.
baselineSingularValues = svd(noiseFactor(1:2,1:2)\rangeJacobian(1:2,:),"econ");
baselineRank = nnz(baselineSingularValues> ...
    max(size(rangeJacobian(1:2,:)))*eps(max(baselineSingularValues)));
% Known-Up covariance uses all three ranges and the horizontal columns.
horizontalWhitened = noiseFactor\rangeJacobian(:,1:2);
[~,horizontalS,horizontalV] = svd(horizontalWhitened,"econ");
horizontalValues = diag(horizontalS);
horizontalRank = nnz(horizontalValues> ...
    max(size(horizontalWhitened))*eps(max(horizontalValues)));
horizontalCovariance_m2 = inf(2);
if horizontalRank==2
    horizontalFactor = horizontalV./horizontalValues';
    horizontalCovariance_m2 = horizontalFactor*horizontalFactor';
end
disp(table(["Newton+Hudson 3D";"With WLEK 3D";"With WLEK known Up"], ...
    [baselineRank;positionRank;horizontalRank], ...
    [Inf;positionRMS_m;sqrt(trace(horizontalCovariance_m2))], ...
    VariableNames=["Case","Rank","PositionRMS_m"]))
%[text] **RMS uncertainty** is the square root of the covariance trace, not a guaranteed error radius. The dimensionless geometry metric repeats the calculation with unit range variance. For independent equal errors, position RMS equals range sigma times geometry RMS. Operational altitude uncertainty would require a different model than exact known Up.
% Check the educational calculation against the production implementation.
pointGeometry = helperLLGeometry(targetENU_m,transmitterENU_m,receiverENU_m, ...
    rangeCovariance_m2,1:3,true(1,3),cfg.maxCondition,cfg.totalLimitM);
pointKnownUp = helperLLGeometry(targetENU_m,transmitterENU_m,receiverENU_m, ...
    rangeCovariance_m2,1:2,true(1,3),cfg.maxCondition,cfg.horizontalLimitM);
assert(max(abs(excessRange_m-pointGeometry.rho'))<1e-8);
assert(norm(rangeJacobian-reshape(pointGeometry.H,3,3),"fro")<1e-12);
helperCheckCovariance(positionCovariance_m2,pointGeometry.covariance);
helperCheckCovariance(horizontalCovariance_m2,pointKnownUp.covariance);
pointBaseline = helperLLGeometry(targetENU_m,transmitterENU_m(1:2,:),receiverENU_m, ...
    rangeCovariance_m2(1:2,1:2),1:3,true(1,2),cfg.maxCondition,cfg.totalLimitM);
assert(baselineRank==pointBaseline.rank);
assert(isinf(pointBaseline.totalRMS));
%%
%[text] ## 6. Compare ideal geometry on matched maps (2 minutes)
%[text] Assume every selected range is available to see geometric potential first. Gray marks deficient rank. Both panels use the same cells and color limits; colors saturate at the configured plot limit. Full rank alone is insufficient: the uncertainty and conditioning thresholds still apply.
helperLLPlots(result,Plots=4,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
%[text] Two transmitters leave a missing 3D direction. Adding WLEK can make that direction locally observable, but its uncertainty can remain large. The table also includes the known-Up case; valid-cell counts include full rank and accepted conditioning, while useful area additionally enforces the RMS limit.
disp(view.ideal)
%%
%[text] ## 6a. See the effect of exact altitude information
%[text] With Up fixed, two scalar ranges can resolve the two horizontal unknowns where their directions are independent. The matched maps show horizontal RMS for this conditional case; compare them with the larger 3D uncertainty above before deciding whether an operational altitude measurement is sufficiently precise.
helperLLPlots(result,Plots=3,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
%[text] Adding WLEK can improve the horizontal covariance even when both baseline ranges already provide rank two. The color limits are shared within this comparison; known-Up and 3D figures use their separately labeled configured ranges.
%%
%[text] ## 6b. Separate finite improvement from newly observable geometry
%[text] A finite RMS reduction is meaningful where both cases are observable. Subtracting infinite uncertainties is not meaningful. The right panel therefore uses categories for the 3D rank transition; the left shows the finite known-Up RMS reduction.
helperLLPlots(result,Plots=5,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
%[text] These are ideal geometry maps. The next step determines whether each required echo can support its assumed range measurement.
%%
%[text] ## 7. Determine which signals support measurements (3 minutes)
%[text] The bistatic radar equation connects transmitted power, two slant ranges, wavelength, RCS, receiver gain, noise, and loss. ERP references a dipole; add the configured ERP-to-EIRP correction to reference isotropic radiation. Passing EIRP as power with zero transmit gain avoids counting transmit gain twice.
%[text] $P_{\\mathrm{EIRP}}=P_{\\mathrm{ERP}}10^{c_{\\mathrm{ERP}}/10},\\quad T_s=T_0 10^{NF/10}$
%[text] Total noise temperature includes antenna noise at `T0` plus receiver equivalent noise `(F-1)T0`. For this model the matched-observation SNR is received power times the equivalent interval divided by `k Ts`. It differs from input power SNR by the time-bandwidth product.
transmitterIndex = 3; % WLEK; change to 1 or 2 for another channel.
site = cfg.sites(transmitterIndex);
pointRF = result.rf{altitudeIndex,transmitterIndex};
wavelength_m = physconst("LightSpeed")/site.frequencyHz;
eirp_W = site.erpW*10^(cfg.rf.erpToEirpDB/10);
noiseTemperature_K = cfg.rf.referenceTemperatureK*10^(cfg.rf.noiseFigureDB/10);
twoLegRanges_m = pointRF.rangesM(pointIndex,:);
signedExcessLoss_dB = sum(pointRF.excessLossDB(pointIndex,:));
totalLoss_dB = signedExcessLoss_dB + pointRF.filterLossDB + cfg.rf.additionalLossDB;
modeledSNR_dB = radareqsnr(wavelength_m,twoLegRanges_m,eirp_W, ...
    cfg.rf.equivalentIntervalS,Gain=[0 cfg.rf.receiveGainDBi], ...
    Ts=noiseTemperature_K,RCS=cfg.rf.rcsM2,Loss=totalLoss_dB);
disp(table(eirp_W,noiseTemperature_K,signedExcessLoss_dB,modeledSNR_dB, ...
    VariableNames=["EIRP_W","NoiseTemperature_K","SignedExcessLoss_dB","SNR_dB"]))
%[text] The equivalent interval is counted once. Bandwidth sets input noise power; it is not an additional matched-observation gain. The following power calculation makes that convention explicit.
receivedPower_W = eirp_W*10^(cfg.rf.receiveGainDBi/10)*wavelength_m^2*cfg.rf.rcsM2 ...
    /((4*pi)^3*prod(twoLegRanges_m.^2))*10^(-totalLoss_dB/10);
inputNoise_W = physconst("Boltzmann")*noiseTemperature_K*cfg.rf.bandwidthHz;
inputSNR_dB = 10*log10(receivedPower_W/inputNoise_W);
timeBandwidthGain_dB = 10*log10(cfg.rf.bandwidthHz*cfg.rf.equivalentIntervalS);
disp(table(inputSNR_dB,timeBandwidthGain_dB,inputSNR_dB+timeBandwidthGain_dB, ...
    VariableNames=["InputSNR_dB","TimeBandwidthGain_dB","ObservationSNR_dB"]))
assert(abs(modeledSNR_dB-pointRF.snrDB(pointIndex))<1e-10);
assert(abs(modeledSNR_dB-inputSNR_dB-timeBandwidthGain_dB)<1e-10);
%%
%[text] ## 7a. Read the transmitter SNR and propagation reference together
%[text] The terrain model computes Longley-Rice loss minus free-space loss on each path leg at that transmitter's frequency. The reverse leg uses reciprocity. This **signed difference** can be negative, increasing modeled SNR relative to free space; we retain that behavior and expose its impact.
helperLLPlots(result,Plots=6,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
%[text] The reference table sets the two signed excess losses to zero while keeping the same geometry, filter loss, and RF assumptions. It is distinct from restarting the whole study with flat terrain. Compare supported area with its reference: support that disappears depends on the propagation enhancement.
disp(view.rfComparison)
%%
%[text] ## 8. Combine support with geometry (2 minutes)
%[text] Apply the gate separately to each channel. A strong echo on one channel supplies one range constraint; the strongest-link SNR is not a combined localization SNR. Remove unavailable rows and their covariance entries, then recompute information for the remaining subset.
channelSNR_dB = result.analysis(altitudeIndex).snrDB(pointIndex,:);
availableRanges = channelSNR_dB>=cfg.snrGateDB;
disp(table(string({cfg.sites(1:3).name})',channelSNR_dB',availableRanges', ...
    VariableNames=["Transmitter","SNR_dB","RangeAvailable"]))
supportedH = rangeJacobian(availableRanges,:);
supportedR_m2 = rangeCovariance_m2(availableRanges,availableRanges);
% Start with unobservable 3D. Only a full-rank supported subset gets covariance.
supportedRank = 0;
supportedCovariance_m2 = inf(3);
supportedCondition = Inf;
if any(availableRanges)
    supportedL = chol(supportedR_m2,"lower");
    [~,supportedS,supportedV] = svd(supportedL\supportedH,"econ");
    supportedValues = diag(supportedS);
    supportedRank = nnz(supportedValues>max(size(supportedH))*eps(max(supportedValues)));
    if supportedRank==3
        supportedFactor = supportedV./supportedValues';
        supportedCovariance_m2 = supportedFactor*supportedFactor';
        supportedCondition = supportedValues(1)/supportedValues(end);
    end
end
supportedRMS_m = sqrt(trace(supportedCovariance_m2));
usefulPosition = supportedRank==3;
usefulPosition = usefulPosition && supportedCondition<=cfg.maxCondition;
usefulPosition = usefulPosition && supportedRMS_m<=cfg.totalLimitM;
disp(table(nnz(availableRanges),supportedRank,supportedRMS_m,usefulPosition, ...
    VariableNames=["SupportedRanges","Rank","PositionRMS_m","Useful3D"]))
% Verify the supported-subset calculation against the same production helper.
pointAvailable = helperLLGeometry(targetENU_m,transmitterENU_m,receiverENU_m, ...
    rangeCovariance_m2,1:3,availableRanges,cfg.maxCondition,cfg.totalLimitM);
assert(supportedRank==pointAvailable.rank);
helperCheckCovariance(supportedCovariance_m2,pointAvailable.covariance);
assert(usefulPosition==pointAvailable.useful);
%%
%[text] ## 8a. Identify useful coverage, including invalid cells
%[text] A cell is useful only if its supported subset passes all three checks. The compact table retains ROI-cell, valid-cell, and useful-cell counts so that a small set of finite uncertainties cannot conceal a mostly deficient region.
helperLLPlots(result,Plots=9,AltitudesFtAGL=mainAltitudeFtAGL, ...
    ROI=view.roiName,Display="inline");
disp(view.coverage)
%[text] Cell areas are geographic intersections with each ROI. A partially intersecting boundary cell contributes only its clipped area, but the condition is still evaluated at its center. A center outside the ROI can therefore contribute a small positive area; refinement must test whether it persists.
%%
%[text] ## 9. Check stability across altitude and both ROIs (2 minutes)
%[text] A conclusion from one map can be fragile. First compare useful area across the configured altitude slices in both ROIs, including the known-Up case. The dashed ideal curves show geometry potential; solid curves require signal support. Lines between slices are visual interpolation, not a volumetric coverage result.
helperLLPlots(result,Plots=11,Display="inline");
%[text] The experiment retains the complete study in `walkthroughStudy`. The next tables condense the sensitivity cases rather than repeating every full-size map.
%%
%[text] ## 9a. Change measurement assumptions and resolve boundary sampling
%[text] Range error changes uncertainty; the SNR gate changes which constraints exist. These nine 3D cases reuse the physical RF arrays. Their areas are newly useful with WLEK, relative to Newton + Hudson. Known-Up cases remain in `walkthroughStudy.sensitivity`.
disp(view.sensitivity)
%[text] Grid refinement evaluates the configured sensitivity altitude. **Center-inside count** distinguishes a supported sample in the ROI from a clipped area assigned using a sample outside it. Different positive areas on finer grids are not evidence of convergence.
disp(view.grid)
%[text] The catalog-Newton rerun tests the coordinate conflict, retaining the same site height and other assumptions. Its table includes both position modes and both ROIs at the displayed altitude.
disp(view.catalog)
%%
%[text] ## 9b. Keep the southern geometry comparison in its proper role
%[text] Cochesett helps distinguish a weak extra direction from the absence of a usable echo. Compare ideal valid counts, useful area, and median uncertainty with WLEK under the same assumptions. No Cochesett RF availability is inferred.
disp(view.cochesett)
%[text] Propagation-model dependence, site-coordinate uncertainty, error correlation, exact altitude conditioning, and global ambiguity remain limits. The model treats range errors as independent; shared timing or reference errors would change the information matrix.
%%
%[text] ## 10. Interpret and adapt the current study (2 minutes)
%[text] Read the current result alongside the grid and propagation comparisons. These statements are generated from this execution, so changing the error, gate, or physical mode changes the evidence used here.
disp(join(view.conclusion,newline))
%[text] **Acquisition caveat.** Realizing a modeled gain requires simultaneous coherent acquisition on separate RF channels, suitable reference signals, and synchronized/calibrated measurements. Installed receive-chain response, optional high-pass filtering, channel count/bandwidth, and reference quality remain unresolved.
%[text] The most useful next investigation is to measure per-channel echo/reference support and validate the signed propagation behavior near the receiver before expanding localization. This separates missing measurements from geometric limitations.
%[text] To adapt the study, edit `localizationLikelihoodConfig.m` or the setup overrides, rerun setup and scenario computation, then run the sections in order. After computation, map and table sections can be rerun without rebuilding the study. Worked matrix sections require the preceding range/Jacobian variables. `helperLLPlots` also supports the other configured altitude slices, both ROI names, and the figure numbers documented in its help.
%%
%[text] ## Optional: full verification and bulk export
%[text] Set the switch below to true only when you want the existing full-study runner: tests, native reference checks, 12 exported figures, CSV/MAT products, and regenerated report. It runs in a separate function workspace and rereads `localizationLikelihoodConfig.m`; temporary walkthrough overrides are not exported. The default walkthrough ends with the inline results and only cache writes.
runFullVerificationAndExport = false;
if runFullVerificationAndExport
    exportStatus = helperLLWalkthroughExport(walkthroughFolder); %#ok<UNRCH>
    disp(exportStatus)
end
%[text] Supporting references: [report](../../docs/localizationLikelihood/report.md), [assumptions](../../docs/localizationLikelihood/assumptions.md), [survey](../../docs/localizationLikelihood/repositorySurvey.md), and [concept index](../../concepts.md). The original command remains `run("TrackingPreWork/analysis/localizationLikelihood/runLocalizationLikelihoodPOC.m")` from the repository root.
%%
%[text] ## Setup helper
%[text] This small helper only locates the existing analysis folder. No machine-specific path is required.
function studyFolder = helperWalkthroughSetup()
candidates = [string(pwd), ...
    fullfile(pwd,"analysis","localizationLikelihood"), ...
    fullfile(pwd,"TrackingPreWork","analysis","localizationLikelihood")];
found = isfile(fullfile(candidates,"localizationLikelihoodConfig.m"));
assert(any(found), ...
    "Start from flightTest, TrackingPreWork, or analysis/localizationLikelihood.");
studyFolder = candidates(find(found,1));
% Keep helpers available for independent presentation-section reruns.
addpath(studyFolder);
end
function helperCheckCovariance(actual,expected)
% Compare finite covariance at numerical tolerance and retain missing rank.
assert(isequal(isinf(actual),isinf(expected)));
finite = isfinite(expected);
difference = norm(actual(finite)-expected(finite));
assert(difference<=1e-10*max(1,norm(expected(finite))));
end
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
