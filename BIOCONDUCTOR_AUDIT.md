# Bioconductor audit (Phase 6, Stop Point 0)

Status: **read-only audit; stopped for review.** Nothing in the package was
changed:

- no change to package code, `DESCRIPTION`, version, vignette, tests,
  workflows or `.Rbuildignore`;
- no account actions;
- no submission.

**Baselines:**

- **Audited state:** branch `bioconductor-prep` from `main` @ `de5f722`.
  The package content is identical to the released **v0.1.0** (release
  merge `04c4407`); `de5f722` only adds release documentation, which is
  build-ignored.
- **v0.1.0 is immutable.** Tag `v0.1.0` → `04c4407`; released tarball
  SHA256 `dd6979ff48a49c5ce5118e3990abb5b74ebdf2264a5728e22662d6ba87f18eda`.
  There is no package DOI.
- **Frozen reference:** `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`. The frozen implementation's
  DOI is `10.5281/zenodo.22944109`; it is not the package's.
- **Main CI on `de5f722`:** release-candidate `36145161887`,
  linux-regression `36145162298`, platforms `36145162673` and r-compat
  `36145161899`, all green.

**Sources of Bioconductor requirements** (read 2026-09-25):

- contributions.bioconductor.org: DESCRIPTION, general development, R
  code, documentation/vignettes, NEWS, CITATION, data, reuse of Bioconductor
  classes, git/gitignore;
- the Bioconductor/Contributions README.

---

## 1. Current results (source of truth)

All runs are on a clean `git archive` of `de5f722`, on macOS arm64 with
R 4.6.0 (BiocManager 3.23), pandoc 3.11 from a scratch directory, and
`caffeinate` to prevent sleep.

| Check | Result |
|---|---|
| `R CMD build` | OK, vignette built; tarball `postexportKinetics_0.1.0.tar.gz`, **992 kB** (limit 10 MB; largest file 347 kB, limit 5 MB) |
| `R CMD check --as-cran` (with manual) | **0 ERRORs, 0 WARNINGs, 2 NOTEs**: CRAN incoming feasibility (new submission), and HTML-manual validation skipped because of old local HTML Tidy / no V8 (environment). Tests 34 s, vignette re-build 13 s; far under the 10-minute limit. |
| `BiocCheck::BiocCheck()` 1.48.1 on the tarball | **1 ERROR, 2 WARNINGs, 10 NOTEs** (§2) |
| `BiocCheck::BiocCheckGitClone()` on a fresh clone of `main` | **0 ERRORs, 0 WARNINGs, 0 NOTEs** |
| Regression suite (testthat) | 16 files, **3,677 expectations, 0 failures / errors / warnings / skips** |
| Full `tools/validate_against_manuscript.R` | **EQUIVALENT**: 10/10 PASS, including same-platform level A with bootstrap draws; frozen repository unchanged |
| Linux / macOS / Windows / R 4.1.3 / R 4.5.3 CI | green (main runs above) |

---

## 2. BiocCheck findings and classification

Classes:

- **A.** Must fix before submission.
- **B.** Should fix.
- **C.** Acceptable / justified.
- **D.** External maintainer action.
- **E.** Frozen-code finding, not to be changed for style.

"Frozen ports" are `R/constants.R`, `matrix-utils.R`, `covariance.R`,
`interval-balance.R`, `fit.R`, `crank-nicolson.R`, `bootstrap.R`,
`inference.R`, `ode.R` and `assay.R`. They are verbatim ports enforced by
`test-verbatim-port.R`. All other `R/` files are package-authored.

| # | Level | Check | Finding (current output) | Location | Class | Rationale / proposed handling |
|---|---|---|---|---|---|---|
| 1 | ERROR | `checkSupportReg` | "Unable to find your email in the Support Site: HTTP 404 Not Found." | maintainer `lcerulo@unisannio.it` | **D** | The maintainer must register on support.bioconductor.org with the DESCRIPTION email. Not a code issue. |
| 2 | WARNING | `checkBiocDepsDESC` | "No Bioconductor dependencies detected … consider a CRAN submission." Only Depends/Imports are counted (BiocCheck source). | DESCRIPTION | **B**, decision-linked to §4 | Resolved only by a *genuine* Bioconductor Import. See §4: a Layout-A SummarizedExperiment converter would justify `SummarizedExperiment` in Imports. No dependency is added merely to silence the check. |
| 3a | WARNING | `checkCodingPractice` | `set.seed()` in `R/inference.R` line 89 | frozen orchestrator (`test_sigma_nested`) | **E** | Frozen RNG semantics (manuscript reproducibility, SF-2/RNG decisions). The public API sets it only when the user passes `seed`, and restores the caller's RNG state afterwards. Not changed; justify to reviewers. |
| 3b | WARNING | `checkCodingPractice` | `set.seed()` in `R/simulate.R` line 371 | package-authored `simulate_postexport_kinetics()` | **C** (reviewer risk) | Called only when the user supplies `seed =`, and the caller's `.Random.seed` is restored (documented, tested). Bioconductor says "Do not use `set.seed()` in any internal code". This is a user-requested seed in an exported function, part of the 0.1.0 API. Removing the argument would break the API. Justify; option: document that `seed = NULL` plus a caller-side `set.seed()` is the idiomatic alternative. |
| 4 | NOTE | `checkRVersionDependency` | "Update R version dependency from 4.1.0 to 4.6.0" | DESCRIPTION | **C** | `R (>= 4.1.0)` is backed by CI on R 4.1.3. Bioconductor builds only on its current R, so raising the minimum is optional and would be a policy choice, not a necessity. |
| 5 | NOTE | `checkBBScompatibility` | "Consider adding the maintainer's ORCID iD" | Authors@R | **D** (voluntary) | Add only if the authors supply their ORCIDs; never invented. |
| 6 | NOTE | `checkFndPerson` | "No 'fnd' role found … If the work is supported by a grant" | Authors@R | **D** (voluntary) | Only if the authors want to credit a funder (name supplied by them). |
| 7 | NOTE | `checkCodingPractice` | "Avoid using '=' for assignment" | `R/assay.R` line 74 (`disp = …`) | **E** | Frozen port, verbatim. |
| 8 | NOTE | `checkCodingPractice` | "Avoid the use of 'paste' in condition signals" (6 sites) | 5 frozen: `assay.R:268`, `bootstrap.R:64`, `covariance.R:129, 244, 329`; 1 package-authored: `simulate.R:248` | **E** (5) / **B** (1) | Package site: `stop(sprintf(paste0(...)))`, which could build the format string outside the signal. A message-text-only change, with no behaviour change (6A item, optional). |
| 9 | NOTE | `checkCodingPractice` | "Avoid '<<-' if possible (found 2 times)" | `R/inference.R` lines 123 and 254 | **E** | Frozen orchestrator error capture. |
| 10 | NOTE | `checkFunctionLengths` | 25 functions > 50 lines; longest `test_sigma_nested()` 720 | **13 frozen** (e.g. `test_sigma_nested` 720, `generate_ODE_states` 520, `build_Ab_fullcov` 310); **12 package-authored** (51–140 lines: `.validate_simulation` 140, `.domain_check_design` 108, `print.summary.postexport_fit` 93, `.new_fit` 90, `.check_wide_values` 85, `.new_test` 74, `.long_to_wide` 63, `.plot_fit_trajectories` 61, `plot.postexport_domain_check` 60, `check_operational_domain` 58, `plot.postexport_simulation` 58, `rank_postexport_candidates` 51) | **E** (frozen) / **C** (package) | The frozen ports are not refactored. Package functions are long mainly because of validation and messages; splitting them is optional and carries regression risk for no user benefit (the Phase 2 decision stands). |
| 11 | NOTE | `checkFormatting` | 6 lines > 80 characters | all in frozen `R/ode.R` (comment rulers, lines 887–939) | **E** | Frozen port. |
| 12 | NOTE | `checkFormatting` | indentation not a multiple of 4 in 21% of lines | frozen ports: 1,357 of 2,838 non-empty lines; package-authored: 264 of 3,674 (continuation lines aligned under an open parenthesis) and some vignette prose lines | **E** (frozen) / **C** (package) | The package code follows the 4-space rule for block indentation. The flagged package lines are argument alignment, which is common R style. Restyling (e.g. with `styler`) is possible but not needed. |
| 13 | NOTE | `BiocCheckRun` | "Cannot determine whether maintainer is subscribed to the Bioc-Devel mailing list" | — | **D** | The maintainer subscribes to bioc-devel. |

**Previously known findings that no longer apply:**

- the version ERROR/WARNING, gone since 0.1.0 has a valid format;
- the missing vignette (resolved in Phase 5);
- the NEWS note (resolved);
- the biocViews suggestion (resolved by `MultipleComparison`).

The `checkBBScompatibility` output now covers only the ORCID message.

---

## 3. Additional submission requirements not covered by BiocCheck

| # | Requirement (source) | Current state | Class | Proposed handling |
|---|---|---|---|---|
| R1 | Version **0.99.0** at first submission (DESCRIPTION chapter: "a package should have pre-release version `0.99.0`") | `0.1.0` | **A** | 6A, after approval. v0.1.0 stays released and immutable; 0.99.0 is the Bioconductor pre-release line. |
| R2 | **"The default branch must contain only package code. Any files or directories for other applications (Github Actions, devtool, etc) should be in a different branch."** (Contributions README) | `main` has `.github/` (CI, release machinery), `tools/`, `data-raw/`, phase reports, `PACKAGE_PLAN.md`, `STOP_CONDITION_REPORT.md`, `PROJECT_STATE.md`, `RELEASE_*.md`, `CLAUDE.md`. `BiocCheckGitClone()` does not flag them. | **A** (policy; decision needed) | See §8, option P1 (recommended): a package-only default branch at submission time, with development and CI kept on a separate branch. |
| R3 | Vignette: an **"Introduction"** section and an **"Installation"** section showing how to install from Bioconductor, with `eval = FALSE` (documentation chapter: "This is a requirement of Bioconductor package vignettes") | The vignette starts with "Overview"; there is no Installation section | **A** | 6A: rename "Overview" to "Introduction" and add "Installation" (`BiocManager::install("postexportKinetics")`, `eval = FALSE`, plus the GitHub route). No other rewrite. |
| R4 | `.Rbuildignore` must exclude this audit file; otherwise it enters the tarball (top-level NOTE) | `BIOCONDUCTOR_AUDIT.md` not ignored (not changed at Stop Point 0 by instruction) | **A** (trivial) | 6A: add `^BIOCONDUCTOR_AUDIT\.md$`. |
| R5 | Data provenance scripts "in either `inst/scripts/` (preferred) or `data-raw`" (data chapter) | `data-raw/postexport_example.R` and `data-raw/benchmark_domain.R` exist but are build-ignored | **B** | 6A/6B: copy the example-data script to `inst/scripts/`, so that it ships with the package. `R/sysdata.rda` provenance is documented, and `benchmark_domain.R` needs the frozen export; ship it too as documentation, or reference it. |
| R6 | README installation instructions | GitHub installation only | **B** | 6D, after acceptance: add BiocManager installation. Until then, keep GitHub. |
| R7 | NEWS: markdown with list elements; `checkNEWS` OK | `# postexportKinetics 0.1.0` with bullets | **B** | 6A: add a `# postexportKinetics 0.99.0` entry (Bioconductor submission) once the version changes. |
| R8 | `readCitationFile("inst/CITATION")` works without loading the package | uses `meta$Version` (standard); `readCitationFile("inst/CITATION", meta = packageDescription("postexportKinetics"))` returns 3 entries without error (verified at Stop Point 0) | **C** | Re-check in 6D. |
| R9 | Examples runnable, no `dontrun`; non-trivial evaluated vignette code | all examples run (≤ 1.1 s); the vignette evaluates 19 chunks | **C** | Keep. |
| R10 | Package not on CRAN; name unique | BiocCheck "already exists in CRAN" check passed | **C** | Re-check at submission. |
| R11 | Builds on Linux, macOS and Windows with **Bioconductor devel** | CI covers R release (4.6.1) on all three OSes and R 4.1.3 / 4.5.3; no Bioconductor-devel job | **B** | 6D: add a Bioconductor-devel check job (e.g. the `bioconductor/bioconductor_docker:devel` container) with `R CMD check` and BiocCheck. |

---

## 4. SummarizedExperiment audit (not implemented)

- **Required?** Not by BiocCheck. However, the Bioconductor guidance on
  reusing classes states that "package submissions are generally not
  accepted unless they demonstrate such interoperability, typically by
  reusing existing Bioconductor classes". It also says that submissions
  introducing new data structures "must provide strong justification and
  clearly describe how they interoperate with existing Bioconductor
  infrastructure". `postexport_data` is such a structure: a validated long
  or wide data frame. The BiocCheck warning (§2 #2) says the same from the
  tooling side ("consider a CRAN submission").
- **Materially improves submission quality?** **Yes.** Assessment: without
  any Bioconductor-class interoperability, acceptance is doubtful. A thin
  Layout-A converter is the smallest credible demonstration and adds no
  biological assumptions.
- **Layout A only (approved mapping, unambiguous):**
  - rows are events; columns are destructive samples;
  - `colData(se)$time` and `colData(se)$replicate`;
  - four assays `N`, `N_s`, `C`, `C_s`;
  - `event = rownames(se)`, `time = se$time`, `replicate = se$replicate`,
    `N = assay(se, "N")`, and so on;
  - each (event, sample) cell becomes one wide-format row.
  - It does **not** pair nuclear and cytoplasmic libraries, infer
    inclusion/skipping, normalise, or convert rMATS output. Layout B is not
    considered.
- **Proposed minimal converter (additive; no existing function or field
  changes):**
  - `postexport_data_from_se(se, time_unit, assays = c(N = "N", N_s =
    "N_s", C = "C", C_s = "C_s"), time = "time", replicate = "replicate")`
    returns exactly what `postexport_data(<wide data frame>, time_unit)`
    returns. All validation is delegated to `postexport_data()`.
  - Errors on missing assays, missing `colData` columns, missing rownames,
    or non-numeric assays. Missing values stay errors, never zero-filled.
  - Optional reverse helper
    `as_summarized_experiment(<postexport_data>)` for round-trip tests. It is
    not required.
  - Tests:
    - a round trip against `postexport_example`, requiring identical input
      to `fit_postexport_model()` and `test_postexport_conversion()`
      results for a small B;
    - every error path.
  - Vignette: one short section.
  - The scientific core is untouched.
- **Dependency cost:** `SummarizedExperiment` has 24 recursive dependencies
  in this installation, all Bioconductor or base infrastructure (S4Vectors,
  IRanges, GenomicRanges, BiocGenerics, MatrixGenerics, DelayedArray,
  SparseArray, Matrix, …). The current package has 16 recursive runtime
  dependencies. Installation footprint grows substantially; runtime
  behaviour is unaffected.
- **Imports or Suggests?**
  - **Imports (recommended if implemented):** the converter is an exported
    input path. This is the only option that removes the BiocCheck
    warning, and it is justified by real API use, not by silencing a check.
  - **Suggests** with `requireNamespace()`: lighter, but the BiocCheck
    warning remains and reviewers may still question interoperability.
- **Recommendation:** implement the Layout-A converter as the only 6B item,
  with SummarizedExperiment in Imports, **after approval**. Not implemented
  at Stop Point 0.

---

## 5. Vignette and documentation audit

| Aspect | Covered? | Where |
|---|---|---|
| Motivation / objective | yes, under "Overview" (not titled "Introduction") | §Overview, §The four-state model |
| Installation / loading | **loading only**; no installation section | `library(postexportKinetics)` |
| Input representation | yes | wide and long format, `columns`, RI mapping caveat |
| Workflow | yes | validation → fit → test → interpretation → adjustment → ranking → plots → simulation → domain |
| Output interpretation | yes | `sigma_c`, IR, p, boundary, status; low-power explanation |
| Reproducible example | yes | shipped synthetic data, fixed seeds, B = 499 with the `1/(B+1)` floor stated |
| `sessionInfo()` | yes | final section |
| Limitations | yes | dedicated section |

- **Concrete issues:** only R3 (Introduction title and Installation
  section). No rewrite otherwise.
- **BiocStyle:** "recommended but not mandatory" ("We encourage the use of
  BiocStyle with the html_document rendering function"). Recommendation:
  **optional (6B)**. Switching the output to `BiocStyle::html_document`
  would add `BiocStyle` to Suggests and pull in extra dependencies at
  vignette-build time. The current `rmarkdown::html_vignette` (no MathJax,
  no network access) is acceptable. If adopted, confirm that the output
  still makes no network requests.
- **Help pages:** all exports have runnable examples, value sections and
  interpretation caveats (Phase 5). No change needed.

---

## 6. Dependency audit

| Package | Field | Used where | Minimum version | Assessment |
|---|---|---|---|---|
| deSolve | Imports | `deSolve::ode()` (frozen `ode.R`, simulator) | none | correct; no minimum needed (standard `ode()` API) |
| ggplot2 | Imports (`>= 3.4.0`) | all plot methods; `importFrom(ggplot2, .data)` | 3.4.0 (the `linewidth` aesthetic) | correct. Bioconductor notes that version pins are "seldom necessary"; keeping this justified minimum is harmless. |
| MASS | Imports | `MASS::mvrnorm()` (frozen bootstrap), `MASS::rnegbin()` (frozen assay noise) | none | correct; a recommended package |
| nnls | Imports | `nnls::nnls()` (frozen fit) | none | correct |
| stats, utils | Imports | `p.adjust`, `setNames`, `median`, `rnorm`, …; `head`, `packageVersion`, `globalVariables` | — | correct |
| expm | Suggests | `test-crank-nicolson.R` (`skip_if_not_installed`) | none | correct as Suggests |
| knitr, rmarkdown | Suggests | vignette | none | correct; `VignetteBuilder: knitr` |
| testthat | Suggests (`>= 3.1.7`) | tests (`local_mocked_bindings`) | 3.1.7 | correct |
| SummarizedExperiment | — | — | — | not present. Add to Imports only together with the §4 converter, if approved. |
| BiocStyle | — | — | — | optional, Suggests only if the §5 option is adopted |

No unused dependency was found, and no dependency belongs in a different
field. Introducing a Bioconductor dependency is justified **only** through
the Layout-A input converter (§4), which is an interoperability API, not a
change to the science.

---

## 7. Release and citation state (preserved)

- The package GitHub release is `v0.1.0`, **immutable**. There is **no
  package DOI**.
- `10.5281/zenodo.22944109` is labelled everywhere as the DOI of the frozen
  manuscript implementation, not of postexportKinetics.
- The manuscript is **submitted/unpublished**.
- At 0.99.0 the version appears in `DESCRIPTION`, `CITATION.cff` and NEWS
  (`inst/CITATION` follows `meta$Version`). `tools/ci/citation_audit.R`
  already enforces a single version and no package DOI.

---

## 8. CI audit

| Workflow | Role | During Bioconductor development |
|---|---|---|
| `linux-regression.yml` | **scientific gate**: frozen-reference level A on recomputed outputs, benchmark MD5, cross-platform B/C, quick validation, frozen clone unchanged; plus package tests and `R CMD check` | **keep, unchanged, mandatory** |
| `r-compat.yml` | R 4.1.3 and oldrel-1 | keep |
| `platforms.yml` | macOS and Windows, R release | keep |
| `release-candidate.yml` | CI-built tarball, hygiene, clean install, citation audit, full validation | keep (run on `bioconductor-prep` as well, if desired) |
| `publish-release.yml` | tag-triggered GitHub release | keep (dormant) |
| *(new, 6D)* Bioconductor-devel check | `R CMD check` and BiocCheck in the Bioconductor devel container | add before submission |

- **Maintenance item (not scientific debt):** GitHub warns that
  `actions/upload-artifact@v4` targets the deprecated Node.js 20 runtime.
  Bump it in a CI maintenance commit.
- **Ubuntu 26 migration** of `ubuntu-latest` from 2026-10-19: after the
  migration, rerun and confirm the scientific gate
  (`RELEASE_CHECKLIST.md` §3a).
- **Interaction with R2** (the default branch must be package-only): CI
  workflow files and `tools/` are "files for other applications".
  - **P1 (recommended):** keep full development, the reports, `tools/` and
    all workflows on a development branch (the current `main`, or renamed).
    At submission, make the GitHub default branch a **package-only branch**
    (e.g. `devel`). It would be produced from the development branch by a
    documented, scripted export that removes only non-package files, and
    verified to build to the identical tarball content.
    - CI keeps running on the development branch.
    - The scientific gate is never removed.
    - Changing the default branch is a maintainer action (D).
  - **P2:** keep everything on the default branch and ask reviewers for an
    exception, since `.github/` is common in accepted packages. Lower effort,
    but risks a reviewer request in the middle of review.
  - **P3:** move only the documentation and reports to another branch, and
    keep `.github/` and `tools/`. A partial measure; still conflicts with
    the literal rule.

---

## 9. Maintainer actions (cannot be done by Claude)

1. **Bioconductor Support Site registration** (support.bioconductor.org)
   with the DESCRIPTION maintainer email `lcerulo@unisannio.it`. BiocCheck
   currently returns HTTP 404. This clears ERROR #1.
2. **bioc-devel mailing-list subscription**
   (https://stat.ethz.ch/mailman/listinfo/bioc-devel) with the same email
   (NOTE #13).
3. **GitHub SSH public key** on the maintainer's GitHub account, as required
   by the submission process for later updates of the Bioconductor git
   repository.
4. **GitHub repository settings** if P1 is chosen: set the package-only
   branch as the default branch at submission time.
5. **Open the submission issue** in `Bioconductor/Contributions` (only after
   6A–6D and explicit approval).
6. **Voluntary:** ORCID iDs for the authors (NOTE #5), or a `fnd` funder
   entry (NOTE #6), only if supplied by the authors. Never invented.

External registration results (such as the Support Site 404) are not
package-code failures.

---

## 10. Submission readiness matrix

| Requirement | Current state | Required action | Who performs it | Blocking? | Proposed phase |
|---|---|---|---|---|---|
| Version 0.99.0 | 0.1.0 (released, immutable) | set `Version: 0.99.0` on the Bioconductor line; NEWS entry | Claude, after approval | yes | 6A |
| R CMD check | 0 E / 0 W / 2 NOTEs (environment and new-submission) | none; re-run on Bioconductor devel | Claude | no | 6D |
| BiocCheck | 1 E (Support Site) / 2 W / 10 N | clear the ERROR via registration; the Bioc-deps WARNING via §4; justify `set.seed`; frozen-style notes justified | maintainer (E), Claude (§4) | yes (ERROR) | 6A/6B/6C |
| BiocCheckGitClone | 0 / 0 / 0 | none | — | no | 6D (re-run) |
| Vignette | complete workflow; missing "Introduction" title and "Installation" section | rename and add section (`eval = FALSE`) | Claude | yes | 6A |
| NEWS | NEWS.md, bullets, checkNEWS OK | add 0.99.0 entry | Claude | no | 6A |
| License | MIT + file LICENSE (standard, permissive) | none | — | no | — |
| Repository | GitHub, public; default branch has non-package files | P1 package-only default branch (decision) | Claude (branch) and maintainer (settings) | yes (policy) | 6C/6D |
| Support Site | not registered (HTTP 404) | register | maintainer | yes | 6C |
| bioc-devel | unknown | subscribe | maintainer | yes (submission requirement) | 6C |
| Package dependencies | all used; no Bioconductor Import | only via §4 | Claude, after approval | tied to §4 | 6B |
| SummarizedExperiment | absent | Layout-A converter, SummarizedExperiment in Imports (recommended) | Claude, after approval | effectively yes for acceptance (class-reuse guidance) | 6B |
| biocViews | Software, Transcriptomics, RNASeq, AlternativeSplicing, TimeCourse, StatisticalMethod, MultipleComparison, Visualization (BiocCheck OK) | none | — | no | — |
| Citation | inst/CITATION (package, manuscript submitted, frozen DOI labelled); no package DOI | keep; `readCitationFile` check | Claude | no | 6D |
| ORCID | none | only if supplied by the authors | authors | no | 6C (optional) |
| CI | scientific gate, compatibility, platforms, release machinery green | add a Bioconductor-devel job; Node 20 bump; keep the gate | Claude | no (devel job recommended) | 6D |
| Scientific validation | full validation EQUIVALENT; 3,677 expectations | re-run the full validation after every 6A/6B commit | Claude | yes (gate) | 6A–6D |
| Platform compatibility | Linux/macOS/Windows R 4.6.1; R 4.1.3; R 4.5.3 green | add Bioconductor devel | Claude | no | 6D |
| Data provenance | `data-raw/` scripts (acceptable); `inst/scripts/` preferred | copy the example-data script to `inst/scripts/` | Claude | no | 6A (optional) / 6B |
| Build hygiene | `BIOCONDUCTOR_AUDIT.md` not in `.Rbuildignore` | add the ignore entry | Claude | yes (trivial) | 6A |

---

## 11. Proposed Phase 6 plan (not executed)

**Phase 6A: mandatory package changes.** Small, logical,
documentation-level commits; no scientific code touched.

1. `.Rbuildignore`: exclude `BIOCONDUCTOR_AUDIT.md`.
2. `Version: 0.99.0`, with a `# postexportKinetics 0.99.0` NEWS entry
   ("prepared for Bioconductor submission"). `CITATION.cff` version 0.99.0.
   There is still no package DOI, and `citation_audit.R` passes.
3. Vignette: rename "Overview" to "Introduction"; add an "Installation"
   section with `eval = FALSE`:
   - `BiocManager::install("postexportKinetics")`, marked as available
     after acceptance;
   - the GitHub route.
4. Optional, message text only: rewrite the single package-authored
   `stop(sprintf(paste0(...)))` in `R/simulate.R`, keeping the message
   identical. No test asserts this text yet; add one with the change.
5. Optional: copy the example-data generation script to `inst/scripts/`.
6. Gates after each commit: testthat, `R CMD check --as-cran`, BiocCheck,
   full validation EQUIVALENT, Linux scientific CI.

**Phase 6B: optional interoperability improvements** (the recommended
item needs explicit approval):

1. **Layout-A SummarizedExperiment converter** (§4):
   `postexport_data_from_se()`, SummarizedExperiment in Imports, tests,
   documentation and one vignette section.
2. Optional: `BiocStyle::html_document` vignette output (§5).

**Phase 6C: maintainer and account actions** (§9):

- Support Site registration and bioc-devel subscription;
- GitHub SSH key;
- the default-branch decision (P1 recommended), then the settings change;
- ORCID or `fnd` only if voluntarily supplied.

**Phase 6D: final submission checks:**

- a Bioconductor-devel CI job (`R CMD check` and BiocCheck on the devel
  container);
- `BiocCheckGitClone` on the package-only default branch;
- the Node 20 action bump;
- confirm the scientific gate after the Ubuntu 26 migration;
- the full validation;
- the `readCitationFile` check;
- tarball hygiene;
- the final readiness review;
- the submission issue, only on explicit approval.

**Not in Phase 6:** refactoring or restyling frozen ports; changes to
tolerances, bootstrap or RNG behaviour; API redesign; Layout B or rMATS;
parallel execution.
