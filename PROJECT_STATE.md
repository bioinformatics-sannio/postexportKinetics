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

- Package: `postexportKinetics`. The released version is **`0.1.0`** (tag
  `v0.1.0`, immutable). The Bioconductor development line on branch
  `bioconductor-prep` is **`0.99.0`** (Phase 6A). MIT license.
  Maintainer Luigi Cerulo `<lcerulo@unisannio.it>`.
- **Released version 0.1.0**, the first public GitHub release:
  - GitHub tag: **`v0.1.0`**, annotated (tag object `303e2e1`);
  - GitHub release:
    <https://github.com/bioinformatics-sannio/postexportKinetics/releases/tag/v0.1.0>
    (published 2026-09-25);
  - release merge commit:
    **`04c4407dfbc0e04b2725a007387e33bdcf5b131d`** (`--no-ff` merge of
    `release-0.1.0`);
  - release tarball `postexportKinetics_0.1.0.tar.gz`, built in CI
    (release-candidate run `36143895882`, R 4.6.1, Ubuntu 24.04.5) from the
    merge commit: SHA256
    **`dd6979ff48a49c5ce5118e3990abb5b74ebdf2264a5728e22662d6ba87f18eda`**;
  - release assets: the tarball, its `.sha256` and the full manuscript
    validation log (EQUIVALENT), published by `publish-release.yml` from the
    gated artifact of the merge commit;
  - **no package DOI and no Zenodo archive** (maintainer policy);
  - the frozen manuscript DOI remains **`10.5281/zenodo.22944109`**. It is
    the DOI of the frozen implementation, never of the package.
- **Bioconductor** is the intended future distribution channel. The
  Bioconductor line `0.99.0` has not been started.
- Repository: `https://github.com/bioinformatics-sannio/postexportKinetics`.
- **Current approved main:** `04c4407` (0.1.0 release merge) plus the
  documentation-only commit that updates this file.
- **Phase 5 merge:** `f7e23ee`.
- **Earlier baselines:**
  - Phase 4 merge `21d8a23` (with `PROJECT_STATE.md` update `982aeb6`);
  - Phase 3 merge `aace22ddf9a8248e9950aef3841eefc0cbbd713e`;
  - documentation checkpoints `1965404` and `9de2958`.
- Branches `phase1-core`, `phase2-api`, `phase3-sim`, `phase4-batch`,
  `phase5-docs` and `release-0.1.0` are kept.

## 3. Completed phases

| Phase | Content | Report |
|---|---|---|
| audit | frozen-source audit, plan | `PACKAGE_PLAN.md`, `STOP_CONDITION_REPORT.md` |
| 1 | verbatim internal numerical core, fixtures, regression tests | `PHASE1_REPORT.md` |
| 1.5 | Linux CI, three-level cross-platform regression policy | `PHASE1_5_REPORT.md` |
| 2 | public inference API, frozen orchestrator port | `PHASE2_REPORT.md` |
| 3 | simulator and assay ports, simulation API, operational-domain diagnostics | `PHASE3_REPORT.md` |
| 4 | batch usability, multiple-testing adjustment, exploratory ranking, plots, tidy tables | `PHASE4_REPORT.md` |
| 5 | README, vignette, synthetic example data, NEWS, CITATION.cff / inst/CITATION, `tools/validate_against_manuscript.R`, documentation and metadata polish | `PHASE5_REPORT.md` |
| RC / release 0.1.0 | fixture provenance normalisation, dependency minimums, R-compatibility and platform CI, release-candidate and publish-release workflows, version 0.1.0, GitHub release `v0.1.0` | `RELEASE_CANDIDATE_0.1.0.md` |

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
adjust_postexport_pvalues(x, method = "BH", groups = NULL)  # set or single test
rank_postexport_candidates(x)                               # adjusted set
as.data.frame(x, ...)  # postexport_fit, postexport_test, postexport_fit_set,
                       # postexport_test_set: stable columns + column_roles
plot(x, ...)           # fit/test ("fit", "bootstrap"), fit_set/test_set
                       # ("status" default, "boundary", "sigma_IR",
                       # test_set also "sigma_q", "IR_q", "score"),
                       # simulation, domain_check ("Manuscript benchmark designs")
```

- **Methods:** `print`/`summary` for all result classes, `print` for
  `postexport_ranking`, and `plot()` (ggplot2) and `as.data.frame()` as
  above.
- **Internal:** `build_interval_balance`, `add_assay_noise` and
  `postexport_trajectory` concepts stay internal.
- **Data:** `postexport_example` and `postexport_example_truth`
  (synthetic; see §5a); `inst/extdata/postexport_example_long.csv`.
- **Documentation and metadata:**
  - vignette `vignette("postexportKinetics")`;
  - `README.md`, `NEWS.md`;
  - `CITATION.cff` and `inst/CITATION` (`citation("postexportKinetics")`):
    the package (**no package DOI**), the submitted manuscript, and the
    frozen manuscript implementation (`10.5281/zenodo.22944109`, which is
    not the package DOI).
- **Maintainer validation:** `tools/validate_against_manuscript.R` (§5a).
- **Not yet available:** parallel execution, rMATS conversion, comparators.
  SummarizedExperiment input is **deferred** (§5a).
- **Dependencies:**
  - Imports: deSolve, ggplot2, MASS, nnls, stats, utils;
  - Suggests: expm, knitr, rmarkdown, testthat;
  - VignetteBuilder: knitr.
- **Metadata:**
  - `Depends: R (>= 4.1.0)` is **supported by CI evidence**: the r-compat
    workflow (R 4.1, oldrel-1) is green on the release branch. The minimums
    `ggplot2 (>= 3.4.0)` and `testthat (>= 3.1.7)` are declared on the
    release branch.
  - biocViews: Software, Transcriptomics, RNASeq, AlternativeSplicing,
    TimeCourse, StatisticalMethod, **MultipleComparison**, Visualization.
  - `LazyData: false`.

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
- **Batch failures (`event_error`):**
  - used exclusively for unexpected R-level errors while processing one
    event in a multi-event run;
  - the original message is kept in `error_message`, and the other events
    continue;
  - never used for frozen scientific or numerical statuses, malformed
    package-level input, or validation errors, which stop before batch
    processing;
  - single-event calls are not wrapped.
- **Multiple testing:**
  - an explicit step, `adjust_postexport_pvalues()`, never done inside
    `test_postexport_conversion()`;
  - BH by default via `stats::p.adjust`;
  - only valid tests enter: status `ok` and a finite p-value;
  - raw p-values are never altered.
  - Families: one family by default. `groups` adjusts separately per group;
    the manuscript used one family per dataset.
  - A single `postexport_test` is a family of size one (BH: `q = p`), with
    no warning.
- **Ranking:**
  - exploratory prioritisation, not inferential and not an optimised
    discrimination score;
  - score `sigma_c × IR × min(−log10(max(q, 1e-10)), 6)`; q is required, and
    p is never substituted;
  - ranks are computed within adjustment families, with no global rank; a
    common ranking needs one common family;
  - `ties.method = "min"`, with stable input order;
  - failed or NA events are kept with NA score and rank.
- **Plots:**
  - fitted curves are display-only ODE reconstructions, propagated from the
    observed replicate-mean state at the first sampled time with the fitted
    coefficients;
  - they do not replace the frozen interval-balance / Crank-Nicolson
    inference;
  - there is no CN overlay in v0.1;
  - plots never refit or modify results.
- **Excluded from v0.1:** ΔPSI and cytoplasmic-only comparators, and
  PR-AUC/AUROC utilities.

## 5a. Phase 5 decisions

- **Example data:**
  - one calibrated benchmark design (SHUTOFF, `t_star = 332` min, 5 time
    points × 5 replicates, step 10 min, RNA-seq very low noise; benchmark
    power about 0.24), selected from the benchmark table before generation;
  - the seed (20260925) was fixed a priori, with no seed search;
  - it is not to be replaced by a higher-power, anti-conservative design;
  - generation code in `data-raw/postexport_example.R`.
- **Bootstrap counts in documentation:** `B = 499` in the vignette (which
  states the floor `1/(B+1)`), `B = 49`/`99` in examples. Each is marked as
  only for speed and not recommended for final analysis.
- **SummarizedExperiment:** deferred from v0.1. No Bioconductor dependency
  is added merely to silence BiocCheck.
  - Layout A (four state assays) is a possible future thin converter.
  - Layout B (compartment libraries) needs pairing, normalisation and
    mapping decisions.
  - Revisit at Bioconductor submission preparation.
- **Citation and identifiers** (maintainer policy, superseding the earlier
  Zenodo plan):
  - the manuscript stays unpublished/submitted;
  - **postexportKinetics gets no Zenodo archive and no DOI.** Releases are
    GitHub releases, and the intended future distribution channel is
    Bioconductor;
  - `10.5281/zenodo.22944109` is only the DOI of the frozen manuscript
    implementation and is never presented as the package DOI;
  - there is no `.zenodo.json`.
- **Manuscript validation:** `tools/validate_against_manuscript.R`,
  documented in `tools/frozen/README.md`. It exits 1 on any failure. The
  full run is required for release; Linux CI runs it with `--quick`.

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

Phase 5 final counts (BiocCheck 1.48.1): **2 ERRORs, 2 WARNINGs, 10 NOTEs**.

- ERRORs:
  - version not `x.99.z` (intentional during development);
  - support-site registration of the maintainer email (maintainer action;
    also needs network).
  - The missing-vignette ERROR is resolved.
- WARNINGs:
  - no Bioconductor dependencies (SummarizedExperiment deferred);
  - `set.seed` usage, in the frozen orchestrator and the public simulator
    (documented).
- NOTEs:
  - frozen-code style (indentation, `paste` in conditions, `<<-`, `=`, long
    lines, function length);
  - metadata (ORCID, `fnd`, bioc-devel);
  - R version (4.1.0 is kept provisionally).
  - The NEWS and biocViews notes are resolved.
- `R CMD check --as-cran`, including the manual and the vignette: 0 ERRORs,
  0 WARNINGs, 2 NOTEs locally.
  - CRAN incoming feasibility: new submission and the development version
    number.
  - HTML manual validation skipped because of the local tools (old HTML
    Tidy, no V8).
- **Correction of the historical NOTE attribution:** in Phases 1–4, the
  "checking top-level files" NOTE was the non-ignored `PHASE1_5_REPORT.md`,
  not the missing pandoc as reported earlier. `.Rbuildignore` was fixed in
  Phase 5 (`^PHASE[0-9_]+_REPORT\.md$`), and that NOTE no longer appears.
- Test suite: 16 files, 3,677 expectations, 0 failures.

## 10. Next phase

**Phase 6: Bioconductor preparation. Stop Point 0 (read-only audit) is in
progress** on branch `bioconductor-prep`: `BIOCONDUCTOR_AUDIT.md`, awaiting
review. No package change, no version change and no account action have
been made. Earlier candidate topics:

- the `0.99.x` version line;
- BiocCheck remaining items:
  - Support Site registration;
  - Bioconductor dependency (the SummarizedExperiment decision, deferred;
    Layout A converter possible);
  - `set.seed`;
  - style NOTEs outside the frozen ports;
- the bioc-devel subscription;
- ORCID if supplied by the authors.

**Release 0.1.0: done** (§2). There is no package DOI and no Zenodo archive.

**Still open for later:** parallel execution, rMATS conversion,
comparators, SummarizedExperiment input.

**CI maintenance:**

- GitHub moves `ubuntu-latest` to Ubuntu 26 from 2026-10-19. CI stays on
  `ubuntu-latest` unless a concrete compatibility problem appears. After
  the migration, confirm the level A/B/C results and record the new
  LAPACK/BLAS provenance (`RELEASE_CHECKLIST.md` §3a).
- `actions/upload-artifact@v4` triggers a Node.js 20 deprecation warning.

**Manuscript Availability statement** (author action): cite the
manuscript-code repository and DOI 10.5281/zenodo.22944109, and optionally
the postexportKinetics repository and release `v0.1.0`.

## 11. Authoritative reading order

1. `CLAUDE.md`: standing rules.
2. `PROJECT_STATE.md`: this file.
3. `STOP_CONDITION_REPORT.md`: provenance decisions (SF-1 … SF-19).
4. `PHASE1_5_REPORT.md` §9–10 and `tools/frozen/README.md`: regression
   policy.
5. `RELEASE_CANDIDATE_0.1.0.md` (release record), `PHASE5_REPORT.md`,
   `PHASE4_REPORT.md`, `PHASE3_REPORT.md`, then
   `PHASE2_REPORT.md`: current API and decisions.
6. `PACKAGE_PLAN.md`: original architecture and remaining scope, with the
   amendments recorded in the later reports.
7. `RELEASE_CHECKLIST.md`: release requirements.
