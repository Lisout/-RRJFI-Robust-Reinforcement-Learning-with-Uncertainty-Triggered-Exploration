function [lowerSuccessor, upperSuccessor] = intervalSuccessor( ...
    lowerState, upperState, controlHistory, step, cfg, adjacency)
%INTERVALSUCCESSOR Hull all admissible one-step delay-mode predictions.

arguments
    lowerState (2,:) double
    upperState (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    cfg (1,1) struct
    adjacency double
end

numDelays = numel(cfg.sim.delayValues);
lowerBranches = zeros(2, size(lowerState, 2), numDelays);
upperBranches = zeros(size(lowerBranches));
for delayIndex = 1:numDelays
    delay = cfg.sim.delayValues(delayIndex);
    [lowerBranches(:, :, delayIndex), upperBranches(:, :, delayIndex)] = ...
        rrjfi.predictIntervalForDelay( ...
        lowerState, upperState, controlHistory, step, delay, cfg, adjacency);
end
lowerSuccessor = min(lowerBranches, [], 3);
upperSuccessor = max(upperBranches, [], 3);
end

