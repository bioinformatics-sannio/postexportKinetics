# Bioconductor readiness report (Phase 6C/6D)

Status: **prepared; stopped for explicit human approval.**

- The Contributions issue has not been opened, and nothing was submitted.
- The GitHub default branch is unchanged (`main`).
- `v0.1.0` is untouched (tag → `04c4407`).
- No frozen scientific code was changed.

## 1. Branches and Source-Commit mapping

| Item | Value |
|---|---|
| Development branch | `bioconductor-prep`; CI, tools, provenance infrastructure, reports and the scientific regression gates |
| **Development source commit** of the current package-only export | **`f6e1bfb823e90a7f1aa8294f628aedb4950dc008`**. It adds `^BIOCONDUCTOR_READINESS\.md$` to `.Rbuildignore`, an allowlisted file, so the exported tree changed. Later development commits (this correction) change only reports, so no new `devel` commit is created. |
| **`devel`** (package-only branch, pushed, **not default**) | **`e3202a89382e5b241baa5cfb7e881cf7de5b343d`**: "package-only export of f6e1bfb" / `Source-Commit: f6e1bfb823e90a7f1aa8294f628aedb4950dc008`; tree `f5000fb810b9387158256913e91b2e24aad62083`; parent `ad31ab9` |
| Earlier export | `ad31ab97b9c2afe84d6503206329b9fc759af925` ("package-only export of 271c573", tree `a94294e…`). It differs from the current export only by that one `.Rbuildignore` line; package content is otherwise identical. |
| `devel` content | `.Rbuildignore`, `.gitignore`, `CITATION.cff`, `DESCRIPTION`, `LICENSE`, `NAMESPACE`, `NEWS.md`, `README.md`, `R/`, `data/`, `inst/`, `man/`, `tests/`, `vignettes/` (allowlist `tools/release/package_allowlist.txt`) |
| `devel` history | linear: `ad31ab9` (root) → `e3202a8`; normal pushes, no force |
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

CI verification of the current `devel` (`e3202a8`) is reported in the review
message: the bioc-devel `package-branch` job on this commit.

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
- **Decision (optional):** whether a recurrence confirmed by the control
  should be tolerated for embedded vignette images.

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

The earlier runs on this phase's commits:

| Commit | Result |
|---|---|
| `5b1467e` | bioc-devel job failed only because `checkWatchedTag` was not yet whitelisted, and package-branch had no annotations; the other three workflows green |
| `3ec0025` | package-branch B failed as described in §3; bioc-devel job and the other three green |

## 6. Maintainer-action status

| Action | Status |
|---|---|
| Bioconductor Support Site registration | **done** (BiocCheck: "Maintainer is registered at support site") |
| Add `postexportKinetics` to **Watched Tags** | **pending**. It is the only BiocCheck ERROR (`checkWatchedTag`). Do it at https://support.bioconductor.org/accounts/edit/profile, then re-run the final readiness check. |
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
- [ ] I understand that a minimum requirement for package acceptance
  is to pass R CMD check and R CMD BiocCheck with no ERROR or WARNINGS.
  ...   <-- see note A below
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

- R CMD check: OK (Bioconductor devel). BiocCheckGitClone: 0/0/0.
  BiocCheck: 0 ERRORs once the Watched Tag is set; 1 WARNING (set.seed),
  justified below; NOTEs relate to the verbatim ported scientific core.
- set.seed justification: [text of section 7.1]
- Frozen-code style: [table of section 7.2]
- Provenance: the numerical core is ported verbatim from the frozen
  manuscript implementation (github.com/bioinformatics-sannio/postexport-kinetics,
  tag manuscript-revision-v1.0, doi:10.5281/zenodo.22944109; the DOI of that
  implementation, not of this package), by the same authors, under MIT,
  and is regression-tested against it. The associated manuscript is
  submitted and not yet published. A GitHub release v0.1.0 exists; the
  package has no DOI.
- AI assistance: [disclosure text, see note B]
```

**Note A (blocking decision).** The template states that "a minimum
requirement for package acceptance is to pass R CMD check and R CMD
BiocCheck with no ERROR or WARNINGS".

- The `set.seed` WARNING remains by decision, so this box cannot honestly be
  ticked without qualification.
- **Options:**
  - (a) submit with the WARNING and the §7.1 justification, leaving the box
    unticked or annotated, and accept reviewer risk;
  - (b) approve a change that removes the WARNING. This would be a
    behaviour/API decision: for example, dropping the simulator's explicit
    seed argument, or changing how the frozen orchestrator's seeding is
    reached. It is not recommended without scientific review.
- The frozen orchestrator's `set.seed` cannot be removed without changing
  validated behaviour.

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
- **Proposal (needs approval; comment-only change):**
  - add an `Assisted-by: Claude (Anthropic)` header line to the
    package-authored `R/` files and tests;
  - keep the existing "Ported verbatim from …" headers in the frozen ports;
  - include this disclosure in the issue:

    > Development of the package-authored code, tests and documentation was
    > assisted by an AI model (Claude, Anthropic) under the authors'
    > direction and review; the scientific numerical core is ported
    > verbatim from the authors' frozen manuscript implementation and is
    > regression-tested against it.

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

**Recommendation: NO-GO at this moment. GO once the following are
resolved, in order:**

1. **Watched Tags** set by the maintainer. BiocCheck is then expected to
   show 0 ERRORs; re-run the final networked BiocCheck to confirm.
2. **Decision on Note A** (the `set.seed` WARNING versus the template's
   "no ERROR or WARNINGS" requirement).
3. **Decision and implementation of Note B** (AI-assistance attribution in
   the code and the issue disclosure). This is comment-only and needs
   approval.
4. Merge the development branch into `main` (§10). Re-export and verify
   `devel` from the final commit (§8, steps 1–3), with all four workflows
   green.
5. The maintainer switches the default branch to `devel` (§8, steps 4–5).
6. Explicit human approval to open the Contributions issue (§9).

Package quality is otherwise ready:

- Bioconductor-devel `R CMD check` OK; BiocCheckGitClone 0/0/0;
- scientific validation EQUIVALENT;
- all platforms and R 4.1 green;
- no package DOI, and the frozen DOI correctly labelled.
