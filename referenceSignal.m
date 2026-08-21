function [positionReference, velocityReference] = referenceSignal(time, task)
%REFERENCESIGNAL Return the common stabilization or tracking reference.

arguments
    time double
    task (1,1) string {mustBeMember(task,["stabilization","tracking"])}
end

switch task
    case "stabilization"
        positionReference = zeros(size(time));
        velocityReference = zeros(size(time));
    case "tracking"
        amplitude = 0.75;
        frequency = 0.42;
        positionReference = amplitude .* sin(frequency .* time);
        velocityReference = amplitude * frequency .* cos(frequency .* time);
end
end

