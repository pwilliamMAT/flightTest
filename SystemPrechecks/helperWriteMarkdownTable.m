function helperWriteMarkdownTable(tableData, outputPath, headingText)
%helperWriteMarkdownTable Write a MATLAB table to a simple Markdown table.

arguments
    tableData table
    outputPath (1, 1) string
    headingText (1, 1) string = ""
end

headerCells = string(tableData.Properties.VariableNames);
headerLine = "| " + strjoin(headerCells, " | ") + " |";
separatorLine = "| " + strjoin(repmat(":---", 1, width(tableData)), " | ") + " |";

bodyStrings = strings(height(tableData), width(tableData));

for columnIndex = 1:width(tableData)
    columnData = tableData.(columnIndex);
    if isnumeric(columnData)
        bodyStrings(:, columnIndex) = compose("%g", columnData);
    elseif islogical(columnData)
        bodyStrings(:, columnIndex) = string(columnData);
    else
        bodyStrings(:, columnIndex) = string(columnData);
    end
end

bodyStrings = replace(bodyStrings, newline, "<br>");

lines = strings(height(tableData) + 2, 1);
lines(1) = headerLine;
lines(2) = separatorLine;

for rowIndex = 1:height(tableData)
    lines(rowIndex + 2) = "| " + strjoin(bodyStrings(rowIndex, :), " | ") + " |";
end

if headingText ~= ""
    lines = [headingText; ""; lines];
end

writelines(lines, outputPath);
end
