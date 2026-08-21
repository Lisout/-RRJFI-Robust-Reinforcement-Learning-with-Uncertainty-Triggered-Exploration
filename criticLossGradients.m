function [loss, gradients] = criticLossGradients(critic, input, target)
%CRITICLOSSGRADIENTS Return mean-square Critic loss and parameter gradients.

arguments
    critic (1,1) struct
    input double
    target double
end

[value, cache] = rrjfiTraining.criticForward(critic, input);
batchSize = size(input, 2);
residual = value - target;
loss = mean(residual.^2);
dv = 2 .* residual ./ batchSize;
p = critic.parameters;

gradients.W3 = dv * cache.h2.';
gradients.b3 = sum(dv, 2);
dh2 = p.W3.' * dv;
dz2 = dh2 .* (1 - cache.h2.^2);
gradients.W2 = dz2 * cache.h1.';
gradients.b2 = sum(dz2, 2);
dh1 = p.W2.' * dz2;
dz1 = dh1 .* (1 - cache.h1.^2);
gradients.W1 = dz1 * cache.input.';
gradients.b1 = sum(dz1, 2);
end

