function batch = sampleReplay(replay, batchSize, stream)
%SAMPLEREPLAY Draw a reproducible minibatch with replacement.

arguments
    replay (1,1) struct
    batchSize (1,1) double {mustBeInteger,mustBePositive}
    stream (1,1) RandStream
end

indices = randi(stream, replay.count, 1, batchSize);
batch.observation = double(replay.observation(:, indices));
batch.action = double(replay.action(:, indices));
batch.lowerReward = double(replay.lowerReward(:, indices));
batch.upperReward = double(replay.upperReward(:, indices));
batch.nextObservation = double(replay.nextObservation(:, indices));
batch.done = double(replay.done(:, indices));
end

