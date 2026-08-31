function [targetPathSummary, coverageResults] = helperBuildBistaticTargetPathSummary(stationSummary)
%helperBuildBistaticTargetPathSummary Rebuild the bistatic target-path estimate.
%
% Plain-language concept:
% The cleaned precheck needs deterministic target-path numbers and matching
% figure-ready map data. This wrapper keeps the established helper name while
% delegating the actual Longley-Rice rerun to a dedicated coverage-data
% builder that returns named analysis bundles. The baseline table remains the
% recovered-ROI branch so existing consumers still have a single reference
% summary, while the full multi-ROI result is available as the second output.

coverageResults = helperBuildDeterministicCoverageData(stationSummary);
targetPathSummary = coverageResults.ByName.RecoveredRoi.TargetPathSummary;
end
