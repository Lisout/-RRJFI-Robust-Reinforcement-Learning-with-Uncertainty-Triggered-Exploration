%% Reproducible workflow diagram for the revised manuscript
clear
close all

projectRoot = fileparts(fileparts(mfilename('fullpath')));
figureHandle = figure('Color', 'w', 'Position', [80, 80, 1350, 760]);
axis off

boxColor = [0.88, 0.93, 0.99];
decisionColor = [1.00, 0.94, 0.78];
safeColor = [0.86, 0.96, 0.88];
warningColor = [1.00, 0.88, 0.86];

addBox([0.04, 0.77, 0.18, 0.12], ...
    {'Declared parameter, noise,','delay, graph, and safety sets'}, boxColor)
addBox([0.29, 0.77, 0.18, 0.12], ...
    {'CTDE training','robust interval / point baselines'}, boxColor)
addBox([0.54, 0.77, 0.18, 0.12], ...
    {'Held-out snapshot selection','and spectral projection'}, boxColor)
addBox([0.79, 0.77, 0.17, 0.12], ...
    {'Post-training common-P audit','freeze certified Actor'}, safeColor)
addArrow([0.22, 0.38], [0.83, 0.83])
addArrow([0.47, 0.63], [0.83, 0.83])
addArrow([0.72, 0.79], [0.83, 0.83])

annotation('textbox', [0.035, 0.665, 0.20, 0.045], 'String', ...
    'OFFLINE DESIGN AND CERTIFICATION', 'EdgeColor', 'none', ...
    'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center')
annotation('line', [0.04, 0.96], [0.65, 0.65], 'Color', [0.55, 0.55, 0.55])

addBox([0.03, 0.43, 0.14, 0.11], ...
    {'Measurements and','neighbor envelopes'}, boxColor)
addBox([0.21, 0.43, 0.14, 0.11], ...
    {'Delay-indexed DC-IDO','prediction + rejection'}, boxColor)
addBox([0.39, 0.43, 0.14, 0.11], ...
    {'State hull, delay set,','and robust reward bounds'}, boxColor)
addBox([0.57, 0.43, 0.14, 0.11], ...
    {'Frozen residual Actor','and nominal scaffold'}, boxColor)
addBox([0.75, 0.43, 0.14, 0.11], ...
    {'IE-BPU gate: variance, PE,','hysteresis, and dwell'}, decisionColor)
addBox([0.81, 0.20, 0.14, 0.11], ...
    {'Bounded exploratory','action proposal'}, decisionColor)
addArrow([0.17, 0.21], [0.485, 0.485])
addArrow([0.35, 0.39], [0.485, 0.485])
addArrow([0.53, 0.57], [0.485, 0.485])
addArrow([0.71, 0.75], [0.485, 0.485])
addArrow([0.82, 0.87], [0.43, 0.31])

addBox([0.57, 0.20, 0.16, 0.11], ...
    {'Certified recovery projection','and action feasibility'}, safeColor)
addBox([0.34, 0.20, 0.15, 0.11], ...
    {'Plant and asynchronous','input-delay channel'}, boxColor)
addBox([0.10, 0.20, 0.16, 0.11], ...
    {'Inversion-free RLS update','of compact Critic head'}, boxColor)
addArrow([0.81, 0.73], [0.255, 0.255])
addArrow([0.57, 0.49], [0.255, 0.255])
addArrow([0.34, 0.26], [0.255, 0.255])
addArrow([0.18, 0.10], [0.31, 0.43])

addBox([0.37, 0.035, 0.26, 0.085], ...
    {'If containment/domain/feasibility fails:','withdraw certificate and enter declared fallback'}, warningColor)
addArrow([0.65, 0.50], [0.20, 0.12])

annotation('textbox', [0.035, 0.565, 0.18, 0.045], 'String', ...
    'CERTIFIED ONLINE LOOP', 'EdgeColor', 'none', ...
    'FontWeight', 'bold', 'FontSize', 11, 'HorizontalAlignment', 'center')

fontname(figureHandle, 'Times New Roman')
exportgraphics(figureHandle, fullfile(projectRoot, '06_figures', ...
    'workflow_complete_algorithm.pdf'), 'ContentType', 'vector')
exportgraphics(figureHandle, fullfile(projectRoot, '06_figures', ...
    'workflow_complete_algorithm.png'), 'Resolution', 300)
savefig(figureHandle, fullfile(projectRoot, '06_figures', ...
    'workflow_complete_algorithm.fig'), 'compact')
close(figureHandle)

function addBox(position, content, color)
annotation('textbox', position, 'String', content, 'FitBoxToText', 'off', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'BackgroundColor', color, 'EdgeColor', [0.25, 0.35, 0.48], ...
    'LineWidth', 1.0, 'FontSize', 10)
end

function addArrow(horizontal, vertical)
annotation('arrow', horizontal, vertical, 'LineWidth', 1.1, ...
    'Color', [0.20, 0.25, 0.32], 'HeadLength', 7, 'HeadWidth', 7)
end
