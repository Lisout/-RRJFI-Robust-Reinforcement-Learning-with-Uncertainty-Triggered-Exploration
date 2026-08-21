function result = simulateObserverScenario(cfg, seed, task)
%SIMULATEOBSERVERSCENARIO Run one deterministic DC-IDO evaluation episode.

arguments
    cfg (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    task (1,1) string {mustBeMember(task,["stabilization","tracking"])} = "tracking"
end

numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;
numDelays = numel(cfg.sim.delayValues);
adjacency = rrjfi.makeRingGraph(numAgents);
scenario = rrjfi.sampleScenario(cfg, seed, task);

state = zeros(2, numAgents, numSteps + 1);
lower = zeros(size(state));
upper = zeros(size(state));
measurement = zeros(size(state));
control = zeros(numAgents, numSteps);
delayCardinality = zeros(numAgents, numSteps);
trueDelayRetained = false(numAgents, numSteps);
exactDelay = false(numAgents, numSteps);
containment = false(2, numAgents, numSteps + 1);
hullInflation = nan(numAgents, numSteps);
hullExcess = nan(2, numAgents, numSteps);
contraction = nan(2, numAgents, numDelays, numSteps);
rewardWidthRefined = nan(1, numSteps);
rewardWidthPrior = nan(1, numSteps);

state(:, :, 1) = scenario.initialState;
lower(:, :, 1) = state(:, :, 1) - cfg.observer.initialRadius;
upper(:, :, 1) = state(:, :, 1) + cfg.observer.initialRadius;
measurement(:, :, 1) = state(:, :, 1) + scenario.measurementNoise(:, :, 1);
containment(:, :, 1) = state(:, :, 1) >= lower(:, :, 1) & state(:, :, 1) <= upper(:, :, 1);

for step = 1:numSteps
    midpoint = 0.5 .* (lower(:, :, step) + upper(:, :, step));
    nextReference = scenario.positionReference(step);
    nextVelocityReference = scenario.velocityReference(step);
    control(:, step) = rrjfi.observerProbeAction( ...
        midpoint, nextReference, nextVelocityReference, step, cfg, adjacency).';

    process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
    state(:, :, step + 1) = rrjfi.stepPlant( ...
        state(:, :, step), control, step, scenario.delay(:, step), scenario, process, cfg, adjacency);
    measurement(:, :, step + 1) = state(:, :, step + 1) + scenario.measurementNoise(:, :, step + 1);

    update = rrjfi.stepObserver( ...
        lower(:, :, step), upper(:, :, step), control, step, measurement(:, :, step + 1), cfg, adjacency);
    if ~update.isConsistent
        error('rrjfi:EmptyDelaySet', 'All delay branches were rejected at seed %d, step %d.', seed, step)
    end
    lower(:, :, step + 1) = update.lower;
    upper(:, :, step + 1) = update.upper;
    containment(:, :, step + 1) = state(:, :, step + 1) >= update.lower ...
        & state(:, :, step + 1) <= update.upper;
    delayCardinality(:, step) = sum(update.isRetained, 2);
    exactDelay(:, step) = delayCardinality(:, step) == 1;
    hullExcess(:, :, step) = update.hullExcess;

    for agent = 1:numAgents
        trueIndex = find(cfg.sim.delayValues == scenario.delay(agent, step), 1);
        trueDelayRetained(agent, step) = update.isRetained(agent, trueIndex);
        retained = find(update.isRetained(agent, :));
        branchLower = reshape(update.lowerBranch(:, agent, retained), 2, []);
        branchUpper = reshape(update.upperBranch(:, agent, retained), 2, []);
        unionArea = rrjfi.rectangleUnionArea(branchLower, branchUpper);
        hullArea = prod(update.upper(:, agent) - update.lower(:, agent));
        hullInflation(agent, step) = max(hullArea - unionArea, 0) / max(unionArea, eps);
    end

    contraction(:, :, :, step) = update.correctedWidth ./ max(update.predictionWidth, eps);
    priorLower = min(update.lowerPrediction, [], 3);
    priorUpper = max(update.upperPrediction, [], 3);
    [refinedLowerReward, refinedUpperReward] = rrjfi.robustRewardBounds( ...
        update.lower, update.upper, control(:, step).', scenario.positionReference(step + 1), ...
        scenario.velocityReference(step + 1), cfg, adjacency);
    [priorLowerReward, priorUpperReward] = rrjfi.robustRewardBounds( ...
        priorLower, priorUpper, control(:, step).', scenario.positionReference(step + 1), ...
        scenario.velocityReference(step + 1), cfg, adjacency);
    rewardWidthRefined(step) = refinedUpperReward - refinedLowerReward;
    rewardWidthPrior(step) = priorUpperReward - priorLowerReward;
end

midpoint = 0.5 .* (lower + upper);
estimationError = state - midpoint;
stateWidth = upper - lower;
validInflation = hullInflation(isfinite(hullInflation));
validContraction = contraction(isfinite(contraction));

metrics.seed = seed;
metrics.containmentRate = mean(containment, 'all');
metrics.delayRetentionRate = mean(trueDelayRetained, 'all');
metrics.exactDelayRate = mean(exactDelay, 'all');
metrics.meanDelayCardinality = mean(delayCardinality, 'all');
metrics.midpointRmse = sqrt(mean(estimationError.^2, 'all'));
metrics.meanPositionWidth = mean(stateWidth(1, :, :), 'all');
metrics.meanVelocityWidth = mean(stateWidth(2, :, :), 'all');
metrics.meanHullInflation = mean(validInflation);
metrics.maximumHullInflation = max(validInflation);
metrics.meanHullExcess = mean(hullExcess, 'all', 'omitnan');
metrics.maximumHullExcess = max(hullExcess, [], 'all', 'omitnan');
metrics.certifiedHullExcessCap = max(2*cfg.noise.measurementBound);
metrics.maximumMeasurementRatio = max(validContraction);
metrics.meanPriorRewardWidth = mean(rewardWidthPrior);
metrics.meanRefinedRewardWidth = mean(rewardWidthRefined);
metrics.rewardWidthReduction = 1 - metrics.meanRefinedRewardWidth / metrics.meanPriorRewardWidth;
repeatedRewardWidth = repmat(rewardWidthRefined, numAgents, 1);
metrics.cardinalityRewardCorrelation = corr(delayCardinality(:), ...
    repeatedRewardWidth(:));

result.config = cfg;
result.scenario = scenario;
result.adjacency = adjacency;
result.state = state;
result.lower = lower;
result.upper = upper;
result.measurement = measurement;
result.control = control;
result.delayCardinality = delayCardinality;
result.trueDelayRetained = trueDelayRetained;
result.hullInflation = hullInflation;
result.hullExcess = hullExcess;
result.contraction = contraction;
result.rewardWidthRefined = rewardWidthRefined;
result.rewardWidthPrior = rewardWidthPrior;
result.metrics = metrics;
end
