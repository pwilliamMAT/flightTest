function helperPlotStageReviewLocalTracks(review, varargin)
%HELPERPLOTSTAGEREVIEWLOCALTRACKS Plot ADS-B tracks in local ENU.

parser = inputParser;
parser.FunctionName = mfilename;
addParameter(parser, "MaxTracks", 8);
parse(parser, varargin{:});

maxTracks = double(parser.Results.MaxTracks);
trackSummary = review.trackSummary;

if height(trackSummary) > maxTracks
    trackSummary = trackSummary(1:maxTracks, :);
end

figure("Name", "Stage Review Local ADS-B Tracks");
cla reset;
hold on;

legendText = strings(height(trackSummary), 1);

for trackIdx = 1:height(trackSummary)
    trackHex = string(trackSummary.hex(trackIdx));
    rowMask = string(review.pairReviewTable.hex) == trackHex;
    rows = find(rowMask);
    [~, sortIdx] = sort(review.pairReviewTable.timeUtcNext(rows));
    rows = rows(sortIdx);
    plot( ...
        review.dataset.nextState(rows, 1), ...
        review.dataset.nextState(rows, 3), ...
        "LineWidth", 1.2);
    legendText(trackIdx) = trackHex;
end

hold off;
grid on;
axis equal;
xlabel("East [m]");
ylabel("North [m]");
title("Local ADS-B Tracks In ENU Coordinates");
legend(legendText, "Location", "bestoutside");

end
