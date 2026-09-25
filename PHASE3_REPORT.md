# Phase 3 Report: simulation and operational-domain diagnostics

Status: **Phase 3 approved and completed (§16); merged to `main`.
Phase 4 not started.**

Baseline: `main` @ `d88d4b04f540f00b684cba6925548d02d7295c1b`. The
validated Phase 1/2 numerical core was not changed.

Frozen reference: `manuscript-revision-v1.0` →
`65c3b7368fb7686bfde3dab857f98c393bb534c5`.

Commits on `phase3-sim`:

- `3e1c797` Port frozen ODE simulator and assay models verbatim
- `7635b10` Add simulate_postexport_kinetics() and check_operational_domain()

---

## 1. Simulation source mapping

Authoritative path: `ode_model/ode.r` at the tag, as used by
`gen_synthetic_ODE_states_corrected_onset.R`, plus the assay models in
`commons/platforms.r` with the benchmark presets from
`run_benchmark_main_corrected_onset_revision.R`. The historical generator
(`gen_synthetic_ODE_states.r`) and the legacy observation-shift helpers of
`ode.r` (`apply_observation_shift`, `simulate_piecewise_trajectory`,
`simulate_latent_trajectory`) were not used.

| Concept | Frozen source | Package |
|---|---|---|
| four-state ODE | `ode.r:54-89` `rna_kinetics` | `R/ode.R` (verbatim) |
| closed-form steady state | `ode.r:119-178` `steady_states` | `R/ode.R` (verbatim) |
| one interval at fixed R (`deSolve::ode`, lsoda) | `ode.r:301-348` `integrate_interval_fixed_R` | `R/ode.R` (verbatim) |
| transcription schedule: onset, t_star, residual fraction | `ode.r:374-640` `simulate_scheduled_trajectory` | `R/ode.R` (verbatim) |
| replicate generation (log-normal rate multipliers; R fixed) and baseline/intervention trajectories | `ode.r:771-1290` `generate_ODE_states` | `R/ode.R` (verbatim) |
| explicit per-gene onset, no internal draw (`use_onset_shift = FALSE`, `max_shift = 0`, `nominal_onset_time`) | `gen_…_corrected_onset.R:584-587, 660-664` | `.simulate_composition()` uses the same call pattern |
| parameter list order (order of replicate draws) | `gen_…_corrected_onset.R:331-392` (`random_params()` then `sigma_c`, `R`, `alpha_s`) → `tau, tau_s, alpha, alpha_s, sigma_n, sigma_c, R` | `.FROZEN_PARAM_LIST_ORDER` |
| NONE: baseline trajectory, `t_star = NULL`, `post_R_fraction = 1` | `gen_…:564-588` | regime `"NONE"` |
| SHUTOFF: intervention trajectory, `post_R_fraction = 0` | `gen_…:637-682` | regime `"SHUTOFF"` |
| pseudo-shutoff: `post_R_fraction = rho > 0` | `gen_…:211-220, 637-682`; used by the authoritative `run_pseudoshutoff_misspecification_benchmark.R` | regime `"PSEUDO_SHUTOFF"`, `residual_fraction` |
| initial state | `y0 = 0` at the simulation origin (`gen_…:552-557`) | `y0` (default 0), `origin`, `grid_step`, `horizon` |
| Gaussian / RNA-seq / RT-qPCR models | `platforms.r:45-54, 67-71, 89-125, 145-182` | `R/assay.R` (verbatim except data.table → data.frame) |
| platform × level presets | `run_benchmark_main…R:469-474, 538-645` | `R/assay.R` (verbatim except data.table → data.frame) |

Mechanical edits:

- `stats::` qualification of `rgamma`, `rpois` and `rnorm`;
- in `simulate_rnaseq`, `simulate_rt_qpcr` and `add_platform_noise_main`,
  `copy(as.data.table(dt))` → `as.data.frame(dt)` and `dt[]` → `dt`.

`data.table` is therefore not required. All outputs are bitwise identical to
the frozen `data.table` versions; frozen data.tables carry no row names, so row
names are reset before comparison. `deSolve` and `utils` were added to
`Imports`. The names used inside `with()` in `rna_kinetics` are declared in
`R/globals.R`, leaving the port unchanged.

**Pseudo-shutoff authority:** there is a single frozen residual-transcription
implementation, `post_R_fraction` in `ode.r`. The historical generator has no
pseudo-shutoff, and the superseded pseudo-shutoff runner used the same
`ode.r`. Its semantics are unambiguous, so it is exposed; no new model was
introduced.

---

## 2. Timing semantics mapping

The rules come from `simulate_scheduled_trajectory()`, `ode.r:374-640`; the
header of `ode.r` is at lines 13-43.

- **One time axis:** all times, in `time_unit`.
- **Transcription schedule** (right-continuous):
  - `R(t) = 0` for `t < onset_time`;
  - `R` for `onset_time <= t < t_star`;
  - `post_R_fraction * R` for `t >= t_star`.
- **Early onset:** an `onset_time` earlier than the grid origin is handled by
  a pre-run from `onset_time`. `y0` is the state at `min(onset_time, origin)`.
- **Breakpoints:** onset and `t_star` are inserted as breakpoints; each
  interval is integrated at constant R.
- **Intervention time:** `t_star` is common and **independent of onset**. The
  onset changes only the transcriptional history. No observation time shift
  is applied, and the package never enables the frozen onset draw.

Regression tests (`test-simulation.R`):

- Onsets −30, 0, 20 and 60 with `t_star = 100`:
  - `R = 0` for all `t >= 100`;
  - `R = 100` between onset and `t_star`;
  - `R = 0` before onset;
  - the schedule changes at 100 for every onset.
- Different onsets give different pre-intervention states.
- NONE and SHUTOFF with the same onset coincide **exactly** before `t_star`.
- With `param_cv = 0` and no noise, the global `.Random.seed` is unchanged:
  no hidden random draw or time shift occurs.
- Pseudo-shutoff: `R = rho * R` after `t_star`.

---

## 3. Public function signatures

```r
simulate_postexport_kinetics(params, times, onset_time, t_star, regime,
                             time_unit, residual_fraction = NULL,
                             n_replicates = 1L, param_cv = 0, noise = NULL,
                             y0 = c(N = 0, N_s = 0, C = 0, C_s = 0),
                             origin = 0, grid_step = 1, horizon = NULL,
                             seed = NULL, event = "simulated")

check_operational_domain(data = NULL, regime, t_star = NULL,
                         platform = NULL, noise_level = NULL,
                         n_time_points = NULL, n_replicates = NULL,
                         sampling_interval = NULL, time_unit = NULL)
```

- **Required, no defaults:** `params`, `times`, `onset_time`, `t_star`
  (`NULL` allowed only for NONE), `regime` and `time_unit`. The domain check
  also requires `regime`.
- **Deterministic defaults:** `n_replicates = 1`, `param_cv = 0` and
  `noise = NULL` give the deterministic latent trajectory. The manuscript
  benchmark used `param_cv = 0.05`, 3/5/10 replicates, `origin = 0`,
  `grid_step = 1`, `horizon = 1000` and `y0 = 0`; this is documented.
- **Noise:** `noise = list(platform = "gaussian" | "rnaseq" | "rtqpcr",
  level = "very_low" | "low" | "medium" | "high")`. It maps one-to-one to the
  benchmark labels GAUSS / RNA-seq / RT-qPCR and Very low / Low / Medium /
  High.

S3 methods: `print()`/`summary()` for `postexport_simulation` and
`postexport_domain_check`. No `plot()`.

---

## 4. Supported transcriptional regimes

| Regime | Frozen semantics | `t_star` | `residual_fraction` |
|---|---|---|---|
| `NONE` | baseline trajectory, `post_R_fraction = 1` | must be `NULL` | not allowed |
| `SHUTOFF` | intervention trajectory, `post_R_fraction = 0` | required | not allowed |
| `PSEUDO_SHUTOFF` | intervention trajectory, `post_R_fraction = rho` | required | required, in (0, 1] |

---

## 5. Parameter validation rules (errors unless stated)

- **`params`:**
  - named numeric vector or list with exactly `R, tau, tau_s, sigma_c,
    sigma_n, alpha, alpha_s`;
  - finite and non-negative;
  - **unnamed vectors are rejected**; names determine the order, and
    positions are never used (tested with a shuffled named vector).
- **`times`:**
  - finite, distinct, `>= origin`;
  - unsorted times are accepted and returned sorted (tested equal to sorted
    input);
  - duplicates are an error.
- **Timing and grid:**
  - `onset_time`: a single finite number;
  - `t_star`: consistent with `regime`;
  - `horizon >= max(times)`;
  - `grid_step > 0`.
- **Regime:** `regime` must be one of the three regimes, and the
  `residual_fraction` rules follow the table in §4.
- **Replicates:** `n_replicates` is a positive whole number; `param_cv >= 0`.
- **Other arguments:**
  - `noise` must use the documented vocabulary;
  - `y0` is a named, finite, non-negative vector of the four states;
  - `seed` is `NULL` or a whole number;
  - `time_unit` is a non-empty string.
- **Warnings:**
  - `t_star < onset_time`;
  - `t_star > max(times)` (no post-intervention sample);
  - identical replicates (`n_replicates > 1` with `param_cv = 0` and no
    noise).

---

## 6. Result object structure

`postexport_simulation`:

```
event, time_unit
latent      deterministic states on the integration grid, per replicate
            (event, replicate, time, N, N_s, C, C_s, R)
sampled     latent states at the sampling times (same columns)
observed    noisy observations (event, time, replicate, N, N_s, C, C_s) or NULL;
            no R column (not observable); accepted by postexport_data()
params      base parameters (PARAM_NAMES order)
replicate_parameters, steady_state   per replicate (frozen generate_ODE_states output)
timing      regime, onset_time, t_star, residual_fraction, post_R_fraction,
            origin, grid_step, horizon, sampling_times
replication n_replicates, param_cv
noise       platform, level, benchmark labels and preset values (or NULL)
y0, rng (seed, kind, random_seed_before, draw_order, note), provenance
```

`postexport_domain_check`:

```
designs     one row per distinct design (events, n_time_points, n_replicates,
            sampling_interval, time_unit, n_before_t_star, regime, platform,
            noise_level, match_type)
checks[[i]] design, match_type ("exact" | "nearest" | "not_benchmarked"),
            matches (benchmark configurations), differences (nearest only),
            summary, statements, caveats
provenance  benchmark provenance (tag, commit, files, md5, run metadata, criterion)
```

There is no field that states that a dataset is calibrated, and there is no
valid/invalid verdict.

---

## 7. RNG behaviour

- **Explicit seed:** `set.seed(seed)`, then the frozen composition. The
  caller's `.Random.seed` is restored afterwards, using the Phase 2 helper.
- **`seed = NULL`:** the global stream is consumed.
- **Draw order:**
  - per replicate, one normal draw for each of `tau, tau_s, alpha, alpha_s,
    sigma_n, sigma_c, R` (the `R` draw is discarded, as frozen);
  - then assay noise for `N, C, C_s, N_s`.
- **No draws** are made with `param_cv = 0` and no noise.

Tests:

- a fixed seed reproduces the result exactly and leaves the caller's state
  unchanged;
- `seed = NULL` leaves the stream in exactly the state produced by the
  frozen-order composition from the same starting point, with identical
  observations;
- the random-number state before the call is recorded.

The frozen generator seeds per gene (`1000000 + gene` / `2000000 + gene`, with
the ineffective restore, SF-2); benchmark-gene reproduction is not part of
the public API.

**Cross-platform:** random draws are generated by R itself. `deSolve::lsoda`
(compiled) and assay noise that depends on values (`rpois`, `rnegbin`) can
differ at rounding level. Latent states are therefore level B (scale-aware
deterministic) and noisy observations level C (reported).

---

## 8. Simulation regression results

Local, macOS (fixture platform). Fixtures are generated by
`tools/frozen/make_fixtures_phase3.R`, which writes only new files; frozen
compositions are defined in `tools/frozen/frozen_compositions.R`.

| Fixture | Cases | Content | Bitwise identical |
|---|---:|---|---:|
| `fx_source_simulation` | 11 | frozen source text | verbatim check passes |
| `fx_ode` | 30 | `rna_kinetics`, `steady_states`, `integrate_interval_fixed_R`, `simulate_scheduled_trajectory` (onset −30/0/20 × t_star NULL/100 × rho 0/0.25/1, unsorted/duplicated times, non-zero y0, t_star before origin), 5 frozen error messages | 30/30 |
| `fx_generate` | 18 | NONE / SHUTOFF / PSEUDO_SHUTOFF × onset −30/0/20 × (1 replicate, CV 0) / (3 replicates, CV 0.05) | 18/18 |
| `fx_noise` | 17 | 3 platforms × 4 levels, invalid platform, raw functions | 17/17 |
| `fx_simulation` | 4 | seeded compositions with Gaussian/Low, RNA-seq/Medium (pseudo-shutoff), RT-qPCR/High (NONE), latent only | 4/4 |

`simulate_postexport_kinetics()` reproduces all 22 frozen compositions
(`fx_generate` plus `fx_simulation`) bitwise, covering the latent grid,
sampled and observed states, replicate parameters and steady states.

Full suite, 13 files: **3,439 expectations, 0 failures**. The recompute
round-trip reproduces all 16 fixture files bitwise on macOS; the forced
cross-platform mode passes; `compare_fixtures.R` reports no blocking failure.

---

## 9. Benchmark metadata provenance

`R/sysdata.rda` (19 kB): `.pek_benchmark`, 1152 rows, and
`.pek_benchmark_provenance`. It is built by `data-raw/benchmark_domain.R` from
the frozen export.

- **Summary:** `synthetic_dataset/benchmark_main_corrected_onset_summary.tsv`,
  MD5 `d2a94feb822f8387ff119358a442a57e`.
- **Run metadata:**
  `synthetic_dataset/benchmark_main_corrected_onset_run_metadata.tsv`, MD5
  `eadd915ca8a77b951c5bc674bf92bb19`: `N_BOOT` 1999, 2000 genes, 2,304,000
  tests, onset −100..100, `common_T_star` 332.
- **Criterion** (from `analyze_benchmark_corrected_onset_final.R`):
  - primary (L867-896): the Wilson 95% CI of Type-I error at α = 0.05
    contains 0.05;
  - secondary (L91-94, L426-433): Type-I error in [0.025, 0.075];
  - classes (L406-424).
- **Effective sampling design:** recomputed with the generator's own
  expressions (`gen_…_corrected_onset.R:235-254, 470-545`). The effective
  number of time points differs from the nominal label for NONE 10 → 9,
  NONE 20 → 17 and SHUTOFF 20 × 50 → 15.
- **Columns:** regime, platform, noise level, nominal and effective number
  of time points, replicates, interval, sampling times (absolute and relative
  to `t_star`), N null / alternative / valid, Type-I error with Wilson
  bounds, CI-contains flag, practical band, calibration class and power.
  Raw benchmark output is not packaged.
- **Verification:** the CI (`tools/ci/check_benchmark_provenance.R`) checks
  both MD5 checksums against the frozen export. The tests check the tag,
  commit, 1152 rows, 68/576 SHUTOFF and 0/576 NONE configurations meeting the
  criterion, and the effective time-point sets.

---

## 10. Operational-domain matching rules

- **Input:** a `postexport_data` object plus explicit `regime` (and optional
  `t_star`, `platform`, `noise_level`), or explicit design arguments. From
  data, the following are taken per event:
  - the number of distinct times;
  - the minimum number of replicates per time;
  - the regular interval (`NA` if irregular);
  - the time unit;
  - the number of samples before `t_star`.

  **Platform, noise level and regime are never inferred.**
- **Exact match:** equal regime, platform and noise level (all levels if not
  given), effective time points, replicates, and, for SHUTOFF only, the
  interval. The interval is compared only if it is regular and the time unit
  is minutes.
- **Nearest match (no exact match):** lexicographic nearest evaluated levels
  — interval, then time points, then replicates — within the same regime,
  platform and noise level. The result is labelled *nearest evaluated
  benchmark designs … not equivalent designs*. There is no interpolation and
  no score.
- **NONE:** the interval is ignored, because NONE designs do not depend on
  it. The statement "strongly anti-conservative across all tested
  configurations: … met in 0 of 576" is always added.
- **PSEUDO_SHUTOFF:** `not_benchmarked`, with an explanatory statement. The
  pseudo-shutoff summary is not in the tag.
- **Caveats:**
  - simulated benchmark assumptions, not a guarantee;
  - design descriptors only;
  - platform/noise level not supplied;
  - irregular interval;
  - non-minute units;
  - benchmark layout (one sample at `t_star − interval`) vs the user's number
    of samples before `t_star`;
  - NONE interval ignored.
- **Wording:**
  - "In the manuscript benchmark, the k configuration(s) matching this
    design … had …";
  - "No configuration of the manuscript benchmark matches this design
    exactly. The nearest evaluated benchmark designs …".

  Tests assert the absence of "is calibrated", "calibrated for", "valid
  design", "invalid", "verdict" and "your dataset", and the presence of "not
  a calibration guarantee".

---

## 11. Example exact and nearest matches

| Design | Match | Result (manuscript benchmark) |
|---|---|---|
| SHUTOFF, rnaseq, low, 5 time points, 3 replicates, interval 10 min | exact, 1 configuration | criterion met (Wilson CI contains 0.05) |
| SHUTOFF, rnaseq, medium, 5 × 3, interval 10 | exact, 1 | Type-I 0.0393, Wilson 0.0308–0.0499; criterion **not** met (conservative); power 0.114 |
| SHUTOFF, gaussian, high, 5 × 3, interval 50 | exact, 1 | anti-conservative; criterion not met |
| NONE, 5 × 3, all platforms/levels | exact, 48 | Type-I 0.246–0.347; 0/48 met; plus the NONE statement (0/576; median 0.394) |
| SHUTOFF, 7 × 4, interval 15 | nearest, 48 | levels: interval 10, 20; time points 5; replicates 3, 5; Type-I 0.0305–0.238; 12/48 met |
| mESC design (Nsd1-type event: 0/30/60/120/240 min, 3 replicates, `t_star = 0`), rnaseq | nearest, 16 | interval irregular, so not compared (5 × 3 at intervals 5/10/20/50); Type-I 0.0231–0.363; 3/16 met; caveats: 0 samples before `t_star`, irregular interval |

---

## 12. R CMD check

`R CMD build` + `R CMD check --as-cran --no-manual` (macOS, R 4.6.0):
**0 ERRORs, 0 WARNINGs, 2 NOTEs.**

- The NOTEs are the new submission and `pandoc` unavailable.
- Examples OK; tests OK (about 28 s).
- Tarball 739 kB, including the fixtures.
- A first run gave an Rd cross-reference WARNING, because roxygen markdown
  read the text "[-100, 100]" as a link. The wording was changed and the
  warning is gone.

---

## 13. BiocCheck (1.48.1, local)

**3 ERRORs, 3 WARNINGs, 12 NOTEs.**

| Finding | Type | Source | Status |
|---|---|---|---|
| version not `x.99.z`; version format | ERROR / WARNING | DESCRIPTION | intentional (`0.0.0.9000`) |
| no vignettes | ERROR | — | later phase |
| Support Site email (HTTP 404) | ERROR | maintainer registration | maintainer action |
| no Bioconductor dependencies | WARNING | DESCRIPTION | as before |
| `set.seed` (2) | WARNING | frozen orchestrator (documented), and the public simulator's explicit seeding with caller-state restore (approved RNG policy) | documented |
| `=` for assignment | NOTE (new) | frozen `simulate_rnaseq` (`disp = …`, `platforms.r`) | frozen code, unchanged |
| lines > 80 (6) | NOTE | frozen `ode.r` comment rules, frozen `platforms.r` and the ported `bootstrap.R` | frozen formatting, unchanged |
| `paste` in conditions; `<<-` (2); indentation; function length (21) | NOTE | frozen ports; function length also includes new validation code | unchanged (Phase 2 decisions) |
| R dependency, biocViews, ORCID, `fnd`, NEWS, bioc-devel | NOTE | metadata | as before |

---

## 14. Linux CI

Run **36094542304** on commit `7635b10` (branch `phase3-sim`, `ubuntu-latest`,
R release): **success** for both jobs.

| Job | Step | Result |
|---|---|---|
| `package` | install (with `deSolve`) | success |
| `package` | tests vs committed macOS fixtures (level B/C), including simulation and domain tests | success |
| `package` | `R CMD check --as-cran --no-manual`, `error-on: warning` | success: 0 ERRORs, 0 WARNINGs |
| `frozen-reference` | tag verified; export; frozen outputs (inference and simulation) recomputed on the committed inputs, with `ode.r`, `platforms.r` and the runner presets sourced | success |
| `frozen-reference` | **packaged benchmark metadata matches the frozen benchmark files (MD5)** | success |
| `frozen-reference` | **same-platform package vs frozen, strict**: inference, bootstrap draws, simulator, assay noise | success |
| `frozen-reference` | cross-platform frozen comparison (level B/C) | success: no blocking failure |
| `frozen-reference` | frozen repository unchanged | success |

**Cross-platform simulation results:**

- The ODE-layer, `generate_ODE_states` and assay-noise fixtures (`fx_ode`,
  `fx_generate`, `fx_noise`) do not appear in the cross-platform diagnostic.
  On Linux they agree with the macOS fixtures even at the strict elementwise
  tier, so the deterministic simulation results are within the approved
  policy with a wide margin.
- One `fx_simulation` case was reported as a non-blocking, platform-sensitive
  (level C) difference in its noisy observations.
- The remaining reported differences are the known ones: bootstrap draws and
  the four extreme-conditioning fixtures, within `100·κ·ε`.
- No scientific output was outside the policy.

The same-platform package-vs-frozen regression passes on Linux for the
simulator and all earlier components.

---

## 15. Unresolved decisions

1. **`horizon` argument.** The frozen generator integrates over its own grid
   (`times = 0:1000` in the benchmark), independently of the last sampling
   time. `horizon` (default `max(times)`) was added so that frozen
   trajectories can be reproduced exactly. It affects only integration
   intervals at the level of the solver tolerance, not the model.
2. **Defaults.** `n_replicates = 1`, `param_cv = 0` and `noise = NULL`
   give a deterministic default rather than the frozen
   `generate_ODE_states()` defaults (3 replicates, CV 0.05). The benchmark
   values are documented. Timing arguments have no defaults.
3. **One seed for replicate draws and noise.** The benchmark used separate
   per-stream seeds (measurement vs bootstrap, hashed keys). The public
   simulator uses one seed in the documented order. Reproducing individual
   benchmark genes (1000000 + gene seeds, full design grid, SF-2 behaviour)
   is not exposed.
4. **Nearest-design rule.** Lexicographic priority is interval, then time
   points, then replicates. Alternatives, such as a different priority or
   reporting all neighbours, can be chosen; none involves a score.
5. **Design derivation from data.** "Replicates" is the minimum number per
   time point. The interval is compared only when it is exactly regular and
   the time unit is minutes. Other units are not converted.
6. **Pseudo-shutoff domain.** The pseudo-shutoff benchmark summary
   (`pseudoshutoff_benchmark/pseudoshutoff_summary.tsv`) is not in the tag,
   so no quantitative pseudo-shutoff domain information is packaged. It
   could be added if the author supplies the file.
7. **Simulation vocabulary.** Platforms `gaussian` / `rnaseq` / `rtqpcr` and
   levels `very_low` … `high` are package vocabulary, mapped 1:1 to the
   benchmark labels.
8. **`data.table` removal** in the assay ports is proven bitwise identical;
   please confirm it is acceptable as a mechanical edit.
9. **Merge.** `phase3-sim` is not merged to `main`, pending review.


---

## 16. Phase 3 completion: approved decisions and final results

The review decisions were implemented in `56b5970`:

| # | Decision | Implementation |
|---|---|---|
| 1 | `horizon` kept (default `max(times)`) | documented as an integration-grid / numerical-reproducibility parameter; it does not change the model |
| 2 | Deterministic defaults kept | a *Manuscript benchmark settings* section documents `param_cv = 0.05`, 3/5/10 replicates, `origin = 0`, `grid_step = 1`, `horizon = 1000`, `y0 = 0`, `t_star = 332`, onsets −100..100 |
| 3 | One public seed | unchanged. Benchmark per-gene/per-stream seeding and the ineffective restore (SF-2) are not reproduced; this is documented. |
| 4 | Nearest designs: return the full set | For every ordering of the design dimensions, the configurations at the nearest evaluated level of each dimension in turn are kept (ties included), and **the union is returned**. Rows are sorted lexicographically for display and carry `differs_in`. The wording is "nearest evaluated benchmark designs (not equivalent designs)". There is no score and no interpolation. |
| 5 | Design derivation | unchanged (minimum replicates; exactly regular interval; minutes only; no unit conversion) |
| 6 | Pseudo-shutoff domain | unchanged: `not_benchmarked` with an explanation; no external files |
| 7 | Vocabulary | the 1:1 mapping to the manuscript labels is documented in both functions |
| 8 | `data.table` removal | kept |

**New tests:**

- **All tied nearest designs are returned.** For 7 time points × 4
  replicates at interval 15: intervals 10 and 20, replicates 3 and 5, all
  platforms and noise levels, 48 configurations.
- **Per-dimension nearest levels that are not evaluated together.** For
  16 time points at interval 10, with gaussian/low and 5 replicates, both
  (20 time points, interval 10) and (15 time points, interval 50) are
  returned.

**Final results:**

- **Local tests:** 3,448 expectations, 0 failures.
- **`R CMD check --as-cran --no-manual`:** 0 ERRORs, 0 WARNINGs, 2 NOTEs.
- **BiocCheck:** bioconductor.org was unreachable from the development
  machine at completion time (HTTP timeouts), and BiocCheck stopped while
  fetching its package-status file. It was re-run with only the
  network-dependent checks disabled (`no-check-deprecated`,
  `no-check-bioc-help`, `no-check-CRAN`, `no-check-dependencies`): **2
  ERRORs (version format, no vignettes), 3 WARNINGs (version format, no
  Bioconductor dependencies, `set.seed` ×2), 10 NOTEs**. These are the same
  package findings as in §13; the support-site and bioc-devel lookups were
  not performed.
- **Linux CI on `phase3-sim`:**

  | Run | Commit | Result |
  |---|---|---|
  | 36094542304 | `7635b10` | success |
  | **36095554467** | **`56b5970`** (final) | **success**, both jobs |

**Final Phase 3 commits:** `3e1c797`, `7635b10`, `756debf`, `56b5970`, and
this report update.
