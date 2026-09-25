# Phase 6A/6B report: Bioconductor preparation (mandatory changes and minimal interoperability)

Status: **Phase 6A and the approved minimal Phase 6B are implemented on
branch `bioconductor-prep`; stopped for review.** Not done:

- no default-branch switch;
- no Bioconductor Contributions issue;
- no new release or tag, and `v0.1.0` untouched;
- no Layout B, rMATS or BiocStyle;
- no frozen code refactored.

**Baselines:**

- `main` @ `de5f722`. The package content equals the released `v0.1.0`
  (`04c4407`).
- Frozen reference: `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`, unchanged.
- **No frozen port, fixture, `R/sysdata.rda`, `data/` or `inst/extdata`
  file changed.** `git diff main` is empty for all of them. The only
  non-documentation change to existing R code is the approved
  `stop()` rewrite in `R/simulate.R`.

## 1. Commits

| Commit | Content | Local gates |
|---|---|---|
| `da1285a` | `BIOCONDUCTOR_AUDIT.md` (Stop Point 0) | audit run |
| `d9e19ee` | build hygiene: `^BIOCONDUCTOR_AUDIT\.md$`; report pattern widened to `^PHASE[0-9A-Za-z_]+_REPORT\.md$`; inspector updated | tests 3,677 ✓; check 2 NOTEs; validation EQUIVALENT (BiocCheck: see §8, bioconductor.org outage) |
| `fe0c549` | **version 0.99.0** | 3,677 ✓; 2 NOTEs; BiocCheck 1E/2W/10N; EQUIVALENT |
| `c89c0d7` | vignette "Introduction" and "Installation" | 3,677 ✓; 2 NOTEs; 1E/2W/10N; EQUIVALENT |
| `8df5cd8` | **`postexport_data_from_se()`**, SummarizedExperiment in Imports, tests, vignette section | 3,705 ✓; 2 NOTEs; **1E/1W/10N**; EQUIVALENT |
| `83de17e` | package-authored paste fix in `R/simulate.R` and message regression test | 3,708 ✓; 2 NOTEs; 1E/1W/10N; EQUIVALENT |
| `ca851ad` | `inst/scripts/generate_postexport_example.R` (provenance) | 3,708 ✓; 2 NOTEs; 1E/1W/10N; EQUIVALENT |
| `3018d53` | reviewer justifications (`set.seed`, frozen style) and maintainer-action status | documentation |
| `b2a555c`, `b126cc8` | r-compat: failure-only dependency diagnosis (CI) | CI only |
| `cae1f4d` | r-compat: Bioconductor 3.14 dependencies for the R 4.1 job (CI environment) | CI only |
| this commit | `PHASE6_AB_REPORT.md` | documentation |

"Local gates" means: testthat; `R CMD build` / `R CMD check --as-cran` on a
clean `git archive`; BiocCheck; full `tools/validate_against_manuscript.R`.
All ran on macOS arm64 with R 4.6.0.

## 2. Version transition

`0.1.0` → **`0.99.0`** in `DESCRIPTION`, `CITATION.cff` and NEWS (new
`# postexportKinetics 0.99.0` entry: "Bioconductor submission development
line"). The README release status and package help now say:

- the released version is 0.1.0 (tag `v0.1.0`, unchanged);
- 0.99.x is the Bioconductor submission line;
- the package is not yet a Bioconductor release.

`inst/CITATION` follows `meta$Version`. There is no package DOI:
`tools/ci/citation_audit.R` reports "CITATION AUDIT PASSED (version 0.99.0,
no package DOI)". `10.5281/zenodo.22944109` stays labelled as the frozen
manuscript implementation DOI. `PROJECT_STATE.md` is updated.

## 3. Vignette changes (structure only)

- "Overview" is renamed to "**Introduction**".
- New "**Installation**" section:
  - `BiocManager::install("postexportKinetics")` with `eval = FALSE`,
    stated to apply only after Bioconductor acceptance;
  - the current GitHub routes (`@v0.1.0` and the development line), also
    `eval = FALSE`;
  - then `library(postexportKinetics)`.
- New short "**SummarizedExperiment input**" section (§5).
- The data-source sentence now points to the shipped provenance script.
- Otherwise unchanged. `rmarkdown::html_vignette` is kept; no BiocStyle.

## 4. SummarizedExperiment API and mapping

```r
postexport_data_from_se(se, time_unit,
                        assays = c(N = "N", N_s = "N_s", C = "C", C_s = "C_s"),
                        time = "time", replicate = "replicate")
```

**Layout A:**

| Input | Mapping |
|---|---|
| rows | events: `event = rownames(se)` |
| columns | destructive samples |
| `colData(se)[[time]]` | `time` |
| `colData(se)[[replicate]]` | `replicate` |
| `assay(se, assays[["N"]])` … | `N`, `N_s`, `C`, `C_s` |

- Each (event, sample) cell becomes one wide row, ordered by event and then
  by sample.
- The wide table is passed to **`postexport_data()`**, so all data
  validation is delegated to it and to `validate_postexport_data()`. The
  result is exactly a normal `postexport_data` object.
- **Errors:**
  - non-SummarizedExperiment input (subclasses are accepted);
  - missing, empty or duplicated rownames;
  - `assays` not naming exactly `N`, `N_s`, `C`, `C_s`;
  - assays absent from `se`;
  - `time` / `replicate` not in `colData`;
  - non-numeric assays;
  - assay dimensions differing from `dim(se)`;
  - zero events or zero samples;
  - missing values, via the existing package rule. They are never
    zero-filled.
- **Never:** pairing fraction libraries, normalisation, rMATS conversion,
  inclusion/skipping inference, Layout B. There is no
  `as_summarized_experiment()`.

## 5. Dependency changes

- `Imports` gains **SummarizedExperiment**, with
  `importFrom(SummarizedExperiment, assay, assayNames, colData)`. No other
  dependency was added.
- **BiocCheck:** the WARNING "No Bioconductor dependencies detected"
  **disappeared** from `8df5cd8` on ("Checking for Bioconductor software
  dependencies... OK").
- **R 4.1 compatibility:** R 4.1 maps to Bioconductor 3.14, which has
  SummarizedExperiment 1.24.0.
  - pak could not resolve it ("Can't find package called
    SummarizedExperiment").
  - A BiocManager source install first failed at RCurl because the runner
    lacks the libcurl headers.
  - Both are **category A, ecosystem/environment** failures, not package
    incompatibilities.
  - With the CI fix (`cae1f4d`: install `libcurl4-openssl-dev` and install
    SummarizedExperiment via BiocManager for the R 4.1 job only), the
    **R 4.1.3 job passes the full regression suite and `R CMD check
    --as-cran`** with Bioconductor 3.14 and SummarizedExperiment 1.24.0.
  - `Depends: R (>= 4.1.0)` is unchanged and remains supported by evidence.
- The oldrel-1 job (R 4.5.3) reports dependency-load warnings inside
  Bioconductor ("replacing previous import
  'S4Arrays::makeNindexFromArrayViewport' by 'DelayedArray::…' when loading
  'SummarizedExperiment'"). These come from a version mix between
  Bioconductor packages, not from postexportKinetics, and the job is green.

## 6. Interoperability tests and identity proof

`tests/testthat/test-se.R`, 28 expectations:

- **Exact conversion** of the shipped `postexport_example` (built as a
  Layout-A SummarizedExperiment): `expect_identical()` with
  `postexport_data(postexport_example, time_unit = "min")`, also for a
  `RangedSummarizedExperiment`.
- **Custom assay names** (in any order) and custom `colData` names
  (`minutes`, `rep`): identical to canonical.
- **Errors:** missing assays; missing or duplicated rownames; missing
  `time` / `replicate` columns; malformed `assays`; non-SE input; missing
  `time_unit`; non-numeric assay; NA in an assay and NA in `colData$time`
  (errors, not zero-filled).
- **Dimensions:** SummarizedExperiment refuses assays of incompatible
  dimensions; zero-row and zero-column objects are rejected; a 2 × 10
  subset gives 20 rows.
- **Identity of downstream results**, canonical input versus SE-derived
  input:
  - `validate_postexport_data()` results are identical;
  - the attached validation object is identical;
  - **`fit_postexport_model()` is identical for all 8 events**;
  - **`test_postexport_conversion()` is identical** (B = 19, fixed
    per-event seeds, 2 events), both the whole result and each `$raw`.
- **Mutation checks:**
  - zero-filling NA in the converter: 1 failure;
  - column-major instead of event-major ordering: 8 failures.

The scientific core is untouched.

## 7. Package-authored paste fix

`R/simulate.R` now builds the parameter-name error from the message
pieces passed directly to `stop()`, instead of `stop(sprintf(paste0(...)))`.

- **The user-visible message is byte-identical.** A new test in
  `test-simulation.R` asserts the exact text for three cases (missing name,
  unknown name, duplicated name). It passed before and after the change,
  and a one-character mutation of the message fails it.
- BiocCheck's paste finding now lists only the **5 frozen sites**
  (`assay.R:268`, `bootstrap.R:64`, `covariance.R:129, 244, 329`), which are
  unchanged.

## 8. Data-provenance script

`inst/scripts/generate_postexport_example.R` is shipped:

- It defines `generate_postexport_example()` (the validated simulator only;
  no frozen repository inputs, no local paths) and
  `write_postexport_example(out_dir)`.
- Run as a script, it writes to an explicit directory or a temporary one,
  never into the installed package. The caller's RNG state is restored
  (tested).
- **It reproduces the distributed `data/postexport_example.rda`,
  `data/postexport_example_truth.rda` and
  `inst/extdata/postexport_example_long.csv` byte-for-byte** (identical
  MD5s) on the generating platform. Elsewhere, differences are possible at
  the level of ODE rounding, as documented.
- `data-raw/postexport_example.R` is now a thin maintainer wrapper. The
  dataset help and the vignette point to the shipped script.
- No benchmark infrastructure is shipped. `data-raw/benchmark_domain.R`
  stays build-ignored; `R/sysdata.rda` provenance is documented.

## 9. Current R CMD check and BiocCheck

**`R CMD check --as-cran`** (final package content, clean archive):
**0 ERRORs, 0 WARNINGs, 2 NOTEs**, both unchanged:

- CRAN incoming feasibility: new submission;
- HTML-manual validation skipped: old local HTML Tidy, no V8.

**BiocCheck 1.48.1** (full, networked, including the deprecated-package
check, run once bioconductor.org was reachable again): **1 ERROR,
1 WARNING, 10 NOTEs**.

**Findings that disappeared** (compared with the audit's 1E/2W/10N):

- WARNING: no Bioconductor dependencies. Resolved by SummarizedExperiment
  in Imports.
- The Support Site part of the ERROR changed. BiocCheck now reports
  "**Maintainer is registered at support site**". The remaining ERROR is
  "Add package to Watched Tags in your Support Site profile" (maintainer
  action).
- The package-authored `simulate.R` site left the paste NOTE.

**Findings that remain, and why:**

| Finding | Class | Reason |
|---|---|---|
| ERROR: add the package to Watched Tags | D | maintainer action (§11) |
| WARNING: `set.seed` ×2 (`inference.R:89` frozen; `simulate.R:371` explicit user seed) | E / C | justified in `BIOCONDUCTOR_AUDIT.md` §10a; not changed, by decision |
| NOTE: R version 4.1.0 → 4.6.0 | C | kept by decision; CI-verified on R 4.1.3 |
| NOTE: ORCID; `fnd` role | D (voluntary) | only if supplied by the authors |
| NOTE: `=` (frozen `assay.R`); paste in conditions (5 frozen); `<<-` (frozen) | E | verbatim frozen ports |
| NOTE: 26 functions > 50 lines (13 frozen; 13 package-authored, now including `postexport_data_from_se`, whose length is mostly argument checks) | E / C | no refactoring, by decision |
| NOTE: 6 lines > 80 characters (frozen `ode.R`) | E | frozen |
| NOTE: indentation, 1,686 lines (frozen ports and argument-alignment continuation lines) | E / C | no styler pass, by decision |
| NOTE: bioc-devel subscription undeterminable | D | maintainer action |

**Tool incident:** during the first gate, bioconductor.org timed out, and
BiocCheck's deprecated-status cache lookup crashed ("missing value where
TRUE/FALSE needed" in `get_status_file_cache`). Per-commit gates therefore
used `no-check-deprecated = TRUE`. The final networked run with all checks
gives the result above.

## 10. Full manuscript validation and CI

**Full manuscript validation:** **EQUIVALENT** (10/10 PASS) after every
package commit (`d9e19ee` … `ca851ad`), on macOS arm64 with R 4.6.0:

- same-platform level A, including bootstrap draws;
- Ppp1r36dn and Nsd1 relative differences ≤ 6.7e-15;
- 28 mESC events ≤ 5.6e-13;
- frozen repository unchanged.

**Test suite:** 17 files, **3,708 expectations, 0 failures**.

**CI on `bioconductor-prep`:**

| Commit | linux-regression (scientific gate) | platforms (macOS, Windows) | r-compat (R 4.1.3, R 4.5.3) |
|---|---|---|---|
| `da1285a` | ✓ `36150887585` | ✓ `36150887677` | ✓ `36150887640` |
| `d9e19ee` | ✓ `36156215798` | ✓ `36156215643` | ✓ `36156215663` |
| `fe0c549` | ✓ `36156798613` | ✓ `36156798711` | ✓ `36156798792` |
| `c89c0d7` | ✓ `36157296145` | ✓ `36157296134` | ✓ `36157296176` |
| `8df5cd8` | ✓ `36158357868` | ✓ `36158357816` | ✗ `36158357770` (R 4.1 dependency install; oldrel-1 ✓) |
| `83de17e` | ✓ `36159146106` | ✓ `36159146350` | ✗ `36159146116` (same) |
| `ca851ad` | ✓ `36160038067` | ✓ `36160038035` | ✗ `36160038003` (same) |
| `3018d53` | ✓ `36160119819` | ✓ `36160120270` | ✗ `36160119787` (same) |
| `b2a555c`, `b126cc8` | — | — | ✗ diagnostic runs `36160920384`, `36164232513` (cause captured) |
| **`cae1f4d`** | **✓ `36165544168`** | **✓ `36165544397`** | **✓ `36165544314`** (R 4.1.3 with Bioconductor 3.14 / SummarizedExperiment 1.24.0; R 4.5.3) |

- **Final state (`cae1f4d`):** every workflow is green, including macOS,
  Windows and R 4.1 compatibility.
- The linux-regression and platforms results for `b2a555c` and `b126cc8`
  were not re-queried: the GitHub API rate limit was reached, and those
  commits are CI-only.
- The CI of this report commit is reported in the review message.

## 11. Maintainer-action checklist (not performed by Claude)

| Action | Status |
|---|---|
| Bioconductor Support Site registration (`lcerulo@unisannio.it`) | **done** (BiocCheck: "Maintainer is registered at support site") |
| Add `postexportKinetics` to **Watched Tags** (https://support.bioconductor.org/accounts/edit/profile) | **pending**; this is the remaining BiocCheck ERROR |
| bioc-devel mailing-list subscription | pending (not determinable by BiocCheck) |
| GitHub SSH public key on the maintainer account | pending |
| Package-only default branch switch (policy P1) | later (Phase 6C/6D); **not done** |
| ORCID / funder metadata | optional; only if supplied by the authors |
| Open the Bioconductor Contributions issue | only after 6C/6D and explicit approval |

## 12. Proposed package-only branch generation (policy P1, Phase 6C/6D)

**Goal:** a GitHub default branch that contains only package-distribution
content, while all development, CI, tools, reports and the scientific
regression infrastructure stay on the development branch.

**Design:**

1. **Branches.**
   - The development branch is the current `main`, or `bioconductor-prep`
     merged into it.
   - A package-only branch `devel` follows Bioconductor naming. It becomes
     the default branch only at submission time.
2. **Allowlist export.** A script `tools/release/make_package_branch.sh`
   (on the development branch only) takes a development commit `X`. It
   exports with `git archive X` and keeps only an allowlist:
   - `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `NEWS.md`, `README.md`;
   - `R/`, `man/`, `data/`, `inst/`, `vignettes/`, `tests/` (with
     fixtures);
   - `.Rbuildignore` (pruned to the remaining entries) and `.gitignore`.
   - `CITATION.cff` is optional and still to be decided.
   - Everything else is excluded: `.github/`, `tools/`, `data-raw/`,
     `CLAUDE.md`, the phase reports, `PACKAGE_PLAN.md`,
     `STOP_CONDITION_REPORT.md`, `PROJECT_STATE.md`, `RELEASE_*`,
     `BIOCONDUCTOR_AUDIT.md`.
3. **Commit.** The script commits the tree onto `devel` as a normal
   (non-force) commit, with the message "package-only export of <X>" and a
   trailer `Source-Commit: <full SHA of X>`. The history of `devel` is linear
   and never rewritten.
4. **Verification, run by CI on the development branch.** Rebuild the
   export and check:
   - (i) it is identical to the tip of `devel`;
   - (ii) `R CMD build` of `devel` and of `X` give the same file list and
     identical file contents, except the `Packaged:` line;
   - (iii) `BiocCheckGitClone()` on `devel` gives 0/0/0;
   - (iv) `tools/ci/inspect_tarball.R` passes.
5. **CI location.** No workflows live on `devel`. The scientific gate
   (linux-regression), r-compat, platforms and release machinery keep
   running on the development branch. The regression gate is never removed.
6. **Default-branch switch** (maintainer action, GitHub settings), just
   before opening the Contributions issue. After acceptance, updates are
   pushed from `devel` to git.bioconductor.org by the maintainer's SSH key.
7. **Not yet implemented.** It requires approval (Phase 6C/6D).

## 13. Next steps (not started)

- **6C:** the maintainer actions in §11; implement and approve the P1
  export script.
- **6D:**
  - a Bioconductor-devel CI job (`R CMD check` and BiocCheck in the devel
    container);
  - `BiocCheckGitClone` on the package-only branch;
  - the Node.js 20 action bump;
  - re-confirm the scientific gate after the Ubuntu 26 migration;
  - full validation;
  - final readiness review;
  - the submission issue, only on explicit approval.
