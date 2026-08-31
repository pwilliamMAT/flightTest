function helperExportTextFigure(titleText, textLines, outputPath)
%helperExportTextFigure Render preformatted text as a reproducible figure asset.

if ischar(textLines)
    textLines = string({textLines});
elseif iscell(textLines)
    textLines = string(textLines);
else
    textLines = string(textLines);
end

figureHandle = figure( ...
    "Visible", "off", ...
    "Color", "w", ...
    "Position", [100 100 1400 900]);
axesHandle = axes(figureHandle, "Position", [0.03 0.03 0.94 0.94]);

xlim(axesHandle, [0 1]);
ylim(axesHandle, [0 1]);
axis(axesHandle, "off");
xlabel(axesHandle, "Text figure");
ylabel(axesHandle, "Text figure");
title(axesHandle, titleText, "FontSize", 16, "FontWeight", "bold");

text( ...
    axesHandle, ...
    0.01, 0.96, ...
    textLines, ...
    "Units", "normalized", ...
    "VerticalAlignment", "top", ...
    "FontName", "Courier New", ...
    "FontSize", 10, ...
    "Interpreter", "none");

exportgraphics(figureHandle, outputPath, "Resolution", 300);
close(figureHandle);
end
