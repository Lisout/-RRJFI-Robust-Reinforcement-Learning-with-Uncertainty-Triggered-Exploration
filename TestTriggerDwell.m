classdef TestTriggerDwell < matlab.unittest.TestCase
    %TESTTRIGGERDWELL Regression checks for digital trigger separation.

    methods (Test)
        function fullTriggerRespectsRefractoryInterval(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            data = load(fullfile(projectRoot, '05_results', ...
                'E3_iebpu_full_results.mat'), 'cfg', 'episodes');
            requiredSamples = data.cfg.trigger.refractorySamples;
            for episodeIndex = 1:size(data.episodes, 2)
                onsets = find(data.episodes{1, episodeIndex}.onset);
                if numel(onsets) > 1
                    testCase.verifyGreaterThanOrEqual(min(diff(onsets)), requiredSamples)
                end
            end
        end

        function sampleGridExcludesClassicalZenoAccumulation(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            data = load(fullfile(projectRoot, '05_results', ...
                'E3_iebpu_full_results.mat'), 'cfg');
            testCase.verifyGreaterThan(data.cfg.sim.sampleTime, 0)
            theoreticalSeparation = data.cfg.trigger.refractorySamples ...
                .* data.cfg.sim.sampleTime;
            testCase.verifyEqual(theoreticalSeparation, 0.8, 'AbsTol', 1e-12)
        end
    end
end
