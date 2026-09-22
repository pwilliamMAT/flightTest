function result = verifyTechnicalSummaryFamily(releaseRoot)
% verifyTechnicalSummaryFamily Validate a staged or promoted family release.
%
% This verifier reads the reports, metadata, assets, and immutable source
% baselines. It writes audit records only in the release validation folder.

arguments
    releaseRoot (1,1) string
end

releaseRoot = string(char(releaseRoot));
expected = localExpectedReports();
validationRoot = fullfile(releaseRoot,"validation");
metadataRoot = fullfile(releaseRoot,"metadata");
reportsRoot = fullfile(releaseRoot,"reports");

checks = localEmptyChecks();
linkAudit = localEmptyLinkAudit();
hashAudit = localEmptyHashAudit();
continuityAudit = localEmptyContinuityAudit();
fileInventory = localEmptyFileInventory();
manifest = struct();

if ~isfolder(validationRoot)
    error("TechnicalSummaryFamily:MissingValidationFolder", ...
        "Release validation folder is unavailable: %s",validationRoot);
end

try
    [checks,manifest] = localVerifyReleaseInterface( ...
        releaseRoot,metadataRoot,reportsRoot,expected,checks);
    [checks,hashAudit] = localVerifyHashes(manifest,expected,reportsRoot,checks,hashAudit);
    [checks,fileInventory] = localVerifyReportIdentity( ...
        releaseRoot,reportsRoot,expected,checks,fileInventory);
    [checks,continuityAudit] = localVerifyContinuity( ...
        metadataRoot,reportsRoot,expected,checks,continuityAudit);
    [checks,linkAudit] = localVerifyReportsAndLinks( ...
        releaseRoot,reportsRoot,expected,checks,linkAudit);
    [checks,linkAudit] = localVerifyIndexLinks( ...
        releaseRoot,checks,linkAudit);
    [checks] = localVerifyContentGates(metadataRoot,expected,checks);
catch exception
    checks = localAddCheck(checks,"Verifier execution",false,"P0", ...
        string(getReport(exception,"extended","hyperlinks","off")));
end

failedChecks = checks(~[checks.Passed]);
hasKnownGaps = isfile(fullfile(metadataRoot,"family_known_gaps.md"));
if isempty(failedChecks)
    if hasKnownGaps
        finalStatus = "PASSED WITH ACCEPTED KNOWN GAPS";
    else
        finalStatus = "PASSED";
    end
else
    finalStatus = "FAILED";
end

localWriteValidationOutputs(validationRoot,releaseRoot,manifest,expected, ...
    finalStatus,checks,linkAudit,hashAudit,continuityAudit,fileInventory);

result = struct();
result.Passed = isempty(failedChecks);
result.Status = finalStatus;
result.ReleaseRoot = releaseRoot;
result.ReportCount = numel(expected);
result.FailedCheckCount = numel(failedChecks);
result.FailedChecks = failedChecks;
result.ValidationRoot = validationRoot;
end

function expected = localExpectedReports()
expected = struct( ...
    "Id",{"01","01A","01B","02","02A","03","04","05","06"}, ...
    "Filename",{ ...
        "01_NorthStarAndMotivation_V2.html", ...
        "01A_IlluminatorSelection_V4.html", ...
        "01B_ReceiveChainDesign_V2.html", ...
        "02_HardwareAndCollection_V4.html", ...
        "02A_SyntheticEchoGeneration_V1.html", ...
        "03_AnalysisPipelineAndGateRebuild.html", ...
        "04_MitigationAndMapRateRecovery_V2.html", ...
        "05_StrongestEvidence_G4RRecoveryStudy.html", ...
        "06_StatusAndFutureWork_V2.html"});
end

function [checks,manifest] = localVerifyReleaseInterface(releaseRoot,metadataRoot,reportsRoot,expected,checks)
requiredFolders = [releaseRoot,reportsRoot,fullfile(releaseRoot,"assets"), ...
    fullfile(releaseRoot,"companions"),metadataRoot,fullfile(releaseRoot,"validation")];
for index = 1:numel(requiredFolders)
    checks = localAddCheck(checks,"Required release folder",isfolder(requiredFolders(index)), ...
        "P0",requiredFolders(index));
end

requiredFiles = [ ...
    fullfile(releaseRoot,"index.html"); ...
    fullfile(releaseRoot,"README.md"); ...
    fullfile(metadataRoot,"family_manifest.json"); ...
    fullfile(metadataRoot,"family_evidence_catalog.csv"); ...
    fullfile(metadataRoot,"family_handoff_catalog.csv"); ...
    fullfile(metadataRoot,"family_visual_catalog.csv"); ...
    fullfile(metadataRoot,"family_code_navigation.csv"); ...
    fullfile(metadataRoot,"family_known_gaps.md"); ...
    fullfile(metadataRoot,"report_family_gap_review.md"); ...
    fullfile(metadataRoot,"report_family_gap_matrix.csv"); ...
    fullfile(metadataRoot,"report_family_duplication_review.csv"); ...
    fullfile(metadataRoot,"report_family_story_spine.html"); ...
    fullfile(metadataRoot,"report_family_gap_review_audit.md"); ...
    fullfile(metadataRoot,"content_stabilization_log.csv"); ...
    fullfile(metadataRoot,"source_integrity_baseline.csv")];
for index = 1:numel(requiredFiles)
    checks = localAddCheck(checks,"Required release interface",isfile(requiredFiles(index)), ...
        "P0",requiredFiles(index));
end

manifestPath = fullfile(metadataRoot,"family_manifest.json");
manifest = struct();
if ~isfile(manifestPath)
    checks = localAddCheck(checks,"Manifest parse",false,"P0", ...
        "family_manifest.json is unavailable.");
    return;
end

manifest = jsondecode(fileread(manifestPath));
requiredFields = ["schema_version","release_id","release_timestamp","source_root", ...
    "canonical_order","reports","content_audit_status","known_gaps"];
for index = 1:numel(requiredFields)
    checks = localAddCheck(checks,"Manifest field",isfield(manifest,requiredFields(index)), ...
        "P0",requiredFields(index));
end

if isfield(manifest,"canonical_order")
    actualOrder = string(manifest.canonical_order);
    checks = localAddCheck(checks,"Canonical order", ...
        isequal(actualOrder(:),string({expected.Id})'),"P0", ...
        strjoin(actualOrder," → "));
end
end

function [checks,hashAudit] = localVerifyHashes(manifest,expected,reportsRoot,checks,hashAudit)
if ~isfield(manifest,"reports") || ~isfield(manifest,"source_root")
    checks = localAddCheck(checks,"Source immutability baseline",false,"P0", ...
        "Manifest does not contain report/source-root records.");
    return;
end

manifestReports = manifest.reports;
checks = localAddCheck(checks,"Manifest report count", ...
    numel(manifestReports) == numel(expected),"P0", ...
    "Expected nine canonical report records.");
for index = 1:min(numel(manifestReports),numel(expected))
    report = manifestReports(index);
    expectedFile = string(expected(index).Filename);
    canonicalName = localFieldText(report,"canonical_filename");
    acceptedName = localFieldText(report,"accepted_version");
    reportId = localFieldText(report,"report_id");
    checks = localAddCheck(checks,"Accepted report mapping", ...
        reportId == expected(index).Id && canonicalName == expectedFile && ...
        acceptedName == expectedFile,"P0",reportId + " → " + canonicalName);

    sourcePath = string(fullfile(string(manifest.source_root),expectedFile));
    expectedSourceHash = localFieldText(report,"source_hash");
    actualSourceHash = "";
    sourcePassed = false;
    if isfile(sourcePath)
        actualSourceHash = localSha256(sourcePath);
        sourcePassed = actualSourceHash == expectedSourceHash;
    end
    hashAudit(end+1,:) = { ...
        "Source report",expectedFile,sourcePath,expectedSourceHash,actualSourceHash, ...
        localPassFail(sourcePassed)}; %#ok<AGROW>
    checks = localAddCheck(checks,"Source report immutability",sourcePassed, ...
        "P0",expectedFile);

    releasePath = fullfile(reportsRoot,expectedFile);
    expectedReleaseHash = localFieldText(report,"release_hash");
    actualReleaseHash = "";
    releasePassed = false;
    if isfile(releasePath)
        actualReleaseHash = localSha256(releasePath);
        releasePassed = actualReleaseHash == expectedReleaseHash;
    end
    hashAudit(end+1,:) = { ...
        "Release report",expectedFile,releasePath,expectedReleaseHash,actualReleaseHash, ...
        localPassFail(releasePassed)}; %#ok<AGROW>
    checks = localAddCheck(checks,"Release report identity",releasePassed, ...
        "P0",expectedFile);
end

[checks,hashAudit] = localVerifySourceHashRecords( ...
    manifest,"source_asset_hashes","Source asset",checks,hashAudit);
[checks,hashAudit] = localVerifySourceHashRecords( ...
    manifest,"source_powerpoint_hashes","Source PowerPoint",checks,hashAudit);
end

function [checks,hashAudit] = localVerifySourceHashRecords(manifest,fieldName,kind,checks,hashAudit)
if ~isfield(manifest,fieldName)
    checks = localAddCheck(checks,kind + " baseline",false,"P0", ...
        "Missing " + fieldName + " in manifest.");
    return;
end

records = manifest.(fieldName);
for index = 1:numel(records)
    record = records(index);
    path = localFieldText(record,"SourcePath");
    expectedHash = localFieldText(record,"SourceSHA256");
    relativePath = localFieldText(record,"RelativePath");
    actualHash = "";
    passed = false;
    if isfile(path)
        actualHash = localSha256(path);
        passed = actualHash == expectedHash;
    end
    hashAudit(end+1,:) = {kind,relativePath,path,expectedHash,actualHash, ...
        localPassFail(passed)}; %#ok<AGROW>
    checks = localAddCheck(checks,kind + " immutability",passed,"P0",relativePath);
end
end

function [checks,fileInventory] = localVerifyReportIdentity(releaseRoot,reportsRoot,expected,checks,fileInventory)
listing = dir(fullfile(reportsRoot,"*.html"));
names = string({listing.name})';
expectedNames = string({expected.Filename})';
checks = localAddCheck(checks,"Canonical report count",numel(names) == 9,"P0", ...
    "Found " + string(numel(names)) + " HTML report copies.");
checks = localAddCheck(checks,"Canonical report filenames", ...
    isequal(sort(names),sort(expectedNames)),"P0",strjoin(names,", "));
checks = localAddCheck(checks,"Unique report IDs", ...
    numel(unique(string({expected.Id}))) == 9,"P0","Nine unique IDs.");

allFiles = dir(fullfile(releaseRoot,"**","*"));
for index = 1:numel(allFiles)
    if allFiles(index).isdir
        continue;
    end
    fullPath = string(fullfile(allFiles(index).folder,allFiles(index).name));
    relativePath = extractAfter(fullPath,releaseRoot + filesep);
    fileInventory(end+1,:) = {relativePath,string(allFiles(index).bytes), ...
        string(allFiles(index).datenum),localFileCategory(relativePath)}; %#ok<AGROW>
end
end

function [checks,continuityAudit] = localVerifyContinuity(metadataRoot,reportsRoot,expected,checks,continuityAudit)
path = fullfile(metadataRoot,"family_handoff_catalog.csv");
if ~isfile(path)
    checks = localAddCheck(checks,"Handoff catalog",false,"P0","Catalog unavailable.");
    return;
end

handoffs = localReadStringTable(path);
required = ["HandoffID","FromReport","ToReport","ArtifactOrOutputProduced", ...
    "InputConsumedDownstream","HandoffStatus"];
hasColumns = all(ismember(required,string(handoffs.Properties.VariableNames)));
checks = localAddCheck(checks,"Handoff catalog columns",hasColumns,"P0", ...
    strjoin(string(handoffs.Properties.VariableNames),", "));
if ~hasColumns
    return;
end

checks = localAddCheck(checks,"Eight canonical handoffs",height(handoffs) == 8, ...
    "P0","Found " + string(height(handoffs)) + " handoff records.");
for index = 1:min(height(handoffs),8)
    expectedFrom = expected(index).Id;
    expectedTo = expected(index+1).Id;
    outputPresent = strlength(strtrim(handoffs.ArtifactOrOutputProduced(index))) > 0;
    inputPresent = strlength(strtrim(handoffs.InputConsumedDownstream(index))) > 0;
    sequencePassed = handoffs.FromReport(index) == expectedFrom && ...
        handoffs.ToReport(index) == expectedTo;
    continuityAudit(end+1,:) = {handoffs.HandoffID(index),handoffs.FromReport(index), ...
        handoffs.ToReport(index),outputPresent,inputPresent, ...
        localPassFail(sequencePassed && outputPresent && inputPresent), ...
        handoffs.HandoffStatus(index)}; %#ok<AGROW>
    checks = localAddCheck(checks,"Documented report handoff", ...
        sequencePassed && outputPresent && inputPresent,"P0", ...
        expectedFrom + " → " + expectedTo);
end

for index = 1:numel(expected)
    reportPath = fullfile(reportsRoot,expected(index).Filename);
    if ~isfile(reportPath)
        continue;
    end
    content = string(fileread(reportPath));
    if index > 1
        checks = localAddCheck(checks,"Previous handoff navigation", ...
            contains(content,"href=""" + expected(index-1).Filename + """"), ...
            "P0",expected(index).Id);
    end
    if index < numel(expected)
        checks = localAddCheck(checks,"Next handoff navigation", ...
            contains(content,"href=""" + expected(index+1).Filename + """"), ...
            "P0",expected(index).Id);
    end
end
end

function [checks,linkAudit] = localVerifyReportsAndLinks(releaseRoot,reportsRoot,expected,checks,linkAudit)
for index = 1:numel(expected)
    report = expected(index);
    reportPath = fullfile(reportsRoot,report.Filename);
    if ~isfile(reportPath)
        continue;
    end
    content = string(fileread(reportPath));
    checks = localAddCheck(checks,"Report HTML body", ...
        ~isempty(regexp(content,'(?i)<body[^>]*>','once')),"P0",report.Filename);
    checks = localAddCheck(checks,"Single release navigation", ...
        numel(regexp(content,"data-tsf-release-navigation","match")) == 1, ...
        "P0",report.Filename);
    checks = localAddCheck(checks,"Namespaced navigation", ...
        contains(content,"id=""tsf-navigation-" + report.Id + """") && ...
        contains(content,".tsf-nav"),"P0",report.Filename);
    checks = localAddCheck(checks,"Responsive navigation", ...
        contains(content,"flex-wrap:wrap") && ...
        contains(content,"tsf-nav__question") && ...
        contains(content,"overflow-wrap:anywhere"),"P1",report.Filename);
    checks = localAddCheck(checks,"Source report link", ...
        contains(content,"Unchanged source report"),"P0",report.Filename);
    checks = localAddCheck(checks,"Claim boundary", ...
        contains(content,"Scope boundary:"),"P0",report.Filename);
    checks = localAddCheck(checks,"Evidence citation layer", ...
        contains(lower(content),"source") || contains(lower(content),"evidence"), ...
        "P1",report.Filename);

    [attributes,links] = localExtractAttributes(content);
    for linkIndex = 1:numel(links)
        [dependencyClass,resolved,status,details] = localClassifyLink( ...
            links(linkIndex),attributes(linkIndex),reportPath,releaseRoot,expected);
        linkAudit(end+1,:) = {report.Filename,attributes(linkIndex),links(linkIndex), ...
            dependencyClass,resolved,status,details}; %#ok<AGROW>
        checks = localAddLinkCheck(checks,dependencyClass,status,report.Filename,links(linkIndex));
    end
end
end

function [checks,linkAudit] = localVerifyIndexLinks(releaseRoot,checks,linkAudit)
indexPath = fullfile(releaseRoot,"index.html");
if ~isfile(indexPath)
    return;
end
content = string(fileread(indexPath));
checks = localAddCheck(checks,"Index responsive layout", ...
    contains(content,"viewport") && contains(content,"@media"),"P1","index.html");
[attributes,links] = localExtractAttributes(content);
for index = 1:numel(links)
    [dependencyClass,resolved,status,details] = localClassifyLink( ...
        links(index),attributes(index),indexPath,releaseRoot,localExpectedReports());
    linkAudit(end+1,:) = {"index.html",attributes(index),links(index), ...
        dependencyClass,resolved,status,details}; %#ok<AGROW>
    checks = localAddLinkCheck(checks,dependencyClass,status,"index.html",links(index));
end
end

function checks = localAddLinkCheck(checks,dependencyClass,status,document,link)
if status ~= "Resolved"
    checks = localAddCheck(checks,"Dependency resolution",false,"P0", ...
        document + ": " + link + " [" + dependencyClass + "]");
elseif dependencyClass == "Obsolete dependency" || dependencyClass == "Missing dependency"
    checks = localAddCheck(checks,"Prohibited dependency",false,"P0", ...
        document + ": " + link);
end
end

function [dependencyClass,resolved,status,details] = localClassifyLink(link,attribute,documentPath,releaseRoot,expected)
link = string(link);
attribute = string(attribute);
dependencyClass = "Missing dependency";
resolved = "";
status = "Unresolved";
details = "";

if localIsObsoleteReference(link)
    dependencyClass = "Obsolete dependency";
    details = "Superseded report or temporary-work path.";
    return;
end

if startsWith(link,"http://") || startsWith(link,"https://")
    dependencyClass = "External web evidence";
    resolved = link;
    status = localPassFail(localValidExternalUri(link));
    if status == "PASSED"
        status = "Resolved";
    else
        status = "Unresolved";
    end
    details = "Syntax checked; network availability intentionally not required.";
    return;
end

if startsWith(link,"file:")
    dependencyClass = "Local workstation evidence";
    [fileTarget,~] = localSplitFragment(link);
    resolved = localFileUriToPath(fileTarget);
    if isfile(resolved) || isfolder(resolved)
        status = "Resolved";
        details = "Exists at verification time; nonportable by design.";
    else
        details = "Local workstation dependency was unavailable.";
    end
    return;
end

if startsWith(link,"data:") || startsWith(link,"mailto:") || startsWith(link,"javascript:")
    dependencyClass = "External web evidence";
    resolved = link;
    status = "Resolved";
    details = "Non-file URI retained without network validation.";
    return;
end

[relativeTarget,fragment] = localSplitFragment(link);
if strlength(relativeTarget) == 0
    resolved = documentPath;
else
    resolved = fullfile(fileparts(documentPath), ...
        string(urldecode(char(relativeTarget))));
end
resolved = localCanonicalPath(resolved);

if contains(replace(resolved,"\","/"),replace(fullfile(releaseRoot,"reports"),"\","/"))
    [~,name,extension] = fileparts(resolved);
    if ismember(string(name) + string(extension),string({expected.Filename}))
        dependencyClass = "Canonical report link";
    elseif endsWith(lower(resolved),".html")
        dependencyClass = "Obsolete dependency";
    else
        dependencyClass = "Bundled companion artifact";
    end
elseif startsWith(localNormalizedPath(resolved),localNormalizedPath(fullfile(releaseRoot,"assets")))
    dependencyClass = "Bundled release asset";
elseif startsWith(localNormalizedPath(resolved),localNormalizedPath(releaseRoot))
    dependencyClass = "Bundled companion artifact";
else
    dependencyClass = "Missing dependency";
end

if localNormalizedPath(resolved) == ...
        localNormalizedPath(fullfile(releaseRoot,"validation","release_validation.md"))
    status = "Resolved";
    details = "Generated by this verification transaction.";
    return;
end

if isfile(resolved) || isfolder(resolved)
    if strlength(fragment) > 0
        if isfile(resolved) && endsWith(lower(resolved),".html")
            if localFragmentExists(resolved,fragment)
                status = "Resolved";
                details = "Internal fragment resolved.";
            else
                status = "Unresolved";
                details = "Internal fragment is absent.";
            end
        else
            status = "Unresolved";
            details = "Fragment target is not an HTML file.";
        end
    else
        status = "Resolved";
        details = "Release-local dependency resolved.";
        if attribute == "src" && localIsRasterImage(resolved)
            [imagePassed,imageDetail] = localImageReadable(resolved);
            if ~imagePassed
                status = "Unresolved";
            end
            details = imageDetail;
        end
    end
else
    details = "Release-local target is unavailable.";
end
end

function checks = localVerifyContentGates(metadataRoot,expected,checks)
gapPath = fullfile(metadataRoot,"report_family_gap_matrix.csv");
if ~isfile(gapPath)
    checks = localAddCheck(checks,"Content gap matrix",false,"P0","Unavailable.");
    return;
end

gapMatrix = localReadStringTable(gapPath);
required = ["ReportID","CandidateFilename","LatestAvailableVersion","AcceptedVersion", ...
    "PrimaryQuestion","IntendedTopicOwnership","ActualTopicsCovered", ...
    "PatternClassification","ExecutiveAnswerQuality","ResultVisibility", ...
    "ImportantMetricsVisible","WhyItMattersQuality","EngineeringDecisionVisibility", ...
    "RemainingUncertaintyVisibility","OriginalEvidenceQuality","CodeDiscoverability", ...
    "PredecessorInputClarity","SuccessorHandoffClarity","ScopeOverlap", ...
    "MissingTechnicalEvidence","MissingVisual","SourceProvenanceGap", ...
    "ContradictionOrDiscrepancy","RecommendedDisposition","Priority","Confidence","Notes"];
hasColumns = all(ismember(required,string(gapMatrix.Properties.VariableNames)));
checks = localAddCheck(checks,"Gap matrix columns",hasColumns,"P0", ...
    strjoin(string(gapMatrix.Properties.VariableNames),", "));
checks = localAddCheck(checks,"Gap matrix report coverage", ...
    height(gapMatrix) == numel(expected),"P0","Expected nine report rows.");
if hasColumns
    blocked = gapMatrix.Priority == "P0" & ...
        gapMatrix.RecommendedDisposition == "Blocked from Canonical Release";
    checks = localAddCheck(checks,"No unresolved P0 blocker",~any(blocked),"P0", ...
        "Blocked P0 rows: " + string(sum(blocked)));
end

knownGaps = fullfile(metadataRoot,"family_known_gaps.md");
if isfile(knownGaps)
    content = string(fileread(knownGaps));
    checks = localAddCheck(checks,"Known gaps remain visible", ...
        contains(content,"Field channel-role") && ...
        contains(content,"Historical 01A/01B") && ...
        contains(content,"controlled synthetic evidence"),"P1", ...
        "Known-gap record is present.");
end
end

function localWriteValidationOutputs(validationRoot,releaseRoot,manifest,expected,finalStatus,checks,linkAudit,hashAudit,continuityAudit,fileInventory)
checkTable = localChecksTable(checks);
writetable(linkAudit,fullfile(validationRoot,"link_audit.csv"));
writetable(hashAudit,fullfile(validationRoot,"hash_audit.csv"));
writetable(linkAudit(:,{'Document','Attribute','Link','DependencyClass','ResolutionStatus','Details'}), ...
    fullfile(validationRoot,"dependency_audit.csv"));
writetable(continuityAudit,fullfile(validationRoot,"continuity_audit.csv"));
writetable(fileInventory,fullfile(validationRoot,"release_file_inventory.csv"));

releaseId = localFieldText(manifest,"release_id");
if strlength(releaseId) == 0
    releaseId = "UNAVAILABLE";
end
sourceVersions = string({expected.Filename});
linkClasses = unique(linkAudit.DependencyClass);
linkSummary = strings(0,1);
for index = 1:numel(linkClasses)
    linkSummary(end+1,1) = "- " + linkClasses(index) + ": " + ...
        string(sum(linkAudit.DependencyClass == linkClasses(index))); %#ok<AGROW>
end
unresolved = linkAudit(linkAudit.ResolutionStatus ~= "Resolved",:);
failed = checkTable(checkTable.Passed == "No",:);
knownGapSummary = "Known gaps are recorded in `../metadata/family_known_gaps.md`.";
text = "# Technical Summary Family Release Validation" + newline + newline + ...
    "Release ID: `" + releaseId + "`" + newline + ...
    "Release root: `" + releaseRoot + "`" + newline + newline + ...
    "## Source and accepted versions" + newline + newline + ...
    "- Canonical report count: " + string(numel(expected)) + newline + ...
    "- Accepted versions: " + strjoin(sourceVersions,", ") + newline + newline + ...
    "## Link counts by dependency class" + newline + newline + ...
    strjoin(linkSummary,newline) + newline + newline + ...
    "## Asset and source integrity" + newline + newline + ...
    "- Release files inventoried: " + string(height(fileInventory)) + newline + ...
    "- Source/release hashes audited: " + string(height(hashAudit)) + newline + newline + ...
    "## Continuity" + newline + newline + ...
    "- Documented canonical handoffs: " + string(height(continuityAudit)) + " of 8" + newline + newline + ...
    "## Unresolved items" + newline + newline + ...
    localMarkdownTable(unresolved(:,{'Document','Link','DependencyClass','ResolutionStatus','Details'})) + newline + newline + ...
    "## Failed checks" + newline + newline + ...
    localMarkdownTable(failed(:,{'Name','Severity','Details'})) + newline + newline + ...
    "## Known-gap summary" + newline + newline + knownGapSummary + newline + newline + ...
    "## Content-audit status" + newline + newline + ...
    localFieldText(manifest,"content_audit_status") + newline + newline + ...
    "## Packaging status" + newline + newline + finalStatus + newline + newline + ...
    "## Final result" + newline + newline + "**" + finalStatus + "**" + newline;
localWriteText(fullfile(validationRoot,"release_validation.md"),text);
end

function checks = localEmptyChecks()
checks = struct("Name",{}, "Passed",{}, "Severity",{}, "Details",{});
end

function checks = localAddCheck(checks,name,passed,severity,details)
checks(end+1) = struct( ...
    "Name",char(string(name)), ...
    "Passed",logical(passed), ...
    "Severity",char(string(severity)), ...
    "Details",char(string(details)));
end

function audit = localEmptyLinkAudit()
audit = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1), ...
    'VariableNames',{'Document','Attribute','Link','DependencyClass', ...
    'ResolvedPath','ResolutionStatus','Details'});
end

function audit = localEmptyHashAudit()
audit = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1), ...
    'VariableNames',{'RecordType','RelativePath','SourcePath','ExpectedSHA256', ...
    'ActualSHA256','Status'});
end

function audit = localEmptyContinuityAudit()
audit = table(strings(0,1),strings(0,1),strings(0,1),false(0,1), ...
    false(0,1),strings(0,1),strings(0,1), ...
    'VariableNames',{'HandoffID','FromReport','ToReport','OutputDocumented', ...
    'InputDocumented','Status','Notes'});
end

function inventory = localEmptyFileInventory()
inventory = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    'VariableNames',{'RelativePath','Bytes','ModifiedDatenum','Category'});
end

function tableData = localChecksTable(checks)
if isempty(checks)
    tableData = table(strings(0,1),strings(0,1),strings(0,1), ...
        'VariableNames',{'Name','Passed','Severity','Details'});
    return;
end
passedText = repmat("No",numel(checks),1);
passedText(logical([checks.Passed])') = "Yes";
tableData = table(string({checks.Name})',passedText, ...
    string({checks.Severity})',string({checks.Details})', ...
    'VariableNames',{'Name','Passed','Severity','Details'});
end

function [attributes,links] = localExtractAttributes(content)
tokens = regexp(char(content),'(?i)(href|src)\s*=\s*["'']([^"'']+)["'']','tokens');
attributes = strings(numel(tokens),1);
links = strings(numel(tokens),1);
for index = 1:numel(tokens)
    attributes(index) = string(tokens{index}{1});
    links(index) = string(tokens{index}{2});
end
end

function [target,fragment] = localSplitFragment(link)
parts = split(string(link),"#",2);
target = parts(1);
fragment = "";
if numel(parts) > 1
    fragment = parts(2);
end
end

function tf = localFragmentExists(path,fragment)
content = string(fileread(path));
fragment = lower(string(urldecode(char(fragment))));
normalizedContent = lower(content);
tf = contains(normalizedContent,"id=""" + fragment + """") || ...
    contains(normalizedContent,"id='" + fragment + "'") || ...
    contains(normalizedContent,"name=""" + fragment + """") || ...
    contains(normalizedContent,"name='" + fragment + "'");
end

function tf = localIsObsoleteReference(link)
lowerLink = lower(string(link));
obsolete = [ ...
    "_human_story_work","_pilot_work","_pilot_v2_work", ...
    "02_hardwareandcollection_v2.html","02_hardwareandcollection_v3.html", ...
    "01_northstarandmotivation.html","04_mitigationandmapraterecovery.html", ...
    "06_statusandfuturework.html","temporary extraction","_staging"];
tf = any(contains(lowerLink,obsolete));
end

function path = localFileUriToPath(uri)
path = erase(string(uri),"file:///");
path = replace(path,"/","\");
path = string(urldecode(char(path)));
end

function tf = localValidExternalUri(uri)
tf = ~isempty(regexp(uri,"^https?://[^\\s]+$","once"));
end

function path = localNormalizedPath(path)
path = lower(replace(string(path),"/","\"));
end

function path = localCanonicalPath(path)
try
    path = string(java.io.File(char(path)).getCanonicalPath());
catch
    path = string(path);
end
end

function tf = localIsRasterImage(path)
extension = lower(string(extractAfter(path,".")));
tf = ismember(extension,["png","jpg","jpeg","gif","tif","tiff","bmp"]);
end

function [passed,details] = localImageReadable(path)
try
    info = imfinfo(path);
    passed = ~isempty(info);
    details = "Raster image decoded.";
catch exception
    passed = false;
    details = "Raster decode failed: " + string(exception.message);
end
end

function category = localFileCategory(relativePath)
relativePath = string(relativePath);
if startsWith(relativePath,"reports\")
    category = "Canonical report";
elseif startsWith(relativePath,"assets\")
    category = "Bundled asset";
elseif startsWith(relativePath,"companions\")
    category = "Bundled companion";
elseif startsWith(relativePath,"metadata\")
    category = "Metadata";
elseif startsWith(relativePath,"validation\")
    category = "Validation";
else
    category = "Release interface";
end
end

function value = localFieldText(record,fieldName)
value = "";
if isstruct(record) && isfield(record,fieldName)
    value = string(record.(fieldName));
end
end

function tableData = localReadStringTable(path)
options = detectImportOptions(path,TextType="string");
options = setvartype(options,options.VariableNames,"string");
tableData = readtable(path,options);
end

function value = localPassFail(passed)
if passed
    value = "PASSED";
else
    value = "FAILED";
end
end

function hash = localSha256(path)
fileId = fopen(path,"r");
if fileId < 0
    error("TechnicalSummaryFamily:HashReadFailure","Cannot read %s",path);
end
cleanup = onCleanup(@()fclose(fileId)); %#ok<NASGU>
digest = java.security.MessageDigest.getInstance("SHA-256");
while true
    [bytes,count] = fread(fileId,1024 * 1024,"*int8");
    if count == 0
        break;
    end
    digest.update(bytes);
end
raw = typecast(digest.digest(),"uint8");
hash = string(lower(reshape(dec2hex(raw,2).',1,[])));
end

function markdown = localMarkdownTable(tableData)
variables = string(tableData.Properties.VariableNames);
markdown = "| " + strjoin(variables," | ") + " |" + newline;
markdown = markdown + "| " + strjoin(repmat("---",1,numel(variables))," | ") + " |" + newline;
for row = 1:height(tableData)
    values = strings(1,numel(variables));
    for column = 1:numel(variables)
        values(column) = replace(string(tableData{row,column}),"|","/");
    end
    markdown = markdown + "| " + strjoin(values," | ") + " |" + newline;
end
end

function localWriteText(path,text)
fileId = fopen(path,"w","n","UTF-8");
if fileId < 0
    error("TechnicalSummaryFamily:WriteFailure","Cannot write %s",path);
end
cleanup = onCleanup(@()fclose(fileId)); %#ok<NASGU>
fwrite(fileId,char(text),"char");
end
