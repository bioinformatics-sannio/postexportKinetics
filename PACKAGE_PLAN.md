# postexportKinetics — Package Plan (audit phase)

Status: **DRAFT FOR REVIEW — no package code has been written.**
Scope of this document: audit of the frozen manuscript implementation and a
proposed architecture, API, validation, regression and release plan for the
`postexportKinetics` R package. Nothing in this plan is implemented until it is
explicitly approved.

Conventions used below:

- `FROZEN:` paths are relative to the frozen manuscript repository at tag
  `manuscript-revision-v1.0` (e.g. `FROZEN:commons/nested_test2.r:1447`).
- Line numbers refer to the file content at the tag.
- **[SF-n]** marks a *stop-condition finding* (Section 16.C) that needs a human
  decision before the affected component is implemented.
- "Frozen behaviour" always means *what the code at the tag does*, which in a
  few documented cases differs from what its comments say.

Interpretation used throughout: `sigma_c` is a **phenomenological post-export
conversion rate** (C → C_s) within the four-state model. A positive estimate or
a small bootstrap p-value indicates *kinetic evidence consistent with an
additional post-export conversion component within the model*; it does not
identify a molecular mechanism and is not evidence of cytoplasmic splicing per
se. The inferential comparison is null `sigma_c = 0` vs full `sigma_c >= 0`
(one-sided alternative `sigma_c > 0`). The statistic is a difference of
whitened NNLS residual sums of squares calibrated by a generative bootstrap;
**no likelihood exists in the frozen implementation and the procedure must not
be described as a likelihood-ratio test.**

---

## 1. Frozen source verification

All checks were read-only (`git rev-parse`, `git status`, `git diff`,
`git log`, `git cat-file`, `git show`, `git archive`). No command altered the
Git state of `~/postexport-kinetics`.

| Item | Value |
|---|---|
| Repository path | `/Users/luce/postexport-kinetics` |
| Tag | `manuscript-revision-v1.0` (annotated tag object `8a2d83d67d709c4945d539f302f9f75836778690`) |
| Tag message | "Frozen analysis for BIOINF-2026-0699 revised manuscript" |
| **Frozen commit SHA** | **`65c3b7368fb7686bfde3dab857f98c393bb534c5`** ("Finalize revised manuscript reproducibility archive", 2026-09-24) |
| Commit introducing the final analysis | `29320a9` "Freeze revised analysis for BIOINF-2026-0699" (adds `nested_test2.r`, all `*corrected_onset*`/`*revision*`/`*FINAL*` scripts, rewrites `ode.r`) |
| Current branch / HEAD at audit time | `main` / `687ec24f82c6c2c7fe29da1615fb618fc1176890` ("Add software citation metadata") — **one commit after the tag** |
| Committed difference HEAD vs tag | `A CITATION.cff` only (no code changes) |
| Working tree vs HEAD | `M README.md` (uncommitted, +9 lines, documentation only) |
| Code files differing from tag | **none** |
| Files at tag | 64 (see Section 3) |

Consequence: the working tree is *not* identical to the tag (README and
CITATION.cff differ), but no scientific file differs. To remove any ambiguity,
all reading for this audit was done from a `git archive manuscript-revision-v1.0`
export into a scratch directory, and the same mechanism is proposed for fixture
generation (Section 9.1).

Recorded environment of the frozen benchmark run
(`FROZEN:synthetic_dataset/benchmark_main_corrected_onset_sessionInfo.txt`):
R 4.5.2, RHEL 8.3, OpenBLAS 0.3.3 / LAPACK 3.8.0, `MASS 7.3-65`, `nnls 1.6`,
`data.table 1.18.4`; run completed 2026-09-22, `N_BOOT = 1999`,
2,000 genes, 2,304,000 tests, `common_T_star = 332`, onset shift ∈ [-100, 100].

Local development environment at audit time: R 4.6.0 (macOS, reference
BLAS/LAPACK), `MASS 7.3-65`, `data.table 1.18.4`, `roxygen2 8.0.0`,
`BiocParallel 1.46.0`, `knitr`, `rmarkdown`, `ggplot2`, `withr`.
**Not installed:** `nnls`, `deSolve`, `expm`, `testthat`, `BiocCheck`,
`devtools`. The frozen core therefore has **not yet been executed** in this
audit; installing these is the first step after approval (Section 9.1).

---

## 2. Scientific dependency map

### 2.0 Model definition (common to all components)

State vector (order is fixed everywhere: `KINETIC_VARS`,
`FROZEN:commons/nested_test2.r:29-34`): `N`, `N_s`, `C`, `C_s`.

Parameter vector (order is fixed: `PARAM_NAMES`, `nested_test2.r:36-44`):
`R, tau, tau_s, sigma_c, sigma_n, alpha, alpha_s`; `sigma_c` is column 4
(`col_test = 4L`).

ODE (`FROZEN:ode_model/ode.r:54-89`, identical structure in
`kinetic_matrix`, `nested_test2.r:1093-1126`):

```
dN   = R - sigma_n*N - tau*N
dN_s = sigma_n*N - tau_s*N_s
dC   = tau*N - sigma_c*C - alpha*C
dC_s = tau_s*N_s + sigma_c*C - alpha_s*C_s
```

`sigma_n`: nuclear processing N→N_s; `tau`, `tau_s`: export of unprocessed /
processed RNA; `sigma_c`: post-export conversion C→C_s; `alpha`, `alpha_s`:
cytoplasmic decay. No nuclear decay term. Closed-form steady state
`steady_states()` (`ode.r:119-178`) was checked algebraically against the ODE
and is consistent.

### 2.1 Component table

Legend: *F* = function, *G* = global/constant dependency, *P* = package.

| ID | Component | Source (FROZEN) | Function(s) / key helpers | Globals / packages | Input → Output |
|---|---|---|---|---|---|
| A | ODE simulation | `ode_model/ode.r:54-89, 301-348, 374-640, 771-1290` | `rna_kinetics`, `integrate_interval_fixed_R`, `simulate_scheduled_trajectory`, `generate_ODE_states`, `steady_states` | P: `deSolve::ode` (default method `lsoda`, default `rtol=atol=1e-6`) | params (list), `y0`, time grid → data.frame(time, N, N_s, C, C_s, R[, replicate]) |
| B | Transcriptional onset | `ode.r:374-640` (semantics), `ode.r:907-966` (shift draw); benchmark use `gen_synthetic_ODE_states_corrected_onset.R:410-432, 584-587, 660-664` | `simulate_scheduled_trajectory(onset_time=)`; pre-run for `onset_time < min(times)` (`ode.r:444-493`); breakpoints at onset/t_star (`ode.r:500-540`); R evaluated at interval midpoint (`ode.r:566-605`) | G: `MAX_ONSET_SHIFT = floor(0.1*max(times)) = 100` (benchmark), `54` (mESC-matched) | R(t)=0 for t<onset; R_pre for onset≤t<t_star; `post_R_fraction*R_pre` for t≥t_star (right-continuous) |
| C | Shutoff / intervention | Simulation: `ode.r:374-640`, common `t_star` (`gen_…_corrected_onset.R:250-254`, T_star=332). Inference: `nested_test2.r:689-712` (interval balance), `1284-1296` (CN null) | `build_Ab_fullcov(t_star=)`, `predict_null_cn(t_star=)` | — | Inference: `R_dt = pmax(0, pmin(dt, t_star - t0))`; only the R column is truncated; all other processes continue |
| D | Interval balances (trapezoid) | `nested_test2.r:580-889` | `build_Ab_fullcov` → `time_summary_cov_shrink` | — | per-time means `X` (K×4) → `b = diff(X)` stacked species-major; integrals `I = dt*(X_k+X_{k+1})/2` |
| E | Regression/design system | `nested_test2.r:714-785` | `build_Ab_fullcov` | G: `PARAM_NAMES` | `A` ((4(K-1))×7), rows N-intervals, N_s, C, C_s; columns in `PARAM_NAMES` order |
| F | Weighting / column scaling | GLS whitening `nested_test2.r:931-948`; column scaling `nested_test2.r:838-867` | `inverse_sqrt_matrix`, `make_spd` | — | `W^{-1/2}` by eigen decomposition; `A_w = W^{-1/2}A`, `b_w = W^{-1/2}b`; optional unit-norm column scaling (`scaling_A=TRUE`), zero/non-finite norms reset to 1 |
| G | Measurement covariance estimation | `nested_test2.r:199-448` | `time_summary_cov_shrink` | P: `stats::cov`; `complete.cases` | long data with `time` + 4 states → list(times, means, n_rep, cov_obs, cov_mean, pooled_cov) |
| H | Covariance propagation | `nested_test2.r:455-573, 791-832` | `build_sigma_means`, `build_difference_matrix` | G: `KINETIC_VARS` | block-diagonal `Sigma_m` (4K×4K, species-major) → `Sigma_b = D Sigma_m Dᵀ` |
| I | Regularisation / shrinkage / eigenvalue floor | `nested_test2.r:51-145, 344-432, 822-832` | `make_spd` (relative floor `max(median(positive diag)*rel_floor, .Machine$double.xmin)`), shrinkage `lambda_diag` (pooled → diag), `lambda_time` (per-time → pooled) | defaults `lambda_time=0.5`, `lambda_diag=0.1`, `rel_floor=1e-8` | applied to pooled cov, each per-time cov, and `Sigma_b` (and again inside `inverse_sqrt_matrix`) |
| J | Full constrained fit | `nested_test2.r:896-1079` | `fit_nnls_nested_once` | P: `nnls::nnls` (Lawson–Hanson) | `A_w`, `b_w` → `coef_full_scaled`, `RSS1` |
| K | `sigma_c = 0` null fit | same | `A0 = A_w[, -4]` | P: `nnls::nnls` | `coef_null_scaled` (6), `RSS0`; rescaled by `col_norms[-4]`, `sigma_c` set to 0 (`nested_test2.r:1601-1632`) |
| L | Observed statistic | `nested_test2.r:1010-1013` | `T = max(0, RSS0 - RSS1)` (whitened scale) | — | scalar; `IR = DeltaRSS / RSS0` (NA if RSS0 ≤ 0) `nested_test2.r:1998-2018` |
| M | Boundary handling | `nested_test2.r:1936-1992` | `tol_zero = 1e-10 * max(1, |RSS0|, |RSS1|)`; if `T.obs <= tol_zero` → `p = 1`; `atom.zero = mean(T* <= tol_zero)` | — | p-value override + diagnostic |
| N | Bootstrap data generation | null mean: `nested_test2.r:1093-1310, 1634-1707`; draws: `nested_test2.r:1317-1440` | `kinetic_matrix`, `cn_interval`, `predict_null_cn`, `simulate_destructive_null` | P: `MASS::mvrnorm` (eigen-based) | null coefficients + observed first-time mean `x0` → CN null means at observed times; `n_k` independent MVN draws per time with `cov_obs[[k]]` (shrunk, SPD); optional truncation at 0 (`truncate_nonnegative_boot`, default FALSE) |
| O | Bootstrap covariance propagation | `nested_test2.r:1773-1797` | `build_Ab_fullcov` on each bootstrap dataset | — | fresh `Sigma_b*` per replicate (same shrinkage/floors) |
| P | Reconstruction of design system in bootstrap | same | `build_Ab_fullcov` | — | `A*`, `b*`, `Sigma_b*`, `col_norms*` recomputed from bootstrap means |
| Q | Bootstrap refitting | `nested_test2.r:1811-1848` | `fit_nnls_nested_once` | — | `T*_b`, condition number, rank; failures flagged and excluded |
| R | Add-one p-value | `nested_test2.r:1963-1985` | `(1 + sum(T* >= T.obs)) / (n_valid + 1)` (no tolerance in the comparison); bootstrap declared unstable if failure rate > `max_failure_rate = 0.05` → `p = NA`, status `bootstrap_unstable` (`nested_test2.r:1850-1934`) | — | scalar p ∈ [1/(n_valid+1), 1] |
| S | Numerical diagnostics | `nested_test2.r:1015-1078, 2020-2053` | `svd(A_w)$d` → condition number (Inf if min sv = 0), min singular value, `qr()$rank` full/null; bootstrap median/q95/max condition, rank-deficient fraction; status codes `ok`, `observed_system_failed`, `observed_fit_failed`, `null_trajectory_failed`, `bootstrap_unstable` | — | list fields (Section 7) |
| T | RNG and seed handling | inference: `nested_test2.r:1501-1504` (`set.seed(seed)` on the **global** RNG, before any computation; no RNG is consumed before the bootstrap loop); simulation: `gen_…_corrected_onset.R:321-324, 416-429` **[SF-2]**; benchmark seeds `run_benchmark_main_corrected_onset_revision.R:658-722`; real-data seeds `run_real_datasets_revision.R:687-712`, `run_mESC_20k.R:515-558` | `stable_seed_from_string`, `make_main_seed`, `make_real_seed`, `stable_event_seed` | RNGkind never set → R defaults (Mersenne-Twister / Inversion / Rejection) | integer seeds; results independent of worker count because every task is reseeded |
| U | Observation / noise models | biological variability: `ode.r:886-900, 1060-1090` (lognormal per-replicate multiplier, `param_cv = 0.05`, R held fixed); assay: `commons/platforms.r:45-181`; presets: `run_benchmark_main_corrected_onset_revision.R:469-474, 538-645` | `add_gaussian_noise`, `sample_dispersion_gamma`, `simulate_rnaseq`, `simulate_rt_qpcr`, `add_platform_noise_main` | P: `MASS::rnegbin`, `data.table::copy`/`as.data.table` (hidden: not loaded by `platforms.r`) | latent states → noisy states; target order `N, C, C_s, N_s` (RNG-relevant) |
| V | Candidate-ranking score | synthetic: `analyze_composite_score_ablation.R:163-226`, `regenerate_corrected_discrimination_figures.R:141-157`; real data: `run_real_datasets_revision.R:1495-1627, 1807-1843` | composite `sigma_c × IR × min(-log10(max(q, 1e-10)), 6)`; q = BH within dataset/config | — | exploratory prioritisation score (not inferential) |

### 2.2 Data flow of `test_sigma_nested()` (authoritative inference)

```
tsampled_data (rows = destructive samples; columns time, N, N_s, C, C_s; replicate ignored)
  │  set.seed(seed)                                  [T]   nested_test2.r:1501
  ▼
build_Ab_fullcov ─ time_summary_cov_shrink          [G,I] pooled within-time cov → diag shrink → make_spd
  │               ─ per-time cov shrink → make_spd, cov_mean = S_k/n_k
  │               ─ trapezoid A, b; R_dt truncation [C,D,E]
  │               ─ Sigma_b = D Sigma_m D' → make_spd [H,I]
  │               ─ column scaling                   [F]
  ▼
fit_nnls_nested_once ─ W^{-1/2} whitening; NNLS null (–sigma_c) and full [F,J,K]
  │                  ─ T = max(0, RSS0-RSS1); svd/qr diagnostics [L,S]
  ▼
rescale coefficients by col_norms; coef_null[sigma_c] = 0
  ▼
predict_null_cn(times, x0 = observed mean at first time, coef_null, t_star)  [N]
  ▼
for b in 1..B:  simulate_destructive_null → build_Ab_fullcov → fit_nnls_nested_once → T*_b   [N,O,P,Q]
  ▼
failure-rate check → boundary tolerance → add-one p → atom.zero, IR, diagnostics             [M,R,S]
```

### 2.3 Input/output structures of the core entry point

`test_sigma_nested(tsampled_data, scaling_A = TRUE, t_star = NULL, B_n = 1999,
seed = NULL, lambda_time = 0.5, lambda_diag = 0.1, lambda_var = NULL,
rel_floor = 1e-8, truncate_nonnegative_boot = FALSE, max_failure_rate = 0.05,
return_boot = FALSE, verbose = FALSE)` (`nested_test2.r:1447-1475`).

- `lambda_var` is a backward-compatibility alias that **overrides**
  `lambda_time` (`nested_test2.r:1481-1485`) although the shrinkage target
  changed between implementations **[SF-15]**. `verbose` is unused.
- Returned list on success (`nested_test2.r:2059-2165`): `p.value`, `Sigma`
  (= `coef_full["sigma_c"]`), `Alpha`, `T.obs`, `RSS0`, `RSS1`, `IR`,
  `coef_full`, `coef_null`, `atom.zero`, `boundary.tolerance`,
  `bootstrap.failure.rate`, `n.bootstrap.valid`,
  `bootstrap.condition.median/q95/max`, `bootstrap.rank.deficient.fraction`,
  `condition.number`, `min.singular.value`, `rank.full`, `rank.null`,
  `lambda.time`, `lambda.diag`, `null.means`, `pooled.covariance`,
  `n.replicates.by.time`, `times`, `status`, `error.message`
  (+ `T.boot`, `bootstrap.condition`, `bootstrap.rank` if `return_boot`).
- Failure returns are *partial* lists with different field sets per status
  (`nested_test2.r:1544-1558, 1581-1595, 1675-1707, 1874-1934`).

---

## 3. Finalized vs historical implementations

Authority evidence common to all rows: README at the tag, lines 19–71 ("Only
the scripts listed under Final manuscript pipeline define the authoritative
analysis path"); commit `29320a9` introduces every final file and rewrites
`ode.r`; historical files were last changed in March 2026 (`67667d5`,
`5266f66`, the latter comments/formatting only); in-code markers such as
`BENCHMARK_VERSION <- "corrected_onset_v1"` and
`ALLOW_LEGACY_RECOVERY <- FALSE` ("MUST remain FALSE",
`run_benchmark_main_corrected_onset_revision.R:163-172`) and the API guard in
`run_GSE256335_matched_corrected_onset_benchmark.R:136-195`.

| Topic | Authoritative | Superseded / historical | Evidence and differences |
|---|---|---|---|
| Core test | `commons/nested_test2.r` | `commons/nested_test.r` | v1: diagonal variances only, pooled variance over the whole dataset (includes between-time mean change), interval-major rows, increment-level parametric or wild bootstrap with **fixed A**, failed bootstrap fits counted as `T*=0`, randomised tie-breaking p-value, no boundary rule, `seed` argument accepted but **never used**, `IR = 0` if RSS0 ≤ 0. v2: full within-time covariance, shrinkage + relative floor, `D Σ Dᵀ` propagation, GLS whitening, replicate-level generative bootstrap with reconstruction of A*, b*, Σ_b*, deterministic add-one p, explicit boundary rule, seed applied. Both define `test_sigma_nested` → **name collision; sourcing order decides**. v1 sourced only by historical `run_tests.r:54`, `run_nested_test.r:39`, `fig_representative_dynamics.r:40`. |
| ODE module | `ode_model/ode.r` at tag (rewritten in `29320a9`) | pre-freeze `ode.r` (`git show 5266f66:ode_model/ode.r`) | Old: random *observation* time shift applied post hoc; shutoff applied to shifted trajectory. New: gene-specific *transcriptional onset history* with common `t_star`. Legacy helpers retained but unused by final scripts: `apply_observation_shift` (`ode.r:681-764`), `simulate_piecewise_trajectory` (`651-671`), `simulate_latent_trajectory` (`255-294`), `use_time_shift`/`time_shift` aliases. |
| Synthetic generator | `synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R` → `ode_states_2k_20p_corrected_onset.rdata` | `synthetic_dataset/gen_synthetic_ODE_states.r` → `ode_states_2k_20p.rdata` | Corrected: `alpha_s ~ U(0.01, min(alpha, 0.23))` (historical: `U(0.01, alpha)`), one onset per gene with its own seed, 8 residual-transcription levels (`rho ∈ {0,.05,.10,.25,.50,.75,.90,1}`), new metadata columns. Header/comments of the corrected script contain stale statements (filename "retained", rho list, "rho=1 not generated") — cosmetic. |
| Main benchmark | `run_benchmark_main_corrected_onset_revision.R` + `analyze_benchmark_corrected_onset_final.R` | `synthetic_dataset/run_tests.r`, `fig_calibration_power.r`, `fig_pr_roc.r` | Historical: unseeded, `nested_test.r`, lambda grid, T_step fixed at 10, `N_boot = 5000`. Final: seeded per task, single configuration, 1152 configurations. Run metadata in tag matches the final runner. |
| Pseudo-shutoff | `run_pseudoshutoff_misspecification_benchmark.R` (feeds `make_FigS_pseudoshutoff_minimal.R:33`) | `run_benchmark_pseudoshutoff_revision.R` (**listed as final in README:41**) | The older runner loads `ode_states_2k_20p.rdata` (`:118`), i.e. the *legacy* generator's output, which has no `PSEUDO_SHUTOFF`/`Post_R_fraction`; it cannot be reproduced from the tag, and its integer seed formula collides across genes/rho/platforms. **[SF-4]** |
| Fraction separation | `run_fraction_separation_robustness_benchmark.R` (feeds `make_FigS_fraction_misspecification.R:40`) | — | New in revision. |
| Real data (pseudo-shutoff) | `real_datasets/run_real_datasets_revision.R` (Kc167, K562, NIH-3T3) | `real_datasets/run_nested_test.r`, `fig_representative_dynamics.r`, `fig_diagnostics.r`, `go_analysis.r` | Historical: `nested_test.r`, unseeded, positional-indexing bug in `lambda` lookup (`run_nested_test.r:122, 210`), uses the removed `deltaAIC` field. **Final script sets `N_BOOT <- 1999` (`:146`) but deposited p-values imply B = 4999 [SF-1].** |
| Real data (mESC) | `real_datasets/run_mESC_20k.R` (`N_BOOT = 19999`) | mESC rows of `run_real_datasets_revision.R` | `audit_final_real_data.R:666-739` drops mESC from the revision table and appends the 20k results. `real_dataset_discovery_summary.tsv` (180 / 29 / 12) is from the revision run; `final_real_data_audit/*.tsv` (179 / 28 / 14) is authoritative. The 20k script re-implements QC inline without the within-time replication rule (no effect on mESC: 3 replicates everywhere) **[SF-8]**. |
| Real-data audit | `real_datasets/audit_final_real_data.R` | — | Produces the reference TSVs in `final_real_data_audit/`. Unique genes are counted by biomaRt gene symbol (revision summary counts Ensembl IDs → 1642 vs 1635 for K562, etc.). |
| Representative-event figure | `real_datasets/fig_representative_Ppp1r36dn_Nsd1_common_y0_FINAL.R` | `fig_representative_dynamics.r` | FINAL does not refit; draws continuous-ODE (lsoda) curves from stored coefficients. |
| ΔPSI comparator | `synthetic_dataset/analyze_three_way_AUPR.R:487-666` (`compute_delta_psi_test`) | `commons/psi_test.r` (`baseline_psi_logit_ttest_pre_vs_post`) | Different windows, aggregation, logit stabilisation, filters, degenerate handling. `psi_test.r` is sourced by the main runner (`:153`) but never called. **[SF-5]** |
| PR-AUC | `analyze_composite_score_ablation.R:252-283` = `regenerate_corrected_discrimination_figures.R:178-203` | `analyze_three_way_AUPR.R:907-1048` (different: reorders by recall, precision) | Diverge under score ties. **[SF-6]** |
| Plot helpers | FINAL figure scripts (own `ode_rhs`, `t >= t_star`) | `commons/plot.r` (`ode_rhs` with strict `t > t_star`, `optimal_y0`) | Plotting only; not scientific sources for the package. |

`commons/platforms.r` and `commons/psi_test.r` are not listed as "core" in the
README, but `platforms.r` is sourced by every final synthetic runner and is
therefore authoritative for the assay models (unchanged since March except
comments).

---

## 4. Proposed package architecture

Principle: **port verbatim, then wrap.** The frozen numerical functions are
first ported into the package as internal functions whose bodies are
unchanged except for mechanical, behaviour-neutral edits (namespace-qualified
calls such as `stats::median`, `nnls::nnls`; no reliance on globals; constants
moved to one file). User-facing functions are thin wrappers that validate
input, call the internal ports in the frozen order, and assemble result
objects. Any later internal refactor must pass the frozen-reference fixtures.

### 4.1 Layers and files (`R/`)

| Layer | File | Contents | Frozen source |
|---|---|---|---|
| Constants | `constants.R` | `.PEK_STATES` (= `KINETIC_VARS`), `.PEK_PARAMS` (= `PARAM_NAMES`), manuscript defaults | `nested_test2.r:29-44` |
| Input | `data-input.R` | long/wide parsing into canonical form; column mapping | new (no frozen equivalent; see Section 5) |
| Validation | `data-validate.R` | error/warning/info checks (Section 6) | thresholds from `nested_test2.r`, benchmark design |
| Representation | `data-class.R` | `postexport_data` S3 constructor, `print`, `summary`, `[`, `as.data.frame` | new |
| Matrix utilities | `matrix-utils.R` | `.make_spd`, `.inverse_sqrt_matrix` | `nested_test2.r:51-192` |
| Covariance | `covariance.R` | `.time_summary_cov_shrink`, `.build_sigma_means`, `.build_difference_matrix` | `nested_test2.r:199-573` |
| Interval construction | `interval-balance.R` | `.build_Ab_fullcov`; exported wrapper `build_interval_balance()` | `nested_test2.r:580-889` |
| Fitting | `fit.R` | `.fit_nnls_nested_once`, coefficient rescaling; exported `fit_postexport_model()` | `nested_test2.r:896-1079, 1597-1632` |
| Null propagation | `crank-nicolson.R` | `.kinetic_matrix`, `.cn_interval`, `.predict_null_cn` | `nested_test2.r:1093-1310` |
| Bootstrap | `bootstrap.R` | `.simulate_destructive_null`, `.bootstrap_T` (loop body) | `nested_test2.r:1317-1440, 1709-1872` |
| Inference | `inference.R` | `.test_sigma_nested` (orchestration: failure rate, boundary, add-one p, diagnostics); exported `test_postexport_conversion()` | `nested_test2.r:1447-2166` |
| Batch / multiple testing | `batch.R`, `multiple-testing.R` | per-event loop, per-event seeds, optional `BiocParallel`; BH within call/dataset | `run_real_datasets_revision.R:719-1237, 1436-1446`; `run_mESC_20k.R:666-1019, 1758-1765` |
| RNG | `seeds.R` | `.stable_seed_from_string`, frozen key builders (`main`, `mesc_20k`, `real_revision`) | Section 2.1 row T |
| Simulation (ODE) | `ode.R` | `.rna_kinetics`, `.steady_states`, `.integrate_interval_fixed_R`, `.simulate_scheduled_trajectory`, `.generate_ODE_states`; exported `simulate_postexport_kinetics()` | `ode.r` |
| Simulation (parameters) | `simulate-parameters.R` | `.random_params`, corrected-onset gene draw (`simulate_one_gene` parameter block) | `ode.r:96-248`; `gen_…_corrected_onset.R:307-432` |
| Simulation (assay) | `assay.R` | `.add_gaussian_noise`, `.sample_dispersion_gamma`, `.simulate_rnaseq`, `.simulate_rt_qpcr`, preset table; exported `add_assay_noise()` | `platforms.r`; presets `run_benchmark_main…R:469-474, 538-645` |
| Simulation (misspecification, optional) | `misspecification.R` | `.apply_fraction_scaling`, `.apply_cross_contamination` | `run_fraction_separation_robustness_benchmark.R:567-661` |
| Diagnostics | `diagnostics.R` | assembly of numeric/boundary/bootstrap diagnostics; design summary | fields from `nested_test2.r` |
| Operational domain | `domain.R`, `R/sysdata.rda` | benchmark-design table and matching (Section 8) | `benchmark_main_corrected_onset_summary.tsv` |
| Ranking | `ranking.R` | composite score and ordering | Section 2.1 row V |
| Trajectories | `trajectory.R` | CN (inference-consistent) and ODE (display) reconstruction of fitted/null curves | `nested_test2.r:1216-1310`; `fig_representative_…FINAL.R:605-805` |
| Methods | `methods-print.R`, `methods-summary.R`, `methods-plot.R`, `methods-coef.R` | S3 methods | new |
| Plotting | `methods-plot.R` | base-graphics plots; no computation beyond reading the object and `trajectory.R` | new |

Plotting is strictly separated from inference: `plot()` never refits and never
consumes RNG.

### 4.2 What is deliberately *not* in the package

Manuscript workflows (factorial benchmark loops, PSOCK orchestration,
checkpointing, progress files), figure scripts, LaTeX/xlsx writers, biomaRt
annotation, GO enrichment, raw-read pipelines (`*.sh`), full normalized CSVs,
benchmark raw outputs, legacy helpers (`apply_observation_shift`,
`simulate_piecewise_trajectory`, `simulate_latent_trajectory`), `nested_test.r`,
and the older pseudo-shutoff runner. The cytoplasmic-only and ΔPSI comparators
are excluded from the first release pending [SF-5]/[SF-7] (they could later
live in a separate, clearly labelled `compare_*` family or in `tools/`).

---

## 5. Proposed public API

Target: about ten exported functions plus S3 methods. Names below are
proposals; alternatives are listed in Section 16.B.

### 5.1 Exported functions

| # | Function | Purpose | Inputs | Returns | Frozen source | Abstraction change only? |
|---|---|---|---|---|---|---|
| 1 | `postexport_data()` | Parse and validate compartment-resolved time-course data into canonical form | `x` (data.frame), `format = c("auto","wide","long")`, column mapping (`event`, `time`, `replicate`, `compartment`, `processing`/`state`, `abundance`), `time_unit` (required, character), `missing_state = c("error","NA","zero")` (default `"error"`) | `postexport_data` (canonical long table + validation report + design metadata) | none (pre-processing); `"zero"` reproduces `dcast(fill = 0)` in `gen_RMATS_table.r` | Yes — no effect on numerics given identical wide input |
| 2 | `validate_postexport_data()` | Stand-alone validation report (also run by #1) | `postexport_data` or data.frame, optional `t_star` | `postexport_validation` (errors, warnings, info) | thresholds from `nested_test2.r` | Yes |
| 3 | `postexport_control()` | Collect numerical settings with manuscript defaults | `lambda_time = 0.5`, `lambda_diag = 0.1`, `rel_floor = 1e-8`, `scaling_A = TRUE`, `truncate_nonnegative_boot = FALSE`, `max_failure_rate = 0.05` | `postexport_control` | `nested_test2.r:1447-1475` | Yes (defaults identical; `lambda_var` alias not exposed [SF-15]) |
| 4 | `build_interval_balance()` | Expose `A`, `b`, `Sigma_b`, covariance summaries for one event (transparency / advanced use) | one-event `postexport_data`, `t_star` (required argument, may be `NULL`), `control` | `postexport_system` | `build_Ab_fullcov` | Yes |
| 5 | `fit_postexport_model()` | Deterministic full and `sigma_c = 0` null NNLS fits, statistic, IR, conditioning — **no bootstrap, no RNG** | one or more events, `t_star`, `control` | `postexport_fit` (single) / `postexport_fit_set` | first half of `test_sigma_nested` (`:1510-1632`) | Yes — same code path; the p-value is simply absent |
| 6 | `test_postexport_conversion()` | Full bootstrap test for one or many events | data, `t_star` (required), `B = 1999`, `seed` (required for many events: base seed or named vector of per-event seeds), `seed_scheme` (see 5.3), `control`, `keep_boot`, `BPPARAM = NULL`, `p_adjust = "BH"` | `postexport_test` (single) / `postexport_results` (many; includes BH q within the call) | `test_sigma_nested`; batch/BH from real-data scripts | Yes, if seeds are supplied exactly as in the frozen scripts |
| 7 | `rank_postexport_candidates()` | Exploratory prioritisation | `postexport_results`, `score = "sigma_IR_q"` (default; see 5.4), `cap = 6`, `q_floor = 1e-10` | data.frame ordered by score with score components | Section 2.1 row V | Yes (definition per [SF-9]) |
| 8 | `simulate_postexport_kinetics()` | Replicate-level four-state simulation with onset and intervention semantics | `params` (named list/vector incl. `R`), `times` (sampling times), `n_replicates`, `t_star = NULL`, `post_R_fraction = 0`, `onset_time = 0`, `param_cv = 0.05`, `y0 = 0` states, `grid_step = 1`, `seed = NULL` | `postexport_data` with attribute `truth` (parameters per replicate, onset, t_star, rho, steady state) | `generate_ODE_states` + `simulate_scheduled_trajectory` | Yes (wrapper selects `intervention_tsampled_data` or `tsampled_data`; see Section 16.B-7) |
| 9 | `add_assay_noise()` | Assay/measurement noise with manuscript presets | `postexport_data`, `platform = c("gaussian","rnaseq","rtqpcr")`, `level = c("very_low","low","medium","high")` or explicit parameters, `seed = NULL` | `postexport_data` (noisy) | `platforms.r` + `add_platform_noise_main` | Yes (target order `N, C, C_s, N_s` preserved) |
| 10 | `check_operational_domain()` | Compare a design with benchmarked regimes (diagnostic only) | `postexport_data` or a design spec (`times`, replicates per time, `t_star`, intervention type), optional `platform`, `noise_level` | `postexport_domain` report | `benchmark_main_corrected_onset_summary.tsv` | New diagnostic; no inference change |
| 11 | `postexport_trajectory()` | Fitted full/null mean trajectories for plotting | `postexport_fit`/`postexport_test`, `model = c("null","full")`, `method = c("crank_nicolson","ode")`, `times` | data.frame | CN: `predict_null_cn`; ODE: FINAL figure scripts | Yes; ODE method is display-only and documented as such |

Optional (Phase 3, pending [SF-7], [SF-11]): `sample_kinetic_parameters()`
(benchmark parameter prior), `perturb_fraction_separation()` (scaling /
contamination), `rmats_to_postexport()` (rMATS → four states).

### 5.2 S3 methods

`print()`, `summary()`, `plot()`, `coef()` (full/null), `as.data.frame()` for
`postexport_test`, `postexport_fit`, `postexport_results`; `print()` /
`summary()` for `postexport_data`, `postexport_validation`, `postexport_domain`,
`postexport_system`. `[` and `as.data.frame()` for `postexport_results`.

### 5.3 Seeds and reproducibility in the API

- Single event: `seed` is passed to `set.seed()` immediately before the
  observed system is built, exactly as in `nested_test2.r:1501-1504`.
- Many events: each event receives its own seed. `seed_scheme` options:
  - `"hash"` (proposed default): `.stable_seed_from_string(paste(seed, event,
    sep = "|"))` using the frozen hash (`run_benchmark_main…R:658-686`).
  - `"mesc_20k"`: `stable_event_seed(event)` (`run_mESC_20k.R:515-558`) — needed
    to reproduce the mESC results.
  - `"real_revision"`: `make_real_seed(dataset, event)`
    (`run_real_datasets_revision.R:687-712`).
  - A named integer vector of seeds supplied by the user.
- Worker-count independence follows from per-event reseeding (as in the
  frozen scripts). `BPPARAM` only changes execution order.
- Whether the package should **restore the caller's global RNG state** after
  `set.seed()` is an open API decision (Section 16.B-3); it does not change
  any computed value.

### 5.4 Input representations

| Representation | Supported | Rationale / ambiguity handling |
|---|---|---|
| Wide: `event, time, replicate, N, N_s, C, C_s` | **Yes (canonical)** | Exactly the frozen input (`tsampled_data`). One row = one destructive biological sample. `replicate` is a label only; it is never used for pairing across time (frozen semantics, `nested_test2.r:1408-1411`). |
| Long (state-level): `event, time, replicate, state ∈ {N,N_s,C,C_s}, abundance` | **Yes** | Pivot to wide requires exactly one value per `(event,time,replicate,state)`. Duplicates → **error** (no implicit summing; summing is a preprocessing decision). Missing states → governed by `missing_state` (default error). |
| Long (compartment × processing): `event, time, replicate, compartment ∈ {nuclear,cytoplasmic}, processing ∈ {unprocessed,processed}, abundance` | **Yes** | Mapping fixed and printed: nuclear/unprocessed→N, nuclear/processed→N_s, cytoplasmic/unprocessed→C, cytoplasmic/processed→C_s. For rMATS RI events: inclusion = unprocessed, skipping = processed (`gen_RMATS_table.r`; README). Labels must be declared explicitly (no guessing from strings such as "nuc"/"cyt" unless the user passes the mapping). |
| rMATS-style raw long tables | Deferred (optional helper) | The frozen conversion includes dataset-specific normalisation and zero-fill; not reproducible for K562/3T3 from the tag [SF-11]. |
| `SummarizedExperiment` | Deferred | Bioconductor-friendly; requires a mapping of assays/colData to states and times; candidate for Phase 3 (Section 11). |

Time units are required metadata (not converted silently). Rate parameters
are per unit of the supplied time; `check_operational_domain()` and printed
half-lives (`log(2)/sigma_c`) use that unit.

---

## 6. Input validation design

Principle: the package **never changes numerics** relative to the frozen code
for inputs that the frozen code accepts. Validation adds information and
refuses only inputs that the frozen code would fail on or that are
structurally ambiguous. No new scientific thresholds are invented: thresholds
come from the frozen code (ERROR) or from the benchmarked design range
(WARNING / INFO), and are labelled with their source.

| Condition | Level | Rule and source |
|---|---|---|
| Required columns / states missing | ERROR | `nested_test2.r:216-235` stops on missing columns. |
| Non-numeric abundance or time | ERROR | frozen `colMeans`/`cov` would fail or coerce. |
| Non-finite time | ERROR | `diff(times)` must be finite (`nested_test2.r:604-612`). |
| Fewer than 2 distinct time points | ERROR | `nested_test2.r:244-246`. |
| A time point with no complete observation | ERROR | `nested_test2.r:301-309`. |
| No time point with ≥ 2 complete replicates | ERROR | pooled df = 0 → `nested_test2.r:337-342`. |
| `t_star` not `NULL` and not a single finite number | ERROR | `nested_test2.r:691-701`. |
| `B < 1`, lambdas outside [0,1] | ERROR | `nested_test2.r:207-212, 1487-1496`. |
| Duplicated `(event, time, replicate)` in long input / ambiguous pivot | ERROR | structural ambiguity (package rule). |
| Duplicated `(event, time, replicate)` in wide input | WARNING | frozen code treats rows as independent samples; report, do not alter. |
| Rows with NA in any state | WARNING | frozen code silently drops incomplete rows per time (`complete.cases`, `nested_test2.r:293-297`); package reports counts, same numerics. |
| Negative abundance | WARNING | frozen code accepts it (Gaussian-noise benchmark produces negatives); states are non-negative quantities by definition. Level to be confirmed (Section 16.C). |
| All-zero state for an event | WARNING | real-data QC rule `state_all_zero` (`run_real_datasets_revision.R:485-657`); frozen core accepts. |
| Unsorted time points | INFO | frozen code sorts (`nested_test2.r:237-239`). |
| Unequal replicates across times | INFO | supported by design (`n_rep[k]`). |
| A time point with exactly 1 replicate | WARNING | its covariance is replaced by the pooled covariance (`nested_test2.r:395-409`). |
| Exactly 2 time points | WARNING | 4 equations vs 7 parameters; below benchmarked range (min 3 time points). |
| Fewer than 3 replicates per time | WARNING (domain) | benchmark minimum is 3 (`gen_…_corrected_onset.R:176-180`); pseudo-shutoff real datasets used 2. |
| `t_star <= min(time)` | INFO | R column structurally zero; `R` not estimable; condition number = Inf and `rank.full = 6` by construction (all four real datasets) **[SF-10]**. |
| `t_star >= max(time)` | WARNING | equivalent to no shutoff within the sampled window. |
| `t_star = NULL` (continuous transcription) | WARNING (domain) | benchmark NONE regime: 0/576 cells with Wilson CI containing 0.05; median empirical Type I at 0.05 = 0.394 (Section 8). |
| Ill-conditioned covariance (eigenvalues floored) | DIAGNOSTIC | report number of eigenvalues raised to the floor in each `make_spd` call (computed alongside; same numerics) — new diagnostic, requires approval **[SF-10]**. |
| Time units missing | ERROR | package rule (required metadata). |
| Unsupported designs (e.g. several intervention times, residual-transcription–aware fits) | ERROR | not in the frozen model. Pseudo-shutoff data are accepted but fitted as complete shutoff, with a domain WARNING (pseudo-shutoff benchmark). |

Real-data QC (`filter_event`: coverage and dynamic-range 1 % quantiles,
`min_pos = 3`, `min_frac = 0.30`, zero-fraction limits 0.70 / 0.80,
within-time replication ≥ 2) is **dataset-level preprocessing**, not
validation. Proposed as an optional exported helper
`filter_postexport_events()` in Phase 3 with the exact frozen rules, clearly
documented as the manuscript's QC and dependent on the dataset [SF-8].

---

## 7. Result object design

### 7.1 `postexport_test` (one event)

```
postexport_test (list, S3)
├─ event, dataset                         identifiers
├─ status, error_message                  frozen status codes (Section 2.1 S)
├─ estimates
│   ├─ coef_full     named numeric(7)     PARAM_NAMES order, original scale
│   ├─ coef_null     named numeric(7)     sigma_c = 0
│   └─ sigma_c       = coef_full["sigma_c"]
├─ fit
│   ├─ RSS_null (RSS0), RSS_full (RSS1)   whitened scale
│   ├─ T_obs          max(0, RSS0 - RSS1)
│   └─ IR             relative RSS improvement (NA if RSS0 <= 0)
├─ inference
│   ├─ p_value        add-one bootstrap p (NA unless status == "ok")
│   ├─ B_requested, B_valid, failure_rate
│   ├─ T_boot         optional (keep_boot)
│   └─ method         "generative parametric bootstrap, add-one p"
├─ boundary
│   ├─ tolerance      1e-10 * max(1, |RSS0|, |RSS1|)
│   ├─ at_boundary    T_obs <= tolerance  (=> p_value = 1)
│   ├─ atom_zero      mean(T_boot <= tolerance)
│   └─ sigma_c_zero   |sigma_c| < 1e-12 (audit definition; reported separately)
├─ diagnostics
│   ├─ condition_number, min_singular_value, rank_full, rank_null
│   ├─ structurally_zero_columns (proposed, [SF-10])
│   ├─ bootstrap: condition median/q95/max, rank_deficient_fraction
│   └─ covariance: pooled covariance, eigenvalue-floor counts (proposed)
├─ design
│   ├─ times, n_replicates_by_time, t_star, time_unit
│   └─ validation     postexport_validation
├─ null_means         CN null trajectory used by the bootstrap
├─ control            postexport_control used
└─ reproducibility
    ├─ seed, seed_scheme, RNGkind()
    ├─ package version, frozen tag + SHA the implementation is validated against
    └─ R version, BLAS/LAPACK (sessionInfo excerpt)
```

A lossless accessor `as_frozen_list()` (internal or exported for validation)
returns the exact frozen `test_sigma_nested()` field names, so regression
tests compare the frozen list field by field.

### 7.2 `postexport_results` (many events)

A data.frame-like object (one row per event) with columns for identifiers,
status, `sigma_c`, `IR`, `T_obs`, `RSS0`, `RSS1`, `p_value`, `q_value` (BH
within the call unless `p_adjust = "none"`), boundary flags, key diagnostics,
seed; plus attributes: list of per-event `postexport_test` objects (optional),
control, domain report, session metadata.

### 7.3 `print`, `summary`, `plot`

- `print.postexport_test`: status, `sigma_c` (with unit and half-time when
  > 0), IR, T_obs, p (with B_valid), boundary line, design line, one-line
  interpretation note ("kinetic evidence consistent with an additional
  post-export conversion component within the model; does not identify a
  molecular mechanism").
- `summary.postexport_test`: full/null coefficient table, RSS table, full
  diagnostics, domain report, reproducibility block.
- `summary.postexport_results`: counts of tested/ok/failed, p < 0.05,
  q < 0.10/0.05, boundary fraction, status table, domain summary.
- `plot.postexport_test(type = c("trajectories","bootstrap","residuals"))`:
  observed replicate points and means; full and null mean trajectories from
  `postexport_trajectory()` (CN at observed times by default; ODE curves as an
  explicitly labelled display option); histogram of `T_boot` with `T_obs`
  and the boundary atom. Base graphics; no refitting.
- `plot.postexport_results(type = c("pvalues","volcano"))`: p-value histogram
  / QQ; `sigma_c` vs `-log10(q)`.

---

## 8. Operational-domain diagnostics

### 8.1 Why

Calibration is strongly design dependent in the frozen benchmark
(`FROZEN:synthetic_dataset/benchmark_main_corrected_onset_summary.tsv`, 1152
cells, ~2000 genes each, B = 1999). Computed during this audit:

| Slice | Cells | Wilson 95 % CI of Type I contains 0.05 | Median Type I (α = 0.05) | Median power |
|---|---:|---:|---:|---:|
| NONE (continuous transcription) | 576 | 0 | 0.394 | 0.527 |
| SHUTOFF (all) | 576 | 68 (309 anti-conservative, 199 conservative) | 0.071 | 0.280 |
| SHUTOFF, T_step = 5 | 144 | 17 (11 anti-, 116 conservative) | 0.021 | 0.136 |
| SHUTOFF, T_step = 10 | 144 | 40 (22 anti-, 82 conservative) | 0.037 | 0.208 |
| SHUTOFF, T_step = 20 | 144 | 11 (132 anti-, 1 conservative) | 0.110 | 0.289 |
| SHUTOFF, T_step = 50 | 144 | 0 (144 anti-conservative) | 0.279 | 0.485 |
| SHUTOFF, replicates 3 / 5 / 10 | 192 each | 16 / 20 / 32 | 0.089 / 0.070 / 0.059 | 0.232 / 0.270 / 0.379 |

(Computed during the audit from the frozen summary TSV; the package's domain
table will be regenerated by a script, not hand-copied. "anti-" = Wilson lower
bound > 0.05, "conservative" = Wilson upper bound < 0.05, as in
`analyze_benchmark_corrected_onset_final.R:406-424`.) These are empirical benchmark
facts under the benchmark's parameter prior, time scale (rates per minute,
`T_star = 332`) and assay models; they are **not** calibration guarantees for
other data.

Additional design facts that must be encoded exactly:

- The nominal `N_time_samples` label differs from the effective number of
  time points in some cells: NONE 10 → 9, NONE 20 → 17, SHUTOFF (20, step 50)
  → 15 (computed from `gen_…_corrected_onset.R:470-545`). **[SF-12]**
- The NONE sampling grid does not depend on `T_step`; the four NONE × T_step
  cells are re-simulations of the same design. **[SF-12]**
- SHUTOFF designs sample one point before `t_star` (`T_star - T_step`), one at
  `t_star`, then `n - 2` points at spacing `T_step`.
- Real mESC design (hard-coded in the matched benchmark, consistent with the
  data): 0, 30, 60, 120, 240 min after pharmacological shutoff, 3 replicates,
  fitted with `t_star = 0`. Pseudo-shutoff datasets: K562/NIH-3T3 0, 15, 30,
  60, 120 min, 2 replicates; Kc167 0, 30, 90, 180, 300, 450 min, 2 replicates.
- The mESC-matched benchmark keeps only "Medium"/"High" noise citing a
  noise-matching analysis that is **absent from the tag** **[SF-3]**, and its
  summary TSV is not in the tag.

### 8.2 Proposed representation

`R/sysdata.rda` object `.pek_benchmark_domain`, generated by a script in
`data-raw/benchmark_domain.R` from the frozen summary TSV (read from a
`git archive` export; provenance = tag + SHA + file checksum). Columns:
`perturbation` (NONE / SHUTOFF), `platform`, `noise_level`,
`n_time_nominal`, `n_time_effective`, `n_replicates`, `t_step`,
`times_relative_to_t_star` (list), `type1_005`, `type1_wilson_low/high`,
`calibration_class` (as in `analyze_benchmark_corrected_onset_final.R:406-424`),
`power_005`, `valid_fraction`, `median_condition`. The pseudo-shutoff and
fraction-separation summaries are not in the tag and are therefore **not**
included unless the author supplies them (Section 16.C).

### 8.3 Matching (diagnostic only)

`check_operational_domain()` reports:

1. **Design descriptors computed from the data** (no thresholds): intervention
   type, number of time points, replicates per time (min/median), number of
   pre-/post-`t_star` samples, sampling spacing relative to `t_star`, whether
   the R column is structurally zero, time unit.
2. **Nearest benchmark cells** by exact matching on intervention type and
   replicate level (rounded down to {3, 5, 10}), number of effective time
   points (nearest of the benchmarked values) and relative spacing. Because
   rate scales differ between systems, spacing can only be compared *in the
   benchmark's time unit (minutes) under the benchmark's parameter prior*; the
   report says so explicitly and shows the matched cells' empirical Type I
   (with Wilson CI) and power **across all platforms and noise levels**, unless
   the user states `platform`/`noise_level`.
3. **Flags** (never errors): "continuous-transcription design: no benchmarked
   cell was calibrated"; "below benchmarked replication"; "design outside the
   benchmark grid"; "pseudo-shutoff data fitted as complete shutoff: see
   pseudo-shutoff sensitivity analysis in the manuscript".

Wording is fixed in advance to avoid implying guarantees (e.g. "In the
manuscript benchmark, the most similar designs showed empirical Type I error
between X and Y"). Final wording to be approved (Section 16.C).

---

## 9. Regression test strategy

### 9.1 Mechanism

1. **Frozen snapshot, never the live repo.** `tools/frozen/export_frozen.sh`
   runs `git -C ~/postexport-kinetics archive manuscript-revision-v1.0 | tar -x
   -C <tmp>` and verifies that the tag resolves to
   `65c3b7368fb7686bfde3dab857f98c393bb534c5`. No other Git command is used.
2. **Reference generation.** `tools/frozen/make_fixtures.R` sources only the
   frozen *function definitions* (`commons/nested_test2.r`, `ode_model/ode.r`,
   `commons/platforms.r`; for script-embedded functions such as
   `simulate_one_gene`, `stable_seed_from_string`, `add_platform_noise_main`,
   the function bodies are extracted by parsing the frozen file with
   `parse()` and evaluating only the named `function` assignments — scripts'
   top-level code (setwd, cluster start, full loops) is never run). It writes
   `tests/testthat/fixtures/*.rds` containing inputs, frozen outputs and a
   provenance record (tag, SHA, R version, `RNGkind()`, BLAS/LAPACK, `nnls`,
   `MASS`, `deSolve` versions, platform).
3. **Package tests** load fixtures and compare the package output. Fixtures
   are committed; they are regenerated only by the script, never edited by
   hand, and a regeneration must be reported with a diff of values.
4. **Optional live mode.** If `POSTEXPORT_FROZEN_DIR` points at an exported
   snapshot, tests additionally source the frozen code and compare live
   (skipped on CRAN/Bioconductor builders).
5. Prerequisites (after approval): install `nnls`, `deSolve`, `expm`,
   `testthat`, `BiocCheck` locally.

### 9.2 Tolerance tiers (justification)

| Tier | Comparison | Tolerance | Justification |
|---|---|---|---|
| T0 | integers, status strings, ranks, seeds, integer-valued RNG draws, p-values on the platform that generated the fixture | exact (`identical`) | discrete quantities; same arithmetic and RNG |
| T1 | pure arithmetic without decompositions (A, b, D, Sigma_m, trapezoid integrals, CN step, seeds' double arithmetic, noise transforms) | `1e-12` relative | only reordering of floating-point sums could differ; code is ported verbatim |
| T2 | quantities through `eigen`/`svd`/`solve`/NNLS (make_spd, whitening, coefficients, RSS, T, IR, condition number) | `1e-10` relative (abs `1e-14` near zero) | backward-stable decompositions give errors ~ κ·ε; observed benchmark condition numbers are ~1e2–1e4 → ≤ ~1e-12; margin for BLAS differences. **An NNLS active-set change is a discontinuity and must fail, not be absorbed by a wider tolerance.** |
| T3 | ODE outputs (deSolve) | `1e-12` relative with the same `deSolve` version; otherwise documented `1e-6` | `lsoda` defaults `rtol = atol = 1e-6`; identical code/version is deterministic |
| T4 | bootstrap p-values across platforms (validation tool only) | not required to be identical; compare against Monte-Carlo error `sqrt(p(1-p)/B)` | `MASS::mvrnorm` uses `eigen()`; eigenvector sign/order may differ across LAPACK builds (frozen run: OpenBLAS 0.3.3 / LAPACK 3.8.0; local: reference BLAS) |

Unit tests compare against fixtures generated **on the same machine** as the
first implementation; CI on other platforms runs T0–T3 for deterministic
components and marks T0 bootstrap-p comparisons as platform-specific
(`skip_if_not(fixture_platform_matches())`), with a cross-platform statistical
check instead.

### 9.3 Fixtures

All fixtures are small; the full benchmark is never run in tests.

| ID | Component | Construction | Compared outputs | Tier |
|---|---|---|---|---|
| FX-ODE-1 | ODE RHS | fixed params/state | `rna_kinetics` derivatives; `steady_states` vs algebra and vs long integration | T1 / T3 |
| FX-ODE-2 | scheduled trajectory: onset, shutoff, residual | `simulate_scheduled_trajectory` with onset ∈ {-30, 0, +20}, `t_star ∈ {NULL, 100}`, `post_R_fraction ∈ {0, 0.25, 1}`, times `c(0, 5, 50, 95, 100, 105, 150, 200)` | states and `R` column; R = 0 before onset, R_post after t_star (right-continuous) | T3 / T0 (R) |
| FX-ODE-3 | replicate generation + RNG order | `generate_ODE_states` with fixed seed, 3 replicates, `param_cv = 0.05` | `parameters` (7 draws per replicate, list order `tau, tau_s, alpha, alpha_s, sigma_n, sigma_c, R`), sampled data | T0 (params) / T3 |
| FX-GEN-1 | corrected-onset generator (gene level) | frozen `simulate_one_gene()` extracted by parse, for gene ids 1–4 with the full 48-cell design grid (RNG is sequential across cells), store only cells `(3 reps, 5 tp, T_step 10)` and `(5, 10, 20)` | latent data incl. onset, truth, Base_* | T0 / T3 |
| FX-SEED-1 | seed functions | fixed keys, e.g. `"1|5|3|10|SHUTOFF|GAUSS|Low|measurement"`; mESC event ids of Ppp1r36dn and Nsd1; real-revision key; empty string (`104729`) | integers | T0 |
| FX-NOISE-1 | assay presets | 3-row latent table, fixed seed, 3 platforms × 4 levels | noisy values; also RNG consumption order | T0 (RNA-seq counts) / T1 |
| FX-COV-1 | `make_spd`, `inverse_sqrt_matrix` | SPD, indefinite, zero-diagonal, all-zero, non-finite, 1×1 matrices | matrices / NULL returns | T2 / T0 |
| FX-COV-2 | `time_summary_cov_shrink` | hand table: 4 times × 3 reps, one time with 1 replicate, one row with NA, `lambda_time ∈ {0, 0.5, 1}`, `lambda_diag ∈ {0, 0.1, 1}` | means, n_rep, cov_obs, cov_mean, pooled_cov; error cases (1 time; no replication) | T2 / T0 |
| FX-IB-1 | interval balance | same table with `t_star ∈ {NULL, 0, 25 (inside an interval), 30 (= a sample time)}`, `scaling_A ∈ {TRUE, FALSE}` | A, b, Sigma_m, D, Sigma_b, col_norms; R column truncation | T1 / T2 |
| FX-FIT-1 | full/null NNLS, statistic, IR | FX-IB-1 systems | coef_full/null (scaled and rescaled), RSS0, RSS1, T, IR, cond, min sv, ranks | T2 / T0 |
| FX-BND-1 | boundary | constructed data whose full fit has `sigma_c = 0` (T = 0) and a case with T just below/above `tol_zero` | `p = 1` branch, `boundary.tolerance`, `atom.zero` | T0 / T2 |
| FX-CN-1 | Crank–Nicolson null | `cn_interval`, `predict_null_cn` with/without `t_star`; comparison with `expm::expm` (Suggests), as in `analyze_CN_vs_exact_transition.R:140-195` | states; CN one-step error recorded | T1 / T2 |
| FX-BOOT-1 | bootstrap generation | `simulate_destructive_null` with fixed seed, n_k ∈ {1, 3} | generated table (incl. `n = 1` branch), truncation option | T0 same platform / T4 |
| FX-TEST-NULL | full test, null gene | benchmark cell (gene with `truth_pos = 0` from FX-GEN-1, SHUTOFF, 3 reps, 5 tp, T_step 10, GAUSS Low), frozen measurement and bootstrap seeds, `B = 99` | entire frozen return list (all fields) | T0/T2 |
| FX-TEST-ALT | full test, alternative gene | as above with `truth_pos = 1`; plus an RNA-seq Medium variant | entire frozen return list | T0/T2 |
| FX-TEST-NONE | continuous transcription | NONE cell, `t_star = NULL` | entire return list | T0/T2 |
| FX-TEST-FAIL | failure paths | 1 time point; no replication; forced high bootstrap failure (e.g. `max_failure_rate = 0`) | status, partial field sets | T0 |
| FX-PVAL-1 | add-one p | `return_boot = TRUE`: check `p == (1 + sum(T.boot >= T.obs)) / (length(T.boot) + 1)`; prefix property: `T.boot` for `B = 19` equals the first 19 of `B = 99` with the same seed | exact | T0 |
| FX-SEEDREP | fixed-seed reproducibility | same call twice; serial vs `BiocParallel::SerialParam`/`SnowParam(2)` | identical results | T0 |
| FX-REAL-1 | mESC Ppp1r36dn and Nsd1 (deterministic part) | 15-row inputs extracted from `real_datasets/GSE256335/gse256335_mouse_normalized.csv` by the frozen conversion (`GSE256335/gen_RMATS_table.r`), `t_star = 0`, frozen control | `sigma_c`, `IR` vs `final_representative_events.tsv` (0.01899229537886, 0.5350818120513; 0.04742466642579, 0.3810515261106) and all other fit fields vs frozen code | T2 vs frozen; `1e-8` relative vs TSV (15 significant digits written by `fwrite`) |
| FX-RANK-1 | composite score | hand table of p, sigma_c, RSS0, RSS1, groups (incl. q < 1e-6 cap, RSS0 = 0, sigma_c = 0 ties) | q (BH), capped −log10 q, IR, score, order | T1 / T0 |
| FX-MISC-1 | fraction transforms (if packaged) | N=10, N_s=2, C=5, C_s=1; ε = 0.1 → (9.5, 1.9, 5.5, 1.1); scaling s = 2 | exact | T1 |

The extracted real-data input for FX-REAL-1 (2 events × 15 rows) becomes the
package example dataset in `inst/extdata/` (with provenance: GEO accession
GSE256335, file, event IDs, conversion steps). Size: a few kB.

### 9.4 Manuscript validation tool (`tools/validate_against_manuscript.R`)

Not run by `R CMD check`. Steps, each reporting PASS/FAIL with values:

1. FX-REAL-1 against the tag's TSVs.
2. `sigma_c` and `IR` for all 28 events in
   `final_real_data_audit/final_mesc_FDR10_events.tsv` (deterministic, seconds).
3. Optional (`--bootstrap`): p-values for Ppp1r36dn (`p = 1e-4`) and Nsd1
   (`p = 5e-5`) with `B = 19999` and the `mesc_20k` seed scheme; exact match
   expected only on a platform whose `eigen()` matches the frozen run (T4 check
   otherwise). Runtime: minutes.
4. Optional (`--mesc-full`): mESC QC (1972 of 3420 events) and boundary count
   (1107) from the CSV; Kc167 with the ×60 time conversion (337 of 574; 181).
5. Report of package version, frozen SHA, platform.

---

## 10. Manuscript regression targets (integration references, not unit tests)

Final real-data audit (`FROZEN:real_datasets/final_real_data_audit/final_dataset_counts.tsv`;
BH within dataset):

| Dataset | Tested | Unique genes | p < .05 | q < .10 | q < .05 | Boundary (`|sigma_c| < 1e-12`) |
|---|---:|---:|---:|---:|---:|---:|
| Kc167 | 337 | 286 | 16 | 0 | 0 | 181 |
| K562 | 2696 | 1635 | 121 | 0 | 0 | 1651 |
| NIH-3T3 | 1746 | 1288 | 79 | 0 | 0 | 993 |
| mESC | 1972 | 1302 | 179 | 28 | 14 | 1107 |

Representative events (`final_representative_events.tsv`, from the 20k mESC run):

| Event | Gene | p | BH q | `sigma_c` (min⁻¹) | IR |
|---|---|---:|---:|---:|---:|
| `ENSMUSG00000073000.5:chr12:+:76494749:76494927:76496485:76497292` | Ppp1r36dn | 1e-4 | 0.019720 | 0.01899230 | 0.5350818 |
| `ENSMUSG00000021488.9:chr13:+:55361017:55361130:55361874:55361963` | Nsd1 | 5e-5 | 0.012325 | 0.04742467 | 0.3810515 |

Audit facts relevant to these targets (verified during this audit):

- The number of `p == 1` events equals the boundary count in each dataset
  (181, 1651, 993, 1107), consistent with the core rule `p = 1` when
  `T.obs <= tol_zero`.
- All mESC p-values are multiples of 1/20000 (B = 19999 with no failures).
- **All Kc167/K562/NIH-3T3 p-values are multiples of 1/5000 and 63–68 % are
  not multiples of 1/2000; minima are 0.007, 0.0002, 0.0008. The deposited
  pseudo-shutoff results therefore used B = 4999, whereas the frozen script
  sets `N_BOOT <- 1999`. [SF-1]** Observed-fit quantities (`sigma_c`, IR,
  boundary) do not depend on B; p/q values do.
- "Unique genes" counts biomaRt gene symbols fetched live at an unspecified
  Ensembl release; Ensembl-ID counts differ (1642, 1289, 1305).
- Reproducible from the tag alone: mESC and Kc167 inputs (normalized CSVs are
  in the tag). **Not** reproducible from the tag: K562/NIH-3T3 inputs (per-gene
  labelling-fraction files and ERCC tables absent) **[SF-11]**.

Synthetic benchmark reference: 1152 configurations, 1999 bootstrap replicates
per test, summary TSV in the tag (used for Section 8, not for tests).

---

## 11. Bioconductor plan

Compatibility is **not claimed** until `R CMD check --as-cran` and
`BiocCheck::BiocCheck()` have been run and pass.

| Item | Plan |
|---|---|
| `DESCRIPTION` | `Package: postexportKinetics`; `Version: 0.99.0` (Bioconductor pre-release convention); `Authors@R` from the manuscript author list (no ORCIDs unless provided); `License:` per [SF-14]; `biocViews:` e.g. `Transcriptomics, RNASeq, AlternativeSplicing, TimeCourse, Software, StatisticalMethod`; `Depends: R (>= 4.5.0)`; `Imports`/`Suggests` per Section 12; `VignetteBuilder: knitr`; `URL`/`BugReports` once the GitHub repository is known. |
| `NAMESPACE` | generated by roxygen2; explicit `importFrom()`; only the API in Section 5 exported. |
| roxygen2 | every exported function with `@param`, `@return` (full structure), runnable `@examples` (< 5 s each, small `B`), `@references` (manuscript, no DOI until published), interpretation note for `sigma_c`. |
| testthat (3e) | unit + regression tests (Section 9); fixtures in `tests/testthat/fixtures/`; tests run in < 2 min; no network. |
| Vignette | Section 15; built with `BiocStyle::html_document` (Suggests); small `B` for speed. |
| `inst/extdata` | two mESC events (FX-REAL-1) + one small synthetic example; README file documenting provenance. No full CSVs. |
| `inst/CITATION` / `CITATION.cff` | no invented DOI/ORCID/publication/acceptance data; the frozen Zenodo DOI 10.5281/zenodo.22944109 is cited as the archived *manuscript implementation* (supplied by the author), not as the package DOI. |
| `NEWS.md`, `README.md`, `LICENSE` | standard; README with installation from GitHub, minimal example, interpretation note. |
| Checks | iterative `R CMD build`, `R CMD check --as-cran`, `BiocCheck::BiocCheck()`; fix issues without suppressing legitimate checks; line width ≤ 80, 4-space indentation (Bioconductor style), function length guidance. |
| Examples | no network, no parallelism by default, `B` ≤ 99. |
| Data interoperability | Bioconductor reviewers typically expect reuse of core classes; propose `SummarizedExperiment` input support in Phase 3 via `Suggests` (open decision 16.B-6). |
| `RELEASE_CHECKLIST.md`, `tools/validate_against_manuscript.R` | as required by CLAUDE.md. |

---

## 12. Dependency audit

| Package | Frozen use | Classification | Justification |
|---|---|---|---|
| `nnls` | `nnls::nnls` (core fits) | **Imports** | Lawson–Hanson NNLS; must be identical to reproduce coefficients. |
| `MASS` | `MASS::mvrnorm` (bootstrap), `MASS::rnegbin` (RNA-seq noise) | **Imports** | RNG semantics of the bootstrap and assay model depend on these exact functions. Recommended package, ships with R. |
| `deSolve` | `deSolve::ode` (simulation) | **Imports** (alternative: Suggests if simulation becomes optional) | Needed by `simulate_postexport_kinetics()`; `lsoda` defaults are part of the simulation semantics. |
| `stats`, `utils`, `graphics`, `grDevices` | `cov`, `median`, `quantile`, `rnorm`, `runif`, `rgamma`, `rpois`, `p.adjust`, base plots | **Imports** (base) | — |
| `BiocParallel` | none (frozen used `parallel` PSOCK / `mclapply`) | **Suggests** | optional parallel batch execution; seeds are per event so results do not depend on it. |
| `expm` | `analyze_CN_vs_exact_transition.R` | **Suggests** | CN-vs-exact validation test only. |
| `testthat`, `knitr`, `rmarkdown`, `BiocStyle` | — | **Suggests** | tests / vignette. |
| `SummarizedExperiment` | — | **Suggests** (Phase 3, if approved) | Bioconductor input interoperability. |
| `data.table` | pervasive in scripts; hidden in `platforms.r` (`copy`, `as.data.table`) | **Removable** | Core inference is base R; assay functions can be ported to data.frame with identical arithmetic and RNG consumption (verified by FX-NOISE-1). If any difference appears, keep `data.table` rather than change behaviour. |
| `parallel` | PSOCK, `mclapply`, `detectCores` | **Removable** (replaced by optional `BiocParallel`) | orchestration only. |
| `ggplot2`, `patchwork`, `scales`, `grid`, `latex2exp`, `ggrepel` | figures | **Manuscript-only** | plotting uses base graphics. |
| `pROC`, `PRROC` | historical/figure scripts | **Manuscript-only** | final PR-AUC is custom code. |
| `openxlsx`, `tidyr`, `readr`, Python `openpyxl` | output tables, preprocessing | **Manuscript-only** | — |
| `biomaRt`, `AnnotationDbi`, `org.*.eg.db`, `clusterProfiler`, `ReactomePA`, `enrichplot` | annotation, GO | **Manuscript-only** | network access, not reproducible. |
| SRA Toolkit, cutadapt, STAR, samtools, rMATS, fastp, RSEM | raw-read preprocessing | **Manuscript-only** | external tools. |

---

## 13. Performance plan (no optimisation before equivalence is established)

- **Cost profile.** Each bootstrap replicate performs one `build_Ab_fullcov`
  (≈ K+2 eigen decompositions of 4×4 and one of 4(K-1)×4(K-1)), one more
  eigen decomposition for whitening, two NNLS fits, one SVD and two QR
  decompositions. Frozen benchmark median runtime ≈ 11 s per test at B = 1999
  (summary column `Median_test_seconds`).
- **Parallelism.** Parallelise over events (embarrassingly parallel) with
  optional `BiocParallel`; per-event seeds make results independent of worker
  count and scheduling (as in all frozen runners). Do not parallelise inside a
  bootstrap: that would change RNG consumption.
- **Reproducible parallel RNG.** Use explicit per-event `set.seed()` (frozen
  semantics), not `RNGseed`/L'Ecuyer streams, which would change the numbers.
  Record `RNGkind()` in results.
- **BLAS threads.** Frozen runs pinned BLAS/OMP threads to 1; document this
  for users running many workers (not enforced by the package).
- **Progress reporting.** `BiocParallel` progress bar or a simple
  `message()` counter at event granularity (off by default in examples).
- **Memory.** `keep_boot = FALSE` by default in batch mode (store only
  summary statistics); `TRUE` for single-event tests. Store per-event objects
  optionally.
- **Checkpointing** of long batches is left to the user (documented recipe),
  not built in.
- **Candidate later optimisations** (each requiring fixture equivalence):
  skipping redundant `make_spd` on already-SPD matrices, reusing the
  difference matrix `D`, vectorising `build_sigma_means`. Any change must keep
  `eigen()`/`mvrnorm` call sequences identical or be proven equivalent.

---

## 14. Bioinformatician user experience

### 14.1 Typical workflow

```r
library(postexportKinetics)

# 1. data -> validate (explicit units and mapping; nothing guessed)
x <- postexport_data(tab, format = "long",
                     event = "event", time = "time", replicate = "replicate",
                     compartment = c(nuclear = "nuc", cytoplasmic = "cyt"),
                     processing  = c(unprocessed = "inclusion", processed = "skipping"),
                     abundance = "count", time_unit = "min")
x                              # prints design + validation summary
check_operational_domain(x, t_star = 0)

# 2. deterministic fit for inspection (no bootstrap)
f <- fit_postexport_model(x[["event_1"]], t_star = 0)
summary(f)

# 3. bootstrap test for all events
res <- test_postexport_conversion(x, t_star = 0, B = 1999, seed = 20260924,
                                  BPPARAM = BiocParallel::SnowParam(4))
summary(res)                   # counts, boundary fraction, q-values (BH within call)

# 4. exploratory ranking and plots
top <- rank_postexport_candidates(res)
plot(res[["event_1"]], type = "trajectories")
```

### 14.2 Principles

- `t_star` is a **required** argument of the fit/test functions (use `NULL`
  explicitly for continuous transcription) — the intervention semantics are
  never hidden behind a default.
- Printed defaults: every result prints the control settings when they differ
  from the manuscript defaults, and `summary()` always lists them.
- Informative errors name the event, the column and the rule, e.g.
  "Event 'X': time 60 has no complete observation (all 3 rows contain NA in
  C_s); the test requires at least one complete sample per time point."
- Boundary results are explained in print: "T_obs = 0 (full fit places
  sigma_c on the boundary); p-value set to 1 by the boundary rule."
- Multiple testing: BH within the set of events tested together (as in the
  manuscript, within dataset); the documentation states that combining
  datasets changes q-values.
- Interpretation text appears in `print()`, `summary()`, help pages and the
  vignette, using "post-export conversion" language only.

---

## 15. Vignette plan

Title: *Testing for an additional post-export conversion component with
postexportKinetics.* Runtime target < 1 min (B ≤ 199).

1. **Model**: the four states (N, N_s, C, C_s), the ODE, parameter meanings;
   `sigma_c` as a phenomenological post-export conversion rate; explicit
   statement that `sigma_c` **does not identify a unique molecular
   mechanism** and is not by itself evidence of cytoplasmic splicing.
2. **Required design**: destructive sampling, replicates per time, time
   units, a common transcriptional-shutoff time `t_star` (pharmacological
   shutoff) vs pseudo-shutoff vs continuous transcription; what `t_star`
   truncates in the interval balance.
3. **Input formatting**: wide and long examples; compartment/processing
   mapping; rMATS RI inclusion/skipping mapping as an example; missing states.
4. **Simulated example**: `simulate_postexport_kinetics()` for one null and one
   alternative gene, `add_assay_noise()`.
5. **Fitting**: `fit_postexport_model()`, full vs `sigma_c = 0` null, RSS,
   relative RSS improvement (IR), coefficients.
6. **Bootstrap comparison**: generative bootstrap under the null,
   reconstruction of A*, b*, Σ_b*, add-one p-value; why this is not a
   likelihood-ratio test.
7. **Diagnostics**: conditioning (and why it is Inf when `t_star` precedes the
   first sample), bootstrap failure rate, covariance floors.
8. **Boundary behaviour**: `T_obs = 0`, `p = 1`, the atom at zero.
9. **Real-data example**: the two mESC events in `inst/extdata` (fit only, and
   a small-B test), with the manuscript values for comparison.
10. **Many events and multiple testing**: BH within dataset; operational-domain
    report; why calibration is design dependent (benchmark summary).
11. **Exploratory ranking**: composite score, explicitly not inferential.
12. **Limitations**: model assumptions (complete shutoff at `t_star`, no
    nuclear decay term, constant rates, destructive sampling), pseudo-shutoff
    approximations, design dependence of calibration, interpretation limits.
13. Session info.

---

## 16. Risks and open questions

### 16.A Software-engineering decisions

1. **Frozen code in tests.** Commit fixtures generated from the frozen code
   (proposed), plus optional live comparison via `POSTEXPORT_FROZEN_DIR`.
   Confirm that installing `nnls`, `deSolve`, `expm`, `testthat`, `BiocCheck`
   locally is acceptable.
2. **Script-embedded functions** (`simulate_one_gene`, seed functions, noise
   wrappers) are extracted by parsing the frozen files and evaluating only the
   function definitions. Confirm this is acceptable as "executing frozen code".
3. **Globals, paths, platform assumptions** found in every script
   (`setwd("~/postexport-kinetics/...")`, `detectCores() - 80`, 100 PSOCK
   workers, `mclapply` forking, BLAS env vars, hidden `data.table` use in
   `platforms.r`, `KINETIC_VARS`/`PARAM_NAMES` as globals) — all removed in the
   package; none affects numerics.
4. **Duplicate implementations** to be single-sourced: noise wrappers (7
   copies), `stable_seed_from_string` (6 copies), `wilson_interval`,
   `safe_*` helpers, three plotting ODE right-hand sides.
5. **Mixed plotting/computation** in historical figure scripts and in some
   FINAL runners (ggplot in benchmark runners) — not ported.
6. **Removing `data.table`** from the assay functions: proceed only if
   FX-NOISE-1 is bitwise identical.
7. **License.** Frozen repo: MIT (`LICENSE`), but 21 frozen scripts carry an
   "academic and research purposes" permission header; this repository
   currently contains GPL-3. Bioconductor requires an OSI-approved license.
   **Decision required [SF-14]** (license of the package and of code derived
   from the frozen scripts).
8. **Version numbering** (`0.99.0` for Bioconductor) and repository hosting
   (GitHub organisation) — to confirm.

### 16.B API decisions

1. Function names (Section 5.1) — alternatives: `pek_*` prefix;
   `test_sigma_c()`; single `postexport_test()` for fit + test.
2. `t_star` as a required argument (proposed) vs default `NULL`.
3. Global RNG side effect: keep frozen behaviour (global `set.seed`) and
   **restore the caller's RNG state on exit** (proposed; numbers unchanged) or
   leave the global state modified as in the frozen code.
4. Default per-event seed scheme for batch tests (`"hash"` proposed) and
   whether `seed` is mandatory (proposed: mandatory for `B > 0`).
5. Whether to expose `build_interval_balance()` publicly (proposed yes, as an
   advanced/transparency function).
6. `SummarizedExperiment` input support (Phase 3) — yes/no.
7. `simulate_postexport_kinetics()` returns only the sampled intervention (or
   baseline) data (proposed) vs both regimes as in `generate_ODE_states`.
8. Whether the IR returned in batch results follows the core (NA if
   RSS0 ≤ 0) — proposed yes [SF-9].
9. Whether `lambda_var` (legacy alias) is exposed — proposed no [SF-15].
10. Whether optional helpers (`filter_postexport_events()`,
    `rmats_to_postexport()`, `perturb_fraction_separation()`,
    `sample_kinetic_parameters()`) belong to the first release.

### 16.C Scientific decisions (stop-condition findings — not resolved autonomously)

Each item lists source, current behaviour, why it may matter, impact, and
options. **No change is proposed to frozen behaviour without approval.**

- **[SF-1] Bootstrap size of the pseudo-shutoff real-data results.**
  *Source:* `real_datasets/run_real_datasets_revision.R:146` (`N_BOOT <- 1999`)
  vs `real_datasets/S5testresults_final.xlsx` and
  `final_real_data_audit/*.tsv`. *Behaviour:* the frozen script, run as
  written, uses B = 1999; the deposited Kc167/K562/NIH-3T3 p-values lie on the
  1/5000 lattice (B = 4999). *Impact:* the frozen script does not reproduce the
  deposited pseudo-shutoff p/q values; counts in the README table (16 / 121 / 79
  at p < .05) may change at B = 1999. `sigma_c`, IR and boundary counts are
  unaffected. *Options:* (a) confirm B = 4999 was used and record it as a
  documented deviation of the tag; (b) the package validation tool uses
  B = 4999 for these datasets; (c) re-run is out of scope for the package.
- **[SF-2] RNG state "restore" in the corrected generator is a no-op.**
  *Source:* `synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R:416-429`
  (`.Random.seed <- rng_state_after_parameters` inside `simulate_one_gene`).
  *Behaviour:* assigning `.Random.seed` inside a function creates a local
  variable; confirmed with a base-R test during this audit. Replicate-level
  lognormal perturbations are therefore drawn from the `2000000 + gene_id`
  stream after the onset `sample()`, not from the `1000000 + gene_id` stream as
  the comment states. *Impact:* none on validity (deterministic, independent
  streams per gene), but documentation is wrong and a "fixed" reimplementation
  would not reproduce the benchmark. *Proposal:* the package reproduces the
  actual behaviour; document it; do not fix.
- **[SF-3] Missing mESC noise-matching analysis.** *Source:*
  `synthetic_dataset/analyze_GSE256335_effect_size_power.R:12-13`
  (keeps Medium/High "identified by the mESC noise-matching analysis"). No
  such analysis exists in the tag; the matched benchmark matches design only,
  not noise. The matched benchmark's raw/summary outputs are also not in the
  tag. *Impact:* the operational-domain report cannot include mESC-matched
  calibration unless the author supplies the source/outputs. *Question:* where
  is this analysis, and should it be cited or excluded?
- **[SF-4] Authority of `run_benchmark_pseudoshutoff_revision.R`.** Listed as
  final (README:41) but loads the legacy `ode_states_2k_20p.rdata` (`:118`),
  cannot be reproduced from the tag, and has a colliding seed formula
  (`:383-404`). `run_pseudoshutoff_misspecification_benchmark.R` feeds the
  Supplementary figures. *Question:* confirm that manuscript pseudo-shutoff
  results come from the latter and that the former is superseded.
- **[SF-5] Two ΔPSI comparators** (`commons/psi_test.r:63-180` vs
  `synthetic_dataset/analyze_three_way_AUPR.R:487-666`), differing in windows,
  aggregation, stabilisation and degenerate handling; both pair replicates by
  label across time (contrary to destructive-sampling semantics). *Proposal:*
  do not package a ΔPSI comparator in the first release; if later needed,
  package the `analyze_three_way_AUPR.R` version as manuscript comparator.
  *Question:* which one underlies the manuscript's three-way comparison text?
- **[SF-6] Two PR-AUC implementations** (`analyze_three_way_AUPR.R:1018-1029`
  reorders points by recall/precision; ablation/regenerate scripts do not).
  They diverge under ties, which are frequent for discrete bootstrap p-values.
  *Impact:* three-way AUPR values are not computed by the same rule as FigS17
  and the ablation. Not packaged; flagged for the manuscript.
- **[SF-7] Cytoplasmic-only comparator properties**
  (`run_cytoplasmic_only_baseline.R:735-1531`): absolute variance floor
  `max(0.1·q10, 1e-8)` (not scale-equivariant; may make RT-qPCR fits
  effectively unweighted), residual bootstrap without `n/(n-1)` inflation, no
  boundary tolerance, different failure rule, `B = 499`, unused `expm`
  dependency. These are comparator-design properties. *Proposal:* do not
  package in the first release. *Question:* is a comparator needed in the
  package at all?
- **[SF-8] QC divergence between real-data scripts.** `run_mESC_20k.R:344-482`
  re-implements `filter_event` without the within-time replication rule and
  with `all(d$N == 0)` lacking `na.rm` (no effect on mESC data). *Question:*
  which is canonical for an optional QC helper (proposed:
  `run_real_datasets_revision.R:485-657`)?
- **[SF-9] Composite score definition.** Synthetic scripts:
  `pmax(sigma, 0) × IR × min(-log10(max(q, 1e-10 or 1e-300)), 6)` with IR = 0
  when RSS0 ≤ 0; real-data script: `Sigma × IR × min(-log10(max(q, 1e-10)), 6)`
  with IR = NA when RSS0 ≤ 0 (`run_real_datasets_revision.R:1455-1466,
  1570-1627`); a further mESC "validation_score" with rank-based weights
  (`run_mESC_20k.R`, ≈ L2094-2177). The floors are equivalent because of the
  cap; `sigma_c ≥ 0` by NNLS. *Proposal:* canonical
  `score_sigma_IR_q = sigma_c × IR × min(-log10(max(q, 1e-10)), 6)`,
  IR per core (NA if RSS0 ≤ 0 → score NA, ranked last); the mESC
  validation score is not packaged. *Question:* confirm.
- **[SF-10] Diagnostics for shutoff designs with `t_star <= first sample`.**
  R column structurally zero → `condition.number = Inf`, `rank.full = 6`,
  `bootstrap.rank.deficient.fraction = 1` for every real-data event
  (`Median_condition = Inf` in `real_dataset_discovery_summary.tsv`).
  Inference unaffected. *Proposal:* keep frozen diagnostics unchanged and
  **add** `structurally_zero_columns` plus a condition number computed on the
  remaining columns, and eigenvalue-floor counts from `make_spd`. These are new
  diagnostics — approval required.
- **[SF-11] Real-data preprocessing not reproducible from the tag.** K562 and
  NIH-3T3 labelling-fraction and ERCC inputs are absent; `*.sh` heredocs are
  not runnable as written (`read_tsv` without `readr`; headerless file read
  as `nor$counts`); GSE207924 output filenames differ from what
  `gen_RMATS_table.r` reads; missing states are zero-filled by `dcast(fill = 0)`;
  gene symbols come from live biomaRt. *Proposal:* the package does not
  reproduce preprocessing; an optional `rmats_to_postexport()` would make the
  zero-fill explicit (`missing_state = "zero"`).
- **[SF-12] Design labels vs effective designs** (nominal vs effective number
  of time points; NONE cells independent of `T_step`). Affects interpretation
  of benchmark tables and the domain report. *Proposal:* store both nominal
  and effective values; report effective values.
- **[SF-13] Assay-model properties to document, not change:** RT-qPCR output
  `2^-Ct` is not rescaled by `scale_copies` (absolute scale ≈ copies × 2⁻³⁵;
  rate estimates are scale-invariant but `R` and RSS are not comparable across
  platforms); the RT-qPCR limit of detection (`Ct > 40`) is practically never
  reached; RNA-seq uses one dispersion per state per call; Gaussian noise can
  produce negative values; `rnegbin` is evaluated for all elements (RNG).
- **[SF-14] License** (see 16.A-7).
- **[SF-15] `lambda_var` alias** overrides `lambda_time` although the target
  of shrinkage differs from the historical meaning. *Proposal:* not exposed.
- **[SF-16] Boundary definitions.** Core: `T.obs <= 1e-10·max(1,|RSS0|,|RSS1|)`
  (drives `p = 1`); audit/benchmarks: `|sigma_c| < 1e-12` or `<= 1e-12`. They
  coincide in the real data. *Proposal:* report both with distinct names;
  only the core rule affects p.
- **[SF-17] Replicate-level perturbation can violate `alpha_s ≤ alpha`**
  (independent lognormal multipliers, `ode.r:1060-1090`), a property of the
  simulation prior. *Proposal:* document only.
- **[SF-18] Operational-domain wording** (Section 8.3) must be approved so
  that no calibration guarantee is implied.
- **[SF-19] Level for negative abundances** in user data (WARNING proposed;
  frozen code accepts them).

### 16.D Proposed implementation phases (after approval)

1. Environment + frozen fixture generator + fixtures (no package code yet
   beyond `tools/`). Report fixture values for review.
2. Package skeleton; verbatim internal ports of core inference; regression
   tests to T0–T2; `fit_postexport_model()`, `test_postexport_conversion()`
   (single event); result class with print/summary.
3. Input/validation layer; batch testing, BH, seeds, optional BiocParallel;
   ranking; domain report.
4. Simulation (ODE, onset, intervention, assay presets) with FX-ODE/GEN/NOISE.
5. Plotting, vignette, README, NEWS, CITATION.cff, RELEASE_CHECKLIST.md,
   `tools/validate_against_manuscript.R`; `R CMD check --as-cran`, BiocCheck.

Each phase ends with a summary of files/functions affected, regression tests
and whether any output changed, before committing.
