classdef TestObserverContainment < matlab.unittest.TestCase
    %TESTOBSERVERCONTAINMENT Integration tests for true-branch preservation.

    methods (TestClassSetup)
        function addCorePath(testCase)
            testFolder = fileparts(mfilename('fullpath'));
            coreFolder = fullfile(fileparts(testFolder), '01_core');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(coreFolder));
        end
    end

    methods (Test)
        function trueStateAndDelayRemainContained(testCase)
            cfg = rrjfi.defaultConfig(3);
            cfg.sim.numSteps = 90;
            adjacency = rrjfi.makeRingGraph(cfg.sim.numAgents);
            scenario = rrjfi.sampleScenario(cfg, 91, "tracking");
            state = scenario.initialState;
            lower = state - cfg.observer.initialRadius;
            upper = state + cfg.observer.initialRadius;
            controlHistory = zeros(cfg.sim.numAgents, cfg.sim.numSteps);

            for step = 1:cfg.sim.numSteps
                midpoint = 0.5 .* (lower + upper);
                reference = scenario.positionReference(step);
                velocityReference = scenario.velocityReference(step);
                control = -cfg.control.positionGain .* (midpoint(1, :) - reference) ...
                    - cfg.control.velocityGain .* (midpoint(2, :) - velocityReference);
                control = min(max(control, -cfg.control.inputLimit), cfg.control.inputLimit);
                controlHistory(:, step) = control.';

                process = scenario.processNoise(:, :, step) + scenario.disturbance(:, :, step);
                state = rrjfi.stepPlant(state, controlHistory, step, scenario.delay(:, step), ...
                    scenario, process, cfg, adjacency);
                measurement = state + scenario.measurementNoise(:, :, step + 1);
                update = rrjfi.stepObserver(lower, upper, controlHistory, step, measurement, cfg, adjacency);

                testCase.verifyTrue(update.isConsistent, sprintf('All branches rejected at step %d.', step));
                testCase.verifyGreaterThanOrEqual(state, update.lower);
                testCase.verifyLessThanOrEqual(state, update.upper);
                for agent = 1:cfg.sim.numAgents
                    delayIndex = find(cfg.sim.delayValues == scenario.delay(agent, step), 1);
                    testCase.verifyTrue(update.isRetained(agent, delayIndex));
                end
                lower = update.lower;
                upper = update.upper;
            end
        end

        function replayIsDeterministic(testCase)
            cfg = rrjfi.defaultConfig(3);
            first = rrjfi.sampleScenario(cfg, 777, "stabilization");
            second = rrjfi.sampleScenario(cfg, 777, "stabilization");
            testCase.verifyEqual(first.delay, second.delay);
            testCase.verifyEqual(first.processNoise, second.processNoise);
            testCase.verifyEqual(first.measurementNoise, second.measurementNoise);
            testCase.verifyEqual(first.initialState, second.initialState);
        end
    end
end
