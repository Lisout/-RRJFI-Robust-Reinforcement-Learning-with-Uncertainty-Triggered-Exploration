function [meanWeights, covariance, diagnostics] = rlsUpdate( ...
    meanWeights, covariance, features, target, forgettingFactor)
%RLSUPDATE Apply one inversion-free covariance-form RLS update.

arguments
    meanWeights (:,1) double
    covariance (:,:) double
    features (:,1) double
    target (1,1) double
    forgettingFactor (1,1) double {mustBePositive,mustBeLessThanOrEqual(forgettingFactor,1)}
end

covarianceFeature = covariance * features;
denominator = forgettingFactor + features.' * covarianceFeature;
gain = covarianceFeature / denominator;
innovation = target - features.' * meanWeights;
meanWeights = meanWeights + gain .* innovation;
covariance = (covariance - covarianceFeature * covarianceFeature.' / denominator) ./ forgettingFactor;
covariance = 0.5 .* (covariance + covariance.');
[vectors, values] = eig(covariance, 'vector');
values = max(values, 1e-10);
covariance = vectors * diag(values) * vectors.';

diagnostics.innovation = innovation;
diagnostics.uncertainty = features.' * covarianceFeature;
diagnostics.denominator = denominator;
end

