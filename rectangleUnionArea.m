function area = rectangleUnionArea(lowerRectangles, upperRectangles)
%RECTANGLEUNIONAREA Compute the exact area of a union of 2-D rectangles.

arguments
    lowerRectangles (2,:) double
    upperRectangles (2,:) double
end

if isempty(lowerRectangles)
    area = 0;
    return
end

xCoordinates = unique([lowerRectangles(1, :), upperRectangles(1, :)]);
area = 0;
for strip = 1:(numel(xCoordinates) - 1)
    xLeft = xCoordinates(strip);
    xRight = xCoordinates(strip + 1);
    if xRight <= xLeft
        continue
    end
    active = lowerRectangles(1, :) < xRight & upperRectangles(1, :) > xLeft;
    if ~any(active)
        continue
    end
    yIntervals = sortrows([lowerRectangles(2, active).', upperRectangles(2, active).'], 1);
    covered = 0;
    currentLower = yIntervals(1, 1);
    currentUpper = yIntervals(1, 2);
    for row = 2:size(yIntervals, 1)
        if yIntervals(row, 1) <= currentUpper
            currentUpper = max(currentUpper, yIntervals(row, 2));
        else
            covered = covered + currentUpper - currentLower;
            currentLower = yIntervals(row, 1);
            currentUpper = yIntervals(row, 2);
        end
    end
    covered = covered + currentUpper - currentLower;
    area = area + (xRight - xLeft) * covered;
end
end

