%% Experiment E3: IE-BPU uncertainty, PE, hysteresis, and dwell logic

projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, '01_core'));
addpath(fullfile(projectRoot, '02_training'));

trainingData = load(fullfile(projectRoot, '05_results', 'training_all_seeds.mat'), 'allTraining');
policy = trainingData.allTraining{1, 1};
cfg = rrjfi.defaultConfig(3);
cfg.sim.numSteps = 500;
cfg.trigger.featureDimension = 4;
cfg.trigger.peThreshold = 1e-4;
cfg.trigger.explorationAmplitude = 0.50;
cfg.trigger.priorScale = 10;
cfg.trigger.forgettingFactor = 1;
cfg.trigger.baseThreshold = 1e-3;
cfg.trigger.hysteresisHalfWidth = 2e-4;
cfg.trigger.refractorySamples = 8;
cfg.trigger.useExactPe = true;

head = rrjfiTraining.prepareBayesianHead( ...
    policy, cfg, 4401, cfg.trigger.featureDimension);
variants = ["full", "entropyOnly", "continuous", "none"];
seeds = 5201:5212;
episodes = cell(numel(variants), numel(seeds));
rows = cell(numel(variants) * numel(seeds), 1);
rowIndex = 0;

for variantIndex = 1:numel(variants)
    for seedIndex = 1:numel(seeds)
        episodes{variantIndex, seedIndex} = rrjfi.simulateIEBPU( ...
            cfg, policy, head, variants(variantIndex), seeds(seedIndex));
        rowIndex = rowIndex + 1;
        rows{rowIndex} = episodes{variantIndex, seedIndex}.metrics;
    end
end

rawMetrics = struct2table(vertcat(rows{:}));
summary = summarize(rawMetrics, variants);
writetable(rawMetrics, fullfile(cfg.paths.results, 'E3_iebpu_raw_metrics.csv'));
writetable(summary, fullfile(cfg.paths.results, 'E3_iebpu_summary.csv'));
save(fullfile(cfg.paths.results, 'E3_iebpu_full_results.mat'), ...
    'cfg', 'policy', 'head', 'variants', 'seeds', 'episodes', 'rawMetrics', 'summary', '-v7.3');

makeTriggerFigure(episodes{1, 1}, cfg);
makeVariantFigure(rawMetrics, variants, cfg);
disp(summary);

function summary = summarize(rawMetrics, variants)
reported = {'trackingRmse','activationRatio','switchingRate','onsetCount', ...
    'minimumInterOnsetTime','explorationEnergy','finalValidationMse', ...
    'finalParameterError','tailInnovationRmse','peCertificateRatio', ...
    'safetyViolationRate','containmentRate','averageUpdateTime','worstUpdateTime'};
rows = cell(numel(variants) * numel(reported), 1);
index = 0;
for variant = variants
    subset = rawMetrics(rawMetrics.variant == variant, :);
    for metricIndex = 1:numel(reported)
        values = subset.(reported{metricIndex});
        values = values(isfinite(values));
        if isempty(values)
            values = NaN;
        end
        index = index + 1;
        row.variant = variant;
        row.metric = string(reported{metricIndex});
        row.mean = mean(values);
        row.standardDeviation = std(values);
        row.minimum = min(values);
        row.maximum = max(values);
        rows{index} = row;
    end
end
summary = struct2table(vertcat(rows{:}));
end

function makeTriggerFigure(result, cfg)
time = (1:cfg.sim.numSteps) .* cfg.sim.sampleTime;
figureHandle = figure('Color', 'w', 'Position', [100, 100, 1080, 760]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
semilogy(time, max(result.uncertainty, 1e-8), 'b-', 'LineWidth', 1.15, ...
    'DisplayName', 'Predictive variance');
hold on;
semilogy(time, max(result.onThreshold, 1e-8), 'r--', 'LineWidth', 1.0, ...
    'DisplayName', 'On threshold');
semilogy(time, max(result.offThreshold, 1e-8), 'Color', [0.75, 0.35, 0.10], ...
    'LineStyle', ':', 'LineWidth', 1.0, 'DisplayName', 'Off threshold');
xlabel('Time (s)'); ylabel('Uncertainty score'); title('(a) Hysteretic uncertainty gate');
legend('Location', 'best'); grid on;

nexttile;
semilogy(time, max(result.exactPe, 1e-10), 'Color', [0.10, 0.55, 0.25], ...
    'LineWidth', 1.15, 'DisplayName', 'Exact PE index');
hold on;
semilogy(time, max(result.lowerPe, 1e-10), 'Color', [0.45, 0.45, 0.45], ...
    'LineWidth', 1.0, 'DisplayName', 'Gershgorin lower bound');
yline(cfg.trigger.peThreshold, 'k--', 'LineWidth', 1.0, 'DisplayName', 'PE threshold');
xlabel('Time (s)'); ylabel('Feature-Gramian margin'); title('(b) PE monitoring');
legend('Location', 'best'); grid on;

nexttile;
stairs(time, double(result.trigger), 'b-', 'LineWidth', 1.2, 'DisplayName', 'Exploration active');
hold on;
stem(time(result.onset), 0.82 .* ones(1, sum(result.onset)), 'r', 'filled', ...
    'MarkerSize', 3, 'DisplayName', 'Activation onset');
ylim([-0.08, 1.08]);
xlabel('Time (s)'); ylabel('Binary state'); title('(c) Trigger and activation onsets');
legend('Location', 'best'); grid on;

nexttile;
yyaxis left;
semilogy(time, max(result.parameterError, 1e-6), 'Color', [0.45, 0.20, 0.70], ...
    'LineWidth', 1.15, 'DisplayName', 'Parameter error');
ylabel('Parameter-error norm');
yyaxis right;
semilogy(time, max(result.covarianceTrace, 1e-6), 'Color', [0.15, 0.55, 0.65], ...
    'LineWidth', 1.0, 'DisplayName', 'Covariance trace');
ylabel('Covariance trace');
xlabel('Time (s)'); title('(d) Inversion-free RLS convergence');
grid on;

fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_trigger.pdf'), ...
    'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_trigger.png'), ...
    'Resolution', 300);
savefig(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_trigger.fig'), 'compact');
close(figureHandle);
end

function makeVariantFigure(rawMetrics, variants, cfg)
labels = ["Full IE-BPU", "Entropy only", "Continuous", "No exploration"];
metrics = {'trackingRmse','activationRatio','switchingRate','finalParameterError'};
yLabels = ["Tracking RMSE", "Activation ratio", "Switching rate", "Final parameter error"];
figureHandle = figure('Color', 'w', 'Position', [100, 100, 1080, 720]);
tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for metricIndex = 1:numel(metrics)
    nexttile;
    means = zeros(1, numel(variants));
    deviations = zeros(size(means));
    for variantIndex = 1:numel(variants)
        values = rawMetrics.(metrics{metricIndex})(rawMetrics.variant == variants(variantIndex));
        means(variantIndex) = mean(values, 'omitnan');
        deviations(variantIndex) = std(values, 'omitnan');
    end
    bar(1:numel(variants), means, 0.72, 'FaceColor', [0.30, 0.50, 0.80]);
    hold on;
    errorbar(1:numel(variants), means, deviations, 'k.', 'LineWidth', 1.0);
    xticks(1:numel(variants)); xticklabels(labels); xtickangle(18);
    ylabel(char(yLabels(metricIndex)));
    title(sprintf('(%s) %s', char('a' + metricIndex - 1), char(yLabels(metricIndex))));
    grid on;
end
fontname(figureHandle, 'Times New Roman');
fontsize(figureHandle, 10, 'points');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_variants.pdf'), ...
    'ContentType', 'vector');
exportgraphics(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_variants.png'), ...
    'Resolution', 300);
savefig(figureHandle, fullfile(cfg.paths.figures, 'E3_iebpu_variants.fig'), 'compact');
close(figureHandle);
end
