function result = simulateRecoveryStress( ...
    cfg, proposedPolicy, maddpgPolicy, variant, seed, domainMode)
%SIMULATERECOVERYSTRESS Stress-test the certified recovery interface.
%   The in-domain experiment uses a strongly nonlinear but declared plant
%   box and a finite-duration anomalous action proposal. All controller
%   variants see the same scenario and proposal stress. The out-of-domain
%   diagnostic deliberately violates the declared model box and reports
%   when the interval certificate is withdrawn.

arguments
    cfg (1,1) struct
    proposedPolicy (1,1) struct
    maddpgPolicy (1,1) struct
    variant (1,1) string {mustBeMember(variant, ...
        ["certifiedRecovery","robustOnly","pointOnly"])}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    domainMode (1,1) string {mustBeMember(domainMode,["inDomain","outOfDomain"])} = "inDomain"
end

numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;
adjacency = rrjfi.makeRingGraph(numAgents);
scenario = rrjfi.sampleScenario(cfg, seed, "stabilization");
stream = RandStream('Threefry', 'Seed', seed + 41000);

initialSigns = 2 .* (rand(stream, 1, numAgents) > 0.5) - 1;
scenario.initialState = [initialSigns .* (1.08 + 0.16 .* rand(stream, 1, numAgents)); ...
    initialSigns .* (0.18 + 0.12 .* rand(stream, 1, numAgents))];
scenario.positionReference(:) = 0;
scenario.velocityReference(:) = 0;

if domainMode == "outOfDomain"
    scenario.sinGain(:) = cfg.model.sinGain(2) + 0.45;
    scenario.couplingGain(:) = cfg.model.couplingGain(2) + 0.18;
    violationStart = max(2, round(0.42 * numSteps));
    violationPulse = reshape( ...
        4.0 .* cfg.noise.processBound(2) .* initialSigns, 1, numAgents, 1);
    scenario.disturbance(2, :, violationStart:(violationStart + 2)) = ...
        repmat(violationPulse, 1, 1, 3);
end

state = zeros(2, numAgents, numSteps + 1);
lower = nan(size(state));
upper = nan(size(state));
measurement = nan(size(state));
control = zeros(numAgents, numSteps);
desiredControl = zeros(numAgents, numSteps);
stressProposal = zeros(numAgents, numSteps);
containment = false(1, numSteps + 1);
certificateActive = false(1, numSteps + 1);
recoveryIntervention = false(1, numSteps);
recoveryFeasible = true(1, numSteps);
withdrawalStep = NaN;

state(:, :, 1) = scenario.initialState;
lower(:, :, 1) = state(:, :, 1) - cfg.observer.initialRadius;
upper(:, :, 1) = state(:, :, 1) + cfg.observer.initialRadius;
measurement(:, :, 1) = state(:, :, 1) + scenario.measurementNoise(:, :, 1);
containment(1) = all(state(:, :, 1) >= lower(:, :, 1) ...
    & state(:, :, 1) <= upper(:, :, 1), 'all');
certificateActive(1) = true;
retained = true(numAgents, numel(cfg.sim.delayValues));
lastCompletedStep = 0;

stressStart = round(0.24 * numSteps);
stressStop = round(0.48 * numSteps);
for step = 1:numSteps
    if ~certificateActive(step)
        break
    end

    observation = rrjfi.buildObservation( ...
        lower(:, :, step), upper(:, :, step), retained, 0, 0, cfg, adjacency);
    nominal = rrjfi.nominalActionFromObservation(observation, cfg);
    stress = zeros(1, numAgents);
    if step >= stressStart && step <= stressStop
        currentSigns = sign(0.5 .* (lower(1, :, step) + upper(1, :, step)));
        currentSigns(currentSigns == 0) = initialSigns(currentSigns == 0);
        stress = 1.85 .* currentSigns .* (0.75 + 0.25 .* sin(0.21 .* step + (1:numAgents)));
    end

    switch variant
        case {"certifiedRecovery","robustOnly"}
            residual = rrjfiTraining.actorForward(proposedPolicy.actor, observation);
            desired = nominal + residual + stress;
        case "pointOnly"
            pointObservation = rrjfi.buildObservation( ...
                measurement(:, :, step), measurement(:, :, step), retained, 0, 0, cfg, adjacency);
            desired = rrjfiTraining.actorForward(maddpgPolicy.actor, pointObservation) + stress;
    end

    if variant == "certifiedRecovery"
        projectionCfg = cfg;
        if isfield(cfg.control, 'recoverySafetyBuffer')
            projectionCfg.control.safetyPosition = cfg.control.safetyPosition ...
                - cfg.control.recoverySafetyBuffer(1);
            projectionCfg.control.safetyVelocity = cfg.control.safetyVelocity ...
                - cfg.control.recoverySafetyBuffer(2);
        end
        projection = rrjfi.scaleSafeAction( ...
            desired, nominal, lower(:, :, step), upper(:, :, step), ...
            control, step, projectionCfg, adjacency);
        if ~projection.isFeasible
            emergency = rrjfi.projectSafeAction( ...
                nominal, lower(:, :, step), upper(:, :, step), ...
                control, step, cfg, adjacency);
            projection.action = emergency.action;
            projection.isFeasible = emergency.certified;
            projection.wasProjected = true;
        end
        action = projection.action;
        recoveryIntervention(step) = projection.wasProjected;
        recoveryFeasible(step) = projection.isFeasible;
    else
        action = min(max(desired, -cfg.control.inputLimit), cfg.control.inputLimit);
    end

    desiredControl(:, step) = desired.';
    stressProposal(:, step) = stress.';
    control(:, step) = action.';
    process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
    state(:, :, step + 1) = rrjfi.stepPlant( ...
        state(:, :, step), control, step, scenario.delay(:, step), scenario, process, cfg, adjacency);
    lastCompletedStep = step;
    measurement(:, :, step + 1) = state(:, :, step + 1) ...
        + scenario.measurementNoise(:, :, step + 1);

    update = rrjfi.stepObserver( ...
        lower(:, :, step), upper(:, :, step), control, step, ...
        measurement(:, :, step + 1), cfg, adjacency);
    stateInsideDeclaredDomain = all(state(1, :, step + 1) >= cfg.model.positionDomain(1) ...
        & state(1, :, step + 1) <= cfg.model.positionDomain(2)) ...
        && all(state(2, :, step + 1) >= cfg.model.velocityDomain(1) ...
        & state(2, :, step + 1) <= cfg.model.velocityDomain(2));
    if ~update.isConsistent || ~stateInsideDeclaredDomain
        withdrawalStep = step;
        break
    end

    lower(:, :, step + 1) = update.lower;
    upper(:, :, step + 1) = update.upper;
    retained = update.isRetained;
    containment(step + 1) = all(state(:, :, step + 1) >= update.lower ...
        & state(:, :, step + 1) <= update.upper, 'all');
    if ~containment(step + 1)
        withdrawalStep = step;
        break
    else
        certificateActive(step + 1) = true;
    end
end

lastStateIndex = lastCompletedStep + 1;
stateUsed = state(:, :, 1:lastStateIndex);
lowerUsed = lower(:, :, 1:lastStateIndex);
upperUsed = upper(:, :, 1:lastStateIndex);
safetyViolation = abs(stateUsed(1, :, :)) > cfg.control.safetyPosition ...
    | abs(stateUsed(2, :, :)) > cfg.control.safetyVelocity;
positionError = stateUsed(1, :, :);
intervalWidth = upperUsed - lowerUsed;

metrics.variant = variant;
metrics.seed = seed;
metrics.domainMode = domainMode;
metrics.trackingRmse = sqrt(mean(positionError.^2, 'all'));
metrics.worstTrackingError = max(abs(positionError), [], 'all');
metrics.safetyViolationRate = mean(safetyViolation, 'all');
metrics.anySafetyViolation = any(safetyViolation, 'all');
metrics.containmentRate = mean(containment(1:lastStateIndex));
metrics.recoveryInterventionRate = mean(recoveryIntervention(1:max(lastCompletedStep, 1)));
metrics.recoveryFeasibilityRate = mean(recoveryFeasible(1:max(lastCompletedStep, 1)));
metrics.maximumPositionWidth = max(intervalWidth(1, :, :), [], 'all', 'omitnan');
metrics.maximumVelocityWidth = max(intervalWidth(2, :, :), [], 'all', 'omitnan');
metrics.certificateWithdrawn = ~isnan(withdrawalStep);
metrics.withdrawalTime = withdrawalStep .* cfg.sim.sampleTime;
metrics.completedFraction = lastCompletedStep ./ numSteps;

result.metrics = metrics;
result.config = cfg;
result.variant = variant;
result.domainMode = domainMode;
result.scenario = scenario;
result.state = state;
result.lower = lower;
result.upper = upper;
result.measurement = measurement;
result.control = control;
result.desiredControl = desiredControl;
result.stressProposal = stressProposal;
result.containment = containment;
result.certificateActive = certificateActive;
result.recoveryIntervention = recoveryIntervention;
result.recoveryFeasible = recoveryFeasible;
end
