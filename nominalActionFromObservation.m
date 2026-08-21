function action = nominalActionFromObservation(observation, cfg)
%NOMINALACTIONFROMOBSERVATION Evaluate the transparent residual-policy scaffold.

arguments
    observation (10,:) double
    cfg (1,1) struct
end

positionError = observation(7, :) .* cfg.control.safetyPosition;
velocityError = observation(8, :) .* cfg.control.safetyVelocity;
relativePosition = observation(9, :) .* cfg.control.safetyPosition;
position = observation(1, :) .* cfg.control.safetyPosition;
velocity = observation(2, :) .* cfg.control.safetyVelocity;
positionReference = position - positionError;
velocityReference = velocity - velocityError;
referenceAcceleration = -(0.42^2) .* positionReference;
preview = cfg.control.referencePreview;
previewPosition = positionReference + preview .* velocityReference ...
    + 0.5 * preview^2 .* referenceAcceleration;
previewVelocity = velocityReference + preview .* referenceAcceleration;
positionError = position - previewPosition;
velocityError = velocity - previewVelocity;
feedforward = (referenceAcceleration ...
    - mean(cfg.model.sinGain) .* sin(positionReference) ...
    + mean(cfg.model.damping) .* velocityReference) ./ mean(cfg.model.inputGain);
action = -cfg.control.positionGain .* positionError ...
    - cfg.control.velocityGain .* velocityError ...
    + cfg.control.consensusGain .* relativePosition + feedforward;
action = min(max(action, -cfg.control.inputLimit), cfg.control.inputLimit);
end
