# postexportKinetics 0.0.0.9000 (development)

Initial development version. It is not yet a Bioconductor release, and the
interface may still change.

## Scientific reference

* The numerical core is ported verbatim from the frozen manuscript
  implementation.
  * Repository: `bioinformatics-sannio/postexport-kinetics`.
  * Tag `manuscript-revision-v1.0`, commit
    `65c3b7368fb7686bfde3dab857f98c393bb534c5`.
  * Archive: doi:10.5281/zenodo.22944109.
* Ported components:
  * four-state ODE model and transcription schedules;
  * trapezoidal interval balances;
  * covariance estimation, shrinkage, eigenvalue floor and propagation;
  * whitened NNLS fits of the full model (`sigma_c >= 0`) and the null model
    (`sigma_c = 0`);
  * the statistic `T = max(0, RSS0 - RSS1)` and the boundary rule;
  * Crank-Nicolson null trajectories;
  * the replicate-level generative bootstrap and the add-one p-value.
* Regression tests compare the package with fixtures generated from the
  frozen tag, on macOS and on Linux CI.

## Inference

* `postexport_data()` and `validate_postexport_data()`: validated wide or
  long input. Missing states are errors, never zero-filled.
* `postexport_control()`: numerical and inferential settings with the frozen
  defaults (`B = 1999`).
* `fit_postexport_model()`: full and null fits with diagnostics.
* `test_postexport_conversion()`: bootstrap test of `sigma_c = 0` against
  `sigma_c > 0`, with boundary information and RNG metadata.
* `print()` and `summary()` methods for all result classes.

## Simulation and design diagnostics

* `simulate_postexport_kinetics()`: the manuscript simulator, with:
  * transcriptional onset and a common intervention time;
  * the NONE, SHUTOFF and PSEUDO_SHUTOFF regimes;
  * replicate variability and the benchmark assay-noise presets.
* `check_operational_domain()`: diagnostic comparison of a design with the
  manuscript's corrected factorial benchmark. It is not a calibration
  guarantee.

## Batch analysis, multiple testing, ranking and plots

* Multi-event calls run sequentially with per-event seeds. An unexpected
  error in one event is recorded as status `"event_error"`.
* `adjust_postexport_pvalues()`: explicit multiple-testing adjustment
  (Benjamini-Hochberg by default) over valid tests, with user-defined
  families. A single test is a family of size one.
* `rank_postexport_candidates()`: exploratory prioritisation with the
  manuscript's composite score. It is not inferential.
* `as.data.frame()` methods give tidy result tables with documented column
  roles.
* `plot()` methods (ggplot2) for fits, tests, result sets, simulations and
  operational-domain checks.

## Documentation and data

* Vignette `vignette("postexportKinetics")`.
* Synthetic example data `postexport_example` and `postexport_example_truth`,
  with a long-format copy in `inst/extdata`.

## Not yet available

* Parallel execution.
* rMATS input conversion.
* Comparator methods.
* SummarizedExperiment input.
