function gradients = actorBackward(actor, cache, actionDerivative)
%ACTORBACKWARD Backpropagate a scalar loss derivative through the Actor.

arguments
    actor (1,1) struct
    cache (1,1) struct
    actionDerivative double
end

p = actor.parameters;
dz3 = actionDerivative .* actor.outputScale .* (1 - cache.unitAction.^2);
gradients.W3 = dz3 * cache.h2.';
gradients.b3 = sum(dz3, 2);
dh2 = p.W3.' * dz3;
dz2 = dh2 .* (1 - cache.h2.^2);
gradients.W2 = dz2 * cache.h1.';
gradients.b2 = sum(dz2, 2);
dh1 = p.W2.' * dz2;
dz1 = dh1 .* (1 - cache.h1.^2);
gradients.W1 = dz1 * cache.observation.';
gradients.b1 = sum(dz1, 2);
end

