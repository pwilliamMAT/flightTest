function rf = helperLLRF(cfg,grid,terrain,siteIndex,altitudeIndex)
%HELPERLLRF Two-leg terrain excess loss plus explicit bistatic radar SNR.
% The reverse leg is reciprocal: a transmitter at the receiver location,
% at THIS illuminator frequency, yields the target-to-receiver path loss.
site = cfg.sites(siteIndex);
heightAGL = cfg.altitudesFtAGL(altitudeIndex)*cfg.metresPerFoot;
p = terrain.targetENU(:,:,altitudeIndex);
sourceFiles = [string(mfilename("fullpath"))+".m", ...
    string(fullfile(fileparts(mfilename("fullpath")),"helperLLRadarSNR.m"))];
key = struct("site",site,"receiver",cfg.receiver,"heightAGL",heightAGL, ...
    "terrain",terrain.key,"p",p,"tx",terrain.transmitterENU(siteIndex,:), ...
    "rf",cfg.rf,"propagation",cfg.propagation, ...
    "filter",helperLLSourceStamp(cfg.filterPath),"code",helperLLSourceStamp(sourceFiles));
file = helperLLCacheFile(cfg,"rf_"+site.name,key);
[rf,hit] = helperLLCache("get",file,key);
if hit && ~cfg.forceRefresh
    rf.cacheHit = true;
    return
end
rf = struct("mode",terrain.mode,"cacheHit",false,"key",key);
rf.rangesM = [vecnorm(p-terrain.transmitterENU(siteIndex,:),2,2), ...
    vecnorm(p-terrain.receiverENU,2,2)];
if terrain.mode == "terrain"
    target = rxsite(Latitude=grid.latitude',Longitude=grid.longitude', ...
        AntennaHeight=heightAGL);
    tx = txsite(Latitude=site.latitude,Longitude=site.longitude, ...
        AntennaHeight=site.heightAGL,TransmitterFrequency=site.frequencyHz);
    reverse = txsite(Latitude=cfg.receiver.latitude,Longitude=cfg.receiver.longitude, ...
        AntennaHeight=cfg.receiver.heightAGL,TransmitterFrequency=site.frequencyHz);
    lr = propagationModel("longley-rice");
    fields = fieldnames(cfg.propagation);
    for k = 1:numel(fields)
        lr.(fields{k}) = cfg.propagation.(fields{k});
    end
    fs = propagationModel("freespace");
    try
        forwardLoss = pathloss(lr,target,tx)-pathloss(fs,target,tx);
        reverseLoss = pathloss(lr,target,reverse)-pathloss(fs,target,reverse);
    catch exception
        error("localizationLikelihood:PropagationUnavailable", ...
            "Native terrain propagation failed: %s",exception.message);
    end
    rf.excessLossDB = [forwardLoss(:),reverseLoss(:)];
else
    rf.excessLossDB = zeros(size(p,1),2);
end
if ~all(isfinite(rf.excessLossDB),"all")
    error("localizationLikelihood:PropagationUnavailable","Propagation returned missing losses.");
end
rf.filterLossDB = 0;
if cfg.rf.applyBandpassLoss
    net = sparameters(cfg.filterPath);
    response = interp1(net.Frequencies,squeeze(net.Parameters(2,1,:)),site.frequencyHz);
    rf.filterLossDB = -20*log10(abs(response));
end
rf.radar = helperLLRadarSNR(cfg,site,rf.rangesM,sum(rf.excessLossDB,2)+rf.filterLossDB);
rf.snrDB = rf.radar.snrDB(:);
helperLLCache("put",file,key,rf);
fprintf("RF computed: %s, %.0f ft AGL, %s, SNR %.1f to %.1f dB\n", ...
    site.name,cfg.altitudesFtAGL(altitudeIndex),terrain.mode,min(rf.snrDB),max(rf.snrDB));
end
