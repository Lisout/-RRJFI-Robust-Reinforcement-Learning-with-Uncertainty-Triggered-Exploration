%% E4: Certified recovery under strong nonlinearity and domain withdrawal
clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'))
addpath(fullfile(projectRoot, '02_training'))

cfg = rrjfi.defaultConfig(3);
cfg.sim.numSteps = 280;
cfg.model.sinGain = [0.45, 0.75];
cfg.model.damping = [0.20, 0.34];
cfg.model.couplingGain = [0.14, 0.24];
cfg.model.positionDomain = [-2.0, 2.0];
cfg.model.velocityDomain = [-2.2, 2.2];
cfg.control.safetyPosition = 1.90;
cfg.control.safetyVelocity = 2.20;
cfg.control.recoveryWidthLimit = [0.24; 0.40];
cfg.control.recoverySafetyBuffer = [0.35; 0.35];
cfg.noise.processBound = [5e-4; 6e-3];

proposedData = load(fullfile(projectRoot, '05_results', 'trained_proposed_seed3101.mat'));
maddpgData = load(fullfile(projectRoot, '05_results', 'trained_maddpg_seed3101.mat'));
proposedPolicy = proposedData.training;
maddpgPolicy = maddpgData.training;

variants = ["certifiedRecovery","robustOnly","pointOnly"];
seeds = 6201:6220;
results = cell(numel(variants), numel(seeds));
metricRows = cell(numel(variants) * numel(seeds), 1);
row = 0;
for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(seeds)
        current = rrjfi.simulateRecoveryStress( ...
            cfg, proposedPolicy, maddpgPolicy, variants(variantIndex), ...
            seeds(seedIndex), "inDomain");
        results{variantIndex, seedIndex} = current;
        row = row + 1;
        metricRows{row} = current.metrics;
    end
end
rawTable = struct2table(vertcat(metricRows{:}));
writetable(rawTable, fullfile(cfg.paths.results, 'E4_recovery_raw_metrics.csv'))

numericMetrics = ["trackingRmse","worstTrackingError","safetyViolationRate", ...
    "containmentRate","recoveryInterventionRate","recoveryFeasibilityRate", ...
    "maximumPositionWidth","maximumVelocityWidth"];
summaryRows = cell(numel(variants) * numel(numericMetrics), 1);
row = 0;
for variantIndex = 1:numel(variants)
    selected = rawTable(rawTable.variant == variants(variantIndex), :);
    for metricIndex = 1:numel(numericMetrics)
        row = row + 1;
        values = selected.(numericMetrics(metricIndex));
        currentSummary.variant = variants(variantIndex);
        currentSummary.metric = numericMetrics(metricIndex);
        currentSummary.mean = mean(values);
        currentSummary.standardDeviation = std(values);
        currentSummary.minimum = min(values);
        currentSummary.maximum = max(values);
        summaryRows{row} = currentSummary;
    end
end
summaryTable = struct2table(vertcat(summaryRows{:}));
writetable(summaryTable, fullfile(cfg.paths.results, 'E4_recovery_summary.csv'))

outSeeds = 7201:7212;
withdrawalRows = cell(numel(outSeeds), 1);
outResults = cell(size(outSeeds));
for seedIndex = 1:numel(outSeeds)
    current = rrjfi.simulateRecoveryStress( ...
        cfg, proposedPolicy, maddpgPolicy, "certifiedRecovery", ...
        outSeeds(seedIndex), "outOfDomain");
    outResults{seedIndex} = current;
    withdrawalRows{seedIndex} = current.metrics;
end
withdrawalTable = struct2table(vertcat(withdrawalRows{:}));
writetable(withdrawalTable, fullfile(cfg.paths.results, 'E4_domain_withdrawal.csv'))
save(fullfile(cfg.paths.results, 'E4_recovery_full_results.mat'), ...
    'cfg', 'results', 'rawTable', 'summaryTable', 'outResults', 'withdrawalTable', '-v7.3')

representative = results{1, 1};
time = (0:cfg.sim.numSteps) .* cfg.sim.sampleTime;
figureHandle = figure('Color', 'w', 'Position', [80, 80, 1120, 700]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact')
nexttile
hold on
colors = lines(numel(variants));
for variantIndex = 1:numel(variants)
    lastIndex = round(results{variantIndex, 1}.metrics.completedFraction ...
        * cfg.sim.numSteps) + 1;
    plot(time(1:lastIndex), squeeze(results{variantIndex, 1}.state(1, 1, 1:lastIndex)), ...
        'LineWidth', 1.35, 'Color', colors(variantIndex, :))
end
yline(cfg.control.safetyPosition, '--k', 'HandleVisibility', 'off')
yline(-cfg.control.safetyPosition, '--k', 'HandleVisibility', 'off')
xlabel('Time (s)')
ylabel('Agent 1 position')
legend({'Certified recovery','Robust reward only','Point-reward policy'}, ...
    'Location', 'best')
grid on

nexttile
plot(time(1:end-1), representative.desiredControl(1, :), ':', 'LineWidth', 1.1)
hold on
plot(time(1:end-1), representative.control(1, :), 'LineWidth', 1.35)
stairs(time(1:end-1), double(representative.recoveryIntervention), ...
    'LineWidth', 1.0)
xlabel('Time (s)')
ylabel('Command / intervention')
legend({'Desired proposal','Applied command','Recovery active'}, 'Location', 'best')
grid on

nexttile
violationRate = zeros(1, numel(variants));
interventionRate = zeros(1, numel(variants));
for variantIndex = 1:numel(variants)
    selected = rawTable(rawTable.variant == variants(variantIndex), :);
    violationRate(variantIndex) = mean(selected.anySafetyViolation);
    interventionRate(variantIndex) = mean(selected.recoveryInterventionRate);
end
bar([violationRate; interventionRate].')
set(gca, 'XTickLabel', {'Certified','Robust only','Point only'})
ylabel('Across-seed fraction / time ratio')
legend({'Runs with violation','Recovery intervention'}, 'Location', 'best')
grid on

nexttile
withdrawalTimes = withdrawalTable.withdrawalTime;
histogram(withdrawalTimes(~isnan(withdrawalTimes)), 8, ...
    'FaceColor', [0.30, 0.55, 0.82])
xlabel('Certificate-withdrawal time (s)')
ylabel('Out-of-domain runs')
title(sprintf('Withdrawal detected: %d/%d', ...
    sum(withdrawalTable.certificateWithdrawn), height(withdrawalTable)))
grid on
sgtitle('Certified recovery and declared-domain diagnostic')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E4_recovery_and_withdrawal.pdf'), ...
    'ContentType', 'vector')
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E4_recovery_and_withdrawal.png'), ...
    'Resolution', 300)
savefig(figureHandle, fullfile(cfg.paths.figures, 'E4_recovery_and_withdrawal.fig'), 'compact')
close(figureHandle)

disp(summaryTable)
disp(withdrawalTable(:, {'seed','certificateWithdrawn','withdrawalTime','completedFraction'}))
