function projection = scaleSafeAction( ...
    desiredAction, backupAction, lowerState, upperState, controlHistory, step, cfg, adjacency)
%SCALESAFEACTION Find the largest certified interpolation toward a desired action.

arguments
    desiredAction (1,:) double
    backupAction (1,:) double
    lowerState (2,:) double
    upperState (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    cfg (1,1) struct
    adjacency double
end

desiredAction = min(max(desiredAction, -cfg.control.inputLimit), cfg.control.inputLimit);
backupAction = min(max(backupAction, -cfg.control.inputLimit), cfg.control.inputLimit);
scales = linspace(1, 0, 17);
isFeasible = false;
selectedScale = 0;
selectedAction = backupAction;

for scale = scales
    candidate = backupAction + scale .* (desiredAction - backupAction);
    trialHistory = controlHistory;
    trialHistory(:, step) = candidate.';
    [lowerNext, upperNext] = rrjfi.intervalSuccessor( ...
        lowerState, upperState, trialHistory, step, cfg, adjacency);
    widthNext = upperNext - lowerNext;
    safe = all(lowerNext(1, :) >= -cfg.control.safetyPosition) ...
        && all(upperNext(1, :) <= cfg.control.safetyPosition) ...
        && all(lowerNext(2, :) >= -cfg.control.safetyVelocity) ...
        && all(upperNext(2, :) <= cfg.control.safetyVelocity);
    widthAdmissible = all(widthNext <= cfg.control.recoveryWidthLimit, 'all');
    if safe && widthAdmissible
        selectedAction = candidate;
        selectedScale = scale;
        isFeasible = true;
        break
    end
end

projection.action = selectedAction;
projection.scale = selectedScale;
projection.isFeasible = isFeasible;
projection.wasProjected = selectedScale < 1 - 1e-12;
end

