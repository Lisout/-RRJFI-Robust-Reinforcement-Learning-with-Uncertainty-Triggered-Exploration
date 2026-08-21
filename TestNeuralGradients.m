classdef TestNeuralGradients < matlab.unittest.TestCase
    %TESTNEURALGRADIENTS Finite-difference checks for manual backpropagation.

    methods (Test)
        function actorGradientMatchesFiniteDifference(testCase)
            actor = rrjfiTraining.initializeActor(3, 4, 0.7, 101, false);
            observation = [0.2, -0.3; 0.4, 0.1; -0.5, 0.6];
            actionDerivative = [0.8, -0.35];
            [~, cache] = rrjfiTraining.actorForward(actor, observation);
            gradients = rrjfiTraining.actorBackward(actor, cache, actionDerivative);

            checks = {"W1", [2, 3]; "W2", [3, 1]; "W3", [1, 4]; "b2", [2, 1]};
            for checkIndex = 1:size(checks, 1)
                name = checks{checkIndex, 1};
                location = checks{checkIndex, 2};
                numerical = actorDifference(actor, observation, actionDerivative, name, location);
                analytical = gradients.(name)(location(1), location(2));
                testCase.verifyEqual(analytical, numerical, 'RelTol', 2e-5, 'AbsTol', 2e-7)
            end
        end

        function criticGradientMatchesFiniteDifference(testCase)
            critic = rrjfiTraining.initializeCritic(5, 4, 202);
            input = reshape(linspace(-0.6, 0.7, 15), 5, 3);
            target = [0.3, -0.2, 0.5];
            [~, gradients] = rrjfiTraining.criticLossGradients(critic, input, target);

            checks = {"W1", [1, 4]; "W2", [4, 2]; "W3", [1, 3]; "b1", [3, 1]};
            for checkIndex = 1:size(checks, 1)
                name = checks{checkIndex, 1};
                location = checks{checkIndex, 2};
                numerical = criticDifference(critic, input, target, name, location);
                analytical = gradients.(name)(location(1), location(2));
                testCase.verifyEqual(analytical, numerical, 'RelTol', 2e-5, 'AbsTol', 2e-7)
            end
        end

        function criticInputGradientMatchesFiniteDifference(testCase)
            critic = rrjfiTraining.initializeCritic(4, 5, 303);
            input = [0.2; -0.4; 0.7; 0.1];
            analytical = rrjfiTraining.criticInputGradient(critic, input);
            numerical = zeros(size(input));
            step = 1e-6;
            for index = 1:numel(input)
                perturbation = zeros(size(input));
                perturbation(index) = step;
                plus = rrjfiTraining.criticForward(critic, input + perturbation);
                minus = rrjfiTraining.criticForward(critic, input - perturbation);
                numerical(index) = (plus - minus) ./ (2 .* step);
            end
            testCase.verifyEqual(analytical, numerical, 'RelTol', 2e-5, 'AbsTol', 2e-7)
        end
    end
end

function derivative = actorDifference(actor, observation, actionDerivative, name, location)
step = 1e-6;
plusActor = actor;
minusActor = actor;
plusActor.parameters.(name)(location(1), location(2)) = ...
    plusActor.parameters.(name)(location(1), location(2)) + step;
minusActor.parameters.(name)(location(1), location(2)) = ...
    minusActor.parameters.(name)(location(1), location(2)) - step;
plusLoss = sum(rrjfiTraining.actorForward(plusActor, observation) .* actionDerivative, 'all');
minusLoss = sum(rrjfiTraining.actorForward(minusActor, observation) .* actionDerivative, 'all');
derivative = (plusLoss - minusLoss) ./ (2 .* step);
end

function derivative = criticDifference(critic, input, target, name, location)
step = 1e-6;
plusCritic = critic;
minusCritic = critic;
plusCritic.parameters.(name)(location(1), location(2)) = ...
    plusCritic.parameters.(name)(location(1), location(2)) + step;
minusCritic.parameters.(name)(location(1), location(2)) = ...
    minusCritic.parameters.(name)(location(1), location(2)) - step;
plusValue = rrjfiTraining.criticForward(plusCritic, input);
minusValue = rrjfiTraining.criticForward(minusCritic, input);
plusLoss = mean((plusValue - target).^2);
minusLoss = mean((minusValue - target).^2);
derivative = (plusLoss - minusLoss) ./ (2 .* step);
end
