function reward = pointReward(state, control, positionReference, velocityReference, cfg, adjacency)
%POINTREWARD Evaluate the matched scalar team reward for a point state.

arguments
    state (2,:) double
    control (1,:) double
    positionReference (1,1) double
    velocityReference (1,1) double
    cfg (1,1) struct
    adjacency double
end

[reward, ~] = rrjfi.robustRewardBounds( ...
    state, state, control, positionReference, velocityReference, cfg, adjacency);
end

