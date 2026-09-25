# Phase 5 Report: user-facing development package

Status: **Phase 5 is approved. The approved decisions (§12) are
implemented.**

- Version unchanged (`0.0.0.9000`); no release has been tagged.
- No Bioconductor submission preparation.

**Baseline and reference:**

- Baseline: `main` @ `982aeb6`.
- Frozen reference: `manuscript-revision-v1.0` →
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`.

Commits on `phase5-docs`:

| Commit | Content |
|---|---|
| `9dfa849` | Add small synthetic example dataset |
| `fc156ef` | Use the example dataset in examples and polish package documentation |
| `c2792a3` | Add task-oriented vignette |
| `dae2361` | Add README, NEWS, CITATION.cff and inst/CITATION |
| `0572127` | Add `tools/validate_against_manuscript.R` |
| `bafeb24` | `PHASE5_REPORT.md` for review |
| `f6a2165` | Apply the approved Phase 5 documentation and metadata decisions |
| this commit | report updated with the approved decisions and final results |

**No scientific or numerical code changed.**

- `git diff main` is empty for the fixtures and all frozen ports:
  `R/constants.R`, `matrix-utils.R`, `covariance.R`, `interval-balance.R`,
  `fit.R`, `crank-nicolson.R`, `bootstrap.R`, `inference.R`, `ode.R`,
  `assay.R`.
- It is also empty for `R/sysdata.rda`, `control.R`, `simulate.R`,
  `domain.R` and `methods.R`.
- Every change to existing R files is a roxygen comment. A check that
  every changed non-comment line is `#'` found none.
- The frozen repository was only read, through `git show`/`git archive` of
  the tag. It is unchanged: the tag still resolves to `65c3b73…`, HEAD is
  `5d06a93` (the author's own commit) and the working tree is clean
  (verified by `tools/validate_against_manuscript.R`, step 7).

---

## 1. README summary

`README.md` covers:

- **Purpose:** kinetic model comparison for post-export RNA conversion.
- **Status:** a development-status banner (not a Bioconductor release).
- **Model:** the four-state table and the ODEs (as plain text); the full
  model (`sigma_c >= 0`) and null model (`sigma_c = 0`).
- **Estimation and statistic:** interval balances, covariance, whitened
  NNLS; `T = max(0, RSS0 - RSS1)` with the generative bootstrap, add-one
  p-value and boundary rule, explicitly **not a likelihood-ratio test**.
- **Interpretation of `sigma_c`:**
  - it is phenomenological;
  - "kinetic patterns consistent with an additional post-export conversion
    component within the model";
  - it does not identify a unique molecular mechanism and is not by itself
    evidence of cytoplasmic splicing.
- **Installation:** `remotes::install_github(...)`, with and without
  vignettes; R ≥ 4.1.0; runtime and suggested dependencies. `remotes` is
  *not* a package dependency.
- **Usage:** a quick start on `postexport_example` (single event: fit,
  summary, test); batch testing with named seeds and `event_error`; BH with
  families; exploratory ranking (formula, not inferential).
- **Plots, simulation and diagnostics:** plots, with the note that the
  curves are display reconstructions; simulation; operational-domain
  diagnostics (no calibration guarantee; NONE anti-conservative).
- **Reference and reproducibility:** the frozen repository, tag and commit;
  Zenodo DOI 10.5281/zenodo.22944109; the manuscript citation, stated as
  submitted; the reproducibility note (bitwise only within a matched
  numerical environment; `MASS::mvrnorm` and LAPACK).
- **Citation and license:** citation instructions; MIT license.

## 2. Vignette outline

`vignettes/postexportKinetics.Rmd`:

- Format: `rmarkdown::html_vignette`, `VignetteBuilder: knitr`.
- MathJax is disabled and formulas are shown as code, so the rendered HTML
  loads nothing from the network.
- It runs on the shipped example data; the build takes about 14 s locally.

| # | Section | Content |
|---|---|---|
| 1 | Overview | purpose, provenance |
| 2 | The four-state model | states, ODEs, rates, full vs null, phenomenological `sigma_c`, onset / `t_star` |
| 3 | Example data and input format | wide format, `time_unit`, destructive replicates; long format from the installed CSV; `columns`; RI inclusion/skipping mapping is the user's responsibility |
| 4 | Validation | errors, warnings and notes; never zero-fills |
| 5 | Fitting | `fit_postexport_model()`, `summary()` |
| 6 | Inference | statistic (not an LRT), generative bootstrap, add-one p, one-sided alternative; batch with named seeds; `B = 499` in the vignette with the `1/(B+1)` floor stated; RNG policy |
| 7 | Interpretation | `sigma_c` (effect size; it can be positive under the null and trades off against `alpha`, as the `alt_3` example shows), IR, p-value, boundary rule, status; low power of the design explained |
| 8 | Multiple testing | explicit BH over valid tests; families; single test |
| 9 | Exploratory ranking | formula; q required; within families; ties; not inferential |
| 10 | Plots | fit (display reconstruction; inference uses interval balances / Crank-Nicolson), bootstrap, `sigma_q` set plot |
| 11 | Simulation | `simulate_postexport_kinetics()`, `plot(sim)` |
| 12 | Operational-domain diagnostics | example design (exact match); `plot(dom)`; NONE anti-conservative |
| 13 | Limitations | phenomenological `sigma_c`; design-dependent calibration; pseudo-shutoff assumptions; benchmark similarity is not a guarantee; continuous transcription anti-conservative; ranking exploratory |
| 14 | Reproducibility and provenance | tag, commit, DOI, platform dependence of bootstrap draws, `citation()` |
| 15 | Session information | `sessionInfo()` |

## 3. Example dataset provenance

`postexport_example` (200 rows: 8 events × 5 time points × 5 replicates,
wide format) and `postexport_example_truth` (8 rows) are in `data/`, with
`LazyData: false`. A long-format copy of the same observations is at
`inst/extdata/postexport_example_long.csv` (38 kB).

**Generation:** `data-raw/postexport_example.R` (excluded from the build)
calls `simulate_postexport_kinetics()`, the ported frozen simulator and
assay-noise model. No real data are used.

- **Design:** one cell of the corrected factorial benchmark.
  - SHUTOFF at `t_star = 332` min.
  - Sampling at `t_star - 10, 0, +10, +20, +30` min, 5 replicates.
  - `param_cv = 0.05`; RNA-seq noise at level `very_low`.
  - Benchmark integration grid (`origin = 0`, `grid_step = 1`,
    `horizon = 1000`, `y0 = 0`).
- **Why this design** (chosen before any data were generated): among the
  benchmark's SHUTOFF designs with at most 10 time points and 5 replicates
  whose Type-I Wilson interval contains 0.05, it had the highest power
  (0.242; Type-I error 0.042).
  - A first draft used RNA-seq `low` with 3 replicates (power 0.104). It was
    replaced so that the example shows at least some signal. This was done
    by choosing the design from the documented benchmark power, not by
    tuning seeds.
  - Every higher-power small SHUTOFF design in the benchmark is strongly
    anti-conservative (Type-I error 0.28–0.63), so none of them was used.
  - `check_operational_domain()` reports an **exact** match.
- **Parameters:** per event, drawn once from the manuscript benchmark ranges
  (frozen `ode_model/ode.r`) with the generator's Gamma(5, 20) for `R`. The
  onset is a uniform integer in [−100, 100], as in the corrected-onset
  generator. `alt_1..4` have `sigma_c > 0`; `null_1..4` have `sigma_c = 0`.
- **Seed:** 20260925, fixed a priori and not tuned. The script reproduces
  the benchmark's parameter *distributions*, not its per-gene random
  streams. The rows were sorted (event, time, replicate) after generation,
  which does not change any result.
- **Results in the vignette** (`B = 499`):
  - `alt_3`: p = 0.008, q = 0.064.
  - All other events: p ≥ 0.136.
  - Two boundary events: `alt_2` and `null_1`.
  - Three null events have `sigma_c` estimates > 0 but non-small p-values.
  - This matches the documented low power and is used in the vignette to
    explain interpretation.
- **Tests:** `test-example-data.R`, 23 expectations:
  - structure and truth consistency;
  - no validation findings;
  - long/wide round trip (1e-14);
  - exact benchmark design;
  - a workflow smoke test (B = 19, two events);
  - plus a check that the defaults table used for "non-default" reporting
    (`.FROZEN_CONTROL_DEFAULTS`) equals the `postexport_control()` formals.
    That table is used only for reporting, and nothing checked this
    before.

## 4. Citation metadata

- **`CITATION.cff` (CFF 1.2.0):**
  - type software; title as in DESCRIPTION; version `0.0.0.9000`; MIT;
    repository URL;
  - full author names; maintainer email; no ORCID; **no package DOI**;
  - `references`: the manuscript, as `type: manuscript` with the note
    "Revised manuscript submitted to Bioinformatics (BIOINF-2026-0699)",
    and the frozen implementation, as software with DOI
    `10.5281/zenodo.22944109`, tag and commit.
  - The YAML parses. Schema validation with `cffr` was not run, because it
    is not installed.
- **`inst/CITATION`:** `citation("postexportKinetics")` gives three entries:
  - the package (Manual, development version, URL);
  - the manuscript (Unpublished, "Revised manuscript submitted to
    Bioinformatics");
  - the frozen implementation (Misc, Zenodo DOI).
  - Checked with `citation()`.
- The manuscript title and submission status are taken from the frozen
  repository's README; nothing is claimed as published.
- `CITATION.cff` is excluded from the package build.

## 5. NEWS summary

`NEWS.md` has one development entry, `0.0.0.9000`, with sections:

- Scientific reference (tag, commit, DOI, ported components, regression
  testing);
- Inference API;
- Simulation and design diagnostics;
- Batch analysis, multiple testing, ranking and plots;
- Documentation and data;
- Not yet available (parallel execution, rMATS conversion, comparators,
  SummarizedExperiment).

It contains no internal debugging history.

## 6. Validation-script behaviour

Usage:

```sh
Rscript tools/validate_against_manuscript.R [--frozen-repo PATH] [--quick]
```

It is run from the package root and documented in the script header and
in `tools/frozen/README.md`. It needs no network access, only a local
clone that contains the tag.

| Step | Check | Local result (macOS) |
|---|---|---|
| 1 | tag resolves to the expected commit; HEAD, status and refs recorded | PASS |
| 2 | read-only export (`export_frozen.sh`); working tree installed into a **temporary library** (the user library is untouched) | PASS |
| 3 | packaged benchmark table MD5 vs frozen files | PASS |
| 4a | Ppp1r36dn and Nsd1 through the public API vs `final_representative_events.tsv` (1e-8 rel) | PASS (rel. 5.5e-16 to 6.7e-15) |
| 4b | all 28 mESC FDR < 0.10 events vs `final_mesc_FDR10_events.tsv` | PASS (max rel. 5.6e-13) |
| 5 | regression suite vs committed fixtures | PASS |
| 6a–c | unless `--quick`: recompute frozen outputs on this platform; strict level A; committed vs recomputed (B/C) | PASS |
| 7 | frozen repository unchanged | PASS |

- **Output and exit status:** PASS/FAIL per step and an overall status
  (`EQUIVALENT` / `REGRESSION`). The script exits with status 1 on any
  failure. The full run takes about 84 s.
- **The full benchmark is not rerun.**
- **Negative check:** the script was run on a scratch copy of the package
  with the default `lambda_diag` perturbed from 0.1 to 0.1000001. Steps
  4a, 4b and 5 failed and the exit status was 1.
  - A first perturbation of `.FROZEN_CONTROL_DEFAULTS` was correctly *not*
    detected, because that table only drives the "non-default" report. The
    new consistency test covers it.
- **CI:** the Linux frozen-reference job now runs the script with `--quick`,
  because that job already performs step 6.

## 7. DESCRIPTION changes

| Field | Change |
|---|---|
| Description | adds simulation, design diagnostics, multiple-testing adjustment, exploratory ranking, tables and plots; keeps the phenomenological caveat |
| Suggests | adds `knitr` and `rmarkdown` |
| VignetteBuilder | `knitr` (new) |
| LazyData | `false` (explicit `data()`) |
| biocViews | adds `MultipleComparison` (approved; public multiple-testing API) and `Visualization` |
| unchanged | Title, Version `0.0.0.9000`, Authors@R (no ORCID), License `MIT + file LICENSE`, URL, BugReports, Encoding `UTF-8`, Imports, `Depends: R (>= 4.1.0)` (kept provisionally, decision 3) |

`.Rbuildignore` now also excludes `CITATION.cff` and rendered vignette
HTML. The `PHASE` pattern is corrected to `^PHASE[0-9_]+_REPORT\.md$`; see
§9.

## 8. SummarizedExperiment decision

**Benefits**

- It is the standard Bioconductor container, so reviewers commonly expect
  interoperability.
- It would address BiocCheck's "No Bioconductor dependencies" WARNING.
- It carries sample annotation (`colData`) and event annotation (`rowData`)
  together.

**Complexity**

- It adds a dependency (24 recursive dependencies in this installation) to
  a package that currently has six.
- It needs a new constructor or converter with validation and tests.
- The main difficulty is the **biological mapping**, which is not unique:
  - **Layout A: four assays** `N`, `N_s`, `C`, `C_s` (events × destructive
    samples), with `colData$time` and `colData$replicate`. This maps
    one-to-one onto `postexport_data()`:
    - `event = rownames(se)`;
    - `time = se$time`;
    - `replicate = se$replicate`;
    - `N = assay(se, "N")`, and likewise for the other states.
    - It is unambiguous, but it is not how compartment data are usually
      stored.
  - **Layout B: libraries as columns.** Nuclear and cytoplasmic fractions
    are separate libraries (`colData$compartment`), with two assays
    (`unprocessed`/`processed`, for example rMATS inclusion and skipping).
    This is closer to real data, but it requires:
    - pairing nuclear and cytoplasmic libraries into one destructive
      sample by (`time`, `replicate`);
    - an inclusion/skipping → unprocessed/processed assignment;
    - a normalisation choice.
    These are the same ambiguities that led to deferring rMATS conversion.
- **Does it materially improve Bioconductor usability?** Only moderately.
  Layout A adds a container, but users must still build four
  state-resolved matrices. Layout B would help, but only with
  assumption-laden decisions.

**Recommendation: defer SummarizedExperiment support from v0.1.**

- If Bioconductor review requires it, implement only Layout A as a thin
  converter, with `SummarizedExperiment` in `Suggests` and no automatic
  pairing, normalisation or inclusion/skipping mapping.
- Revisit Layout B together with rMATS conversion.

## 9. R CMD check results

Final committed state (`f6a2165`), macOS arm64, R 4.6.0, pandoc 3.11 from a
scratch directory (the system was not modified):

- `R CMD build`: OK, with the vignette built.
- `R CMD check --as-cran`, including the manual: **0 ERRORs, 0 WARNINGs,
  2 NOTEs.**
  - CRAN incoming feasibility: new submission; the version contains large
    components (`0.0.0.9000`, intentional).
  - HTML manual: local HTML Tidy is too old and V8 is unavailable, so
    validation was skipped (environment).
  - Tests OK (34 s); vignette re-build OK (13 s); PDF manual OK; examples
    OK. Each example takes ≤ 0.5 s (`B` of 49/99 with an explicit comment).

**Correction to earlier reports:** the "checking top-level files" NOTE in
Phases 1–4 was the non-ignored `PHASE1_5_REPORT.md`, not the missing pandoc
as the Phase 3 and Phase 4 reports stated. The `.Rbuildignore` fix removes
it. `PROJECT_STATE.md` §9 will be corrected when Phase 5 is merged.

**Test suite:** 16 files, **3,677 expectations, 0 failures, 0 errors, 0
warnings, 0 skipped** (Phase 4: 3,654; +23 from `test-example-data.R`). The
approved changes are documentation-only, so the counts are unchanged.

## 10. BiocCheck results

BiocCheck 1.48.1, final tarball (`f6a2165`): **2 ERRORs, 2 WARNINGs, 10
NOTEs** (Phase 4: 3 / 2 / 12; review draft: 2 / 2 / 11).

| Finding | Type | Status |
|---|---|---|
| version not `x.99.z` | ERROR | intentional (`0.0.0.9000`; do not switch yet) |
| Support Site lookup (HTTP 504) | ERROR | maintainer registration and network |
| no vignette | ERROR | **resolved** |
| no Bioconductor dependencies | WARNING | open; see §8 (defer) |
| `set.seed` (2: frozen orchestrator, public simulator) | WARNING | frozen behaviour / documented seed policy |
| NEWS | NOTE | **resolved** |
| R version (4.1.0 → suggests 4.6.0) | NOTE | kept by decision 3, provisionally, pending compatibility CI before 0.1.0 |
| biocViews: suggests `MultipleComparison` | NOTE | **resolved** (added) |
| ORCID, `fnd` role, bioc-devel subscription | NOTE | metadata; no ORCID invented |
| `=`, `paste` in conditions, `<<-`, function length (25), long lines (6, all in frozen `ode.R`), indentation (21%) | NOTE | frozen code style, preserved by decision; new code uses 4 spaces and ≤ 80 characters |

## 11. Linux CI

- **Final Phase 5 code** (`f6a2165`): run `36106757736`, both jobs
  (`package` and `frozen-reference`) succeeded, with every step successful.
- **Review state** (`0572127`): run `36104965575`, details below.

Run `36104965575` on `0572127` (`ubuntu-latest`, R release): **both jobs
succeeded, with every step successful.**

- `package`:
  - pandoc set up;
  - deterministic regression tests on the committed fixtures (level B/C on
    Linux) passed;
  - `check-r-package` (`--as-cran --no-manual`, `error-on: warning`)
    passed, including the vignette build and re-build and the examples.
- `frozen-reference`:
  - tag verified;
  - frozen outputs recomputed from the committed inputs;
  - benchmark MD5 matches;
  - same-platform strict level A passed, including bootstrap draws;
  - cross-platform B/C passed;
  - the new end-to-end step `tools/validate_against_manuscript.R --quick`
    passed on Linux (the step fails on any FAIL, since the script exits
    with status 1);
  - frozen clone verified unchanged.
- Annotations are notices only:
  - level-C bootstrap-draw differences, reported and not compared, as in
    earlier phases;
  - fixture case counts;
  - the `ubuntu-latest` → Ubuntu 26 migration notice.
- Raw job logs require authentication and were not read. Results are taken
  from the job and step conclusions and the annotations.

**CI runner notice:** GitHub announced that `ubuntu-latest` migrates to
Ubuntu 26 from 2026-10-19. As instructed, CI stays on `ubuntu-latest`,
since there is no concrete compatibility reason to pin. The notice is
recorded here and in `RELEASE_CHECKLIST.md` §3a: after the migration,
confirm that the level A/B/C results are unchanged and record the new
LAPACK/BLAS provenance.

## 12. Approved decisions (review of this report)

1. **Example dataset:** keep the calibrated, modest-power design. Its
   documentation (`?postexport_example`, the vignette and
   `data-raw/postexport_example.R`) now states that:
   - the design was selected from the benchmark table before data
     generation;
   - the seed was fixed a priori;
   - there was no seed search;
   - benchmark power is about 0.24.
2. **Bootstrap counts:** `B = 499` in the vignette and `B = 49`/`99` in the
   examples, as before.
   - The vignette states the floor `1/(B+1)`, here 0.002.
   - Every executable example with a small `B`, and the README batch
     example, now says that it is used only for speed and is not
     recommended for final scientific analysis.
3. **R version:** `Depends: R (>= 4.1.0)` is kept provisionally.
   - The README states that the package is tested only with the current
     release and that older releases have not been checked.
   - Before 0.1.0, a compatibility CI job on at least one older supported
     R release is required (`RELEASE_CHECKLIST.md` §4).
   - A concrete incompatibility would be reported before `DESCRIPTION` is
     changed.
4. **biocViews:** `MultipleComparison` is added and `Visualization` kept.
5. **SummarizedExperiment:** deferred from v0.1. No Bioconductor dependency
   is added merely to remove the BiocCheck warning.
   - Layout A (four state assays) is a possible future thin converter.
   - Layout B needs pairing, normalisation and mapping decisions.
   - Revisit during Bioconductor submission preparation.
6. **Citation metadata:** the manuscript stays unpublished/submitted, and
   there is no package DOI. `10.5281/zenodo.22944109` is the frozen
   manuscript implementation. A package DOI will be added only after the
   first GitHub release is archived on Zenodo.
7. **Release version:** the first public GitHub release will be `0.1.0`;
   the Bioconductor line `0.99.0` comes later and is not used for the
   GitHub release (`RELEASE_CHECKLIST.md` §4). No release has been created
   or tagged.

## 13. Recommended next steps

**Next: a separate release-candidate plan for `0.1.0`** (after merge and
documentation). It should cover:

- the version bump to `0.1.0`;
- compatibility CI on an older R release;
- macOS/Linux/Windows checks where feasible;
- full manuscript validation;
- README/CITATION/NEWS synchronisation;
- release tarball inspection;
- GitHub release preparation;
- Zenodo archival planning.

The outline below remains the reference.

**Toward a first public GitHub release:**

1. Merge Phase 5 (`--no-ff`); done after approval.
2. Add compatibility CI on an older R release (decision 3).
3. Bump the version to `0.1.0` (decision 7) and synchronise `DESCRIPTION`,
   `NEWS.md`, `CITATION.cff` and `inst/CITATION`.
4. Run `RELEASE_CHECKLIST.md` §1–3a:
   - full `tools/validate_against_manuscript.R`;
   - `R CMD check` on macOS and Linux, and Windows if possible;
   - Linux CI green.
5. Tag a GitHub release and archive it on Zenodo. Record the package DOI
   only after it is minted.
6. Update the manuscript Availability section (author action).

**Later Bioconductor submission (not started):**

- move to `0.99.0`;
- decide on SummarizedExperiment (Layout A thin converter, if requested);
- maintainer Support Site registration and bioc-devel subscription;
- optional ORCID, supplied by the authors;
- re-run BiocCheck and address the remaining style NOTEs outside the frozen
  ports only;
- submit.
