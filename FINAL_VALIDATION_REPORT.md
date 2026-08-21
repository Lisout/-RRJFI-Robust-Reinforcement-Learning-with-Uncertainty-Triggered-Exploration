# RRJFI Final Validation Report

Date: 2026-08-20

## Scope

This audit covers the revised manuscript, the highlighted manuscript, the three Typora response variants, the LaTeX response letter, all regenerated MATLAB experiments, archived numerical results, and figure/data consistency.

## Experimental verification

- E1: 20 seeds and 360 samples per seed; state containment and true-delay retention were both 100%. Measurement refinement reduced the one-step robust-reward width by 49.19% on average.
- E2: proposed, point-state MADDPG, tuned Smith predictor, and tuned observer-based PID were evaluated on the same 20 test seeds. Paired Wilcoxon tests and confidence intervals were regenerated from seed-level data. The revised text explicitly reports that PID remains preferable for stabilization RMSE and settling time, while the proposed method provides the strongest tested tracking result.
- E3: four exploration policies were compared over 12 common seeds. Full IE-BPU used 30.55% activation and 57.23 mean excitation energy versus 100% and 187.47 for continuous exploration. Every observed full-gate inter-onset time was at least 0.8 s.
- E4: certified recovery yielded 0/20 in-domain violations; robust-only and point-only variants yielded 18/20 and 11/20. All 12 out-of-domain trials withdrew the certificate in 0.2--1.9 s.
- E5: Bayesian/RLS head dimensions 4, 8, 16, 32, and 48 were evaluated for accuracy, full-covariance memory, PE, and measured update time.
- E6: networks from 3 to 200 agents were evaluated over five seeds per size. In the archived rerun at 200 agents, the mean DC-IDO, Actor, and complete online-step times were 1.219, 0.344, and 5.319 ms for a 100 ms sampling period, with 100% containment and true-delay retention.
- E7: the actual frozen seed-3101 Actor was audited over 4,096 parameter vertices and 27 asynchronous delay patterns, giving 110,592 modes. The worst common-$P$ contraction factor was 0.991233929, below one.

## Automated checks

- MATLAB unit tests: 15 passed, 0 failed, 0 incomplete. The added test verifies all required editable FIG sources.
- MATLAB Code Analyzer: 0 messages across 61 MATLAB files.
- Final static/document audit: 104 passed, 0 failed.
- Response inventory: 38 unique comments, with reviewer counts 5/5/6/6/10/6.
- Each response Markdown file contains 38 Caution blocks, 38 plain response sections, and 38 Note blocks.
- Each reviewer folder has three complete standalone language variants with the correct reviewer-specific comment count.
- All display-math delimiters are balanced and no display equation ends in punctuation.
- The manuscript contains neither proposition nor the misspelling propsition.
- All Markdown image references resolve to archived files.
- Ten editable MATLAB `.fig` files are present, including E1--E7, the workflow, the E3 variant figure, and the training curves.
- The highlighted LaTeX contains more than 5,000 real `\hl{}` commands with `\sethlcolor{yellow}`.
- Clean manuscript, highlighted manuscript, and response-letter LaTeX builds have no critical compilation error, undefined reference, duplicate destination, or missing citation.
- The newest review-sensitive references (Refs. 33--39) were cross-checked against current publisher/bibliographic metadata; no correction was required.

## Compiled artifacts

- Clean manuscript PDF: 19 pages.
- Highlighted manuscript PDF: 18 pages.
- English LaTeX response letter PDF: 50 pages.

## P0 closure

- Reviewer #1--Comment 2: the hull term now has a center--spread inequality, a certified cell-wise maximum construction, and the benchmark cap $[0.024,0.024]^{\mathsf T}$.
- Reviewer #5--Comment 2: Assumption 1--5 each carry local literature support, and the response Note quotes both the assumption block and the matched-seed comparison block.
- Reviewer #9--Comment 6: Section 5 contains a row-by-row dynamic event-trigger comparison and explicitly distinguishes the algebraically adaptive IE-BPU threshold from a dynamic internal-state trigger.

## Claim boundaries retained in the revision

- Deterministic interval uncertainty and Bayesian epistemic uncertainty are kept separate.
- Training proposes a candidate policy; spectral normalization bounds sensitivity; the post-training common-$P$ test provides the benchmark deployment certificate.
- IE-BPU triggers bounded auxiliary exploration only, not communication, measurement, controller, or observer updates.
- The recovery guarantee is restricted to the declared inclusion-valid domain and is withdrawn when the assumptions fail.
- The stability audit is an exhaustive benchmark-family certificate, not a global guarantee for arbitrary network size or unmodeled dynamics.
- The reported timing results are simulation measurements on the declared MATLAB/CPU platform and are not substituted for a hardware or asymptotic scalability proof.

## Reproduction commands

MATLAB:

    root = 'D:/mat/mat_for_IDAOmas/RRJFI';
    addpath(genpath(root));
    results = runAllTests;

PowerShell:

    & 'D:\mat\mat_for_IDAOmas\RRJFI\00_project_control\final_audit.ps1'
