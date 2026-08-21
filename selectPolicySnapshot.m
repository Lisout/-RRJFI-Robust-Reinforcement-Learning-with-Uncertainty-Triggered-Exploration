function training = selectPolicySnapshot(training, cfg, validationSeeds)
%SELECTPOLICYSNAPSHOT Select an Actor checkpoint on held-out scenarios.

arguments
    training (1,1) struct
    cfg (1,1) struct
    validationSeeds (1,:) double {mustBeInteger,mustBeNonnegative}
end

numSnapshots = numel(training.actorSnapshots);
scores = zeros(numSnapshots, 1);
trackingRmse = zeros(numSnapshots, 1);
controlEnergy = zeros(numSnapshots, 1);
safetyRate = zeros(numSnapshots, 1);
validationCfg = cfg;
validationCfg.sim.numSteps = min(cfg.sim.numSteps, 180);

for snapshot = 1:numSnapshots
    candidate.actor = training.actorSnapshots{snapshot};
    rmseValues = zeros(numel(validationSeeds), 1);
    energyValues = zeros(numel(validationSeeds), 1);
    safetyValues = zeros(numel(validationSeeds), 1);
    for seedIndex = 1:numel(validationSeeds)
        task = "tracking";
        if mod(seedIndex, 2) == 0
            task = "stabilization";
        end
        evaluation = rrjfi.simulateController( ...
            validationCfg, training.variant, candidate, validationSeeds(seedIndex), task);
        rmseValues(seedIndex) = evaluation.metrics.trackingRmse;
        energyValues(seedIndex) = evaluation.metrics.controlEnergy;
        safetyValues(seedIndex) = evaluation.metrics.safetyViolationRate;
    end
    trackingRmse(snapshot) = mean(rmseValues);
    controlEnergy(snapshot) = mean(energyValues);
    safetyRate(snapshot) = mean(safetyValues);
    scores(snapshot) = trackingRmse(snapshot) + 0.008 * controlEnergy(snapshot) ...
        + 50 * safetyRate(snapshot);
end

minimumEligibleEpisode = ceil(cfg.training.warmupSteps / cfg.training.stepsPerEpisode) + 5;
eligible = training.snapshotEpisode(:) >= minimumEligibleEpisode;
selectionScores = scores;
selectionScores(~eligible) = inf;
[~, selected] = min(selectionScores);
training.actor = training.actorSnapshots{selected};
[training.actor, layerNorms] = rrjfiTraining.enforceActorSpectralBounds(training.actor);
training.actorLayerNorms = layerNorms;
training.actorLipschitzBound = training.actor.outputScale * prod(layerNorms);
training.selection.selectedIndex = selected;
training.selection.selectedEpisode = training.snapshotEpisode(selected);
training.selection.validationSeeds = validationSeeds;
training.selection.score = scores;
training.selection.minimumEligibleEpisode = minimumEligibleEpisode;
training.selection.trackingRmse = trackingRmse;
training.selection.controlEnergy = controlEnergy;
training.selection.safetyRate = safetyRate;
end
