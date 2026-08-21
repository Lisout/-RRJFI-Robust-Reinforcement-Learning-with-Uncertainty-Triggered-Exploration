function [actor, layerNorms] = enforceActorSpectralBounds(actor)
%ENFORCEACTORSPECTRALBOUNDS Project Actor matrices onto spectral-norm balls.

arguments
    actor (1,1) struct
end

weightNames = {'W1','W2','W3'};
layerNorms = zeros(1, numel(weightNames));
for index = 1:numel(weightNames)
    name = weightNames{index};
    weights = actor.parameters.(name);
    layerNorms(index) = norm(weights, 2);
    bound = actor.spectralBounds(index);
    if actor.useSpectralNormalization && layerNorms(index) > bound
        actor.parameters.(name) = weights .* (bound / layerNorms(index));
        layerNorms(index) = bound;
    end
end
end

