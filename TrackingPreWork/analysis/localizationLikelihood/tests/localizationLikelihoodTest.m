classdef localizationLikelihoodTest < matlab.unittest.TestCase
    %LOCALIZATIONLIKELIHOODTEST Range-only localization and explicit RF checks.
    % Ten sanity groups cover range conventions, derivatives, observability,
    % fixed Up, variance scaling, independent information, availability,
    % native localization, RF conventions, and reproducible cache use.
    % Tests use synthetic anchors to isolate arithmetic from terrain service
    % availability. The full study separately checks physical-site results.

    properties (TestParameter)
        rfChange = struct( ...
            'noiseFigure',struct('field','noiseFigureDB','delta',3,'expected',-3), ...
            'receiveGain',struct('field','receiveGainDBi','delta',3,'expected',3), ...
            'erpConversion',struct('field','erpToEirpDB','delta',2.15,'expected',2.15), ...
            'additionalLoss',struct('field','additionalLossDB','delta',3,'expected',-3))
    end

    methods (TestClassSetup)
        function addStudyPath(testCase)
            source = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(source));
        end
    end

    methods (Test)
        function excessRangeIsZeroOnBaseline(testCase)
            p = [4 0 0;4 3 0];
            g = helperLLGeometry(p,[10 0 0],[0 0 0],1,1:3,true(2,1),1e4,1e3);
            expected = [0;sqrt(45)+5-10];
            testCase.verifyEqual(g.rho,expected,AbsTol=1e-12);
            testCase.verifyGreaterThanOrEqual(g.rho,zeros(2,1));
        end

        function exchangeOfTransmitterAndReceiverPreservesRange(testCase)
            p = [1000 2000 3000];
            a = [10000 0 100];
            b = [500 -400 30];
            first = helperLLGeometry(p,a,b,2500,1:3,true,1e4,1e3);
            second = helperLLGeometry(p,b,a,2500,1:3,true,1e4,1e3);
            testCase.verifyEqual(first.rho,second.rho,AbsTol=1e-10);
            testCase.verifyEqual(first.H,second.H,AbsTol=1e-12);
        end

        function analyticalJacobianMatchesFiniteDifference(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            step = 0.01;
            g = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            plus = localizationLikelihoodTest.ranges(p+step*eye(3),tx,rx);
            minus = localizationLikelihoodTest.ranges(p-step*eye(3),tx,rx);
            numerical = ((plus-minus)/(2*step)).';
            testCase.verifyEqual(reshape(g.H,4,3),numerical,AbsTol=5e-9);
        end

        function twoRangesCannotObserveThreeCoordinates(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            g = helperLLGeometry(p,tx(1:2,:),rx,2500*eye(2),1:3,true(1,2),1e4,1e3);
            testCase.verifyEqual(g.rank,2);
            testCase.verifyEqual(g.covariance,inf(3));
            testCase.verifyEqual(g.totalRMS,Inf);
            testCase.verifyFalse(g.useful);
        end

        function oneRangeCannotObserveTwoCoordinates(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            g = helperLLGeometry(p,tx(1,:),rx,2500,1:2,true,1e4,500);
            testCase.verifyEqual(g.rank,1);
            testCase.verifyEqual(g.covariance,inf(2));
            testCase.verifyFalse(g.useful);
        end

        function coplanarTargetAndAnchorsHaveNoVerticalInformation(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            p(3) = 0;
            tx(:,3) = 0;
            rx(3) = 0;
            g = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            testCase.verifyEqual(g.rank,2);
            testCase.verifyEqual(g.H(:,:,3),zeros(1,4),AbsTol=1e-12);
            testCase.verifyFalse(g.useful);
        end

        function knownUpRetainsThreeDimensionalSlants(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            known = helperLLGeometry(p,tx,rx,2500*eye(4),1:2,true(1,4),1e4,500);
            full = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            expected = (p-tx)./vecnorm(p-tx,2,2)+(p-rx)/norm(p-rx);
            testCase.verifyEqual(known.rho,full.rho,AbsTol=1e-10);
            testCase.verifyEqual(reshape(known.H,4,3),expected,AbsTol=1e-12);
            testCase.verifyEqual(known.verticalRMS,0,AbsTol=1e-12);
            testCase.verifyEqual(known.totalRMS,known.horizontalRMS,AbsTol=1e-12);
            testCase.verifySize(known.covariance,[2 2]);
        end

        function covarianceScalesWithRangeVariance(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            low = helperLLGeometry(p,tx,rx,25^2*eye(4),1:3,true(1,4),1e4,1e3);
            high = helperLLGeometry(p,tx,rx,100^2*eye(4),1:3,true(1,4),1e4,1e3);
            testCase.verifyEqual(high.covariance,16*low.covariance,AbsTol=1e-8);
            testCase.verifyEqual(high.totalRMS,4*low.totalRMS,AbsTol=1e-10);
            testCase.verifyEqual(high.condition,low.condition,AbsTol=1e-12);
        end

        function independentAddedRangeCannotWorsenCovariance(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            baseline = helperLLGeometry(p,tx(1:3,:),rx,2500*eye(3),1:3,true(1,3),1e4,1e3);
            added = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            eigenvalues = eig(baseline.covariance-added.covariance);
            testCase.verifyGreaterThanOrEqual(eigenvalues,-1e-8*ones(3,1));
            testCase.verifyLessThanOrEqual(added.totalRMS,baseline.totalRMS+1e-10);
        end

        function unsupportedThirdRangePreservesUsefulBaseline(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            baseline = helperLLGeometry(p,tx(1:2,:),rx,2500*eye(2),1:2,true(1,2),1e4,500);
            weak = helperLLGeometry(p,tx(1:3,:),rx,2500*eye(3),1:2,[true true false],1e4,500);
            testCase.verifyTrue(baseline.useful);
            testCase.verifyEqual(weak.useful,baseline.useful);
            testCase.verifyEqual(weak.covariance,baseline.covariance,AbsTol=1e-10);
        end

        function eachAvailableSubsetDeterminesItsOwnRank(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            available = logical([0 0 0 0;1 0 0 0;1 1 0 0;1 1 1 0]);
            g = helperLLGeometry(repmat(p,4,1),tx,rx,2500*eye(4),1:3,available,1e4,1e3);
            testCase.verifyEqual(g.rank,(0:3).');
            testCase.verifyEqual(g.useful(1:3),false(3,1));
            testCase.verifyTrue(isfinite(g.totalRMS(4)));
        end

        function correlatedNoiseUsesSelectedCovariance(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            R = 2500*(0.75*eye(4)+0.25*ones(4));
            selected = [1 2 4];
            g = helperLLGeometry(p,tx,rx,R,1:3,logical([1 1 0 1]),1e4,1e3);
            H = reshape(g.H(1,selected,:),3,3);
            expected = (H'*(R(selected,selected)\H))\eye(3);
            testCase.verifyEqual(g.covariance,expected,AbsTol=1e-8);
        end

        function geometryMetricHasUnitRangeVariance(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            g = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            unit = helperLLGeometry(p,tx,rx,eye(4),1:3,true(1,4),1e4,1e3);
            testCase.verifyEqual(g.geometryRMS,unit.totalRMS,AbsTol=1e-12);
            testCase.verifyEqual(g.totalRMS,50*g.geometryRMS,AbsTol=1e-10);
        end

        function reorderingMeasurementsPreservesInformation(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            R = diag([25 40 50 100].^2);
            order = [4 2 1 3];
            original = helperLLGeometry(p,tx,rx,R,1:3,true(1,4),1e4,1e3);
            reordered = helperLLGeometry(p,tx(order,:),rx,R(order,order),1:3,true(1,4),1e4,1e3);
            testCase.verifyEqual(reordered.covariance,original.covariance,AbsTol=1e-8);
            testCase.verifyEqual(reordered.rho,original.rho(:,order),AbsTol=1e-10);
        end

        function conditionAndUncertaintyLimitsBothGateUsefulness(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            accepted = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            badCondition = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1,1e3);
            badError = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1);
            testCase.verifyTrue(accepted.useful);
            testCase.verifyFalse(badCondition.useful);
            testCase.verifyFalse(badError.useful);
            testCase.verifyEqual(badCondition.rank,3);
            testCase.verifyEqual(badError.rank,3);
        end

        function nativeCrlbAgreesAtWellConditionedPoint(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            R = 2500*eye(4);
            g = helperLLGeometry(p,tx,rx,R,1:3,true(1,4),1e4,1e3);
            signal = @(x) localizationLikelihoodTest.ranges(x(:).',tx,rx).';
            [native,information] = crlb(signal,R,p.',DataComplexity='Real');
            H = reshape(g.H,4,3);
            relativeError = norm(native-g.covariance,'fro')/norm(g.covariance,'fro');
            testCase.verifyLessThan(relativeError,1e-7);
            testCase.verifyEqual(information,H'*(R\H),AbsTol=1e-10);
        end

        function nativeTsoaAddsBaselineAndConvertsSecondsSquared(testCase)
            [p,tx,rx] = localizationLikelihoodTest.anchors();
            c = physconst('LightSpeed');
            g = helperLLGeometry(p,tx,rx,2500*eye(4),1:3,true(1,4),1e4,1e3);
            baseline = vecnorm(tx-rx,2,2);
            rangeSum = g.rho.'+baseline;
            [estimate,covariance] = tsoaposest(rangeSum/c,2500/c^2*ones(4,1),tx.',rx.');
            [rangeEstimate,rangeCovariance] = tsoaposest(rangeSum,2500*ones(4,1),tx.',rx.',PropagationSpeed=1);
            testCase.verifyEqual(estimate,p.',AbsTol=1e-7);
            testCase.verifyEqual(estimate,rangeEstimate,AbsTol=1e-7);
            testCase.verifyEqual(covariance,rangeCovariance,AbsTol=1e-6);
            testCase.verifyGreaterThan(eig(covariance),zeros(3,1));
        end

        function explicitRadarEquationMatchesHandCalculation(testCase)
            cfg = localizationLikelihoodConfig();
            % Fixed reference case stays independent of edited study defaults.
            cfg.rf.erpToEirpDB = 2.15;
            cfg.rf.referenceTemperatureK = 290;
            cfg.rf.noiseFigureDB = 2.5;
            cfg.rf.receiveGainDBi = 12;
            cfg.rf.rcsM2 = 0.5;
            cfg.rf.equivalentIntervalS = 5e-6;
            site = cfg.sites(1);
            ranges = [10000 20000;15000 30000];
            loss = [0;7];
            cfg.rf.additionalLossDB = 1.2;
            actual = helperLLRadarSNR(cfg,site,ranges,loss);
            f = cfg.rf;
            k = physconst('Boltzmann');
            wavelength = physconst('LightSpeed')/site.frequencyHz;
            eirp = site.erpW*10^(2.15/10);
            temperature = 290*10^(2.5/10);
            power = eirp*10^(12/10)*wavelength^2*0.5 ...
                ./((4*pi)^3*prod(ranges.^2,2)).*10.^(-(loss+1.2)/10);
            expected = 10*log10(power*5e-6/(k*temperature));
            testCase.verifyEqual(actual.snrDB,expected,AbsTol=1e-10);
            testCase.verifyEqual(actual.receivedPowerW,power,AbsTol=1e-24);
            testCase.verifyEqual(actual.eirpW,eirp,AbsTol=1e-8);
            testCase.verifyEqual(actual.noiseTemperatureK,temperature,AbsTol=1e-10);
            testCase.verifyEqual(actual.inputNoiseW,k*temperature*f.bandwidthHz,AbsTol=1e-24);
        end

        function explicitGainNoiseAndLossChangesAreInDecibels(testCase,rfChange)
            cfg = localizationLikelihoodConfig();
            baseline = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            cfg.rf.(rfChange.field) = cfg.rf.(rfChange.field)+rfChange.delta;
            changed = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            testCase.verifyEqual(changed.snrDB-baseline.snrDB,rfChange.expected,AbsTol=1e-10);
        end

        function equivalentIntervalIsCountedOnce(testCase)
            cfg = localizationLikelihoodConfig();
            baseline = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            cfg.rf.equivalentIntervalS = 2*cfg.rf.equivalentIntervalS;
            doubled = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            testCase.verifyEqual(doubled.snrDB-baseline.snrDB,10*log10(2),AbsTol=1e-10);
            testCase.verifyEqual(doubled.receivedPowerW,baseline.receivedPowerW,AbsTol=1e-24);
        end

        function frequencyAndSlantDistanceFollowBistaticEquation(testCase)
            cfg = localizationLikelihoodConfig();
            site = cfg.sites(1);
            baseline = helperLLRadarSNR(cfg,site,[10000 20000],0);
            site.frequencyHz = 2*site.frequencyHz;
            higherFrequency = helperLLRadarSNR(cfg,site,[10000 20000],0);
            farther = helperLLRadarSNR(cfg,cfg.sites(1),[20000 40000],0);
            testCase.verifyEqual(higherFrequency.snrDB-baseline.snrDB,-20*log10(2),AbsTol=1e-10);
            testCase.verifyEqual(farther.snrDB-baseline.snrDB,-40*log10(2),AbsTol=1e-10);
        end

        function bandwidthAffectsInputNoiseWithoutExtraIntegrationGain(testCase)
            cfg = localizationLikelihoodConfig();
            baseline = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            cfg.rf.bandwidthHz = 2*cfg.rf.bandwidthHz;
            wider = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            testCase.verifyEqual(wider.inputNoiseW,2*baseline.inputNoiseW,AbsTol=1e-24);
            testCase.verifyEqual(wider.snrDB,baseline.snrDB,AbsTol=1e-10);
            inputSNR = 10*log10(baseline.receivedPowerW/baseline.inputNoiseW);
            testCase.verifyEqual(baseline.snrDB-inputSNR, ...
                10*log10(cfg.rf.bandwidthHz/2*cfg.rf.equivalentIntervalS),AbsTol=1e-10);
        end

        function cachedAndFreshRfResultsAreIdentical(testCase)
            cfg = localizationLikelihoodConfig();
            file = [tempname(fileparts(mfilename('fullpath'))) '.mat'];
            testCase.addTeardown(@() delete(file));
            key = struct('site',cfg.sites(1),'rf',cfg.rf,'mode',"terrain");
            fresh = helperLLRadarSNR(cfg,cfg.sites(1),[10000 20000],0);
            [stored,writeHit] = helperLLCache("put",file,key,fresh);
            [cached,readHit] = helperLLCache("get",file,key);
            testCase.verifyTrue(writeHit);
            testCase.verifyTrue(readHit);
            testCase.verifyEqual(stored,fresh);
            testCase.verifyEqual(cached,fresh);
        end

        function changedConfigurationAndSourceInvalidateCache(testCase)
            cfg = localizationLikelihoodConfig();
            file = [tempname(fileparts(mfilename('fullpath'))) '.mat'];
            testCase.addTeardown(@() delete(file));
            key = struct('rf',cfg.rf,'source',"catalog-v1",'mode',"terrain");
            helperLLCache("put",file,key,[1 2 3]);
            changedConfiguration = key;
            changedConfiguration.rf.noiseFigureDB = 4;
            changedSource = key;
            changedSource.source = "catalog-v2";
            [valueConfig,hitConfig] = helperLLCache("get",file,changedConfiguration);
            [valueSource,hitSource] = helperLLCache("get",file,changedSource);
            testCase.verifyFalse(hitConfig);
            testCase.verifyFalse(hitSource);
            testCase.verifyEmpty(valueConfig);
            testCase.verifyEmpty(valueSource);
        end

        function fallbackMetadataCannotReuseTerrainCache(testCase)
            file = [tempname(fileparts(mfilename('fullpath'))) '.mat'];
            testCase.addTeardown(@() delete(file));
            terrain = struct('mode',"terrain",'source',"GMTED2010");
            fallback = struct('mode',"flat-free-space",'source',"explicit fallback");
            helperLLCache("put",file,terrain,1);
            [value,hit] = helperLLCache("get",file,fallback);
            testCase.verifyFalse(hit);
            testCase.verifyEmpty(value);
        end

        function clippedGridCellsExactlyCoverEachRoi(testCase)
            cfg = localizationLikelihoodConfig();
            cfg.rois(1).bounds = [42.391 42.407 -71.413 -71.392];
            cfg.rois(2).bounds = [42.379 42.395 -71.421 -71.402];
            cfg.gridSpacingDegrees = 0.01;
            grid = helperLLGrid(cfg);
            bounds = vertcat(cfg.rois.bounds);
            expected = areaquad(bounds(:,1),bounds(:,3),bounds(:,2),bounds(:,4),wgs84Ellipsoid('km'));
            testCase.verifyEqual(sum(grid.areaKm2,1).',expected,AbsTol=1e-8);
            testCase.verifyGreaterThanOrEqual(grid.areaKm2,zeros(size(grid.areaKm2)));
            testCase.verifyEqual(grid.mask,any(grid.areaKm2>0,2));
        end

        function explicitFlatTerrainRetainsHeightDatumAndCacheLabels(testCase)
            cfg = localizationLikelihoodTest.smallConfiguration();
            testCase.addTeardown(@() localizationLikelihoodTest.removeTestCache(cfg.cacheDir));
            grid = helperLLGrid(cfg);
            fresh = helperLLTerrain(cfg,grid);
            cached = helperLLTerrain(cfg,grid);
            origin = fresh.originLLH;
            [lat,lon,height] = enu2geodetic(fresh.targetENU(:,1),fresh.targetENU(:,2), ...
                fresh.targetENU(:,3),origin(1),origin(2),origin(3),wgs84Ellipsoid);
            expectedHeight = fresh.geoidM(6:end)+cfg.altitudesFtAGL*cfg.metresPerFoot;
            testCase.verifyEqual(fresh.mode,"flat-free-space");
            testCase.verifyEqual(fresh.groundMSL,zeros(size(fresh.groundMSL)),AbsTol=1e-12);
            testCase.verifyEqual(origin(3),fresh.geoidM(1)+cfg.receiver.heightAGL,AbsTol=1e-10);
            testCase.verifyEqual(lat,grid.latitude,AbsTol=1e-9);
            testCase.verifyEqual(lon,grid.longitude,AbsTol=1e-9);
            testCase.verifyEqual(height,expectedHeight,AbsTol=1e-6);
            testCase.verifyFalse(fresh.cacheHit);
            testCase.verifyTrue(cached.cacheHit);
            testCase.verifyEqual(rmfield(fresh,'cacheHit'),rmfield(cached,'cacheHit'));
        end

        function changedAltitudeAndAntennaHeightInvalidateTerrainPositions(testCase)
            cfg = localizationLikelihoodTest.smallConfiguration();
            testCase.addTeardown(@() localizationLikelihoodTest.removeTestCache(cfg.cacheDir));
            grid = helperLLGrid(cfg);
            initial = helperLLTerrain(cfg,grid);
            higher = cfg;
            higher.altitudesFtAGL = cfg.altitudesFtAGL+1000;
            changedAltitude = helperLLTerrain(higher,grid);
            taller = cfg;
            taller.sites(1).heightAGL = cfg.sites(1).heightAGL+20;
            changedAntenna = helperLLTerrain(taller,grid);
            testCase.verifyFalse(changedAltitude.cacheHit);
            testCase.verifyFalse(changedAntenna.cacheHit);
            testCase.verifyNotEqual(initial.key,changedAltitude.key);
            testCase.verifyNotEqual(initial.key,changedAntenna.key);
            testCase.verifyEqual(vecnorm(changedAltitude.targetENU-initial.targetENU,2,2), ...
                repmat(304.8,size(grid.latitude)),AbsTol=1e-6);
            testCase.verifyEqual(norm(changedAntenna.transmitterENU(1,:)-initial.transmitterENU(1,:)),20,AbsTol=1e-6);
            testCase.verifyEqual(changedAntenna.targetENU,initial.targetENU,AbsTol=1e-12);
        end

        function actualFlatRfHasZeroTerrainLossAndReproducibleCache(testCase)
            cfg = localizationLikelihoodTest.smallConfiguration();
            testCase.addTeardown(@() localizationLikelihoodTest.removeTestCache(cfg.cacheDir));
            grid = helperLLGrid(cfg);
            terrain = helperLLTerrain(cfg,grid);
            fresh = helperLLRF(cfg,grid,terrain,3,1);
            cached = helperLLRF(cfg,grid,terrain,3,1);
            expected = helperLLRadarSNR(cfg,cfg.sites(3),fresh.rangesM,zeros(numel(grid.latitude),1));
            changed = cfg;
            changed.rf.noiseFigureDB = changed.rf.noiseFigureDB+3;
            revised = helperLLRF(changed,grid,terrain,3,1);
            testCase.verifyEqual(fresh.mode,"flat-free-space");
            testCase.verifyEqual(fresh.excessLossDB,zeros(numel(grid.latitude),2),AbsTol=1e-12);
            testCase.verifyEqual(fresh.snrDB,expected.snrDB,AbsTol=1e-10);
            testCase.verifyFalse(fresh.cacheHit);
            testCase.verifyTrue(cached.cacheHit);
            testCase.verifyEqual(rmfield(fresh,'cacheHit'),rmfield(cached,'cacheHit'));
            testCase.verifyFalse(revised.cacheHit);
            testCase.verifyEqual(revised.snrDB-fresh.snrDB,-3*ones(numel(grid.latitude),1),AbsTol=1e-10);
        end

        function explicitFlatScenarioHasCoherentSignalAndGeometrySummaries(testCase)
            cfg = localizationLikelihoodTest.smallConfiguration();
            testCase.addTeardown(@() localizationLikelihoodTest.removeTestCache(cfg.cacheDir));
            cfg.snrGateDB = -Inf;
            result = helperLLRunScenario(cfg);
            summary = result.summary;
            actual = summary(~summary.GeometryOnly,:);
            baseline3D = actual.Configuration=="Newton+Hudson";
            baseline3D = baseline3D & actual.Mode=="Unconstrained 3D";
            added = result.analysis(1).configurations(5);
            countsArea = actual.Measurement0AreaKm2+actual.Measurement1AreaKm2 ...
                +actual.Measurement2AreaKm2+actual.Measurement3AreaKm2;
            attr = result.attribution;
            testCase.verifyEqual(result.mode,"flat-free-space");
            testCase.verifyEqual(result.fallbackReason,"");
            testCase.verifyEqual(actual.AnyLinkAreaKm2,actual.ROIAreaKm2,AbsTol=1e-10);
            testCase.verifyEqual(countsArea,actual.ROIAreaKm2,AbsTol=1e-10);
            testCase.verifyEqual(actual.UsefulAreaKm2,actual.IdealUsefulAreaKm2,AbsTol=1e-10);
            testCase.verifyEqual(actual.UsefulAreaKm2(baseline3D),zeros(nnz(baseline3D),1),AbsTol=1e-12);
            testCase.verifyEqual(actual.ValidCells+actual.RankDeficientCells+actual.IllConditionedCells,actual.ROICells);
            testCase.verifyEqual(attr.AddedUsefulAreaKm2, ...
                attr.AddedWhereBothBaselineSupportedKm2+attr.AddedWhereBaselineMissingConstraintKm2,AbsTol=1e-10);
            testCase.verifyEqual(added.available3D.covariance,added.ideal3D.covariance,AbsTol=1e-8);
        end

        function unsupportedThirdLinkScenarioRecomputesBaselineSubset(testCase)
            cfg = localizationLikelihoodTest.smallConfiguration();
            testCase.addTeardown(@() localizationLikelihoodTest.removeTestCache(cfg.cacheDir));
            cfg.snrGateDB = -100;
            cfg.sites(3).erpW = 1e-100;
            result = helperLLRunScenario(cfg);
            baseline = result.analysis(1).configurations(4);
            added = result.analysis(1).configurations(5);
            testCase.verifyTrue(all(baseline.available,'all'));
            testCase.verifyFalse(any(added.available(:,3)));
            testCase.verifyEqual(added.available2D.covariance,baseline.available2D.covariance,AbsTol=1e-8);
            testCase.verifyEqual(added.available2D.useful,baseline.available2D.useful);
            testCase.verifyEqual(added.available3D.rank,baseline.available3D.rank);
            testCase.verifyEqual(result.attribution.AddedUsefulAreaKm2,zeros(height(result.attribution),1),AbsTol=1e-12);
            testCase.verifyEqual(result.attribution.LostUsefulCells,zeros(height(result.attribution),1));
        end
    end

    methods (Static)
        function cfg = smallConfiguration()
            cfg = localizationLikelihoodConfig();
            cfg.rois(1).bounds = [42.391 42.407 -71.413 -71.392];
            cfg.rois(2).bounds = [42.379 42.395 -71.421 -71.402];
            cfg.gridSpacingDegrees = 0.01;
            cfg.altitudesFtAGL = 6000;
            cfg.terrainMode = "flat-free-space";
            cfg.allowFallback = false;
            cfg.forceRefresh = false;
            cfg.rf.applyBandpassLoss = false;
            cfg.cacheDir = tempname(fileparts(mfilename('fullpath')));
            mkdir(cfg.cacheDir);
        end

        function removeTestCache(folder)
            % Only remove this suite's unique disposable cache and its MATs.
            % Confirm the absolute parent before touching any file on Windows.
            assert(strcmp(fileparts(folder),fileparts(mfilename('fullpath'))));
            files = dir(fullfile(folder,'*.mat'));
            for k = 1:numel(files)
                delete(fullfile(folder,files(k).name));
            end
            rmdir(folder);
        end

        function [p,tx,rx] = anchors()
            p = [1000 2000 3000];
            tx = [0 0 0;10000 0 100;0 12000 200;-9000 -6000 400];
            rx = [500 -400 30];
        end

        function rho = ranges(p,tx,rx)
            % Independent equation used for finite differences/native checks.
            delta = reshape(p,size(p,1),1,3)-reshape(tx,1,size(tx,1),3);
            transmitLeg = sqrt(sum(delta.^2,3));
            receiveLeg = vecnorm(p-rx,2,2);
            directPath = vecnorm(tx-rx,2,2).';
            rho = transmitLeg+receiveLeg-directPath;
        end
    end
end
