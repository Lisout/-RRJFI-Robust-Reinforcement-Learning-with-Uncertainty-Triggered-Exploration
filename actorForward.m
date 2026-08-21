function [action, cache] = actorForward(actor, observation)
%ACTORFORWARD Evaluate the shared Actor for columnwise observations.

arguments
    actor (1,1) struct
    observation double
end

p = actor.parameters;
z1 = p.W1 * observation + p.b1;
h1 = tanh(z1);
z2 = p.W2 * h1 + p.b2;
h2 = tanh(z2);
z3 = p.W3 * h2 + p.b3;
unitAction = tanh(z3);
action = actor.outputScale .* unitAction;

if nargout > 1
    cache.observation = observation;
    cache.h1 = h1;
    cache.h2 = h2;
    cache.unitAction = unitAction;
end
end

