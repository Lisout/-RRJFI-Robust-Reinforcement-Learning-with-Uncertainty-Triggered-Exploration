%% Experiment E1: DC-IDO containment, delay refinement, and hull conservatism

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'));

cfg = rrjfi.defaultConfig(3);
cfg.sim.numSteps = 360;
seeds = 2101:2120;
episodes = cell(numel(seeds), 1);
metricRows = cell(numel(seeds), 1);

for index = 1:numel(seeds)
    episodes{index} = rrjfi.simulateObserverScenario(cfg, seeds(index), "tracking");
    metricRows{index} = episodes{index}.metrics;
end

metrics = struct2table(vertcat(metricRows{:}));
summary = table(string(metrics.Properties.VariableNames).', ...
    zeros(width(metrics), 1), zeros(width(metrics), 1), zeros(width(metrics), 1), zeros(width(metrics), 1), ...
    'VariableNames', {'Metric','Mean','Std','Minimum','Maximum'});
for column = 1:width(metrics)
    values = metrics{:, column};
    summary.Mean(column) = mean(values);
    summary.Std(column) = std(values);
    summary.Minimum(column) = min(values);
    summary.Maximum(column) = max(values);
end

resultsFolder = cfg.paths.results;
figuresFolder = cfg.paths.figures;
if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end
if ~isfolder(figuresFolder)
    mkdir(figuresFolder);
end
writetable(metrics, fullfile(resultsFolder, 'E1_observer_seed_metrics.csv'));
writetable(summary, fullfile(resultsFolder, 'E1_observer_summary.csv'));
save(fullfile(resultsFolder, 'E1_observer_full_results.mat'), 'cfg', 'seeds', 'episodes', 'metrics', 'summary', '-v7.3');

representative = episodes{1};
time = (0:cfg.sim.numSteps) .* cfg.sim.sampleTime;
agent = 1;
figureHandle = figure('Color', 'w', 'Position', [80, 80, 1380, 760]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
actualLower = squeeze(representative.lower(1, agent, :)).';
actualUpper = squeeze(representative.upper(1, agent, :)).';
hullMidpoint = 0.5*(actualLower + actualUpper);
visualHalfWidthScale = 4;
displayHalfWidth = 0.5*visualHalfWidthScale*(actualUpper - actualLower);
fill([time, fliplr(time)], ...
    [hullMidpoint - displayHalfWidth, fliplr(hullMidpoint + displayHalfWidth)], ...
    [0.72, 0.84, 1.00], 'EdgeColor', 'none', 'FaceAlpha', 0.75, ...
    'DisplayName', 'DC-IDO hull (4x half-width; display only)');
hold on;
plot(time, actualLower, '-', 'Color', [0.15, 0.45, 0.85], 'LineWidth', 0.7, ...
    'DisplayName', 'Actual DC-IDO bounds');
plot(time, actualUpper, '-', 'Color', [0.15, 0.45, 0.85], 'LineWidth', 0.7, ...
    'HandleVisibility', 'off');
plot(time, squeeze(representative.state(1, agent, :)), 'k-', 'LineWidth', 1.2, 'DisplayName', 'True state');
xlabel('Time (s)');
ylabel('Position');
title('(a) State enclosure under the identifying probe');
legend('Location', 'best');
grid on;

nexttile;
stairs(time(2:end), representative.delayCardinality(agent, :), 'b-', 'LineWidth', 1.2, ...
    'DisplayName', 'Retained-set cardinality');
hold on;
stairs(time(2:end), representative.scenario.delay(agent, :), 'k--', 'LineWidth', 1.0, ...
    'DisplayName', 'True delay (samples)');
xlabel('Time (s)');
ylabel('Cardinality / delay');
title('(b) Measurement-consistent delay refinement');
legend('Location', 'best');
grid on;

nexttile;
semilogy(time(2:end), max(representative.hullInflation(agent, :), 1e-8), 'Color', [0.20, 0.55, 0.25], ...
    'LineWidth', 1.2, 'DisplayName', 'Hull inflation ratio');
hold on;
semilogy(time(2:end), max(squeeze(vecnorm(representative.hullExcess(:, agent, :), 2, 1)), 1e-8), ...
    'Color', [0.70, 0.30, 0.10], 'LineWidth', 1.0, 'DisplayName', 'Hull width excess');
xlabel('Time (s)');
ylabel('Conservatism metric');
title('(c) Hull over-approximation');
legend('Location', 'best');
grid on;

nexttile;
semilogy(time(2:end), max(representative.rewardWidthPrior, 1e-7), '--', ...
    'Color', [0.45, 0.45, 0.45], ...
    'LineWidth', 1.1, 'DisplayName', 'A-priori delay set');
hold on;
semilogy(time(2:end), max(representative.rewardWidthRefined, 1e-7), ...
    'Color', [0.20, 0.35, 0.80], ...
    'LineWidth', 1.2, 'DisplayName', 'Measurement-refined set');
xlabel('Time (s)');
ylabel('One-step robust reward width');
title('(d) Observer-to-value uncertainty interface');
legend('Location', 'best');
grid on;

fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');
exportgraphics(figureHandle, fullfile(figuresFolder, 'E1_observer_and_hull.pdf'), 'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(figuresFolder, 'E1_observer_and_hull.png'), 'Resolution', 300);
savefig(figureHandle, fullfile(figuresFolder, 'E1_observer_and_hull.fig'), 'compact');
close(figureHandle);

disp(summary);
