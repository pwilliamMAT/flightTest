function generatedDeckPath = helperGenerateSystemPrecheckDeck(deckPath, slideSpecs)
%helperGenerateSystemPrecheckDeck Build a reproducible PPTX from the fixed slide spec.

import mlreportgen.ppt.*

generatedDeckPath = deckPath;

if isfile(deckPath)
    try
        delete(deckPath);
    catch deleteException
        warning( ...
            "helperGenerateSystemPrecheckDeck:DeleteFailed", ...
            "Could not replace the existing deck %s: %s. Falling back to a timestamped deck path.", ...
            deckPath, ...
            deleteException.message);
        generatedDeckPath = buildFallbackDeckPath(deckPath);
    end
end

presentation = Presentation(generatedDeckPath);

try
    open(presentation);
catch openException
    if strcmp(string(generatedDeckPath), string(deckPath))
        generatedDeckPath = buildFallbackDeckPath(deckPath);
        warning( ...
            "helperGenerateSystemPrecheckDeck:FallbackPath", ...
            "Could not open %s (%s). Writing the regenerated deck to %s instead.", ...
            deckPath, ...
            openException.message, ...
            generatedDeckPath);
        presentation = Presentation(generatedDeckPath);
        open(presentation);
    else
        rethrow(openException);
    end
end

titleSlide = add(presentation, "Title Slide");
replace(titleSlide, "Title", "System Precheck Review");
replace(titleSlide, "Subtitle", "Generated from MATLAB assets on " + string(datetime("now", "Format", "yyyy-MM-dd HH:mm")));

for slideIndex = 1:numel(slideSpecs)
    contentSlide = add(presentation, "Title and Content");
    replace(contentSlide, "Title", slideSpecs(slideIndex).Title);

    if strlength(string(slideSpecs(slideIndex).ImagePath)) > 0 && isfile(slideSpecs(slideIndex).ImagePath)
        replace(contentSlide, "Content", Picture(slideSpecs(slideIndex).ImagePath));
        continue
    end

    if strlength(string(slideSpecs(slideIndex).ImagePath)) > 0
        warning( ...
            "helperGenerateSystemPrecheckDeck:MissingImage", ...
            "Slide '%s' expected image '%s', but the file was not found. Falling back to text content.", ...
            slideSpecs(slideIndex).Title, ...
            slideSpecs(slideIndex).ImagePath);
    end

    bodyLines = string(slideSpecs(slideIndex).BodyLines);
    bodyText = strjoin(bodyLines, newline);
    replace(contentSlide, "Content", char(bodyText));
end

close(presentation);
end

function fallbackDeckPath = buildFallbackDeckPath(deckPath)
[folderPath, baseName, extension] = fileparts(deckPath);
timestampText = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
fallbackDeckPath = fullfile(folderPath, baseName + "_" + timestampText + extension);
end
