function helperDisplayArtifactImage(imagePath, titleText)
%helperDisplayArtifactImage Display a generated PNG artifact inline.

arguments
    imagePath (1, 1) string
    titleText (1, 1) string = ""
end

if ~isfile(imagePath)
    error("helperDisplayArtifactImage:MissingFile", "Artifact image not found: %s", imagePath);
end

try
    imageData = imread(imagePath);
catch readException
    error( ...
        "helperDisplayArtifactImage:ReadFailed", ...
        "Could not read artifact image %s: %s", ...
        imagePath, ...
        readException.message);
end

image(imageData);
axis image
set(gca, "YDir", "reverse");
xlabel("Pixel column");
ylabel("Pixel row");

if titleText == ""
    [~, imageName, imageExt] = fileparts(imagePath);
    title(imageName + imageExt);
else
    title(titleText);
end
end
