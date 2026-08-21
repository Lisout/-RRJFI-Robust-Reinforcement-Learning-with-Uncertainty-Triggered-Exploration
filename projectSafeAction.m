function projection = projectSafeAction( ...
    desiredAction, lowerState, upperState, controlHistory, step, cfg, adjacency)
%PROJECTSAFEACTION Project a joint action onto the certified one-step set.
%   The grid search is deterministic. Safety and interval-width constraints
%   are checked for every admissible delay and model parameter realization.

arguments
    desiredAction (1,:) double
    lowerState (2,:) double
    upperState (2,:) double
    controlHistory double
    step (1,1) double {mustBeInteger,mustBePositive}
    cfg (1,1) struct
    adjacency double
end

numAgents = numel(desiredAction);
appliedAction = min(max(desiredAction, -cfg.control.inputLimit), cfg.control.inputLimit);
isFeasible = true(1, numAgents);
wasProjected = false(1, numAgents);
candidateGrid = linspace(-cfg.control.inputLimit, cfg.control.inputLimit, cfg.control.safetyGridSize);

for agent = 1:numAgents
    [~, order] = sort(abs(candidateGrid - desiredAction(agent)));
    found = false;
    for candidateIndex = order
        trialHistory = controlHistory;
        trialHistory(:, step) = appliedAction.';
        trialHistory(agent, step) = candidateGrid(candidateIndex);
        [lowerNext, upperNext] = rrjfi.intervalSuccessor( ...
            lowerState, upperState, trialHistory, step, cfg, adjacency);
        widthNext = upperNext(:, agent) - lowerNext(:, agent);
        safe = lowerNext(1, agent) >= -cfg.control.safetyPosition ...
            && upperNext(1, agent) <= cfg.control.safetyPosition ...
            && lowerNext(2, agent) >= -cfg.control.safetyVelocity ...
            && upperNext(2, agent) <= cfg.control.safetyVelocity;
        widthAdmissible = all(widthNext <= cfg.control.recoveryWidthLimit);
        if safe && widthAdmissible
            appliedAction(agent) = candidateGrid(candidateIndex);
            found = true;
            break
        end
    end
    if ~found
        isFeasible(agent) = false;
    end
    wasProjected(agent) = abs(appliedAction(agent) - desiredAction(agent)) > 1e-10;
end

projection.action = appliedAction;
projection.isFeasible = isFeasible;
projection.wasProjected = wasProjected;
projection.certified = all(isFeasible);
end

