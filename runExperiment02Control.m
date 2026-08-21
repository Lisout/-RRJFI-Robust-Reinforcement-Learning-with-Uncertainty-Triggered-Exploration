%% Experiment E2: matched controller comparison on common test seeds

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'));
addpath(fullfile(projectRoot, '02_training'));

trainingData = load(fullfile(projectRoot, '05_results', 'training_all_seeds.mat'), ...
    'cfg', 'trainingSeeds', 'allTraining');
cfg = trainingData.cfg;
cfg.sim.numSteps = 240;
tuningData = load(fullfile(cfg.paths.results, 'baseline_tuning.mat'), 'tunedConfig');
cfg.baseline = tuningData.tunedConfig.baseline;
trainingSeeds = trainingData.trainingSeeds;
allTraining = trainingData.allTraining;
evaluationSeeds = 1201:1220;
tasks = ["stabilization", "tracking"];
methods = ["proposed", "maddpg", "smith", "pid"];
rows = cell(0, 1);
rowIndex = 0;
representative = struct;

for task = tasks
    for evaluationSeed = evaluationSeeds
        for method = methods
            if method == "proposed" || method == "maddpg"
                variantIndex = find(["proposed", "maddpg"] == method, 1);
                for trainingIndex = 1:numel(trainingSeeds)
                    policy = allTraining{variantIndex, trainingIndex};
                    result = rrjfi.simulateController(cfg, method, policy, evaluationSeed, task);
                    rowIndex = rowIndex + 1;
                    rows{rowIndex} = metricRow(result.metrics, trainingSeeds(trainingIndex));
                    if evaluationSeed == evaluationSeeds(1) && trainingIndex == 1
                        representative.(char(task)).(char(method)) = result;
                    end
                end
            else
                result = rrjfi.simulateController(cfg, method, [], evaluationSeed, task);
                rowIndex = rowIndex + 1;
                rows{rowIndex} = metricRow(result.metrics, NaN);
                if evaluationSeed == evaluationSeeds(1)
                    representative.(char(task)).(char(method)) = result;
                end
            end
        end
    end
end

rawMetrics = struct2table(vertcat(rows{:}));
seedMetrics = aggregateTrainingSeeds(rawMetrics, methods, tasks, evaluationSeeds);
summary = summarizeMetrics(seedMetrics, methods, tasks);
pairedTests = pairedComparisons(seedMetrics, methods, tasks);

writetable(rawMetrics, fullfile(cfg.paths.results, 'E2_control_raw_metrics.csv'));
writetable(seedMetrics, fullfile(cfg.paths.results, 'E2_control_seed_metrics.csv'));
writetable(summary, fullfile(cfg.paths.results, 'E2_control_summary.csv'));
writetable(pairedTests, fullfile(cfg.paths.results, 'E2_control_paired_tests.csv'));
save(fullfile(cfg.paths.results, 'E2_control_full_results.mat'), ...
    'cfg', 'trainingSeeds', 'evaluationSeeds', 'tasks', 'methods', 'rawMetrics', ...
    'seedMetrics', 'summary', 'pairedTests', 'representative', '-v7.3');

makeComparisonFigure(representative, cfg, methods);
disp(summary);
disp(pairedTests);

function row = metricRow(metrics, trainingSeed)
row.method = metrics.method;
row.trainingSeed = trainingSeed;
row.evaluationSeed = metrics.seed;
row.task = metrics.task;
row.trackingRmse = metrics.trackingRmse;
row.velocityRmse = metrics.velocityRmse;
row.consensusRmse = metrics.consensusRmse;
row.worstTrackingError = metrics.worstTrackingError;
row.controlEnergy = metrics.controlEnergy;
row.safetyViolationRate = metrics.safetyViolationRate;
row.containmentRate = metrics.containmentRate;
row.meanDelayCardinality = metrics.meanDelayCardinality;
row.recoveryInterventionRate = metrics.recoveryInterventionRate;
row.recoveryFeasibilityRate = metrics.recoveryFeasibilityRate;
row.meanStepReward = metrics.meanStepReward;
row.settlingTime = metrics.settlingTime;
end

function seedMetrics = aggregateTrainingSeeds(rawMetrics, methods, tasks, evaluationSeeds)
rows = cell(numel(methods) * numel(tasks) * numel(evaluationSeeds), 1);
index = 0;
numericNames = rawMetrics.Properties.VariableNames(5:end);
for method = methods
    for task = tasks
        for seed = evaluationSeeds
            mask = rawMetrics.method == method & rawMetrics.task == task ...
                & rawMetrics.evaluationSeed == seed;
            subset = rawMetrics(mask, :);
            index = index + 1;
            row.method = method;
            row.evaluationSeed = seed;
            row.task = task;
            for nameIndex = 1:numel(numericNames)
                name = numericNames{nameIndex};
                row.(name) = mean(subset.(name), 'omitnan');
            end
            rows{index} = row;
        end
    end
end
seedMetrics = struct2table(vertcat(rows{:}));
end

function summary = summarizeMetrics(seedMetrics, methods, tasks)
reported = {'trackingRmse','consensusRmse','controlEnergy','safetyViolationRate', ...
    'recoveryInterventionRate','containmentRate','settlingTime'};
rows = cell(numel(methods) * numel(tasks) * numel(reported), 1);
index = 0;
for task = tasks
    for method = methods
        subset = seedMetrics(seedMetrics.method == method & seedMetrics.task == task, :);
        for metricIndex = 1:numel(reported)
            values = subset.(reported{metricIndex});
            values = values(isfinite(values));
            index = index + 1;
            row.task = task;
            row.method = method;
            row.metric = string(reported{metricIndex});
            row.mean = mean(values);
            row.standardDeviation = std(values);
            if numel(values) > 1
                halfWidth = tinv(0.975, numel(values) - 1) * std(values) / sqrt(numel(values));
            else
                halfWidth = NaN;
            end
            row.ci95Lower = row.mean - halfWidth;
            row.ci95Upper = row.mean + halfWidth;
            rows{index} = row;
        end
    end
end
summary = struct2table(vertcat(rows{:}));
end

function tests = pairedComparisons(seedMetrics, methods, tasks)
competitors = methods(methods ~= "proposed");
reported = {'trackingRmse','controlEnergy','safetyViolationRate'};
rows = cell(numel(tasks) * numel(competitors) * numel(reported), 1);
index = 0;
for task = tasks
    proposed = sortrows(seedMetrics(seedMetrics.method == "proposed" ...
        & seedMetrics.task == task, :), 'evaluationSeed');
    for competitor = competitors
        comparison = sortrows(seedMetrics(seedMetrics.method == competitor ...
            & seedMetrics.task == task, :), 'evaluationSeed');
        for metricIndex = 1:numel(reported)
            metric = reported{metricIndex};
            difference = comparison.(metric) - proposed.(metric);
            index = index + 1;
            row.task = task;
            row.competitor = competitor;
            row.metric = string(metric);
            row.meanDifferenceCompetitorMinusProposed = mean(difference);
            row.medianDifferenceCompetitorMinusProposed = median(difference);
            if all(abs(difference) < eps)
                row.signrankP = 1;
            else
                row.signrankP = signrank(difference);
            end
            rows{index} = row;
        end
    end
end
tests = struct2table(vertcat(rows{:}));
end

function makeComparisonFigure(representative, cfg, methods)
colors = lines(numel(methods));
labels = ["Proposed", "MADDPG", "Smith predictor", "Observer PID"];
time = (0:cfg.sim.numSteps) .* cfg.sim.sampleTime;
figureHandle = figure('Color', 'w', 'Position', [60, 120, 1380, 440]);
tiledlayout(1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
tracking = representative.tracking;
fill([time, fliplr(time)], ...
    [squeeze(tracking.proposed.lower(1, 1, :)).', ...
    fliplr(squeeze(tracking.proposed.upper(1, 1, :)).')], ...
    [0.85, 0.91, 1.00], 'EdgeColor', 'none', 'DisplayName', 'Proposed interval');
hold on;
for methodIndex = 1:numel(methods)
    result = tracking.(char(methods(methodIndex)));
    plot(time, squeeze(result.state(1, 1, :)), 'Color', colors(methodIndex, :), ...
        'LineWidth', 1.15, 'DisplayName', labels(methodIndex));
end
plot(time, tracking.proposed.scenario.positionReference, 'k--', 'LineWidth', 1.1, ...
    'DisplayName', 'Reference');
xlabel('Time (s)'); ylabel('Agent 1 position'); title('(a) Tracking response');
legend('Location', 'best'); grid on;

nexttile;
for methodIndex = 1:numel(methods)
    result = tracking.(char(methods(methodIndex)));
    error = abs(squeeze(result.state(1, 1, :)) - result.scenario.positionReference.');
    semilogy(time, max(error, 1e-4), 'Color', colors(methodIndex, :), ...
        'LineWidth', 1.15, 'DisplayName', labels(methodIndex));
    hold on;
end
xlabel('Time (s)'); ylabel('Absolute tracking error'); title('(b) Tracking-error magnitude');
legend('Location', 'best'); grid on;

nexttile;
for methodIndex = 1:numel(methods)
    result = tracking.(char(methods(methodIndex)));
    stairs(time(1:end-1), result.control(1, :), 'Color', colors(methodIndex, :), ...
        'LineWidth', 1.05, 'DisplayName', labels(methodIndex));
    hold on;
end
xlabel('Time (s)'); ylabel('Agent 1 input'); title('(c) Applied control input');
legend('Location', 'best'); grid on;

fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E2_controller_comparison.pdf'), ...
    'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E2_controller_comparison.png'), ...
    'Resolution', 300);
savefig(figureHandle, fullfile(cfg.paths.figures, 'E2_controller_comparison.fig'), 'compact');
close(figureHandle);
end
