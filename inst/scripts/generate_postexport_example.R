# Assisted-by: Claude Code (Anthropic)
# =============================================================================
# Provenance of the example data distributed with postexportKinetics:
#   data/postexport_example.rda          observations (wide format)
#   data/postexport_example_truth.rda    simulation truth per event
#   inst/extdata/postexport_example_long.csv   the same observations, long
#
# The distributed data were generated with this script, using the package's
# validated simulator simulate_postexport_kinetics(). That simulator is the
# ported manuscript simulator and assay-noise model, regression-tested
# against the frozen manuscript implementation. No real data and no frozen
# repository inputs are used; the package alone is sufficient.
#
# Usage:
#   Rscript generate_postexport_example.R [out_dir]
#       writes the three files to out_dir (default: a new temporary
#       directory); it never writes into the installed package.
#   source(system.file("scripts", "generate_postexport_example.R",
#                      package = "postexportKinetics"))
#       defines generate_postexport_example(), which returns the objects.
#
# Reproducibility: generate_postexport_example() reproduces the distributed
# objects exactly on the platform that generated them (macOS arm64,
# R 4.6.0). Elsewhere the deterministic ODE part (deSolve lsoda) and hence
# the values may differ at the level of floating-point rounding.
#
# Design: one cell of the manuscript's corrected factorial benchmark. It was
# chosen from the benchmark table, before any data were generated, as the
# SHUTOFF design with at most 10 time points and 5 replicates whose Type-I
# error interval contains 0.05 and whose power at alpha = 0.05 is highest
# (about 0.24; Type-I error 0.042). Most simulated alternative events are
# therefore not expected to reach significance.
#   - regime SHUTOFF at the common intervention time t_star = 332 min;
#   - sampling at t_star - 10, t_star, +10, +20, +30 min;
#   - 5 destructive replicates per time point;
#   - replicate-level rate variability param_cv = 0.05;
#   - RNA-seq assay noise at level "very_low";
#   - integration grid origin 0, grid_step 1, horizon 1000, y0 = 0.
#
# Parameters: drawn once per event from the manuscript benchmark ranges:
#   - tau 0.006-0.06, tau_s 0.003-0.03, alpha 0.03-0.69,
#     alpha_s 0.01-min(alpha, 0.23), sigma_n 0.05-0.2;
#   - sigma_c 0.05-0.2 under the alternative;
#   - R ~ Gamma(shape 5, scale 20);
#   - onset a uniform integer in [-100, 100].
# Events alt_1..alt_4 have sigma_c > 0; null_1..null_4 have sigma_c = 0.
# The seed 20260925 was fixed a priori, and neither the design nor the data
# were chosen by searching over seeds. The draws reproduce the benchmark's
# parameter distributions, not its per-gene random streams.
# =============================================================================

generate_postexport_example <- function() {
    SEED <- 20260925L
    T_STAR <- 332
    TIMES <- T_STAR + c(-10, 0, 10, 20, 30)
    N_REP <- 5L
    NOISE <- list(platform = "rnaseq", level = "very_low")

    draw_params <- function(alternative) {
        alpha <- stats::runif(1, 0.03, 0.69)
        c(R = stats::rgamma(1, shape = 5, scale = 20),
          tau = stats::runif(1, 0.006, 0.06),
          tau_s = stats::runif(1, 0.003, 0.03),
          sigma_c = if (alternative) stats::runif(1, 0.05, 0.2) else 0,
          sigma_n = stats::runif(1, 0.05, 0.2),
          alpha = alpha,
          alpha_s = stats::runif(1, 0.01, min(alpha, 0.23)))
    }

    # The generator draws from the global stream after set.seed(SEED); the
    # caller's random-number state is restored on exit.
    old_seed <- if (exists(".Random.seed", envir = globalenv())) {
        get(".Random.seed", envir = globalenv())
    } else {
        NULL
    }
    on.exit({
        if (is.null(old_seed)) {
            if (exists(".Random.seed", envir = globalenv())) {
                rm(".Random.seed", envir = globalenv())
            }
        } else {
            assign(".Random.seed", old_seed, envir = globalenv())
        }
    })
    set.seed(SEED)
    events <- c(paste0("alt_", 1:4), paste0("null_", 1:4))
    truth <- vector("list", length(events))
    obs <- vector("list", length(events))
    for (i in seq_along(events)) {
        alternative <- startsWith(events[i], "alt")
        p <- draw_params(alternative)
        onset <- sample(-100:100, 1)
        sim_seed <- SEED + i
        sim <- postexportKinetics::simulate_postexport_kinetics(
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

    example <- do.call(rbind, obs)
    example <- example[, c("event", "time", "replicate",
                           "N", "N_s", "C", "C_s")]
    example$replicate <- as.integer(example$replicate)
    example <- example[order(match(example$event, events), example$time,
                             example$replicate), ]
    rownames(example) <- NULL
    truth <- do.call(rbind, truth)
    rownames(truth) <- NULL

    long <- do.call(rbind, lapply(
        list(c("N", "nuclear", "unprocessed"),
             c("N_s", "nuclear", "processed"),
             c("C", "cytoplasmic", "unprocessed"),
             c("C_s", "cytoplasmic", "processed")),
        function(m) {
            data.frame(example[, c("event", "time", "replicate")],
                       compartment = m[2], state = m[3],
                       abundance = example[[m[1]]])
        }))
    long <- long[order(match(long$event, events), long$time,
                       long$replicate), ]
    rownames(long) <- NULL

    stopifnot(!anyNA(example), identical(nrow(example), 8L * 5L * 5L))
    list(postexport_example = example, postexport_example_truth = truth,
         postexport_example_long = long)
}

write_postexport_example <- function(out_dir) {
    x <- generate_postexport_example()
    dir.create(file.path(out_dir, "data"), recursive = TRUE,
               showWarnings = FALSE)
    dir.create(file.path(out_dir, "inst", "extdata"), recursive = TRUE,
               showWarnings = FALSE)
    postexport_example <- x$postexport_example
    postexport_example_truth <- x$postexport_example_truth
    save(postexport_example,
         file = file.path(out_dir, "data", "postexport_example.rda"),
         compress = "xz", version = 2)
    save(postexport_example_truth,
         file = file.path(out_dir, "data", "postexport_example_truth.rda"),
         compress = "xz", version = 2)
    utils::write.csv(x$postexport_example_long,
                     file.path(out_dir, "inst", "extdata",
                               "postexport_example_long.csv"),
                     row.names = FALSE)
    invisible(out_dir)
}

if (!interactive() && sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    out <- if (length(args)) args[1] else tempfile("postexport_example-")
    write_postexport_example(out)
    cat("Example data written to", normalizePath(out), "\n")
}
