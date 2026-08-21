function replay = initializeReplay(observationDimension, numAgents, capacity)
%INITIALIZEREPLAY Preallocate a deterministic joint replay buffer.

arguments
    observationDimension (1,1) double {mustBeInteger,mustBePositive}
    numAgents (1,1) double {mustBeInteger,mustBePositive}
    capacity (1,1) double {mustBeInteger,mustBePositive}
end

jointDimension = observationDimension * numAgents;
replay.observation = zeros(jointDimension, capacity, 'single');
replay.action = zeros(numAgents, capacity, 'single');
replay.lowerReward = zeros(1, capacity, 'single');
replay.upperReward = zeros(1, capacity, 'single');
replay.nextObservation = zeros(jointDimension, capacity, 'single');
replay.done = false(1, capacity);
replay.capacity = capacity;
replay.count = 0;
replay.position = 0;
end

