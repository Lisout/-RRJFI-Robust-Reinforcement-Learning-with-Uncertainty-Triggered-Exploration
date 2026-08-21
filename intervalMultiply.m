function [lowerProduct, upperProduct] = intervalMultiply(lowerA, upperA, lowerB, upperB)
%INTERVALMULTIPLY Compute the natural product of two real intervals.

arguments
    lowerA double
    upperA double
    lowerB double
    upperB double
end

products = cat(ndims(lowerA) + 1, ...
    lowerA .* lowerB, lowerA .* upperB, upperA .* lowerB, upperA .* upperB);
lowerProduct = min(products, [], ndims(products));
upperProduct = max(products, [], ndims(products));
end

