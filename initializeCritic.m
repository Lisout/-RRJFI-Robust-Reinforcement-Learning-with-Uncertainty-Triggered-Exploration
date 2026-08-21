function critic = initializeCritic(inputDimension, hiddenWidth, seed)
%INITIALIZECRITIC Create a centralized two-hidden-layer team Critic.

arguments
    inputDimension (1,1) double {mustBeInteger,mustBePositive}
    hiddenWidth (1,1) double {mustBeInteger,mustBePositive}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
end

stream = RandStream('Threefry', 'Seed', seed);
critic.parameters.W1 = xavier(stream, hiddenWidth, inputDimension);
critic.parameters.b1 = zeros(hiddenWidth, 1);
critic.parameters.W2 = xavier(stream, hiddenWidth, hiddenWidth);
critic.parameters.b2 = zeros(hiddenWidth, 1);
critic.parameters.W3 = 0.05 .* xavier(stream, 1, hiddenWidth);
critic.parameters.b3 = 0;
critic.inputDimension = inputDimension;
critic.hiddenWidth = hiddenWidth;
end

function weights = xavier(stream, rows, columns)
limit = sqrt(6 / (rows + columns));
weights = (2 .* rand(stream, rows, columns) - 1) .* limit;
end

