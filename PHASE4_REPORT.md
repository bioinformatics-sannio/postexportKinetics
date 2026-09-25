# Phase 4 Report: batch usability, multiple testing, ranking, plotting, tables

Status: **Phase 4 approved, with the decisions recorded in §12. The
approved single-test adjustment change is implemented. Phase 5 not
started.**

- **Baseline:** `main` @ `1965404`. The branch starts from `9de2958`, which
  adds only the approved documentation update to `PROJECT_STATE.md` on top
  of `1965404`.
- **Frozen reference:** `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`.

Commits on `phase4-batch`:

- `bbae462` Add batch usability, BH adjustment, exploratory ranking and tidy
  tables
- `e857e4c` Add ggplot2 plot methods for fits, tests, sets, simulations and
  domain checks
- `1e5188f` Add PHASE4_REPORT.md for review
- `1d18013` Accept single tests in adjust_postexport_pvalues(); document
  families, ties and display curves (approved change, decision 7)
- this report update

**No frozen fixture, ported frozen function (`R/constants.R`,
`matrix-utils.R`, `covariance.R`, `interval-balance.R`, `fit.R`,
`crank-nicolson.R`, `bootstrap.R`, `inference.R`, `ode.R`, `assay.R`),
benchmark table or single-event computation was changed.** `git diff main`
on these paths is empty.

---

## 1. Files and functions added

| File | Content |
|---|---|
| `R/batch.R` (new) | `adjust_postexport_pvalues()`, `rank_postexport_candidates()`, `print.postexport_ranking()`, `as.data.frame()` methods for `postexport_fit`, `postexport_fit_set`, `postexport_test_set` (and `postexport_test` through inheritance), column-role table |
| `R/plot.R` (new) | `plot()` methods for `postexport_fit`, `postexport_test`, `postexport_fit_set`, `postexport_test_set`, `postexport_simulation`, `postexport_domain_check`; internal display-trajectory helper |
| `R/api.R` (modified, additive) | results keep their event's input rows (`$data`); multi-event runs record unexpected per-event errors as status `"event_error"`; documentation |
| `tests/testthat/test-batch.R`, `test-plot.R` (new) | batch, adjustment, ranking, tables, plots |
| `man/` | new topics: `adjust_postexport_pvalues`, `rank_postexport_candidates`, `as.data.frame.postexport`, `plot.postexport` |

---

## 2. Public API additions

```r
adjust_postexport_pvalues(x, method = "BH", groups = NULL)
rank_postexport_candidates(x)
## S3 method for class 'postexport_fit' / 'postexport_fit_set' / 'postexport_test_set'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
## S3 method for class 'postexport_fit'
plot(x, type = "fit", show_means = TRUE, ...)
## S3 method for class 'postexport_test'
plot(x, type = c("fit", "bootstrap"), show_means = TRUE, ...)
## S3 method for class 'postexport_fit_set'
plot(x, type = c("status", "boundary", "sigma_IR"), ...)
## S3 method for class 'postexport_test_set'
plot(x, type = c("status", "boundary", "sigma_IR", "sigma_q", "IR_q", "score"), ...)
## S3 method for class 'postexport_simulation'
plot(x, show_observed = TRUE, ...)
## S3 method for class 'postexport_domain_check'
plot(x, ...)
```

Existing public fields were neither removed nor renamed. The additions are:

- `$data` on fit and test results;
- `inference$q_value` and `inference$adjustment_method` after adjustment;
- `summary$q_value`, `summary$adjustment_group` and `$adjustment` on
  adjusted sets.

`$raw` (the frozen result) is unchanged, and a test asserts it.

### Batch behaviour

- Events are processed sequentially; there is no parallel execution.
- Per-event result objects are kept in `$results`; `$summary` is compact.
- Frozen failures are already frozen status codes. An **unexpected R error
  while processing one event** in a multi-event call becomes status
  `"event_error"`, with the message in `error_message`, and the remaining
  events are processed. This is tested with a mocked failure.
- Malformed package-level input (data, control, `t_star`, seeds) still
  stops with an error.
- Single-event calls are not wrapped and behave exactly as before; this is
  tested.
- Multi-event results equal the corresponding single-event results
  (`$raw` identical; tested for 4 events).

---

## 3. Multiple-testing design

- `adjust_postexport_pvalues()` is an explicit, separate batch-level
  operation. `test_postexport_conversion()` never adjusts.
- It calls `stats::p.adjust(method = "BH")` by default; any
  `p.adjust.methods` value is accepted.
- **Valid tests** only: `status == "ok"` and a finite p-value, the frozen
  `valid_test` rule (`run_real_datasets_revision.R` L1389). Other events
  keep their status and get `q_value = NA`. Status decides validity even
  when a finite p-value is present (tested).
- **Families:** by default a single family. `groups` (one label per event,
  or named by event) adjusts separately within each group. The manuscript
  applied BH separately within each dataset (L1440), and this is
  documented.
- Raw p-values are never modified (tested). p- and q-values are separate
  columns and fields.
- **Single tests** (approved decision 7): a single `postexport_test` is
  accepted and adjusted as a multiple-testing family of size one.
  - `stats::p.adjust()` is applied normally, so under BH `q = p`.
  - `q_value` and `adjustment_method` are stored in `inference`, exactly as
    for sets, and `$adjustment` is added.
  - The raw p-value is preserved, and no warning is emitted for a family of
    size one.
  - An invalid single test gets `q_value = NA`.
  - The documentation explains that multi-event studies should define their
    testing family according to the experimental or dataset analysis plan.

---

## 4. Ranking formula and provenance

\[
\text{score} = \sigma_c \times IR \times \min\bigl(-\log_{10}(\max(q, 10^{-10})), 6\bigr)
\]

Frozen `score_sigma_IR_q`, `real_datasets/run_real_datasets_revision.R`:

| Element | Lines |
|---|---|
| `eps = 1e-10` | L1453 |
| `-log10` | L1506 |
| cap 6 | L1516, L1531 |
| score | L1614 |
| IR = ΔRSS/RSS0 if RSS0 > 0, else NA | L1468-1471 |
| exploratory order `order(dataset, -score)` | L1841 |

The same composite is used in `analyze_composite_score_ablation.R`
L186-218.

- q-values are **required**. Without an adjustment the call errors with "call
  adjust_postexport_pvalues() first", and raw p-values are never
  substituted.
- `q = 0` is floored at 1e-10, so the evidence term is capped at 6. Because
  of the cap, any floor ≤ 1e-6 gives identical scores. This is a property of
  the frozen formula, so a floor mutation of 1e-10 → 1e-8 is correctly
  undetectable.
- `q = NA`, a non-`ok` status, or NA `sigma_c`/IR: the event is kept with
  `score = NA` and `rank = NA`, listed last.
- Boundary events (`sigma_c = 0`) get score 0 and are ranked.
- Ties share the minimum rank (`ties.method = "min"`) and keep input order,
  as the stable frozen `order()` does.
- Ranking is performed within each adjustment family, as the frozen code
  does per dataset.
- The output is a `postexport_ranking` data frame. Its attributes
  `definition` and `provenance` state that it is exploratory prioritization,
  not inferential and not an optimized discrimination score.

Ranking output columns: `rank`, `event`, `status`, `score`, `evidence`,
`p_value`, `q_value`, `sigma_c`, `IR`, `at_boundary`, `sigma_c_zero`,
`adjustment_group`, `n_bootstrap_valid`, `bootstrap_failure_rate`,
`condition_number`, `rank_full`.

---

## 5. Plot methods and types (ggplot2; each returns a `ggplot`)

| Class | Types | Content |
|---|---|---|
| `postexport_fit` | `"fit"` | Four states faceted (`N`, `N_s`, `C`, `C_s`, labelled with compartment and processing), replicate observations, time-point means (`show_means`), sampling-time rug and `t_star`. The fitted full (`sigma_c >= 0`) and null (`sigma_c = 0`) models are display reconstructions: propagated from the observed replicate-mean state at the first sampled time with the fitted coefficients, using the ported frozen `simulate_scheduled_trajectory()`. The caption and documentation state that inference uses the frozen interval-balance / Crank-Nicolson machinery, not these curves. Title: "Post-export kinetic model fit". |
| `postexport_test` | `"fit"` (default), `"bootstrap"` | As above; `"bootstrap"` shows the T* histogram with the boundary atom highlighted, observed T, p-value, valid count, failure fraction and `atom.zero` in the subtitle. |
| `postexport_fit_set` | `"status"` (default), `"boundary"`, `"sigma_IR"` | Counts or scatter; descriptive. |
| `postexport_test_set` | adds `"sigma_q"`, `"IR_q"`, `"score"` (these require adjustment) | Axes name effect size, fit improvement and adjusted evidence separately. There is no "volcano" type. |
| `postexport_simulation` | — | Latent trajectories per replicate (no smoothing), sampled latent states, noisy observations (`show_observed`), dotted onset marker and dashed `t_star` marker, regime in the subtitle. |
| `postexport_domain_check` | — | Title "Manuscript benchmark designs": empirical Type-I error with Wilson 95% interval, nominal 0.05 line, colour for exact vs nearest evaluated designs, shape for the Wilson criterion; caption "not a calibration guarantee for any dataset". `not_benchmarked` gives an explanatory empty plot. |

- **Colours:** the colour-blind-safe Okabe–Ito palette; no
  manuscript-specific colours.
- **Separation from inference:** no plot modifies its input (every plot
  test asserts `identical()` before and after); no plot refits or runs
  inference.

---

## 6. Result-table schema (`as.data.frame()`)

One row per event, flat columns only (no matrices). The column roles are also
in `attr(, "column_roles")`.

| Role | Columns |
|---|---|
| identifier / status | `event`, `status`, `error_message` |
| inference | `p_value`, `q_value` (only after adjustment), `adjustment_group`, `B`, `n_bootstrap_valid`, `bootstrap_failure_rate`, `atom_zero` |
| effect size | `sigma_c` |
| fit | `IR`, `T_obs`, `RSS_null`, `RSS_full` |
| boundary | `at_boundary`, `sigma_c_zero`, `boundary_tolerance` |
| diagnostics | `condition_number`, `condition_number_nonzero_columns`, `min_singular_value`, `rank_full`, `rank_null`, `structurally_zero_columns` |
| design | `t_star`, `time_unit`, `n_time_points`, `min_replicates`, `design_warnings` |

Fit sets have no inference columns. The existing `$summary` of sets is
unchanged, apart from the additive `q_value` and `adjustment_group` after
adjustment.

---

## 7. Dependency changes

- **`ggplot2` added to `Imports`.** Plotting is part of the public API
  scope. `ggplot2` is widely used, maintained and already common in
  Bioconductor, and it exports `.data`, so no undefined-global NOTEs arise.
  No `patchwork`/`cowplot` was added. On the development machine it has 22
  recursive dependencies.
- No other dependency changes.

---

## 8. Tests and mutation checks

Final local suite (macOS), 15 files: **3,654 expectations, 0 failures, 0
errors, 0 warnings, 0 skipped.** The initial Phase 4 run had 3,626; the
difference comes from the single-test and caption tests.

- `test-batch.R`, 9 `test_that` blocks:
  - batch results equal single-event results;
  - a mocked per-event failure gives `event_error` for that event only, and
    single-event calls still propagate the error;
  - BH equals `stats::p.adjust` on valid tests; other methods pass through;
  - invalid and failed events are excluded, including a non-ok status with
    a finite p-value;
  - groups; raw p-values unchanged; `$raw` unchanged;
  - the ranking formula exactly;
  - `q = 0` and `q = 1e-12` give evidence capped at 6; `q = NA` is
    retained and listed last;
  - tied scores share the minimum rank in input order; failed events are
    retained;
  - boundary events get score 0; ranking within families;
  - table columns and roles;
  - a single test adjusted as a family of size one: equals
    `stats::p.adjust()` for BH, holm and bonferroni, BH gives `q = p`, no
    warning, raw p and `$raw` preserved, an invalid test gets NA, the tidy
    table gains `q_value`, and ranking still requires a set.
- `test-plot.R`, 4 `test_that` blocks (95 expectations):
  - every method returns a buildable `ggplot` and does not modify its
    input;
  - the fit plot has four state facets, two model curves, the rug and a
    `t_star` line at the right position, and a caption stating display reconstruction from the first sampled
    time and inference by the frozen interval-balance / Crank-Nicolson
    machinery;
  - bootstrap-plot subtitle content;
  - set plot types, with q required where needed;
  - simulation onset and `t_star` markers at the correct times, no smoothing
    geom, and NONE shows only the onset marker;
  - domain plot title and caption, the 0.05 reference, and exact vs nearest
    labels;
  - forbidden wording is absent: "cytoplasmic splicing detected", "your
    dataset is calibrated", "likelihood-ratio test", "calibration of your
    dataset".
- There are no image snapshots.
- The Phase 1–3 suites are unchanged and pass.

**Mutation checks** (temporary edits to the installed namespace):

| Mutation | `test-batch.R` failures |
|---|---:|
| evidence cap 6 → 5 | 2 |
| q floor 1e-10 → 1e-8 | 0 (equivalent by construction, §4) |
| BH over all events instead of valid tests | 2 |
| ties `"min"` → `"first"` | 1 |
| failed events treated as rankable | 1 |
| "q required" guard removed | 1 |

The BH mutation was initially not caught, because NA p-values are already
skipped by `p.adjust`. The finite-p invalid-status test was added to cover
it.

---

## 9. R CMD check

`R CMD build` + `R CMD check --as-cran --no-manual` (macOS, R 4.6.0):
**0 ERRORs, 0 WARNINGs, 2 NOTEs** (final code, after the approved change).

- The NOTEs are the new submission and `pandoc` unavailable.
- Examples OK, including the adjustment, ranking and plot examples; tests OK
  (about 33 s).

---

## 10. BiocCheck (1.48.1, bioconductor.org reachable)

Final code: **3 ERRORs, 2 WARNINGs, 12 NOTEs**, counted by BiocCheck
check. There are no new findings.

The draft of this report listed 3 WARNINGs because it counted the version
format separately; BiocCheck reports version format under the ERROR only.
The `set.seed` warning has two occurrences in one check.

| Finding | Type | Status |
|---|---|---|
| version not `x.99.z` | ERROR | intentional (`0.0.0.9000`) |
| no vignettes | ERROR | later phase |
| Support Site email lookup (HTTP 404 in the final run, 504 earlier) | ERROR | maintainer registration |
| no Bioconductor dependencies | WARNING | open (SummarizedExperiment not approved) |
| `set.seed` (2 occurrences) | WARNING | frozen orchestrator; public simulator (documented) |
| function length (25 functions > 50 lines) | NOTE | now includes new plot/validation helpers; advisory (decision 9 of Phase 2) |
| `=`, `paste` in conditions, `<<-`, long lines (6), indentation (22%) | NOTE | frozen code only; new code uses 4 spaces and ≤ 80 characters |
| R version, biocViews, ORCID, `fnd`, NEWS, bioc-devel | NOTE | metadata |

---

## 11. Linux CI

The run on the final Phase 4 code change (`1d18013`) and the runs on
`main` are listed in `PROJECT_STATE.md` and in the completion report.

- Run `36099416762` on `1d18013` (final Phase 4 code): **both jobs
  succeeded**, `package` and `frozen-reference`, with every step
  successful.

Earlier run `36097861393` on `e857e4c` (`ubuntu-latest`, Linux regression
workflow): **both jobs succeeded.**

- `package`: deterministic regression tests on committed fixtures and
  `check-r-package` passed.
- `frozen-reference`:
  - frozen outputs recomputed from committed inputs;
  - benchmark metadata MD5 matches;
  - same-platform strict comparison, including bootstrap draws, passed;
  - cross-platform scientific-policy comparison passed;
  - frozen repository verified unmodified.
- Annotations are notices only:
  - Level-C diagnostics: bootstrap-draw-dependent fields differ across
    platforms and are reported but not compared, as in earlier phases.
  - Fixture case counts.
  - GitHub's notice that `ubuntu-latest` migrates to Ubuntu 26 from
    2026-10-19. No action has been taken; pinning the runner image is a
    possible later decision.

The Phase 1–3 regression is green on Linux.

---

## 12. Approved decisions (review of this report)

1. **`event_error`:** approved.
   - Used exclusively for unexpected R-level errors while processing one
     event inside a multi-event run.
   - Not used for frozen scientific or numerical failure statuses, malformed
     package-level input, or validation errors, which stop before batch
     processing.
   - The original error message is preserved in `error_message`.
2. **Ties:** `ties.method = "min"` (competition rank). Stable input order is
   kept for display among ties. First-occurrence and dense ranks are not
   used.
3. **Ranking families:** ranks are computed independently within each
   adjustment group; there is no global rank across distinct families. The
   documentation states that a common ranking requires one common
   multiple-testing family before adjustment and ranking.
4. **Default set plot:** `type = "status"` for fit and test sets.
5. **Fitted trajectories:**
   - ODE-based display reconstructions are the default and only fitted
     trajectory representation in v0.1; there is no Crank-Nicolson overlay.
   - The caption and documentation state that the curves are display
     reconstructions propagated from the observed replicate-mean state at
     the first sampled time with the fitted coefficients, and that
     inference uses the validated frozen interval-balance / Crank-Nicolson
     machinery.
   - Plotting stays separate from inference.
6. **`ggplot2`** stays in Imports; no other plotting dependencies.
7. **Single-test adjustment:** changed as approved (§3). A single
   `postexport_test` is a family of size one, adjusted with
   `stats::p.adjust()`. Tested.
