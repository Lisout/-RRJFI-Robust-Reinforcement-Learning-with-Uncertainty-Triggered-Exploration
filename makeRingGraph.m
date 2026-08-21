function adjacency = makeRingGraph(numAgents)
%MAKERINGGRAPH Create a connected bidirectional unit-weight ring.

arguments
    numAgents (1,1) double {mustBeInteger,mustBePositive}
end

adjacency = spalloc(numAgents, numAgents, 2 * numAgents);
if numAgents == 1
    return
end

agents = (1:numAgents).';
previous = mod(agents - 2, numAgents) + 1;
next = mod(agents, numAgents) + 1;
adjacency = sparse([agents; agents], [previous; next], ...
    ones(2 * numAgents, 1), numAgents, numAgents);
end
