function exportInfo = helperExportArchitectureDiagram(modelName, targetImagePath)
%HELPEREXPORTARCHITECTUREDIAGRAM Export a PNG snapshot of the architecture.
% System Composer diagrams do not behave like MATLAB figures, so the
% snapshot is taken through the Report Generator diagram reporter.

arguments
    modelName (1,1) string
    targetImagePath (1,1) string
end

exportInfo = struct( ...
    "exported", false, ...
    "status", "skipped", ...
    "image_path", targetImagePath, ...
    "message", "" ...
);

tempImagePath = "";

try
    reportHandle = slreportgen.report.Report(tempname, "html");
    diagramReporter = slreportgen.report.Diagram(modelName);
    diagramReporter.SnapshotFormat = "png";
    diagramReporter.Scaling = "zoom";
    diagramReporter.Zoom = "115%";

    tempImagePath = string(getSnapshotImage(diagramReporter, reportHandle));

    if isfile(targetImagePath)
        delete(targetImagePath);
    end

    copyfile(tempImagePath, targetImagePath);

    exportInfo.exported = true;
    exportInfo.status = "saved";
catch ME
    exportInfo.status = "error";
    exportInfo.message = string(ME.message);
end

if strlength(tempImagePath) > 0 && isfile(tempImagePath)
    try
        delete(tempImagePath);
    catch
    end
end
end
