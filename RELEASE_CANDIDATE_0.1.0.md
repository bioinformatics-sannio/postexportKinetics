# Release candidate 0.1.0: plan and pre-release inspection

Status: **plan and inspection only.** No release-version change has been
made.

- `DESCRIPTION` is still `0.0.0.9000`.
- No tag, no GitHub release, no Zenodo archive, no `0.99.0`.
- No Bioconductor submission preparation.

**Baseline:**

- Branch `release-0.1.0` from `main` @ `daa7185`.
  - Main CI runs `36107305781` (Phase 5 merge `f7e23ee`),
    `36107867352` (`98ec4dc`) and `36119576243` (`daa7185`) are all green.
- Frozen reference: `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`, verified. The frozen
  repository is unchanged (HEAD `5d06a93`, clean).

This document has two parts:

- §A records what was inspected on the current `main` content.
- §B is the concrete release plan, to be executed only after review.

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

- **R 4.1:** the declared minimum. `oldrel-1` is the release before the
  previous one, as a mid-range point. The current release is already
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
| `CITATION.cff` | `version: "0.1.0"`; add `date-released` at release time; **no** package DOI |
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
  > `65c3b73`, doi:10.5281/zenodo.22944109. Full manuscript validation:
  > EQUIVALENT. Regression is tested on Linux, macOS and Windows.
  >
  > **Reproducibility.** Results are bitwise reproducible only within a
  > matched numerical environment. Bootstrap draws depend on LAPACK/BLAS
  > through `MASS::mvrnorm()`.
  >
  > **Known provenance notes of the frozen tag.** Pseudo-shutoff real-data
  > B = 4999 (SF-1); corrected-onset generator RNG (SF-2); pseudo-shutoff
  > benchmark authority (SF-4).
  >
  > **Status.** Not a Bioconductor release.
  >
  > **Not yet included.** Parallel execution, rMATS conversion, comparator
  > methods and SummarizedExperiment input.

- **Assets:** the source tarball `postexportKinetics_0.1.0.tar.gz`, built
  from the tagged commit, and the full validation log.

### B.11 Zenodo archival plan (separate package DOI)

1. **Link the repository.** A GitHub owner/admin of `bioinformatics-sannio`
   signs in to Zenodo with GitHub (Account → GitHub), grants the
   organisation access, and switches **on** the repository
   `bioinformatics-sannio/postexportKinetics`. This must happen *before* the
   release is published, because Zenodo archives only releases published
   after activation.
2. **Optional `.zenodo.json`** (proposed for a B.1 commit, subject to
   approval). It controls the Zenodo metadata instead of letting Zenodo
   derive it from `CITATION.cff`:
   - title, the four authors (no ORCID unless the authors supply one), MIT,
     `upload_type: software`, version `0.1.0`;
   - keywords;
   - `related_identifiers`:
     - `10.5281/zenodo.22944109` with relation `isDerivedFrom`, or
       `references` (the frozen manuscript implementation);
     - the repository URL with relation `isSupplementTo`.
   - The manuscript will be added once it has a DOI.
3. **Publish** the GitHub release `v0.1.0` (B.10). Zenodo then creates the
   archive and mints:
   - a **version DOI** (0.1.0 specifically);
   - a **concept DOI** (all versions).
   Both are **new and separate** from `10.5281/zenodo.22944109`, which must
   never be reused as the package DOI.
4. **Verify the Zenodo record:** authors, license, version, files (the
   GitHub source archive) and the related identifiers.
5. **Post-release documentation commit** on `main`, without re-tagging:
   - add the package DOI to `CITATION.cff` (`doi:` and/or `identifiers`,
     concept and version DOI);
   - add it to `inst/CITATION` (the package entry) and to a README badge;
   - add a `NEWS.md` note.
   - The archived v0.1.0 cannot contain its own DOI. This is normal for
     Zenodo, and the DOI appears from the next version on.
6. **Author action:** update the manuscript's Availability section with the
   package repository and the package DOI (`RELEASE_CHECKLIST.md` §7).

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
3. Tagging, the GitHub release and Zenodo only after explicit approval.

---

## C. Release blockers and decisions

| # | Item | Type | Proposed action |
|---|---|---|---|
| 1 | Absolute scratch paths in `provenance$frozen_md5` names of all 16 fixtures (A.1) | **blocker** | normalise names only, with identity verification; fix generator scripts |
| 2 | Compatibility CI on older R not yet present (Phase 5 decision 3) | **blocker** (by decision) | B.2 |
| 3 | macOS/Windows CI not yet present | required by RC scope | B.3 |
| 4 | Understated `ggplot2` / `testthat` minimum versions (A.3) | fix before release | declare `ggplot2 (>= 3.4.0)`, `testthat (>= 3.1.7)` |
| 5 | Frozen-derived test fixtures in the tarball (A.2) | decision | keep (recommended) |
| 6 | `.zenodo.json` (B.11) | decision | add (recommended) |
| 7 | Support Site registration / BiocCheck ERRORs | not a GitHub-release blocker | later, Bioconductor phase |
