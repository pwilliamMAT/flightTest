function analysis = helperLLAnalyze(cfg,grid,terrain,rf)
%HELPERLLANALYZE Rebuild information using only available measurements.
% Signal coverage answers whether ANY echo is supported. Localization also
% needs enough independent directions. A maximum-SNR map cannot establish it.
n = numel(grid.lat);
for a = 1:numel(cfg.altitudesFtAGL)
    p = terrain.targetENU(:,:,a);
    snr = [rf{a,1}.snrDB rf{a,2}.snrDB rf{a,3}.snrDB];
    analysis(a).snrDB = snr;
    for k = 1:numel(cfg.configurations)
        ids = cfg.configurations{k};
        tx = terrain.transmitterENU(ids,:);
        R = cfg.rangeSigmaM^2*eye(numel(ids));
        allAvailable = true(n,numel(ids));
        one.name = cfg.configurationNames(k);
        one.ids = ids;
        one.geometryOnly = any(ids==4);
        one.ideal3D = helperLLGeometry(p,tx,terrain.receiverENU,R,1:3, ...
            allAvailable,cfg.maxCondition,cfg.totalLimitM);
        one.ideal2D = helperLLGeometry(p,tx,terrain.receiverENU,R,1:2, ...
            allAvailable,cfg.maxCondition,cfg.horizontalLimitM);
        one.available = false(n,numel(ids));
        one.available3D = [];
        one.available2D = [];
        if ~one.geometryOnly
            one.available = snr(:,ids)>=cfg.snrGateDB;
            one.available3D = helperLLGeometry(p,tx,terrain.receiverENU,R,1:3, ...
                one.available,cfg.maxCondition,cfg.totalLimitM);
            one.available2D = helperLLGeometry(p,tx,terrain.receiverENU,R,1:2, ...
                one.available,cfg.maxCondition,cfg.horizontalLimitM);
        end
        analysis(a).configurations(k) = one;
    end
end
end
