function control = observerProbeAction(midpoint, positionReference, velocityReference, step, cfg, adjacency)
%OBSERVERPROBEACTION Apply bounded feedback plus a deterministic identifying probe.

arguments
    midpoint (2,:) double
    positionReference (1,1) double
    velocityReference (1,1) double
    step (1,1) double {mustBeInteger,mustBePositive}
    cfg (1,1) struct
    adjacency double
end

position = midpoint(1, :);
velocity = midpoint(2, :);
numAgents = size(midpoint, 2);
control = zeros(1, numAgents);

for agent = 1:numAgents
    relativePosition = sum(adjacency(agent, :) .* (position - position(agent)));
    phase = 0.71 * agent;
    probe = cfg.scenario.probePrimary * sin(0.17 * step + phase) ...
        + cfg.scenario.probeSecondary * sin(0.047 * step^1.08 + 2 * phase);
    control(agent) = -cfg.control.positionGain * (position(agent) - positionReference) ...
        - cfg.control.velocityGain * (velocity(agent) - velocityReference) ...
        + cfg.control.consensusGain * relativePosition + probe;
end
control = min(max(control, -cfg.control.inputLimit), cfg.control.inputLimit);
end
