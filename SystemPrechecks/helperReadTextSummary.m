function summaryText = helperReadTextSummary(textPath)
%helperReadTextSummary Read a generated text summary as a single display block.

arguments
    textPath (1, 1) string
end

if ~isfile(textPath)
    error("helperReadTextSummary:MissingFile", "Text summary not found: %s", textPath);
end

try
    summaryText = string(fileread(textPath));
catch readException
    error( ...
        "helperReadTextSummary:ReadFailed", ...
        "Could not read text summary %s: %s", ...
        textPath, ...
        readException.message);
end
end
