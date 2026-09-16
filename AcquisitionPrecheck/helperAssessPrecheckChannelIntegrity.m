function result = helperAssessPrecheckChannelIntegrity(samples, expectedSamples, options)
%HELPERASSESSPRECHECKCHANNELINTEGRITY Validate a dual-channel IQ payload.
%
% The check answers whether both physical channels are present, finite,
% changing, distinct, and free of suspicious zero-filled runs. Signal
% quality is assessed later; this function only establishes that the
% capture itself is structurally trustworthy.

arguments
    samples {mustBeNumeric}
    expectedSamples (1, 1) double {mustBeNonnegative} = 1
    options.MaximumZeroFraction (1, 1) double ...
        {mustBeNonnegative, mustBeLessThanOrEqual(options.MaximumZeroFraction, 1)} = 1e-3
    options.MaximumZeroRunSamples (1, 1) double ...
        {mustBeNonnegative, mustBeInteger} = 64
end

nRows = size(samples, 1);
nChannels = size(samples, 2);
channelCountPass = nChannels == 2;
sampleCountPass = nRows >= expectedSamples;

finitePass = false(1, 2);
nonzeroPass = false(1, 2);
nonconstantPass = false(1, 2);
zeroContentPass = false(1, 2);
zeroFraction = nan(1, 2);
longestZeroRunSamples = nan(1, 2);
channelRMS = nan(1, 2);

channelsToInspect = min(nChannels, 2);
for channelIndex = 1:channelsToInspect
    channel = double(samples(:, channelIndex));
    finitePass(channelIndex) = all(isfinite(channel));
    zeroMask = channel == 0;
    zeroFraction(channelIndex) = mean(zeroMask);
    longestZeroRunSamples(channelIndex) = localLongestTrueRun(zeroMask);
    channelRMS(channelIndex) = sqrt(mean(abs(channel).^2));
    nonzeroPass(channelIndex) = channelRMS(channelIndex) > eps;
    nonconstantPass(channelIndex) = std(channel) > eps;
    zeroContentPass(channelIndex) = ...
        zeroFraction(channelIndex) <= options.MaximumZeroFraction && ...
        longestZeroRunSamples(channelIndex) <= options.MaximumZeroRunSamples;
end

duplicateNormalizedError = NaN;
duplicatePass = false;
if channelCountPass && all(finitePass)
    differenceRMS = sqrt(mean(abs(double(samples(:, 1)) - ...
        double(samples(:, 2))).^2));
    normalization = max(channelRMS);
    duplicateNormalizedError = differenceRMS / max(normalization, eps);
    duplicatePass = duplicateNormalizedError > 1e-6;
end

pass = channelCountPass && sampleCountPass && all(finitePass) && ...
    all(nonzeroPass) && all(nonconstantPass) && all(zeroContentPass) && ...
    duplicatePass;

failures = strings(0, 1);
if ~channelCountPass
    failures(end + 1) = sprintf( ...
        "Expected exactly two channels; found %d.", nChannels);
end
if ~sampleCountPass
    failures(end + 1) = sprintf( ...
        "Expected at least %d samples; found %d.", expectedSamples, nRows);
end
if channelCountPass && ~all(finitePass)
    failures(end + 1) = "At least one channel contains NaN or Inf samples.";
end
if channelCountPass && ~all(nonzeroPass)
    failures(end + 1) = "At least one channel is all zero.";
end
if channelCountPass && ~all(nonconstantPass)
    failures(end + 1) = "At least one channel is constant.";
end
if channelCountPass && ~all(zeroContentPass)
    failures(end + 1) = sprintf( ...
        "Zero-filled data exceed the %.3g fraction or %d-sample run limit.", ...
        options.MaximumZeroFraction, options.MaximumZeroRunSamples);
end
if channelCountPass && all(finitePass) && ~duplicatePass
    failures(end + 1) = "The two channels are numerically duplicated.";
end

result = struct( ...
    "Pass", pass, ...
    "ChannelCount", nChannels, ...
    "SampleCount", nRows, ...
    "ExpectedSamples", expectedSamples, ...
    "FinitePass", finitePass, ...
    "NonzeroPass", nonzeroPass, ...
    "NonconstantPass", nonconstantPass, ...
    "ZeroContentPass", zeroContentPass, ...
    "ZeroFraction", zeroFraction, ...
    "LongestZeroRunSamples", longestZeroRunSamples, ...
    "MaximumZeroFraction", options.MaximumZeroFraction, ...
    "MaximumZeroRunSamples", options.MaximumZeroRunSamples, ...
    "ChannelRMS", channelRMS, ...
    "DuplicateNormalizedError", duplicateNormalizedError, ...
    "DuplicatePass", duplicatePass, ...
    "Failures", failures);
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
