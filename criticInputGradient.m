function inputGradient = criticInputGradient(critic, input)
%CRITICINPUTGRADIENT Return d(sum Q)/d(input) for each independent sample.

arguments
    critic (1,1) struct
    input double
end

[~, cache] = rrjfiTraining.criticForward(critic, input);
p = critic.parameters;
dv = ones(1, size(input, 2));
dh2 = p.W3.' * dv;
dz2 = dh2 .* (1 - cache.h2.^2);
dh1 = p.W2.' * dz2;
dz1 = dh1 .* (1 - cache.h1.^2);
inputGradient = p.W1.' * dz1;
end

