function head = prepareBayesianHead(policy, cfg, seed, featureDimension)
%PREPAREBAYESIANHEAD Fit a compact full-covariance neural-linear bottleneck.

arguments
    policy (1,1) struct
    cfg (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    featureDimension (1,1) double {mustBeInteger,mustBeGreaterThan(featureDimension,1)} = 16
end

stream = RandStream('Threefry', 'Seed', seed);
numAgents = cfg.sim.numAgents;
observationDimension = 10;
sampleCount = 7000;
jointObservation = zeros(observationDimension * numAgents, sampleCount);
for sample = 1:sampleCount
    local = zeros(observationDimension, numAgents);
    local(1:2, :) = 1.1 .* (2 .* rand(stream, 2, numAgents) - 1);
    local(3:4, :) = 0.30 .* rand(stream, 2, numAgents);
    local(5:6, :) = rand(stream, 2, numAgents);
    local(7:9, :) = 1.1 .* (2 .* rand(stream, 3, numAgents) - 1);
    local(10, :) = rand(stream, 1, numAgents);
    jointObservation(:, sample) = local(:);
end
localObservation = reshape(jointObservation, observationDimension, []);
residual = rrjfiTraining.actorForward(policy.actor, localObservation);
nominal = rrjfi.nominalActionFromObservation(localObservation, cfg);
action = reshape(nominal + residual, numAgents, sampleCount);
action = action + 0.35 .* randn(stream, size(action));
action = min(max(action, -cfg.control.inputLimit), cfg.control.inputLimit);

criticInput = [jointObservation; action];
[target, ~, deepFeatures] = rrjfiTraining.criticForward(policy.lowerCritic, criticInput);
trainingCount = 5000;
deepTraining = deepFeatures(:, 1:trainingCount).';
center = mean(deepTraining, 1).';
[coefficients, scores] = pca(deepTraining, 'Centered', true);
reducedDimension = featureDimension - 1;
projection = coefficients(:, 1:reducedDimension).';
scale = std(scores(:, 1:reducedDimension), 0, 1).';
scale = max(scale, 1e-5);

features = makeFeatures(deepFeatures, projection, center, scale, featureDimension);
trainingFeatures = features(:, 1:trainingCount);
trainingTarget = target(:, 1:trainingCount);
regularization = 1e-5;
referenceWeights = (trainingFeatures * trainingFeatures.' ...
    + regularization .* eye(featureDimension)) \ (trainingFeatures * trainingTarget.');

validationFeatures = features(:, (trainingCount + 1):end);
validationTarget = target(:, (trainingCount + 1):end);
validationPrediction = referenceWeights.' * validationFeatures;

head.featureDimension = featureDimension;
head.projection = projection;
head.center = center;
head.scale = scale;
head.referenceWeights = referenceWeights;
head.validationFeatures = validationFeatures;
head.validationTarget = validationTarget;
head.referenceValidationMse = mean((validationPrediction - validationTarget).^2);
head.seed = seed;
end

function features = makeFeatures(deepFeatures, projection, center, scale, featureDimension)
centered = deepFeatures - center;
reduced = (projection * centered) ./ scale;
features = [reduced; ones(1, size(reduced, 2))] ./ sqrt(featureDimension);
end

