# =============================================================================
# Build the internal benchmark-design table used by check_operational_domain()
#
# Usage (from the package root):
#   FROZEN=$(tools/frozen/export_frozen.sh)
#   Rscript data-raw/benchmark_domain.R "$FROZEN"
#
# Source (frozen tag manuscript-revision-v1.0,
# 65c3b7368fb7686bfde3dab857f98c393bb534c5):
#   synthetic_dataset/benchmark_main_corrected_onset_summary.tsv
#       one row per benchmark configuration (1152), produced by
#       run_benchmark_main_corrected_onset_revision.R:3074-3355
#   synthetic_dataset/benchmark_main_corrected_onset_run_metadata.tsv
#   synthetic_dataset/analyze_benchmark_corrected_onset_final.R
#       calibration classes (L406-424), practical band (L91-94, L426-433),
#       operational-domain flags (L867-896): primary = Wilson 95% CI of the
#       empirical Type-I error at alpha = 0.05 contains 0.05; secondary =
#       Type-I error in [0.025, 0.075].
#   synthetic_dataset/gen_synthetic_ODE_states_corrected_onset.R
#       sampling designs (L235-254 horizon and T_star; L470-545 sampling
#       times), reproduced below expression by expression to record the
#       EFFECTIVE sampling times of every configuration.
#
# Output: R/sysdata.rda with objects .pek_benchmark (data frame) and
# .pek_benchmark_provenance (list). Only design descriptors and calibration /
# power summaries are kept; no raw benchmark output is packaged.
# =============================================================================

FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)
snap <- normalizePath(args[1], mustWork = TRUE)
stopifnot(identical(readLines(file.path(snap, ".frozen_commit")), FROZEN_COMMIT))

sum_file <- file.path(snap, "synthetic_dataset",
                      "benchmark_main_corrected_onset_summary.tsv")
meta_file <- file.path(snap, "synthetic_dataset",
                       "benchmark_main_corrected_onset_run_metadata.tsv")

s <- utils::read.delim(sum_file, check.names = FALSE, stringsAsFactors = FALSE)
meta <- utils::read.delim(meta_file, check.names = FALSE,
                          stringsAsFactors = FALSE)
stopifnot(nrow(s) == 1152L, nrow(meta) == 1L)

# --- Generator design (gen_synthetic_ODE_states_corrected_onset.R) ----------
r_sigma_n_min <- 0.05; r_tau_min <- 0.006; r_tau_s_min <- 0.003
r_sigma_c_min <- 0.05; r_alpha_min <- 0.03; r_alpha_s_min <- 0.01
tmax <- 3 / min(r_sigma_n_min + r_tau_min, r_tau_s_min,
                r_sigma_c_min + r_alpha_min, r_alpha_s_min)          # L235-240
times <- seq(0, tmax, by = 1)                                         # L242-246
T_star <- times[floor(length(times) / 3)]                             # L250-254
stopifnot(T_star == meta$common_T_star)

none_times <- function(time_samples_i) {                               # L470-500
    u <- seq(0, 1, length.out = time_samples_i + 2)
    p <- 3
    idx <- floor(max(times) / 3 * (u^p))
    sampled_times <- sort(unique(idx))
    if (length(sampled_times) >= 3L) {
        sampled_times <- sampled_times[-1]
        sampled_times <- sampled_times[-length(sampled_times)]
    }
    sampled_times
}
shutoff_times <- function(time_samples_i, tstep_i) {                   # L507-545
    if (time_samples_i == 2L) {
        x <- c(T_star - tstep_i, T_star)
    } else {
        step_adders <- cumsum(rep(tstep_i, time_samples_i - 2L))
        x <- sort(c(T_star - tstep_i, T_star, T_star + step_adders))
    }
    x[x >= min(times) & x <= max(times)]
}

design_times <- mapply(function(pert, nt, ts) {
    if (pert == "NONE") none_times(nt) else shutoff_times(nt, ts)
}, s$Perturbation, s$N_tsamples, s$Tsteps, SIMPLIFY = FALSE)

platform_map <- c("GAUSS" = "gaussian", "RNA-seq" = "rnaseq",
                  "RT-qPCR" = "rtqpcr")
level_map <- c("Very low" = "very_low", "Low" = "low", "Medium" = "medium",
               "High" = "high")

bench <- data.frame(
    regime = s$Perturbation,
    platform = unname(platform_map[s$Platform]),
    noise_level = unname(level_map[s$Exprs_noise]),
    n_time_points_nominal = as.integer(s$N_tsamples),
    n_time_points = vapply(design_times, length, integer(1)),
    n_replicates = as.integer(s$N_replicates),
    sampling_interval = as.numeric(s$Tsteps),
    sampling_times = vapply(design_times, function(x) {
        paste(format(x, trim = TRUE), collapse = ",")
    }, character(1)),
    sampling_times_relative_to_t_star = vapply(seq_along(design_times),
        function(i) {
            if (s$Perturbation[i] == "NONE") return(NA_character_)
            paste(format(design_times[[i]] - T_star, trim = TRUE),
                  collapse = ",")
        }, character(1)),
    n_null = as.integer(s$N_null),
    n_alternative = as.integer(s$N_alt),
    n_valid = as.integer(s$N_valid),
    type1_005 = s$TypeI_005,
    type1_005_wilson_low = s$TypeI_005_Wilson_low,
    type1_005_wilson_high = s$TypeI_005_Wilson_high,
    ci_contains_005 = as.logical(s$TypeI_005_CI_contains_005),
    practical_near_nominal = s$TypeI_005 >= 0.025 & s$TypeI_005 <= 0.075,
    calibration_class = ifelse(
        s$TypeI_005_Wilson_low > 0.05, "Anti-conservative",
        ifelse(s$TypeI_005_Wilson_high < 0.05, "Conservative",
               "CI includes 0.05")),
    power_005 = s$Power_005,
    stringsAsFactors = FALSE
)
stopifnot(!anyNA(bench$platform), !anyNA(bench$noise_level),
          identical(bench$ci_contains_005,
                    bench$calibration_class == "CI includes 0.05"))

.pek_benchmark <- bench
.pek_benchmark_provenance <- list(
    frozen_tag = "manuscript-revision-v1.0",
    frozen_commit = FROZEN_COMMIT,
    summary_file = "synthetic_dataset/benchmark_main_corrected_onset_summary.tsv",
    summary_md5 = unname(tools::md5sum(sum_file)),
    run_metadata_file = "synthetic_dataset/benchmark_main_corrected_onset_run_metadata.tsv",
    run_metadata_md5 = unname(tools::md5sum(meta_file)),
    run_metadata = as.list(meta),
    criterion = paste(
        "Primary operational criterion (analyze_benchmark_corrected_onset_final.R",
        "L867-896): the Wilson 95% interval of the empirical Type-I error at",
        "alpha = 0.05 contains 0.05. Secondary descriptive flag: empirical",
        "Type-I error in [0.025, 0.075] (L91-94, L426-433). Calibration class",
        "(L406-424): Anti-conservative if the Wilson lower bound > 0.05,",
        "Conservative if the upper bound < 0.05, otherwise 'CI includes 0.05'."),
    design_notes = c(
        "Time scale: the benchmark rates are per minute (tmax = 1000, common T_star = 332).",
        "SHUTOFF designs sample one point at T_star - T_step, one at T_star and N_time_samples - 2 points at spacing T_step after T_star, truncated at 1000.",
        "NONE designs use u^3-spaced times that do not depend on T_step; the four T_step cells of a NONE design are independent re-simulations of the same design.",
        "n_time_points is the effective number of sampling times; n_time_points_nominal is the benchmark label.",
        "Each configuration: 2000 simulated genes (about 20% with sigma_c > 0), onset shifts in [-100, 100], replicate CV 0.05, B = 1999 bootstrap replicates."
    ),
    generated_by = "data-raw/benchmark_domain.R",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
)

save(.pek_benchmark, .pek_benchmark_provenance, file = "R/sysdata.rda",
     compress = "xz", version = 3)
cat("Saved", nrow(bench), "configurations to R/sysdata.rda (",
    file.size("R/sysdata.rda"), "bytes )\n")
print(table(bench$regime, bench$n_time_points))
print(with(bench, table(regime, ci_contains_005)))
