function file = helperLLCacheFile(cfg,prefix,key)
%HELPERLLCACHEFILE Content-addressed caches preserve alternate scenarios.
md = java.security.MessageDigest.getInstance("SHA-256");
digest = typecast(md.digest(uint8(unicode2native(jsonencode(key),"UTF-8"))),"uint8");
name = lower(reshape(dec2hex(digest,2)',1,[]));
file = fullfile(cfg.cacheDir,prefix+"_"+string(name(1:24))+".mat");
end
