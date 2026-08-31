function helperWriteTextSummary(titleText, textLines, outputPath)
%helperWriteTextSummary Write a short bullet-style text summary to disk.

arguments
    titleText (1, 1) string
    textLines (:, 1) string
    outputPath (1, 1) string
end

separatorLine = string(repmat("=", 1, strlength(titleText)));
separatorLine = join(separatorLine, "");
formattedLines = [titleText; separatorLine; compose("- %s", textLines)];

try
    writelines(formattedLines, outputPath);
catch writeException
    error( ...
        "helperWriteTextSummary:WriteFailed", ...
        "Could not write text summary %s: %s", ...
        outputPath, ...
        writeException.message);
end
end
