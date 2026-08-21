function [parameters, state] = adamStep(parameters, gradients, state, learningRate, iteration)
%ADAMSTEP Apply one Adam update to a flat parameter structure.

arguments
    parameters (1,1) struct
    gradients (1,1) struct
    state (1,1) struct
    learningRate (1,1) double {mustBePositive}
    iteration (1,1) double {mustBeInteger,mustBePositive}
end

beta1 = 0.9;
beta2 = 0.999;
epsilon = 1e-8;
names = fieldnames(parameters);
for index = 1:numel(names)
    name = names{index};
    if ~isfield(state, 'first')
        state.first = struct;
        state.second = struct;
    end
    if ~isfield(state.first, name)
        state.first.(name) = zeros(size(parameters.(name)));
        state.second.(name) = zeros(size(parameters.(name)));
    end
    state.first.(name) = beta1 .* state.first.(name) + (1 - beta1) .* gradients.(name);
    state.second.(name) = beta2 .* state.second.(name) + (1 - beta2) .* gradients.(name).^2;
    firstHat = state.first.(name) ./ (1 - beta1^iteration);
    secondHat = state.second.(name) ./ (1 - beta2^iteration);
    parameters.(name) = parameters.(name) ...
        - learningRate .* firstHat ./ (sqrt(secondHat) + epsilon);
end
end

