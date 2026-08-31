function tableData = helperReadArtifactTable(tablePath)
%helperReadArtifactTable Read a generated CSV artifact with string text columns.

arguments
    tablePath (1, 1) string
end

if ~isfile(tablePath)
    error("helperReadArtifactTable:MissingFile", "Artifact table not found: %s", tablePath);
end

try
    tableData = readtable(tablePath, TextType="string");
catch readException
    error( ...
        "helperReadArtifactTable:ReadFailed", ...
        "Could not read artifact table %s: %s", ...
        tablePath, ...
        readException.message);
end
end
