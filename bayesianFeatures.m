function [features, teacherValue] = bayesianFeatures(policy, head, jointObservation, action)
%BAYESIANFEATURES Evaluate frozen bottleneck features and teacher Critic.

arguments
    policy (1,1) struct
    head (1,1) struct
    jointObservation double
    action double
end

[teacherValue, ~, deepFeatures] = rrjfiTraining.criticForward( ...
    policy.lowerCritic, [jointObservation; action]);
centered = deepFeatures - head.center;
reduced = (head.projection * centered) ./ head.scale;
features = [reduced; ones(1, size(reduced, 2))] ./ sqrt(head.featureDimension);
end

