function helperGenerateSystemPrecheckDeck(deckPath, slideSpecs)
%helperGenerateSystemPrecheckDeck Build a simple reproducible PPTX from generated images.

import mlreportgen.ppt.*

presentation = Presentation(deckPath);
open(presentation);

titleSlide = add(presentation, "Title Slide");
replace(titleSlide, "Title", "System Precheck Review");
replace(titleSlide, "Subtitle", "Generated from MATLAB assets on " + string(datetime("now", "Format", "yyyy-MM-dd HH:mm")));

for slideIndex = 1:numel(slideSpecs)
    contentSlide = add(presentation, "Title and Content");
    replace(contentSlide, "Title", slideSpecs(slideIndex).Title);
    replace(contentSlide, "Content", Picture(slideSpecs(slideIndex).ImagePath));
end

close(presentation);
end
