# PROJECT_STATE: entry point for new sessions

Concise project status. Details live in the phase reports; read them in the
order in §11. `CLAUDE.md` holds the standing engineering and
scientific-invariance rules.

## 1. Frozen scientific reference (read-only)

- Repository: `../postexport-kinetics` (`~/postexport-kinetics`); remote
  `https://github.com/bioinformatics-sannio/postexport-kinetics`.
- Authoritative tag: **`manuscript-revision-v1.0`** →
  **`65c3b7368fb7686bfde3dab857f98c393bb534c5`**.
- Never modify it. Read it only through `tools/frozen/export_frozen.sh`
  (`git archive` of the tag). Its HEAD may move for the author's own
  documentation commits; the tag is what counts.

## 2. Package state

- Package: `postexportKinetics` `0.0.0.9000` (development; move to `0.99.0`
  only at Bioconductor submission preparation). MIT license. Maintainer Luigi
  Cerulo `<lcerulo@unisannio.it>`.
- Repository: `https://github.com/bioinformatics-sannio/postexportKinetics`.
- **Current approved main:** `1965404`. This is a documentation-only
  checkpoint that adds this file on top of the Phase 3 merge.
- **Phase 3 merge baseline:** `aace22ddf9a8248e9950aef3841eefc0cbbd713e`.
- Branches `phase1-core`, `phase2-api` and `phase3-sim` are kept.

## 3. Completed phases

| Phase | Content | Report |
|---|---|---|
| audit | frozen-source audit, plan | `PACKAGE_PLAN.md`, `STOP_CONDITION_REPORT.md` |
| 1 | verbatim internal numerical core, fixtures, regression tests | `PHASE1_REPORT.md` |
| 1.5 | Linux CI, three-level cross-platform regression policy | `PHASE1_5_REPORT.md` |
| 2 | public inference API, frozen orchestrator port | `PHASE2_REPORT.md` |
| 3 | simulator and assay ports, simulation API, operational-domain diagnostics | `PHASE3_REPORT.md` |

## 4. Current public API

```r
postexport_data(x, time_unit, format = c("wide", "long"), columns = NULL)
validate_postexport_data(x, format, columns, t_star = NULL)
postexport_control(B = 1999L, seed = NULL, lambda_time = 0.5, lambda_diag = 0.1,
                   rel_floor = 1e-8, max_failure_rate = 0.05,
                   scaling_A = TRUE, truncate_nonnegative_boot = FALSE)
fit_postexport_model(data, t_star, control = postexport_control(), events = NULL)
test_postexport_conversion(data, t_star, control = postexport_control(), events = NULL)
simulate_postexport_kinetics(params, times, onset_time, t_star, regime, time_unit,
                             residual_fraction = NULL, n_replicates = 1L,
                             param_cv = 0, noise = NULL, y0 = 0, origin = 0,
                             grid_step = 1, horizon = NULL, seed = NULL,
                             event = "simulated")
check_operational_domain(data = NULL, regime, t_star = NULL, platform = NULL,
                         noise_level = NULL, n_time_points = NULL,
                         n_replicates = NULL, sampling_interval = NULL,
                         time_unit = NULL)
```

- **Methods:** `print`/`summary` for all result classes. There is no
  `plot()` yet.
- **Internal:** `build_interval_balance`, `add_assay_noise` and
  `postexport_trajectory` concepts stay internal.
- **Not yet available:** ranking, plotting, batch/parallel execution, rMATS
  conversion, comparators, vignette.

## 5. Key scientific-invariance decisions

- **Verbatim ports:** the frozen code is ported verbatim, with mechanical
  edits only. They are listed per function and enforced by
  `test-verbatim-port.R`:
  - `stats::` qualification;
  - `data.table` → `data.frame` in the assay ports (proven bitwise
    identical).
- **Frozen formatting** is preserved: no reformatting and no style
  refactoring of the ports.
- **`sigma_c`** is a phenomenological post-export conversion rate; wording
  never claims a mechanism. The procedure is not a likelihood-ratio test.
- **`t_star`** is a required argument of fit, test and simulation (`NULL`
  means continuous transcription). It never lives in the control object.
- **Onset** changes only the pre-intervention history; the intervention time
  is common. No hidden onset draw is made.
- **RNG:**
  - the public API restores the caller's RNG state for explicit seeds;
  - `seed = NULL` consumes the stream;
  - the frozen `set.seed` inside the orchestrator is unchanged.
- **Data validation:**
  - missing states are errors, never zero-filled;
  - negative abundances warn and are kept unchanged;
  - `t_star` outside the sampled window warns and never blocks.
- **Multiple events:**
  - a named per-event seed vector or `seed = NULL`; a scalar seed with
    several events is an error;
  - no q-values inside tests.
- **Operational domain:**
  - diagnostic only; no calibration claim;
  - NONE is always reported as strongly anti-conservative;
  - PSEUDO_SHUTOFF is `not_benchmarked`;
  - nearest evaluated benchmark designs are returned as a full set, with no
    score.
- **Excluded from v0.1:** ΔPSI and cytoplasmic-only comparators, and
  PR-AUC/AUROC utilities.

## 6. Cross-platform regression policy

- **A. Same platform (provenance matches): strict, blocking.** Elementwise
  tiers T0/T1/T2; bitwise identity where achieved; includes bootstrap
  draws.
- **B. Cross platform: scale-aware, blocking.**
  - Normwise: `max|a−e| ≤ 1e-10·max(1, max|e|)`.
  - T and RSS: `1e-10·max(1,|RSS0|,|RSS1|)`; IR uses the propagated bound.
  - Integers are compared exactly.
  - The frozen boundary classification must be identical.
- **C. Reported, not blocking.** Bootstrap draws and draw-dependent fields,
  noisy simulated observations, and the four extreme-conditioning fixtures
  (within `100·κ·ε`).
- **Linux CI (`.github/workflows/linux-regression.yml`):** recomputes frozen
  outputs on the committed inputs (A), compares them with the committed
  macOS fixtures (B/C), verifies benchmark metadata against its MD5, and
  checks that the frozen clone is unchanged.
- Fixtures are never edited by hand (`tools/frozen/`).

## 7. Manuscript-run bootstrap provenance

| Analysis | B |
|---|---|
| package default (core default, factorial benchmark) | **1999** |
| pseudo-shutoff final real-data run (Kc167, K562, NIH-3T3) | **4999**; the script declares 1999, so this is a recorded discrepancy (`STOP_CONDITION_REPORT.md` §1) |
| mESC final run (`run_mESC_20k.R`) | **19999** |

## 8. Other recorded provenance facts

- The corrected-onset generator's `.Random.seed` restore is ineffective.
  Fixtures reproduce the actual behaviour (SF-2).
- `run_pseudoshutoff_misspecification_benchmark.R` is authoritative;
  `run_benchmark_pseudoshutoff_revision.R` is superseded (SF-4).
- The benchmark table (`R/sysdata.rda`) is built by
  `data-raw/benchmark_domain.R` from the tag's summary TSV (MD5 recorded).

## 9. Current BiocCheck blockers (not claimed compatible)

- ERROR: version not `x.99.z` (intentional during development).
- ERROR: no vignette (a later phase).
- ERROR: support-site registration of the maintainer email (maintainer
  action; also needs network).
- WARNINGs:
  - version format;
  - no Bioconductor dependencies (open: SummarizedExperiment input);
  - `set.seed` usage, in the frozen orchestrator and the public simulator
    (documented).
- NOTEs: frozen-code style (indentation, `paste` in conditions, `<<-`, `=`,
  long lines, function length); metadata (ORCID, `fnd`, NEWS, R version).
- `R CMD check --as-cran`: 0 ERRORs / 0 WARNINGs, with 2 NOTEs locally (new
  submission; no pandoc).

## 10. Next phase

**Phase 4** is the next phase. Its approved scope is:

- serial multi-event / batch usability;
- Benjamini-Hochberg multiple-testing adjustment;
- exploratory candidate ranking (approved score
  `sigma_c × IR × min(−log10(max(q, 1e-10)), 6)`; exploratory prioritisation,
  not inferential);
- plotting;
- exportable result tables.

**Not part of Phase 4** (later phases):

- parallel execution;
- vignette;
- rMATS conversion;
- comparators;
- Bioconductor submission cleanup;
- release `0.99.0`.

## 11. Authoritative reading order

1. `CLAUDE.md`: standing rules.
2. `PROJECT_STATE.md`: this file.
3. `STOP_CONDITION_REPORT.md`: provenance decisions (SF-1 … SF-19).
4. `PHASE1_5_REPORT.md` §9–10 and `tools/frozen/README.md`: regression
   policy.
5. `PHASE3_REPORT.md`, then `PHASE2_REPORT.md`: current API and decisions.
6. `PACKAGE_PLAN.md`: original architecture and remaining scope, with the
   amendments recorded in the later reports.
7. `RELEASE_CHECKLIST.md`: release requirements.
