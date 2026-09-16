function capture = helperReadPassiveRadarCapture(filePath, sliceDurationS)
%HELPERREADPASSIVERADARCAPTURE Strictly read a dual-channel baseband capture.
%
% A hardware precheck must not reinterpret a malformed MATLAB baseband file
% as another binary format. This reader therefore has no raw-data fallback:
% header or payload errors are surfaced with a stable error identifier.

arguments
    filePath (1, 1) string {mustBeNonzeroLengthText}
    sliceDurationS (1, 1) double {mustBePositive} = inf
end

if ~isfile(filePath)
    error("helperReadPassiveRadarCapture:fileNotFound", ...
        "Capture file not found: %s", filePath);
end

try
    headerReader = comm.BasebandFileReader(char(filePath), SamplesPerFrame=1);
    readerCleanup = onCleanup(@() release(headerReader));
    headerInfo = info(headerReader);
    sampleRateHz = double(headerReader.SampleRate);
    centerFrequencyHz = double(headerReader.CenterFrequency);
    numberOfChannels = double(headerReader.NumChannels);
    metadata = headerReader.Metadata;
    clear readerCleanup
catch exception
    error("helperReadPassiveRadarCapture:invalidBasebandFile", ...
        "Could not read the baseband header for %s: %s", ...
        filePath, exception.message);
end

availableSamples = double(headerInfo.NumSamplesInData);
if availableSamples < 1
    error("helperReadPassiveRadarCapture:emptyCapture", ...
        "Capture file contains no samples: %s", filePath);
end

if isfinite(sliceDurationS)
    requestedSamples = max(1, round(sliceDurationS * sampleRateHz));
else
    requestedSamples = availableSamples;
end
samplesToRead = min(availableSamples, requestedSamples);

try
    payloadReader = comm.BasebandFileReader( ...
        char(filePath), SamplesPerFrame=samplesToRead);
    readerCleanup = onCleanup(@() release(payloadReader));
    samples = payloadReader();
    clear readerCleanup
catch exception
    error("helperReadPassiveRadarCapture:payloadReadFailed", ...
        "Could not read %d samples from %s: %s", ...
        samplesToRead, filePath, exception.message);
end

capture = struct( ...
    "File", filePath, ...
    "Samples", samples, ...
    "SampleClass", string(class(samples)), ...
    "SampleRateHz", sampleRateHz, ...
    "CenterFrequencyHz", centerFrequencyHz, ...
    "NumberOfChannels", numberOfChannels, ...
    "AvailableSamples", availableSamples, ...
    "SamplesRead", size(samples, 1), ...
    "Metadata", metadata);
end
