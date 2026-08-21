function actor = initializeActor(inputDimension, hiddenWidth, outputScale, seed, useSpectralNormalization)
%INITIALIZEACTOR Create a two-hidden-layer deterministic Actor.

arguments
    inputDimension (1,1) double {mustBeInteger,mustBePositive}
    hiddenWidth (1,1) double {mustBeInteger,mustBePositive}
    outputScale (1,1) double {mustBePositive}
    seed (1,1) double {mustBeInteger,mustBeNonnegative}
    useSpectralNormalization (1,1) logical = true
end

stream = RandStream('Threefry', 'Seed', seed);
actor.parameters.W1 = xavier(stream, hiddenWidth, inputDimension);
actor.parameters.b1 = zeros(hiddenWidth, 1);
actor.parameters.W2 = xavier(stream, hiddenWidth, hiddenWidth);
actor.parameters.b2 = zeros(hiddenWidth, 1);
actor.parameters.W3 = 0.08 .* xavier(stream, 1, hiddenWidth);
actor.parameters.b3 = 0;
actor.outputScale = outputScale;
actor.inputDimension = inputDimension;
actor.hiddenWidth = hiddenWidth;
actor.useSpectralNormalization = useSpectralNormalization;
actor.spectralBounds = [1.10, 1.10, 0.85];
end

function weights = xavier(stream, rows, columns)
limit = sqrt(6 / (rows + columns));
weights = (2 .* rand(stream, rows, columns) - 1) .* limit;
end

