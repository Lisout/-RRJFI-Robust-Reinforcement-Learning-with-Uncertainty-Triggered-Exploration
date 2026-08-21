# Experiment-to-reviewer map

## Scientific policy

The revised study distinguishes analytic guarantees, computed certificates, and empirical evidence. Plots do not prove containment, anti-Zeno behavior, convergence, or stability. Analytic results are invoked only when their stated assumptions and computed certificate conditions are satisfied.

## E1 — DC-IDO containment, delay refinement, and hull conservatism

Outputs: state containment, true-delay retention, delay-set cardinality, midpoint RMSE, branch/hull widths, hull inflation/excess, measurement contraction, and one-step robust-reward interval width.

Addresses: R1-C1/C2/C5, R2-C4, R4-C3/C5, R7-C3/C4, R9-C1/C4.

## E2 — Fair closed-loop controller comparison

Controllers: proposed certified robust residual Actor--Critic, standard parameter-sharing MADDPG, nominal-delay Smith predictor, and observer-based PID. The learned methods use matched hidden widths, replay size, batch size, optimization steps, training seeds, and environment interactions. Model-based baselines are tuned on separate tuning seeds.

Outputs: stabilization and tracking RMSE, worst error, settling time, control energy, safety violations, observer containment, recovery interventions, and paired-seed confidence intervals.

Addresses: R1-C5, R2-C4, R4-C5/C6, R5-C2/C4/C5, R9-C5.

## E3 — IE-BPU trigger and Bayesian/RLS update

Variants: full PE/uncertainty/safety gate with hysteresis and refractory counter, entropy-only trigger, continuous exploration, and no auxiliary exploration.

Outputs: predictive variance, dynamic on/off thresholds, exact PE eigenvalue, conservative PE bound, activation ratio, switching rate, minimum inter-onset time, exploration energy, held-out TD error, and RLS covariance trace.

Addresses: R2-C2, R4-C1/C5, R7-C7/C8/C9, R9-C2/C3.

## E4 — Certified recovery in inclusion-valid nonlinear regions

Variants: certified action projection, soft width reward only, and no recovery. A separate out-of-domain diagnostic withdraws certification rather than claiming safety after the assumed inclusion model fails.

Outputs: containment, safe-set violations, maximum interval width, recovery feasibility/intervention rates, and tracking error.

Addresses: R5-C3, R7-C10, R9-C1 and the transient-safety concern in R9's summary.

## E5 — Neural-linear representation ablation

Bayesian bottleneck dimensions are compared using the same frozen nonlinear feature extractor and train/validation split.

Outputs: reference-head and online-RLS held-out MSE, final parameter error, exact and Gershgorin PE margins, full-covariance/head memory, and measured update latency.

Addresses: R7-C9 and R9-C2.

## E6 — Scalability and execution-time profiling

DC-IDO, the shared Actor, and the complete online loop are profiled on bidirectional ring graphs from 3 to 200 agents, with five seeds per size.

Outputs: mean observer, Actor, and end-to-end step time; observer workspace; containment; true-delay retention; empirical finite-range log--log slopes; and sampling-period utilization.

Addresses: R4-C5, R7-C9, R9-C4.

## E7 — Post-training policy/stability certificate

The actual frozen seed-3101 Actor is retained, including its nonzero equilibrium residual. The audit distinguishes its finite-difference local Jacobian norm from the product-of-layer-norms sensitivity bound, enumerates 4,096 independent parameter endpoints and 27 asynchronous delay modes, generates a common $P$, and then scans all 110,592 modes.

Outputs: Actor equilibrium residual, local Jacobian norm, global spectral-product bound, common-$P$ condition number, maximum frozen-mode spectral radius, and worst common-$P$ contraction factor. Any policy update invalidates the certificate until recomputed.

Addresses: R1-C1/C3, R4-C2/C4, R7-C5/C6/C8.
