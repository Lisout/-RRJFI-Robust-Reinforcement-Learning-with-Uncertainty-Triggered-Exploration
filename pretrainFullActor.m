function actor = pretrainFullActor(actor, cfg, seed)
%PRETRAINFULLACTOR Initialize a full-action Actor from the matched feedback prior.

arguments
    actor (1,1) struct
    cfg (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

stream = RandStream('Threefry', 'Seed', seed);
sampleCount = 6000;
observation = zeros(actor.inputDimension, sampleCount);
observation(1:2, :) = 1.2 .* (2 .* rand(stream, 2, sampleCount) - 1);
observation(3:4, :) = 0.25 .* rand(stream, 2, sampleCount);
observation(5:6, :) = rand(stream, 2, sampleCount);
observation(7:9, :) = 1.2 .* (2 .* rand(stream, 3, sampleCount) - 1);
observation(10, :) = rand(stream, 1, sampleCount);
target = rrjfi.nominalActionFromObservation(observation, cfg);

state = struct;
iteration = 0;
batchSize = 256;
for epoch = 1:450
    indices = randi(stream, sampleCount, 1, batchSize);
    batch = observation(:, indices);
    targetBatch = target(:, indices);
    [action, cache] = rrjfiTraining.actorForward(actor, batch);
    derivative = 2 .* (action - targetBatch) ./ batchSize;
    gradients = rrjfiTraining.actorBackward(actor, cache, derivative);
    iteration = iteration + 1;
    [actor.parameters, state] = rrjfiTraining.adamStep( ...
        actor.parameters, gradients, state, 8e-4, iteration);
end
end

