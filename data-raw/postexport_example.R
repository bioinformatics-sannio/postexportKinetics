# =============================================================================
# Generates the small synthetic example dataset shipped with the package:
#   data/postexport_example.rda        (observations, wide format)
#   data/postexport_example_truth.rda  (simulation truth per event)
#   inst/extdata/postexport_example_long.csv (same observations, long format)
#
# Run from the package root with the package installed:
#   Rscript data-raw/postexport_example.R
#
# All data are simulated with simulate_postexport_kinetics() (the ported
# frozen manuscript simulator and assay-noise model). No real data are used.
#
# Design (one cell of the manuscript's corrected factorial benchmark). It was
# chosen, before any data were generated, as the SHUTOFF design with at most
# 10 time points and 5 replicates whose benchmark Type-I error interval
# contains 0.05 and whose benchmark power at alpha = 0.05 is highest (0.24;
# Type-I error 0.042). Low power is a property of the calibrated benchmark
# designs, so most simulated alternative events are not expected to be
# detected.
#   regime SHUTOFF, common intervention t_star = 332 min (benchmark value),
#   sampling times t_star - 10, t_star, t_star + 10, + 20, + 30
#   (5 time points, step 10 min, benchmark shutoff sampling rule),
#   5 destructive replicates per time point, replicate-level rate variability
#   param_cv = 0.05, RNA-seq assay noise at level "very_low",
#   origin 0, grid_step 1, horizon 1000, y0 = 0 (benchmark integration grid).
#
# Parameters: drawn once per event from the manuscript benchmark ranges
# (frozen ode_model/ode.r: tau 0.006-0.06, tau_s 0.003-0.03, alpha 0.03-0.69,
# alpha_s 0.01-min(alpha, 0.23), sigma_n 0.05-0.2, sigma_c 0.05-0.2 under the
# alternative; R ~ Gamma(shape 5, scale 20); onset uniform integer in
# [-100, 100], as in gen_synthetic_ODE_states_corrected_onset.R). Events
# alt_1..alt_4 have sigma_c > 0; null_1..null_4 have sigma_c = 0.
#
# The parameter draws below use this script's own seed; they reproduce the
# benchmark's parameter DISTRIBUTIONS, not its per-gene random streams.
# The seed was fixed before the data were generated and not tuned.
# =============================================================================

suppressPackageStartupMessages(library(postexportKinetics))

SEED <- 20260925L
T_STAR <- 332
TIMES <- T_STAR + c(-10, 0, 10, 20, 30)
N_REP <- 5L
NOISE <- list(platform = "rnaseq", level = "very_low")

draw_params <- function(alternative) {
    alpha <- stats::runif(1, 0.03, 0.69)
    p <- c(
        R = stats::rgamma(1, shape = 5, scale = 20),
        tau = stats::runif(1, 0.006, 0.06),
        tau_s = stats::runif(1, 0.003, 0.03),
        sigma_c = if (alternative) stats::runif(1, 0.05, 0.2) else 0,
        sigma_n = stats::runif(1, 0.05, 0.2),
        alpha = alpha,
        alpha_s = stats::runif(1, 0.01, min(alpha, 0.23))
    )
    p
}

set.seed(SEED)
events <- c(paste0("alt_", 1:4), paste0("null_", 1:4))
truth <- vector("list", length(events))
obs <- vector("list", length(events))
for (i in seq_along(events)) {
    alternative <- startsWith(events[i], "alt")
    p <- draw_params(alternative)
    onset <- sample(-100:100, 1)
    sim_seed <- SEED + i
    sim <- simulate_postexport_kinetics(
        p, times = TIMES, onset_time = onset, t_star = T_STAR,
        regime = "SHUTOFF", time_unit = "min", n_replicates = N_REP,
        param_cv = 0.05, noise = NOISE, origin = 0, grid_step = 1,
        horizon = 1000, seed = sim_seed, event = events[i])
    obs[[i]] <- sim$observed
    truth[[i]] <- data.frame(
        event = events[i],
        truth = if (alternative) "alternative" else "null",
        as.list(p), onset_time = onset, t_star = T_STAR,
        simulation_seed = sim_seed, stringsAsFactors = FALSE)
}

postexport_example <- do.call(rbind, obs)
postexport_example <- postexport_example[, c("event", "time", "replicate",
                                             "N", "N_s", "C", "C_s")]
postexport_example$replicate <- as.integer(postexport_example$replicate)
postexport_example <- postexport_example[order(
    match(postexport_example$event, events), postexport_example$time,
    postexport_example$replicate), ]
rownames(postexport_example) <- NULL
postexport_example_truth <- do.call(rbind, truth)
rownames(postexport_example_truth) <- NULL

# Long-format copy of the same observations for the file-input example.
long <- do.call(rbind, lapply(
    list(c("N", "nuclear", "unprocessed"), c("N_s", "nuclear", "processed"),
         c("C", "cytoplasmic", "unprocessed"),
         c("C_s", "cytoplasmic", "processed")),
    function(m) {
        data.frame(postexport_example[, c("event", "time", "replicate")],
                   compartment = m[2], state = m[3],
                   abundance = postexport_example[[m[1]]])
    }))
long <- long[order(match(long$event, events), long$time, long$replicate), ]
rownames(long) <- NULL

stopifnot(!anyNA(postexport_example),
          identical(nrow(postexport_example), 8L * 5L * 5L))
invisible(postexport_data(postexport_example, time_unit = "min"))

dir.create("data", showWarnings = FALSE)
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
save(postexport_example, file = "data/postexport_example.rda",
     compress = "xz", version = 2)
save(postexport_example_truth, file = "data/postexport_example_truth.rda",
     compress = "xz", version = 2)
utils::write.csv(long, "inst/extdata/postexport_example_long.csv",
                 row.names = FALSE)
