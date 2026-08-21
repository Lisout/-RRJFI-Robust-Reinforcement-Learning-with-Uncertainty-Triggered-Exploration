function [value, cache, features] = criticForward(critic, input)
%CRITICFORWARD Evaluate centralized Critic values for columnwise samples.

arguments
    critic (1,1) struct
    input double
end

p = critic.parameters;
z1 = p.W1 * input + p.b1;
h1 = tanh(z1);
z2 = p.W2 * h1 + p.b2;
h2 = tanh(z2);
value = p.W3 * h2 + p.b3;

if nargout > 1
    cache.input = input;
    cache.h1 = h1;
    cache.h2 = h2;
end
if nargout > 2
    features = h2;
end
end

