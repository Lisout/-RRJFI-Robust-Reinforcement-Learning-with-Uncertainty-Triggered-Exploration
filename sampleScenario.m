function scenario = sampleScenario(cfg, seed, task)
%SAMPLESCENARIO Generate deterministic parameters, delays, and bounded noise.

arguments
    cfg (1,1) struct
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    task (1,1) string {mustBeMember(task,["stabilization","tracking"])} = "tracking"
end

stream = RandStream('Threefry', 'Seed', seed);
numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;

scenario.sinGain = sampleBox(stream, cfg.model.sinGain, numAgents);
scenario.damping = sampleBox(stream, cfg.model.damping, numAgents);
scenario.inputGain = sampleBox(stream, cfg.model.inputGain, numAgents);
scenario.couplingGain = sampleBox(stream, cfg.model.couplingGain, numAgents);

position0 = -1.15 + 2.30 .* rand(stream, 1, numAgents);
velocity0 = -0.35 + 0.70 .* rand(stream, 1, numAgents);
scenario.initialState = [position0; velocity0];

delayValues = cfg.sim.delayValues;
numDelayValues = numel(delayValues);
delayIndex = randi(stream, numDelayValues, numAgents, 1);
scenario.delay = zeros(numAgents, numSteps);
for step = 1:numSteps
    if step > 1
        switchMask = rand(stream, numAgents, 1) < 0.18;
        proposed = randi(stream, numDelayValues, numAgents, 1);
        delayIndex(switchMask) = proposed(switchMask);
    end
    scenario.delay(:, step) = delayValues(delayIndex);
end

processScale = cfg.noise.randomProcessBound;
measurementScale = cfg.noise.measurementBound;
scenario.processNoise = (2 .* rand(stream, 2, numAgents, numSteps) - 1) .* ...
    reshape(processScale, 2, 1, 1);
scenario.measurementNoise = (2 .* rand(stream, 2, numAgents, numSteps + 1) - 1) .* ...
    reshape(measurementScale, 2, 1, 1);

scenario.disturbance = zeros(2, numAgents, numSteps);
pulseStart = round(0.58 * numSteps);
pulseLength = max(4, round(0.04 * numSteps));
pulseSigns = 2 .* (rand(stream, 1, numAgents) > 0.5) - 1;
scenario.disturbance(2, :, pulseStart:(pulseStart + pulseLength - 1)) = ...
    repmat(reshape(cfg.scenario.pulseAmplitude .* pulseSigns, 1, numAgents, 1), 1, 1, pulseLength);

time = (0:numSteps) .* cfg.sim.sampleTime;
[scenario.positionReference, scenario.velocityReference] = rrjfi.referenceSignal(time, task);
scenario.task = task;
scenario.seed = seed;
end

function samples = sampleBox(stream, bounds, count)
samples = bounds(1) + (bounds(2) - bounds(1)) .* rand(stream, 1, count);
end
