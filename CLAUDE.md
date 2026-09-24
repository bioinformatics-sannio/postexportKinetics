# CLAUDE.md

## Mission

Engineer the reusable `postexportKinetics` R package from the finalized manuscript implementation. The science is finalized. Package, modularize, document, and test it without silently redesigning it.

## Source of truth

Read-only manuscript repository:

`~/postexport-kinetics`

Authoritative tag:

`manuscript-revision-v1.0`

Never modify that repository. All development occurs only in `postexportKinetics`.

## Authoritative sources

Trace dependencies from the frozen tag. Principal sources include:

- `commons/nested_test2.r`
- `ode_model/ode.r`
- `synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R`
- `synthetic_dataset/run_benchmark_main_corrected_onset_revision.R`
- `synthetic_dataset/analyze_benchmark_corrected_onset_final.R`
- `synthetic_dataset/run_benchmark_pseudoshutoff_revision.R`
- `synthetic_dataset/run_pseudoshutoff_misspecification_benchmark.R`
- `synthetic_dataset/run_fraction_separation_robustness_benchmark.R`
- `synthetic_dataset/run_cytoplasmic_only_baseline.R`
- `synthetic_dataset/analyze_three_way_AUPR.R`
- `synthetic_dataset/analyze_composite_score_ablation.R`
- `synthetic_dataset/analyze_practical_identifiability.R`
- `synthetic_dataset/analyze_CN_vs_exact_transition.R`
- `synthetic_dataset/run_GSE256335_matched_corrected_onset_benchmark.R`
- `synthetic_dataset/analyze_GSE256335_effect_size_power.R`
- `real_datasets/run_real_datasets_revision.R`
- `real_datasets/run_mESC_20k.R`
- `real_datasets/audit_final_real_data.R`

Historical similarly named scripts may be superseded.

## Scientific invariance

Do not change without explicit approval:

- ODE/state definitions;
- `sigma_c` interpretation;
- transcriptional onset and intervention semantics;
- interval-balance / trapezoidal construction;
- parameter order or constraints;
- full/null definitions;
- NNLS fitting and weighting;
- covariance propagation, shrinkage, regularization, eigenvalue floor;
- test statistic and boundary handling;
- generative bootstrap and reconstruction semantics;
- add-one p-value;
- RNG/seed semantics;
- simulation ranges and assay/noise models;
- composite score;
- multiple-testing procedure.

If a possible scientific bug or inconsistency is found: stop, document exact source and impact, propose a change, and wait for approval.

## Interpretation

`sigma_c` is a phenomenological post-export conversion parameter. Statistical support does not establish cytoplasmic splicing or a unique molecular mechanism.

Use language such as "post-export conversion", "additional post-export conversion component", and "kinetic patterns consistent with post-export processing".

## Regression-first rule

Before refactoring a scientific component:

1. identify the exact frozen implementation;
2. identify inputs/outputs;
3. create a deterministic small fixture;
4. run the frozen implementation;
5. record expected numerical outputs;
6. implement the package version;
7. compare against the frozen reference;
8. justify numerical tolerances.

Never change expected values merely to make tests pass.

Minimum regression coverage: ODE propagation; corrected onset; common intervention; interval balances; full NNLS; `sigma_c=0` null; test statistic; relative RSS improvement; covariance estimation/propagation/regularization; boundary behavior; add-one p-value; fixed-seed reproducibility; one null and one alternative synthetic example; key coefficient agreement.

Do not run the complete benchmark in package tests.

## FIRST TASK — AUDIT ONLY

Before writing implementation code, inspect the frozen repository and create only:

`PACKAGE_PLAN.md`

in `postexportKinetics`.

The plan must contain:

1. **Dependency map** for ODE simulation, onset/intervention, interval balances, covariance, full/null fits, statistic, bootstrap, p-value, boundary handling, diagnostics, RNG, and assay simulation.
2. **Source mapping** from every proposed package function to exact frozen source file/function/code block.
3. **Compact public API** proposal. Candidate concepts include `fit_postexport_model()`, `test_postexport_conversion()`, `build_interval_balance()`, `simulate_postexport_kinetics()`, and `rank_postexport_candidates()`.
4. **Internal API** helpers.
5. **Dependencies**, with justification.
6. **Risks**: globals, hard-coded paths, duplicate implementations, hidden dependencies, platform assumptions, parallel/RNG behavior, mixed plotting/computation, manuscript-only code.
7. **Regression strategy** with exact fixtures and comparisons.

Do **not** implement package code until `PACKAGE_PLAN.md` is reviewed and explicitly approved.

## Target package

Package: `postexportKinetics`

Target structure:

- `DESCRIPTION`
- `NAMESPACE`
- `R/`
- `man/`
- `tests/testthat/`
- `vignettes/`
- `inst/extdata/`
- `README.md`
- `NEWS.md`
- `CITATION.cff`
- `LICENSE`

Use roxygen2.

## Boundaries

Expose reusable scientific operations, not manuscript workflows. Do not package full RNA-seq datasets, full benchmark outputs, checkpoints, manuscript PDFs, intermediate figures, primer-design workflows, third-party software, genome indexes, or large references. Small synthetic fixtures are appropriate.

## Results/API

Where supported by the frozen implementation, primary results should expose full/null coefficients, `sigma_c`, RSS values, relative RSS improvement, observed statistic, bootstrap p-value, diagnostics, boundary information, and RNG metadata.

An S3 class with `print()` and `summary()` is encouraged only if behavior is unchanged.

## Bioconductor target

Prepare for eventual Bioconductor submission. Iteratively run `R CMD build`, `R CMD check --as-cran`, and `BiocCheck::BiocCheck()` when available. Do not suppress legitimate checks. Minimize dependencies, prefer `Imports`, avoid network access in tests/examples/vignettes, and keep examples fast.

## Vignette

Use a small synthetic dataset. Explain the four-state model, cautious `sigma_c` interpretation, data formatting, full/null fitting, bootstrap comparison, diagnostics, boundary behavior, and exploratory ranking where appropriate.

## Release metadata

Create `CITATION.cff` without inventing DOI, ORCID, publication, or Bioconductor acceptance information. Create `RELEASE_CHECKLIST.md` covering regression validation, R checks, BiocCheck, versioning, GitHub release, Zenodo DOI, manuscript Availability update, and Bioconductor submission.

## Manuscript validation

Create a lightweight `tools/validate_against_manuscript.R` using small frozen fixtures. Do not rerun the full benchmark.

## Git discipline

Make small logical commits. Never rewrite manuscript-repository history. Before a commit that could affect science, summarize files/functions affected, regression tests, and whether outputs changed.

## Stop conditions

Stop for human review if regression outputs differ unexpectedly, source authority is ambiguous, the frozen implementation appears inconsistent, dependencies cannot be traced, scientific behavior must change for compliance, or tolerances cannot be justified.

Scientific equivalence takes priority over code elegance.

## First deliverable

The first deliverable is **only `PACKAGE_PLAN.md`**. Do not create package implementation code before approval.
