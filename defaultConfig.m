function cfg = defaultConfig(numAgents)
%DEFAULTCONFIG Return the reproducible benchmark configuration.
%   CFG = rrjfi.defaultConfig(NUMAGENTS) defines the uncertain nonlinear
%   multi-agent plant, interval observer, controllers, trigger, and paths.

arguments
    numAgents (1,1) double {mustBeInteger,mustBePositive} = 3
end

cfg.meta.packageVersion = "1.0.0";
cfg.meta.matlabRelease = version('-release');

cfg.sim.numAgents = numAgents;
cfg.sim.sampleTime = 0.10;
cfg.sim.numSteps = 320;
cfg.sim.delayValues = 0:2;
cfg.sim.trainingSeed = 314159;
cfg.sim.evaluationSeeds = 1201:1220;

cfg.model.sinGain = [0.08, 0.12];
cfg.model.damping = [0.28, 0.36];
cfg.model.inputGain = [0.95, 1.05];
cfg.model.couplingGain = [0.10, 0.14];
cfg.model.positionDomain = [-2.4, 2.4];
cfg.model.velocityDomain = [-2.8, 2.8];

cfg.noise.randomProcessBound = [2e-4; 1e-3];
cfg.noise.processBound = [4e-4; 5e-3];
cfg.noise.measurementBound = [1.2e-2; 1.2e-2];

cfg.observer.initialRadius = [0.035; 0.045];
cfg.observer.minimumWidthForCertificate = [0.012; 0.016];
cfg.observer.maximumAllowedWidth = [0.30; 0.45];
cfg.observer.velocityMeasurementPeriod = 1;

cfg.control.positionGain = 1.00;
cfg.control.velocityGain = 1.25;
cfg.control.consensusGain = 0.30;
cfg.control.integralGain = 0.06;
cfg.control.inputLimit = 2.50;
cfg.control.residualLimit = 0.30;
cfg.control.referencePreview = 0;
cfg.control.safetyPosition = 2.25;
cfg.control.safetyVelocity = 2.65;
cfg.control.recoveryWidthLimit = [0.24; 0.36];
cfg.control.safetyGridSize = 81;

cfg.reward.positionWeight = 2.0;
cfg.reward.velocityWeight = 0.40;
cfg.reward.consensusWeight = 0.55;
cfg.reward.inputWeight = 0.035;
cfg.reward.widthWeight = 0.80;
cfg.reward.safetyPenalty = 80.0;
cfg.reward.discount = 0.985;

cfg.trigger.featureDimension = 16;
cfg.trigger.peWindow = 80;
cfg.trigger.forgettingFactor = 0.995;
cfg.trigger.priorScale = 12.0;
cfg.trigger.baseThreshold = 0.035;
cfg.trigger.hysteresisHalfWidth = 0.006;
cfg.trigger.peThreshold = 0.15;
cfg.trigger.useExactPe = true;
cfg.trigger.refractorySamples = 8;
cfg.trigger.performanceGain = 1.2;
cfg.trigger.performanceScale = 0.50;
cfg.trigger.safetyGain = 5.0;
cfg.trigger.safetyRate = 2.0;
cfg.trigger.cooperationGain = 0.15;
cfg.trigger.explorationAmplitude = 0.24;
cfg.trigger.targetNoiseBound = 5e-3;

cfg.training.numEpisodes = 100;
cfg.training.stepsPerEpisode = 160;
cfg.training.warmupSteps = 1200;
cfg.training.batchSize = 128;
cfg.training.replayCapacity = 60000;
cfg.training.actorLearningRate = 2e-4;
cfg.training.criticLearningRate = 8e-4;
cfg.training.targetRate = 5e-3;
cfg.training.explorationStd = 0.20;
cfg.training.explorationDecay = 0.997;
cfg.training.hiddenWidth = 48;
cfg.training.robustScenarios = 4;

cfg.scenario.pulseAmplitude = 3e-3;
cfg.scenario.probePrimary = 2.00;
cfg.scenario.probeSecondary = 0.45;

cfg.baseline.nominalDelay = 1;
cfg.baseline.smithPositionGain = 0.95;
cfg.baseline.smithVelocityGain = 1.20;
cfg.baseline.pidPositionGain = 1.05;
cfg.baseline.pidVelocityGain = 1.30;
cfg.baseline.pidIntegralGain = 0.04;
cfg.baseline.observerBlend = 0.72;
cfg.baseline.integralLimit = 1.5;

packageFolder = fileparts(mfilename('fullpath'));
coreFolder = fileparts(packageFolder);
cfg.paths.root = fileparts(coreFolder);
cfg.paths.results = fullfile(cfg.paths.root, '05_results');
cfg.paths.figures = fullfile(cfg.paths.root, '06_figures');
cfg.paths.supplement = fullfile(cfg.paths.root, '07_supplement');
end
