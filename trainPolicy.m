function training = trainPolicy(cfg, variant, seed)
%TRAINPOLICY Train a matched CTDE deterministic multi-agent policy.
%   VARIANT is "proposed" for the interval-robust residual policy or
%   "maddpg" for the point-observation full-action baseline.

arguments
    cfg (1,1) struct
    variant (1,1) string {mustBeMember(variant,["proposed","maddpg"])}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

observationDimension = 10;
numAgents = cfg.sim.numAgents;
jointObservationDimension = observationDimension * numAgents;
criticInputDimension = jointObservationDimension + numAgents;
hiddenWidth = cfg.training.hiddenWidth;
isProposed = variant == "proposed";

if isProposed
    outputScale = cfg.control.residualLimit;
else
    outputScale = cfg.control.inputLimit;
end
actor = rrjfiTraining.initializeActor( ...
    observationDimension, hiddenWidth, outputScale, seed + 11, isProposed);
if isProposed
    actor.parameters.W3(:) = 0;
    actor.parameters.b3(:) = 0;
else
    actor = rrjfiTraining.pretrainFullActor(actor, cfg, seed + 19);
end
[actor, ~] = rrjfiTraining.enforceActorSpectralBounds(actor);
targetActor = actor;

lowerCritic = rrjfiTraining.initializeCritic(criticInputDimension, hiddenWidth, seed + 31);
upperCritic = rrjfiTraining.initializeCritic(criticInputDimension, hiddenWidth, seed + 47);
targetLowerCritic = lowerCritic;
targetUpperCritic = upperCritic;

replay = rrjfiTraining.initializeReplay( ...
    observationDimension, numAgents, cfg.training.replayCapacity);
stream = RandStream('Threefry', 'Seed', seed + 101);
adjacency = rrjfi.makeRingGraph(numAgents);
allDelays = true(numAgents, numel(cfg.sim.delayValues));
nominalDelays = false(size(allDelays));
[~, nominalIndex] = min(abs(cfg.sim.delayValues - median(cfg.sim.delayValues)));
nominalDelays(:, nominalIndex) = true;

actorState = struct;
lowerCriticState = struct;
upperCriticState = struct;
updateIteration = 0;
globalStep = 0;
explorationStd = cfg.training.explorationStd;
episodeReturn = nan(cfg.training.numEpisodes, 1);
episodeLength = zeros(cfg.training.numEpisodes, 1);
criticLoss = nan(cfg.training.numEpisodes, 2);
projectionRate = zeros(cfg.training.numEpisodes, 1);
actorSnapshots = {actor};
snapshotEpisode = 0;

for episode = 1:cfg.training.numEpisodes
    episodeCfg = cfg;
    episodeCfg.sim.numSteps = cfg.training.stepsPerEpisode;
    task = "tracking";
    if mod(episode, 3) == 0
        task = "stabilization";
    end
    scenario = rrjfi.sampleScenario(episodeCfg, seed * 10000 + episode, task);
    state = scenario.initialState;
    lower = state - episodeCfg.observer.initialRadius;
    upper = state + episodeCfg.observer.initialRadius;
    retained = allDelays;
    measurement = state + scenario.measurementNoise(:, :, 1);
    controlHistory = zeros(numAgents, episodeCfg.sim.numSteps);
    cumulativeReward = 0;
    projectionCount = 0;
    lastLoss = [NaN, NaN];

    for step = 1:episodeCfg.sim.numSteps
        if isProposed
            observation = rrjfi.buildObservation( ...
                lower, upper, retained, scenario.positionReference(step), ...
                scenario.velocityReference(step), episodeCfg, adjacency);
        else
            observation = rrjfi.buildObservation( ...
                measurement, measurement, nominalDelays, scenario.positionReference(step), ...
                scenario.velocityReference(step), episodeCfg, adjacency);
        end

        actorOutput = rrjfiTraining.actorForward(actor, observation);
        if isProposed
            nominalAction = rrjfi.nominalActionFromObservation(observation, episodeCfg);
            desiredAction = nominalAction + actorOutput;
        else
            nominalAction = rrjfi.nominalActionFromObservation(observation, episodeCfg);
            desiredAction = actorOutput;
        end
        exploration = explorationStd .* randn(stream, 1, numAgents);
        desiredAction = min(max(desiredAction + exploration, ...
            -episodeCfg.control.inputLimit), episodeCfg.control.inputLimit);

        if isProposed
            projection = rrjfi.scaleSafeAction( ...
                desiredAction, nominalAction, lower, upper, controlHistory, step, episodeCfg, adjacency);
            action = projection.action;
            projectionCount = projectionCount + projection.wasProjected;
        else
            action = desiredAction;
        end
        controlHistory(:, step) = action.';

        process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
        nextState = rrjfi.stepPlant( ...
            state, controlHistory, step, scenario.delay(:, step), scenario, process, episodeCfg, adjacency);
        nextMeasurement = nextState + scenario.measurementNoise(:, :, step + 1);
        update = rrjfi.stepObserver( ...
            lower, upper, controlHistory, step, nextMeasurement, episodeCfg, adjacency);
        if ~update.isConsistent
            error('rrjfi:TrainingObserverFailure', ...
                'Observer branch set became empty in episode %d, step %d.', episode, step)
        end

        if isProposed
            [lowerReward, upperReward] = rrjfi.robustRewardBounds( ...
                update.lower, update.upper, action, scenario.positionReference(step + 1), ...
                scenario.velocityReference(step + 1), episodeCfg, adjacency);
            nextObservation = rrjfi.buildObservation( ...
                update.lower, update.upper, update.isRetained, scenario.positionReference(step + 1), ...
                scenario.velocityReference(step + 1), episodeCfg, adjacency);
        else
            scalarReward = rrjfi.pointReward( ...
                nextState, action, scenario.positionReference(step + 1), ...
                scenario.velocityReference(step + 1), episodeCfg, adjacency);
            lowerReward = scalarReward;
            upperReward = scalarReward;
            nextObservation = rrjfi.buildObservation( ...
                nextMeasurement, nextMeasurement, nominalDelays, scenario.positionReference(step + 1), ...
                scenario.velocityReference(step + 1), episodeCfg, adjacency);
        end

        unsafe = any(abs(nextState(1, :)) > episodeCfg.control.safetyPosition) ...
            || any(abs(nextState(2, :)) > episodeCfg.control.safetyVelocity);
        done = unsafe || step == episodeCfg.sim.numSteps;
        replay = rrjfiTraining.appendReplay( ...
            replay, observation(:), action.', lowerReward, upperReward, nextObservation(:), done);
        cumulativeReward = cumulativeReward + lowerReward;
        globalStep = globalStep + 1;

        if replay.count >= max(cfg.training.warmupSteps, cfg.training.batchSize)
            batch = rrjfiTraining.sampleReplay(replay, cfg.training.batchSize, stream);
            [actor, lowerCritic, upperCritic, targetActor, targetLowerCritic, targetUpperCritic, ...
                actorState, lowerCriticState, upperCriticState, updateIteration, lastLoss] = ...
                updateNetworks(actor, lowerCritic, upperCritic, targetActor, targetLowerCritic, ...
                targetUpperCritic, actorState, lowerCriticState, upperCriticState, ...
                updateIteration, batch, cfg, isProposed, observationDimension, numAgents);
        end

        state = nextState;
        lower = update.lower;
        upper = update.upper;
        retained = update.isRetained;
        measurement = nextMeasurement;
        if done
            episodeLength(episode) = step;
            break
        end
    end

    episodeReturn(episode) = cumulativeReward;
    criticLoss(episode, :) = lastLoss;
    projectionRate(episode) = projectionCount / max(episodeLength(episode), 1);
    explorationStd = max(0.025, explorationStd * cfg.training.explorationDecay);
    if mod(episode, 5) == 0
        actorSnapshots{end + 1, 1} = actor; %#ok<AGROW>
        snapshotEpisode(end + 1, 1) = episode; %#ok<AGROW>
    end
end

[actor, layerNorms] = rrjfiTraining.enforceActorSpectralBounds(actor);
training.variant = variant;
training.seed = seed;
training.actor = actor;
training.lowerCritic = lowerCritic;
training.upperCritic = upperCritic;
training.episodeReturn = episodeReturn;
training.episodeLength = episodeLength;
training.criticLoss = criticLoss;
training.projectionRate = projectionRate;
training.actorLayerNorms = layerNorms;
training.actorLipschitzBound = actor.outputScale * prod(layerNorms);
training.actorSnapshots = actorSnapshots;
training.snapshotEpisode = snapshotEpisode;
training.totalEnvironmentSteps = globalStep;
training.totalGradientSteps = updateIteration;
training.config = cfg;
end

function [actor, lowerCritic, upperCritic, targetActor, targetLowerCritic, targetUpperCritic, ...
    actorState, lowerState, upperState, iteration, losses] = updateNetworks( ...
    actor, lowerCritic, upperCritic, targetActor, targetLowerCritic, targetUpperCritic, ...
    actorState, lowerState, upperState, iteration, batch, cfg, isProposed, observationDimension, numAgents)

batchSize = size(batch.observation, 2);
nextLocalObservation = reshape(batch.nextObservation, observationDimension, []);
targetActorOutput = rrjfiTraining.actorForward(targetActor, nextLocalObservation);
if isProposed
    targetNominal = rrjfi.nominalActionFromObservation(nextLocalObservation, cfg);
    targetAction = reshape(targetNominal + targetActorOutput, numAgents, batchSize);
else
    targetAction = reshape(targetActorOutput, numAgents, batchSize);
end
targetAction = min(max(targetAction, -cfg.control.inputLimit), cfg.control.inputLimit);
targetInput = [batch.nextObservation; targetAction];
targetLowerValue = rrjfiTraining.criticForward(targetLowerCritic, targetInput);
targetUpperValue = rrjfiTraining.criticForward(targetUpperCritic, targetInput);
lowerTarget = batch.lowerReward + cfg.reward.discount .* (1 - batch.done) .* targetLowerValue;
upperTarget = batch.upperReward + cfg.reward.discount .* (1 - batch.done) .* targetUpperValue;

criticInput = [batch.observation; batch.action];
[lowerLoss, lowerGradients] = rrjfiTraining.criticLossGradients(lowerCritic, criticInput, lowerTarget);
[upperLoss, upperGradients] = rrjfiTraining.criticLossGradients(upperCritic, criticInput, upperTarget);
iteration = iteration + 1;
[lowerCritic.parameters, lowerState] = rrjfiTraining.adamStep( ...
    lowerCritic.parameters, lowerGradients, lowerState, cfg.training.criticLearningRate, iteration);
[upperCritic.parameters, upperState] = rrjfiTraining.adamStep( ...
    upperCritic.parameters, upperGradients, upperState, cfg.training.criticLearningRate, iteration);

localObservation = reshape(batch.observation, observationDimension, []);
[actorOutput, actorCache] = rrjfiTraining.actorForward(actor, localObservation);
if isProposed
    nominalAction = rrjfi.nominalActionFromObservation(localObservation, cfg);
    policyAction = reshape(nominalAction + actorOutput, numAgents, batchSize);
else
    policyAction = reshape(actorOutput, numAgents, batchSize);
end
policyAction = min(max(policyAction, -cfg.control.inputLimit), cfg.control.inputLimit);
policyInput = [batch.observation; policyAction];
inputGradient = rrjfiTraining.criticInputGradient(lowerCritic, policyInput);
actionGradient = inputGradient((end - numAgents + 1):end, :);
actorDerivative = -reshape(actionGradient, 1, []) ./ batchSize;
actorGradients = rrjfiTraining.actorBackward(actor, actorCache, actorDerivative);
[actor.parameters, actorState] = rrjfiTraining.adamStep( ...
    actor.parameters, actorGradients, actorState, cfg.training.actorLearningRate, iteration);
[actor, ~] = rrjfiTraining.enforceActorSpectralBounds(actor);

targetActor = rrjfiTraining.softUpdate(targetActor, actor, cfg.training.targetRate);
targetLowerCritic = rrjfiTraining.softUpdate(targetLowerCritic, lowerCritic, cfg.training.targetRate);
targetUpperCritic = rrjfiTraining.softUpdate(targetUpperCritic, upperCritic, cfg.training.targetRate);
losses = [lowerLoss, upperLoss];
end
