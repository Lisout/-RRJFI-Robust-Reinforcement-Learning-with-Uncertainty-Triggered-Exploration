# -RRJFI-Robust-Reinforcement-Learning-with-Uncertainty-Triggered-Exploration
This paper studies distributed cooperative control of nonlinear multi-agent systems subject to bounded parametric uncertainty, bounded process and measurement disturbances, and unknown asynchronous input delays.
This directory is a public-facing package for the revised numerical study. It contains the MATLAB source code, experiment drivers, tests, archived numerical results, figure assets, and the script that redraws the figures from the archived results. Manuscript files are intentionally not included.

All files copied into this package are retained verbatim. The original files remain in the parent `RRJFI` directory.

## Requirements

- MATLAB R2023b or a later compatible release
- No Simulink model is required for the archived numerical experiments
- MATLAB Statistics and Machine Learning Toolbox is recommended for the paired statistical tests in E2

## Directory map

| Directory                    | Contents                                                     |
| ---------------------------- | ------------------------------------------------------------ |
| `00_project_control`         | Experiment map, validation reports, and consistency-audit scripts |
| `01_core/+rrjfi`             | Interval arithmetic, plant/scenario generation, DC-IDO, controller, IE-BPU, recovery, and metric functions |
| `02_training/+rrjfiTraining` | Actor--Critic training, replay, spectral projection, Bayesian-head preparation, and RLS updates |
| `03_experiments`             | Training, baseline tuning, and E1--E7 experiment drivers     |
| `04_tests`                   | MATLAB unit and integration tests for arithmetic, gradients, containment, triggering, and artifacts |
| `05_results`                 | Archived MAT/CSV results, seed-level metrics, trained checkpoints, and certificate data |
| `06_figures`                 | Existing FIG/PDF/PNG/EPS figure assets, including the redrawn-from-archive figures |

The MATLAB preference folders, review/manuscript extracts, and other private editor artifacts in the working directory are not part of this public package.

## Recommended execution order

Set MATLAB's current folder to this package root, then add the source folders:

```matlab
addpath(fullfile(pwd, "01_core"));
addpath(fullfile(pwd, "02_training"));
addpath(fullfile(pwd, "03_experiments"));
addpath(fullfile(pwd, "04_tests"));
```

For a complete regeneration from source, use the existing drivers in this order:

1. `03_experiments/runTraining.m`
2. `03_experiments/runBaselineTuning.m`
3. `03_experiments/runExperiment01Observer.m` through `runExperiment07Certificate.m`
4. `04_tests/runAllTests.m`

The archived files in `05_results` are sufficient for inspection and figure regeneration; rerunning the experiments is not necessary merely to redraw the published plots.

## Figure regeneration manual

`redrawFiguresFromExistingData.m` reads the archived MAT files in `05_results` and creates the E1--E7 figure windows without rerunning training or simulations. It does not modify, save, or close figure windows.

Run it from the package root with:

```matlab
redrawFiguresFromExistingData(ManualZoom=false);
```

This mode is non-interactive and works entirely from the packaged results. The script creates independent normal figure windows and leaves them open for inspection. The current E1/E2 layout uses publication-sized windows and keeps the y-axis labels outside neighboring panels.

For the optional interactive BaseZoom workflow, call the function with `ManualZoom=true` and provide a local folder containing `BaseZoom.m` and its associated `parameters.json`:

```matlab
redrawFiguresFromExistingData(ManualZoom=true, ...
    BaseZoomFolder="D:/path/to/BaseZoom/folder");
```

E1(a) and E2(a) are the axes connected to BaseZoom. Follow the prompts to place the inset and select the zoomed data region. The BaseZoom utility is deliberately not copied into this package because it is an external local helper rather than part of the archived experiment code.

## Experiment index

| ID   | Driver                            | Main output in `05_results`                                  |
| ---- | --------------------------------- | ------------------------------------------------------------ |
| E1   | `runExperiment01Observer.m`       | DC-IDO containment, delay retention, hull excess, and reward-width refinement |
| E2   | `runExperiment02Control.m`        | Common-seed controller tracking, control, and paired metrics |
| E3   | `runExperiment03IEBPU.m`          | Uncertainty, PE, hysteresis, and trigger ablations           |
| E4   | `runExperiment04Recovery.m`       | Recovery projection, safety outcomes, and certificate withdrawal |
| E5   | `runExperiment05Representation.m` | Bayesian-head dimension, accuracy, runtime, memory, and PE trade-offs |
| E6   | `runExperiment06Scalability.m`    | Agent-count runtime, memory, containment, and delay retention |
| E7   | `runExperiment07Certificate.m`    | Frozen-Actor common-$P$ certificate audit                    |

## Testing

Run the existing test entry point after adding the source folders:

```matlab
results = runAllTests;
disp(results);
```

The tests operate on the source code and archived artifacts; they do not alter the packaged files.

## Provenance and publication use

The `06_figures` directory contains both the previously generated figure assets and the `redrawn_from_existing_data` assets. The latter are produced from the MAT archives by `redrawFiguresFromExistingData.m`. CSV files provide directly inspectable tabular summaries, while MAT files retain the complete archived structures used by the plotting script.

This package is suitable for supplementary-material submission and for publication in a GitHub repository. Before public release, review the repository's license and any journal-specific data-sharing requirements.
