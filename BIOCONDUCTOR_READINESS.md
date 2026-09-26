# Bioconductor readiness report (Phase 6C/6D)

Status: **GO FOR FINAL SUBMISSION PREPARATION (§19).**

- Full networked BiocCheck: **0 ERRORs / 1 WARNING (`set.seed`, accepted
  with a reviewer-exception request) / 10 NOTEs**.
- `bioconductor-prep` is merged into `main` (`236f509`), and all workflows
  are green.
- `devel` is verified A–E.
- **Stopped for explicit approval to switch the default branch and
  submit.** The Contributions issue is not opened.

- The Contributions issue has not been opened, and nothing was submitted.
- The GitHub default branch is unchanged (`main`).
- `v0.1.0` is untouched (tag → `04c4407`).
- No frozen scientific code was changed.

## 1. Branches and Source-Commit mapping

| Item | Value |
|---|---|
| Development branch | `bioconductor-prep`; CI, tools, provenance infrastructure, reports and the scientific regression gates |
| **Development source commit** of the current package-only export | **`9fd96d9e68d15903eb492563d2ee0fde7f41fe9b`**: the AI-attribution commit (§12.4). Later development commits (`f313fb9`, this report) change only tools and reports, so no new `devel` commit is created. |
| **`devel`** (package-only branch, pushed, **not default**) | **`05ba5a8cbc1b1e8dcc3ffa6fc9b3863a0038692e`**: "package-only export of 9fd96d9" / `Source-Commit: 9fd96d9e68d15903eb492563d2ee0fde7f41fe9b`; tree `45ba02ed208ec6647d981be289fbb27ecc1e32cb`; parent `e3202a8` |
| Earlier exports | `e3202a8` ← `f6e1bfb` (tree `f5000fb…`) and `ad31ab9` ← `271c573` (tree `a94294e…`) |
| `devel` content | `.Rbuildignore`, `.gitignore`, `CITATION.cff`, `DESCRIPTION`, `LICENSE`, `NAMESPACE`, `NEWS.md`, `README.md`, `R/`, `data/`, `inst/`, `man/`, `tests/`, `vignettes/` (allowlist `tools/release/package_allowlist.txt`) |
| `devel` history | linear: `ad31ab9` (root) → `e3202a8` → `05ba5a8`; normal pushes, no force |
| GitHub default branch | `main` (unchanged) |

## 2. Tooling added (development branch only)

**`tools/release/make_package_branch.sh <SHA> [branch]`:**

- allowlist export through git plumbing (a temporary index), without
  touching the working tree or the current branch;
- one normal commit per export, carrying the `Source-Commit` trailer;
- fast-forward only (`update-ref` with the expected old tip);
- no push;
- no empty commit when the tree is unchanged.

**`tools/release/verify_package_branch.sh [branch]`** runs checks A to E:

- **A.** The exact tree matches a fresh export of the Source-Commit.
- **B.** `R CMD build` of `X` and of `devel` gives identical tarball content;
  only the `Packaged:` line of DESCRIPTION may differ. On failure it adds a
  diagnostic control build of `X` against itself, without changing the
  verdict.
- **C.** Tarball hygiene (`tools/ci/inspect_tarball.R`).
- **D.** `BiocCheckGitClone()` on a clone of `devel`.
- **E.** Identical DESCRIPTION, CITATION.cff, inst/CITATION and NAMESPACE.

A negative test with a tampered one-line README on a throwaway local branch
failed A and B, and the script exited 1. The branch was deleted.

**`.github/workflows/bioc-devel.yml`** runs in
`bioconductor/bioconductor_docker:devel`:

- install, regression tests, `R CMD build`, `R CMD check`
  (fails on ERROR/WARNING), networked BiocCheck (fails on any ERROR except
  the maintainer-side `checkSupportReg` / `checkWatchedTag`);
- a `package-branch` job running `verify_package_branch.sh devel`.

It supplements linux-regression, platforms and r-compat, which are
unchanged.

**CI maintenance:** `actions/upload-artifact` v4 → **v6** (Node.js 24),
with identical inputs. It is used only by `release-candidate.yml`, which runs
on `main` / `release-*`. It will first be exercised at the next `main` push.

## 3. Verification results

| Check | Local, `devel` @ `e3202a8` ← `f6e1bfb` (macOS, R 4.6.0) | CI, `devel` @ `ad31ab9` ← `271c573` (Bioconductor devel container, run on `5daa6ba`) |
|---|---|---|
| A. exact tree | PASS (`f5000fb…`) | PASS (`a94294e…`) |
| B. tarball equivalence | PASS (90 files; only `Packaged:` differs) | PASS (90 files) |
| C. tarball hygiene | PASS | PASS |
| D. **BiocCheckGitClone(devel)** | **0 ERRORS / 0 WARNINGS / 0 NOTES** | **0 / 0 / 0** |
| E. version / citation / API | PASS (0.99.0; 10 exports) | PASS |

**CI verification of the current `devel` (`e3202a8` ← `f6e1bfb`), run
`36185810683` on `f6d037f`:** A, C, D and E pass (BiocCheckGitClone 0/0/0),
but **B FAILS**. The only differing file is again
`inst/doc/postexportKinetics.html`. The diagnostic control build of the same
source reproduced the first build exactly, so nondeterminism was not shown
within a single job.

**Finding on check B:** in one earlier CI run (`3ec0025`, run `36180831285`),
B failed.

- The only difference was the bytes of one embedded base64 PNG figure in the
  built vignette HTML (`inst/doc/postexportKinetics.html`, line 937). The
  sources were byte-identical (A passed).
- The same comparison passed locally and in the next CI run (`5daa6ba`).
- This is intermittent figure-encoding nondeterminism when building the
  vignette in the container, not a branch difference.
- B was **not relaxed**. It still allows only `Packaged:`. The diagnostic
  control build will show directly whether any recurrence is build
  nondeterminism (`X` differs from itself).
- **Recurrence (`f6d037f`, run `36185810683`):**
  - B failed again on the rendered vignette HTML only;
  - the control build of the source reproduced the first source build;
  - the trees are identical (A), and every non-vignette file is identical;
  - locally, B passes consistently.
- **Status: unresolved and intermittent.** Across the three CI runs it failed
  twice and passed once. The cause, probably rendering nondeterminism in the
  vignette figures, is **not yet demonstrated**.
- **Proposed investigation (needs approval):** extend the B diagnostic to
  decode each embedded PNG from both HTML files and compare them
  pixel-wise (for example with the `png` package, in CI only).
  - Pixel-identical images mean encoding nondeterminism.
  - Differing pixels mean a rendering difference, and identify the figure.
- **Decision:** whether B may then treat embedded vignette images as a
  controlled exception, or must stay strict. **Until decided, the
  package-branch gate is not green.**

## 4. Checks on the final package content (`0.99.0`; `R/`, `man/`, `data/`, `inst/`, `tests/` and `vignettes/` identical between trees `a94294e…` and `f5000fb…`)

| Check | Result |
|---|---|
| testthat | 17 files, **3,708 expectations, 0 failures / errors / warnings / skips** |
| `R CMD check --as-cran` (local, macOS; tarball built from `devel`) | **0 ERRORs, 0 WARNINGs, 2 NOTEs**: CRAN incoming feasibility (new submission); HTML-manual validation skipped (old local HTML Tidy / no V8) |
| **`R CMD check` (Bioconductor 3.24 devel, R 4.6.1, container)** | **Status: OK** |
| **BiocCheck, full networked** (local 1.48.1; `devel` tarball) | **1 ERROR, 1 WARNING, 10 NOTEs** |
| BiocCheck (Bioconductor 3.24 devel, container) | 1 ERROR `checkWatchedTag`, 1 WARNING `checkCodingPractice` (`set.seed`), 9 NOTEs |
| **Full `tools/validate_against_manuscript.R`** | **EQUIVALENT**: 10/10 PASS, including same-platform level A with bootstrap draws; frozen repository unchanged |
| Frozen ports, fixtures, `R/sysdata.rda`, data | unchanged versus `main` / `v0.1.0` (`git diff` empty) |
| Frozen repository | tag → `65c3b7368fb7686bfde3dab857f98c393bb534c5`, HEAD `5d06a93`, clean |

## 5. CI results (development branch)

| Workflow | Run on `5daa6ba` | Result |
|---|---|---|
| linux-regression (frozen-reference scientific gate and package) | `36183026944` | **success** |
| platforms (macOS, Windows; R 4.6.1) | `36183026990` | **success** |
| r-compat (R 4.1.3 with Bioconductor 3.14 / SummarizedExperiment 1.24.0; R 4.5.3) | `36183027013` | **success** |
| **bioc-devel** (`bioc-devel` and `package-branch` jobs) | `36183026953` | **success** |
| bioc-devel on `f6d037f` (current `devel` `e3202a8`) | `36185810683` | `bioc-devel` job **success** (R CMD check OK; BiocCheck 1E `checkWatchedTag` / 1W / 9N); `package-branch` job **failure** (check B, §3) |
| linux-regression, platforms, r-compat on `f6d037f` | `36185810688`, `36185810691`, `36185810608` | **success** |

The earlier runs on this phase's commits:

| Commit | Result |
|---|---|
| `5b1467e` | bioc-devel job failed only because `checkWatchedTag` was not yet whitelisted, and package-branch had no annotations; the other three workflows green |
| `3ec0025` | package-branch B failed as described in §3; bioc-devel job and the other three green |

## 6. Maintainer-action status

| Action | Status |
|---|---|
| Bioconductor Support Site registration | **done** (BiocCheck: "Maintainer is registered at support site") |
| Add `postexportKinetics` to **Watched Tags** | **pending until the maintainer confirms completion** (in progress). It is the only BiocCheck ERROR (`checkWatchedTag`, still present in the networked BiocCheck of 2026-09-26). The check is not simulated or bypassed. |
| bioc-devel mailing list | **done** (maintainer). BiocCheck cannot verify it ("requires admin credentials"); this NOTE is not a package failure. |
| GitHub SSH public key | **done** (maintainer) |
| Default-branch switch to `devel` | **pending**, immediately before submission (§8) |
| ORCID / `fnd` | optional; only if supplied by the authors (not invented) |

## 7. Remaining findings and justification

| Level | Finding | Location | Justification / action |
|---|---|---|---|
| ERROR | `checkWatchedTag`: add the package to Watched Tags | Support Site profile | maintainer action (§6) |
| WARNING | `set.seed()` ×2 | `R/inference.R:89` (frozen orchestrator); `R/simulate.R:371` (public simulator) | kept by decision; wording in §7.1 |
| NOTE | R version dependency 4.1.0 → 4.6.0 | DESCRIPTION | `R (>= 4.1.0)` is verified by CI on R 4.1.3 (Bioconductor 3.14); kept by decision |
| NOTE | ORCID; `fnd` role | Authors@R | optional; only if supplied by the authors |
| NOTE | `=` assignment; paste in conditions (5 sites); `<<-` (2) | frozen `assay.R`, `bootstrap.R`, `covariance.R`, `inference.R` | frozen verbatim ports (§7.2) |
| NOTE | 26 functions > 50 lines | 13 frozen; 13 package-authored (validation-heavy) | no refactoring, by decision (§7.2) |
| NOTE | 6 lines > 80 characters | frozen `ode.R` (comment rulers) | frozen (§7.2) |
| NOTE | 4-space indentation (1,686 lines) | frozen ports; argument-alignment continuation lines | no styler pass, by decision (§7.2) |
| NOTE | bioc-devel subscription undeterminable | — | subscribed by the maintainer; not verifiable by BiocCheck |

### 7.1 `set.seed()` review wording (for the submission issue)

> **set.seed() (BiocCheck WARNING, 2 sites).**
>
> **(1) `R/inference.R` (frozen orchestrator).** This is a verbatim port
> of the frozen manuscript implementation. It is preserved for exact
> manuscript-method reproducibility and protected by frozen-reference
> regression tests (bootstrap draws compared at the same-platform strict
> level). It is used only when the user sets `postexport_control(seed =)`.
> The public API restores the caller's RNG state.
>
> **(2) `R/simulate.R`, `simulate_postexport_kinetics(seed =)`.** An
> explicit user-facing reproducibility argument. The caller's RNG state is
> restored on exit (tested), and `seed = NULL` (the default) leaves RNG
> control entirely to the caller.
>
> Neither sets a seed silently in internal code.

### 7.2 Frozen-code style justification (for the submission notes)

| Finding | Where | Why unchanged |
|---|---|---|
| `=` assignment, paste in conditions, `<<-`, long lines, indentation, long functions | the ten frozen ports (`constants.R`, `matrix-utils.R`, `covariance.R`, `interval-balance.R`, `fit.R`, `crank-nicolson.R`, `bootstrap.R`, `inference.R`, `ode.R`, `assay.R`) | Verbatim ports of the validated manuscript implementation (tag `manuscript-revision-v1.0`), enforced by `test-verbatim-port.R` and by the frozen-reference regression gate. Restyling would break the verbatim guarantee without user benefit. |
| long functions and continuation indentation | package-authored code | Mostly argument validation and messages. Refactoring only for the NOTE would add regression risk; block indentation follows the 4-space rule, lines ≤ 80 characters. |

## 8. Default-branch switch (maintainer, immediately before submission)

1. **Freeze development.** Merge the approved development branch into
   `main`, or keep submitting from `bioconductor-prep`, as decided.
   Confirm that all four workflows are green on the final development
   commit `F`.
2. **Refresh `devel` if the package content changed.**

   ```sh
   git checkout <development branch>
   sh tools/release/make_package_branch.sh F
   sh tools/release/verify_package_branch.sh devel
   git push origin devel
   ```

   The verification must print `PACKAGE BRANCH VERIFICATION PASSED`. Never
   use `--force`.
3. **Confirm the bioc-devel `package-branch` job** is green on `F`.
4. **Switch the default branch on GitHub:**
   - repository **Settings** → **General** → **Default branch**;
   - click the switch (⇄) icon, select **`devel`**, **Update**, and confirm
     "I understand, update the default branch".
5. **Check the switch:**
   - `git ls-remote --symref https://github.com/bioinformatics-sannio/postexportKinetics HEAD`
     shows `refs/heads/devel`;
   - a fresh `git clone` checks out only package files;
   - `BiocCheck::BiocCheckGitClone()` on that clone gives 0/0/0.
6. **Open the Contributions issue** (§9) only after explicit approval.

Consequences of the switch:

- CI keeps running on the development branches (`devel` has no workflows).
- New pull requests default to `devel`.
- The `v0.1.0` tag and release are unaffected.
- After acceptance, updates are pushed from `devel` to git.bioconductor.org
  with the maintainer's SSH key, each with a version bump.

## 9. Proposed Bioconductor Contributions issue

Template: `Bioconductor/Contributions/.github/ISSUE_TEMPLATE/issue_template.md`,
read on 2026-09-25.

- **Title:** `postexportKinetics`
- **Body:**

```markdown
Update the following URL to point to the GitHub repository of
the package you wish to submit to _Bioconductor_

- Repository: https://github.com/bioinformatics-sannio/postexportKinetics

Confirm the following by editing each check box to '[x]'

- [x] I understand that by submitting my package to _Bioconductor_,
  the package source and all review commentary are visible to the
  general public.
- [x] I have read the _Bioconductor_ Package Submission
  instructions. My package is consistent with the _Bioconductor_
  Package Guidelines.
- [x] I understand Bioconductor Package Naming Policy and acknowledge
  Bioconductor may retain use of package name.
- [x] I understand that a minimum requirement for package acceptance
  is to pass R CMD check and R CMD BiocCheck with no ERROR or WARNINGS.
  Passing these checks does not result in automatic acceptance. The
  package will then undergo a formal review and recommendations for
  acceptance regarding other Bioconductor standards will be addressed.
  **Current status, stated explicitly:** R CMD check: 0 ERRORs /
  0 WARNINGs. BiocCheck: 0 ERRORs / **1 WARNING** (`set.seed`, 2 sites).
  We request a reviewer exception for this intentional, documented
  warning; the justification is under "Additional information" below.
- [x] I understand Bioconductor's AI and Third Party Code policy and will
  acknowledge accordingly if applicable.   <-- see note B below
- [x] My package addresses statistical or bioinformatic issues related
  to the analysis and comprehension of high throughput genomic data.
- [x] I am committed to the long-term maintenance of my package. ...
- [x] I understand it is my responsibility to maintain a valid, active
  maintainer email in the DESCRIPTION of my package. ...
- [x] I am familiar with the Bioconductor code of conduct and
  agree to abide by it.

I am familiar with the essential aspects of _Bioconductor_ software
management, including:

- [x] The 'devel' branch for new packages and features.
- [x] The stable 'release' branch, made available every six
      months, for bug fixes.
- [x] _Bioconductor_ version control using Git
  (optionally via GitHub).

**Additional information**

postexportKinetics fits a compartment-resolved four-state kinetic model of
nuclear and cytoplasmic, unprocessed and processed RNA. It compares a null
model (sigma_c = 0) with a full model (sigma_c >= 0) using trapezoidal
interval balances, propagated covariance, whitened NNLS and a
replicate-level generative bootstrap with an add-one p-value. sigma_c is a
phenomenological post-export conversion rate and does not identify a
molecular mechanism. SummarizedExperiment input is supported through
postexport_data_from_se() (four state assays, events by destructive
samples).

- R CMD check: 0 ERRORs / 0 WARNINGs (Bioconductor devel: Status OK).
  BiocCheckGitClone: 0 / 0 / 0.
- BiocCheck: 0 ERRORs / 1 WARNING (set.seed) / NOTEs, listed below. The
  WARNING is intentional and documented, and we request a reviewer
  exception. The NOTEs relate mainly to the verbatim-ported scientific
  core. [Exact counts to be filled from the final networked BiocCheck.]
- set.seed justification (reviewer exception request): [text of section 7.1]
- Frozen-code style: [table of section 7.2]
- Provenance: the numerical core is ported verbatim from the frozen
  manuscript implementation (github.com/bioinformatics-sannio/postexport-kinetics,
  tag manuscript-revision-v1.0, doi:10.5281/zenodo.22944109; the DOI of that
  implementation, not of this package), by the same authors, under MIT,
  and is regression-tested against it. The associated manuscript is
  submitted and not yet published. A GitHub release v0.1.0 exists; the
  package has no DOI.
- AI assistance: Development of the package-authored code, tests and
  documentation was assisted by Claude Code (Anthropic) under the authors'
  direction and review. The scientific numerical core is ported verbatim
  from the authors' frozen manuscript implementation and is
  regression-tested against it.
```

**Note A (the "no ERROR or WARNINGS" checklist item): RESOLVED BY
DECISION (2026-09-26).**

- `set.seed` status: **accepted for submission with explicit
  justification and a reviewer-exception request; no longer a blocker.**
  - It is no longer awaiting bioc-devel guidance.
  - Both implementations stay unchanged: the frozen orchestrator exactly;
    `simulate_postexport_kinetics(seed =)`; caller-RNG restoration; the
    `seed = NULL` semantics.
- **Checkbox:** ticked as a statement of *understanding* of the
  requirement. The adjacent text states the actual status explicitly (R CMD
  check 0/0; BiocCheck 0 ERRORs / 1 WARNING) and requests the exception, so
  the item is not represented falsely. BiocCheck is never described as
  having zero warnings.

**Note B (blocking decision).** The AI and Third Party Code policy says:

> If a non-trivial portion of your contribution is copied from somewhere
> else (such as AI-generated or copied from another software project) you
> are required to discuss it in the issue and disclose it in the PR
> description and provide details about the provenance.

It also asks for attribution such as "Assisted-by: Name of AI" or "Code
copied from: source" in the code itself.

- The package-authored code, tests, documentation and tooling were developed
  with AI assistance (every commit carries a `Co-Authored-By: Claude`
  trailer).
- The ten frozen ports already state "Ported verbatim from
  postexport-kinetics@manuscript-revision-v1.0": same authors, MIT.
- **Implemented, as approved (§12.4).** `# Assisted-by: Claude Code
  (Anthropic)` is in the package-authored files; the frozen ports are
  unchanged. The issue will include the approved disclosure:

  > Development of the package-authored code, tests and documentation was
  > assisted by Claude Code (Anthropic) under the authors' direction and
  > review. The scientific numerical core is ported verbatim from the
  > authors' frozen manuscript implementation and is regression-tested
  > against it.

  The human maintainer remains responsible for every submitted line.

## 10. Other items

- **Ubuntu 26 migration** of `ubuntu-latest` from 2026-10-19; the runners
  are not pinned.
  - If submission happens after the migration, first re-run the full Linux
    scientific gate, record the new LAPACK/BLAS provenance, and require the
    level A/B/C policy to stay satisfied.
  - If submission happens before it, this becomes a post-submission CI
    maintenance item.
- **Development-branch merge.** `bioconductor-prep` is not yet merged into
  `main`. Recommendation: merge (`--no-ff`) after approval, so that the
  long-lived development branch holds Phase 6. Then re-export `devel` from
  the merge commit; its tree is unchanged, so no new `devel` commit is
  expected.

## 11. Go / no-go

**Recommendation: NO-GO.** GO is not recommended while the `set.seed`
submission-policy question is unresolved. Open items, in order:

1. **Check B:** intermittent **pixel-level rendering nondeterminism** of
   one vignette figure in the Bioconductor devel container (§12.1). The
   approved controlled exception correctly does **not** apply, because the
   pixels differ, so B fails intermittently.
   - It is not a branch or content difference: A passes, and two builds of
     the same source differ.
   - **Decision needed:** one of
     - (a) make the vignette figures deterministic in that environment (a
       vignette-only change, e.g. a different knitr graphics device); this
       needs approval and must be shown effective across repeated runs;
     - (b) keep B strict and treat a failure as a re-run trigger, with the
       control diagnostic recorded each time;
     - (c) another policy.
2. **Watched Tags:** the maintainer confirms completion. Then re-run the
   full networked BiocCheck and require **0 ERRORs**.
3. **`set.seed`:** accepted for submission with explicit justification and
   a reviewer-exception request (Note A); no longer a blocker.
4. After items 1–3: merge `bioconductor-prep` into `main` (`--no-ff`);
   re-export and verify `devel` from the final commit (all of A–E); all
   workflows green.
5. The maintainer switches the default branch to `devel` (§8).
6. Explicit human approval to open the Contributions issue (§9).

Package quality is otherwise ready:

- Bioconductor-devel `R CMD check` OK; BiocCheckGitClone 0/0/0;
- full scientific validation EQUIVALENT;
- Linux, macOS, Windows, R 4.1.3 and R 4.5.3 green;
- AI attribution in place;
- no package DOI, and the frozen DOI correctly labelled.

## 12. Final pre-submission resolutions (2026-09-26)

### 12.1 Check B: root-cause classification

The decoded-image diagnostic `tools/release/compare_built_packages.R`
(§12.2) replaced the plain `diff -r` verdict of check B in
`verify_package_branch.sh`.

**CI history of check B** (`package-branch` job, Bioconductor 3.24 devel
container, R 4.6.1, Ubuntu 24.04), all on package-identical content:

| Development commit (run) | `devel` checked | Check B | Evidence |
|---|---|---|---|
| `3ec0025` (`36180831285`) | `ad31ab9` | FAIL | only the vignette HTML differed (embedded PNG); before the image diagnostic existed |
| `5daa6ba` (`36183026953`) | `ad31ab9` | PASS | strict, identical |
| `f6d037f` (`36185810683`) | `e3202a8` | FAIL | only the vignette HTML differed; a second build of the source matched the first (plain-diff control) |
| `9fd96d9` (`36202941565`) | `05ba5a8` | **FAIL** | decoded images: **embedded PNG #5 pixels differ, 3,355 values, image 360×504×3**. The **control** (two builds of the same source `9fd96d9`) **also differs** in PNG #5 pixels. |
| `f313fb9` (`36204280117`) | `05ba5a8` | PASS | strict, identical (90 files) |

- **Classification: `RENDERING_NONDETERMINISM` (pixel level)**, not
  `VIGNETTE_PNG_ENCODING_ONLY`.
  - Embedded figure #5 of the vignette is the operational-domain plot,
    `plot(dom)` (layers: vline, errorbar, point; no jitter or random
    positions in `R/plot.R` or `R/domain.R`).
  - Its pixels intermittently differ between two renderings of **identical
    source** in the container.
  - It is therefore **not a difference between X and `devel`** (A: trees
    identical).
- **Local reproduction:** none. On macOS, R 4.6.0, the domain plot rendered
  three times in each of two processes was pixel-identical with both the
  quartz and the cairo `png()` devices.
- The exact mechanism in the container, presumably the cairo/fontconfig
  text or anti-aliasing path, is not yet localised. The comparator now
  reports the bounding box and the maximum difference of the differing
  pixels at the next recurrence. The last run (`f313fb9`) passed, so there
  is no bounding box yet.
- **Impact:** none on the science or on package behaviour. It affects only
  the byte and pixel reproducibility of one rendered vignette figure in one
  build environment.

### 12.2 Decoded-image comparison and controlled-exception rule

`compare_built_packages.R <dirA> <dirB>` gives one of three verdicts:

- **IDENTICAL:** every file is byte-identical, ignoring only the
  R-generated `Packaged:` line. B passes.
- **VIGNETTE_PNG_ENCODING_ONLY (controlled exception):** B passes with an
  explicit message only if **all** of the following hold:
  - the sole differing file is `inst/doc/postexportKinetics.html`;
  - the HTML is byte-identical once each embedded
    `data:image/png;base64,…` payload is replaced by a placeholder;
  - both files contain the same number of embedded PNGs;
  - every differing pair decodes (`png::readPNG`) to arrays with identical
    dimensions and channel structure and **exactly identical pixel
    values**.
- **DIFFERENT:** anything else. This includes any other differing, missing
  or additional file, surrounding-HTML changes, differing image count,
  dimensions or channels, any pixel difference, or an undecodable image.
  B fails.

Check A (the source-tree identity) is required separately. Checks A, C, D
and E are unchanged.

- **Dependencies:** `png` and `jsonlite` are CI/development-only; they are
  installed in the bioc-devel `package-branch` job and are **not** package
  dependencies.
- **Activation:** the exception has **not been triggered by any real run**.
  The only observed real differences were pixel-level (§12.1), and B
  correctly failed on them.

### 12.3 Mutation and negative tests

`tools/release/test_compare_built_packages.R` has **14 of 14 expectations
met**, locally and in CI (the bioc-devel `package-branch` job, runs
`36202941565` and `36204280117`):

| Case | Expected verdict | Result |
|---|---|---|
| identical content, only `Packaged:` differs | IDENTICAL | met |
| byte-different, pixel-identical PNG (re-encoded with a PNG text chunk) | VIGNETTE_PNG_ENCODING_ONLY | met |
| one-pixel difference | DIFFERENT | met |
| surrounding HTML changed (PNGs identical) | DIFFERENT | met |
| surrounding HTML changed and a PNG re-encoded | DIFFERENT | met |
| non-vignette file changed | DIFFERENT | met |
| non-vignette file changed and a PNG re-encoded | DIFFERENT | met |
| image dimensions differ | DIFFERENT | met |
| channel structure differs (RGB vs RGBA) | DIFFERENT | met |
| image count differs | DIFFERENT | met |
| additional file | DIFFERENT | met |
| real vignette: figure 1 re-encoded, pixel-identical | VIGNETTE_PNG_ENCODING_ONLY | met |
| real vignette: figure 1 one-pixel difference | DIFFERENT | met |
| real vignette: one character of text changed | DIFFERENT | met |

The earlier branch-level negative test (a tampered README on a throwaway
branch) failed A and B, as required.

### 12.4 AI-assistance attribution (implemented)

Commit `9fd96d9` adds the single comment line
`# Assisted-by: Claude Code (Anthropic)` at the top of **32 files**:

- the 12 package-authored `R/` files: `api.R`, `batch.R`, `control.R`,
  `data-docs.R`, `data.R`, `domain.R`, `globals.R`, `methods.R`, `plot.R`,
  `postexportKinetics-package.R`, `se.R`, `simulate.R`;
- the 19 test files `tests/testthat/*.R`;
- `inst/scripts/generate_postexport_example.R`.

No model or version is stated. The **ten frozen ports are unchanged** and
keep "Ported verbatim from postexport-kinetics@manuscript-revision-v1.0".

The change is comment-only:

- 35 inserted lines (32 attributions and 3 blank separators before roxygen
  blocks);
- roxygen regeneration leaves `man/` and `NAMESPACE` unchanged;
- tests: 3,708 expectations, 0 failures;
- `R CMD check`: 2 NOTEs;
- full validation: EQUIVALENT;
- the example data are still reproduced byte-for-byte by the provenance
  script.

### 12.5 Full networked BiocCheck (2026-09-26, `devel` tarball)

**1 ERROR, 1 WARNING, 10 NOTEs** (BiocCheck 1.48.1; bioconductor.org
reachable):

- ERROR `checkWatchedTag` (maintainer, pending);
- WARNING `set.seed` (at the time awaiting guidance; since 2026-09-26 accepted with a reviewer-exception request, see §18);
- NOTEs as in §7.

"Maintainer is registered at support site." The Bioconductor devel
container gives the same ERROR and WARNING, with 9 NOTEs. The **0 ERRORs**
required for GO has **not** been reached; the run will be repeated after
the maintainer confirms Watched Tags.

### 12.6 Current package-only branch and verification

- **`devel` = `05ba5a8`**, Source-Commit
  **`9fd96d9e68d15903eb492563d2ee0fde7f41fe9b`**, tree `45ba02e…`.
  It was refreshed because `R/`, `tests/` and `inst/` changed (attribution).
- **`verify_package_branch.sh devel`:**
  - locally (macOS): A PASS; B PASS (strict IDENTICAL, 90 files); C PASS;
    D BiocCheckGitClone 0/0/0; E PASS (0.99.0, 10 exports);
  - CI `f313fb9` (run `36204280117`): all PASS, B strict;
  - CI `9fd96d9` (run `36202941565`): B FAIL (pixel-level, §12.1), A, C,
    D and E PASS.

### 12.7 Scientific and platform gates (latest)

| Gate | Result |
|---|---|
| testthat (local) | 17 files, 3,708 expectations, 0 failures |
| `R CMD check --as-cran` (local) | 0 ERRORs, 0 WARNINGs, 2 NOTEs |
| `R CMD check` (Bioconductor 3.24 devel) | Status: OK |
| full `tools/validate_against_manuscript.R` | **EQUIVALENT** (local, `9fd96d9`) |
| linux-regression (scientific gate), platforms (macOS, Windows), r-compat (R 4.1.3 / Bioc 3.14; R 4.5.3) | **success** on `f313fb9` (`36204280071`, `36204280067`, `36204280147`) and on `9fd96d9` |
| bioc-devel | success on `f313fb9` (`36204280117`); failure on `9fd96d9` (check B only) |
| frozen repository | tag → `65c3b7368fb7686bfde3dab857f98c393bb534c5`; unchanged |
| `v0.1.0` | untouched (→ `04c4407`) |
| default branch | `main` (not switched) |

### 12.8 Maintainer status

| Item | Status |
|---|---|
| Support Site registration | DONE |
| bioc-devel subscription | DONE |
| GitHub SSH public key | DONE |
| Watched Tags | pending until the maintainer confirms completion |
| Default-branch switch | pending |
| ORCID / funder | optional |
| `set.seed` | accepted with justification and reviewer-exception request (§18) |

## 13. Deterministic vignette rendering: option (a), first device attempt (2026-09-26)

### 13.1 Change

- **Commit `9159c6d` (vignette only).** The setup chunk now sets
  `knitr::opts_chunk$set(..., dev = "svg")`: base R `grDevices::svg()`
  (cairo), with no new dependency.
- No `plot()` method, data, inference or numerical output changed.
- Local gates on `35a5112`:
  - tests: 3,708 expectations, 0 failures;
  - `R CMD check`: 2 NOTEs;
  - BiocCheck: 1 ERROR `checkWatchedTag` / 1 WARNING `set.seed` / 10
    NOTEs;
  - full validation: EQUIVALENT.
- **Commit `35a5112` (CI).** New `vignette-determinism` job in
  `bioc-devel.yml`:
  - builds the **same source 11 times** (reference and 10 repeats) in the
    Bioconductor devel container;
  - requires each repeat to be **strictly IDENTICAL** to the reference,
    under the check-B rule, with no PNG exception.

### 13.2 Results

| Where | Device | Figure format | Result |
|---|---|---|---|
| local (macOS, R 4.6.0) | base `svg` | 5 × `data:image/svg+xml;base64` (no PNG) | 3 builds: **IDENTICAL** |
| **CI, Bioconductor 3.24 devel container** (bioc-devel run `36223599204`, `vignette-determinism` job) | base `svg` | 5 × `data:image/svg+xml;base64` (no PNG) | **only 3 of 10 repeated builds IDENTICAL to the reference**. Builds 1, 3, 4, 5, 6, 7 and 9 differ: "vignette HTML differs outside the embedded PNG payloads", i.e. the embedded **SVG payloads differ between builds of identical source**. |
| CI package-branch (same run) | base `svg` | — | A, C, D (BiocCheckGitClone 0/0/0) and E PASS; **B FAIL**. The same-source control also differs in the same way. |

**Conclusion:** the base-R SVG device does **not** make the vignette
reproducible in the Bioconductor devel container. It is less reproducible
there than the PNG raster (PNG: 3 of 6 CI runs failed, one figure; SVG: 7 of
10 repeated builds differ).

- The comparator does not decode SVG, so whether the SVG differences are
  **visual** or only structural could not be established. For example, cairo
  SVG output embeds glyph and clip-path definitions whose identifiers or
  ordering may vary.
- **As instructed, no further device was tried.**

### 13.3 Other CI on `35a5112`

| Workflow | Result |
|---|---|
| linux-regression (`36223599210`) | **success** |
| r-compat (`36223599219`) | **success** |
| bioc-devel `bioc-devel` job | **success** (`R CMD check` OK; BiocCheck 1 ERROR `checkWatchedTag`, 1 WARNING, 9 NOTEs) |
| **platforms** (`36223599209`) | **failure on both macOS and Windows, at `setup-r-dependencies`** (dependency installation), before any package step |

The platforms failure happened on both OSes at the same step, and the two
preceding runs (`f313fb9`, `6b0ef9e`) were green with unchanged
dependencies. It looks like an ecosystem/transient installation failure,
not a package problem. The annotations give no detail; the CI of the commit
adding this section shows whether it recurs.

### 13.3a Second run (`23f301b`, documentation-only commit)

| Workflow | Result |
|---|---|
| bioc-devel `vignette-determinism` (`36224749049`) | **6 of 10** repeated builds IDENTICAL; builds 1, 2, 4 and 6 differ (SVG payloads). Still nondeterministic. |
| bioc-devel `package-branch` | A–E PASS; B happened to be strict IDENTICAL this time |
| platforms (`36224749020`) | Windows **success** (so the earlier Windows dependency failure was transient). **macOS failure** at `R CMD check`: "Vignette re-building failed … processing vignette 'postexportKinetics.Rmd' failed". |
| linux-regression, r-compat | success |

**Root cause of the macOS failure (confirmed locally):**

- CRAN's macOS build of R links the cairo-based devices (`grDevices`
  `cairo.so`, which backs `svg()`) against XQuartz: `otool -L` shows
  `/opt/X11/lib/libXrender.1.dylib`, `libSM`, `libICE`.
- The local machine has XQuartz, so the vignette built there.
- The GitHub macOS runner has no XQuartz, so `svg()` cannot be used and the
  vignette fails to build.
- The base-R SVG device therefore adds a **platform requirement (XQuartz
  on macOS)** in addition to being nondeterministic in the Bioconductor
  container.

### 13.4 Current state and options (for decision)

- **Current state:**
  - The development branch and `devel` (`75b2c5f` ← `35a5112`, tree
    `b77c598…`) carry the SVG vignette.
  - Local verification passes A–E. CI check B fails.
  - The PNG controlled exception is not applicable to SVG and was not used.
- **Base `svg` is demonstrably unsuitable:** nondeterministic in the
  Bioconductor devel container (3/10 and 6/10 identical), and the vignette
  fails to build on macOS without XQuartz.
- **Recommended immediate step (needs approval):** revert `9159c6d` (the
  vignette device line), restoring the previous portable PNG vignette.
  Until then the development branch and `devel` carry a vignette that does
  not build on stock macOS.
- **Options:**
  1. **svglite** (the next escalation step): Suggests only, vignette-only
     `dev = "svglite"`, then the same 10-build proof and the macOS, Windows
     and Linux checks. svglite writes SVG itself, without cairo or X11, and
     aims at reproducible output.
  2. **Revert to the PNG device and localise the pixel differences** (the
     comparator reports a bounding box), for example font or anti-aliasing
     settings for figure #5.
  3. Another policy for documentation-build reproducibility.
- Until a decision is made: no merge, no default-branch switch, no
  Contributions issue.

## 14. Base R `pdf()` device experiment (2026-09-26)

### 14.1 Setup

- **Base `svg` reverted on the development branch.** Commit `b899ab3`
  (revert of `9159c6d`, approved) restores the portable PNG vignette; the
  vignette is byte-identical to its pre-SVG state.
  - `devel` was refreshed to **`a8239a9`** ← Source-Commit **`b899ab3`**,
    tree `45ba02e…` (identical to the earlier `05ba5a8` tree).
  - It verifies A–E locally and in CI (bioc-devel run `36230234646`,
    `package-branch` job: B strict IDENTICAL; BiocCheckGitClone 0/0/0).
- **Experiment only**, on the separate branch `experiment/vignette-pdf`:
  - `5161328` sets `knitr::opts_chunk$set(..., dev = "pdf")` in the
    vignette setup chunk;
  - the branch tip reverts it.
  - Nothing from the experiment is on `bioconductor-prep` or `devel`.

### 14.2 Findings

| Question | Result |
|---|---|
| How figures appear in the html_vignette | pandoc embeds each figure as `<embed role="img" src="data:application/pdf;base64,…">` (5 figures) |
| Renders correctly in a standard browser context | **No (as tested).** WebKit (macOS QuickLook, the Safari engine) renders only an **empty placeholder frame** for the embedded PDF. Display depends on a browser PDF plugin accepting `data:` PDFs inside `<embed>`; this is not guaranteed in standard browsers, mobile browsers or static vignette viewers. |
| `R CMD build` / `R CMD check` | build and vignette re-build succeed: locally, on Linux, **macOS and Windows** (platforms run `36230359619` success) and in the Bioconductor devel container (`R CMD check` OK); no extra system software needed |
| Repeated-build determinism (Bioconductor devel container, 1 + 10 builds; bioc-devel run `36230359639`) | **0 of 10 strictly IDENTICAL** |
| PDF byte differences (two local builds, decoded) | Surrounding HTML identical once the PDF payloads are masked. Every one of the 5 PDFs differs in exactly 4 bytes, all inside **`/CreationDate (D:…)` and `/ModDate (D:…)`**. All graphical content is byte-identical. R's `pdf()` always writes these timestamps. |
| BiocCheck on the experiment branch | the BiocCheck step exited without its summary annotation, apparently a BiocCheck/network crash like the earlier bioconductor.org cache failures; not investigated further (experiment only) |

- **Conclusion:** base `pdf()` is **not suitable**. The figures are not
  reliably renderable inside an HTML vignette, and builds are never strictly
  identical, because of PDF creation/modification timestamps; the graphical
  content itself is identical.
- As instructed, no PDF-metadata exception was introduced, check B was not
  weakened, the experiment was reverted, and svglite was not tried.

### 14.3 New localisation of the original PNG nondeterminism

The PNG baseline run on `b899ab3` (bioc-devel run `36230234646`,
`vignette-determinism` job: **5 of 10 identical**) captured the pixel
differences with the new diagnostic.

- Every differing build has the **same** difference: embedded PNG #5 (the
  operational-domain plot, 360×504×3), **3,355 values in 1,183 pixels**.
  - **Bounding box: rows 323–329, columns 206–425**, a thin horizontal
    strip about 7 px high near the bottom of the figure.
  - Maximum absolute difference 0.996 (full intensity).
- So the rendering alternates between **two stable variants of one text
  line** (axis title, legend or caption region). This is text rasterisation
  in the container's cairo/font stack, not plotted data.
- The domain-plot strings are plain ASCII, so non-ASCII font fallback is
  ruled out.
- **Options (for decision):**
  1. **svglite** (Suggests, vignette only; writes SVG without cairo, then the
     same 10-build proof and platform checks).
  2. Stay on PNG and pin the text rendering. Examples: an explicit font
     family for the vignette figures, a knitr `dev.args` / `png(type = …)`
     choice, or `ragg` if you approve it.
  3. Another policy.

## 15. PNG font / device pinning experiment (2026-09-26)

All work is on the diagnostic branch `experiment/png-fonts` (`c04f3cd`,
`b2865b6`; workflow `font-inventory.yml`, scripts
`tools/ci/font_inventory.R` and `tools/ci/render_probe.R`). **No vignette,
package or dependency change** was made on `bioconductor-prep` or `devel`.

### 15.1 Font and PNG-device inventory (verified, not assumed)

| Environment | Fonts | "DejaVu Sans" | fontconfig matches | PNG devices |
|---|---|---|---|---|
| Bioconductor devel container (R 4.6.1, Linux) | 20 families: URW (Nimbus Sans, Nimbus Roman, …) and TeX Gyre (Heros, …) | **absent** (no font files) | `sans`, `Helvetica`, `Arial`, `DejaVu Sans` → Nimbus Sans | default `cairo`; `cairo` and `cairo-png` work; no Xlib, no quartz |
| macOS runner (R 4.6.1) | 673 families, including Helvetica, Arial and Verdana | **absent** | `sans` → Verdana; `DejaVu Sans` → Verdana | default `quartz`; **`cairo` fails**: `cairo.so` needs XQuartz (`/opt/X11/lib/libXrender.1.dylib` not found) |
| Windows runner (R 4.6.1) | Windows fonts, no fontconfig | **absent** ("font family not found in Windows font database") | — | `windows`, `cairo`, `cairo-png` work |

- **No common explicit font family** exists across the three environments.
  DejaVu Sans is absent everywhere; Nimbus Sans exists only on Linux;
  Arial and Helvetica are not installed in the container.
- **An explicit cairo PNG device is not portable:** it is unavailable on
  stock macOS.

### 15.2 Render probe in the Bioconductor devel container

Figure #5 (the operational-domain plot, 504×360 px) was rendered **15
times per configuration, each in a fresh R process**. The probe counts
distinct decoded-pixel outputs.

| Configuration | Distinct pixel outputs | Counts |
|---|---|---|
| default (`cairo`, family "sans" → Nimbus Sans) | **2** | 9 / 6 |
| `family = "Nimbus Sans"` | **2** | 5 / 10 |
| `family = "TeX Gyre Heros"` | **2** | 5 / 10 |
| `type = "cairo-png"` | **2** | 6 / 9 |
| `type = "cairo"` + `family = "Nimbus Sans"` | **2** | 12 / 3 |

Locally on macOS, every configuration gives 1 distinct output (3 of 3).

- **Result: explicit font-family and PNG-device pinning does not remove the
  nondeterminism.** Every configuration alternates between two outputs in
  the container.
- Because no candidate is stable even for a single render, the vignette
  11-build proof could not reach 10/10. No vignette change was committed
  and the proof was not run with pinning. This is the stop condition.
- **Figure #5 is still the only figure observed to vary** (§14.3: one
  7-px text strip).
- **What this implies:**
  - The variation does not come from font-family mapping (fontconfig
    matches are deterministic) or from the cairo surface type.
  - It may come from the text layout path itself in that container, or from
    the drawn content of that text line varying between processes.
  - These two possibilities have not yet been told apart.
- **Suggested next diagnostic (needs approval; diagnostic only):** in the
  same container probe, record the plot's grid text grobs (strings,
  positions, font metrics) per process. If they vary, the content or
  metrics vary, and svglite would not help. If they are stable, it is
  rasterisation.
- Then the approved next experiment is **svglite**, as instructed; ragg is
  not tried.

### 15.3 Unchanged

- **Branches:** the development branch is `bioconductor-prep`. `devel` is
  `a8239a9` ← Source-Commit `b899ab3`, the PNG vignette as released in the
  0.99.0 line.
- **Package:** no plot method, data, text, calculation or dependency
  change.
- **Status (at the time; superseded by §18):** Watched Tags is pending, and `set.seed` is awaiting bioc-devel
  guidance. The Contributions issue is not opened.

## 16. Text/grob diagnostic of figure #5: before or during rasterisation? (2026-09-26)

**Setup.** Diagnostic branch `experiment/png-fonts`, commit `f56a9ce`,
scripts `tools/ci/text_probe_one.R` and `tools/ci/text_probe.R`, workflow
`font-inventory.yml`, run `36236726879`.

- The environment is the Bioconductor devel container (R 4.6.1).
- There were 15 fresh R processes. Each one:
  - built `plot(dom)` for the vignette's operational-domain check without
    mutating it (`ggplot_build()`, `ggplotGrob()`);
  - wrote a canonical record of:
    - labels and the resolved theme text elements (family, face, size,
      line height, colour, hjust, vjust, angle);
    - scale breaks and labels;
    - all built layer data;
    - the gtable layout, widths and heights;
    - every text grob: path, label, x/y, justification, rotation, font
      family, face, size, line height, colour, and measured width/height
      on the same `png()` device;
  - rendered the 504×360 PNG;
  - separately recorded sessionInfo, capabilities, locale and fontconfig
    resolution.
- No vignette, package or plotting-code change.

### 16.1 Result

| Measure | Result |
|---|---|
| PNG classes (decoded pixels) | **2** (7 and 8 runs) |
| Distinct text/grob records | **2**, one per PNG class (`c0967612…` for class 1, `e1ec7283…` for class 2) |
| Distinct environment records | **1** (identical sessionInfo, capabilities, locale and font resolution) |
| **Verdict** | **A: the text/grob records differ between the PNG classes.** The nondeterminism is upstream of rasterisation. |

**The exact differing property is the order of the two legend guides** in
the bottom legend box (`gt/guide-box/layout/...`):

| PNG class | first guide | second guide |
|---|---|---|
| 1 | colour guide, label "exact match" (`guide.label.titleGrob.79`) | shape guide, label "Wilson interval contains 0.05" (`guide.label.titleGrob.90`) |
| 2 | shape guide, "Wilson interval contains 0.05" (`guide.label.titleGrob.79`) | colour guide, "exact match" (`guide.label.titleGrob.89`) |

Everything else is identical: the strings, positions, justification,
rotation, font family, face, size, line height, colour and measured
text widths, the scales, and the layer data. The swapped legend row is the
unstable 7-px strip (rows 323–329) found in §14.3.

### 16.2 Interpretation

- In `plot.postexport_domain_check()` (`R/plot.R`), the colour
  (`match_type`) and shape (`criterion`) scales both have `name = NULL`.
  They give two separate, untitled guides with the default `order = 0`.
- ggplot2 documents that with `order = 0` the order of multiple guides is
  decided internally. In the Bioconductor devel container that order is not
  stable across R processes.
- The figure *content* (which legend comes first) therefore varies between
  builds before any rasterisation.
- This also explains the earlier results: the base-SVG builds varied
  (§13), and font or PNG-device pinning could not help (§15).
- It is **not** a scientific issue. The data, values and labels are the
  same; only the left-to-right order of the two legend keys changes.

### 16.3 Decision rule and proposal (not implemented)

- Decision rule **A**: stop. svglite is **not** tried, because a different
  device cannot fix nondeterminism in the plot content.
- **Proposed fix (needs approval, since it changes package plotting code):**
  in `plot.postexport_domain_check()`, give the two scales explicit guide
  orders, for example
  `scale_colour_manual(..., guide = ggplot2::guide_legend(order = 1))` and
  `scale_shape_manual(..., guide = ggplot2::guide_legend(order = 2))`.
  - It is display-only and matches class-1 order. The values, labels and
    returned object type stay the same.
  - It also makes the user-visible legend order deterministic.
  - Then audit the other `plot()` methods for multiple separate guides with
    default order, and re-run the vignette 11-build proof on the PNG device
    (no device change needed).
- Expected validation after the fix:
  - the plot tests (`test-plot.R`) still pass;
  - the text/grob probe gives 1 record and 1 PNG class;
  - the 10/10 strict repeated-build proof;
  - check B strict.

### 16.4 Unchanged

- `bioconductor-prep` and `devel` (`a8239a9` ← `b899ab3`) are unchanged
  by this diagnostic.
- Check B is not weakened; no package, plotting, dependency or scientific
  change was made.
- (At the time; superseded by §18.) Watched Tags (pending) and `set.seed` (awaiting bioc-devel guidance)
  remain separate pending items.

## 17. Guide-order fix and determinism proof (2026-09-26)

### 17.1 Root cause (from §16)

- `plot.postexport_domain_check()` maps `colour = match_type` and
  `shape = criterion`.
- Both scales have `name = NULL`, which gives two untitled legend guides at
  ggplot2's default `order = 0`.
- Their left-to-right order in the bottom legend was decided internally by
  ggplot2 and was **not stable across R processes** in the Bioconductor
  devel container. It swapped the two legend keys and changed one 7-px
  strip of vignette figure #5.

### 17.2 Code change (approved), commit `deccdde`

- In `R/plot.R`, `plot.postexport_domain_check()`:
  - `scale_colour_manual(..., name = NULL, guide = ggplot2::guide_legend(order = 1))`;
  - `scale_shape_manual(..., name = NULL, guide = ggplot2::guide_legend(order = 2))`;
  - plus a comment explaining why.
- Unchanged: mapped variables, colours (`.PAL`), shapes (16/1), key labels,
  `NULL` titles, `legend.position = "bottom"`, plot data and
  interpretation. No numerical or inferential code changed, and no frozen
  port was touched.
- The resulting order (colour first, then shape) is the previously observed
  class-1 order.

### 17.3 Audit of the other plot methods

Every `plot()` type was built and its legends counted:

| Plot | Legends |
|---|---|
| fit, test "fit" | 1: colour and linetype are both mapped to `model` with identical names and labels, so they merge into one guide |
| test "bootstrap" | 1 (fill) |
| set "sigma_IR" / "sigma_q" / "IR_q" | 1 (shape) |
| set and fit-set "status" / "boundary" / "score" | 0 |
| simulation | 1 (linetype) |
| **operational domain** | **2** (colour and shape): the only case with multiple guides |

No other method has multiple independent guides, so no other change was
made.

### 17.4 Regression tests

`test-plot.R` gains "operational-domain legend order is explicit and
deterministic" (17 expectations). It asserts that:

- the colour guide has `order = 1` and the shape guide `order = 2`;
- in the rendered gtable (null PDF device) the bottom guide box holds 2
  guides: "exact match" (colour) first, then "Wilson interval contains 0.05"
  (shape);
- the order is identical over repeated construction;
- the title, x label and `NULL` scale names are unchanged;
- the plot data columns and values are unchanged (point `x` = `type1`,
  shape 16);
- the input object is unmodified.

**Mutation check:** swapping the orders (colour 2, shape 1) fails 4
expectations.

### 17.5 Repeated root-cause probe (fixed code)

Bioconductor devel container, 15 fresh R processes (diagnostic branch
`experiment/png-fonts` @ `cee6023`, the fix cherry-picked; run
`36237809547`):

- **1 text/grob diagnostic record** (`c0967612…`);
- **1 PNG pixel class** (15 of 15);
- 1 environment record.

Before the fix there were 2 of each (§16).

### 17.6 Vignette determinism proof (PNG device, unchanged vignette)

Bioconductor devel container, the same source (`deccdde`) built 11 times,
builds 2–11 compared strictly with build 1 (bioc-devel run `36237806452`,
`vignette-determinism` job):

- **10 of 10 repeated builds strictly IDENTICAL.** The surrounding HTML
  and all 5 embedded PNG figures are byte-identical.
- The controlled PNG exception was **not used**.
- **Figure #5 is stable**, and no other figure had varied.

### 17.7 Check B final status and package-only branch

- **`devel` = `d099ac79d1bacc8edd24a5d9aa4f3ffaea67ee0f`**, "package-only
  export of deccdde", **Source-Commit
  `deccddef91a3cd9858244e280a4194e857299874`**, tree `5ccfbac…`.
- Linear history: `ad31ab9` → `e3202a8` → `05ba5a8` → `75b2c5f` →
  `a8239a9` → `d099ac7`.
- **`verify_package_branch.sh devel`**, locally and in CI (bioc-devel run
  `36237806452`, `package-branch` job):
  - **A** PASS;
  - **B** strict PASS (IDENTICAL, 90 files);
  - **C** PASS;
  - **D** BiocCheckGitClone 0/0/0;
  - **E** PASS (0.99.0, 10 exports).
- Check-B rule tests: 14 of 14.

### 17.8 Gates (`deccdde`)

| Gate | Result |
|---|---|
| testthat (local) | 17 files, **3,725 expectations** (3,708 + 17 new), 0 failures |
| `R CMD check --as-cran` (local) | 0 ERRORs, 0 WARNINGs, 2 NOTEs |
| `R CMD check` (Bioconductor 3.24 devel) | **Status: OK** |
| full `tools/validate_against_manuscript.R` | **EQUIVALENT** |
| linux-regression (scientific gate) `36237806434` | success |
| platforms `36237806454` (macOS, Windows; R 4.6.1) | success |
| r-compat `36237806447` (R 4.1.3 / Bioconductor 3.14; R 4.5.3) | success |
| bioc-devel `36237806452` (`bioc-devel`, `vignette-determinism`, `package-branch`) | success |
| BiocCheck (Bioconductor devel) | 1 ERROR `checkWatchedTag` (maintainer) / 1 WARNING `set.seed` / 9 NOTEs |
| frozen ports, fixtures, `sysdata`, data | unchanged versus `v0.1.0` |
| frozen repository | tag → `65c3b7368fb7686bfde3dab857f98c393bb534c5`, unchanged |

### 17.9 Remaining before GO

1. **Watched Tags:** the maintainer confirms completion. Then re-run the full
   networked BiocCheck and require **0 ERRORs**.
2. **`set.seed`:** accepted with justification and a reviewer-exception
   request (§18); no longer a blocker.
3. Then:
   - merge `bioconductor-prep` into `main` (`--no-ff`);
   - re-export and verify `devel`;
   - the maintainer switches the default branch (§8);
   - explicit approval to open the Contributions issue (§9).

The diagnostic branches `experiment/vignette-pdf` and `experiment/png-fonts`
are records only and will not be merged.

## 18. Policy update and current blocker (2026-09-26)

### 18.1 `set.seed`

- **Status:** accepted for submission with explicit justification and a
  reviewer-exception request; **no longer a blocker**, and no longer
  awaiting bioc-devel guidance.
- No implementation change.
- The issue states honestly: **R CMD check 0 ERRORs / 0 WARNINGs; BiocCheck
  0 ERRORs / 1 WARNING (`set.seed`)**, with the §7.1 justification.
- The "no ERROR or WARNINGS" checklist item is ticked as understanding,
  with the adjacent explicit status and exception request (§9).

### 18.2 The only remaining blocker: Watched Tags

Full networked BiocCheck (BiocCheck 1.48.1; bioconductor.org reachable;
`devel` tarball of `d099ac7` ← `deccdde`, 2026-09-26):

- **1 ERROR:** `checkWatchedTag`, "Add package to Watched Tags in your
  Support Site profile". It is still present; "Maintainer is registered at
  support site".
- **1 WARNING:** `checkCodingPractice` (`set.seed` ×2), accepted (§18.1).
- **10 NOTEs.**

The technical readiness recommendation is **not yet** "GO FOR FINAL
SUBMISSION PREPARATION". It changes once the maintainer confirms Watched
Tags and a full networked BiocCheck shows **0 ERRORs**.

### 18.3 Prepared next steps (execute only after 0 ERRORs)

1. Merge `bioconductor-prep` into `main` (`--no-ff`) and push. Require all
   development and scientific workflows green.
2. Re-export `devel` from the final `main` commit. Run
   `verify_package_branch.sh devel` and require:
   - A PASS;
   - B strict PASS;
   - C PASS;
   - D 0/0/0;
   - E PASS.
3. Stop before changing the GitHub default branch. No Contributions issue,
   no change to `v0.1.0`, no `set.seed` change, no frozen-port change.

## 19. Final preparation: 0-ERROR BiocCheck, merge to main, devel verification (2026-09-26)

### 19.1 Full networked BiocCheck (after the maintainer set Watched Tags)

BiocCheck 1.48.1, bioconductor.org reachable, run on the `devel` tarball
(`d099ac7` ← `deccdde`, content identical to `main`):

- "Maintainer is registered at support site."
- "**Package is in the Support Site Watched Tags.**"
- **Result: 0 ERRORs | 1 WARNING | 10 NOTEs.**

| Level | Finding |
|---|---|
| WARNING | `checkCodingPractice`: "Remove set.seed usage (found 2 times)": `R/inference.R` (frozen orchestrator) and `R/simulate.R` (explicit user seed). **Accepted, with justification and a reviewer-exception request** (§7.1, §18). |
| NOTE | R version dependency 4.1.0 → 4.6.0 (kept by decision; CI-verified on R 4.1.3) |
| NOTE | ORCID for the maintainer (optional; not invented) |
| NOTE | no `fnd` role (optional) |
| NOTE | `=` assignment (frozen `assay.R`) |
| NOTE | `paste` in condition signals (5 frozen sites) |
| NOTE | `<<-` (2, frozen `inference.R`) |
| NOTE | 26 functions > 50 lines (13 frozen; 13 package-authored) |
| NOTE | 6 lines > 80 characters (frozen `ode.R`) |
| NOTE | 4-space indentation, 1,686 lines (frozen ports; argument-alignment continuation lines) |
| NOTE | bioc-devel subscription cannot be determined by BiocCheck (maintainer subscribed) |

### 19.2 Merge to main

- **`main` = `236f5091a7624361804fe1259dd533b03c453490`**: `--no-ff` merge
  of `bioconductor-prep` (`4b97549`) into `main` (`de5f722`), pushed. The
  merged tree equals the `bioconductor-prep` tree. This report update is
  added on top as documentation only.
- `v0.1.0` (→ `04c4407`) is untouched.
- The frozen ports, fixtures, `R/sysdata.rda` and data are unchanged versus
  `v0.1.0`.

### 19.3 CI on `main` @ `236f509` (all green)

| Workflow | Run | Result |
|---|---|---|
| linux-regression (frozen-reference scientific gate; package) | `36239890846` | **success** (frozen-reference, package) |
| platforms (macOS, Windows; R 4.6.1) | `36239890842` | **success** |
| r-compat (R 4.1.3 / Bioconductor 3.14; R 4.5.3) | `36239890879` | **success** |
| bioc-devel (`bioc-devel`, `vignette-determinism`, `package-branch`) | `36239890852` | **success**: vignette determinism **10 of 10** strictly identical; package-branch A–E PASS; check-B rule tests 14/14 |
| release-candidate (`main`) | `36239890868` | **success**: tarball inspection PASSED; clean installation PASSED; citation audit PASSED (0.99.0, no package DOI); **full manuscript validation EQUIVALENT**; CI tarball `postexportKinetics_0.99.0.tar.gz`, sha256 `78a1ab36c0d5443117b9217fded18c17bbfd8fc0d7559033db4af452ef6026c…` (see the run annotation for the full digest) |

The container BiocCheck annotation of the bioc-devel job was not retrieved:
the GitHub API rate limit was reached. The job succeeded; its gate fails on
any ERROR other than the maintainer-side checks. The authoritative
networked result is §19.1.

### 19.4 `devel` re-export and verification

- **Re-export from the final `main` commit.** `make_package_branch.sh
  236f509` reported "already the package-only export of this content (tree
  `5ccfbac…`)", so no new commit was created. The package-distribution
  tree of `main` `236f509`, computed independently, is exactly
  `5ccfbac4851b6550998fb7e6ecee6d063f0dabf9`, the tree of `devel`. There
  is no package-distribution difference between `deccdde` and `236f509`.
- **Mapping:** **`devel` = `d099ac79d1bacc8edd24a5d9aa4f3ffaea67ee0f`**, with
  `Source-Commit: deccddef91a3cd9858244e280a4194e857299874`. `deccdde` is
  an ancestor of `main` `236f509`, whose export tree is identical.
- **`verify_package_branch.sh devel`**, locally and in CI (run
  `36239890852`):

| Check | Result |
|---|---|
| A tree | **PASS** (`5ccfbac…`) |
| B tarball | **strict PASS** (IDENTICAL, 90 files; only `Packaged:` differs) |
| C hygiene | **PASS** |
| D BiocCheckGitClone | **0 ERRORS / 0 WARNINGS / 0 NOTES** |
| E version / citation / API | **PASS** (0.99.0; 10 exports) |

### 19.5 Technical readiness

**GO FOR FINAL SUBMISSION PREPARATION.**

Remaining steps, **each requiring explicit approval**:

1. The maintainer switches the GitHub default branch to `devel` (§8,
   steps 4–5).
2. Open the Bioconductor Contributions issue with the §9 text. It states
   honestly: R CMD check 0/0; BiocCheck 0 ERRORs / 1 WARNING (`set.seed`,
   exception requested); the AI-assistance disclosure; the frozen DOI
   labelled correctly; no package DOI.

**Not done:** default-branch switch, Contributions issue, any `set.seed`
change, any `v0.1.0` or frozen-code change.
