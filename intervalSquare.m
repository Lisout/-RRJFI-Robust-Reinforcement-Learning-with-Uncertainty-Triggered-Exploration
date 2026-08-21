function [lowerSquare, upperSquare] = intervalSquare(lowerX, upperX)
%INTERVALSQUARE Compute the exact componentwise square interval.

arguments
    lowerX double
    upperX double
end

upperSquare = max(lowerX.^2, upperX.^2);
lowerSquare = min(lowerX.^2, upperX.^2);
containsZero = lowerX <= 0 & upperX >= 0;
lowerSquare(containsZero) = 0;
end

