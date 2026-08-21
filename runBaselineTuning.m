%% Tune Smith and observer-based PID baselines on disjoint seeds

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'));
addpath(fullfile(projectRoot, '02_training'));

cfg = rrjfi.defaultConfig(3);
cfg.sim.numSteps = 180;
tuningSeeds = 8101:8104;
tasks = ["stabilization", "tracking"];
rows = cell(0, 1);
rowIndex = 0;

smithPosition = [0.75, 0.95, 1.15, 1.35];
smithVelocity = [0.90, 1.10, 1.30, 1.50];
for positionGain = smithPosition
    for velocityGain = smithVelocity
        candidate = cfg;
        candidate.baseline.smithPositionGain = positionGain;
        candidate.baseline.smithVelocityGain = velocityGain;
        metrics = evaluateCandidate(candidate, "smith", tuningSeeds, tasks);
        rowIndex = rowIndex + 1;
        rows{rowIndex} = makeRow("smith", positionGain, velocityGain, NaN, metrics);
    end
end

pidPosition = [0.80, 1.00, 1.20];
pidVelocity = [1.00, 1.25, 1.50];
pidIntegral = [0.00, 0.04, 0.08];
for positionGain = pidPosition
    for velocityGain = pidVelocity
        for integralGain = pidIntegral
            candidate = cfg;
            candidate.baseline.pidPositionGain = positionGain;
            candidate.baseline.pidVelocityGain = velocityGain;
            candidate.baseline.pidIntegralGain = integralGain;
            metrics = evaluateCandidate(candidate, "pid", tuningSeeds, tasks);
            rowIndex = rowIndex + 1;
            rows{rowIndex} = makeRow("pid", positionGain, velocityGain, integralGain, metrics);
        end
    end
end

tuningTable = struct2table(vertcat(rows{:}));
smithRows = find(tuningTable.method == "smith");
pidRows = find(tuningTable.method == "pid");
[~, smithLocal] = min(tuningTable.objective(smithRows));
[~, pidLocal] = min(tuningTable.objective(pidRows));
selectedSmith = tuningTable(smithRows(smithLocal), :);
selectedPid = tuningTable(pidRows(pidLocal), :);

tunedConfig = cfg;
tunedConfig.baseline.smithPositionGain = selectedSmith.positionGain;
tunedConfig.baseline.smithVelocityGain = selectedSmith.velocityGain;
tunedConfig.baseline.pidPositionGain = selectedPid.positionGain;
tunedConfig.baseline.pidVelocityGain = selectedPid.velocityGain;
tunedConfig.baseline.pidIntegralGain = selectedPid.integralGain;

writetable(tuningTable, fullfile(cfg.paths.results, 'baseline_tuning_grid.csv'));
writetable([selectedSmith; selectedPid], fullfile(cfg.paths.results, 'baseline_tuning_selected.csv'));
save(fullfile(cfg.paths.results, 'baseline_tuning.mat'), ...
    'tunedConfig', 'tuningSeeds', 'tasks', 'tuningTable', 'selectedSmith', 'selectedPid');
disp([selectedSmith; selectedPid]);

function metrics = evaluateCandidate(cfg, method, seeds, tasks)
values = zeros(numel(seeds) * numel(tasks), 3);
index = 0;
for seed = seeds
    for task = tasks
        index = index + 1;
        result = rrjfi.simulateController(cfg, method, [], seed, task);
        values(index, :) = [result.metrics.trackingRmse, ...
            result.metrics.controlEnergy, result.metrics.safetyViolationRate];
    end
end
metrics.rmse = mean(values(:, 1));
metrics.energy = mean(values(:, 2));
metrics.safety = mean(values(:, 3));
metrics.objective = metrics.rmse + 0.008 * metrics.energy + 50 * metrics.safety;
end

function row = makeRow(method, positionGain, velocityGain, integralGain, metrics)
row.method = method;
row.positionGain = positionGain;
row.velocityGain = velocityGain;
row.integralGain = integralGain;
row.meanRmse = metrics.rmse;
row.meanEnergy = metrics.energy;
row.safetyViolationRate = metrics.safety;
row.objective = metrics.objective;
end
