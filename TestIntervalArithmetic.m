classdef TestIntervalArithmetic < matlab.unittest.TestCase
    %TESTINTERVALARITHMETIC Unit tests for the custom interval primitives.

    methods (TestClassSetup)
        function addCorePath(testCase)
            testFolder = fileparts(mfilename('fullpath'));
            coreFolder = fullfile(fileparts(testFolder), '01_core');
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(coreFolder));
        end
    end

    methods (Test)
        function multiplicationContainsDenseSamples(testCase)
            lowerA = -1.2;
            upperA = 0.7;
            lowerB = -0.4;
            upperB = 1.8;
            [lowerProduct, upperProduct] = rrjfi.intervalMultiply(lowerA, upperA, lowerB, upperB);
            a = linspace(lowerA, upperA, 101);
            b = linspace(lowerB, upperB, 103);
            samples = a.' .* b;
            testCase.verifyLessThanOrEqual(lowerProduct, min(samples, [], 'all'));
            testCase.verifyGreaterThanOrEqual(upperProduct, max(samples, [], 'all'));
        end

        function sineCapturesInteriorExtrema(testCase)
            [lowerSin, upperSin] = rrjfi.sinInterval(-0.2, 2.1);
            testCase.verifyEqual(upperSin, 1, 'AbsTol', 1e-14);
            testCase.verifyEqual(lowerSin, sin(-0.2), 'AbsTol', 1e-14);

            [lowerWide, upperWide] = rrjfi.sinInterval(-4, 4);
            testCase.verifyEqual(lowerWide, -1, 'AbsTol', 1e-14);
            testCase.verifyEqual(upperWide, 1, 'AbsTol', 1e-14);
        end

        function rectangleUnionAreaHandlesOverlap(testCase)
            lower = [0, 0.5; 0, 0.5];
            upper = [1, 1.5; 1, 1.5];
            area = rrjfi.rectangleUnionArea(lower, upper);
            testCase.verifyEqual(area, 1.75, 'AbsTol', 1e-12);
        end
    end
end
