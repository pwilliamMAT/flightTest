function outputFile = helperInflateGzipWithDotNet(gzipFile, outputFolder)
%HELPERINFLATEGZIPWITHDOTNET Inflate one gzip file using .NET GZipStream.
% This helper is intentionally narrow. Stage 3C calls it only after MATLAB
% gunzip fails, so the normal import path still uses the built-in function.

gzipFile = string(gzipFile);
outputFolder = string(outputFolder);

if strlength(gzipFile) == 0 || exist(gzipFile, "file") ~= 2
    error("GzipFallback:MissingFile", ...
        "Gzip file was not found: %s", gzipFile);
end

if strlength(outputFolder) == 0
    error("GzipFallback:MissingOutputFolder", ...
        "Output folder must not be empty.");
end

if ~ispc
    error("GzipFallback:WindowsOnly", ...
        "The .NET gzip fallback is only supported on Windows MATLAB.");
end

[~, gzipName, gzipExtension] = fileparts(gzipFile);

if strcmpi(gzipExtension, ".gz")
    outputName = string(gzipName);
else
    outputName = string(gzipName) + string(gzipExtension) + ".inflated";
end

outputFile = fullfile(outputFolder, outputName);

try
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    localLoadCompressionAssembly();

    inputStream = System.IO.File.OpenRead(char(gzipFile));
    inputCleanup = onCleanup(@() inputStream.Close());
    gzipStream = System.IO.Compression.GZipStream( ...
        inputStream, ...
        System.IO.Compression.CompressionMode.Decompress);
    gzipCleanup = onCleanup(@() gzipStream.Close());
    outputStream = System.IO.File.Create(char(outputFile));
    outputCleanup = onCleanup(@() outputStream.Close());

    gzipStream.CopyTo(outputStream);
    outputStream.Flush();

    clear outputCleanup
    clear gzipCleanup
    clear inputCleanup
catch err
    error("GzipFallback:InflateFailed", ...
        "Failed to inflate %s with .NET GZipStream: %s", gzipFile, err.message);
end

end

function localLoadCompressionAssembly()
%LOCALLOADCOMPRESSIONASSEMBLY Load compression assembly when needed.

try
    NET.addAssembly("System.IO.Compression");
catch
end

end
