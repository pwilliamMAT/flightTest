function result = helperMeasureChannelHeadroom(samples, options)
%HELPERMEASURECHANNELHEADROOM Detect ADC rail contact and low headroom.
%
% Clipping occurs in the real and imaginary ADC components, not in complex
% magnitude. This helper therefore measures |I| and |Q| independently.
% The high-percentile metric distinguishes sustained near-rail operation
% from a single isolated peak, while ExactRailFraction preserves transient
% events such as the known August repetition-13 rail contact.

arguments
    samples {mustBeNumeric, mustBeNonempty}
    options.FullScale (1, 1) double = NaN
    options.Percentile (1, 1) double {mustBeGreaterThan(options.Percentile, 0), ...
        mustBeLessThanOrEqual(options.Percentile, 100)} = 99.99
    options.NearRailFraction (1, 1) double {mustBePositive, ...
        mustBeLessThanOrEqual(options.NearRailFraction, 1)} = 0.98
    options.MaximumNearRailFraction (1, 1) double {mustBeNonnegative} = 1e-5
    options.MinimumPeakHeadroomDB (1, 1) double {mustBeNonnegative} = 0.25
    options.MinimumPercentileHeadroomDB (1, 1) double {mustBeNonnegative} = 3
end

if ~(isnan(options.FullScale) || ...
        (isfinite(options.FullScale) && options.FullScale > 0))
    error("helperMeasureChannelHeadroom:invalidFullScale", ...
        "FullScale must be NaN for automatic detection or a positive scalar.");
end

[fullScale, positiveRail, negativeRail] = ...
    localResolveFullScale(samples, options.FullScale);
nChannels = size(samples, 2);
rmsDBFS = nan(1, nChannels);
peakDBFS = nan(1, nChannels);
peakHeadroomDB = nan(1, nChannels);
percentileDBFS = nan(1, nChannels);
percentileHeadroomDB = nan(1, nChannels);
exactRailFraction = nan(1, nChannels);
exactRailSampleCount = zeros(1, nChannels);
nearRailFraction = nan(1, nChannels);
longestRailRunSamples = zeros(1, nChannels);
channelPass = false(1, nChannels);

for channelIndex = 1:nChannels
    channel = double(samples(:, channelIndex));
    components = [abs(real(channel)); abs(imag(channel))];
    sortedComponents = sort(components);
    percentileIndex = max(1, ceil(options.Percentile / 100 * numel(sortedComponents)));

    peakComponent = max(components);
    percentileComponent = sortedComponents(percentileIndex);
    componentRMS = sqrt(mean(components.^2));

    rmsDBFS(channelIndex) = 20 * log10(max(componentRMS, eps) / fullScale);
    peakDBFS(channelIndex) = 20 * log10(max(peakComponent, eps) / fullScale);
    peakHeadroomDB(channelIndex) = -peakDBFS(channelIndex);
    percentileDBFS(channelIndex) = ...
        20 * log10(max(percentileComponent, eps) / fullScale);
    percentileHeadroomDB(channelIndex) = -percentileDBFS(channelIndex);

    exactRailMask = real(channel) >= positiveRail | ...
        real(channel) <= negativeRail | ...
        imag(channel) >= positiveRail | ...
        imag(channel) <= negativeRail;
    nearRailMask = abs(real(channel)) >= options.NearRailFraction * fullScale | ...
        abs(imag(channel)) >= options.NearRailFraction * fullScale;
    exactRailFraction(channelIndex) = mean(exactRailMask);
    exactRailSampleCount(channelIndex) = nnz(exactRailMask);
    nearRailFraction(channelIndex) = mean(nearRailMask);
    longestRailRunSamples(channelIndex) = localLongestTrueRun(exactRailMask);

    channelPass(channelIndex) = exactRailFraction(channelIndex) == 0 && ...
        nearRailFraction(channelIndex) <= options.MaximumNearRailFraction && ...
        peakHeadroomDB(channelIndex) >= options.MinimumPeakHeadroomDB && ...
        percentileHeadroomDB(channelIndex) >= options.MinimumPercentileHeadroomDB;
end

result = struct( ...
    "Pass", all(channelPass), ...
    "ChannelPass", channelPass, ...
    "FullScale", fullScale, ...
    "Percentile", options.Percentile, ...
    "NearRailThreshold", options.NearRailFraction * fullScale, ...
    "MaximumNearRailFraction", options.MaximumNearRailFraction, ...
    "MinimumPeakHeadroomDB", options.MinimumPeakHeadroomDB, ...
    "MinimumPercentileHeadroomDB", options.MinimumPercentileHeadroomDB, ...
    "RMSDBFS", rmsDBFS, ...
    "PeakDBFS", peakDBFS, ...
    "PeakHeadroomDB", peakHeadroomDB, ...
    "PercentileDBFS", percentileDBFS, ...
    "PercentileHeadroomDB", percentileHeadroomDB, ...
    "ExactRailSampleCount", exactRailSampleCount, ...
    "ExactRailFraction", exactRailFraction, ...
    "NearRailFraction", nearRailFraction, ...
    "LongestRailRunSamples", longestRailRunSamples);
end

function [fullScale, positiveRail, negativeRail] = ...
        localResolveFullScale(samples, requestedFullScale)
if isfinite(requestedFullScale) && requestedFullScale > 0
    fullScale = requestedFullScale;
    positiveRail = requestedFullScale;
    negativeRail = -requestedFullScale;
    return
end

if isinteger(samples)
    sampleClass = class(samples);
    positiveRail = double(intmax(sampleClass));
    integerMinimum = double(intmin(sampleClass));
    fullScale = max(abs([integerMinimum, positiveRail]));
    if integerMinimum < 0
        negativeRail = integerMinimum;
    else
        negativeRail = -Inf;
    end
else
    fullScale = 1;
    positiveRail = 1;
    negativeRail = -1;
end
end

function runLength = localLongestTrueRun(mask)
edges = diff([false; mask(:); false]);
runStarts = find(edges == 1);
runEnds = find(edges == -1) - 1;
if isempty(runStarts)
    runLength = 0;
else
    runLength = max(runEnds - runStarts + 1);
end
end
