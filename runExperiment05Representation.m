%% E5: Neural-linear representation-dimension ablation
clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'))
addpath(fullfile(projectRoot, '02_training'))

trainingData = load(fullfile(projectRoot, '05_results', ...
    'trained_proposed_seed3101.mat'));
policy = trainingData.training;
cfg = rrjfi.defaultConfig(3);
dimensions = [4, 8, 16, 32, 48];
preparationSeed = 4401;
updateCount = 1200;
warmupCount = 100;

rows = cell(numel(dimensions), 1);
heads = cell(numel(dimensions), 1);
timingTraces = cell(numel(dimensions), 1);
for dimensionIndex = 1:numel(dimensions)
    dimension = dimensions(dimensionIndex);
    head = rrjfiTraining.prepareBayesianHead( ...
        policy, cfg, preparationSeed, dimension);
    heads{dimensionIndex} = head;

    weights = zeros(dimension, 1);
    covariance = cfg.trigger.priorScale .* eye(dimension);
    updateTimes = zeros(1, updateCount);
    for updateIndex = 1:updateCount
        feature = head.validationFeatures(:, updateIndex);
        target = head.validationTarget(updateIndex);
        startTime = tic;
        [weights, covariance] = rrjfiTraining.rlsUpdate( ...
            weights, covariance, feature, target, 1);
        updateTimes(updateIndex) = toc(startTime);
    end
    timingTraces{dimensionIndex} = updateTimes;

    heldOut = (updateCount + 1):size(head.validationFeatures, 2);
    prediction = weights.' * head.validationFeatures(:, heldOut);
    heldOutMse = mean((prediction - head.validationTarget(heldOut)).^2);
    referencePrediction = head.referenceWeights.' * head.validationFeatures(:, heldOut);
    referenceHeldOutMse = mean((referencePrediction - head.validationTarget(heldOut)).^2);
    fullGramian = head.validationFeatures(:, 1:updateCount) ...
        * head.validationFeatures(:, 1:updateCount).';
    exactPe = min(eig(fullGramian));
    gershgorinPe = rrjfi.gershgorinLowerBound(fullGramian);

    row.dimension = dimension;
    row.referenceValidationMse = head.referenceValidationMse;
    row.referenceHeldOutMse = referenceHeldOutMse;
    row.onlineHeldOutMse = heldOutMse;
    row.finalParameterError = norm(weights - head.referenceWeights);
    row.averageUpdateMicroseconds = 1e6 .* mean(updateTimes((warmupCount + 1):end));
    row.worstUpdateMicroseconds = 1e6 .* max(updateTimes((warmupCount + 1):end));
    row.covarianceMemoryKilobytes = 8 .* dimension^2 ./ 1024;
    row.totalHeadMemoryKilobytes = 8 .* ...
        (dimension^2 + dimension + dimension .* cfg.trigger.peWindow) ./ 1024;
    row.exactPeMargin = exactPe;
    row.gershgorinPeMargin = gershgorinPe;
    rows{dimensionIndex} = row;
end

resultTable = struct2table(vertcat(rows{:}));
writetable(resultTable, fullfile(cfg.paths.results, ...
    'E5_representation_ablation.csv'))

logDimension = log(resultTable.dimension);
timeFit = polyfit(logDimension, log(resultTable.averageUpdateMicroseconds), 1);
memoryFit = polyfit(logDimension, log(resultTable.covarianceMemoryKilobytes), 1);
scalingTable = table(timeFit(1), memoryFit(1), ...
    'VariableNames', {'measuredRuntimeLogSlope','covarianceMemoryLogSlope'});
writetable(scalingTable, fullfile(cfg.paths.results, ...
    'E5_representation_scaling.csv'))
save(fullfile(cfg.paths.results, 'E5_representation_full_results.mat'), ...
    'cfg', 'dimensions', 'heads', 'timingTraces', 'resultTable', 'scalingTable', '-v7.3')

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1080, 700]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
semilogy(dimensions, resultTable.referenceHeldOutMse, '-o', 'LineWidth', 1.25, ...
    'DisplayName', 'Reference head')
hold on
semilogy(dimensions, resultTable.onlineHeldOutMse, '-s', 'LineWidth', 1.25, ...
    'DisplayName', 'Online RLS')
xlabel('Bayesian-head dimension')
ylabel('Held-out MSE')
title('(a) Approximation and identification accuracy')
legend('Location', 'best')
grid on

nexttile
loglog(dimensions, resultTable.averageUpdateMicroseconds, '-o', 'LineWidth', 1.25)
xlabel('Bayesian-head dimension')
ylabel('Mean RLS update time (\mus)')
title(sprintf('(b) Measured scaling slope %.2f', timeFit(1)))
grid on

nexttile
loglog(dimensions, resultTable.totalHeadMemoryKilobytes, '-o', 'LineWidth', 1.25)
xlabel('Bayesian-head dimension')
ylabel('Head memory (KiB)')
title('(c) Full covariance and PE-window memory')
grid on

nexttile
semilogy(dimensions, max(resultTable.exactPeMargin, 1e-12), '-o', ...
    'LineWidth', 1.25, 'DisplayName', 'Exact minimum eigenvalue')
hold on
semilogy(dimensions, max(resultTable.gershgorinPeMargin, 1e-12), '--s', ...
    'LineWidth', 1.25, 'DisplayName', 'Gershgorin lower bound')
xlabel('Bayesian-head dimension')
ylabel('PE margin')
title('(d) Exact and conservative PE monitors')
legend('Location', 'best')
grid on
fontname(figureHandle, 'Times New Roman')
fontsize(figureHandle, 10, 'points')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, ...
    'E5_representation_ablation.pdf'), 'ContentType', 'vector')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, ...
    'E5_representation_ablation.png'), 'Resolution', 300)
savefig(figureHandle, fullfile(cfg.paths.figures, ...
    'E5_representation_ablation.fig'), 'compact')
close(figureHandle)

disp(resultTable)
disp(scalingTable)
