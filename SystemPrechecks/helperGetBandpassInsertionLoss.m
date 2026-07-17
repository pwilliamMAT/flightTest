function insertionLoss_dB = helperGetBandpassInsertionLoss(frequencyHz, s2pPath)
%helperGetBandpassInsertionLoss Interpolate insertion loss from the Mini-Circuits S2P file.

arguments
    frequencyHz (1, 1) double {mustBePositive}
    s2pPath (1, 1) string = fullfile("RFBudget", "ZABP-587-S+_Plus25degC.s2p")
end

if ~isfile(s2pPath)
    projectRoot = fileparts(mfilename("fullpath"));
    s2pPath = fullfile(projectRoot, s2pPath);
end

networkData = sparameters(s2pPath);
s21 = squeeze(networkData.Parameters(2, 1, :));
s21Interpolated = interp1(networkData.Frequencies, s21, frequencyHz, "linear", "extrap");
insertionLoss_dB = -20 * log10(abs(s21Interpolated));
end
