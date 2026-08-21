function [action, memory] = baselineAction( ...
    method, measurement, memory, positionReference, velocityReference, controlHistory, step, cfg, adjacency)
%BASELINEACTION Evaluate the nominal-delay Smith or observer-based PID baseline.

arguments
    method (1,1) string {mustBeMember(method,["smith","pid"])}
    measurement (2,:) double
    memory (1,1) struct
    positionReference (1,1) double
    velocityReference (1,1) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    cfg (1,1) struct
    adjacency double
end

numAgents = size(measurement, 2);
dt = cfg.sim.sampleTime;

switch method
    case "smith"
        position = measurement(1, :);
        velocity = measurement(2, :);
        nominalInputIndex = step - cfg.baseline.nominalDelay;
        if nominalInputIndex >= 1
            nominalInput = controlHistory(:, nominalInputIndex).';
        else
            nominalInput = zeros(1, numAgents);
        end
        predicted = zeros(size(measurement));
        sinGain = mean(cfg.model.sinGain);
        damping = mean(cfg.model.damping);
        inputGain = mean(cfg.model.inputGain);
        couplingGain = mean(cfg.model.couplingGain);
        for agent = 1:numAgents
            relativePosition = sum(adjacency(agent, :) .* (position - position(agent)));
            acceleration = sinGain * sin(position(agent)) - damping * velocity(agent) ...
                + inputGain * nominalInput(agent) + couplingGain * relativePosition;
            predictionHorizon = (cfg.baseline.nominalDelay + 1) * dt;
            predicted(1, agent) = position(agent) + predictionHorizon * velocity(agent) ...
                + 0.5 * predictionHorizon^2 * acceleration;
            predicted(2, agent) = velocity(agent) + predictionHorizon * acceleration;
        end
        action = -cfg.baseline.smithPositionGain .* (predicted(1, :) - positionReference) ...
            - cfg.baseline.smithVelocityGain .* (predicted(2, :) - velocityReference);

    case "pid"
        if ~isfield(memory, 'estimate')
            memory.estimate = measurement;
            memory.integral = zeros(1, numAgents);
        end
        blend = cfg.baseline.observerBlend;
        memory.estimate = blend .* memory.estimate + (1 - blend) .* measurement;
        error = memory.estimate(1, :) - positionReference;
        memory.integral = memory.integral + dt .* error;
        memory.integral = min(max(memory.integral, ...
            -cfg.baseline.integralLimit), cfg.baseline.integralLimit);
        action = -cfg.baseline.pidPositionGain .* error ...
            - cfg.baseline.pidVelocityGain .* (memory.estimate(2, :) - velocityReference) ...
            - cfg.baseline.pidIntegralGain .* memory.integral;
end

action = min(max(action, -cfg.control.inputLimit), cfg.control.inputLimit);
end

