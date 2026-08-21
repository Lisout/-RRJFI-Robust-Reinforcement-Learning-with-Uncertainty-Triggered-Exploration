function target = softUpdate(target, source, rate)
%SOFTUPDATE Polyak-average network parameters.

arguments
    target (1,1) struct
    source (1,1) struct
    rate (1,1) double {mustBeGreaterThanOrEqual(rate,0),mustBeLessThanOrEqual(rate,1)}
end

names = fieldnames(source.parameters);
for index = 1:numel(names)
    name = names{index};
    target.parameters.(name) = (1 - rate) .* target.parameters.(name) ...
        + rate .* source.parameters.(name);
end
end

