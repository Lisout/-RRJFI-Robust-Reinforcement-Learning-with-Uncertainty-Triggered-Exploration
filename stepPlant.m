function nextState = stepPlant(state, controlHistory, step, delay, parameters, disturbance, cfg, adjacency)
%STEPPLANT Advance the uncertain nonlinear delayed multi-agent plant.

arguments
    state (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    delay (:,1) double {mustBeInteger,mustBeNonnegative}
    parameters (1,1) struct
    disturbance (2,:) double
    cfg (1,1) struct
    adjacency double
end

numAgents = size(state, 2);
dt = cfg.sim.sampleTime;
position = state(1, :);
velocity = state(2, :);
delayedInput = zeros(1, numAgents);
for agent = 1:numAgents
    inputIndex = step - delay(agent);
    if inputIndex >= 1
        delayedInput(agent) = controlHistory(agent, inputIndex);
    end
end

degree = full(sum(adjacency, 2)).';
relativePosition = (adjacency * position.').' - degree .* position;
acceleration = parameters.sinGain .* sin(position) ...
    - parameters.damping .* velocity ...
    + parameters.inputGain .* delayedInput ...
    + parameters.couplingGain .* relativePosition;

nextState = zeros(size(state));
nextState(1, :) = position + dt .* velocity ...
    + 0.5 .* dt^2 .* acceleration + disturbance(1, :);
nextState(2, :) = velocity + dt .* acceleration + disturbance(2, :);
end
