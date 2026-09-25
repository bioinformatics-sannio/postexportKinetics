# Release checklist — postexportKinetics

Items are completed for every release. Status column is filled in at release
time; nothing below is claimed as done until it has been run.

## 1. Frozen-reference regression validation

- [ ] Frozen export verified: tag `manuscript-revision-v1.0` resolves to
      `65c3b7368fb7686bfde3dab857f98c393bb534c5`
      (`tools/frozen/export_frozen.sh`).
- [ ] Fixtures regenerated only by `tools/frozen/make_fixtures.R`; any change
      in fixture values reported and reviewed (never edited by hand).
- [ ] `tests/testthat` pass, including verbatim-port checks.
- [ ] `tools/frozen/compare_report.R` run; identity / maximum differences
      recorded in the release notes.
- [ ] **Level A (same-platform, strict, blocking):** package vs frozen on the
      fixture platform, and on Linux CI against frozen outputs recomputed
      from the committed inputs (`tools/frozen/recompute_fixtures.R`).
      This includes bootstrap draws and add-one p-values.
- [ ] **Level B (cross-platform scientific, scale-aware, blocking):**
      committed fixtures checked on Linux (tests and `R CMD check`) and
      `tools/frozen/compare_fixtures.R`. Coefficients, `sigma_c`, RSS, IR, T,
      ranks, boundary classification, mESC targets, Ppp1r36dn/Nsd1 all pass.
- [ ] **Level C (reported, not blocking):** cross-platform differences of the
      extreme-conditioning fixtures and of bootstrap draws reviewed in the CI
      annotations; none changes a boundary decision
      (`tools/frozen/README.md`).
- [ ] `Rscript tools/validate_against_manuscript.R` (full, not `--quick`)
      run on the release commit; overall status `EQUIVALENT`; output kept
      with the release notes.
- [ ] Release notes state the reproducibility guarantees:
      - scientific equivalence with the frozen algorithm;
      - bitwise reproducibility only within a matched numerical environment;
      - Monte-Carlo (bootstrap-draw) reproducibility under a fixed seed only
        within a matched numerical environment, because `MASS::mvrnorm()`
        depends on LAPACK/BLAS.

### Known provenance discrepancies of the frozen tag (record, do not "fix")

1. **Pseudo-shutoff real-data bootstrap size (SF-1).**
   `real_datasets/run_real_datasets_revision.R:146` declares `N_BOOT <- 1999`,
   but the deposited Kc167, K562 and NIH-3T3 results
   (`real_datasets/S5testresults_final.xlsx`, `final_real_data_audit/*.tsv`)
   are proven incompatible with B = 1999 and are treated, by author decision,
   as originating from a **B = 4999** final run (evidence:
   `STOP_CONDITION_REPORT.md` §1). Consequences for validation:
   - `sigma_c`, IR, boundary and tested-event counts do not depend on B and
     are exact validation targets;
   - p/q-values of these datasets are compared with B = 4999 and only as
     Monte-Carlo (tier T4) comparisons;
   - the final mESC analysis (`real_datasets/run_mESC_20k.R`) used
     **B = 19999**, consistent with the script;
   - the package default remains **B = 1999** (core function default and
     factorial benchmark).
2. **Corrected-onset generator RNG (SF-2).** The `.Random.seed` "restore" at
   `synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R:429` is a
   function-local assignment and has no effect; replicate-level parameter
   draws come from the `2000000 + gene_id` stream. Regression fixtures
   reproduce this actual behaviour.
3. **Pseudo-shutoff benchmark authority (SF-4).**
   `run_pseudoshutoff_misspecification_benchmark.R` is authoritative;
   `run_benchmark_pseudoshutoff_revision.R` is superseded and is not a
   regression source.

## 2. R checks

- [ ] Vignette builds (`R CMD build`; requires pandoc) with no network
      access and within the check time budget.
- [ ] Examples run fast and use small `B` only with an explicit comment.
- [ ] `R CMD build`
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings; every NOTE explained.
- [ ] Checks on at least macOS and Linux (and Windows before Bioconductor
      submission).

## 3. BiocCheck

- [ ] `BiocCheck::BiocCheck()` — no ERRORs; WARNINGs addressed; NOTEs
      explained. Legitimate checks are not suppressed.

## 3a. Continuous integration

- [ ] Linux CI (`.github/workflows/linux-regression.yml`) green on the
      release commit: package job, frozen-reference job and the quick
      manuscript-validation step.
- [ ] Runner image checked. GitHub announced that `ubuntu-latest` migrates
      to Ubuntu 26 from 2026-10-19. CI stays on `ubuntu-latest` unless a
      concrete compatibility problem appears. After the migration, confirm
      that the levels A/B/C results are unchanged, and record the new
      platform provenance (LAPACK/BLAS) of the frozen-reference job.

## 4. Versioning

- [ ] Version: first public GitHub release `0.1.0` (decided); the
      Bioconductor submission line `0.99.x` comes later and is not used
      for the GitHub release.
- [ ] Declared minimum R version (`R (>= 4.1.0)`, provisional) verified by
      a compatibility CI job on at least one older supported R release. If
      a concrete incompatibility is found, report it before changing
      `DESCRIPTION`.
- [ ] `NEWS.md` updated (created in Phase 5).
- [ ] `CITATION.cff` and `inst/CITATION` versions match `DESCRIPTION`; no
      package DOI is added before one is minted.
- [ ] Frozen tag and commit recorded in `NEWS.md` and package documentation.

## 5. GitHub release

- [ ] Tagged release in the package repository.
- [ ] Release notes include regression summary and known provenance
      discrepancies (section 1).

## 6. Zenodo DOI

- [ ] Package release archived on Zenodo; DOI recorded in `CITATION.cff` only
      after it has been minted. The manuscript implementation archive DOI
      (10.5281/zenodo.22944109) is cited as the frozen scientific reference,
      not as the package DOI.

## 7. Manuscript Availability update

- [ ] Manuscript Availability section updated with package repository and
      DOI once they exist (author action).

## 8. Bioconductor submission

- [ ] Bioconductor requirements re-checked at submission time (vignette,
      examples without network access, runtime, package size, biocViews).
- [ ] Submission opened; no acceptance is claimed before it happens.
