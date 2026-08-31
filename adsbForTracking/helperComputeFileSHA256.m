function hashText = helperComputeFileSHA256(filePath)
%HELPERCOMPUTEFILESHA256 Return the uppercase SHA-256 digest for one file.

filePath = string(filePath);

if ~isscalar(filePath) || strlength(strtrim(filePath)) == 0
    error("ADSBDataVersion:InvalidHashPath", ...
        "File path must be a nonempty string scalar.");
end

if exist(filePath, "file") ~= 2
    error("ADSBDataVersion:MissingHashFile", ...
        "Cannot hash a missing file: %s", filePath);
end

algorithm = java.security.MessageDigest.getInstance("SHA-256");
fileStream = java.io.FileInputStream(char(filePath));
stream = java.security.DigestInputStream( ...
    java.io.BufferedInputStream(fileStream), ...
    algorithm);
cleanup = onCleanup(@() stream.close());
buffer = zeros(8192, 1, "int8");
bytesRead = stream.read(buffer, 0, numel(buffer));

while bytesRead >= 0
    bytesRead = stream.read(buffer, 0, numel(buffer));
end

hashBytes = uint8(mod(double(algorithm.digest()), 256));
hashText = string(reshape(dec2hex(hashBytes, 2).', 1, []));

end
