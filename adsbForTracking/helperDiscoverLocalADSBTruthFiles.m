function sourceFiles = helperDiscoverLocalADSBTruthFiles(searchRoot)
%HELPERDISCOVERLOCALADSBTRUTHFILES Find local SBS-1 ADS-B truth logs.
% Stage 2B should use packaged local truth files, especially capture-session
% truth folders, and should not inspect unrelated NMEA logger outputs.

searchRoot = string(searchRoot);

if strlength(searchRoot) == 0 || ~isfolder(searchRoot)
    sourceFiles = strings(0, 1);
    return;
end

candidateInfo = dir(fullfile(searchRoot, "**", "*adsb*.txt*"));

if isempty(candidateInfo)
    sourceFiles = strings(0, 1);
    return;
end

candidatePaths = strings(numel(candidateInfo), 1);

for fileIdx = 1:numel(candidateInfo)
    candidatePaths(fileIdx) = string(fullfile(candidateInfo(fileIdx).folder, candidateInfo(fileIdx).name));
end

lowerPaths = lower(candidatePaths);
isTextOrGzip = endsWith(lowerPaths, ".txt") | endsWith(lowerPaths, ".txt.gz");
isTruthFolder = contains(lowerPaths, filesep + "truth" + filesep);
sourceFiles = candidatePaths(isTextOrGzip & isTruthFolder);
sourceFiles = unique(sourceFiles(:), "stable");

end
