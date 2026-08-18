function access = helperFetchOpenSkyMetadata(url, label)
%HELPERFETCHOPENSKYMETADATA Return HTTP status and selected headers.
% webread is used for JSON sampling. This helper uses MATLAB's native HTTP
% message API because it exposes response headers needed for the go/no-go
% report.

access = struct();
access.label = string(label);
access.url = string(url);
access.reachable = false;
access.status = "ERROR";
access.statusCode = NaN;
access.contentType = "Not observed";
access.rateLimitHeaders = strings(0, 1);
access.headerNames = strings(0, 1);
access.headerValues = strings(0, 1);
access.bodySize = NaN;
access.errorIdentifier = "";
access.errorMessage = "";

fprintf("Connectivity check:\t%s\n", access.label);

try
    uri = matlab.net.URI(url);
    request = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET, [], []);
    response = request.send(uri);

    access.status = string(response.StatusCode);
    access.statusCode = str2double(access.status);
    access.reachable = access.statusCode >= 200 && access.statusCode < 400;

    header = response.Header;
    access.headerNames = strings(numel(header), 1);
    access.headerValues = strings(numel(header), 1);

    for headerIdx = 1:numel(header)
        access.headerNames(headerIdx) = string(header(headerIdx).Name);
        access.headerValues(headerIdx) = string(header(headerIdx).Value);
    end

    contentTypeIdx = strcmpi(access.headerNames, "Content-Type");

    if any(contentTypeIdx)
        access.contentType = strjoin(access.headerValues(contentTypeIdx), ", ");
    end

    rateLimitIdx = contains(lower(access.headerNames), "rate") | contains(lower(access.headerNames), "limit");

    if any(rateLimitIdx)
        rateNames = access.headerNames(rateLimitIdx);
        rateValues = access.headerValues(rateLimitIdx);
        access.rateLimitHeaders = rateNames + ": " + rateValues;
    end

    access.bodySize = helperBodySize(response.Body.Data);

    fprintf("Status:\t%s\n", access.status);
    fprintf("Content-Type:\t%s\n", access.contentType);

    if isempty(access.rateLimitHeaders)
        fprintf("Rate/limit headers:\tNone observed\n");
    else
        fprintf("Rate/limit headers:\t%s\n", strjoin(access.rateLimitHeaders, "; "));
    end
catch err
    access.errorIdentifier = string(err.identifier);
    access.errorMessage = string(err.message);

    fprintf("Connectivity check failed:\t%s\n", access.label);
    fprintf("Identifier:\t%s\n", access.errorIdentifier);
    fprintf("Message:\t%s\n", access.errorMessage);
end

end

function bodySize = helperBodySize(bodyData)
%HELPERBODYSIZE Estimate body size without forcing arbitrary struct/string conversion.

if ischar(bodyData)
    bodySize = strlength(string(bodyData));
elseif isstring(bodyData)
    bodySize = strlength(strjoin(bodyData, ""));
elseif isnumeric(bodyData) || islogical(bodyData)
    bodySize = numel(bodyData);
else
    bodySize = NaN;
end

end
