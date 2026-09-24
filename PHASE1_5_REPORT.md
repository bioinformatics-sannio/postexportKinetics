# Phase 1.5 Report: commits, Linux CI, cross-platform validation

Status: **Cross-platform diagnosis accepted; approved regression policy
implemented (§9). Final CI status in §10. Phase 2 is not started.**

The first sections (§1–§8) record the investigation as it was reviewed. The
decision in §6 was taken; the approved policy and its implementation are in
§9.

The Linux CI shows differences outside the documented *elementwise* tolerance
tiers of `PACKAGE_PLAN.md` §9.2. These differences are in the **frozen
implementation run on Linux vs the same frozen implementation run on
macOS**. The package matches the frozen code on each platform. No tolerance,
fixture or package code has been changed to make CI pass. Your decision is
needed (§6).

---

## 1. Commits and git log

The five requested commits were made on branch `phase1-core`, not squashed.
The branch was used instead of `main` because of the repository's rule to
branch before committing on the default branch. Three CI commits follow.

| # | Hash | Message |
|---|---|---|
| 1 | `e42cf83` | Add package skeleton (DESCRIPTION, MIT license, package docs) |
| 2 | `7febe90` | Add frozen-reference fixture infrastructure and fixtures |
| 3 | `2d97568` | Port internal numerical core verbatim from manuscript-revision-v1.0 |
| 4 | `fc44763` | Add regression tests for the ported core |
| 5 | `2dbb239` | Add planning, stop-condition, release-checklist and Phase 1 reports |
| CI | `0c9c3ec` | Add Linux CI for deterministic regression and frozen-reference checks |
| CI | `41cadf8` | CI: report test and fixture-comparison failures as annotations |
| CI | `4596ec1` | CI: characterise cross-platform frozen differences; classify boot fields |

```
4596ec1 CI: characterise cross-platform frozen differences; classify boot fields
41cadf8 CI: report test and fixture-comparison failures as annotations
0c9c3ec Add Linux CI for deterministic regression and frozen-reference checks
2dbb239 Add planning, stop-condition, release-checklist and Phase 1 reports
fc44763 Add regression tests for the ported core
2d97568 Port internal numerical core verbatim from manuscript-revision-v1.0
7febe90 Add frozen-reference fixture infrastructure and fixtures
e42cf83 Add package skeleton (DESCRIPTION, MIT license, package docs)
15743c8 Define package engineering and scientific invariance rules
0aad829 Initial commit
```

With your approval, `phase1-core` was pushed to
`origin` (`git@github.com:bioinformatics-sannio/postexportKinetics.git`).
`main` was not pushed or changed. The push also published `15743c8` (the
CLAUDE.md commit), which was on local `main` only.

The two follow-up CI commits (`41cadf8`, `4596ec1`) were needed because raw
GitHub Actions job logs require repository admin rights. The CI now reports
failure details as public annotations. These commits changed only CI and
diagnostic tooling:

- no package code changed;
- no fixture changed;
- no tolerance changed.

`4596ec1` also fixes a classification bug in my own comparison script:
`bootstrap.condition` and `bootstrap.rank` depend on the bootstrap draws and
are now treated as platform-dependent, like `T.boot`.

---

## 2. CI workflow added

`.github/workflows/linux-regression.yml` (`ubuntu-latest`, R release; runs on
push, pull request and manual dispatch).

| Job | Steps |
|---|---|
| `package` | pandoc, R and dependencies; print session and LAPACK/BLAS provenance; install the package; run the regression tests against the **committed (macOS) fixtures** via `tools/ci/run_tests_ci.R`; run `R CMD check --as-cran --no-manual` (fails on WARNING). |
| `frozen-reference` | clone `bioinformatics-sannio/postexport-kinetics` and verify the tag resolves to `65c3b73`; record HEAD, status and refs; export the tag (`git archive`) and **regenerate all fixtures on Linux from the frozen code**; compare them with the committed fixtures (`tools/frozen/compare_fixtures.R`); report per-leaf differences (`tools/ci/diagnose_platform_diffs.R`, diagnostic only); install the package; run the package tests **against the Linux fixtures** (`POSTEXPORT_FIXTURE_DIR`), which also runs the bootstrap-draw tests because the provenance matches; verify the frozen clone is unmodified (HEAD, `status --porcelain --ignored` and `show-ref` all unchanged); fail the job if the fixture comparison failed. |

Supporting files:

- `tools/ci/run_tests_ci.R`
- `tools/ci/diagnose_platform_diffs.R`
- `tools/frozen/compare_fixtures.R`

The test helper gained the optional `POSTEXPORT_FIXTURE_DIR` override; the
default behaviour is unchanged.

The provenance guard is kept. Bootstrap-draw tests against the macOS
fixtures **skip on Linux with an explicit reason**. No attempt was made to
force them to match.

---

## 3. Linux results

Runs (public: `https://github.com/bioinformatics-sannio/postexportKinetics/actions`):

| Run | Commit | `package` | `frozen-reference` |
|---|---|---|---|
| 36051690460 | `0c9c3ec` | failure (tests vs committed fixtures) | failure (fixture comparison; later steps did not run) |
| 36052165875 | `41cadf8` | failure (tests; R CMD check) | failure (comparison only) |
| 36052656730 | `4596ec1` | failure (tests; R CMD check) | failure (comparison only) |

### 3.1 What passes on Linux

- Package installation.
- **Package vs frozen, both on Linux: PASS.** This is the step "Package vs
  frozen on Linux (including bootstrap draws)" in runs 2 and 3. The whole test
  suite, including bootstrap draws, the composed bootstrap, add-one p-values
  and the verbatim-port checks, passes against fixtures regenerated from the
  frozen tag on the same Linux machine. On Linux, as on macOS, the port
  reproduces the frozen implementation within the tiers.
- **Frozen repository not modified: PASS.** HEAD, working-tree/ignored status
  and refs are unchanged after export and fixture regeneration.
- Frozen tag verified on the clone: `65c3b7368fb7686bfde3dab857f98c393bb534c5`.

### 3.2 What fails on Linux

1. `package`: the tests against the committed **macOS** fixtures (run 3).

   | Test file | Failures |
   |---|---:|
   | `test-fit.R` | 29 |
   | `test-interval-balance.R` | 28 |
   | `test-real-mesc.R` | 15 |
   | `test-matrix-utils.R` | 2 |

   In run 2 the counts were 42, 14, 14 and 2 (see §4.4). All other test files
   pass: verbatim port, covariance, Crank–Nicolson, bootstrap (whose draw
   comparisons skip) and the TSV/published-value tests.
2. `package`: `R CMD check` reports "found ERRORs". The test step fails with
   the failures above, and check runs the same tests, so the most likely cause
   is those failures. This cannot be confirmed without the raw log.
3. `frozen-reference`: frozen-on-Linux vs frozen-on-macOS fixtures exceed the
   elementwise tiers. Details in §4.

---

## 4. Platform differences (frozen Linux vs frozen macOS)

Source: the `diagnose_platform_diffs.R` annotation of run 3. For each leaf
that exceeds its tier, the table gives the largest absolute difference, the
largest elementwise relative difference, and the normwise relative difference
`max|a − e| / max|e|`.

### 4.1 Deterministic quantities

| Leaf | Cases | Max abs | Max rel (elementwise) | Max normwise rel | Interpretation |
|---|---:|---:|---:|---:|---|
| `fx_interval_balance` `Sigma_b` | 14 | 6.8e-14 | 169 | **2.4e-15** | entries that are ~0 (structural or near-zero covariances) differ at rounding level; normwise agreement is ~10 ε |
| `fx_real_mesc` `built$Sigma_b` | 14 | 2.7e-12 | 335 | **2.1e-15** | same (real mESC events) |
| `fx_fit` `T` | 75 | 1.5e-8 | 6.7e299 | 1.8 | `T = max(0, RSS0 − RSS1)` at the boundary: 0 on one platform, rounding-level on the other (176 of 232 fit cases have `T ≤ 1e-12·RSS0`). **No case changes the frozen boundary decision** `T ≤ 1e-10·max(1,|RSS0|,|RSS1|)` (checked explicitly for all fit, real-data and full-test cases). |
| `fx_fit` RSS0, RSS1, coefficients, condition number, min singular value | 2 | 555 (RSS ≈ 2e10) | 3.5e-8 | 2.8e-8 | the two deliberately extreme fixtures: `basic/t_star=15/lambda=none` (no shrinkage; κ of whitening covariance ≈ 5.7e8) and `malformed/indefinite_Sigma` (indefinite input, eigenvalues floored). The expected size is κ·ε ≈ 1e-7; the difference is conditioning-limited. |
| `fx_matrix` `inverse_sqrt_matrix` | 2 | 7.9e-5 | 4.0e-8 | 2.1e-8 | `rank1` and `zero_diag` matrices: after flooring, κ ≈ 4.6e8; conditioning-limited as above |
| `fx_test_sigma_nested` inputs (`null_none_gauss` `C_s`) | 2 | 3.2e-12 | 1.5e-10 | — | example **input data** simulated with `deSolve::lsoda`, which differs across platforms at 1.5e-10. This is the ODE simulator used to build fixtures, not the ported core. |

**No difference was found in the scientifically reported quantities of
realistic cases:**

- For all 28 real mESC events, `sigma_c`, IR, T, RSS0, RSS1, full and null
  coefficients, condition number and rank agree within T2. Only
  `built$Sigma_b` is listed, at a normwise relative difference of 2e-15.
- `sigma_c` and IR also match the deposited audit TSV on Linux.
- For the simulated full-test examples, T.obs, RSS, coefficients and null
  means agree within T2.

### 4.2 Bootstrap-draw quantities (platform-dependent by design)

| Leaf | Cases | Max normwise rel |
|---|---:|---:|
| `fx_bootstrap` draws (N, N_s, C, C_s) | 16 | 0.40 |
| `T.boot` | 9 | 0.45 |
| `bootstrap.condition*` | 7 | 0.32 |
| `atom.zero` | 5 | 0.20 (max abs 0.105) |
| `p.value` | 1 of 9 | abs 0.05, at B = 19 |

As anticipated in `PACKAGE_PLAN.md` §9.2 (tier T4), `MASS::mvrnorm()` draws
differ between LAPACK/BLAS builds, because eigenvector signs and bases differ.
So the bootstrap statistics differ too. These comparisons are reported and do
not block. Against the macOS fixtures they are guarded and skipped on Linux.

### 4.3 Classification

| Class | Evidence | Scientific impact |
|---|---|---|
| (a) Rounding-level differences in quantities whose exact value is 0 or near 0 (`Sigma_b` near-zero entries, boundary `T`) | normwise ≤ 2.4e-15; boundary decisions identical | none |
| (b) Conditioning-limited differences in deliberately extreme fixtures (κ ≈ 5e8) | relative differences ≈ κ·ε | none; these fixtures exist to exercise floors |
| (c) Simulator (deSolve) differences in example input data | 1.5e-10 relative | none on the core; affects only which inputs the Linux fixtures contain |
| (d) Bootstrap draws | platform-dependent by design (T4) | Monte-Carlo only |

I found no evidence of a porting error or a scientific discrepancy. The
differences exceed the documented tiers because those tiers were specified
**elementwise with a fixed absolute floor of 1e-14**. That rule does not scale
with the magnitude of the object, so it cannot tolerate rounding in entries
that are ~0, and it assumed κ ≲ 1e4 for all fixtures. This is a flaw in my
tolerance specification, confirmed by the data. It is not a reason to
silently relax tolerances.

### 4.4 Additional observation: hardware dependence within Linux

The number of failing cases changed between runs 2 and 3 on the same commit
content (e.g. `test-fit.R` 42 → 29, `test-interval-balance.R` 14 → 28). This
is consistent with OpenBLAS choosing CPU-specific kernels on different runner
machines. Linux results are therefore not bitwise reproducible across runners,
even though package vs frozen on the *same* machine always agreed.

---

## 5. Final DESCRIPTION metadata

```
Package: postexportKinetics
Title: Kinetic Model Comparison for Post-Export RNA Conversion
Version: 0.0.0.9000
Authors@R: c(
    person("Luca", "Faretra", role = "aut"),
    person("Francesco", "Napolitano", role = "aut"),
    person("Massimo", "Pancione", role = "aut"),
    person("Luigi", "Cerulo", email = "lcerulo@unisannio.it",
           role = c("aut", "cre")))
License: MIT + file LICENSE
URL: https://github.com/bioinformatics-sannio/postexportKinetics
BugReports: https://github.com/bioinformatics-sannio/postexportKinetics/issues
Depends: R (>= 4.1.0)
Imports: MASS, nnls, stats
Suggests: expm, testthat (>= 3.0.0)
biocViews: Software, Transcriptomics, RNASeq, AlternativeSplicing,
    TimeCourse, StatisticalMethod
```

- `LICENSE`: `YEAR: 2026`,
  `COPYRIGHT HOLDER: Luca Faretra, Francesco Napolitano, Massimo Pancione, Luigi Cerulo`.
  `LICENSE.md` names the same holders.
- No ORCID identifiers.
- The repository URL exists (the remote was reachable and the push succeeded).

---

## 6. Decision needed before Phase 2 (decided; see §9)

I propose the following. Nothing has been changed pending your decision.

1. **Keep the strict elementwise tiers on the fixture platform.** macOS is
   currently bitwise identical, so a regression is detected at the first bit.
2. **Add a scale-aware cross-platform tier, applied only when the provenance
   differs.**
   - *Matrices and vectors:* compare normwise, `max|a − e| ≤ 1e-10 · max|e|`,
     instead of per-element.
   - *The statistic T and RSS-scaled scalars:* use an absolute tolerance tied
     to the frozen boundary scale, `1e-10 · max(1, |RSS0|, |RSS1|)`, the same
     quantity that defines `tol_zero`. Also require the boundary decision to be
     identical.
3. **Treat the deliberately extreme-conditioning fixtures as
   platform-dependent across platforms.** These are `lambda=none`,
   `indefinite_Sigma`, `rank1` and `zero_diag`: report them, but don't block.
   Alternatively, use a κ-scaled tolerance of `c · κ · ε` with c = 100.
4. **Compare simulator-generated example inputs across platforms at the ODE
   tier (T3), or reuse the committed inputs.** In the second option,
   `make_fixtures.R` would accept the committed inputs, so that Linux frozen
   outputs are computed on identical inputs. I recommend this option, because
   it isolates the core from `deSolve` differences.
5. **Make both CI jobs pass under 1–4**, and keep the CI red until you
   approve. With these rules the observed Linux differences all fall within
   tolerance (normwise ≤ 2.4e-15; boundary decisions identical).

Alternative: keep the tiers unchanged and treat Linux as outside the validated
domain. I do not recommend this, because Bioconductor builds on Linux.

---

## 7. Remaining BiocCheck findings (local, BiocCheck 1.48.1, final DESCRIPTION)

**3 ERRORs, 2 WARNINGs, 9 NOTEs.** The `URL`/`BugReports` NOTE is gone.

| Finding | Type | Status |
|---|---|---|
| version not `x.99.z` | ERROR | intentional: stays `0.0.0.9000` until submission preparation |
| no `vignettes` directory | ERROR | later phase |
| Support Site: email `lcerulo@unisannio.it` not found (HTTP 404) | ERROR | maintainer to register at support.bioconductor.org |
| new-package version format (expects `0.99.z`) | WARNING | intentional (as above) |
| no Bioconductor dependencies | WARNING | expected so far; SummarizedExperiment input still an open API question |
| R dependency 4.1.0 → 4.6.0 | NOTE | decide at submission |
| suggested biocView `Regression` | NOTE | can be added |
| maintainer ORCID | NOTE | not invented |
| no `fnd` role | NOTE | author to decide |
| `paste()` in `stop()` | NOTE | frozen code: left unchanged (decision 3) |
| 8 functions > 50 lines | NOTE | frozen code: left unchanged (decision 3) |
| 37% of lines not 4-space indented | NOTE | frozen formatting kept (decision 2) |
| no NEWS file | NOTE | later phase |
| bioc-devel subscription | NOTE | maintainer action |

Local `R CMD check --as-cran --no-manual` on macOS: 0 ERRORs, 0 WARNINGs,
2 NOTEs (new submission; no pandoc locally).

---

## 8. Other notes

- **GitHub Actions deprecations:** `actions/checkout@v4` runs on Node 20,
  which is deprecated, and `ubuntu-latest` moves to Ubuntu 26 from
  2026-10-19. Both are cosmetic for now; bumping to `actions/checkout@v5` is
  a one-line follow-up.
- **Logs:** raw job logs need repository admin rights; the annotations
  contain everything cited above.
- `../postexport-kinetics` was not modified by this work: only `git status`,
  `rev-parse`, `archive` and `ls-remote` were run against it, and the CI clone
  was verified unchanged. Its HEAD has since moved from `687ec24` to
  `5d06a93` ("updated readme with doi", Luigi, 2026-09-24 21:55). That commit
  is the author's own; it commits the README change that was pending during
  the audit. The tag `manuscript-revision-v1.0` still resolves to
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`, so the frozen reference is
  unaffected.

Stopping here for your review.


---

## 9. Approved cross-platform regression policy and implementation

### 9.1 Policy (approved in review)

| Level | Applies when | Status | Rules |
|---|---|---|---|
| **A. Same-platform package vs frozen** | fixture provenance matches the current platform exactly (committed fixtures on the fixture platform; fixtures recomputed on the same Linux machine in CI) | **blocking** | unchanged strict tiers T0/T1/T2, elementwise; bitwise identity where achieved; includes bootstrap draws, `T*`, add-one p-values, `atom.zero` |
| **B. Cross-platform scientific regression** | provenance differs (committed macOS fixtures on Linux; frozen-vs-frozen comparison) | **blocking** | normwise `max|a−e| ≤ 1e-10·max(1, max|e|)`; T/RSS/boundary tolerance at absolute scale `1e-10·max(1,|RSS0|,|RSS1|)`; IR with the propagated bound; integers exact; structure exact; **identical frozen boundary classification** |
| **C. Platform-sensitive diagnostics** | extreme-conditioning fixtures (`lambda = none`, `indefinite_Sigma`, `rank1`, `zero_diag`) and bootstrap draws, across platforms | **reported, not blocking** | extreme fixtures: difference must be ≤ `100·κ·ε` (otherwise blocking); boundary classification still blocking; draws: reported only |

Three kinds of reproducibility are distinguished (`tools/frozen/README.md`):

- **Scientific equivalence:** the same frozen algorithm, with the same
  results up to rounding.
- **Numerical bitwise reproducibility:** only within a matched numerical
  environment.
- **Monte-Carlo reproducibility:** a fixed seed reproduces bootstrap draws
  only within a matched numerical environment, because the frozen
  `MASS::mvrnorm()` depends on LAPACK/BLAS.

The package preserves the frozen algorithm. Platform-specific linear algebra
can change bootstrap draws even under the same R seed. This does not change
the manuscript's conclusions: the deterministic observed-fit quantities agree
across platforms.

### 9.2 Implementation

| File | Change |
|---|---|
| `tests/testthat/helper-compare.R` | `compare_close()` (level A) unchanged. Added `compare_cross()`, `assess_cross()`, `max_scaled_diff()` and `case_kappa()` (levels B/C). |
| `tests/testthat/helper-fixtures.R` | `regression_level()` selects A vs B/C from provenance. `expect_regression()` uses the unchanged `expect_case()` at level A and the policy otherwise. Non-blocking notes go to `POSTEXPORT_PLATFORM_NOTES`. Bootstrap-draw tests skip across platforms with the measured difference. `POSTEXPORT_FORCE_CROSS_PLATFORM` exists for local testing only. |
| `tests/testthat/test-*.R` | Fixture comparisons call `expect_regression()`. The composed deterministic fit is compared as one object, so the RSS-scale and boundary rules apply. Same-platform strictness is unchanged. |
| `tools/frozen/recompute_fixtures.R` (new) | Frozen outputs recomputed on the current platform from the **committed inputs**. No `deSolve` regeneration; committed fixtures never overwritten. |
| `tools/frozen/compare_fixtures.R` | Rewritten to apply levels B/C; inputs must be identical. |
| `tools/ci/run_tests_ci.R` | Prints and annotates the reported non-blocking differences. |
| `.github/workflows/linux-regression.yml` | `actions/checkout@v5`. Job 2 recomputes from the committed inputs, then runs level A (strict, blocking), then the level B/C comparison, the diagnostics and the frozen-repository check. No other workflow changes. |
| `tools/frozen/README.md`, `RELEASE_CHECKLIST.md` | Final policy and the reproducibility distinctions documented. |

No package code (`R/`) and no committed fixture was changed.

### 9.3 Local validation of the policy (macOS, fixture platform)

- **Level A (default): all tests pass.** Expectation counts changed only
  because the composed deterministic fit is now one comparison per case (7
  before) and the real-data comparison now includes the error check. The
  tolerances are identical.
- **Forced level B/C on the committed fixtures:** all pass. Bootstrap tests
  skip with "max scaled difference … 0".
- **`recompute_fixtures.R` on macOS:** reproduces all 682 committed cases
  bitwise (`identical()` per file). `compare_fixtures.R` reports no
  differences.
- **Perturbation checks** (`compare_fixtures.R` / forced-cross tests / strict
  tests):

  | Perturbation | Level B/C outcome | Strict outcome |
  |---|---|---|
  | near-zero `Sigma_b` entries +1e-12 | pass | fail |
  | boundary flip (T set to 2×`tol_zero`) | **blocking** | fail |
  | `lambda=none` coefficients ×(1+1e-8) | reported (`1e-8 ≤ 100·κ·ε = 1.3e-5`, κ = 5.7e8) | fail |
  | Nsd1 `sigma_c` +1e-8 | **blocking** | fail |
  | `rank1` inverse square root ×(1+1e-3) | **blocking** (inconsistent with conditioning) | fail |
  | bootstrap `T*` and p changed | reported by `compare_fixtures.R`; the fixture self-consistency tests (add-one rule, B = 19 prefix) still reject the hand-corrupted fixture | fail |
