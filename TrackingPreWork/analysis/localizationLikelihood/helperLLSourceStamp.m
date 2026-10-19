function stamps = helperLLSourceStamp(paths)
%HELPERLLSOURCESTAMP Preserve source content digests in cache and results.
stamps = struct("path",{},"sha256",{});
for k = 1:numel(paths)
    fid = fopen(paths(k),"rb");
    assert(fid>=0,"Cannot read source %s",paths(k));
    cleanup = onCleanup(@() fclose(fid));
    bytes = fread(fid,Inf,"*uint8");
    md = java.security.MessageDigest.getInstance("SHA-256");
    digest = typecast(md.digest(bytes),"uint8");
    stamps(k).path = paths(k);
    stamps(k).sha256 = string(lower(reshape(dec2hex(digest,2)',1,[])));
    clear cleanup
end
end
