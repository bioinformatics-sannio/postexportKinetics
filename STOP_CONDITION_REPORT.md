# Stop-Condition Resolution Report

Status: **FOR REVIEW. No package implementation code has been written.**
This report accompanies `PACKAGE_PLAN.md` and resolves the review items raised
on it. Where the two disagree, this report supersedes `PACKAGE_PLAN.md` (see
Sections 6–8 for plan amendments).

- Frozen reference: tag `manuscript-revision-v1.0` → commit
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`.
- All evidence was taken from a `git archive` export of the tag, plus
  read-only `git log`/`git branch` queries. `../postexport-kinetics` was not
  modified. Its HEAD (`687ec24`) and working-tree state (pre-existing
  `M README.md`) are unchanged from the start of the audit.
- The frozen R code was **not executed**, because `nnls` and `deSolve` are not
  installed. The computations below read deposited files only, using Python
  standard-library XML parsing and base R.
- "**Proof**" means the conclusion follows from the frozen code plus the
  deposited values, with no statistical assumption. "**Inference**" means it
  relies on a probabilistic or plausibility argument, which is stated.

---

## 1. SF-1: bootstrap count used for the pseudo-shutoff real-data results

### 1.1 Provenance chain of the deposited p-values

1. `test_sigma_nested()` returns `p.value` (`commons/nested_test2.r:1963-1985`, add-one formula).
2. `run_real_event()` copies it unchanged into the results row: `p.value = get_field(WWW, "p.value")` (`real_datasets/run_real_datasets_revision.R:998-1001`).
3. The audit standardizes it: `p_final := as.numeric(get(p_col))` with `p_col` = `"p.value"` (`real_datasets/audit_final_real_data.R:294-300, 398-408`).
4. The audit writes `final_all_realdata_standardized.tsv`. This file is **not in the tag**.
5. `make_S5testresults_final.py` writes the values to `S5testresults_final.xlsx`. It applies only a *display* format, `number_format = "0.000000"` (lines 176-178); the stored cell value keeps full precision. The workbook's README sheet names `final_all_realdata_standardized.tsv` as its source.

The analysis therefore uses the `p_final` column of the per-dataset sheets in
`real_datasets/S5testresults_final.xlsx`. It is the only event-level copy of
the final p-values in the tag.

### 1.2 What values the frozen code can produce

For `status == "ok"` (`nested_test2.r:1963-1985`), the p-value is one of two things:

- exactly `1`, when `T.obs <= tol_zero` (boundary rule); or
- `(1 + k) / (n + 1)` with `k ∈ {0, …, n}`, where `n = n.bootstrap.valid ≤ B_n`.

Failed replicates are dropped. If more than 5% fail, p is NA (`nested_test2.r:1850-1934`).

Hence, with `B_n = 1999` as written at `run_real_datasets_revision.R:146`,
every non-boundary p-value is a fraction whose denominator divides some
`d = n + 1 ≤ 2000`. Its reduced (lowest-terms) denominator must therefore be ≤ 2000.

### 1.3 Observed values: exact rational analysis

Each stored decimal string was converted to its nearest rational (bounded
denominator, 2×10⁵). All values lie within 4.6×10⁻¹³ of a multiple of 1/5000,
i.e. at floating-point representation error.

| Dataset | Events | p = 1 (boundary) | Reduced denominator = 5000 | Not a multiple of 1/2000 | p < 1/2000 | LCM of all reduced denominators | Min p |
|---|---:|---:|---:|---:|---:|---:|---:|
| Kc167 | 337 | 181 | 64 | 124 | 0 | **5000** | 0.007 |
| K562 | 2696 | 1651 | 427 | 860 | 2 | **5000** | 0.0002 |
| NIH-3T3 | 1746 | 993 | 301 | 612 | 0 | **5000** | 0.0008 |
| *mESC (control)* | 1972 | 1107 | — | — | 16 | **20000** | 5e-05 |

Full reduced-denominator distributions were recorded. For K562:
{1: 1651, 4: 1, 8: 2, 10: 1, 20: 1, 25: 3, 40: 2, 50: 5, 100: 15, 125: 19, 200: 15, 250: 18, 500: 27, 625: 119, 1000: 76, 1250: 95, 2500: 219, 5000: 427}.
Every denominator divides 5000.

### 1.4 Conclusions

**Proof: B_n = 1999 did not produce the deposited Kc167, K562 and NIH-3T3 p-values.**

- Kc167 has 64 events, K562 427 and NIH-3T3 301 whose p-value has reduced denominator exactly 5000.
- Such a value can equal `(1 + k)/(n + 1)` only if 5000 divides `n + 1`, i.e. `n + 1 ≥ 5000`, which is impossible for `n ≤ 1999`.
- This holds regardless of bootstrap failures, because failures only *decrease* `n`.
- For K562 there is an additional, independent proof: two p-values (0.0002, 0.0004) are below the smallest attainable value, 1/2000.
- The proof assumes only that `p_final` is the unmodified `p.value` (Section 1.1) and that the stored doubles represent their rationals to within 10⁻¹².

**Proof: the historical implementation (`commons/nested_test.r`, used with `B_n = 5000` in `real_datasets/run_nested_test.r:209`) did not produce them either.**

- Its p-value is `(1 + gt + U·eq)/(n + 1)` with `U ~ Uniform(0,1)` (`nested_test.r:354-357`). With B = 5000 the denominator is 5001, and the tie-breaking is random.
- Exact multiples of 1/5000 (e.g. 1/5000 ≠ 1/5001) and exact values `p = 1` are therefore not produced systematically.
- `nested_test.r` has no boundary rule. The 181 / 1651 / 993 exact `p = 1` values, which equal the boundary counts in `final_boundary_summary.tsv`, identify the `nested_test2.r` boundary rule.

**Proof: all non-boundary p-values are compatible with a single common denominator `n + 1 = 5000`, i.e. `n.bootstrap.valid = 4999` for every event.**

- The LCM of all reduced denominators in each dataset is exactly 5000.
- Any common denominator must be a multiple of 5000.

**Inference, strong: B_n = 4999 with no bootstrap failures.**

- *Alternative:* `n + 1 = 10000 m` would require every non-boundary numerator over 10000 to be even. That is 156 (Kc167), 1045 (K562) and 753 (NIH-3T3) independent parity coincidences, with probability of order 2^-156 or smaller under any non-degenerate distribution of k.
- *Alternative:* per-event denominators that are distinct multiples of 5000 are equally implausible.
- *Alternative:* `B_n > 4999` with exactly `B_n − 4999` failures in every one of 4779 events would require identical failure counts across events.
- *Independent corroboration:* `real_dataset_discovery_summary.tsv` reports `Median_atom_zero` = 0.585917183436687 (Kc167), 0.57751550310062 (K562) and 0.578015603120624 (3T3). `atom.zero` is a count divided by `n.bootstrap.valid`. For each value, the smallest n ≤ 40000 that makes `2·median·n` an integer is **4999**, with only its multiples otherwise.

**Proof (from the same summary file, row "mESC | GSE256335"): the revision run of mESC also used n = 4999.**

- `Min_p` is 2e-4 = 1/5000, and `Median_atom_zero × 4999` is an exact half-integer.
- The *final* mESC results come from the separate `run_mESC_20k.R` run (`N_BOOT <- 19999L`, `:131`). They lie on the 1/20000 lattice, consistent with that script as written.

### 1.5 Trace of files that could record the actual B

| Candidate evidence | In tag? | Finding |
|---|---|---|
| `N_boot` column written per event (`run_real_datasets_revision.R:721, 863, 1346`) | No: it lives in `results_realdatasets_revision.rdata` / `.tsv`, which are not in the tag | would record the value used |
| `real_dataset_sessionInfo.txt` (`run_real_datasets_revision.R:~2023`) | No | — |
| `final_all_realdata_standardized.tsv` | No | — |
| `S5testresults_final.xlsx` README/Summary sheets | Yes | no mention of B |
| `real_dataset_discovery_summary.tsv` | Yes | indirect evidence (Min_p, Median_atom_zero) → 4999 |
| Any `4999` literal in the tag | Yes (searched all `.R/.r/.py/.tsv/.txt/.md/.sh`) | none |
| Git history of `run_real_datasets_revision.R` | only commit `29320a9` (file introduced with `N_BOOT <- 1999`) | no other version on any ref |
| Other refs | `main`, `origin/main`, tag only; no stash | — |

The value actually used is therefore **not recorded anywhere in the tag**.
The likeliest explanation is that the run was made with `N_BOOT <- 4999`
before the file was frozen with `1999`. That is an explanation, not evidence.
The author should confirm it.

### 1.6 Impact

**What B does not affect (proof).** B does not affect `sigma_c`, IR, T.obs,
RSS0/RSS1, the coefficients, the boundary status, or the number of tested
events. In the frozen code, `set.seed()` precedes the observed fit, but the
observed fit consumes no random numbers, and QC is deterministic. So the
Tested / Unique genes / Boundary columns and every `sigma_c`/IR value in S5
are unaffected.

**What B does affect.** B affects p, q, and therefore the "p < .05", "q < .10"
and "q < .05" columns for Kc167, K562 and NIH-3T3. It also affects exact
reproducibility of the deposited p/q values from the frozen script as written.

**Inference: size of the effect.** This uses a plug-in Monte Carlo that treats
each deposited p as the event's true bootstrap tail probability. That
approximation is reasonable, because the deposited p already has Monte Carlo
error at B = 4999. The simulation draws p₁₉₉₉ = (1 + Bin(1999, p))/2000 and
keeps boundary events at 1 (they are deterministic). It uses 5000 simulated
re-analyses and BH within each dataset.

| Dataset | p < .05 deposited | p < .05 at B = 1999, median [95% range] | P(any q < .10) | P(any q < .05) | Deposited min q |
|---|---:|---:|---:|---:|---:|
| Kc167 | 16 | 17 [15–19] | < 2×10⁻⁴ (0/5000) | < 2×10⁻⁴ | 0.708 |
| K562 | 121 | 119 [114–124] | < 2×10⁻⁴ (0/5000) | < 2×10⁻⁴ | 0.539 |
| NIH-3T3 | 79 | 79 [75–83] | < 2×10⁻⁴ (0/5000) | < 2×10⁻⁴ | 0.524 |

- **Counts:** at B = 1999 the nominal "p < .05" counts would be expected to differ by a few events (about ±2–5).
- **FDR results:** the conclusion that the three pseudo-shutoff datasets have **no FDR-supported events at q < .10 or q < .05** is not plausibly affected. My independent BH recomputation from the deposited p-values reproduces the deposited minimum q exactly (0.708 / 0.539 / 0.524).
- **mESC:** unaffected (separate run, as written).
- **Manuscript text:** I cannot see the manuscript text. Any statement there of the form "1,999 bootstrap replicates" applied to the real pseudo-shutoff datasets would be inaccurate.

**Classification: C (provenance/documentation).** It does not block core
package implementation: the package's default `B = 1999` is the core function
default and the benchmark value, and `B` is a user argument.

### 1.7 Recommended handling (no frozen change)

1. The author confirms B = 4999 for the revision real-data run. The confirmation is recorded in `RELEASE_CHECKLIST.md` and in package documentation as a known deviation of the tag, with a pointer to this analysis.
2. `tools/validate_against_manuscript.R` uses B = 4999 and the `real_revision` seed scheme whenever it validates Kc167 p-values (the only pseudo-shutoff dataset reproducible from the tag, Section 5 / SF-11). It reports `sigma_c`/IR as exact targets and p-values as T4 (Monte Carlo) comparisons.
3. The package plan defines no manuscript target that depends on B = 1999 for these datasets.

---

## 2. SF-4: provenance of the pseudo-shutoff benchmark

### 2.1 Roles

| Script | Role | Input | Output | Evidence |
|---|---|---|---|---|
| `synthetic_dataset/run_benchmark_pseudoshutoff_revision.R` | earlier, broad residual-transcription benchmark (12 designs × every rho in the data) | `load("ode_states_2k_20p.rdata")` (`:118`; header `:53`) | `benchmark_pseudoshutoff_revision_{raw,summary}.{rdata,tsv}`, `benchmark_pseudoshutoff_batch_*`, `benchmark_pseudoshutoff_sessionInfo.txt` in the working directory (`:61-64, 1294-1332`) | version string "Major-revision misspecification benchmark, 2026"; integer seed formula `:383-404`; no `BENCHMARK_VERSION` |
| `synthetic_dataset/run_pseudoshutoff_misspecification_benchmark.R` | targeted corrected-onset pseudo-shutoff benchmark (2 designs: 5 tp × {3, 10} replicates, T_step 10; 3 platforms × 4 noise levels; 8 rho levels; 500 null + 250 alt genes) | `ode_states_2k_20p_corrected_onset.rdata` (`:95`; header `:40`) | `pseudoshutoff_benchmark/pseudoshutoff_summary.tsv` and others (`:97-121, 2927-2934`) | `BENCHMARK_VERSION = "pseudoshutoff_corrected_onset_v1"` (`:239`); corrected-onset preflight checks (`:292-456`) |
| `synthetic_dataset/make_FigS_pseudoshutoff_minimal.R` | draws the Supplementary figures (Type I vs residual transcription; mean `sigma_c` under H0) | `INPUT_FILE <- "pseudoshutoff_benchmark/pseudoshutoff_summary.tsv"` (`:42-43`) | `pseudoshutoff_benchmark/FigS_pseudoshutoff_{typeI,sigma_null}.{pdf,png}` | requires columns `Design, Platform, Exprs_noise, Residual_transcription_pct, TypeI_005, Null_sigma_hat_mean` (`:111-118`) and stops otherwise (`:120-135`) |

### 2.2 Which runner produced the figure data

**Proof (from code, since the output files are not in the tag):** the figure
data can only come from `run_pseudoshutoff_misspecification_benchmark.R`.

- The figure script reads `pseudoshutoff_benchmark/pseudoshutoff_summary.tsv`.
  Only the misspecification runner writes that path (`:97, 114-116`).
- The older runner writes `benchmark_pseudoshutoff_revision_summary.tsv` in a
  different directory.
- The older runner's summary has **no** `Design` column (no occurrence in the
  file) and no `Null_sigma_hat_mean` (it computes `Median_sigma_null`,
  `:1209`). The figure script's column check would stop on its output.
- No script in the tag reads any output of the older runner. A search for
  `benchmark_pseudoshutoff_(revision|batch)` finds only the runner itself.

**Proof: the older runner cannot be run against the corrected-onset data as written.**

- It loads `ode_states_2k_20p.rdata`, which only the legacy generator
  `gen_synthetic_ODE_states.r:293` writes. That data has no `PSEUDO_SHUTOFF`
  rows and no `Post_R_fraction` column.
- The corrected generator writes `ode_states_2k_20p_corrected_onset.rdata`
  (`gen_…_corrected_onset.R:1301`).

**Inference:** it was run on an intermediate dataset (a corrected or
pre-corrected generator output saved under the legacy name) that is not in the
tag. Its results cannot be reproduced from the tag.

**Documentation issue:** README lines 40–45 list both runners under
"Pseudo-shutoff and model misspecification" without distinguishing them.

Neither runner's outputs are in the tag (`synthetic_dataset/pseudoshutoff_benchmark/`
does not exist in the export), so the figure's numbers cannot be checked here.

### 2.3 Authority for package purposes

- **Authoritative:** `run_pseudoshutoff_misspecification_benchmark.R`, with
  `make_FigS_pseudoshutoff_minimal.R` as its figure consumer.
- **Superseded / non-authoritative:** `run_benchmark_pseudoshutoff_revision.R`.
  It is not used as a regression source and not used for domain information.

The package reuses no code from either runner:

- Residual transcription comes from `ode.r` (`post_R_fraction`).
- The misspecified fit is the unmodified core, with `t_star` treated as a
  complete shutoff.
- Noise presets come from `platforms.r` and the shared preset table.

The pseudo-shutoff summary is not in the tag. `check_operational_domain()`
therefore reports pseudo-shutoff sensitivity only as a qualitative caveat
("fitted as complete shutoff; see the manuscript's pseudo-shutoff sensitivity
analysis"), unless the author supplies `pseudoshutoff_summary.tsv`.

**Classification: C.** The author is asked to confirm the README wording and
the superseded status.

---

## 3. SF-5 / SF-6 / SF-7: comparators and PR-AUC

### 3.1 Isolation from core inference (confirmed)

- **Core files contain no comparator or evaluation code.** Searching
  `commons/nested_test2.r`, `ode_model/ode.r` and `commons/platforms.r` for
  `psi`, `pr_auc`, `auc`, `cyto`, `PRROC` and `pROC` finds nothing.
- **Call sites.** Calls (as opposed to definitions) of the comparator and
  metric functions occur only in these files:

  | Function | Called in |
  |---|---|
  | `baseline_psi_logit_ttest_pre_vs_post` | only `run_tests.r:326` (historical) |
  | `compute_delta_psi_test` | only `analyze_three_way_AUPR.R:777` |
  | `build_cyto_design`, `fit_cyto_model`, `bootstrap_cyto_test` | only `run_cytoplasmic_only_baseline.R` |
  | `pr_auc` | only `analyze_composite_score_ablation.R`, `regenerate_corrected_discrimination_figures.R`, `analyze_three_way_AUPR.R` |
  | `auc_rank` | only `regenerate_corrected_discrimination_figures.R` |

- **The data flow is one-way.** The main benchmark's raw table (p-values and
  measurement seeds) is read by the comparator and evaluation scripts. Their
  outputs are written only to `cytoplasmic_only_baseline/` and `score_ablation/`,
  and are read only by their own figure scripts
  (`make_FigS_full_vs_cytoplasmic_only_typeI.R`, `analyze_three_way_AUPR.R`).
  None is read by the core, the main benchmark, the real-data scripts or the audit.
- **`psi_test.r` is dead code in the final runner.** It is sourced by
  `run_benchmark_main_corrected_onset_revision.R:153` but never called, so it
  cannot affect benchmark results.
- **The composite score does not depend on PR-AUC.** The score formula
  (`analyze_composite_score_ablation.R:187-218`;
  `regenerate_corrected_discrimination_figures.R:141-157`;
  `run_real_datasets_revision.R:1495-1627`) uses only p/q, `sigma_c` and IR.
  PR-AUC only *evaluates* scores. So `rank_postexport_candidates()` inherits
  nothing from either PR-AUC implementation.

**Conclusion.** The discrepancies are confined to manuscript comparator and
evaluation utilities:

- SF-5: two ΔPSI definitions.
- SF-6: two PR-AUC rules that differ under ties.
- SF-7: the cytoplasmic-only comparator's absolute variance floor, residual
  bootstrap without inflation, and missing boundary rule.

They do not affect the postexport inference, the real-data results, or the
main-benchmark calibration used in Section 8. They may affect specific
manuscript comparator figures and statements (three-way AUPR, ΔPSI baseline).
Those remain manuscript questions for the author.

### 3.2 Decision for v0.1.0

**Excluded from v0.1.0:**

- ΔPSI baselines (both versions);
- the cytoplasmic-only model, fit and bootstrap;
- all PR-AUC / AUROC / precision@K implementations;
- Wilson-interval and benchmark-summary helpers, except internal use in
  building the domain table, if needed.

No evidence was found that would require including them.

**Classification:**

- SF-5, SF-6: **C**.
- SF-7: **B**. It blocks only a possible future comparator feature, which is
  out of scope for v0.1.

---

## 4. SF-2: RNG state "restore" in the corrected-onset generator

### 4.1 The issue

`synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R`, inside
`simulate_one_gene()`:

```r
set.seed(1000000L + as.integer(gene_id))           # :321-324  parameter stream
r_param <- random_params(); ...                     # :331-392  params, truth, R, alpha_s
rng_state_after_parameters <- .Random.seed          # :416
set.seed(2000000L + as.integer(gene_id))            # :418-421  onset stream
onset_shift_gene <- sample(-max:max, 1L)            # :423-427
.Random.seed <- rng_state_after_parameters          # :429  <-- creates a LOCAL variable
```

- R's generator reads and writes `.Random.seed` only in the global environment.
  The assignment at `:429` creates a function-local copy and leaves the global
  RNG state untouched.
- I confirmed this during the audit with a base-R script that mirrors the
  pattern. The draw after the "restore" is identical to the no-restore case and
  differs from a true global restore.
- **Consequence:** every later draw in that gene comes from the continuation of
  the `2000000 + gene_id` stream after the onset `sample()`, not from the
  `1000000 + gene_id` stream the comment claims. These are the per-replicate
  lognormal parameter multipliers in `generate_ODE_states()` (`ode.r:1060-1090`),
  over 48 designs × 9 calls.
- The kinetic parameters, class labels, R and alpha_s are all drawn *before*
  `:416`. They are exactly as intended.

### 4.2 Effects

| Question | Answer | Status |
|---|---|---|
| Does it change the frozen manuscript results? | No. The frozen results *are* the output of this code as it executed. There is no "other" result that the manuscript reports. | proof |
| Does it compromise the statistical validity of the benchmark? | No evidence of that. Replicate multipliers are still pseudo-random draws from a seeded Mersenne-Twister stream, distinct for every gene (seeds 2,000,001–2,002,000, disjoint from the parameter seeds 1,000,001–1,002,000). The onset value and the multipliers come from the same stream, which introduces no dependence of statistical concern. Only the *documented* stream assignment is wrong. | inference (standard property of seeded MT streams) |
| Does it affect reproducibility of the frozen results? | No. The behaviour is deterministic: rerunning the frozen generator with the same R RNG defaults and `deSolve` reproduces the same data. It would break reproducibility only if someone "fixed" the line and regenerated. | proof (determinism of the code) |
| Does it affect the package? | Only in design. (a) The generic `simulate_postexport_kinetics()` takes a single user `seed` and calls `generate_ODE_states()` semantics directly, so it neither contains nor needs this pattern. (b) A benchmark-gene reproduction helper, used only in `tools/` and the regression fixtures (FX-GEN-1), must mimic the *actual* stream usage: parameter stream, then onset stream continued for the replicate draws. Reproducing the comment's intent would silently change benchmark data. | design only |

### 4.3 Recommendation

- Do **not** change frozen behaviour.
- Reproduce the actual behaviour in the fixture generator and in any benchmark
  reproduction helper.
- Document the stream usage in the helper's roxygen notes and in
  `RELEASE_CHECKLIST.md`.
- Do not expose the benchmark-gene generator in the v0.1 public API.
- Optionally, the author may add an erratum-style note to the manuscript
  repository README in a future release. That is outside this package's scope.

**Classification: D.** It is a safe API/design decision with no change to
frozen numerics, and it does not block core implementation.

---

## 5. Classification of SF-3, SF-8, SF-10, SF-11, SF-12, SF-15

| Item | Class |
|---|---|
| SF-3 Missing mESC noise-matching analysis | **C** |
| SF-8 QC divergence between real-data scripts | **B** |
| SF-10 Diagnostics when `t_star ≤` first sample | **D** |
| SF-11 Real-data preprocessing not reproducible from the tag | **B** |
| SF-12 Nominal vs effective benchmark designs | **C** |
| SF-15 `lambda_var` alias | **D** |

**SF-3: C (provenance/documentation).**
`analyze_GSE256335_effect_size_power.R:12-13` restricts its effect-size
analysis to the "Medium"/"High" noise regimes, "identified by the mESC
noise-matching analysis". No such analysis exists in the tag, and the
mESC-matched benchmark matches the design (0/30/60/120/240 min, 3 replicates,
complete shutoff, `t_star = 0`) but not the noise level. The matched benchmark
itself and the core test are unaffected. The only package consequence is that
v0.1's operational-domain table is built from the main factorial benchmark
summary, the only benchmark summary in the tag. It will not present
mESC-matched calibration or power numbers unless the author supplies the
missing analysis and outputs. This does not block core implementation or any
v0.1 feature, so it is a provenance question for the author.

**SF-8: B (blocks an optional feature only).**
`run_mESC_20k.R:344-482` re-implements the event QC of
`run_real_datasets_revision.R:485-657`. It omits the within-time-replication
rule and one `na.rm = TRUE`. Both are without effect on the mESC data, and the
final counts agree (1972 events). QC is dataset-level preprocessing and is not
part of the core test, so core implementation is not blocked. It does block the
optional `filter_postexport_events()` helper (not in v0.1) until the author
confirms which definition is canonical. The proposal is the fuller
`run_real_datasets_revision.R` version; with the mESC data both give identical
results.

**SF-10: D (safe API decision, no change to frozen numerics).**
Proof from the code:

- When `t_star <= min(time)`, every interval has `t0 >= t_star`, so
  `R_dt = pmax(0, pmin(dt, t_star - t0)) = 0` (`nested_test2.r:703-711`).
- The R column of A is identically zero, its column norm is reset to 1
  (`:852-859`), the minimum singular value is 0, `condition.number = Inf`
  (`:1035-1044`), and `rank.full = 6`.
- Every bootstrap replicate then has rank < 7, so
  `bootstrap.rank.deficient.fraction = 1` (`:2046-2053`).
- NNLS assigns `R = 0`, and inference is unaffected. This matches
  `Median_condition = Inf` for all four real datasets.

The package keeps these frozen diagnostics verbatim. The proposed additions
(`structurally_zero_columns`, a condition number over the non-zero columns,
eigenvalue-floor counts from `make_spd`) are computed alongside and never feed
back into any estimate, statistic or p-value. Approval is still requested for
the new diagnostic fields and their names, but they change no frozen numerics
and do not block implementation.

**SF-11: B (blocks an optional feature only).**
The core test takes four-state tables and does not depend on how they were
produced. What is missing affects only the optional preprocessing:

- K562/NIH-3T3 labelling-fraction and ERCC inputs are absent from the tag.
- The `*.sh` heredocs are not runnable as written.
- GSE207924 filenames are mismatched.
- Symbols come from live biomaRt.
- Missing states are zero-filled via `dcast(fill = 0)`.

This blocks a dedicated `rmats_to_postexport()` helper, which would carry the
historical zero-fill semantics explicitly (Section 7), until its scope is
decided. It is also a provenance limitation: K562/NIH-3T3 results cannot be
reproduced from the tag. Neither affects core implementation. The mESC and
Kc167 inputs are reproducible from the tag's normalized CSVs; Kc167 needs the
hours→minutes ×60 conversion from `GSE83620/gen_RMATS_table.r:168`.

**SF-12: C (provenance/documentation).**
The benchmark's `N_time_samples` labels are nominal. The effective numbers of
time points are 9 (NONE, label 10), 17 (NONE, label 20) and 15 (SHUTOFF, label
20 with T_step 50), computed from `gen_…_corrected_onset.R:470-545`. The NONE
sampling grid does not depend on `T_step`, so the four NONE × T_step cells are
independent re-simulations of one design. This concerns how manuscript
benchmark tables are described, not the test. For the package, the domain
table stores both nominal and effective values and matches on the effective
values. That is a data-preparation detail, not a change to frozen numerics.
Nothing is blocked.

**SF-15: D (safe API decision, no change to frozen numerics).**
`test_sigma_nested(lambda_var = )` is a compatibility alias that overrides
`lambda_time` (`nested_test2.r:1481-1485`), although the historical
`lambda_var` shrank toward a different target (whole-dataset pooled variance,
`nested_test.r:50, 90`). No final script passes it. Not exposing it in
`postexport_control()` removes an ambiguous, misleading control. It leaves all
frozen computations with the default `lambda_var = NULL` exactly unchanged,
which is how every final script ran.

---

## 6. Revised core-v0.1 scope (amends `PACKAGE_PLAN.md` §5)

### 6.1 Exported functions (v0.1.0)

| Function | Summary | Frozen basis |
|---|---|---|
| `postexport_data()` | constructor from wide or long input; explicit column/state mapping; required `time_unit`; **missing states are an error** (Section 7) | new (input layer) |
| `validate_postexport_data()` | error/warning/info report | rules from `nested_test2.r` and the benchmark design range |
| `postexport_control()` | `lambda_time = 0.5`, `lambda_diag = 0.1`, `rel_floor = 1e-8`, `scaling_A = TRUE`, `truncate_nonnegative_boot = FALSE`, `max_failure_rate = 0.05`; no `lambda_var` | `nested_test2.r:1447-1475` |
| `fit_postexport_model()` | deterministic full and `sigma_c = 0` fits, T, IR, diagnostics; no RNG | `nested_test2.r:1510-1632` |
| `test_postexport_conversion()` | bootstrap test for one or many events; BH within the call; per-event seeds | `nested_test2.r:1447-2166`; batch/BH from the real-data scripts |
| `simulate_postexport_kinetics()` | replicate-level four-state simulation (onset, common `t_star`, `post_R_fraction`, `param_cv`) | `ode.r` (`generate_ODE_states`, `simulate_scheduled_trajectory`) |
| `check_operational_domain()` | diagnostic comparison with manuscript benchmark designs (Section 8) | `benchmark_main_corrected_onset_summary.tsv` |
| `rank_postexport_candidates()` | exploratory score `sigma_c × IR × min(-log10(max(q, 1e-10)), 6)` (pending SF-9 confirmation) | `run_real_datasets_revision.R:1495-1627`; `analyze_composite_score_ablation.R:187-218` |

Plus S3 methods `print`, `summary`, `plot`, `coef` and `as.data.frame` for the
result classes, and `print`/`summary` for `postexport_data` and the
validation/domain reports.

### 6.2 Internal in v0.1 (not exported)

- `build_interval_balance()`: internal wrapper over the `build_Ab_fullcov` port.
  Tests use it directly. Users can inspect `A`, `b` and `Sigma_b` through a
  documented field of `fit_postexport_model()` results (`$system`, if approved)
  rather than through a separate export.
- `add_assay_noise()`: internal. It is used by regression fixtures (FX-NOISE-1)
  and by internal benchmark-reproduction code.
- `postexport_trajectory()`: internal. It is used by `plot()` methods, which
  draw Crank–Nicolson null/full means at observed times by default.

Consequence for `simulate_postexport_kinetics()` in v0.1: it returns
replicate-level states with biological variability (`param_cv`) only, without
assay noise. The vignette's synthetic example uses this output directly. The
test does not require assay noise, because covariance is estimated from
replicates. Whether a later release exports assay noise, or adds an
`assay = NULL` argument to the simulator, is deferred.

### 6.3 Excluded from v0.1

- ΔPSI and cytoplasmic-only comparators, PR-AUC/AUROC/precision@K, Wilson and
  benchmark-summary utilities (Section 3).
- `filter_postexport_events()` (SF-8), `rmats_to_postexport()` (SF-11),
  `perturb_fraction_separation()`, `sample_kinetic_parameters()`.
- `SummarizedExperiment` input.

---

## 7. Missing-state behaviour (amends `PACKAGE_PLAN.md` §5.1, §5.4, §6)

- The `missing_state` argument is **removed** from `postexport_data()`. There
  is no automatic zero-fill and no automatic NA-dropping in the generic
  constructor.
- A *missing state* is a sample (event × time × replicate) that lacks a value
  for any of `N`, `N_s`, `C` or `C_s`:
  - in long input, the row for that state is absent;
  - in wide input, the cell is `NA`.
- Either case is an **ERROR**. The message names the event, time, replicate
  and missing state(s), and says that the package never imputes states.
- Relation to frozen behaviour:
  - The frozen core silently drops incomplete rows per time point
    (`complete.cases`, `nested_test2.r:293-297`). The package constructor is
    stricter: it refuses such input rather than dropping it.
  - For every input the constructor accepts (complete samples), the numerical
    path is identical to the frozen code.
  - The internal verbatim port keeps `complete.cases`, so the regression
    fixtures that exercise NA rows (FX-COV-2) still test frozen behaviour
    through the internal function.
  - Users who want to exclude incomplete samples do so explicitly before
    construction. The documentation shows how.
- Historical rMATS zero-fill (`dcast(..., fill = 0)` in the three
  `gen_RMATS_table.r` scripts) may later be implemented **only** inside a
  dedicated rMATS conversion helper (e.g. `rmats_to_postexport(zero_fill = TRUE)`).
  It must be documented as reproducing the manuscript preprocessing, with the
  caveat that absent junction counts are then treated as observed zeros.
- Validation table change: "Rows with NA in any state" moves from WARNING to
  **ERROR** in the constructor. All other rows of `PACKAGE_PLAN.md` §6 are
  unchanged.

---

## 8. Operational domain (amends `PACKAGE_PLAN.md` §8)

The following properties of `check_operational_domain()` are confirmed and
become requirements (to be enforced by tests).

1. **It is diagnostic only.**
   - It never raises an error because of the design.
   - It never alters, gates or re-weights inference.
   - `fit_postexport_model()` and `test_postexport_conversion()` never call
     `stop()` on domain grounds.
   - At most, results carry the domain report as an attribute, and `print()`
     shows a one-line note.
   - Proposal: no R `warning()` from the domain check. Warnings are reserved
     for validation findings in `validate_postexport_data()`.
2. **It never claims calibration for a new dataset.**
   - The output reports only the empirical behaviour of similar designs *in
     the manuscript benchmark*: Type I error at α = 0.05 with Wilson 95% CI,
     power, calibration class.
   - It always carries these caveats: the benchmark parameter prior and rate
     scale (per minute), the simulated assay models, destructive sampling,
     complete-shutoff simulation, and the fact that noise level/platform of
     real data are generally unknown. When the user supplies neither, results
     are shown across all platforms and noise levels.
3. **Fixed wording templates**, to be reviewed before implementation:
   - "In the manuscript synthetic benchmark, designs most similar to this one
     showed empirical Type I error between X and Y at α = 0.05 (Z of N
     benchmark cells had a Wilson 95% interval containing 0.05). This
     describes simulated data under the benchmark assumptions and is not a
     calibration guarantee for this dataset."
   - For continuous-transcription designs: "No continuous-transcription design
     in the manuscript benchmark showed nominal Type I error (0 of 576 cells;
     median 0.394 at α = 0.05)."
   - For pseudo-shutoff data: "Data are fitted as complete shutoff at
     `t_star`; residual transcription was shown in the manuscript to affect
     null calibration (see the pseudo-shutoff sensitivity analysis)."
     No numbers are given, because that summary is not in the tag (SF-4).
4. **Data source:** only `benchmark_main_corrected_onset_summary.tsv` from the
   tag, with provenance (tag, SHA, file checksum) stored with the internal
   table. Matching uses effective design descriptors (SF-12).
5. **Tests will assert** that `test_postexport_conversion()` returns identical
   numeric results whether or not the domain check runs, and that no domain
   outcome produces an error.

---

## 9. Summary of classifications

| Item | Class | Blocks core? | Action needed from the author |
|---|---|---|---|
| SF-1 real-data B | C | no | confirm B = 4999 for the revision real-data run; check the manuscript text on B |
| SF-2 RNG restore no-op | D | no | acknowledge; package reproduces actual behaviour |
| SF-3 noise-matching analysis | C | no | locate or declare absent |
| SF-4 pseudo-shutoff provenance | C | no | confirm the misspecification runner is authoritative; README wording |
| SF-5 ΔPSI comparators | C (excluded from v0.1) | no | manuscript question only |
| SF-6 PR-AUC rules | C (excluded from v0.1) | no | manuscript question only |
| SF-7 cytoplasmic-only comparator | B (excluded from v0.1) | no | none for v0.1 |
| SF-8 QC divergence | B | no | choose the canonical QC before any QC helper |
| SF-10 diagnostics at `t_star ≤ t₁` | D | no | approve the additional diagnostic fields |
| SF-11 preprocessing provenance | B | no | scope of a future rMATS helper |
| SF-12 nominal vs effective designs | C | no | none for the package |
| SF-15 `lambda_var` alias | D | no | approve non-exposure |

**No item in this report blocks implementation of the core v0.1 package.**
The items still open from `PACKAGE_PLAN.md` §16 are:

- SF-9: canonical ranking score;
- SF-14: license;
- SF-18: domain wording (Section 8.3 above);
- SF-19: level for negative abundances;
- the §16.A/B engineering and API questions.

They should be settled before, or at the start of, implementation Phase 1.
SF-14 must be settled before any file derived from frozen code is committed.

Stopping here for review.
