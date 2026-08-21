function [lowerSin, upperSin] = sinInterval(lowerX, upperX)
%SININTERVAL Return a rigorous componentwise enclosure of sin([LOWERX,UPPERX]).

arguments
    lowerX double
    upperX double
end

if any(lowerX > upperX, 'all')
    error('rrjfi:InvalidInterval', 'Every lower endpoint must not exceed its upper endpoint.')
end

lowerSin = min(sin(lowerX), sin(upperX));
upperSin = max(sin(lowerX), sin(upperX));

for index = 1:numel(lowerX)
    lo = lowerX(index);
    hi = upperX(index);
    if hi - lo >= 2*pi
        lowerSin(index) = -1;
        upperSin(index) = 1;
        continue
    end

    maximumIndex = ceil((lo - pi/2) / (2*pi));
    if pi/2 + 2*pi*maximumIndex <= hi
        upperSin(index) = 1;
    end

    minimumIndex = ceil((lo - 3*pi/2) / (2*pi));
    if 3*pi/2 + 2*pi*minimumIndex <= hi
        lowerSin(index) = -1;
    end
end
end

