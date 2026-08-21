function update = stepObserver(lowerPrior, upperPrior, controlHistory, step, measurement, cfg, adjacency)
%STEPOBSERVER Execute one DC-IDO parallel prediction and correction step.
%   No fabricated fallback interval is created. If every delay branch is
%   inconsistent for an agent, UPDATE.isConsistent is false.

arguments
    lowerPrior (2,:) double
    upperPrior (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    measurement (2,:) double
    cfg (1,1) struct
    adjacency double
end

delayValues = cfg.sim.delayValues;
numDelays = numel(delayValues);
numAgents = size(lowerPrior, 2);
lowerBranch = nan(2, numAgents, numDelays);
upperBranch = nan(2, numAgents, numDelays);
isRetained = false(numAgents, numDelays);
predictionWidth = nan(2, numAgents, numDelays);
correctedWidth = nan(2, numAgents, numDelays);
lowerPredictionAll = nan(2, numAgents, numDelays);
upperPredictionAll = nan(2, numAgents, numDelays);

measurementLower = measurement - cfg.noise.measurementBound;
measurementUpper = measurement + cfg.noise.measurementBound;
if mod(step, cfg.observer.velocityMeasurementPeriod) ~= 0
    measurementLower(2, :) = -inf;
    measurementUpper(2, :) = inf;
end

for delayIndex = 1:numDelays
    delay = delayValues(delayIndex);
    [lowerPrediction, upperPrediction] = rrjfi.predictIntervalForDelay( ...
        lowerPrior, upperPrior, controlHistory, step, delay, cfg, adjacency);

    lowerPredictionAll(:, :, delayIndex) = lowerPrediction;
    upperPredictionAll(:, :, delayIndex) = upperPrediction;
    predictionWidth(:, :, delayIndex) = upperPrediction - lowerPrediction;
    for agent = 1:numAgents
        lowerCorrection = max(lowerPrediction(:, agent), measurementLower(:, agent));
        upperCorrection = min(upperPrediction(:, agent), measurementUpper(:, agent));
        if all(lowerCorrection <= upperCorrection)
            lowerBranch(:, agent, delayIndex) = lowerCorrection;
            upperBranch(:, agent, delayIndex) = upperCorrection;
            correctedWidth(:, agent, delayIndex) = upperCorrection - lowerCorrection;
            isRetained(agent, delayIndex) = true;
        end
    end
end

lowerHull = nan(2, numAgents);
upperHull = nan(2, numAgents);
maxBranchWidth = nan(2, numAgents);
hullExcess = nan(2, numAgents);
isConsistent = all(any(isRetained, 2));

for agent = 1:numAgents
    retained = find(isRetained(agent, :));
    if isempty(retained)
        continue
    end
    retainedLower = reshape(lowerBranch(:, agent, retained), 2, []);
    retainedUpper = reshape(upperBranch(:, agent, retained), 2, []);
    lowerHull(:, agent) = min(retainedLower, [], 2);
    upperHull(:, agent) = max(retainedUpper, [], 2);
    widths = retainedUpper - retainedLower;
    maxBranchWidth(:, agent) = max(widths, [], 2);
    hullExcess(:, agent) = upperHull(:, agent) - lowerHull(:, agent) - maxBranchWidth(:, agent);
end

update.lower = lowerHull;
update.upper = upperHull;
update.lowerBranch = lowerBranch;
update.upperBranch = upperBranch;
update.isRetained = isRetained;
update.isConsistent = isConsistent;
update.predictionWidth = predictionWidth;
update.lowerPrediction = lowerPredictionAll;
update.upperPrediction = upperPredictionAll;
update.correctedWidth = correctedWidth;
update.maxBranchWidth = maxBranchWidth;
update.hullExcess = max(hullExcess, 0);
end
