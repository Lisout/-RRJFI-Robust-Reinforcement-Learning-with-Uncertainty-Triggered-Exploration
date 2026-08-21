%% E6: Online scalability of the distributed interval observer and shared Actor
clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'))
addpath(fullfile(projectRoot, '02_training'))

trainingData = load(fullfile(projectRoot, '05_results', ...
    'trained_proposed_seed3101.mat'));
policy = trainingData.training;
agentCounts = [3, 10, 25, 50, 100, 200];
seeds = 8301:8305;
rows = cell(numel(agentCounts) * numel(seeds), 1);
rowIndex = 0;

for countIndex = 1:numel(agentCounts)
    cfg = rrjfi.defaultConfig(agentCounts(countIndex));
    cfg.sim.numSteps = 180;
    for seedIndex = 1:numel(seeds)
        rowIndex = rowIndex + 1;
        rows{rowIndex} = benchmarkConfiguration(cfg, policy, seeds(seedIndex));
    end
end

rawTable = struct2table(vertcat(rows{:}));
writetable(rawTable, fullfile(projectRoot, '05_results', ...
    'E6_scalability_raw_metrics.csv'))

summaryRows = cell(numel(agentCounts), 1);
for countIndex = 1:numel(agentCounts)
    selected = rawTable(rawTable.numAgents == agentCounts(countIndex), :);
    row.numAgents = agentCounts(countIndex);
    row.meanObserverMicroseconds = mean(selected.meanObserverMicroseconds);
    row.stdObserverMicroseconds = std(selected.meanObserverMicroseconds);
    row.meanObserverPerAgentMicroseconds = mean(selected.observerPerAgentMicroseconds);
    row.meanActorMicroseconds = mean(selected.meanActorMicroseconds);
    row.meanEndToEndMicroseconds = mean(selected.meanEndToEndMicroseconds);
    row.meanPeakObserverMemoryKilobytes = mean(selected.peakObserverMemoryKilobytes);
    row.minimumContainmentRate = min(selected.containmentRate);
    row.minimumDelayRetentionRate = min(selected.delayRetentionRate);
    row.maximumMeanPositionWidth = max(selected.meanPositionWidth);
    summaryRows{countIndex} = row;
end
summaryTable = struct2table(vertcat(summaryRows{:}));
writetable(summaryTable, fullfile(projectRoot, '05_results', ...
    'E6_scalability_summary.csv'))

observerFit = polyfit(log(summaryTable.numAgents), ...
    log(summaryTable.meanObserverMicroseconds), 1);
actorFit = polyfit(log(summaryTable.numAgents), ...
    log(summaryTable.meanActorMicroseconds), 1);
memoryFit = polyfit(log(summaryTable.numAgents), ...
    log(summaryTable.meanPeakObserverMemoryKilobytes), 1);
scalingTable = table(observerFit(1), actorFit(1), memoryFit(1), ...
    'VariableNames', {'observerRuntimeLogSlope','actorRuntimeLogSlope', ...
    'observerMemoryLogSlope'});
writetable(scalingTable, fullfile(projectRoot, '05_results', ...
    'E6_scalability_log_slopes.csv'))
save(fullfile(projectRoot, '05_results', 'E6_scalability_full_results.mat'), ...
    'agentCounts', 'seeds', 'rawTable', 'summaryTable', 'scalingTable')

figureHandle = figure('Color', 'w', 'Position', [100, 100, 1080, 470]);
tiledlayout(1, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
loglog(agentCounts, summaryTable.meanObserverMicroseconds, '-o', ...
    'LineWidth', 1.3, 'DisplayName', 'DC-IDO update')
hold on
loglog(agentCounts, summaryTable.meanActorMicroseconds, '-s', ...
    'LineWidth', 1.3, 'DisplayName', 'Shared Actor')
loglog(agentCounts, summaryTable.meanEndToEndMicroseconds, '-^', ...
    'LineWidth', 1.3, 'DisplayName', 'Complete online step')
xlabel('Number of agents')
ylabel('Mean runtime per sample (\mus)')
title(sprintf('(a) Runtime, DC-IDO slope %.2f', observerFit(1)))
legend('Location', 'northwest')
grid on

nexttile
yyaxis left
memoryLine = loglog(agentCounts, summaryTable.meanPeakObserverMemoryKilobytes, ...
    '-o', 'LineWidth', 1.3, 'Color', [0.00, 0.45, 0.74]);
ylabel('Observer workspace (KiB)')
yyaxis right
containmentLine = semilogx(agentCounts, summaryTable.minimumContainmentRate, ...
    '-s', 'LineWidth', 1.3, 'Color', [0.85, 0.33, 0.10]);
hold on
retentionLine = semilogx(agentCounts, summaryTable.minimumDelayRetentionRate, ...
    ':^', 'LineWidth', 1.3, 'Color', [0.49, 0.18, 0.56]);
ylim([0.98, 1.002])
ylabel('Minimum rate over seeds')
xlabel('Number of agents')
title(sprintf('(b) Memory slope %.2f and enclosure validity', memoryFit(1)))
legend([memoryLine, containmentLine, retentionLine], ...
    {'Observer workspace','Containment','True-delay retention'}, ...
    'Location', 'southwest')
grid on
fontname(figureHandle, 'Times New Roman')
fontsize(figureHandle, 10, 'points')
exportgraphics(figureHandle, fullfile(projectRoot, '06_figures', ...
    'E6_scalability.pdf'), 'ContentType', 'vector')
exportgraphics(figureHandle, fullfile(projectRoot, '06_figures', ...
    'E6_scalability.png'), 'Resolution', 300)
savefig(figureHandle, fullfile(projectRoot, '06_figures', ...
    'E6_scalability.fig'), 'compact')
close(figureHandle)

disp(summaryTable)
disp(scalingTable)

function metrics = benchmarkConfiguration(cfg, policy, seed)
numAgents = cfg.sim.numAgents;
numSteps = cfg.sim.numSteps;
adjacency = rrjfi.makeRingGraph(numAgents);
scenario = rrjfi.sampleScenario(cfg, seed, "tracking");
state = scenario.initialState;
lower = state - cfg.observer.initialRadius;
upper = state + cfg.observer.initialRadius;
control = zeros(numAgents, numSteps);

observerTime = zeros(1, numSteps);
actorTime = zeros(1, numSteps);
endToEndTime = zeros(1, numSteps);
containment = false(numAgents, numSteps);
delayRetention = false(numAgents, numSteps);
positionWidth = zeros(numAgents, numSteps);
peakObserverBytes = 0;

for step = 1:numSteps
    completeStart = tic;
    midpoint = 0.5 .* (lower + upper);
    control(:, step) = rrjfi.observerProbeAction( ...
        midpoint, scenario.positionReference(step), ...
        scenario.velocityReference(step), step, cfg, adjacency).';
    process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
    state = rrjfi.stepPlant( ...
        state, control, step, scenario.delay(:, step), scenario, process, cfg, adjacency);
    measurement = state + scenario.measurementNoise(:, :, step + 1);

    observerStart = tic;
    update = rrjfi.stepObserver( ...
        lower, upper, control, step, measurement, cfg, adjacency);
    observerTime(step) = toc(observerStart);
    if ~update.isConsistent
        error('rrjfi:ScalabilityObserverFailure', ...
            'Empty branch set for N=%d, seed=%d, step=%d.', numAgents, seed, step)
    end

    observation = rrjfi.buildObservation( ...
        update.lower, update.upper, update.isRetained, ...
        scenario.positionReference(step + 1), scenario.velocityReference(step + 1), ...
        cfg, adjacency);
    actorStart = tic;
    rrjfiTraining.actorForward(policy.actor, observation);
    actorTime(step) = toc(actorStart);

    containment(:, step) = all(state >= update.lower & state <= update.upper, 1).';
    for agent = 1:numAgents
        trueDelayIndex = find(cfg.sim.delayValues == scenario.delay(agent, step), 1);
        delayRetention(agent, step) = update.isRetained(agent, trueDelayIndex);
    end
    positionWidth(:, step) = (update.upper(1, :) - update.lower(1, :)).';
    updateInfo = whos('update');
    peakObserverBytes = max(peakObserverBytes, updateInfo.bytes);
    lower = update.lower;
    upper = update.upper;
    endToEndTime(step) = toc(completeStart);
end

timed = 11:numSteps;
metrics.numAgents = numAgents;
metrics.seed = seed;
metrics.meanObserverMicroseconds = 1e6 .* mean(observerTime(timed));
metrics.worstObserverMicroseconds = 1e6 .* max(observerTime(timed));
metrics.observerPerAgentMicroseconds = metrics.meanObserverMicroseconds ./ numAgents;
metrics.meanActorMicroseconds = 1e6 .* mean(actorTime(timed));
metrics.meanEndToEndMicroseconds = 1e6 .* mean(endToEndTime(timed));
metrics.peakObserverMemoryKilobytes = peakObserverBytes ./ 1024;
metrics.containmentRate = mean(containment, 'all');
metrics.delayRetentionRate = mean(delayRetention, 'all');
metrics.meanPositionWidth = mean(positionWidth, 'all');
end
