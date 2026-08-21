%% Rebuild the editable training-curve figure without retraining
% This script reads the archived multi-seed training output and regenerates
% the PDF, PNG, and FIG artifacts used for supplementary reproducibility.

clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
archive = load(fullfile(projectRoot, '05_results', ...
    'training_all_seeds.mat'), 'cfg', 'allTraining');
cfg = archive.cfg;
allTraining = archive.allTraining;
variants = ["proposed", "maddpg"];
numSeeds = size(allTraining, 2);

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1000, 420]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for variantIndex = 1:numel(variants)
    nexttile;
    numEpisodes = numel(allTraining{variantIndex, 1}.episodeReturn);
    returns = zeros(numEpisodes, numSeeds);
    for seedIndex = 1:numSeeds
        returns(:, seedIndex) = ...
            allTraining{variantIndex, seedIndex}.episodeReturn;
    end
    smoothed = movmean(returns, 7, 1);
    meanReturn = mean(smoothed, 2);
    standardDeviation = std(smoothed, 0, 2);
    episodes = (1:numEpisodes).';
    fill([episodes; flipud(episodes)], ...
        [meanReturn - standardDeviation; ...
        flipud(meanReturn + standardDeviation)], ...
        [0.82, 0.88, 0.98], 'EdgeColor', 'none', ...
        'DisplayName', 'Mean \pm SD');
    hold on;
    plot(episodes, meanReturn, 'Color', [0.15, 0.30, 0.75], ...
        'LineWidth', 1.4, 'DisplayName', 'Mean return');
    xlabel('Training episode');
    ylabel('Episode return');
    title(sprintf('(%s) %s', char('a' + variantIndex - 1), ...
        char(upper(variants(variantIndex)))));
    legend('Location', 'best');
    grid on;
end
fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');

figureFolder = fullfile(projectRoot, '06_figures');
exportgraphics(figureHandle, fullfile(figureFolder, ...
    'training_curves.pdf'), 'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(figureFolder, ...
    'training_curves.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(figureFolder, ...
    'training_curves.fig'), 'compact');
close(figureHandle);

fprintf('Regenerated training curves from %d variants and %d seeds.\n', ...
    numel(variants), numSeeds);
