# Release candidate 0.1.0: plan and pre-release inspection

Status: **final release candidate** (B.4–B.9 done; results in §E).
**Stopped for explicit release approval.** Not merged, not tagged, no
GitHub release.

- No release-version change: `DESCRIPTION` is still `0.0.0.9000`.
- No tag, no GitHub release, no `0.99.0`.
- **Maintainer policy (supersedes the earlier Zenodo plan):**
  - postexportKinetics gets **no Zenodo archive and no DOI**;
  - v0.1.0 is a GitHub software release, and Bioconductor is the intended
    future distribution channel;
  - `10.5281/zenodo.22944109` is only the DOI of the frozen manuscript
    implementation.
- No Bioconductor submission preparation.

**Baseline:**

- Branch `release-0.1.0` from `main` @ `daa7185`.
  - Main CI runs `36107305781` (Phase 5 merge `f7e23ee`),
    `36107867352` (`98ec4dc`) and `36119576243` (`daa7185`) are all green.
- Frozen reference: `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`, verified. The frozen
  repository is unchanged (HEAD `5d06a93`, clean).

This document has four parts:

- §A records what was inspected on the current `main` content.
- §B is the release plan.
- §C lists the blockers and decisions.
- §D records the results of stop point 1.
- §E is the final RC record (B.4–B.9).

---

## A. Pre-release inspection (performed at `daa7185`)

All builds used a clean `git archive` of `daa7185`, not the working tree, on
macOS arm64 with R 4.6.0 and pandoc 3.11 from a scratch directory.

| Check | Result |
|---|---|
| testthat (package source) | 16 files, 3,677 expectations, 0 failures / errors / warnings / skips (Phase 5 final) |
| Vignette build (`R CMD build`) | OK |
| `R CMD check --as-cran` (with manual) | 0 ERRORs, 0 WARNINGs, 2 NOTEs (new submission and development version number; HTML-manual validation skipped because of old local HTML Tidy / no V8) |
| BiocCheck 1.48.1 (information only) | 2 ERRORs, 2 WARNINGs, 10 NOTEs, the known set (`PROJECT_STATE.md` §9); Support Site lookup HTTP 504 |
| **Full** `Rscript tools/validate_against_manuscript.R` | **EQUIVALENT**: all 10 steps PASS, including same-platform recomputation (6a–c) and frozen repository unchanged (7) |
| Installation test from the built tarball | PASS (below) |
| Citation metadata | PASS (below) |
| Tarball content | **one blocker** (A.1) and one decision (A.2) |

**Installation test.** The tarball was installed into an empty temporary
library. Run with `R --vanilla` and
`.libPaths(c(<temp lib>, .Library))`, the script asserted that the package
was loaded from the temporary library, not the development installation.
It then ran:

- `library(postexportKinetics)`;
- `data(postexport_example)`;
- a minimal fit of `alt_3`: status ok, `sigma_c` 0.674601, IR 0.0641111;
- a bootstrap test with B = 49: status ok, p = 0.02;
- a simulation: 15 observed rows;
- an operational-domain check: exact match;
- a check that the vignette is installed.

All passed. The dependencies came from the system library, which holds
R's base and recommended packages plus the installed CRAN packages.

**Citation metadata** (before any package DOI):

- `CITATION.cff` has no top-level `doi` or `identifiers`.
- The only DOI in the citation files is `10.5281/zenodo.22944109`, on the
  frozen-implementation reference in both `CITATION.cff` and
  `inst/CITATION`.
- The manuscript is `type: manuscript` / `Unpublished`, "Revised manuscript
  submitted to Bioinformatics".
- No "published", "accepted" or "in press" wording appears in `CITATION.cff`,
  `inst/CITATION`, `README.md` or `NEWS.md`.

### A.1 BLOCKER: machine-specific paths in the committed fixtures

Every committed fixture (16 files in `tests/testthat/fixtures/`, all shipped
in the tarball) has absolute paths from the fixture-generation session in
the **names** of `$provenance$frozen_md5`. For example:

```
/private/tmp/claude-501/-Users-luce-postexportKinetics/<session>/scratchpad/frozen_export/commons/nested_test2.r
```

- **Scope:** only these names are affected (3 per fixture, 1 in
  `fx_orchestrator` and `fx_source_orchestrator`).
  - An exhaustive scan of every character value and name in all fixtures,
    `R/sysdata.rda` and `data/*.rda` found no other path.
  - `R/sysdata.rda`, `data/` and all text files are clean. The only
    text-file match was the word "token" in a comment of
    `test-verbatim-port.R`.
  - No credentials were found.
- **Cause:** `tools::md5sum()` names its result by the full file path, in
  `tools/frozen/make_fixtures.R:73`, `make_fixtures_phase2.R:53`,
  `make_fixtures_phase3.R:74` and `recompute_fixtures.R:72`.
- **Impact:** none scientific. No test, tool or CI step reads these names
  (`grep frozen_md5`). The MD5 values themselves are correct. It is a
  distribution hygiene problem: it leaks a local user name and scratch
  paths.
- **Proposed fix** (requires approval, because it touches committed
  fixtures):
  1. In the four generator scripts, name the MD5s by their path relative to
     the frozen export (for example `commons/nested_test2.r`). This is a
     tooling change only.
  2. Normalise the names in the 16 committed fixtures with a one-off script
     `tools/frozen/normalise_fixture_provenance.R` that:
     - rewrites **only** `names(provenance$frozen_md5)` to
       export-relative paths;
     - asserts that the rewritten object is `identical()` to the original
       once those names are restored, so everything else stays
       bit-for-bit, including all inputs, outputs, references and other
       provenance;
     - asserts that the MD5 values match a fresh `git archive` export of the
       tag.
  3. Re-run the full `validate_against_manuscript.R` and Linux CI. Report
     the change as a provenance-metadata-only fixture update, with no value
     changed.
  - **Alternative:** regenerate all fixtures with `make_fixtures*.R`. This is
    heavier, and it also changes `generated_at` and re-derives the synthetic
    inputs, so it is not recommended.

### A.2 DECISION: frozen-derived material in the shipped tests

The tarball ships `tests/testthat/fixtures/`, about 650 kB. This is needed
for the regression tests to run under `R CMD check`. It includes:

- `fx_source*.rds`: the frozen function source used by the verbatim-port
  tests. It is from the same authors, under the same MIT license.
- `fx_real_mesc.rds`: 28 mESC events × 15 samples, a small derived subset
  of the public GEO series GSE256335, extracted by the frozen conversion.

Nothing else from the frozen repository is shipped: no scripts, results,
figures, benchmark outputs or manuscript files. The benchmark table in
`R/sysdata.rda` is a derived summary with MD5 provenance.

**Recommendation:** keep both. They are small, derived and needed for the
regression gate. **Confirm.**

### A.3 Declared dependency minimums are understated (not blocking the science)

| Declaration | Required by code | Evidence |
|---|---|---|
| `ggplot2` (no minimum) | `ggplot2 (>= 3.4.0)` | `linewidth` aesthetic (`R/plot.R:105,166`); `orientation = "y"` needs ≥ 3.3.0 |
| `testthat (>= 3.0.0)` | `testthat (>= 3.1.7)` | `local_mocked_bindings()` (`test-batch.R`); `expect_no_warning()` needs ≥ 3.1.5 |

**Proposed:** declare these minimums in `DESCRIPTION` (Imports and Suggests).
`Depends: R (>= 4.1.0)` is **not** changed.

### A.4 R 4.1 compatibility: static findings (no claim yet)

- **Base R features:** `R/`, `tests/`, `tools/` and `vignettes/` were
  searched for base features added after R 4.1, such as `%||%` (R 4.4).
  None was found. They also contain no `|>` or lambda `\(x)` syntax (both
  R 4.1 features, which would be allowed).
- **Runtime dependencies:** the 16 recursive runtime dependencies of
  deSolve, ggplot2, MASS and nnls declare at most R ≥ 4.1 (scales, glue).
  None declares more.
- **MASS:** the current CRAN MASS 7.3-65 declares R ≥ 4.4.0. MASS is a
  *recommended* package bundled with every R release, so R 4.1 uses its
  bundled MASS. The package declares no MASS minimum and uses only
  `MASS::mvrnorm()`.
  - Consequence: on R 4.1, bootstrap draws may differ at rounding level
    from the fixtures, because of a different MASS version and LAPACK. The
    fixture-platform check (`fixture_platform_matches()`) then selects
    cross-platform levels B/C, as intended.
- These are static observations only. **Compatibility is claimed only after
  the CI job in B.2 passes.**

---

## B. Release plan (to execute after approval)

Each step is a separate small commit on `release-0.1.0`, with Linux CI green
after each push.

### B.1 Blocker and metadata fixes (before any version change)

1. A.1 fixture-provenance normalisation (if approved), with full validation.
2. A.3 dependency minimums.
3. `.Rbuildignore`: exclude `RELEASE_CANDIDATE_*.md`. This is done in this
   commit so that this plan never enters a tarball.

### B.2 R compatibility CI (decision 3 of Phase 5)

A new workflow, `.github/workflows/r-compat.yml`, separate from the
scientific gate:

```yaml
strategy:
  fail-fast: false
  matrix:
    r: ['4.1', 'oldrel-1']
runs-on: ubuntu-22.04   # rig/r-builds binaries for old R are available here
steps:
  - uses: actions/checkout@v5
  - uses: r-lib/actions/setup-pandoc@v2
  - uses: r-lib/actions/setup-r@v2
    with: { r-version: ${{ matrix.r }}, use-public-rspm: true }
  - uses: r-lib/actions/setup-r-dependencies@v2
    with: { extra-packages: any::rcmdcheck, any::testthat, any::expm, needs: check }
  - name: Install package
    run: R CMD INSTALL .
  - name: Regression tests (committed fixtures; level B/C expected)
    run: Rscript tools/ci/run_tests_ci.R
  - uses: r-lib/actions/check-r-package@v2
    with: { args: 'c("--no-manual", "--as-cran")', error-on: '"warning"' }
```

- **R 4.1:** the declared minimum. `oldrel-1` is the previous minor R
  release (r-lib/actions naming), as a mid-range point. The current release is already
  covered by `linux-regression.yml`.
- **Interpreting failures:**
  - A **dependency-installation** failure (a CRAN dependency no longer
    installable on R 4.1) is reported as an ecosystem limitation, separately
    from package code.
  - A **package** failure (code using post-4.1 functionality) is a concrete
    incompatibility: **STOP and report before changing `DESCRIPTION`**.
  - No `Depends` change without approval, and no speculative compatibility
    claim.
- `ubuntu-22.04` is used only for the old-R job, if R 4.1 binaries are
  unavailable on the `ubuntu-latest` image; this will be confirmed in the
  first run. The scientific gate stays on `ubuntu-latest` (B.3).

### B.3 Platform checks

- **Linux (existing):** `linux-regression.yml` on `ubuntu-latest`,
  unchanged. It remains the scientific release gate:
  - package job: level B/C, plus `R CMD check`;
  - frozen-reference job: level A on recomputed frozen outputs, cross-platform
    comparison, benchmark MD5, quick validation, frozen clone unchanged.
- **macOS and Windows:** a new workflow, `.github/workflows/platforms.yml`,
  on `macos-latest` and `windows-latest`, R release. It installs the
  package, runs `tools/ci/run_tests_ci.R` and `check-r-package`
  (`--as-cran`, error on warning). No compiled code, so no Rtools-specific
  steps.
  - **Windows:** the committed macOS fixtures are compared at levels B/C.
  - **macOS arm64:** if the runner's LAPACK/BLAS, MASS, nnls and RNG
    provenance match the fixtures exactly, the tests select **strict
    level A, including bootstrap draws**. This is a legitimate
    second-machine same-platform check.
  - If level A fails on the macOS runner only because of CPU-specific
    rounding, that is a finding to **report**, not to hide. The tolerance
    policy is not changed without approval.
- **Local macOS:** `R CMD check --as-cran` and the full validation, as in §A.

### B.4 Version synchronisation (one commit)

| File | Change |
|---|---|
| `DESCRIPTION` | `Version: 0.1.0` |
| `NEWS.md` | heading `# postexportKinetics 0.1.0`, first public release; keep content; remove "(development)" |
| `CITATION.cff` | `version: "0.1.0"`; no `date-released` until the tag date is fixed; **no** package DOI |
| `inst/CITATION` | the version comes from `meta$Version`; change the note "(development version)" to plain "R package version 0.1.0" |
| `README.md` | status banner: "first public release 0.1.0; not a Bioconductor release; interface may still evolve"; keep all interpretation caveats |
| `PROJECT_STATE.md` / `RELEASE_CHECKLIST.md` | status updates |

`0.99.0` is not used. The Bioconductor line starts later.

### B.5 Scientific release gate

On the final RC commit:

- the **full** `Rscript tools/validate_against_manuscript.R` (not
  `--quick`) on macOS, which must report **EQUIVALENT**, with the log kept
  for the release notes;
- Linux CI (frozen-reference level A, quick validation) green.

### B.6 Package checks on the final RC commit

- testthat;
- vignette build;
- `R CMD build` from a clean `git archive`;
- `R CMD check --as-cran` (macOS local; Linux, macOS and Windows CI);
- BiocCheck for information only.

### B.7 Tarball inspection (repeat on the final tarball)

The automated scan from §A will be repeated. The file list must contain
only:

- `DESCRIPTION`, `NAMESPACE`, `LICENSE`, `NEWS.md`, `README.md`;
- `R/`, `man/`, `data/`, `inst/{CITATION,doc,extdata}`, `vignettes/`,
  `build/`;
- `tests/`, with fixtures.

It must contain no phase reports, `PACKAGE_PLAN.md`,
`STOP_CONDITION_REPORT.md`, `PROJECT_STATE.md`, `RELEASE_*.md`, `CLAUDE.md`,
`tools/`, `data-raw/` or `.github/`; no scratch or check artefacts; no
absolute paths or user names in text **or** binary (`.rds`/`.rda`) content;
and no credentials.

### B.8 Installation test

Repeat the §A clean-library smoke test on the final tarball. Additionally,
install from GitHub at the RC commit:
`remotes::install_github("bioinformatics-sannio/postexportKinetics@<sha>", build_vignettes = TRUE)`.

### B.9 Citation and reproducibility (re-check before tagging)

- No package DOI in `CITATION.cff`, `inst/CITATION`, README or NEWS.
- `10.5281/zenodo.22944109` appears only as the frozen manuscript
  implementation.
- The manuscript remains submitted/unpublished.

### B.10 GitHub release preparation (prepared, not executed)

- **Final commit to tag:** the `--no-ff` merge of `release-0.1.0` into
  `main`, after approval and green main CI. The exact SHA is recorded in
  the final RC report.
- **Proposed tag:** `v0.1.0`, annotated, on that merge commit.
- **Proposed title:** `postexportKinetics 0.1.0`.
- **Proposed release notes** (draft):

  > First public release of postexportKinetics, an R package for
  > compartment-resolved four-state kinetic modelling of nuclear and
  > cytoplasmic, unprocessed and processed RNA.
  >
  > **Model and inference.**
  > - A constrained nested-model comparison of a null model
  >   (`sigma_c = 0`) against a full model (`sigma_c >= 0`).
  > - Fitting by trapezoidal interval balances, propagated and regularised
  >   covariance, and whitened NNLS.
  > - A replicate-level generative bootstrap with an add-one p-value and an
  >   explicit boundary rule. This is not a likelihood-ratio test.
  >
  > **Also included.** Simulation with the manuscript simulator; design
  > diagnostics against the manuscript benchmark; multiple-testing
  > adjustment; exploratory ranking; tidy tables and plots; a vignette and
  > a synthetic example dataset.
  >
  > **Interpretation.** `sigma_c` is a phenomenological post-export
  > conversion rate. Statistical support indicates kinetic patterns
  > consistent with an additional post-export conversion component. It
  > does not identify a molecular mechanism.
  >
  > **Scientific reference.** The numerical core reproduces the frozen
  > manuscript implementation: tag `manuscript-revision-v1.0`, commit
  > `65c3b73`, doi:10.5281/zenodo.22944109 (the DOI of the frozen
  > implementation; the package itself has no DOI). Full manuscript validation:
  > EQUIVALENT. Regression is tested on Linux, macOS and Windows, and on
  > R 4.1 and oldrel-1.
  >
  > **Reproducibility.** Results are bitwise reproducible only within a
  > matched numerical environment. Bootstrap draws depend on LAPACK/BLAS
  > through `MASS::mvrnorm()`.
  >
  > **Validation.** The package numerical core is regression-tested
  > against the frozen manuscript implementation. Detailed provenance and
  > known frozen-reference notes are documented in the repository
  > validation records.
  >
  > **Status.** Not a Bioconductor release.
  >
  > **Not yet included.** Parallel execution, rMATS conversion, comparator
  > methods and SummarizedExperiment input.

- **Assets:** the source tarball `postexportKinetics_0.1.0.tar.gz`, built
  from the tagged commit, and the full validation log.

### B.11 Identifiers and distribution (maintainer policy; replaces the Zenodo plan)

- **No Zenodo archive and no DOI for postexportKinetics.** The earlier plan
  to enable the repository in Zenodo, mint a package DOI and add it in a
  post-release commit is **withdrawn**. `.zenodo.json` has been removed.
- **v0.1.0** is a GitHub software release: tag `v0.1.0` in
  <https://github.com/bioinformatics-sannio/postexportKinetics>.
- **Future archival and distribution** is intended through Bioconductor.
- **`10.5281/zenodo.22944109`** identifies the frozen postexport-kinetics
  manuscript implementation. It appears in the package citation metadata
  only as that reference and is never presented as the package DOI.
- **Manuscript Availability statement** (author action) cites:
  - the manuscript-code repository
    <https://github.com/bioinformatics-sannio/postexport-kinetics>;
  - DOI 10.5281/zenodo.22944109;
  - optionally, the postexportKinetics repository once v0.1.0 is public.

### B.12 Ubuntu runner

- Keep `ubuntu-latest`. GitHub announced its migration to Ubuntu 26 from
  2026-10-19.
- After the migration, rerun the full scientific regression:
  - Linux CI levels A/B/C;
  - the quick validation in CI;
  - record the new LAPACK/BLAS provenance.
- If the migration happens during the RC, the release waits for that
  rerun.
- `ubuntu-22.04` in B.2 is used for old-R availability only, not as a pin
  of the scientific gate.

### B.13 Stop points

1. After B.1–B.3 (fixes plus compatibility and platform CI results): report,
   especially any R 4.1 or macOS level-A finding.
2. After B.4–B.9 (the version-synchronised RC, with all gates green): final
   RC report with the SHA to tag.
3. Tagging and the GitHub release only after explicit approval (no Zenodo step).

---

## C. Release blockers and decisions

| # | Item | Type | Proposed action |
|---|---|---|---|
| 1 | Absolute scratch paths in `provenance$frozen_md5` names of all 16 fixtures (A.1) | blocker | **resolved** (`379ae65`; §D.1) |
| 2 | Compatibility CI on older R not yet present (Phase 5 decision 3) | blocker (by decision) | **resolved**: R 4.1 and oldrel-1 green (`5c95dee`; §D.3) |
| 3 | macOS/Windows CI not yet present | required by RC scope | **resolved**: both green (`1e9b365`; §D.4) |
| 4 | Understated `ggplot2` / `testthat` minimum versions (A.3) | fix before release | **resolved** (`cdc4fb3`) |
| 5 | Frozen-derived test fixtures in the tarball (A.2) | decision | **approved: keep**; documented in `tests/testthat/fixtures/README.md` |
| 6 | `.zenodo.json` (B.11) | decision | added in `55d37e7`, then **removed** by the maintainer policy (no package DOI or Zenodo archive) |
| 7 | Support Site registration / BiocCheck ERRORs | not a GitHub-release blocker | later, Bioconductor phase |

---

## D. Stop point 1 results (B.1–B.3), branch `release-0.1.0` @ `1e9b365`

Commits since the plan (`36881c1`):

| Commit | Content |
|---|---|
| `379ae65` | normalise fixture provenance (relative MD5 names) and add `tools/frozen/normalise_fixture_provenance.R`; generators use relative names; fixtures documented |
| `cdc4fb3` | `ggplot2 (>= 3.4.0)`, `testthat (>= 3.1.7)` |
| `55d37e7` | `.zenodo.json` (later removed by the maintainer policy; see B.11) |
| `5c95dee` | `.github/workflows/r-compat.yml` (R 4.1, oldrel-1; ubuntu-22.04) |
| `1e9b365` | `.github/workflows/platforms.yml` (macOS and Windows, R release) |

`.Rbuildignore` excludes `RELEASE_CANDIDATE_*.md` (`36881c1`) and
`.zenodo.json` (that entry was removed together with the file under the
maintainer policy). `linux-regression.yml` is unchanged. No R code, numerical
code, tolerance or level classification changed.

### D.1 Fixture-normalisation proof

`tools/frozen/normalise_fixture_provenance.R` was run against a fresh
`git archive` export of `manuscript-revision-v1.0` (commit marker verified):

- **Check-only mode.** All 16 fixtures verified:
  - each of the 44 names (3 per fixture, 1 in `fx_orchestrator` and
    `fx_source_orchestrator`) maps to exactly one export file:
    `commons/nested_test2.r`, `ode_model/ode.r`, `commons/platforms.r`,
    `synthetic_dataset/run_benchmark_main_corrected_onset_revision.R`;
  - every stored MD5 value equals the MD5 of that file in the fresh
    export;
  - restoring the original names on the normalised object gives an object
    `identical()` to the committed one.
- **Apply mode.** 16 rewritten (`saveRDS` version 3, as the generators do),
  with the read-back identities re-checked. A second check-only run
  reports all fixtures "already relative".
- **Independent check** (a separate script, comparing against copies of
  the original files). For every fixture:
  - the object without `provenance$frozen_md5` is `identical()`;
  - the MD5 values are `identical()`;
  - `generated_at` is identical;
  - no name is absolute.
- **Negative test** (scratch copy with one tampered MD5): exit status 1,
  "FAILED (nothing written)", and no file modified. After this test the
  script was made all-or-nothing: it writes nothing unless every fixture
  passes.
- **Not a regeneration.** No input, output, reference or other provenance
  field changed. Only the `.rds` file bytes changed, because of the
  rewritten names.
- **Generators.** `make_fixtures.R`, `make_fixtures_phase2.R`,
  `make_fixtures_phase3.R` and `recompute_fixtures.R` now name MD5s by
  export-relative path. `recompute_fixtures.R` was exercised (output names
  `commons/nested_test2.r`); the generators were only parse-checked, not
  run, since the fixtures are not regenerated.

### D.2 Full manuscript validation

`Rscript tools/validate_against_manuscript.R` (full, not `--quick`), after
the normalisation, on macOS arm64 with R 4.6.0: **EQUIVALENT**, with all 10
steps passing.

- 4a: Ppp1r36dn and Nsd1, relative differences 5.5e-16 to 6.7e-15.
- 4b: 28 mESC events, maximum relative difference 5.6e-13.
- 6b: same-platform level A, including bootstrap draws.
- 7: frozen repository unchanged.

Local testthat: 3,677 expectations, 0 failures.

### D.3 R compatibility (`r-compat`, run `36122217699`, ubuntu-22.04)

| Job | Result |
|---|---|
| R 4.1 (`r-version: '4.1'`, the latest 4.1.x as resolved by `r-lib/actions/setup-r`) | **success**: dependencies installed, package installed, regression tests (cross-platform levels B/C) and `R CMD check --as-cran` (warnings blocking) passed |
| R oldrel-1 | **success**, same steps |

- No dependency or ecosystem failure (A) and no package incompatibility
  (B). `Depends: R (>= 4.1.0)` is **supported by evidence** for R 4.1.
  `DESCRIPTION` is unchanged.
- Both jobs reported the expected non-blocking level-C notice: 37
  bootstrap-draw-dependent differences, not compared across platforms.
- The exact patch versions are in the job logs, which were not read
  because they require authentication.

### D.4 Platforms (`platforms`, run `36122217735`)

| Job | Result |
|---|---|
| macos-latest, R release | **success**: installation, regression tests, `R CMD check --as-cran` (warnings blocking) |
| windows-latest, R release | **success**, same steps; cross-platform level-C notice (37 bootstrap-draw differences, not compared) |

**Platform-specific numerical finding (macOS):**

- The macOS job emitted **no** cross-platform-difference notice. Every
  cross-platform job (Linux, Windows, R 4.1, oldrel-1) emits one, because
  bootstrap-draw fields are always reported there.
- This indicates that the runner's LAPACK/BLAS, MASS, nnls and RNG
  provenance matched the fixture platform. The **strict same-platform
  level A**, including bootstrap draws, was then selected and passed on a
  second machine.
- This is an inference from the annotations; the job log was not read.
- No level-A failure occurred, so there is nothing to stop for.

### D.5 Linux scientific gate (`linux-regression`, run `36122217641`, ubuntu-latest)

**Both jobs succeeded:**

- **package:** level B/C and `R CMD check`.
- **frozen-reference:**
  - frozen outputs recomputed from the committed (normalised) inputs;
  - benchmark MD5 matches;
  - same-platform level A, including bootstrap draws;
  - cross-platform comparison passed;
  - quick validation step passed;
  - frozen clone unchanged.
- The notices are the known level-C differences and the Ubuntu 26
  migration notice.

### D.6 Local package checks (clean `git archive` of `1e9b365`)

- `R CMD build`: OK, vignette built.
- `R CMD check --as-cran`: **0 ERRORs, 0 WARNINGs, 2 NOTEs**. These are the
  new submission with the development version number, and HTML-manual
  validation skipped because of the local tools.
- BiocCheck 1.48.1 (information only): **2 ERRORs, 2 WARNINGs, 10 NOTEs**,
  the known set. The Support Site lookup returned HTTP 404 in this run.

### D.7 Tarball hygiene (exhaustive scan of the `1e9b365` tarball)

- **Contents:** 86 files. Top-level entries are only `DESCRIPTION`,
  `LICENSE`, `NAMESPACE`, `NEWS.md`, `README.md`, `R/`, `man/`, `data/`,
  `inst/`, `vignettes/`, `build/` and `tests/`.
- **No development files:** no phase reports, plans, `PROJECT_STATE.md`,
  `RELEASE_*`, `CLAUDE.md`, `tools/`, `data-raw/`, `.github/`,
  `.zenodo.json` or `CITATION.cff`.
- **No artefacts:** no scratch, check, log or backup files.
- **Binary content:** every string, name, factor level and attribute of
  every `.rds`/`.rda` object, including hidden objects in `R/sysdata.rda`,
  was scanned for absolute paths (`/Users/`, `/private/tmp`, `/home/`,
  Windows user paths) and for the local user and session identifiers.
  Result: **0 hits** in 20 binary files.
- **Text files:** no paths, credentials, tokens or keys.
- **One observation:** `DESCRIPTION` contains the standard
  `Packaged: <date>; luce` line, which `R CMD build` always writes with the
  login name of the user who built the tarball. It is not a path, and every
  R source tarball has it.
  - **Options for the release asset (decision):**
    - (a) accept it;
    - (b) build the attached release tarball in CI, where it would record
      the GitHub runner user.
  - Recommendation: (b), a small CI job at release time. It is not a
    content issue.
- **Installation test:** repeated from this tarball in an empty temporary
  library, and passed. It loaded from the temporary library and ran the
  fit (`sigma_c` 0.674601, IR 0.0641111), the bootstrap test (p = 0.02,
  B = 49), a simulation, the domain check (exact match) and the vignette
  check.

### D.8 Release notes

Revised as approved (B.10): the individual SF items are replaced by the
general validation statement. The detailed SF records remain in
`PROJECT_STATE.md`, `STOP_CONDITION_REPORT.md` and `tools/frozen/README.md`.

### D.9 Remaining blockers and decisions before B.4

- **No remaining release blockers** from the plan (C.1–C.4 resolved; C.5
  and C.6 approved and done).
- **Decision:** how to build the release tarball asset (D.7: local, or CI
  for a neutral `Packaged` line).
- **To confirm at B.4:** the exact R 4.1 and oldrel-1 versions tested,
  from the job logs (for example `gh run view --log`, with authentication),
  so the README can state them precisely.
- **Still pending** (unchanged): the Ubuntu 26 migration from 2026-10-19.
  If it happens before tagging, rerun the Linux scientific gate (B.12).

---

## E. Final release candidate (B.4–B.9)

### E.1 Commits after stop point 1

| Commit | Content |
|---|---|
| `fd65163` | CI: record the exact R version and platform (annotation and job summary) in r-compat, platforms and both linux-regression jobs; provenance only |
| `20ec9fc` | release-candidate workflow: `R CMD build .` on a clean runner, SHA256, `tools/ci/inspect_tarball.R`, `tools/ci/smoke_install.R`, full validation, artifact upload |
| `f919644` | maintainer policy: no Zenodo archive and no package DOI; `.zenodo.json` removed; DOI distinction made explicit (B.11) |
| `9fcc735` | **version 0.1.0** synchronised (DESCRIPTION, NEWS, CITATION.cff, inst/CITATION, README, package help, PROJECT_STATE, RELEASE_CHECKLIST) |
| `62226fb` | fix of `tools/ci/smoke_install.R` (see E.4); tooling only |
| this commit | this record (`RELEASE_CANDIDATE_*.md` is excluded from the build) |

- **RC package commit:** `62226fb36228e70639920f6a1d6b38606f19d2d0`. All
  gates below ran on this commit.
- **Final RC SHA:** the branch tip, i.e. this commit. It differs from
  `62226fb` only by this build-ignored file, which can be checked with
  `git diff --stat 62226fb <tip>`. The package tarball content is therefore
  identical.
- No R code, numerical code, fixture, tolerance or level classification
  changed in B.4–B.9.

### E.2 Exact tested R versions (from the provenance annotations)

| Job | R | Platform / OS | LAPACK |
|---|---|---|---|
| r-compat R 4.1 | **R 4.1.3 (2022-03-10)** | x86_64-pc-linux-gnu, Ubuntu 22.04.5 LTS | 3.10.0 |
| r-compat oldrel-1 | **R 4.5.3 (2026-03-11)** | x86_64-pc-linux-gnu, Ubuntu 22.04.5 LTS | 3.10.0 |
| platforms macOS | R 4.6.1 (2026-06-24) | aarch64-apple-darwin23, macOS Tahoe 26.6.2 | 3.12.1 |
| platforms Windows | R 4.6.1 (2026-06-24 ucrt) | x86_64-w64-mingw32, Windows Server 2022 x64 (build 26100) | 3.12.1 |
| linux-regression (both jobs) | R 4.6.1 (2026-06-24) | x86_64-pc-linux-gnu, Ubuntu 24.04.5 LTS | 3.12.0 |
| release-candidate build | R 4.6.1 (2026-06-24) | x86_64-pc-linux-gnu, Ubuntu 24.04.5 LTS | 3.12.0 |
| local (macOS) | R 4.6.0 (2026-04-24) | aarch64-apple-darwin23 | 3.12.1 |

**macOS:** the runner ran R 4.6.1, while the fixtures were generated with R
4.6.0. The R version is not part of the provenance match (LAPACK/BLAS
library, MASS, nnls, OS, architecture and RNG are). The job again reported
no cross-platform difference, which is consistent with strict level A
passing, including bootstrap draws.

### E.3 CI runs (all green on the RC package commit `62226fb`)

| Workflow | Run | Jobs |
|---|---|---|
| release-candidate | `36132703379` | build: **success** (tarball, inspection PASSED, smoke test PASSED, full validation **EQUIVALENT**, artifact uploaded) |
| linux-regression (scientific gate) | `36132703330` | package **success**; frozen-reference **success** (level A on recomputed frozen outputs, benchmark MD5, cross-platform B/C, quick validation, frozen clone unchanged) |
| platforms | `36132703341` | macos-latest **success**; windows-latest **success** |
| r-compat | `36132703328` | R 4.1 **success**; oldrel-1 **success** |

On `9fcc735`, the same workflows ran:

- `36125387497` linux-regression, `36125387539` platforms and
  `36125387557` r-compat were all green.
- `36125387572` release-candidate **failed** in the smoke step. This was a
  tooling bug, fixed in `62226fb` (E.4).

**Annotations** (notices and one warning):

- level-C cross-platform notices, as always;
- the Ubuntu 26 migration notice;
- a GitHub warning that `actions/upload-artifact@v4` targets the
  deprecated Node.js 20 runtime and is run on Node.js 24. This is a CI
  infrastructure deprecation, not a package check result.
  Recommendation: bump the action in a later maintenance commit.

### E.4 Finding fixed during the RC: smoke-test tooling bug

- **Symptom:** on the Linux runner, `tools/ci/smoke_install.R` generated
  invalid R code ("unexpected symbol").
- **Cause:** `deparse(.libPaths())` wraps across lines when there are
  several library paths, as on the CI runner. Locally there was only one.
- **Fix:** a width-safe one-line literal. The failure was reproduced
  locally with three library paths before the fix, and the fixed script
  passed.
- **Impact:** the package and the tarball were not affected. The inspection
  of the same tarball had already passed.

### E.5 Scientific release gate: full manuscript validation (not `--quick`)

| Where | Commit | Result |
|---|---|---|
| local macOS arm64, R 4.6.0 (fixture platform) | `9fcc735` (package content identical to `62226fb`) | **EQUIVALENT**, 10/10 PASS (strict same-platform level A, including bootstrap draws) |
| CI ubuntu-latest, R 4.6.1 (`release-candidate` run `36132703379`) | `62226fb` | **EQUIVALENT** (annotation: "Scientific equivalence status: EQUIVALENT (0 step(s) failed)") |

- **Logs:**
  - the local log is kept as
    `validate_against_manuscript_full_macos_9fcc735.log` (maintainer
    scratch, not committed);
  - the CI log is `validate_against_manuscript_full.log` in the artifact
    `release-candidate-62226fb36228e70639920f6a1d6b38606f19d2d0`, together
    with the tarball, its `.sha256`, `inspect_tarball.log` and
    `smoke_install.log`. It is retained for 90 days and downloadable by
    maintainers with GitHub authentication.
- **Proposed release asset:** attach the CI log, which carries no local
  paths.

### E.6 Package checks

| Check | Result |
|---|---|
| testthat (local) | 16 files, **3,677 expectations, 0 failures / errors / warnings / skips** |
| vignette build (`R CMD build`, local and CI) | OK |
| `R CMD check --as-cran` (local, clean `git archive` of `9fcc735`, with manual) | **0 ERRORs, 0 WARNINGs, 2 NOTEs**: new submission (CRAN incoming feasibility) and HTML-manual validation skipped (old local HTML Tidy, no V8) |
| `R CMD check --as-cran` (CI: Linux, macOS, Windows, R 4.1.3, R 4.5.3; warnings blocking) | all **success** |
| BiocCheck 1.48.1 (information only) | **1 ERROR, 2 WARNINGs, 10 NOTEs** (below) |

- **BiocCheck:** the version-format ERROR disappeared with `0.1.0`. What
  remains:
  - ERROR: Support Site lookup (HTTP 404; maintainer registration, needed
    only for Bioconductor);
  - WARNINGs: no Bioconductor dependencies; `set.seed`;
  - NOTEs: known style and metadata items.
  - No new finding. Bioconductor submission is not started.
- **Local timing anomaly:** a first local `R CMD check` in the background
  showed an examples NOTE: `plot.postexport` took 987 s elapsed with 1.1 s
  CPU. The macOS power log shows a 988 s system sleep at that moment. The
  foreground rerun gave examples OK (`plot.postexport` 1.07 s elapsed) and
  the 2 NOTEs above. This was not a package issue.

### E.7 Release tarball (official candidate asset)

| Field | Value |
|---|---|
| file | `postexportKinetics_0.1.0.tar.gz` |
| built by | GitHub Actions `release-candidate` run `36132703379`, `R CMD build .` on a clean checkout (working tree verified clean) |
| commit | `62226fb36228e70639920f6a1d6b38606f19d2d0` |
| R | R 4.6.1 (2026-06-24), x86_64-pc-linux-gnu |
| runner | Ubuntu 24.04.5 LTS (image ubuntu24 20260920.314.1) |
| **SHA256** | **`7de6e84396a6e94806a58f22532813fd053d8c2cdc679646d5689aa9437dd2d0`** |

- The `Packaged:` field is the normal one written by R on the runner, and
  it was not edited.
- The local build of `9fcc735` (SHA256 differs because of build time and
  user) was used for the local comparison checks only.

### E.8 Tarball hygiene

`tools/ci/inspect_tarball.R` **PASSED** on the CI-built tarball (in run
`36132703379`) and on the local build:

- 86 files. The top-level entries are only `DESCRIPTION`, `LICENSE`,
  `NAMESPACE`, `NEWS.md`, `README.md`, `R/`, `man/`, `data/`, `inst/`,
  `vignettes/`, `build/` and `tests/`.
- None of: phase reports, `PACKAGE_PLAN.md`, `STOP_CONDITION_REPORT.md`,
  `PROJECT_STATE.md`, `RELEASE_*`, `CLAUDE.md`, `tools/`, `data-raw/`,
  `.github/`, `.zenodo.json`, `CITATION.cff`, scratch, check, log or backup
  files.
- **Binary fixture scan:** 20 `.rds`/`.rda` files and 4,063 distinct
  strings (names, values, factor levels, attributes, hidden objects). There
  are **0** user or temporary paths and **0** credential-like strings.
  - The only other absolute paths are the system R framework LAPACK/BLAS
    library paths
    (`/Library/Frameworks/R.framework/Versions/4.6/Resources/lib/…`). These
    are fixture provenance used for platform matching and are not
    user-specific.
- `tests/testthat/fixtures` is kept, as approved.

### E.9 Clean installation

- **CI-built tarball**, in run `36132703379` (`tools/ci/smoke_install.R`):
  **SMOKE TEST PASSED**. The tarball was installed into an empty library
  and loaded from it, in a fresh `--vanilla` process. The run covered:
  `library()`; `data(postexport_example)`; a minimal fit; a bootstrap test
  with B = 49; a simulation; the operational-domain check (exact match);
  `citation("postexportKinetics")`; and vignette availability.
- **Local tarball (`9fcc735`)**, same script: PASSED. Results: fit
  `sigma_c` 0.674601, IR 0.0641111; bootstrap p = 0.02; 15 simulated rows;
  domain exact; citation printed with "R package version 0.1.0"; vignette
  available. It also passed with three library paths, the regression test
  for E.4.
- **GitHub at the RC SHA:**
  `remotes::install_github("bioinformatics-sannio/postexportKinetics@9fcc735b5fcfb0ed87dbf0d2f7e25f6cb11f7919", build_vignettes = TRUE)`
  (remotes 2.5.0) into an empty library: **OK**.
  - Version 0.1.0; `RemoteSha` matches.
  - The vignette was built and available; a minimal fit ran with status ok
    and `sigma_c` 0.674601.
  - `9fcc735` has the same package content as `62226fb`, which differs only
    in `tools/ci/`.

### E.10 Citation and DOI audit (on the RC commit)

- **Version:** 0.1.0 everywhere. `DESCRIPTION`; `CITATION.cff`
  (`version: "0.1.0"`, no `date-released`); `NEWS.md` heading;
  `inst/CITATION` via `meta$Version` ("R package version 0.1.0"). No
  `0.0.0.9000` in package files.
- **No package DOI anywhere.** `CITATION.cff` has no top-level `doi` or
  `identifiers`. There is no `.zenodo.json` in the repository.
- **`10.5281/zenodo.22944109`** appears only as the frozen manuscript
  implementation, explicitly labelled "not this package" / "not a DOI of
  postexportKinetics". It appears in `CITATION.cff` (references),
  `inst/CITATION` (third entry), README, NEWS and the vignette.
- **Manuscript status:** submitted/unpublished (`type: manuscript`,
  `Unpublished`, "Revised manuscript submitted to Bioinformatics"). There is
  no accepted, published or in-press wording.
- **Syntax:** `CITATION.cff` parses as valid YAML, and `citation()` renders
  its three entries.

### E.11 Proposed release

- **Tag:** `v0.1.0`, annotated. Recommendation: tag the `--no-ff` merge of
  `release-0.1.0` into `main`, after approval and green main CI. Its
  package content equals `62226fb`, and the asset below is attached.
- **Title:** `postexportKinetics 0.1.0`.
- **Assets:**
  - `postexportKinetics_0.1.0.tar.gz`, SHA256 `7de6e843…2d0` (E.7), and
    its `.sha256`;
  - `validate_against_manuscript_full.log`, from the CI artifact of run
    `36132703379`.
- **No Zenodo step** (maintainer policy).

**Final release notes:**

> First public release of postexportKinetics, an R package for
> compartment-resolved four-state kinetic modelling of nuclear and
> cytoplasmic, unprocessed and processed RNA.
>
> **Model and inference.**
> - A constrained nested-model comparison of a null model (`sigma_c = 0`)
>   against a full model (`sigma_c >= 0`).
> - Fitting by trapezoidal interval balances, propagated and regularised
>   covariance, and whitened NNLS.
> - A replicate-level generative bootstrap with an add-one p-value and an
>   explicit boundary rule. This is not a likelihood-ratio test.
>
> **Also included.** Simulation with the manuscript simulator; design
> diagnostics against the manuscript benchmark; multiple-testing
> adjustment; exploratory ranking; tidy tables and plots; a vignette and a
> synthetic example dataset.
>
> **Interpretation.** `sigma_c` is a phenomenological post-export
> conversion rate. Statistical support indicates kinetic patterns
> consistent with an additional post-export conversion component. It does
> not identify a molecular mechanism.
>
> **Scientific reference.** The numerical core reproduces the frozen
> manuscript implementation: postexport-kinetics, tag
> `manuscript-revision-v1.0`, commit `65c3b73`. It is archived as
> doi:10.5281/zenodo.22944109, which is the DOI of the frozen manuscript
> implementation, not of this package.
>
> **Validation.** The package numerical core is regression-tested against
> the frozen manuscript implementation. Detailed provenance and known
> frozen-reference notes are documented in the repository validation
> records. Full manuscript validation: EQUIVALENT. Tested on Linux, macOS
> and Windows (R 4.6.1), and on R 4.1.3 and R 4.5.3.
>
> **Reproducibility.** Results are bitwise reproducible only within a
> matched numerical environment. Bootstrap draws depend on LAPACK/BLAS
> through `MASS::mvrnorm()`.
>
> **Distribution.** This is a GitHub software release and has no DOI. It
> is not yet a Bioconductor release; Bioconductor is the intended future
> distribution channel. The interface may still evolve.
>
> **Not yet included.** Parallel execution, rMATS conversion, comparator
> methods and SummarizedExperiment input.

### E.12 Remaining items (none blocking)

- **Ubuntu 26 migration** from 2026-10-19. If the tag is created after the
  migration, rerun the Linux scientific gate first (B.12).
- **Node.js 20 deprecation warning** for `actions/upload-artifact@v4`: a
  CI maintenance item.
- **Manuscript Availability statement** (author action): cite the
  manuscript-code repository and DOI 10.5281/zenodo.22944109, and
  optionally the postexportKinetics repository once v0.1.0 is public.
