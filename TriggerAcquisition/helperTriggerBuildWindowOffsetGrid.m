function offsets_s = helperTriggerBuildWindowOffsetGrid(bounds_s)
%HELPERTRIGGERBUILDWINDOWOFFSETGRID Build the candidate start-offset grid.
%
% Plain-language goal:
%   The Phase 1 scheduler only searches a bounded set of future start
%   offsets. This helper keeps that grid consistent across the live scorer
%   and the preview visualization.

lower_s = bounds_s(1);
upper_s = bounds_s(2);
if upper_s <= lower_s
    offsets_s = lower_s;
    return
end

offsets_s = unique([lower_s, lower_s:1:upper_s, upper_s]);

end
