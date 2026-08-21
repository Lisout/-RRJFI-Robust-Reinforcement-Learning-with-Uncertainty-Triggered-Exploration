# Theory and Response Consistency Audit

## Result

All 38 point-by-point responses refer to one reconstructed manuscript. Repeated concerns from different reviewers are answered with the same definitions, assumptions, certificate scope, experiment identifiers, and numerical results. No competing revision branch remains in the consolidated documents.

## Unified logical chain

1. DC-IDO propagates one branch for every admissible actuator-delay value, intersects each branch with the bounded-measurement preimage, rejects only inconsistent branches, and takes the smallest axis-aligned hull of the retained union.
2. The physical state/delay uncertainty is deterministic and set-valued. Bayesian variance is epistemic uncertainty of the frozen-feature Critic head. The manuscript never substitutes one for the other.
3. The interval observer supplies robust one-step reward bounds. Paired lower/upper Critics approximate the induced Bellman targets; they are not presented as exact certified endpoints.
4. The shared decentralized Actor proposes a residual command. The same frozen Actor is used in evaluation and in the post-training certificate; no ideal or hidden comparison controller is introduced.
5. Spectral projection bounds Actor sensitivity and improves conditioning. It is not treated as a stability proof.
6. IE-BPU triggers only additional bounded exploration. Observer, controller, and communication updates remain periodic. The digital grid excludes classical Zeno accumulation, while hysteresis and the eight-sample refractory interval control rapid switching.
7. Certified recovery interpolates toward a declared nominal backup until the one-step interval successor is admissible. Its guarantee holds only on the declared inclusion-valid compact domain; otherwise the certificate is withdrawn and fallback is entered.
8. The final delayed closed loop is represented in an augmented state containing the full delay history. The actual frozen Actor is audited with one common positive-definite matrix over all enumerated parameter endpoints and asynchronous delay modes. Bounded nonlinear remainder and implementation mismatch enter the UUB residual radius.

## Scope corrections made during audit

- Removed any implication that reward maximization, robust reward shaping, or spectral normalization proves stability.
- Removed any global safety claim outside the certified model domain.
- Separated the exact PE eigenvalue used for the implemented dimension from the Gershgorin lower bound used only as a conservative diagnostic.
- Replaced broad scalability language by measured finite-range timing/memory results and explicitly retained the exponential cost of exhaustive certification.
- Reported the tuned PID advantage in stabilization and settling time rather than claiming universal controller dominance.
- Restricted the resource-saving claim to avoided exploratory excitation and its computation, not communication packets.
- Removed proposition/propsition constructs and converted their content to direct statements.
- Kept every display equation free of terminal punctuation.

## Cross-review consistency

- R1 and R7 delay-stability concerns use the same augmented-state common-$P$ certificate and UUB residual bound.
- R1, R5, R7, and R9 safety concerns use the same recovery layer, inclusion-valid domain, and withdrawal semantics.
- R2 and R4 implementation concerns use the same finite delay enumeration, inclusion-based state/parameter extrema, paired Critics, initialization rules, and baseline protocol.
- R4, R7, and R9 trigger/PE concerns use the same uncertainty-plus-PE gate, exact PE statistic, hysteresis, refractory interval, and inversion-free full-covariance RLS update.
- R4, R5, and R9 reproducibility concerns use the same training seeds, held-out selection seeds, common evaluation seeds, baseline tuning seeds, and platform disclosure.
- R7 and R9 complexity concerns use the same E5 representation ablation, E6 network scaling study, and explicit separation between online scaling and offline certificate enumeration.

## Remaining limitations stated in the manuscript

The evidence is simulation-only; hardware timing, packet loss, quantization, and communication-delay time stamping remain future validation items. The common-$P$ result certifies the declared three-agent benchmark family and is not a global theorem for arbitrary network size. These limitations are stated in the conclusion and are not contradicted by any response.
