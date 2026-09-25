# postexportKinetics

Kinetic model comparison for post-export RNA conversion.

> **Development status.** This package is under active development
> (version `0.0.0.9000`). It is not yet a Bioconductor release, and its
> interface may still change.

`postexportKinetics` fits a compartment-resolved four-state kinetic model to
time courses of nuclear and cytoplasmic, unprocessed and processed RNA. It
tests whether an additional post-export conversion component improves the
fit beyond a model without it.

The numerical core is ported verbatim from the frozen implementation of the
accompanying manuscript and is regression-tested against it (see
[Scientific reference](#scientific-reference)).

## Model

| State | Compartment | Processing |
|---|---|---|
| `N`   | nuclear     | unprocessed |
| `N_s` | nuclear     | processed   |
| `C`   | cytoplasmic | unprocessed |
| `C_s` | cytoplasmic | processed   |

```
dN/dt   = R(t) - (sigma_n + tau) N
dN_s/dt = sigma_n N - tau_s N_s
dC/dt   = tau N - (sigma_c + alpha) C
dC_s/dt = tau_s N_s + sigma_c C - alpha_s C_s
```

Two nested models are compared:

- the **null model**, with `sigma_c = 0`;
- the **full model**, with `sigma_c >= 0`.

The estimation uses:

- trapezoidal interval balances;
- propagated and regularised measurement covariance;
- whitened non-negative least squares.

The statistic is `T = max(0, RSS0 - RSS1)`. It is calibrated by a
replicate-level generative bootstrap under the fitted null model, with an
add-one p-value and an explicit boundary rule. It is not a likelihood-ratio
test.

**Interpretation of `sigma_c`.** `sigma_c` is a *phenomenological*
post-export conversion rate from `C` to `C_s`. Statistical support for
`sigma_c > 0` indicates kinetic patterns consistent with an additional
post-export conversion component within the model. It does not identify a
unique molecular mechanism, and it is not by itself evidence of cytoplasmic
splicing.

## Installation

Development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("bioinformatics-sannio/postexportKinetics")
```

To also build the vignette:

```r
remotes::install_github("bioinformatics-sannio/postexportKinetics",
                        build_vignettes = TRUE)
```

- **R version:** R >= 4.1.0. The package is currently tested with the
  current R release on macOS and Linux.
- **Runtime dependencies:** `deSolve`, `ggplot2`, `MASS`, `nnls`, `stats`,
  `utils`.
- **Suggested:** `knitr` and `rmarkdown` for the vignette; `testthat` and
  `expm` for tests.

## Quick start

The package includes a small **synthetic** dataset, `postexport_example`. It
has eight simulated events, complete shutoff at `t_star = 332` min, 5 time
points and 5 replicates.

```r
library(postexportKinetics)
data(postexport_example)

x <- postexport_data(postexport_example, time_unit = "min")

# One event: full and null fits, then the bootstrap test.
sel <- postexport_example$event == "alt_3"
one <- postexport_data(postexport_example[sel, ], time_unit = "min")
fit <- fit_postexport_model(one, t_star = 332)
summary(fit)

res1 <- test_postexport_conversion(one, t_star = 332,
                                   control = postexport_control(seed = 1))
res1
```

The default is `B = 1999` bootstrap replicates. The smallest attainable
p-value is `1 / (B + 1)`.

### Batch testing, multiple testing and exploratory ranking

```r
events <- unique(x$event)
res <- test_postexport_conversion(
    x, t_star = 332,
    control = postexport_control(B = 499,
                                 seed = setNames(seq_along(events), events)))

adj <- adjust_postexport_pvalues(res)   # Benjamini-Hochberg over valid tests
as.data.frame(adj)                      # tidy table, one row per event

rank_postexport_candidates(adj)         # exploratory prioritisation only
```

- **Batch runs.** Events are processed sequentially, and each event needs
  its own seed. An unexpected error in one event is recorded as status
  `"event_error"`, and the remaining events continue.
- **Adjustment** is always an explicit step. Families can be defined with
  `groups`, for example one per dataset, as in the manuscript.
- **Ranking.** The score, `sigma_c * IR * min(-log10(max(q, 1e-10)), 6)`,
  is the manuscript's exploratory composite. It is not an inferential
  quantity.

### Plots

```r
plot(res$results$alt_3)                      # observations, full/null fit
plot(res$results$alt_3, type = "bootstrap")  # bootstrap distribution of T
plot(adj, type = "sigma_q")                  # descriptive set plot
```

The fitted curves are display reconstructions. Inference uses the
interval-balance machinery.

### Simulation

```r
p <- c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,
       alpha = 0.2, alpha_s = 0.08)
sim <- simulate_postexport_kinetics(
    p, times = c(90, 100, 110, 120, 130), onset_time = 0, t_star = 100,
    regime = "SHUTOFF", time_unit = "min", n_replicates = 3,
    param_cv = 0.05, noise = list(platform = "rnaseq", level = "low"),
    seed = 1)
plot(sim)
```

### Operational-domain diagnostics

```r
check_operational_domain(x, regime = "SHUTOFF", t_star = 332,
                         platform = "rnaseq", noise_level = "very_low")
```

This reports the empirical Type-I error and power of the matching or
nearest designs in the manuscript's simulation benchmark. It is diagnostic
only: similarity to a benchmark design is not a calibration guarantee for a
real dataset.

In the benchmark, calibration depended strongly on the design, and
continuous transcription (no intervention) was anti-conservative.

## Documentation

- Vignette: `vignette("postexportKinetics")`.
- Help pages: `?fit_postexport_model`, `?test_postexport_conversion`,
  `?simulate_postexport_kinetics`, `?check_operational_domain`.

## Scientific reference

The package reproduces the frozen manuscript implementation:

- repository <https://github.com/bioinformatics-sannio/postexport-kinetics>;
- tag `manuscript-revision-v1.0`, commit
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`;
- archived at [doi:10.5281/zenodo.22944109](https://doi.org/10.5281/zenodo.22944109).

The associated manuscript:

> Faretra L., Napolitano F., Pancione M., Cerulo L. (2026). *Kinetic model
> comparison identifies RNA trajectories consistent with post-export
> processing.* Revised manuscript submitted to *Bioinformatics*.

Maintainers can run the manuscript validation with
`tools/validate_against_manuscript.R` (see `tools/frozen/README.md`).

**Reproducibility.** Results are bitwise reproducible only within a matched
numerical environment. Bootstrap draws depend on the LAPACK/BLAS build
through `MASS::mvrnorm()`. Across platforms, bootstrap p-values are
Monte-Carlo realisations of the same bootstrap distribution.

## Citation

`citation("postexportKinetics")`; see also `CITATION.cff`.

## License

MIT © 2026 Luca Faretra, Francesco Napolitano, Massimo Pancione, Luigi
Cerulo.
