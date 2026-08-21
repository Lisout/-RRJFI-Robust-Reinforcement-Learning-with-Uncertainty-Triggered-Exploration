function result = simulateIEBPU(cfg, policy, head, variant, seed)
%SIMULATEIEBPU Evaluate uncertainty/PE-triggered active exploration.

arguments
    cfg (1,1) struct
    policy (1,1) struct
    head (1,1) struct
    variant (1,1) string {mustBeMember(variant,["full","entropyOnly","continuous","none"])}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;
featureDimension = head.featureDimension;
adjacency = rrjfi.makeRingGraph(numAgents);
scenario = rrjfi.sampleScenario(cfg, seed, "tracking");
stream = RandStream('Threefry', 'Seed', seed + 7000);
allDelays = true(numAgents, numel(cfg.sim.delayValues));

state = scenario.initialState;
lower = state - cfg.observer.initialRadius;
upper = state + cfg.observer.initialRadius;
retained = allDelays;
controlHistory = zeros(numAgents, numSteps);
meanWeights = zeros(featureDimension, 1);
covariance = cfg.trigger.priorScale .* eye(featureDimension);
featureBuffer = zeros(featureDimension, cfg.trigger.peWindow);
bufferCount = 0;
bufferPosition = 0;
isActive = false;
lastOnset = -inf;

uncertainty = zeros(1, numSteps);
threshold = zeros(1, numSteps);
onThreshold = zeros(1, numSteps);
offThreshold = zeros(1, numSteps);
exactPe = zeros(1, numSteps);
lowerPe = zeros(1, numSteps);
trigger = false(1, numSteps);
onset = false(1, numSteps);
explorationEnergy = zeros(1, numSteps);
covarianceTrace = zeros(1, numSteps);
innovation = zeros(1, numSteps);
parameterError = zeros(1, numSteps);
updateTime = zeros(1, numSteps);
trackingError = zeros(1, numSteps);
safetyViolation = false(1, numSteps);
containment = false(1, numSteps);
appliedControl = zeros(numAgents, numSteps);
previousUncertainty = 0;

for step = 1:numSteps
    observation = rrjfi.buildObservation( ...
        lower, upper, retained, scenario.positionReference(step), ...
        scenario.velocityReference(step), cfg, adjacency);
    residual = rrjfiTraining.actorForward(policy.actor, observation);
    nominal = rrjfi.nominalActionFromObservation(observation, cfg);
    baseAction = min(max(nominal + residual, -cfg.control.inputLimit), cfg.control.inputLimit);
    [nominalFeatures, ~] = rrjfiTraining.bayesianFeatures( ...
        policy, head, observation(:), baseAction.');

    bufferPosition = mod(bufferPosition, cfg.trigger.peWindow) + 1;
    featureBuffer(:, bufferPosition) = nominalFeatures;
    bufferCount = min(bufferCount + 1, cfg.trigger.peWindow);
    gramian = featureBuffer(:, 1:bufferCount) * featureBuffer(:, 1:bufferCount).';
    exactPe(step) = min(eig(gramian));
    lowerPe(step) = rrjfi.gershgorinLowerBound(gramian);
    if cfg.trigger.useExactPe
        peMonitor = exactPe(step);
    else
        peMonitor = lowerPe(step);
    end
    uncertainty(step) = nominalFeatures.' * covariance * nominalFeatures;

    midpoint = 0.5 .* (lower + upper);
    positionError = midpoint(1, :) - scenario.positionReference(step);
    velocityError = midpoint(2, :) - scenario.velocityReference(step);
    normalizedError = sqrt(mean(positionError.^2) + 0.25 * mean(velocityError.^2));
    safetyMargin = max(0, min(observation(10, :)));
    cooperationTerm = min(previousUncertainty / max(cfg.trigger.baseThreshold, eps), 3);
    threshold(step) = cfg.trigger.baseThreshold ...
        * (1 + cfg.trigger.performanceGain ...
        * (1 - exp(-normalizedError^2 / cfg.trigger.performanceScale^2))) ...
        * (1 + cfg.trigger.safetyGain * exp(-cfg.trigger.safetyRate * safetyMargin)) ...
        * (1 + cfg.trigger.cooperationGain * cooperationTerm);
    onThreshold(step) = threshold(step) + cfg.trigger.hysteresisHalfWidth;
    offThreshold(step) = max(0, threshold(step) - cfg.trigger.hysteresisHalfWidth);

    switch variant
        case "full"
            if peMonitor >= cfg.trigger.peThreshold
                request = false;
                isActive = false;
            elseif isActive
                request = uncertainty(step) > offThreshold(step);
                isActive = request;
            else
                refractorySatisfied = step - lastOnset >= cfg.trigger.refractorySamples;
                request = uncertainty(step) >= onThreshold(step) && refractorySatisfied;
                if request
                    isActive = true;
                    onset(step) = true;
                    lastOnset = step;
                end
            end
        case "entropyOnly"
            request = uncertainty(step) > threshold(step);
            onset(step) = request && (step == 1 || ~trigger(step - 1));
        case "continuous"
            request = true;
            onset(step) = step == 1;
        case "none"
            request = false;
    end

    action = baseAction;
    if request
        direction = sign(randn(stream, 1, numAgents));
        direction(direction == 0) = 1;
        oscillation = sin(0.37 * step + (1:numAgents));
        candidate = baseAction + cfg.trigger.explorationAmplitude .* direction .* oscillation;
        projection = rrjfi.scaleSafeAction( ...
            candidate, baseAction, lower, upper, controlHistory, step, cfg, adjacency);
        action = projection.action;
        trigger(step) = projection.isFeasible && norm(action - baseAction) > 1e-12;
    end
    if onset(step) && ~trigger(step)
        onset(step) = false;
    end
    explorationEnergy(step) = norm(action - baseAction)^2;
    appliedControl(:, step) = action.';
    controlHistory(:, step) = action.';

    [appliedFeatures, ~] = rrjfiTraining.bayesianFeatures( ...
        policy, head, observation(:), action.');
    targetNoise = cfg.trigger.targetNoiseBound * (2 * rand(stream) - 1);
    teacherValue = head.referenceWeights.' * appliedFeatures + targetNoise;
    startTime = tic;
    [meanWeights, covariance, diagnostics] = rrjfiTraining.rlsUpdate( ...
        meanWeights, covariance, appliedFeatures, teacherValue, cfg.trigger.forgettingFactor);
    updateTime(step) = toc(startTime);
    innovation(step) = diagnostics.innovation;
    covarianceTrace(step) = trace(covariance);
    parameterError(step) = norm(meanWeights - head.referenceWeights);

    process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
    nextState = rrjfi.stepPlant( ...
        state, controlHistory, step, scenario.delay(:, step), scenario, process, cfg, adjacency);
    nextMeasurement = nextState + scenario.measurementNoise(:, :, step + 1);
    update = rrjfi.stepObserver(lower, upper, controlHistory, step, nextMeasurement, cfg, adjacency);
    if ~update.isConsistent
        error('rrjfi:IEBPUObserverFailure', ...
            'Observer branch set became empty at seed %d, step %d.', seed, step)
    end
    containment(step) = all(nextState >= update.lower & nextState <= update.upper, 'all');
    safetyViolation(step) = any(abs(nextState(1, :)) > cfg.control.safetyPosition) ...
        || any(abs(nextState(2, :)) > cfg.control.safetyVelocity);
    trackingError(step) = sqrt(mean((nextState(1, :) - scenario.positionReference(step + 1)).^2));
    state = nextState;
    lower = update.lower;
    upper = update.upper;
    retained = update.isRetained;
    previousUncertainty = uncertainty(step);
end

transitions = sum(abs(diff(trigger)));
onsetIndices = find(onset);
if numel(onsetIndices) >= 2
    minimumInterOnset = min(diff(onsetIndices)) * cfg.sim.sampleTime;
else
    minimumInterOnset = NaN;
end
validationPrediction = meanWeights.' * head.validationFeatures;

metrics.variant = variant;
metrics.seed = seed;
metrics.trackingRmse = sqrt(mean(trackingError.^2));
metrics.safetyViolationRate = mean(safetyViolation);
metrics.containmentRate = mean(containment);
metrics.activationRatio = mean(trigger);
metrics.switchingRate = transitions / max(numSteps - 1, 1);
metrics.onsetCount = sum(onset);
metrics.minimumInterOnsetTime = minimumInterOnset;
metrics.explorationEnergy = sum(explorationEnergy);
metrics.finalValidationMse = mean((validationPrediction - head.validationTarget).^2);
metrics.finalParameterError = parameterError(end);
metrics.finalCovarianceTrace = covarianceTrace(end);
tailStart = max(1, numSteps - 99);
metrics.tailInnovationRmse = sqrt(mean(innovation(tailStart:end).^2));
if cfg.trigger.useExactPe
    metrics.peCertificateRatio = mean(exactPe >= cfg.trigger.peThreshold);
else
    metrics.peCertificateRatio = mean(lowerPe >= cfg.trigger.peThreshold);
end
metrics.averageUpdateTime = mean(updateTime);
metrics.worstUpdateTime = max(updateTime);
if variant == "full"
    metrics.theoreticalMinimumInterOnsetTime = ...
        cfg.trigger.refractorySamples * cfg.sim.sampleTime;
else
    metrics.theoreticalMinimumInterOnsetTime = cfg.sim.sampleTime;
end

result.metrics = metrics;
result.variant = variant;
result.seed = seed;
result.uncertainty = uncertainty;
result.threshold = threshold;
result.onThreshold = onThreshold;
result.offThreshold = offThreshold;
result.exactPe = exactPe;
result.lowerPe = lowerPe;
result.trigger = trigger;
result.onset = onset;
result.explorationEnergy = explorationEnergy;
result.covarianceTrace = covarianceTrace;
result.innovation = innovation;
result.parameterError = parameterError;
result.updateTime = updateTime;
result.trackingError = trackingError;
result.safetyViolation = safetyViolation;
result.containment = containment;
result.appliedControl = appliedControl;
result.finalWeights = meanWeights;
result.finalCovariance = covariance;
result.scenario = scenario;
end
