%% Train matched proposed and MADDPG policies on three reproducible seeds

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'));
addpath(fullfile(projectRoot, '02_training'));

cfg = rrjfi.defaultConfig(3);
cfg.training.numEpisodes = 60;
cfg.training.stepsPerEpisode = 140;
cfg.training.warmupSteps = 1000;
cfg.training.batchSize = 128;
cfg.training.replayCapacity = 40000;
cfg.training.actorLearningRate = 5e-5;
cfg.training.criticLearningRate = 4e-4;
cfg.reward.widthWeight = 0.45;
trainingSeeds = 3101:3103;
validationSeeds = 9101:9105;
variants = ["proposed", "maddpg"];
allTraining = cell(numel(variants), numel(trainingSeeds));
rows = cell(numel(variants) * numel(trainingSeeds), 1);
rowIndex = 0;

for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(trainingSeeds)
        tic;
        training = rrjfiTraining.trainPolicy(cfg, variants(variantIndex), trainingSeeds(seedIndex));
        training = rrjfiTraining.selectPolicySnapshot(training, cfg, validationSeeds);
        elapsedSeconds = toc;
        training.elapsedSeconds = elapsedSeconds;
        allTraining{variantIndex, seedIndex} = training;
        outputFile = sprintf('trained_%s_seed%d.mat', variants(variantIndex), trainingSeeds(seedIndex));
        save(fullfile(cfg.paths.results, outputFile), 'training', '-v7.3');

        rowIndex = rowIndex + 1;
        rows{rowIndex} = struct( ...
            'variant', variants(variantIndex), ...
            'seed', trainingSeeds(seedIndex), ...
            'selectedEpisode', training.selection.selectedEpisode, ...
            'validationScore', training.selection.score(training.selection.selectedIndex), ...
            'actorLipschitzBound', training.actorLipschitzBound, ...
            'environmentSteps', training.totalEnvironmentSteps, ...
            'gradientSteps', training.totalGradientSteps, ...
            'elapsedSeconds', elapsedSeconds);
    end
end

trainingSummary = struct2table(vertcat(rows{:}));
writetable(trainingSummary, fullfile(cfg.paths.results, 'training_summary.csv'));
save(fullfile(cfg.paths.results, 'training_all_seeds.mat'), ...
    'cfg', 'trainingSeeds', 'validationSeeds', 'allTraining', 'trainingSummary', '-v7.3');

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1000, 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for variantIndex = 1:numel(variants)
    nexttile;
    returns = zeros(cfg.training.numEpisodes, numel(trainingSeeds));
    for seedIndex = 1:numel(trainingSeeds)
        returns(:, seedIndex) = allTraining{variantIndex, seedIndex}.episodeReturn;
    end
    smoothed = movmean(returns, 7, 1);
    meanReturn = mean(smoothed, 2);
    standardDeviation = std(smoothed, 0, 2);
    episodes = (1:cfg.training.numEpisodes).';
    fill([episodes; flipud(episodes)], ...
        [meanReturn - standardDeviation; flipud(meanReturn + standardDeviation)], ...
        [0.82, 0.88, 0.98], 'EdgeColor', 'none', 'DisplayName', 'Mean \pm SD');
    hold on;
    plot(episodes, meanReturn, 'Color', [0.15, 0.30, 0.75], 'LineWidth', 1.4, ...
        'DisplayName', 'Mean return');
    xlabel('Training episode');
    ylabel('Episode return');
    title(sprintf('(%s) %s', char('a' + variantIndex - 1), char(upper(variants(variantIndex)))));
    legend('Location', 'best');
    grid on;
end
fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'training_curves.pdf'), 'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'training_curves.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(cfg.paths.figures, 'training_curves.fig'), 'compact');
close(figureHandle);

disp(trainingSummary);
