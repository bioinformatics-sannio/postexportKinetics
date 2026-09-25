# =============================================================================
# Public simulation API: simulate_postexport_kinetics()
#
# Composes the verbatim ports of the frozen simulator (R/ode.R) and assay
# models (R/assay.R) in a fixed, documented order. The reference composition
# of the frozen functions is tools/frozen/frozen_compositions.R; regression
# tests assert equality with it.
# =============================================================================

# Replicate-level random draws follow this list order (frozen benchmark
# generator, gen_synthetic_ODE_states_corrected_onset.R:331-392).
.FROZEN_PARAM_LIST_ORDER <- c("tau", "tau_s", "alpha", "alpha_s", "sigma_n",
                              "sigma_c", "R")

.NOISE_PLATFORMS <- c(gaussian = "GAUSS", rnaseq = "RNA-seq",
                      rtqpcr = "RT-qPCR")
.NOISE_LEVELS <- c(very_low = "Very low", low = "Low", medium = "Medium",
                   high = "High")

# Descriptive copy of the frozen benchmark presets
# (run_benchmark_main_corrected_onset_revision.R:469-474, 538-645); the
# simulation itself calls the ported add_platform_noise_main().
.noise_settings <- function(platform, level) {
    lv <- .NOISE_LEVELS[[level]]
    switch(platform,
        gaussian = list(model = "Gaussian, sd proportional to the signal",
                        noise_sd = unname(RANGE_GAUSS_NOISE[lv])),
        rtqpcr = list(
            model = "Poisson copies, Gaussian Ct noise, detection limit",
            ct_sd = c("Very low" = 0.01, "Low" = 0.05, "Medium" = 0.10,
                      "High" = 0.25)[[lv]],
            scale_copies = c("Very low" = 20, "Low" = 15, "Medium" = 10,
                             "High" = 5)[[lv]],
            ct_intercept = 35, lod_ct = 40),
        rnaseq = list(
            model = "negative-binomial counts, one dispersion per state",
            scale_counts = c("Very low" = 10000, "Low" = 5000,
                             "Medium" = 1000, "High" = 200)[[lv]],
            mean_disp = c("Very low" = 0.01, "Low" = 0.05, "Medium" = 0.10,
                          "High" = 0.25)[[lv]] * 0.25,
            cv_disp = c("Very low" = 0.5, "Low" = 0.7, "Medium" = 0.8,
                        "High" = 1.0)[[lv]])
    )
}


#' Simulate compartment-resolved post-export RNA kinetics
#'
#' Simulates the four-state model (nuclear unprocessed `N`, nuclear processed
#' `N_s`, cytoplasmic unprocessed `C`, cytoplasmic processed `C_s`) with the
#' frozen manuscript simulator: deterministic latent trajectories, optional
#' replicate-level biological variability and optional assay noise.
#'
#' @section Model:
#' \deqn{dN/dt = R(t) - (\sigma_n + \tau) N,\quad
#'       dN_s/dt = \sigma_n N - \tau_s N_s,}
#' \deqn{dC/dt = \tau N - (\sigma_c + \alpha) C,\quad
#'       dC_s/dt = \tau_s N_s + \sigma_c C - \alpha_s C_s.}
#' `sigma_c` is a phenomenological post-export conversion rate. Simulating
#' with `sigma_c > 0` generates data from this kinetic model; it does not
#' represent or establish any molecular mechanism.
#'
#' @section Timing semantics:
#' All times are on one experimental axis, in `time_unit`.
#' \itemize{
#'   \item `onset_time` is the (gene-specific) transcriptional onset:
#'     `R(t) = 0` before it. It may lie before `origin`; the history from
#'     `onset_time` to `origin` is then integrated first.
#'   \item `t_star` is the common intervention (shutoff) time. It is not
#'     shifted by the onset: changing `onset_time` changes only the
#'     transcriptional history before the intervention. No time shift is drawn
#'     internally.
#'   \item Transcription schedule (right-continuous): `R(t) = 0` for
#'     `t < onset_time`; `R` for `onset_time <= t < t_star`; and, from
#'     `t_star` on, `0` (`"SHUTOFF"`), `residual_fraction * R`
#'     (`"PSEUDO_SHUTOFF"`); `"NONE"` keeps `R` throughout.
#'   \item `y0` is the state at `min(onset_time, origin)`. The trajectory is
#'     integrated between consecutive points of the grid
#'     `seq(origin, horizon, by = grid_step)` (plus the sampling times and
#'     `t_star`) with [deSolve::ode()] (method `lsoda`, default tolerances),
#'     with onset and `t_star` as breakpoints. The manuscript benchmark used
#'     `origin = 0`, `grid_step = 1`, `horizon = 1000` and `y0 = 0`. The
#'     grid determines the integration intervals (and so values at the level
#'     of the solver tolerance) but not the model.
#' }
#'
#' @section Replicates and noise:
#' With `n_replicates > 1` and `param_cv > 0`, each replicate multiplies every
#' kinetic rate by an independent log-normal factor with coefficient of
#' variation `param_cv` (`R` is kept fixed), as in the frozen simulator; the
#' manuscript benchmark used `param_cv = 0.05` and 3, 5 or 10 replicates.
#' Replicates are independent destructive samples. `noise` adds assay noise
#' to the sampled states with the benchmark presets:
#' `platform` one of `"gaussian"`, `"rnaseq"`, `"rtqpcr"` and `level` one of
#' `"very_low"`, `"low"`, `"medium"`, `"high"` (benchmark labels GAUSS,
#' RNA-seq, RT-qPCR and Very low, Low, Medium, High). Gaussian noise can give
#' negative values (not truncated); RT-qPCR output is on the `2^-Ct` scale.
#'
#' @section Manuscript benchmark settings:
#' The defaults (`n_replicates = 1`, `param_cv = 0`, `noise = NULL`) give a
#' deterministic latent trajectory. The manuscript's corrected factorial
#' benchmark used `param_cv = 0.05`, 3, 5 or 10 replicates, `origin = 0`,
#' `grid_step = 1`, `horizon = 1000`, `y0 = 0`, a common `t_star = 332`,
#' gene-specific onsets between -100 and 100 and the benchmark noise presets.
#' Its per-gene and per-stream seeding is not reproduced by this function.
#'
#' @section Vocabulary:
#' Noise platforms and levels map one to one to the manuscript benchmark
#' labels: `gaussian` = GAUSS, `rnaseq` = RNA-seq, `rtqpcr` = RT-qPCR;
#' `very_low` = Very low, `low` = Low, `medium` = Medium, `high` = High.
#'
#' @section Random numbers and reproducibility:
#' Random numbers are drawn in this order: per replicate, one normal draw for
#' each of `tau, tau_s, alpha, alpha_s, sigma_n, sigma_c, R` (the draw for `R`
#' is discarded, as in the frozen simulator); then the assay noise for the
#' states `N, C, C_s, N_s`. No draws are made when `param_cv = 0` and
#' `noise = NULL`. With an explicit `seed`, [set.seed()] is called first and
#' the caller's random-number state is restored afterwards; with
#' `seed = NULL` the global stream is used and consumed. ODE integration
#' (compiled `lsoda`) can differ across platforms at the level of
#' floating-point rounding; random draws are generated by R itself.
#'
#' @param params Named numeric vector or list with the seven kinetic
#'   parameters `R, tau, tau_s, sigma_c, sigma_n, alpha, alpha_s` (finite,
#'   non-negative). Names are required; unnamed vectors are not accepted.
#' @param times Sampling times (finite, distinct, `>= origin`); returned in
#'   increasing order.
#' @param onset_time Transcriptional onset time (single finite number).
#' @param t_star Intervention time: a single finite number for `"SHUTOFF"`
#'   and `"PSEUDO_SHUTOFF"`, `NULL` for `"NONE"`. Must be supplied
#'   explicitly.
#' @param regime Transcriptional regime: `"NONE"` (continuous transcription),
#'   `"SHUTOFF"` (complete shutoff at `t_star`) or `"PSEUDO_SHUTOFF"`
#'   (residual transcription after `t_star`). Must be supplied explicitly.
#' @param time_unit Character string naming the time unit (rates are per
#'   this unit).
#' @param residual_fraction For `"PSEUDO_SHUTOFF"` only: fraction of `R`
#'   remaining after `t_star`, in `(0, 1]` (the manuscript robustness
#'   analysis used 0.05 to 1).
#' @param n_replicates Number of biological replicates (destructive samples
#'   per time point); default `1`.
#' @param param_cv Coefficient of variation of the replicate-level rate
#'   multipliers; default `0` (deterministic replicates).
#' @param noise `NULL` (no assay noise; default) or a list with elements
#'   `platform` and `level` (see *Replicates and noise*).
#' @param y0 Named initial state `c(N =, N_s =, C =, C_s =)` (finite,
#'   non-negative); default all zero.
#' @param origin Start of the simulation grid; default `0`.
#' @param grid_step Integration grid spacing; default `1`.
#' @param horizon End of the integration grid (`>= max(times)`); default
#'   `max(times)`. A numerical-reproducibility parameter of the integration
#'   grid, not a biological parameter: it does not change the model, only
#'   where the grid ends (and hence, at the level of the solver tolerance,
#'   the integration intervals).
#' @param seed `NULL` or a single whole number.
#' @param event Event label used in the returned tables.
#'
#' @return An object of class `postexport_simulation`, a list with
#'   \describe{
#'     \item{`latent`}{deterministic (noise-free) states on the integration
#'       grid for each replicate: `event`, `replicate`, `time`, `N`, `N_s`,
#'       `C`, `C_s` and the transcription rate `R` in force.}
#'     \item{`sampled`}{latent states at the sampling times.}
#'     \item{`observed`}{noisy observations at the sampling times (`event`,
#'       `time`, `replicate`, `N`, `N_s`, `C`, `C_s`), or `NULL` without
#'       `noise`; can be passed to [postexport_data()].}
#'     \item{`params`, `replicate_parameters`, `steady_state`}{base
#'       parameters, per-replicate parameters and the closed-form steady state
#'       under constant transcription.}
#'     \item{`timing`}{regime, `onset_time`, `t_star`, `residual_fraction`,
#'       post-intervention transcription fraction, `origin`, `grid_step`,
#'       sampling times.}
#'     \item{`replication`, `noise`, `y0`, `rng`, `time_unit`,
#'       `provenance`}{design, noise settings, random-number metadata and the
#'       frozen reference.}
#'   }
#'
#' @seealso [postexport_data()], [test_postexport_conversion()]
#'
#' @examples
#' p <- c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,
#'        alpha = 0.2, alpha_s = 0.08)
#' sim <- simulate_postexport_kinetics(
#'     p, times = c(90, 100, 110, 130, 160), onset_time = 0, t_star = 100,
#'     regime = "SHUTOFF", time_unit = "min", n_replicates = 3,
#'     param_cv = 0.05, noise = list(platform = "gaussian", level = "low"),
#'     origin = 0, grid_step = 1, seed = 1
#' )
#' sim
#' head(sim$observed)
#'
#' @export
simulate_postexport_kinetics <- function(params, times, onset_time, t_star,
                                         regime, time_unit,
                                         residual_fraction = NULL,
                                         n_replicates = 1L, param_cv = 0,
                                         noise = NULL,
                                         y0 = c(N = 0, N_s = 0, C = 0, C_s = 0),
                                         origin = 0, grid_step = 1,
                                         horizon = NULL, seed = NULL,
                                         event = "simulated") {
    if (missing(t_star)) {
        stop("'t_star' must be supplied explicitly (NULL for regime ",
             "\"NONE\").", call. = FALSE)
    }
    absent <- c(params = missing(params), times = missing(times),
                onset_time = missing(onset_time), regime = missing(regime),
                time_unit = missing(time_unit))
    if (any(absent)) {
        stop(sprintf("Argument(s) must be supplied explicitly: %s.",
                     toString(names(absent)[absent])), call. = FALSE)
    }
    a <- .validate_simulation(params, times, onset_time, t_star, regime,
                              time_unit, residual_fraction, n_replicates,
                              param_cv, noise, y0, origin, grid_step, horizon,
                              seed, event)
    rng_before <- if (is.null(seed) &&
                      exists(".Random.seed", envir = globalenv())) {
        get(".Random.seed", envir = globalenv())
    } else {
        NULL
    }
    out <- .with_caller_rng(!is.null(seed), .simulate_composition(a))
    .new_simulation(a, out, rng_before)
}

.validate_simulation <- function(params, times, onset_time, t_star, regime,
                                 time_unit, residual_fraction, n_replicates,
                                 param_cv, noise, y0, origin, grid_step,
                                 horizon, seed, event) {
    is_num1 <- function(v) is.numeric(v) && length(v) == 1L && is.finite(v)
    if (is.list(params)) {
        if (!all(vapply(params, is_num1, logical(1)))) {
            stop("'params' must contain single finite numbers.",
                 call. = FALSE)
        }
        params <- unlist(params)
    }
    if (!is.numeric(params) || is.null(names(params)) ||
        any(!nzchar(names(params)))) {
        stop("'params' must be a named numeric vector or list with ",
             "R, tau, tau_s, sigma_c, sigma_n, alpha, alpha_s; unnamed ",
             "vectors are not accepted.", call. = FALSE)
    }
    missing_p <- setdiff(PARAM_NAMES, names(params))
    extra_p <- setdiff(names(params), PARAM_NAMES)
    if (length(missing_p) || length(extra_p) || anyDuplicated(names(params))) {
        stop("'params' must have exactly the names ", toString(PARAM_NAMES),
             " (missing: ",
             if (length(missing_p)) toString(missing_p) else "none",
             "; unknown: ",
             if (length(extra_p)) toString(extra_p) else "none", ").",
             call. = FALSE)
    }
    params <- params[PARAM_NAMES]
    if (any(!is.finite(params)) || any(params < 0)) {
        stop("Kinetic parameters must be finite and non-negative.",
             call. = FALSE)
    }
    regime_ok <- c("NONE", "SHUTOFF", "PSEUDO_SHUTOFF")
    if (!is.character(regime) || length(regime) != 1L ||
        !regime %in% regime_ok) {
        stop("'regime' must be one of \"NONE\", \"SHUTOFF\", ",
             "\"PSEUDO_SHUTOFF\".", call. = FALSE)
    }
    if (!is.character(time_unit) || length(time_unit) != 1L ||
        is.na(time_unit) || !nzchar(time_unit)) {
        stop("'time_unit' must be a single non-empty character string.",
             call. = FALSE)
    }
    if (!is_num1(origin)) stop("'origin' must be a finite number.",
                               call. = FALSE)
    if (!is_num1(grid_step) || grid_step <= 0) {
        stop("'grid_step' must be a positive number.", call. = FALSE)
    }
    if (!is.numeric(times) || !length(times) || any(!is.finite(times))) {
        stop("'times' must be finite numbers.", call. = FALSE)
    }
    if (anyDuplicated(times)) {
        stop("'times' must be distinct.", call. = FALSE)
    }
    if (any(times < origin)) {
        stop("'times' must be >= 'origin'.", call. = FALSE)
    }
    times <- sort(times)
    if (is.null(horizon)) horizon <- max(times)
    if (!is_num1(horizon) || horizon < max(times)) {
        stop("'horizon' must be NULL or a finite number >= max(times).",
             call. = FALSE)
    }
    if (!is_num1(onset_time)) {
        stop("'onset_time' must be a single finite number.", call. = FALSE)
    }
    if (regime == "NONE") {
        if (!is.null(t_star)) {
            stop("Regime \"NONE\" requires t_star = NULL.", call. = FALSE)
        }
    } else if (!is_num1(t_star)) {
        stop(sprintf("Regime \"%s\" requires a single finite 't_star'.",
                     regime), call. = FALSE)
    }
    if (regime == "PSEUDO_SHUTOFF") {
        if (!is_num1(residual_fraction) || residual_fraction <= 0 ||
            residual_fraction > 1) {
            stop("Regime \"PSEUDO_SHUTOFF\" requires 'residual_fraction' ",
                 "in (0, 1].", call. = FALSE)
        }
    } else if (!is.null(residual_fraction)) {
        stop("'residual_fraction' applies only to regime ",
             "\"PSEUDO_SHUTOFF\".", call. = FALSE)
    }
    if (!is_num1(n_replicates) || n_replicates < 1 ||
        n_replicates != round(n_replicates)) {
        stop("'n_replicates' must be a positive whole number.", call. = FALSE)
    }
    if (!is_num1(param_cv) || param_cv < 0) {
        stop("'param_cv' must be a finite number >= 0.", call. = FALSE)
    }
    if (!is.null(noise)) {
        if (!is.list(noise) ||
            !setequal(names(noise), c("platform", "level")) ||
            !isTRUE(noise$platform %in% names(.NOISE_PLATFORMS)) ||
            !isTRUE(noise$level %in% names(.NOISE_LEVELS))) {
            stop("'noise' must be NULL or list(platform = ",
                 "\"gaussian\"|\"rnaseq\"|\"rtqpcr\", level = ",
                 "\"very_low\"|\"low\"|\"medium\"|\"high\").", call. = FALSE)
        }
    }
    if (!is.numeric(y0) || !setequal(names(y0), KINETIC_VARS) ||
        length(y0) != 4L || any(!is.finite(y0)) || any(y0 < 0)) {
        stop("'y0' must be a named numeric vector c(N =, N_s =, C =, ",
             "C_s =) with finite non-negative values.", call. = FALSE)
    }
    if (!is.null(seed) && (!is_num1(seed) || seed != round(seed))) {
        stop("'seed' must be NULL or a single whole number.", call. = FALSE)
    }
    if (!is.character(event) || length(event) != 1L || is.na(event)) {
        stop("'event' must be a single character string.", call. = FALSE)
    }
    if (!is.null(t_star)) {
        if (t_star < onset_time) {
            warning("t_star is before onset_time: the intervention precedes ",
                    "the transcriptional onset.", call. = FALSE)
        }
        if (t_star > max(times)) {
            warning("t_star is after the last sampling time: no sample ",
                    "follows the intervention.", call. = FALSE)
        }
    }
    if (n_replicates > 1 && param_cv == 0 && is.null(noise)) {
        warning("n_replicates > 1 with param_cv = 0 and no noise gives ",
                "identical replicates.", call. = FALSE)
    }
    list(params = params, regime = regime, times = times,
         grid = seq(origin, horizon, by = grid_step),
         onset_time = onset_time, t_star = t_star,
         residual_fraction = residual_fraction, y0 = y0[KINETIC_VARS],
         n_replicates = as.integer(n_replicates), param_cv = param_cv,
         seed = seed,
         noise_platform = if (is.null(noise)) NULL else
             .NOISE_PLATFORMS[[noise$platform]],
         noise_level = if (is.null(noise)) NULL else
             .NOISE_LEVELS[[noise$level]],
         noise = noise, time_unit = time_unit, origin = origin,
         grid_step = grid_step, horizon = horizon, event = event)
}

# Same composition, statement for statement, as frozen_simulation() in
# tools/frozen/frozen_compositions.R, on the ported functions.
.simulate_composition <- function(a) {
    if (!is.null(a$seed)) set.seed(a$seed)
    base <- as.list(a$params[.FROZEN_PARAM_LIST_ORDER])
    post <- switch(a$regime, NONE = 1, SHUTOFF = 0,
                   PSEUDO_SHUTOFF = a$residual_fraction)
    g <- generate_ODE_states(
        base_params = base,
        y0 = a$y0,
        times = a$grid,
        n_replicates = a$n_replicates,
        model_kinetics = rna_kinetics,
        param_cv = a$param_cv,
        stimes = a$times,
        shutofftimes = a$times,
        max_shift = 0,
        t_star = if (a$regime == "NONE") NULL else a$t_star,
        post_R_fraction = post,
        use_onset_shift = FALSE,
        nominal_onset_time = a$onset_time
    )
    if (a$regime == "NONE") {
        latent <- g$data
        sampled <- g$tsampled_data
    } else {
        latent <- g$intervention_data
        sampled <- g$intervention_tsampled_data
    }
    observed <- NULL
    if (!is.null(a$noise_platform)) {
        observed <- as.data.frame(add_platform_noise_main(
            sampled, a$noise_platform, a$noise_level))
    }
    list(latent = latent, sampled = sampled, observed = observed,
         parameters = g$parameters, ss_data = g$ss_data,
         onset_time = g$onset_time, t_star = g$t_star,
         post_R_fraction = g$post_R_fraction)
}

.with_event <- function(tab, event, cols) {
    out <- data.frame(event = rep(event, nrow(tab)), stringsAsFactors = FALSE)
    for (cl in cols) out[[cl]] <- tab[[cl]]
    rownames(out) <- NULL
    out
}

.new_simulation <- function(a, out, rng_before) {
    state_cols <- c("time", "replicate", KINETIC_VARS, "R")
    obs_cols <- c("time", "replicate", KINETIC_VARS)
    structure(
        list(
            event = a$event,
            time_unit = a$time_unit,
            latent = .with_event(out$latent, a$event, state_cols),
            sampled = .with_event(out$sampled, a$event, state_cols),
            observed = if (is.null(out$observed)) NULL else
                .with_event(out$observed, a$event, obs_cols),
            params = a$params,
            replicate_parameters = out$parameters,
            steady_state = out$ss_data,
            timing = list(regime = a$regime, onset_time = out$onset_time,
                          t_star = out$t_star,
                          residual_fraction = a$residual_fraction,
                          post_R_fraction = out$post_R_fraction,
                          origin = a$origin, grid_step = a$grid_step,
                          horizon = a$horizon, sampling_times = a$times),
            replication = list(n_replicates = a$n_replicates,
                               param_cv = a$param_cv),
            noise = if (is.null(a$noise)) NULL else
                c(list(platform = a$noise$platform, level = a$noise$level,
                       benchmark_platform = a$noise_platform,
                       benchmark_level = a$noise_level),
                  .noise_settings(a$noise$platform, a$noise$level)),
            y0 = a$y0,
            rng = list(
                seed = a$seed,
                kind = RNGkind(),
                random_seed_before = rng_before,
                draw_order = paste(
                    "per replicate: tau, tau_s, alpha, alpha_s, sigma_n,",
                    "sigma_c, R multipliers (R draw discarded); then assay",
                    "noise for N, C, C_s, N_s"),
                note = if (is.null(a$seed)) {
                    "seed = NULL: the global random-number stream was consumed"
                } else {
                    paste("set.seed(seed) was called first; the caller's",
                          "random-number state was restored afterwards")
                }
            ),
            provenance = .provenance()
        ),
        class = "postexport_simulation"
    )
}

#' @export
print.postexport_simulation <- function(x, ...) {
    tm <- x$timing
    cat("<postexport_simulation> event:", x$event, "\n")
    cat("  Regime      :", tm$regime,
        if (identical(tm$regime, "PSEUDO_SHUTOFF"))
            sprintf("(residual fraction %s)", .fmt(tm$residual_fraction))
        else "", "\n")
    cat(sprintf("  Timing      : onset_time = %s, t_star = %s %s\n",
                .fmt(tm$onset_time),
                if (is.null(tm$t_star)) "NULL" else .fmt(tm$t_star),
                x$time_unit))
    cat(sprintf(paste0("  Sampling    : %d time points (%s), ",
                       "%d replicate(s), param_cv = %s\n"),
                length(tm$sampling_times), .fmt(tm$sampling_times),
                x$replication$n_replicates, .fmt(x$replication$param_cv)))
    cat("  Noise       :", if (is.null(x$noise)) "none (latent states only)"
        else sprintf("%s, %s", x$noise$platform, x$noise$level), "\n")
    cat(sprintf(paste0("  sigma_c     : %s %s^-1 (phenomenological; ",
                       "simulated data do not establish a mechanism)\n"),
                .fmt(x$params[["sigma_c"]]), x$time_unit))
    cat("  Tables      : $latent (", nrow(x$latent), " rows), $sampled (",
        nrow(x$sampled), " rows), $observed (",
        if (is.null(x$observed)) "NULL" else paste(nrow(x$observed), "rows"),
        ")\n", sep = "")
    invisible(x)
}

#' @export
summary.postexport_simulation <- function(object, ...) {
    structure(list(object = object), class = "summary.postexport_simulation")
}

#' @export
print.summary.postexport_simulation <- function(x, ...) {
    o <- x$object
    tm <- o$timing
    cat("Post-export kinetics simulation - event:", o$event, "\n\n")
    cat("Kinetic parameters (rates per ", o$time_unit, ")\n", sep = "")
    print(data.frame(parameter = PARAM_NAMES,
                     value = vapply(o$params, .fmt, character(1)),
                     row.names = NULL), row.names = FALSE, right = FALSE)
    cat("\nTiming (", o$time_unit, ")\n", sep = "")
    cat("  regime:", tm$regime, "\n")
    cat("  transcriptional onset:", .fmt(tm$onset_time), "\n")
    cat("  intervention t_star:",
        if (is.null(tm$t_star)) "NULL (no intervention)" else .fmt(tm$t_star),
        "\n")
    cat("  transcription fraction after t_star:", .fmt(tm$post_R_fraction),
        "\n")
    cat("  simulation origin / grid step / horizon:", .fmt(tm$origin), "/",
        .fmt(tm$grid_step), "/", .fmt(tm$horizon), "\n")
    cat("  initial state y0 (at min(onset, origin)):", .fmt(o$y0), "\n")
    cat("  sampling times:", .fmt(tm$sampling_times), "\n\n")
    cat("Replication: ", o$replication$n_replicates, " replicate(s); ",
        "param_cv = ", .fmt(o$replication$param_cv), "\n", sep = "")
    if (is.null(o$noise)) {
        cat("Noise: none\n")
    } else {
        nz <- o$noise[setdiff(names(o$noise), c("platform", "level"))]
        cat("Noise: ", o$noise$platform, ", ", o$noise$level, " (",
            paste(names(nz), vapply(nz, .fmt, character(1)), sep = " = ",
                  collapse = "; "), ")\n", sep = "")
    }
    cat("Reproducibility: seed =", .fmt(o$rng$seed), ";", o$rng$note, "\n")
    cat("  draw order:", o$rng$draw_order, "\n")
    cat("Frozen reference:", o$provenance$frozen_tag,
        substr(o$provenance$frozen_commit, 1, 12), "\n\n")
    cat(strwrap(paste(
        "sigma_c is a phenomenological post-export conversion rate. Data",
        "simulated from the kinetic model do not establish any molecular",
        "mechanism."), width = 78), sep = "\n")
    invisible(x)
}
