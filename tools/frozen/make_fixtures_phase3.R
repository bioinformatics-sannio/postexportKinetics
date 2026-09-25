# =============================================================================
# Generate Phase 3 frozen-reference fixtures (simulation).
#
# Usage (from the package root):
#   FROZEN=$(tools/frozen/export_frozen.sh)
#   Rscript tools/frozen/make_fixtures_phase3.R "$FROZEN"
#
# Writes ONLY new files (refuses to overwrite):
#   tests/testthat/fixtures/fx_source_simulation.rds  frozen source text
#   tests/testthat/fixtures/fx_ode.rds                ODE-layer functions
#   tests/testthat/fixtures/fx_generate.rds           generate_ODE_states()
#   tests/testthat/fixtures/fx_noise.rds              assay-noise functions
#   tests/testthat/fixtures/fx_simulation.rds         public-API compositions
#
# Sources only function definitions: ode_model/ode.r, commons/platforms.r,
# and, from synthetic_dataset/run_benchmark_main_corrected_onset_revision.R,
# only the objects RANGE_GAUSS_NOISE and add_platform_noise_main (parsed and
# evaluated individually; no top-level script code is run).
# =============================================================================

suppressPackageStartupMessages({
    library(data.table)
    library(deSolve)
})

FROZEN_TAG <- "manuscript-revision-v1.0"
FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
    stop("Usage: Rscript tools/frozen/make_fixtures_phase3.R <frozen_export> [fixture_dir]")
}
snap <- normalizePath(args[1], mustWork = TRUE)
fx_dir <- if (length(args) >= 2L) args[2] else "tests/testthat/fixtures"
if (!identical(readLines(file.path(snap, ".frozen_commit")), FROZEN_COMMIT)) {
    stop("Frozen export does not carry the expected commit marker.")
}
new_files <- c("fx_source_simulation", "fx_ode", "fx_generate", "fx_noise",
               "fx_simulation")
for (f in new_files) {
    if (file.exists(file.path(fx_dir, paste0(f, ".rds")))) {
        stop("Refusing to overwrite existing fixture ", f)
    }
}

ode_file <- file.path(snap, "ode_model", "ode.r")
plat_file <- file.path(snap, "commons", "platforms.r")
run_file <- file.path(snap, "synthetic_dataset",
                      "run_benchmark_main_corrected_onset_revision.R")

frozen <- new.env(parent = globalenv())
sys.source(ode_file, envir = frozen)
sys.source(plat_file, envir = frozen)
exprs <- parse(run_file, keep.source = FALSE)
for (e in exprs) {
    if (is.call(e) && identical(e[[1]], as.name("<-")) &&
        as.character(e[[2]]) %in% c("RANGE_GAUSS_NOISE",
                                     "add_platform_noise_main")) {
        eval(e, envir = frozen)
    }
}
stopifnot(exists("add_platform_noise_main", envir = frozen),
          exists("RANGE_GAUSS_NOISE", envir = frozen))

source(file.path("tools", "frozen", "frozen_compositions.R"))

capture <- function(expr) {
    tryCatch(list(value = expr), error = function(e) list(error = conditionMessage(e)))
}

# MD5 of frozen files, named by their path relative to the export (never by
# a machine-specific absolute path).
frozen_md5 <- function(files) {
    md5 <- tools::md5sum(files)
    names(md5) <- substring(normalizePath(files), nchar(snap) + 2L)
    md5
}

provenance <- list(
    frozen_tag = FROZEN_TAG,
    frozen_commit = FROZEN_COMMIT,
    frozen_md5 = frozen_md5(c(ode_file, plat_file, run_file)),
    generated_by = "tools/frozen/make_fixtures_phase3.R",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    R_version = R.version.string,
    platform = R.version$platform,
    sysname = unname(Sys.info()["sysname"]),
    machine = unname(Sys.info()["machine"]),
    La_version = La_version(),
    La_library = La_library(),
    BLAS = unname(extSoftVersion()["BLAS"]),
    RNGkind = RNGkind(),
    packages = vapply(c("nnls", "MASS", "deSolve", "data.table"),
                      function(p) as.character(utils::packageVersion(p)),
                      character(1))
)

save_fixture <- function(name, cases) {
    saveRDS(list(provenance = provenance, cases = cases),
            file.path(fx_dir, paste0(name, ".rds")), version = 3)
    cat(sprintf("  %-24s %4d cases\n", name, length(cases)))
}

# -----------------------------------------------------------------------------
# Frozen source text
# -----------------------------------------------------------------------------

src <- list(
    rna_kinetics = list("ode_model/ode.r", c(54, 89)),
    steady_states = list("ode_model/ode.r", c(119, 178)),
    integrate_interval_fixed_R = list("ode_model/ode.r", c(301, 348)),
    simulate_scheduled_trajectory = list("ode_model/ode.r", c(374, 640)),
    generate_ODE_states = list("ode_model/ode.r", c(771, 1290)),
    add_gaussian_noise = list("commons/platforms.r", c(45, 54)),
    sample_dispersion_gamma = list("commons/platforms.r", c(67, 71)),
    simulate_rnaseq = list("commons/platforms.r", c(89, 125)),
    simulate_rt_qpcr = list("commons/platforms.r", c(145, 182)),
    RANGE_GAUSS_NOISE = list(
        "synthetic_dataset/run_benchmark_main_corrected_onset_revision.R",
        c(469, 474)),
    add_platform_noise_main = list(
        "synthetic_dataset/run_benchmark_main_corrected_onset_revision.R",
        c(538, 645))
)
src_cases <- lapply(names(src), function(nm) {
    s <- src[[nm]]
    txt <- readLines(file.path(snap, s[[1]]), warn = FALSE)[s[[2]][1]:s[[2]][2]]
    stopifnot(startsWith(txt[1], paste0(nm, " <-")))
    list(input = list(name = nm, file = s[[1]], lines = s[[2]]),
         output = list(text = txt))
})
names(src_cases) <- names(src)
save_fixture("fx_source_simulation", src_cases)

# -----------------------------------------------------------------------------
# ODE layer
# -----------------------------------------------------------------------------

par_list <- list(tau = 0.03, tau_s = 0.015, alpha = 0.2, alpha_s = 0.08,
                 sigma_n = 0.1, sigma_c = 0.1, R = 100)
par_null <- utils::modifyList(par_list, list(sigma_c = 0))
y_mid <- c(N = 12, N_s = 30, C = 4, C_s = 60)

ode_cases <- list()
add_ode <- function(key, fun, a) {
    ode_cases[[key]] <<- list(input = list(fun = fun, args = a),
                              output = capture(do.call(frozen[[fun]], a)))
}

for (pn in c("alt", "null")) {
    p <- if (pn == "alt") par_list else par_null
    add_ode(sprintf("rna_kinetics/%s", pn), "rna_kinetics",
            list(t = 0, y = y_mid, params = p))
    add_ode(sprintf("steady_states/%s", pn), "steady_states", list(params = p))
    for (R_int in c(0, 50, 100)) {
        add_ode(sprintf("integrate_interval_fixed_R/%s/R=%g", pn, R_int),
                "integrate_interval_fixed_R",
                list(y_start = y_mid, t_start = 10, t_end = 25, params = p,
                     R_interval = R_int))
    }
}
add_ode("integrate_interval_fixed_R/zero_length", "integrate_interval_fixed_R",
        list(y_start = y_mid, t_start = 5, t_end = 5, params = par_list,
             R_interval = 100))
add_ode("integrate_interval_fixed_R/invalid_order", "integrate_interval_fixed_R",
        list(y_start = y_mid, t_start = 5, t_end = 4, params = par_list,
             R_interval = 100))

y_zero <- c(N = 0, N_s = 0, C = 0, C_s = 0)
sched_times <- c(0, 5, 50, 95, 100, 105, 150, 200)
for (onset in c(-30, 0, 20)) {
    for (ts in list(NULL, 100)) {
        for (rho in if (is.null(ts)) 1 else c(0, 0.25, 1)) {
            add_ode(sprintf("simulate_scheduled_trajectory/onset=%g/t_star=%s/rho=%g",
                            onset, if (is.null(ts)) "NULL" else ts, rho),
                    "simulate_scheduled_trajectory",
                    list(y0 = y_zero, times = sched_times, params = par_list,
                         onset_time = onset, t_star = ts,
                         post_R_fraction = rho))
        }
    }
}
add_ode("simulate_scheduled_trajectory/unsorted_duplicated_times",
        "simulate_scheduled_trajectory",
        list(y0 = y_zero, times = c(150, 0, 100, 5, 100, 50), params = par_list,
             onset_time = 0, t_star = 100, post_R_fraction = 0))
add_ode("simulate_scheduled_trajectory/nonzero_y0/onset=20",
        "simulate_scheduled_trajectory",
        list(y0 = y_mid, times = sched_times, params = par_list,
             onset_time = 20, t_star = 100, post_R_fraction = 0))
add_ode("simulate_scheduled_trajectory/t_star_before_origin",
        "simulate_scheduled_trajectory",
        list(y0 = y_zero, times = c(10, 20, 40), params = par_list,
             onset_time = -30, t_star = 5, post_R_fraction = 0.25))
for (bad in list(list(post_R_fraction = 1.5), list(onset_time = NA_real_),
                 list(t_star = c(1, 2)))) {
    a <- utils::modifyList(list(y0 = y_zero, times = sched_times,
                                params = par_list, onset_time = 0,
                                t_star = 100, post_R_fraction = 0), bad)
    add_ode(sprintf("simulate_scheduled_trajectory/invalid/%s", names(bad)),
            "simulate_scheduled_trajectory", a)
}
save_fixture("fx_ode", ode_cases)

# -----------------------------------------------------------------------------
# generate_ODE_states() on the package's call pattern
# -----------------------------------------------------------------------------

gen_cases <- list()
shut_times <- c(95, 100, 110, 130, 160)
none_times <- c(5, 20, 60, 120, 180)

gen_args <- function(regime, onset, n_rep, pcv, rho = 0.25) {
    list(params = unlist(par_list), regime = regime,
         times = if (regime == "NONE") none_times else shut_times,
         grid = seq(0, 200, by = 1), onset_time = onset, t_star = 100,
         residual_fraction = rho, y0 = y_zero, n_replicates = n_rep,
         param_cv = pcv, seed = 11L, noise_platform = NULL, noise_level = NULL)
}

for (regime in c("NONE", "SHUTOFF", "PSEUDO_SHUTOFF")) {
    for (onset in c(-30, 0, 20)) {
        for (rep_cfg in list(c(1, 0), c(3, 0.05))) {
            a <- gen_args(regime, onset, rep_cfg[1], rep_cfg[2])
            key <- sprintf("generate/%s/onset=%g/n_rep=%d/param_cv=%g",
                           regime, onset, rep_cfg[1], rep_cfg[2])
            gen_cases[[key]] <- list(
                input = list(fun = "frozen_simulation", args = a),
                output = capture(frozen_simulation(frozen, a))
            )
        }
    }
}
save_fixture("fx_generate", gen_cases)

# -----------------------------------------------------------------------------
# Assay noise on a committed latent table
# -----------------------------------------------------------------------------

lat <- gen_cases[["generate/SHUTOFF/onset=0/n_rep=3/param_cv=0.05"]]$output$value$sampled
noise_cases <- list()
for (platform in c("GAUSS", "RT-qPCR", "RNA-seq")) {
    for (level in c("Very low", "Low", "Medium", "High")) {
        set.seed(20260925L)
        out <- capture(as.data.frame(frozen$add_platform_noise_main(
            lat, platform, level)))
        noise_cases[[sprintf("add_platform_noise_main/%s/%s", platform,
                             level)]] <- list(
            input = list(fun = "add_platform_noise_main",
                         args = list(dt = lat, platform = platform,
                                     noise = level),
                         pre_seed = 20260925L),
            output = out
        )
    }
}
set.seed(3L)
noise_cases[["add_platform_noise_main/invalid_platform"]] <- list(
    input = list(fun = "add_platform_noise_main",
                 args = list(dt = lat, platform = "microarray", noise = "Low"),
                 pre_seed = 3L),
    output = capture(frozen$add_platform_noise_main(lat, "microarray", "Low"))
)
for (fn in c("simulate_rnaseq", "simulate_rt_qpcr")) {
    set.seed(5L)
    noise_cases[[sprintf("%s/defaults", fn)]] <- list(
        input = list(fun = fn, args = list(dt = lat), pre_seed = 5L),
        output = capture(as.data.frame(frozen[[fn]](lat)))
    )
}
set.seed(6L)
noise_cases[["add_gaussian_noise/sd=0.1"]] <- list(
    input = list(fun = "add_gaussian_noise",
                 args = list(df = lat, cols = c("N", "C"), noise_sd = 0.1),
                 pre_seed = 6L),
    output = capture(frozen$add_gaussian_noise(lat, c("N", "C"), 0.1))
)
set.seed(7L)
noise_cases[["sample_dispersion_gamma"]] <- list(
    input = list(fun = "sample_dispersion_gamma",
                 args = list(n_genes = 5, mean_disp = 0.025, cv_disp = 0.8),
                 pre_seed = 7L),
    output = capture(frozen$sample_dispersion_gamma(5, 0.025, 0.8))
)
save_fixture("fx_noise", noise_cases)

# -----------------------------------------------------------------------------
# Public-API compositions (latent + noise with one seed)
# -----------------------------------------------------------------------------

sim_cases <- list()
cfgs <- list(
    shutoff_gauss_low = list(regime = "SHUTOFF", onset = 0, platform = "GAUSS",
                             level = "Low"),
    pseudo_rnaseq_medium = list(regime = "PSEUDO_SHUTOFF", onset = -30,
                                platform = "RNA-seq", level = "Medium"),
    none_rtqpcr_high = list(regime = "NONE", onset = 20, platform = "RT-qPCR",
                            level = "High"),
    shutoff_latent_only = list(regime = "SHUTOFF", onset = 20, platform = NULL,
                               level = NULL)
)
for (nm in names(cfgs)) {
    cfg <- cfgs[[nm]]
    a <- gen_args(cfg$regime, cfg$onset, 3, 0.05)
    a$seed <- 20260925L
    a$noise_platform <- cfg$platform
    a$noise_level <- cfg$level
    sim_cases[[sprintf("simulation/%s", nm)]] <- list(
        input = list(fun = "frozen_simulation", args = a),
        output = capture(frozen_simulation(frozen, a))
    )
}
save_fixture("fx_simulation", sim_cases)
cat("Done.\n")
