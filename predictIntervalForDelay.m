function [lowerNext, upperNext] = predictIntervalForDelay( ...
    lowerState, upperState, controlHistory, step, delay, cfg, adjacency)
%PREDICTINTERVALFORDELAY Enclose one plant step for a specified delay mode.

arguments
    lowerState (2,:) double
    upperState (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    delay (1,1) double {mustBeInteger,mustBeNonnegative}
    cfg (1,1) struct
    adjacency double
end

numAgents = size(lowerState, 2);
dt = cfg.sim.sampleTime;
lowerNext = zeros(size(lowerState));
upperNext = zeros(size(upperState));

[lowerSin, upperSin] = rrjfi.sinInterval(lowerState(1, :), upperState(1, :));
[lowerSinTerm, upperSinTerm] = rrjfi.intervalMultiply( ...
    cfg.model.sinGain(1), cfg.model.sinGain(2), lowerSin, upperSin);
[lowerDampingTerm, upperDampingTerm] = rrjfi.intervalMultiply( ...
    -cfg.model.damping(2), -cfg.model.damping(1), lowerState(2, :), upperState(2, :));

inputIndex = step - delay;
if inputIndex >= 1
    delayedInput = controlHistory(:, inputIndex).';
else
    delayedInput = zeros(1, numAgents);
end
[lowerInputTerm, upperInputTerm] = rrjfi.intervalMultiply( ...
    cfg.model.inputGain(1), cfg.model.inputGain(2), delayedInput, delayedInput);

degree = full(sum(adjacency, 2)).';
weightedLower = (adjacency * lowerState(1, :).').';
weightedUpper = (adjacency * upperState(1, :).').';
lowerRelative = weightedLower - degree .* upperState(1, :);
upperRelative = weightedUpper - degree .* lowerState(1, :);
[lowerCoupling, upperCoupling] = rrjfi.intervalMultiply( ...
    cfg.model.couplingGain(1), cfg.model.couplingGain(2), lowerRelative, upperRelative);

lowerAcceleration = lowerSinTerm + lowerDampingTerm + lowerInputTerm + lowerCoupling;
upperAcceleration = upperSinTerm + upperDampingTerm + upperInputTerm + upperCoupling;
lowerNext(1, :) = lowerState(1, :) + dt .* lowerState(2, :) ...
    + 0.5 .* dt^2 .* lowerAcceleration - cfg.noise.processBound(1);
upperNext(1, :) = upperState(1, :) + dt .* upperState(2, :) ...
    + 0.5 .* dt^2 .* upperAcceleration + cfg.noise.processBound(1);
lowerNext(2, :) = lowerState(2, :) + dt .* lowerAcceleration ...
    - cfg.noise.processBound(2);
upperNext(2, :) = upperState(2, :) + dt .* upperAcceleration ...
    + cfg.noise.processBound(2);
end
