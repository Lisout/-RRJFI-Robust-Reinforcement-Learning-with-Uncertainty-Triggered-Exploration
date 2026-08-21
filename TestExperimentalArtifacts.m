classdef TestExperimentalArtifacts < matlab.unittest.TestCase
    %TESTEXPERIMENTALARTIFACTS Cross-check the principal reported claims.

    methods (Test)
        function observerAndControllerContainmentIsComplete(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            observer = readtable(fullfile(projectRoot, '05_results', ...
                'E1_observer_seed_metrics.csv'));
            controller = readtable(fullfile(projectRoot, '05_results', ...
                'E2_control_seed_metrics.csv'));
            testCase.verifyEqual(min(observer.containmentRate), 1, 'AbsTol', 1e-12)
            proposed = controller(controller.method == "proposed", :);
            testCase.verifyEqual(min(proposed.containmentRate), 1, 'AbsTol', 1e-12)
        end

        function recoveryCertificatePreventsStressViolations(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            recovery = readtable(fullfile(projectRoot, '05_results', ...
                'E4_recovery_raw_metrics.csv'));
            certified = recovery(recovery.variant == "certifiedRecovery", :);
            robustOnly = recovery(recovery.variant == "robustOnly", :);
            testCase.verifyFalse(any(certified.anySafetyViolation))
            testCase.verifyTrue(any(robustOnly.anySafetyViolation))
            testCase.verifyEqual(min(certified.recoveryFeasibilityRate), 1, 'AbsTol', 1e-12)
        end

        function exhaustivePostTrainingCertificateIsFeasible(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            certificate = readtable(fullfile(projectRoot, '05_results', ...
                'E7_certificate_summary.csv'));
            testCase.verifyEqual(certificate.certificateFeasible, 1)
            testCase.verifyLessThan(certificate.worstCertifiedContraction, 1)
            testCase.verifyEqual(certificate.totalEnumeratedModes, 110592)
        end

        function largeNetworkRetainsCertifiedBranches(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            scalability = readtable(fullfile(projectRoot, '05_results', ...
                'E6_scalability_summary.csv'));
            testCase.verifyEqual(max(scalability.numAgents), 200)
            testCase.verifyEqual(min(scalability.minimumContainmentRate), 1, 'AbsTol', 1e-12)
            testCase.verifyEqual(min(scalability.minimumDelayRetentionRate), 1, 'AbsTol', 1e-12)
        end

        function editableFigureSourcesExist(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            figureNames = [ ...
                "workflow_complete_algorithm.fig"; ...
                "training_curves.fig"; ...
                "E1_observer_and_hull.fig"; ...
                "E2_controller_comparison.fig"; ...
                "E3_iebpu_trigger.fig"; ...
                "E3_iebpu_variants.fig"; ...
                "E4_recovery_and_withdrawal.fig"; ...
                "E5_representation_ablation.fig"; ...
                "E6_scalability.fig"; ...
                "E7_common_lyapunov_certificate.fig"];
            figureFolder = fullfile(projectRoot, '06_figures');
            for figureIndex = 1:numel(figureNames)
                figurePath = fullfile(figureFolder, figureNames(figureIndex));
                testCase.verifyTrue(isfile(figurePath), ...
                    sprintf('Missing editable figure source: %s', figurePath))
            end
        end
    end
end
