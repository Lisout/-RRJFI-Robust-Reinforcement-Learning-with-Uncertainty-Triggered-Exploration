function lowerBound = gershgorinLowerBound(matrix)
%GERSHGORINLOWERBOUND Return a nonnegative lower bound on lambda_min.

arguments
    matrix (:,:) double
end

diagonal = diag(matrix);
offDiagonalRadius = sum(abs(matrix), 2) - abs(diagonal);
lowerBound = max(0, min(diagonal - offDiagonalRadius));
end

