# Frozen-reference regression infrastructure

The package's numerical core is validated against the frozen manuscript
implementation: tag `manuscript-revision-v1.0` of `postexport-kinetics`,
commit `65c3b7368fb7686bfde3dab857f98c393bb534c5`. The frozen repository is
only read. It is never modified.

## Files

| File | Purpose |
|---|---|
| `export_frozen.sh` | Verifies the tag commit and exports it with `git archive` into a scratch directory (writes `.frozen_commit`). Does not touch the frozen repository's working tree, index, refs or HEAD. |
| `make_fixtures.R` | Generates the committed fixtures `tests/testthat/fixtures/*.rds` on the fixture platform. It sources only frozen function definitions and records inputs, frozen outputs and provenance. Synthetic example inputs are simulated here, once, with the frozen ODE simulator. |
| `recompute_fixtures.R` | Recomputes the frozen outputs on the **current** platform from the **committed inputs** and writes them to a separate directory. It never regenerates inputs (no `deSolve`) and never overwrites the committed fixtures. |
| `compare_fixtures.R` | Compares committed fixtures with fixtures recomputed on another platform, using the cross-platform policy below. Exits 1 on a blocking failure. |
| `compare_report.R` | Reports bitwise identity and maximum differences, installed package vs fixtures. |
| `../ci/run_tests_ci.R` | Runs the test suite in CI; publishes failures, skips and reported differences as annotations. |
| `../ci/diagnose_platform_diffs.R` | Diagnostic only: per-leaf elementwise and normwise differences between two fixture sets. |
| `../validate_against_manuscript.R` | End-to-end maintainer validation (below). |
| `normalise_fixture_provenance.R` | One-off, approved normalisation of `names(provenance$frozen_md5)` from absolute to export-relative paths. It verifies the MD5s against a fresh export and proves that nothing else changes. It writes nothing unless every fixture passes. |

## End-to-end manuscript validation

`tools/validate_against_manuscript.R` is the single maintainer entry point.
Run it from the package root:

```sh
Rscript tools/validate_against_manuscript.R                  # full (about 1.5 min)
Rscript tools/validate_against_manuscript.R --quick          # skip same-platform recomputation
Rscript tools/validate_against_manuscript.R --frozen-repo /path/to/postexport-kinetics
```

It needs a local clone of `postexport-kinetics` that contains the tag (by
default `$HOME/postexport-kinetics`) and no network access. It works through
these steps:

1. Verifies the tag commit.
2. Exports the tag read-only and installs the package source into a
   temporary library, so the validated code is the current working tree.
3. Checks the MD5 provenance of the packaged benchmark table.
4. Reproduces, through the public API, the deposited `sigma_c` and IR of
   Ppp1r36dn and Nsd1 and of all 28 mESC events with FDR < 0.10 (1e-8
   relative).
5. Runs the regression suite against the committed fixtures.
6. Unless `--quick`, recomputes the frozen outputs on the current platform
   and runs the strict same-platform (level A) and cross-platform
   (levels B/C) comparisons.
7. Verifies that the frozen repository's HEAD, status and refs are
   unchanged.

It prints PASS/FAIL per step and an overall equivalence status. It exits
with status 1 on any failure. It does not rerun the 1,152-configuration
benchmark. Linux CI runs it with `--quick`, since the frozen-reference job
already performs step 6.

## Three kinds of reproducibility

- **Scientific equivalence.** The package implements the same algorithm as
  the frozen code: the same model, interval balances, covariance
  propagation and regularisation, NNLS fits, statistic, boundary rule,
  generative bootstrap and add-one p-value. It produces the same scientific
  outputs up to floating-point rounding.
- **Numerical bitwise reproducibility.** Results are bitwise identical only
  within a matched numerical environment: same OS and architecture,
  LAPACK/BLAS build, `MASS`, `nnls` and `RNGkind()`. On the fixture platform
  the package is currently bitwise identical to the frozen code. Different
  LAPACK/BLAS builds, including CPU-specific OpenBLAS kernels, change results
  at rounding level.
- **Monte-Carlo reproducibility.** A fixed seed reproduces the bootstrap
  draws exactly within a matched numerical environment. Across environments
  it does not guarantee identical draws. The frozen bootstrap uses
  `MASS::mvrnorm()`, which is based on an eigendecomposition whose
  eigenvectors can differ between LAPACK/BLAS builds even under the same R
  seed. `T*`, bootstrap diagnostics and small-B p-values therefore differ
  across platforms. For the same data they are different Monte-Carlo
  realisations of the same bootstrap distribution.

The package preserves the frozen algorithm, including `MASS::mvrnorm()`. It
does not try to make draws identical across platforms, because doing so would
change frozen scientific behaviour. None of this changes the manuscript's
conclusions. The deterministic observed-fit quantities (`sigma_c`, IR,
coefficients, RSS, boundary status) agree across platforms within the
tolerances below.

## Regression levels

### A. Same-platform package vs frozen: blocking, strict

Used when the fixture provenance matches the current platform exactly. On the
fixture platform this means the committed fixtures. In CI it means fixtures
recomputed on the same Linux machine by `recompute_fixtures.R`.

Comparisons are elementwise, `|a − e| ≤ abs + rel·|e|`. Structure (names,
dims, classes, NA pattern, attributes) is compared exactly, and error
messages must be identical.

| Tier | Tolerance | Used for |
|---|---|---|
| T0 | exact | constants, integer diagnostics, p-values, error messages |
| T1 | 1e-12 relative | Crank–Nicolson propagation (small linear solves) |
| T2 | 1e-10 relative | eigen/SVD/NNLS-dependent quantities, bootstrap draws and `T*` |
| — | 1e-8 relative | package vs deposited audit TSV (15 significant digits; platform independent) |

Bootstrap draws, `T*`, add-one p-values and `atom.zero` are blocking at this
level.

### B. Cross-platform scientific regression: blocking, scale-aware

Used when the fixture provenance differs from the current platform, e.g. the
committed macOS fixtures checked on Linux (package tests and `R CMD check`),
and in `compare_fixtures.R`. Implemented in `assess_cross()` /
`compare_cross()` in `tests/testthat/helper-compare.R`.

- Matrices, vectors and scalars (normwise):
  `max|a − e| ≤ 1e-10 · max(1, max|e|)`.
- `T`, `T.obs`, `RSS0`, `RSS1` and `boundary.tolerance`, in an object that
  carries `RSS0` and `RSS1`: absolute scale `1e-10 · max(1, |RSS0|, |RSS1|)`.
- `IR`: the same bound propagated through `IR = (RSS0 − RSS1)/RSS0`, i.e.
  `1e-10 · max(1, |RSS0|, |RSS1|) / |RSS0|`.
- Integer leaves (ranks, replicate counts): exact.
- Structure and NA/NaN/Inf pattern: exact.
- **Boundary classification**: the frozen rule
  `T ≤ 1e-10 · max(1, |RSS0|, |RSS1|)` must give the identical decision.

Blocking scientific outputs: full and null coefficients, `sigma_c`, RSS0,
RSS1, IR, T (modulo the boundary-scale rule), ranks, boundary classification,
the real mESC regression targets, and the published Ppp1r36dn and Nsd1
values.

For leaves whose magnitude is below 1, the normwise rule is an absolute bound
of 1e-10. Level A remains the primary check for such small-scale quantities.

### C. Platform-sensitive diagnostic fixtures: reported, not blocking

- **Deliberately extreme-conditioning fixtures**: `lambda = none`,
  `indefinite_Sigma`, `rank1`, `zero_diag`. These remain in the suite as
  numerical stress tests. Across platforms, differences are reported but do
  not block, provided that:
  - level A passes on that platform;
  - the boundary classification is identical (still blocking);
  - the difference is consistent with conditioning: the largest scaled
    difference is at most `100 · κ · ε`, where κ is the condition number of
    the covariance involved after the frozen eigenvalue floor (otherwise
    blocking).
- **Bootstrap draws and draw-dependent fields**: `T.boot`,
  `bootstrap.condition`, `bootstrap.rank`, `atom.zero`, bootstrap condition
  summaries, and small-B p-values. These are reported and never compared
  across platforms; the corresponding tests skip, stating the measured
  difference.

The deterministic observed fit, the boundary rule, the add-one p-value
implementation (checked on each fixture's own `T*`) and the bootstrap
algorithm (same-platform composition test) remain regression tested.

## Regenerating and recomputing fixtures

```sh
# Committed fixtures (fixture platform only; never edited by hand):
FROZEN=$(tools/frozen/export_frozen.sh "$HOME/postexport-kinetics")
Rscript tools/frozen/make_fixtures.R "$FROZEN"

# Same-platform validation on another platform, from the committed inputs:
Rscript tools/frozen/recompute_fixtures.R "$FROZEN" tests/testthat/fixtures /tmp/fixtures-here
POSTEXPORT_FIXTURE_DIR=/tmp/fixtures-here Rscript tools/ci/run_tests_ci.R
Rscript tools/frozen/compare_fixtures.R tests/testthat/fixtures /tmp/fixtures-here
```

`POSTEXPORT_FORCE_CROSS_PLATFORM=true` forces levels B/C even on a matching
platform, so that the cross-platform policy can be exercised locally. It is
never set in CI.

A regeneration of the committed fixtures that changes any stored value must
be reported and reviewed before it is committed.

The fixtures are shipped in the package tarball (`tests/testthat/fixtures/`,
documented in its `README.md`), so that `R CMD check` runs the regression
suite. MD5s of frozen files are named by their path relative to the frozen
export, never by a machine-specific absolute path. The generators and
`recompute_fixtures.R` do this directly, and the committed fixtures were
normalised once with `normalise_fixture_provenance.R`.

## Validation notes (provenance of the frozen tag)

- **Real-data bootstrap size.** The deposited Kc167/K562/NIH-3T3 results
  correspond to a B = 4999 run, although `run_real_datasets_revision.R`
  declares `N_BOOT <- 1999`. The final mESC analysis used B = 19999
  (`STOP_CONDITION_REPORT.md` §1). The fixtures use only deterministic
  real-data quantities (`sigma_c`, IR, coefficients), which do not depend on B.
- **Generator RNG.** Fixtures that involve the corrected-onset generator
  (later phases) reproduce its actual RNG behaviour, including the
  ineffective function-local `.Random.seed` restore
  (`STOP_CONDITION_REPORT.md` §4).
- **Superseded sources.** `run_benchmark_pseudoshutoff_revision.R` and the
  historical `commons/nested_test.r` are not regression sources.
