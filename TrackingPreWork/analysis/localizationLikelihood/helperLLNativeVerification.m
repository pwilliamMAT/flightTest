function verification = helperLLNativeVerification(result)
%HELPERLLNATIVEVERIFICATION Independent native checks, not a tracker.
% crlb differentiates the range function numerically. Check one well-
% conditioned real grid point using exactly the same range covariance.
[~,a] = min(abs(result.cfg.altitudesFtAGL-result.cfg.sensitivityAltitudeFtAGL));
g = result.analysis(a).configurations(5).ideal3D;
candidate = g.condition;
candidate(~result.grid.mask) = Inf;
[~,q] = min(candidate);
p = result.terrain.targetENU(q,:,a)';
tx = result.terrain.transmitterENU(1:3,:);
rx = result.terrain.receiverENU;
R = result.cfg.rangeSigmaM^2*eye(3);
[native,fim] = crlb(@(x) excessRanges(x,tx,rx),R,p,DataComplexity="Real");
H = reshape(g.H(q,:,:),3,3);
L = chol(R,"lower");
verification.crlbRelativeError = norm(native-g.covariance(:,:,q),"fro")/norm(native,"fro");
verification.informationRelativeError = norm(fim-(L\H)'*(L\H),"fro")/norm(fim,"fro");
verification.gridPointENU = p;
assert(verification.crlbRelativeError<1e-5,"Native CRLB disagreement.");
% Four spatially diverse synthetic anchors avoid making the test depend on
% global ambiguity of exactly three ellipsoids. Units are seconds and s^2.
syntheticTx = [0 0 0;1000 0 100;0 1200 50;-600 -700 900];
syntheticRx = [100 -200 20];
truth = [250;350;650];
rho = excessRanges(truth,syntheticTx,syntheticRx);
baseline = vecnorm(syntheticTx-syntheticRx,2,2);
c = physconst("LightSpeed");
tsoa = (rho+baseline)/c;
tsoavar = result.cfg.rangeSigmaM^2/c^2*ones(4,1);
estimate = tsoaposest(tsoa,tsoavar,syntheticTx',syntheticRx',PropagationSpeed=c);
verification.tsoaPositionErrorM = norm(estimate-truth);
assert(verification.tsoaPositionErrorM<1e-5,"Native TSOA recovery failed.");
% Also compare a fresh native terrain/RF calculation with the cached study.
% This tests the physical service path in addition to the suite's explicit
% fallback-cache tests. An outage here is a verification failure, not a pass.
freshCfg = result.cfg;
freshCfg.forceRefresh = true;
freshTerrain = helperLLTerrain(freshCfg,result.grid);
freshRF = helperLLRF(freshCfg,result.grid,freshTerrain,3,a);
verification.freshTerrainMaximumDifferenceM = ...
    max(abs(freshTerrain.targetENU-result.terrain.targetENU),[],"all");
verification.freshRFMaximumDifferenceDB = max(abs(freshRF.snrDB-result.rf{a,3}.snrDB));
assert(verification.freshTerrainMaximumDifferenceM<1e-8,"Fresh terrain differs from cached study.");
assert(verification.freshRFMaximumDifferenceDB<1e-8,"Fresh RF differs from cached study.");
end

function rho = excessRanges(p,tx,rx)
rho = vecnorm(p'-tx,2,2)+norm(p'-rx)-vecnorm(tx-rx,2,2);
end
