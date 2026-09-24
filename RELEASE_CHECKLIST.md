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
- [ ] Bootstrap-draw comparisons run on the fixture platform (they are skipped
      on other LAPACK/BLAS builds; see `PACKAGE_PLAN.md` §9.2).
- [ ] `tools/validate_against_manuscript.R` run (from Phase 5 onward).

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

- [ ] `R CMD build`
- [ ] `R CMD check --as-cran` — 0 errors, 0 warnings; every NOTE explained.
- [ ] Checks on at least macOS and Linux (and Windows before Bioconductor
      submission).

## 3. BiocCheck

- [ ] `BiocCheck::BiocCheck()` — no ERRORs; WARNINGs addressed; NOTEs
      explained. Legitimate checks are not suppressed.

## 4. Versioning

- [ ] Version number decided (development `0.0.0.9000`; release target
      `0.1.0`; Bioconductor submission convention `0.99.x` — decision pending).
- [ ] `NEWS.md` updated.
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
