function redrawFiguresFromExistingData(options)
%REDRAWFIGURESFROMEXISTINGDATA Rebuild all result figures from archived data.
%   REDRAWFIGURESFROMEXISTINGDATA() loads the existing MAT result archives
%   in 05_results and creates seven independent normal figure windows. The
%   figures remain open for inspection and editing; this function never
%   returns a Figure array, closes a figure, or saves a figure. It does not
%   rerun training, simulation, baseline tuning, or certificate optimization.
%
%   E1(a) and E2(a) use BaseZoom in interactive mode. For each axes, first
%   drag the inset location and right-click to accept it; then drag the data
%   region to magnify and right-click again. Set ManualZoom=false only for
%   unattended validation or when the inset is not required.
%
%   The generated figures correspond to E1--E7: DC-IDO observation,
%   controller tracking, IE-BPU triggering, certified recovery, Bayesian-
%   head representation, network scalability, and the common-P audit.

    arguments
        options.ManualZoom (1, 1) logical = true
        options.BaseZoomFolder (1, 1) string = ...
            "D:/mat/mat_for_IDAOmas/section3.1/New Folder (2)"
    end

    projectRoot = string(fileparts(mfilename("fullpath")));
    resultsFolder = fullfile(projectRoot, "05_results");

    resultFiles = [
        "E1_observer_full_results.mat"
        "E2_control_full_results.mat"
        "E3_iebpu_full_results.mat"
        "E4_recovery_full_results.mat"
        "E5_representation_full_results.mat"
        "E6_scalability_full_results.mat"
        "E7_certificate_full_results.mat"];
    resultPaths = fullfile(resultsFolder, resultFiles);
    missingFiles = resultPaths(~isfile(resultPaths));
    if ~isempty(missingFiles)
        error("redrawFigures:MissingData", ...
            "Missing archived result file(s):%s%s", newline, ...
            strjoin(missingFiles, newline));
    end

    archive1 = load(resultPaths(1), "cfg", "episodes");
    archive2 = load(resultPaths(2), "representative");
    archive3 = load(resultPaths(3), "cfg", "episodes", "variants");
    archive4 = load(resultPaths(4), "cfg", "results", "rawTable", ...
        "withdrawalTable");
    archive5 = load(resultPaths(5), "dimensions", "resultTable", ...
        "scalingTable");
    archive6 = load(resultPaths(6), "agentCounts", "summaryTable", ...
        "scalingTable");
    archive7 = load(resultPaths(7), "policy", "summaryTable");

    [figE1, zoomAxesE1] = plotObserver(archive1);
    [figE2, zoomAxesE2] = plotController(archive2);
    figE3 = plotTrigger(archive3);
    figE4 = plotRecovery(archive4);
    figE5 = plotRepresentation(archive5);
    figE6 = plotScalability(archive6);
    figE7 = plotCertificate(archive7);
    drawnow;

    if options.ManualZoom
        runInteractiveZoom(figE1, zoomAxesE1, options.BaseZoomFolder, "E1(a)");
        runInteractiveZoom(figE2, zoomAxesE2, options.BaseZoomFolder, "E2(a)");
    end
    drawnow;
    assertIndependentFigures(figE1, figE2, figE3, figE4, figE5, figE6, figE7);
    fprintf("Created seven independent publication-sized figures. No figures were saved or closed.\n");
end

function [figureHandle, zoomAxesHandle] = plotObserver(archive)
    result = archive.episodes{1};
    sampleTime = archive.cfg.sim.sampleTime;
    time = (0:(size(result.state, 3) - 1)) .* sampleTime;
    agent = 1;
    actualLower = squeeze(result.lower(1, agent, :)).';
    actualUpper = squeeze(result.upper(1, agent, :)).';
    midpoint = 0.5 .* (actualLower + actualUpper);
    displayHalfWidth = 4 .* 0.5 .* (actualUpper - actualLower);

    figureHandle = createPublicationFigure( ...
        "E1: DC-IDO observation and hull analysis", [9.0, 6.8]);
    axesHandles = createAxesGrid(figureHandle, [
        0.055, 0.44, 0.43, 0.55
        0.515, 0.44, 0.43, 0.55
        0.055, 0.10, 0.43, 0.33
        0.515, 0.10, 0.43, 0.33]);
    zoomAxesHandle = axesHandles(1);
    axesHandles(2).YAxisLocation = "right";
    axesHandles(4).YAxisLocation = "right";

    axes(axesHandles(1));
    fill([time, fliplr(time)], ...
        [midpoint - displayHalfWidth, fliplr(midpoint + displayHalfWidth)], ...
        [0.75, 0.86, 1.00], EdgeColor="none", FaceAlpha=0.65, ...
        DisplayName="DC-IDO hull (4x half-width; display only)");
    hold on;
    plot(time, actualLower, Color=[0.15, 0.45, 0.85], LineWidth=0.75, ...
        DisplayName="Actual DC-IDO bounds");
    plot(time, actualUpper, Color=[0.15, 0.45, 0.85], LineWidth=0.75, ...
        HandleVisibility="off");
    plot(time, squeeze(result.state(1, agent, :)), "k-", LineWidth=1.25, ...
        DisplayName="True state");
    xlabel("Time (s)"); ylabel("Position");
    title("(a) State enclosure under identifying probe");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    axes(axesHandles(2));
    stairs(time(2:end), result.delayCardinality(agent, :), ...
        Color=[0.00, 0.45, 0.74], LineWidth=1.2, ...
        DisplayName="Retained-set cardinality");
    hold on;
    stairs(time(2:end), result.scenario.delay(agent, :), "k--", ...
        LineWidth=1.0, DisplayName="True delay (samples)");
    xlabel("Time (s)"); ylabel("Cardinality / delay");
    title("(b) Measurement-consistent delay refinement");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    axes(axesHandles(3));
    semilogy(time(2:end), max(result.hullInflation(agent, :), 1e-8), ...
        Color=[0.20, 0.55, 0.25], LineWidth=1.2, ...
        DisplayName="Hull inflation ratio");
    hold on;
    excess = squeeze(vecnorm(result.hullExcess(:, agent, :), 2, 1)).';
    semilogy(time(2:end), max(excess, 1e-8), ...
        Color=[0.70, 0.30, 0.10], LineWidth=1.0, ...
        DisplayName="Hull width excess");
    xlabel("Time (s)"); ylabel("Conservatism metric");
    title("(c) Hull over-approximation");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    axes(axesHandles(4));
    semilogy(time(2:end), max(result.rewardWidthPrior, 1e-7), "--", ...
        Color=[0.45, 0.45, 0.45], LineWidth=1.1, ...
        DisplayName="A-priori delay set");
    hold on;
    semilogy(time(2:end), max(result.rewardWidthRefined, 1e-7), ...
        Color=[0.20, 0.35, 0.80], LineWidth=1.2, ...
        DisplayName="Measurement-refined set");
    xlabel("Time (s)"); ylabel("One-step robust reward width");
    title("(d) Observer-to-value uncertainty reduction");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;
    % North-outside legends can reset axis-side defaults; apply the side
    % placement after all legend/layout operations so the right-column
    % labels stay outside the neighboring panels.
    axesHandles(2).YAxisLocation = "right";
    axesHandles(4).YAxisLocation = "right";
end

function [figureHandle, zoomAxesHandle] = plotController(archive)
    tracking = archive.representative.tracking;
    methods = ["proposed", "maddpg", "smith", "pid"];
    labels = ["Proposed", "MADDPG", "Smith predictor", "Observer PID"];
    colors = lines(numel(methods));
    reference = tracking.proposed.scenario.positionReference;
    time = (0:(numel(reference) - 1)) .* ...
        tracking.proposed.config.sim.sampleTime;

    figureHandle = createPublicationFigure( ...
        "E2: Common-seed controller comparison", [9.0, 5.2]);
    axesHandles = createAxesGrid(figureHandle, [
        0.04, 0.06, 0.29, 0.86
        0.35, 0.06, 0.29, 0.86
        0.66, 0.06, 0.29, 0.86]);
    zoomAxesHandle = axesHandles(1);
    axesHandles(2).YAxisLocation = "right";
    axesHandles(3).YAxisLocation = "right";

    axes(axesHandles(1));
    lower = squeeze(tracking.proposed.lower(1, 1, :)).';
    upper = squeeze(tracking.proposed.upper(1, 1, :)).';
    fill([time, fliplr(time)], [lower, fliplr(upper)], ...
        [0.82, 0.90, 1.00], EdgeColor="none", FaceAlpha=0.55, ...
        DisplayName="Proposed interval");
    hold on;
    for methodIndex = 1:numel(methods)
        result = tracking.(methods(methodIndex));
        plot(time, squeeze(result.state(1, 1, :)), ...
            Color=colors(methodIndex, :), LineWidth=1.15, ...
            DisplayName=labels(methodIndex));
    end
    plot(time, reference, "k--", LineWidth=1.1, DisplayName="Reference");
    xlabel("Time (s)"); ylabel("Agent 1 position");
    title("(a) Tracking response");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    axes(axesHandles(2));
    for methodIndex = 1:numel(methods)
        result = tracking.(methods(methodIndex));
        trackingError = abs(squeeze(result.state(1, 1, :)).' - reference);
        semilogy(time, max(trackingError, 1e-4), ...
            Color=colors(methodIndex, :), LineWidth=1.15, ...
            DisplayName=labels(methodIndex));
        hold on;
    end
    xlabel("Time (s)"); ylabel("Absolute tracking error");
    title("(b) Tracking-error magnitude");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    axes(axesHandles(3));
    for methodIndex = 1:numel(methods)
        result = tracking.(methods(methodIndex));
        stairs(time(1:end-1), result.control(1, :), ...
            Color=colors(methodIndex, :), LineWidth=1.05, ...
            DisplayName=labels(methodIndex));
        hold on;
    end
    xlabel("Time (s)"); ylabel("Agent 1 input");
    title("(c) Applied control input");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;
    % Reapply right-side y-axes after the final legends are created.
    axesHandles(2).YAxisLocation = "right";
    axesHandles(3).YAxisLocation = "right";
end

function figureHandle = plotTrigger(archive)
    fullIndex = find(archive.variants == "full", 1);
    if isempty(fullIndex)
        fullIndex = 1;
    end
    result = archive.episodes{fullIndex, 1};
    time = (1:numel(result.uncertainty)) .* archive.cfg.sim.sampleTime;

    figureHandle = createPublicationFigure("E3: IE-BPU trigger", [8.0, 5.8]);
    tiledlayout(figureHandle, 2, 2, TileSpacing="compact", Padding="compact");

    nexttile;
    semilogy(time, max(result.uncertainty, 1e-8), ...
        Color=[0.00, 0.45, 0.74], LineWidth=1.15, ...
        DisplayName="Predictive variance");
    hold on;
    semilogy(time, max(result.onThreshold, 1e-8), "r--", ...
        LineWidth=1.0, DisplayName="On threshold");
    semilogy(time, max(result.offThreshold, 1e-8), ":", ...
        Color=[0.75, 0.35, 0.10], LineWidth=1.0, ...
        DisplayName="Off threshold");
    xlabel("Time (s)"); ylabel("Uncertainty score");
    title("(a) Hysteretic uncertainty gate");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    semilogy(time, max(result.exactPe, 1e-10), ...
        Color=[0.10, 0.55, 0.25], LineWidth=1.15, ...
        DisplayName="Exact PE index");
    hold on;
    semilogy(time, max(result.lowerPe, 1e-10), ...
        Color=[0.45, 0.45, 0.45], LineWidth=1.0, ...
        DisplayName="Gershgorin lower bound");
    yline(archive.cfg.trigger.peThreshold, "k--", LineWidth=1.0, ...
        DisplayName="PE threshold");
    xlabel("Time (s)"); ylabel("Feature-Gramian margin");
    title("(b) PE monitoring");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    stairs(time, double(result.trigger), Color=[0.00, 0.45, 0.74], ...
        LineWidth=1.2, DisplayName="Exploration active");
    hold on;
    stem(time(result.onset), 0.82 .* ones(1, sum(result.onset)), "r", ...
        "filled", MarkerSize=3, DisplayName="Activation onset");
    ylim([-0.08, 1.08]); xlabel("Time (s)"); ylabel("Trigger state");
    title("(c) Exploration activation and onset");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    yyaxis left;
    semilogy(time, max(result.parameterError, 1e-6), ...
        Color=[0.45, 0.20, 0.70], LineWidth=1.15);
    ylabel("Parameter-error norm");
    yyaxis right;
    semilogy(time, max(result.covarianceTrace, 1e-6), ...
        Color=[0.15, 0.55, 0.65], LineWidth=1.0);
    ylabel("Covariance trace"); xlabel("Time (s)");
    title("(d) Inversion-free RLS convergence"); grid on;
end

function figureHandle = plotRecovery(archive)
    results = archive.results;
    representative = results{1, 1};
    variants = ["certifiedRecovery", "robustOnly", "pointOnly"];
    labels = ["Certified recovery", "Robust reward only", "Point-reward policy"];
    colors = lines(numel(variants));
    time = (0:(size(representative.state, 3) - 1)) .* ...
        archive.cfg.sim.sampleTime;

    figureHandle = createPublicationFigure( ...
        "E4: Certified recovery and withdrawal", [8.0, 5.8]);
    tiledlayout(figureHandle, 2, 2, TileSpacing="compact", Padding="compact");

    nexttile; hold on;
    for variantIndex = 1:numel(variants)
        result = results{variantIndex, 1};
        lastIndex = min(size(result.state, 3), ...
            round(result.metrics.completedFraction .* (numel(time) - 1)) + 1);
        plot(time(1:lastIndex), squeeze(result.state(1, 1, 1:lastIndex)), ...
            LineWidth=1.35, Color=colors(variantIndex, :), ...
            DisplayName=labels(variantIndex));
    end
    yline(archive.cfg.control.safetyPosition, "--k", HandleVisibility="off");
    yline(-archive.cfg.control.safetyPosition, "--k", HandleVisibility="off");
    xlabel("Time (s)"); ylabel("Agent 1 position");
    title("(a) In-domain strong-nonlinearity stress");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    plot(time(1:end-1), representative.desiredControl(1, :), ":", ...
        LineWidth=1.1, DisplayName="Desired proposal");
    hold on;
    plot(time(1:end-1), representative.control(1, :), ...
        LineWidth=1.35, DisplayName="Applied command");
    stairs(time(1:end-1), double(representative.recoveryIntervention), ...
        LineWidth=1.0, DisplayName="Recovery active");
    xlabel("Time (s)"); ylabel("Command / intervention");
    title("(b) Recovery projection");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    violationRate = zeros(1, numel(variants));
    interventionRate = zeros(1, numel(variants));
    for variantIndex = 1:numel(variants)
        selected = archive.rawTable(archive.rawTable.variant == ...
            variants(variantIndex), :);
        if isempty(selected)
            error("redrawFigures:MissingRecoveryVariant", ...
                "No E4 recovery rows match variant label %s.", ...
                variants(variantIndex));
        end
        violationRate(variantIndex) = ...
            mean(selected.anySafetyViolation, "omitmissing");
        interventionRate(variantIndex) = ...
            mean(selected.recoveryInterventionRate, "omitmissing");
    end
    bar([violationRate; interventionRate].');
    xticks(1:numel(variants));
    xticklabels(["Certified recovery", "Robust only", "Point only"]);
    ylabel("Across-seed fraction / time ratio");
    title("(c) Safety violations and intervention");
    legend(["Runs with violation", "Recovery intervention"], ...
        Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    withdrawalTimes = archive.withdrawalTable.withdrawalTime;
    histogram(withdrawalTimes(~isnan(withdrawalTimes)), 8, ...
        FaceColor=[0.30, 0.55, 0.82]);
    xlabel("Certificate-withdrawal time (s)"); ylabel("Run count");
    title("(d) Out-of-domain withdrawal"); grid on;
end

function figureHandle = plotRepresentation(archive)
    dimensions = archive.dimensions;
    data = archive.resultTable;
    timeSlope = archive.scalingTable.measuredRuntimeLogSlope(1);

    figureHandle = createPublicationFigure( ...
        "E5: Bayesian-head representation trade-off", [8.0, 5.8]);
    tiledlayout(figureHandle, 2, 2, TileSpacing="compact", Padding="compact");

    nexttile;
    semilogy(dimensions, data.referenceHeldOutMse, "-o", ...
        LineWidth=1.25, DisplayName="Reference head");
    hold on;
    semilogy(dimensions, data.onlineHeldOutMse, "-s", ...
        LineWidth=1.25, DisplayName="Online RLS");
    xlabel("Bayesian-head dimension"); ylabel("Held-out MSE");
    title("(a) Approximation and identification accuracy");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    loglog(dimensions, data.averageUpdateMicroseconds, "-o", LineWidth=1.25);
    xlabel("Bayesian-head dimension"); ylabel("Mean RLS update time (\mus)");
    title(sprintf("(b) Measured scaling slope %.2f", timeSlope)); grid on;

    nexttile;
    loglog(dimensions, data.totalHeadMemoryKilobytes, "-o", LineWidth=1.25);
    xlabel("Bayesian-head dimension"); ylabel("Head memory (KiB)");
    title("(c) Full covariance and PE-window memory"); grid on;

    nexttile;
    semilogy(dimensions, max(data.exactPeMargin, 1e-12), "-o", ...
        LineWidth=1.25, DisplayName="Exact minimum eigenvalue");
    hold on;
    semilogy(dimensions, max(data.gershgorinPeMargin, 1e-12), "--s", ...
        LineWidth=1.25, DisplayName="Gershgorin lower bound");
    xlabel("Bayesian-head dimension"); ylabel("PE margin");
    title("(d) Exact and conservative PE monitors");
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;
end

function figureHandle = plotScalability(archive)
    agents = archive.agentCounts;
    data = archive.summaryTable;
    observerSlope = archive.scalingTable.observerRuntimeLogSlope(1);

    figureHandle = createPublicationFigure("E6: Online scalability", [8.0, 4.6]);
    tiledlayout(figureHandle, 1, 2, TileSpacing="compact", Padding="compact");

    nexttile;
    loglog(agents, data.meanObserverMicroseconds, "-o", ...
        LineWidth=1.3, DisplayName="DC-IDO update");
    hold on;
    loglog(agents, data.meanActorMicroseconds, "-s", ...
        LineWidth=1.3, DisplayName="Shared Actor");
    loglog(agents, data.meanEndToEndMicroseconds, "-^", ...
        LineWidth=1.3, DisplayName="Complete online step");
    xlabel("Number of agents"); ylabel("Mean runtime per sample (\mus)");
    title(sprintf("(a) Runtime, DC-IDO slope %.2f", observerSlope));
    legend(Location="northoutside", NumColumns=2, FontSize=8); grid on;

    nexttile;
    yyaxis left;
    memoryLine = loglog(agents, data.meanPeakObserverMemoryKilobytes, ...
        "-o", LineWidth=1.3, Color=[0.00, 0.45, 0.74]);
    ylabel("Observer workspace (KiB)");
    yyaxis right;
    containmentLine = semilogx(agents, data.minimumContainmentRate, ...
        "-s", LineWidth=1.3, Color=[0.85, 0.33, 0.10]);
    hold on;
    retentionLine = semilogx(agents, data.minimumDelayRetentionRate, ...
        ":^", LineWidth=1.3, Color=[0.49, 0.18, 0.56]);
    ylim([0.98, 1.002]); ylabel("Minimum rate over seeds");
    xlabel("Number of agents"); title("(b) Workspace and validity");
    legend([memoryLine, containmentLine, retentionLine], ...
        ["Observer workspace", "State containment", "True-delay retention"], ...
        Location="northoutside", NumColumns=2, FontSize=8); grid on;
end

function figureHandle = plotCertificate(archive)
    summary = archive.summaryTable;
    certificateValues = [archive.policy.actorLipschitzBound, ...
        summary.maximumFrozenSpectralRadius(1), ...
        summary.worstCertifiedContraction(1)];

    figureHandle = createPublicationFigure( ...
        "E7: Frozen-Actor common-P certificate", [7.2, 4.2]);
    bar(certificateValues, 0.62, FaceColor=[0.25, 0.52, 0.78]);
    hold on;
    yline(1, "k--", "Unit-stability boundary", LineWidth=1.1);
    xticks(1:3);
    xticklabels(["Residual Actor bound", "Frozen-mode radius", ...
        "Common-P factor"]);
    xtickangle(12); ylabel("Certified / audited value");
    ylim([0, 1.08]); grid on;
end

function figureHandle = createPublicationFigure(figureName, figureSize)
    % Use a 7-inch double-column width and publication-sized heights.
    figureHandle = figure(Color="w", Visible="on", WindowStyle="normal", ...
        NumberTitle="off", Name=figureName, Units="inches", ...
        Position=[0.5, 0.5, figureSize], Resize="on", ...
        PaperUnits="inches", PaperPosition=[0, 0, figureSize], ...
        PaperPositionMode="manual", PaperSize=figureSize);
end

function axesHandles = createAxesGrid(figureHandle, positions)
    axesHandles = gobjects(size(positions, 1), 1);
    for axesIndex = 1:size(positions, 1)
        axesHandles(axesIndex) = axes(Parent=figureHandle, ...
            Units="normalized", Position=positions(axesIndex, :));
    end
end

function runInteractiveZoom(figureHandle, axesHandle, baseZoomFolder, figureLabel)
    requiredFiles = fullfile(baseZoomFolder, ["BaseZoom.m", "parameters.json"]);
    missingFiles = requiredFiles(~isfile(requiredFiles));
    if ~isempty(missingFiles)
        error("redrawFigures:MissingBaseZoom", ...
            "BaseZoom dependency file(s) are missing:%s%s", newline, ...
            strjoin(missingFiles, newline));
    end

    pathFolders = string(strsplit(path, pathsep));
    removePathAfterUse = ~any(strcmpi(pathFolders, baseZoomFolder));
    if removePathAfterUse
        addpath(baseZoomFolder);
    end
    pathCleanup = onCleanup(@() restoreBaseZoomPath( ...
        baseZoomFolder, removePathAfterUse));

    figure(figureHandle);
    figureHandle.CurrentAxes = axesHandle;
    fprintf("\nBaseZoom for %s: draw the inset position and right-click; ", ...
        figureLabel);
    fprintf("then draw the magnified data region and right-click.\n");
    zoomObject = constructBaseZoom(axesHandle, baseZoomFolder);
    zoomObject.run();
    setappdata(figureHandle, "BaseZoomObject", zoomObject);
    clear pathCleanup;
end

function assertIndependentFigures(figE1, figE2, figE3, figE4, figE5, figE6, figE7)
    figureIds = [figE1.Number, figE2.Number, figE3.Number, figE4.Number, ...
        figE5.Number, figE6.Number, figE7.Number];
    if numel(unique(figureIds)) ~= 7
        error("redrawFigures:FigureReuse", ...
            "Each result must be displayed in its own figure window.");
    end
end

function zoomObject = constructBaseZoom(axesHandle, baseZoomFolder)
    originalFolder = string(pwd);
    folderCleanup = onCleanup(@() cd(originalFolder));
    cd(baseZoomFolder);
    zoomObject = BaseZoom(axesHandle);
    clear folderCleanup;
end

function restoreBaseZoomPath(baseZoomFolder, removePathAfterUse)
    if removePathAfterUse
        rmpath(baseZoomFolder);
    end
end
