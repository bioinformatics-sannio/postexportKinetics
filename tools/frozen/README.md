# Frozen-reference regression infrastructure

The package's numerical core is validated against the frozen manuscript
implementation: tag `manuscript-revision-v1.0` of `postexport-kinetics`,
commit `65c3b7368fb7686bfde3dab857f98c393bb534c5`. The frozen repository is
only read; it is never modified.

## Files

| File | Purpose |
|---|---|
| `export_frozen.sh` | Verifies the tag commit and exports it with `git archive` into a scratch directory (writes `.frozen_commit`). Does not touch the frozen repository's working tree, index, refs or HEAD. |
| `make_fixtures.R` | Sources only function definitions from the export (`commons/nested_test2.r`; `ode_model/ode.r` and `commons/platforms.r` only to simulate example data) and writes `tests/testthat/fixtures/*.rds` with inputs, frozen outputs and provenance. |
| `compare_report.R` | Runs the installed package on every fixture case and reports bitwise identity and maximum differences. |

## Regenerating fixtures

```sh
FROZEN=$(tools/frozen/export_frozen.sh "$HOME/postexport-kinetics")
Rscript tools/frozen/make_fixtures.R "$FROZEN"
```

Fixtures are never edited by hand. A regeneration that changes any stored
value must be reported and reviewed before it is committed.

## Tolerance tiers

See `PACKAGE_PLAN.md` §9.2 and `tests/testthat/helper-compare.R`.
Comparisons are elementwise (`|a - e| <= abs + rel * |e|`), with structure
(names, dims, classes, NA pattern, attributes) compared exactly.

| Tier | Tolerance | Used for |
|---|---|---|
| T0 | exact | constants, integer diagnostics, p-values, error messages |
| T1 | 1e-12 relative | Crank-Nicolson propagation (small linear solves) |
| T2 | 1e-10 relative | eigen/SVD/NNLS-dependent quantities |
| — | 1e-8 relative | package vs deposited audit TSV (15 significant digits) |

Bootstrap draws (`MASS::mvrnorm`, eigen-based) are compared only when the
current LAPACK/BLAS/OS/`MASS`/`nnls`/`RNGkind()` matches the fixture
provenance; otherwise those tests are skipped with an explanation.

## Validation notes (provenance of the frozen tag)

- **Real-data bootstrap size.** The deposited Kc167/K562/NIH-3T3 results
  correspond to a B = 4999 run although `run_real_datasets_revision.R`
  declares `N_BOOT <- 1999`; the final mESC analysis used B = 19999
  (`STOP_CONDITION_REPORT.md` §1). Phase 1 fixtures use only deterministic
  real-data quantities (`sigma_c`, IR, coefficients), which do not depend on B.
- **Generator RNG.** Fixtures that involve the corrected-onset generator
  (later phases) reproduce its actual RNG behaviour, including the ineffective
  function-local `.Random.seed` restore (`STOP_CONDITION_REPORT.md` §4).
- **Superseded sources.** `run_benchmark_pseudoshutoff_revision.R` and the
  historical `commons/nested_test.r` are not regression sources.
