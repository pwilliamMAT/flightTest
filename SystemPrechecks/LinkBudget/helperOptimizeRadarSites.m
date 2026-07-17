function bestind = helperOptimizeRadarSites(snr, snrmin,numradars)
%helperOptimizeRadarSites   Helper function for Planning Radar Network Coverage over Terrain

%   Copyright 2019 The MathWorks, Inc.

% Compute whether targets are detected
isdetected = snr > snrmin;

% Generate all possible combinations of three radar sites
%numradars = 3;
Cs = nchoosek(1:5,numradars);

% Select best combination of radar sites for maximizing number of
% detections
bestnumdetections = 0;
bestind = [];
for cind = 1:size(Cs,1)
    C = Cs(cind,:);
    
    % A target is detected if any of the radars detects it
    Cisdetected = any(isdetected(:,C),2);
    
    % Count total number of detections
    numdetections = numel(find(Cisdetected));
    
    if numdetections > bestnumdetections
        bestnumdetections = numdetections;
        bestind = C;
    end
end
end