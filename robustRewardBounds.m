function [lowerReward, upperReward] = robustRewardBounds( ...
    lowerState, upperState, control, positionReference, velocityReference, cfg, adjacency)
%ROBUSTREWARDBOUNDS Bound the one-step team reward over a state box.

arguments
    lowerState (2,:) double
    upperState (2,:) double
    control (1,:) double
    positionReference (1,1) double
    velocityReference (1,1) double
    cfg (1,1) struct
    adjacency double
end

[lowerPositionCost, upperPositionCost] = rrjfi.intervalSquare( ...
    lowerState(1, :) - positionReference, upperState(1, :) - positionReference);
[lowerVelocityCost, upperVelocityCost] = rrjfi.intervalSquare( ...
    lowerState(2, :) - velocityReference, upperState(2, :) - velocityReference);

lowerConsensusCost = 0;
upperConsensusCost = 0;
for agent = 1:size(lowerState, 2)
    for neighbor = (agent + 1):size(lowerState, 2)
        if adjacency(agent, neighbor) <= 0 && adjacency(neighbor, agent) <= 0
            continue
        end
        lowerDifference = lowerState(1, agent) - upperState(1, neighbor);
        upperDifference = upperState(1, agent) - lowerState(1, neighbor);
        [lowerSquare, upperSquare] = rrjfi.intervalSquare(lowerDifference, upperDifference);
        lowerConsensusCost = lowerConsensusCost + lowerSquare;
        upperConsensusCost = upperConsensusCost + upperSquare;
    end
end

widthPenalty = cfg.reward.widthWeight * sum((upperState - lowerState).^2, 'all');
inputCost = cfg.reward.inputWeight * sum(control.^2);
minimumCost = cfg.reward.positionWeight * sum(lowerPositionCost) ...
    + cfg.reward.velocityWeight * sum(lowerVelocityCost) ...
    + cfg.reward.consensusWeight * lowerConsensusCost + inputCost + widthPenalty;
maximumCost = cfg.reward.positionWeight * sum(upperPositionCost) ...
    + cfg.reward.velocityWeight * sum(upperVelocityCost) ...
    + cfg.reward.consensusWeight * upperConsensusCost + inputCost + widthPenalty;

isOutside = any(lowerState(1, :) < -cfg.control.safetyPosition ...
    | upperState(1, :) > cfg.control.safetyPosition ...
    | lowerState(2, :) < -cfg.control.safetyVelocity ...
    | upperState(2, :) > cfg.control.safetyVelocity);
if isOutside
    maximumCost = maximumCost + cfg.reward.safetyPenalty;
end

lowerReward = -maximumCost;
upperReward = -minimumCost;
end

