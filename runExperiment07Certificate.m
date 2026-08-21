%% E7: Post-training switched-linear common-Lyapunov audit
clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'))
addpath(fullfile(projectRoot, '02_training'))

trainingData = load(fullfile(projectRoot, '05_results', ...
    'trained_proposed_seed3101.mat'));
policy = trainingData.training;
cfg = rrjfi.defaultConfig(3);
numAgents = cfg.sim.numAgents;
adjacency = rrjfi.makeRingGraph(numAgents);
laplacian = diag(full(sum(adjacency, 2))) - full(adjacency);

equilibriumObservation = zeros(10, 1);
equilibriumObservation(5) = 0.5;
equilibriumObservation(6) = 1;
equilibriumObservation(10) = 1;
equilibriumResidual = rrjfiTraining.actorForward( ...
    policy.actor, equilibriumObservation);
actorJacobian = finiteDifferenceJacobian(policy.actor, equilibriumObservation);

residualPositionGain = (actorJacobian(1) + actorJacobian(7)) ...
    ./ cfg.control.safetyPosition;
residualVelocityGain = (actorJacobian(2) + actorJacobian(8)) ...
    ./ cfg.control.safetyVelocity;
residualRelativeGain = actorJacobian(9) ./ cfg.control.safetyPosition;
positionFeedback = (-cfg.control.positionGain + residualPositionGain) ...
    .* eye(numAgents) - (cfg.control.consensusGain + residualRelativeGain) .* laplacian;
velocityFeedback = (-cfg.control.velocityGain + residualVelocityGain) .* eye(numAgents);
feedbackGain = [positionFeedback, velocityFeedback];

parameterVertices = makeParameterVertices(cfg, numAgents);
delayPatterns = makeDelayPatterns(cfg.sim.delayValues, numAgents);
homogeneousVertices = makeHomogeneousVertices(cfg, numAgents);
activeMatrices = cell(0, 1);
for vertexIndex = 1:size(homogeneousVertices, 1)
    parameters = homogeneousVertices(vertexIndex, :);
    for delayIndex = 1:size(delayPatterns, 1)
        activeMatrices{end + 1, 1} = makeAugmentedMatrix( ...
            cfg, feedbackGain, laplacian, parameters, delayPatterns(delayIndex, :)); %#ok<SAGROW>
    end
end

stream = RandStream('Threefry', 'Seed', 9901);
randomVertexIndex = randperm(stream, size(parameterVertices, 1), 160);
randomDelayIndex = randi(stream, size(delayPatterns, 1), 160, 1);
for sampleIndex = 1:numel(randomVertexIndex)
    activeMatrices{end + 1, 1} = makeAugmentedMatrix( ...
        cfg, feedbackGain, laplacian, parameterVertices(randomVertexIndex(sampleIndex), :), ...
        delayPatterns(randomDelayIndex(sampleIndex), :)); %#ok<SAGROW>
end

targetContraction = 0.999;
maximumIterations = 18;
certificateFeasible = false;
historyRows = cell(maximumIterations, 1);
usedIterations = 0;
commonP = [];
worst = struct;
for iteration = 1:maximumIterations
    usedIterations = iteration;
    [commonP, subsetFeasible, feasibilityMargin] = solveCommonLyapunov( ...
        activeMatrices, targetContraction);
    history.iteration = iteration;
    history.activeConstraintCount = numel(activeMatrices);
    history.subsetFeasible = subsetFeasible;
    history.feasibilityMargin = feasibilityMargin;
    if ~subsetFeasible
        history.fullBoxContraction = NaN;
        historyRows{iteration} = history;
        break
    end

    worst = scanAllModes(commonP, cfg, feedbackGain, laplacian, ...
        parameterVertices, delayPatterns);
    history.fullBoxContraction = worst.contraction;
    history.maximumFrozenSpectralRadius = worst.maximumFrozenSpectralRadius;
    historyRows{iteration} = history;
    fprintf('Certificate iteration %d: active=%d, full-box factor=%.8f\n', ...
        iteration, numel(activeMatrices), worst.contraction)
    if worst.contraction <= targetContraction + 2e-7
        certificateFeasible = true;
        break
    end
    activeMatrices{end + 1, 1} = worst.matrix; %#ok<SAGROW>
end

historyRows = historyRows(1:usedIterations);
historyTable = struct2table(vertcat(historyRows{:}));
writetable(historyTable, fullfile(cfg.paths.results, ...
    'E7_certificate_constraint_generation.csv'))

summary.actorResidualAtEquilibrium = equilibriumResidual;
summary.actorJacobianNorm = norm(actorJacobian, 2);
summary.reportedActorLipschitzBound = policy.actorLipschitzBound;
summary.residualPositionGain = residualPositionGain;
summary.residualVelocityGain = residualVelocityGain;
summary.residualRelativeGain = residualRelativeGain;
summary.parameterVertexCount = size(parameterVertices, 1);
summary.asynchronousDelayPatternCount = size(delayPatterns, 1);
summary.totalEnumeratedModes = size(parameterVertices, 1) * size(delayPatterns, 1);
summary.targetContraction = targetContraction;
summary.certificateFeasible = certificateFeasible;
if isempty(commonP)
    summary.commonPConditionNumber = NaN;
else
    summary.commonPConditionNumber = cond(commonP);
end
if isfield(worst, 'contraction')
    summary.worstCertifiedContraction = worst.contraction;
    summary.maximumFrozenSpectralRadius = worst.maximumFrozenSpectralRadius;
    summary.worstParameterVertexIndex = worst.parameterVertexIndex;
    summary.worstDelayPatternIndex = worst.delayPatternIndex;
else
    summary.worstCertifiedContraction = NaN;
    summary.maximumFrozenSpectralRadius = NaN;
    summary.worstParameterVertexIndex = NaN;
    summary.worstDelayPatternIndex = NaN;
end
summaryTable = struct2table(summary);
writetable(summaryTable, fullfile(cfg.paths.results, 'E7_certificate_summary.csv'))
save(fullfile(cfg.paths.results, 'E7_certificate_full_results.mat'), ...
    'cfg', 'policy', 'actorJacobian', 'equilibriumObservation', ...
    'equilibriumResidual', 'feedbackGain', 'commonP', 'summaryTable', ...
    'historyTable', 'worst', '-v7.3')

figureHandle = figure('Color', 'w', 'Position', [100, 100, 850, 430]);
certificateValues = [policy.actorLipschitzBound, ...
    summary.maximumFrozenSpectralRadius, summary.worstCertifiedContraction];
bar(certificateValues, 0.62, 'FaceColor', [0.25, 0.52, 0.78])
hold on
yline(1, 'k--', 'Unit-stability boundary', 'LineWidth', 1.1)
xticks(1:3)
xticklabels({'Residual Actor bound','Frozen-mode radius','Common-P factor'})
xtickangle(12)
ylabel('Certified / audited value')
ylim([0, 1.08])
title(sprintf('Post-training audit of %d endpoint-delay modes', ...
    summary.totalEnumeratedModes))
text(2, 0.10, sprintf('P condition number: %.2f', summary.commonPConditionNumber), ...
    'HorizontalAlignment', 'center')
grid on
fontname(figureHandle, 'Times New Roman')
fontsize(figureHandle, 10, 'points')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, ...
    'E7_common_lyapunov_certificate.pdf'), 'ContentType', 'vector')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, ...
    'E7_common_lyapunov_certificate.png'), 'Resolution', 300)
savefig(figureHandle, fullfile(cfg.paths.figures, ...
    'E7_common_lyapunov_certificate.fig'), 'compact')
close(figureHandle)

disp(summaryTable)
disp(historyTable)

function jacobian = finiteDifferenceJacobian(actor, observation)
stepSize = 1e-5;
jacobian = zeros(1, numel(observation));
for element = 1:numel(observation)
    perturbation = zeros(size(observation));
    perturbation(element) = stepSize;
    plus = rrjfiTraining.actorForward(actor, observation + perturbation);
    minus = rrjfiTraining.actorForward(actor, observation - perturbation);
    jacobian(element) = (plus - minus) ./ (2 .* stepSize);
end
end

function vertices = makeParameterVertices(cfg, numAgents)
bitCount = 4 * numAgents;
bits = dec2bin(0:(2^bitCount - 1), bitCount) - '0';
vertices = zeros(size(bits));
bounds = [repmat([-max(abs(cfg.model.sinGain)), max(abs(cfg.model.sinGain))], numAgents, 1); ...
    repmat(cfg.model.damping, numAgents, 1); ...
    repmat(cfg.model.inputGain, numAgents, 1); ...
    repmat(cfg.model.couplingGain, numAgents, 1)];
for column = 1:bitCount
    vertices(:, column) = bounds(column, 1) ...
        + bits(:, column) .* (bounds(column, 2) - bounds(column, 1));
end
end

function vertices = makeHomogeneousVertices(cfg, numAgents)
bits = dec2bin(0:15, 4) - '0';
bounds = [-max(abs(cfg.model.sinGain)), max(abs(cfg.model.sinGain)); ...
    cfg.model.damping; cfg.model.inputGain; cfg.model.couplingGain];
vertices = zeros(size(bits, 1), 4 * numAgents);
for row = 1:size(bits, 1)
    values = bounds(:, 1) + bits(row, :).' .* (bounds(:, 2) - bounds(:, 1));
    vertices(row, :) = [repmat(values(1), 1, numAgents), ...
        repmat(values(2), 1, numAgents), repmat(values(3), 1, numAgents), ...
        repmat(values(4), 1, numAgents)];
end
end

function patterns = makeDelayPatterns(delayValues, numAgents)
grid = cell(1, numAgents);
[grid{:}] = ndgrid(delayValues);
patterns = zeros(numel(grid{1}), numAgents);
for agent = 1:numAgents
    patterns(:, agent) = grid{agent}(:);
end
end

function matrix = makeAugmentedMatrix(cfg, feedbackGain, laplacian, parameters, delays)
numAgents = cfg.sim.numAgents;
stateDimension = 2 * numAgents;
augmentedDimension = stateDimension * 3;
dt = cfg.sim.sampleTime;
sinSlope = parameters(1:numAgents);
damping = parameters((numAgents + 1):(2 * numAgents));
inputGain = parameters((2 * numAgents + 1):(3 * numAgents));
coupling = parameters((3 * numAgents + 1):(4 * numAgents));

accelerationPosition = diag(sinSlope) - diag(coupling) * laplacian;
accelerationVelocity = -diag(damping);
plant = [eye(numAgents) + 0.5 .* dt^2 .* accelerationPosition, ...
    dt .* eye(numAgents) + 0.5 .* dt^2 .* accelerationVelocity; ...
    dt .* accelerationPosition, eye(numAgents) + dt .* accelerationVelocity];

matrix = zeros(augmentedDimension);
matrix(1:stateDimension, 1:stateDimension) = plant;
for agent = 1:numAgents
    inputColumnBlock = delays(agent) + 1;
    columns = (inputColumnBlock - 1) * stateDimension + (1:stateDimension);
    inputVector = zeros(stateDimension, 1);
    inputVector(agent) = 0.5 .* dt^2 .* inputGain(agent);
    inputVector(numAgents + agent) = dt .* inputGain(agent);
    matrix(1:stateDimension, columns) = matrix(1:stateDimension, columns) ...
        + inputVector * feedbackGain(agent, :);
end
matrix((stateDimension + 1):(2 * stateDimension), 1:stateDimension) = eye(stateDimension);
matrix((2 * stateDimension + 1):(3 * stateDimension), ...
    (stateDimension + 1):(2 * stateDimension)) = eye(stateDimension);
end

function [P, feasible, margin] = solveCommonLyapunov(matrices, contraction)
setlmis([])
dimension = size(matrices{1}, 1);
Pvariable = lmivar(1, [dimension, 1]);
positivityLmi = newlmi;
lmiterm([positivityLmi, 1, 1, Pvariable], -1, 1)
lmiterm([positivityLmi, 1, 1, 0], eye(dimension))
for index = 1:numel(matrices)
    current = matrices{index};
    contractionLmi = newlmi;
    lmiterm([contractionLmi, 1, 1, Pvariable], current.', current)
    lmiterm([contractionLmi, 1, 1, Pvariable], -contraction^2, 1)
end
lmiSystem = getlmis;
options = [0, 250, 0, 0, 1];
[margin, feasiblePoint] = feasp(lmiSystem, options);
feasible = isfinite(margin) && margin < -1e-8;
if feasible
    P = dec2mat(lmiSystem, feasiblePoint, Pvariable);
    P = 0.5 .* (P + P.');
else
    P = [];
end
end

function worst = scanAllModes(P, cfg, feedbackGain, laplacian, vertices, patterns)
worst.contraction = -inf;
worst.maximumFrozenSpectralRadius = -inf;
worst.parameterVertexIndex = NaN;
worst.delayPatternIndex = NaN;
worst.matrix = [];
for vertexIndex = 1:size(vertices, 1)
    parameters = vertices(vertexIndex, :);
    for delayIndex = 1:size(patterns, 1)
        current = makeAugmentedMatrix( ...
            cfg, feedbackGain, laplacian, parameters, patterns(delayIndex, :));
        generalizedEigenvalues = eig(current.' * P * current, P);
        contraction = sqrt(max(real(generalizedEigenvalues)));
        frozenRadius = max(abs(eig(current)));
        worst.maximumFrozenSpectralRadius = max( ...
            worst.maximumFrozenSpectralRadius, frozenRadius);
        if contraction > worst.contraction
            worst.contraction = contraction;
            worst.parameterVertexIndex = vertexIndex;
            worst.delayPatternIndex = delayIndex;
            worst.matrix = current;
        end
    end
end
end
