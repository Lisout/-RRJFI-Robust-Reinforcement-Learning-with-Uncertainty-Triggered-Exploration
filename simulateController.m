function result = simulateController(cfg, method, policy, seed, task)
%SIMULATECONTROLLER Evaluate one controller on a fixed uncertain scenario.

arguments
    cfg (1,1) struct
    method (1,1) string {mustBeMember(method,["proposed","maddpg","smith","pid"])}
    policy
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    task (1,1) string {mustBeMember(task,["stabilization","tracking"])}
end

numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;
adjacency = rrjfi.makeRingGraph(numAgents);
scenario = rrjfi.sampleScenario(cfg, seed, task);
allDelays = true(numAgents, numel(cfg.sim.delayValues));
nominalDelays = false(size(allDelays));
[~, nominalIndex] = min(abs(cfg.sim.delayValues - cfg.baseline.nominalDelay));
nominalDelays(:, nominalIndex) = true;

state = zeros(2, numAgents, numSteps + 1);
lower = zeros(size(state));
upper = zeros(size(state));
measurement = zeros(size(state));
control = zeros(numAgents, numSteps);
desiredControl = zeros(numAgents, numSteps);
delayCardinality = zeros(numAgents, numSteps);
containment = false(2, numAgents, numSteps + 1);
recoveryIntervention = false(1, numSteps);
recoveryFeasible = true(1, numSteps);
reward = zeros(1, numSteps);
memory = struct;

state(:, :, 1) = scenario.initialState;
lower(:, :, 1) = state(:, :, 1) - cfg.observer.initialRadius;
upper(:, :, 1) = state(:, :, 1) + cfg.observer.initialRadius;
measurement(:, :, 1) = state(:, :, 1) + scenario.measurementNoise(:, :, 1);
containment(:, :, 1) = state(:, :, 1) >= lower(:, :, 1) & state(:, :, 1) <= upper(:, :, 1);
retained = allDelays;

for step = 1:numSteps
    positionReference = scenario.positionReference(step);
    velocityReference = scenario.velocityReference(step);
    switch method
        case "proposed"
            observation = rrjfi.buildObservation( ...
                lower(:, :, step), upper(:, :, step), retained, positionReference, ...
                velocityReference, cfg, adjacency);
            residual = rrjfiTraining.actorForward(policy.actor, observation);
            nominal = rrjfi.nominalActionFromObservation(observation, cfg);
            desired = nominal + residual;
            projection = rrjfi.scaleSafeAction( ...
                desired, nominal, lower(:, :, step), upper(:, :, step), control, step, cfg, adjacency);
            action = projection.action;
            recoveryIntervention(step) = projection.wasProjected;
            recoveryFeasible(step) = projection.isFeasible;
        case "maddpg"
            observation = rrjfi.buildObservation( ...
                measurement(:, :, step), measurement(:, :, step), nominalDelays, ...
                positionReference, velocityReference, cfg, adjacency);
            desired = rrjfiTraining.actorForward(policy.actor, observation);
            action = min(max(desired, -cfg.control.inputLimit), cfg.control.inputLimit);
        otherwise
            [action, memory] = rrjfi.baselineAction( ...
                method, measurement(:, :, step), memory, positionReference, velocityReference, ...
                control, step, cfg, adjacency);
            desired = action;
    end

    desiredControl(:, step) = desired.';
    control(:, step) = action.';
    process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
    state(:, :, step + 1) = rrjfi.stepPlant( ...
        state(:, :, step), control, step, scenario.delay(:, step), scenario, process, cfg, adjacency);
    measurement(:, :, step + 1) = state(:, :, step + 1) + scenario.measurementNoise(:, :, step + 1);
    update = rrjfi.stepObserver( ...
        lower(:, :, step), upper(:, :, step), control, step, measurement(:, :, step + 1), cfg, adjacency);
    if ~update.isConsistent
        error('rrjfi:EvaluationObserverFailure', ...
            'Observer branch set became empty for %s at seed %d, step %d.', method, seed, step)
    end
    lower(:, :, step + 1) = update.lower;
    upper(:, :, step + 1) = update.upper;
    retained = update.isRetained;
    delayCardinality(:, step) = sum(retained, 2);
    containment(:, :, step + 1) = state(:, :, step + 1) >= update.lower ...
        & state(:, :, step + 1) <= update.upper;
    reward(step) = rrjfi.pointReward( ...
        state(:, :, step + 1), action, scenario.positionReference(step + 1), ...
        scenario.velocityReference(step + 1), cfg, adjacency);
end

positionError = state(1, :, :) - reshape(scenario.positionReference, 1, 1, []);
velocityError = state(2, :, :) - reshape(scenario.velocityReference, 1, 1, []);
consensusError = zeros(numAgents, numSteps + 1);
for agent = 1:numAgents
    neighborCount = max(sum(adjacency(agent, :) > 0), 1);
    neighborWeights = reshape(full(adjacency(agent, :)), 1, numAgents, 1);
    consensusError(agent, :) = squeeze(sum( ...
        neighborWeights .* (state(1, :, :) - state(1, agent, :)), 2)) ./ neighborCount;
end

safetyViolation = abs(state(1, :, :)) > cfg.control.safetyPosition ...
    | abs(state(2, :, :)) > cfg.control.safetyVelocity;
errorNorm = squeeze(max(abs(positionError), [], 2));
settlingIndex = findSettlingIndex(errorNorm, task);

metrics.method = method;
metrics.seed = seed;
metrics.task = task;
metrics.trackingRmse = sqrt(mean(positionError.^2, 'all'));
metrics.velocityRmse = sqrt(mean(velocityError.^2, 'all'));
metrics.consensusRmse = sqrt(mean(consensusError.^2, 'all'));
metrics.worstTrackingError = max(abs(positionError), [], 'all');
metrics.controlEnergy = cfg.sim.sampleTime * sum(control.^2, 'all');
metrics.safetyViolationRate = mean(safetyViolation, 'all');
metrics.containmentRate = mean(containment, 'all');
metrics.meanDelayCardinality = mean(delayCardinality, 'all');
metrics.recoveryInterventionRate = mean(recoveryIntervention);
metrics.recoveryFeasibilityRate = mean(recoveryFeasible);
metrics.meanStepReward = mean(reward);
if isempty(settlingIndex)
    metrics.settlingTime = NaN;
else
    metrics.settlingTime = (settlingIndex - 1) * cfg.sim.sampleTime;
end

result.config = cfg;
result.method = method;
result.scenario = scenario;
result.state = state;
result.lower = lower;
result.upper = upper;
result.measurement = measurement;
result.control = control;
result.desiredControl = desiredControl;
result.delayCardinality = delayCardinality;
result.containment = containment;
result.recoveryIntervention = recoveryIntervention;
result.recoveryFeasible = recoveryFeasible;
result.reward = reward;
result.metrics = metrics;
end

function index = findSettlingIndex(errorNorm, task)
if task ~= "stabilization"
    index = [];
    return
end
threshold = 0.05;
index = [];
for candidate = 1:numel(errorNorm)
    if all(errorNorm(candidate:end) <= threshold)
        index = candidate;
        return
    end
end
end
