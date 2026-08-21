function observation = buildObservation( ...
    lowerState, upperState, retainedDelays, positionReference, velocityReference, cfg, adjacency)
%BUILDOBSERVATION Construct normalized decentralized interval observations.

arguments
    lowerState (2,:) double
    upperState (2,:) double
    retainedDelays logical
    positionReference (1,1) double
    velocityReference (1,1) double
    cfg (1,1) struct
    adjacency double
end

numAgents = size(lowerState, 2);
midpoint = 0.5 .* (lowerState + upperState);
width = upperState - lowerState;
maximumDelay = max(cfg.sim.delayValues);
observation = zeros(10, numAgents);

for agent = 1:numAgents
    delayValues = cfg.sim.delayValues(retainedDelays(agent, :));
    if isempty(delayValues)
        delayMidpoint = maximumDelay / 2;
        delayWidth = maximumDelay;
    else
        delayMidpoint = 0.5 * (min(delayValues) + max(delayValues));
        delayWidth = max(delayValues) - min(delayValues);
    end

    degree = max(sum(adjacency(agent, :) > 0), 1);
    relativePosition = sum(adjacency(agent, :) .* (midpoint(1, :) - midpoint(1, agent))) / degree;
    positionMargin = cfg.control.safetyPosition ...
        - max(abs([lowerState(1, agent), upperState(1, agent)]));
    velocityMargin = cfg.control.safetyVelocity ...
        - max(abs([lowerState(2, agent), upperState(2, agent)]));
    normalizedMargin = min(positionMargin / cfg.control.safetyPosition, ...
        velocityMargin / cfg.control.safetyVelocity);

    observation(:, agent) = [ ...
        midpoint(1, agent) / cfg.control.safetyPosition; ...
        midpoint(2, agent) / cfg.control.safetyVelocity; ...
        width(1, agent) / cfg.control.recoveryWidthLimit(1); ...
        width(2, agent) / cfg.control.recoveryWidthLimit(2); ...
        delayMidpoint / max(maximumDelay, 1); ...
        delayWidth / max(maximumDelay, 1); ...
        (midpoint(1, agent) - positionReference) / cfg.control.safetyPosition; ...
        (midpoint(2, agent) - velocityReference) / cfg.control.safetyVelocity; ...
        relativePosition / cfg.control.safetyPosition; ...
        normalizedMargin];
end
end

