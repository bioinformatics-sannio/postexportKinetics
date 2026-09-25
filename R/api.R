# =============================================================================
# Public inference API: fit_postexport_model() and test_postexport_conversion()
#
# fit_postexport_model() reproduces the observed phase of the frozen
# orchestration (commons/nested_test2.r:1510-1632 and the IR / boundary
# tolerance expressions at 1945-2018) without the bootstrap.
# test_postexport_conversion() calls the verbatim port test_sigma_nested()
# and wraps its frozen result list; reported fit values come from that list.
# Events are processed sequentially.
# =============================================================================

.FROZEN_REFERENCE <- list(
    tag = "manuscript-revision-v1.0",
    commit = "65c3b7368fb7686bfde3dab857f98c393bb534c5"
)

.INTERPRETATION <- paste(
    "sigma_c is a phenomenological post-export conversion rate within the",
    "four-state model. A small bootstrap p-value indicates kinetic evidence",
    "consistent with an additional post-export conversion component within",
    "the model; it does not identify a molecular mechanism."
)

.provenance <- function() {
    list(
        package = "postexportKinetics",
        package_version = as.character(utils::packageVersion(
            "postexportKinetics")),
        frozen_tag = .FROZEN_REFERENCE$tag,
        frozen_commit = .FROZEN_REFERENCE$commit
    )
}

.check_inputs <- function(data, t_star, t_star_missing, control, events) {
    if (!inherits(data, "postexport_data")) {
        stop("'data' must be a postexport_data object; create it with ",
             "postexport_data().", call. = FALSE)
    }
    if (t_star_missing) {
        stop("'t_star' must be supplied explicitly: the intervention ",
             "(transcriptional shutoff) time on the time axis of the data, ",
             "or NULL for continuous transcription without intervention.",
             call. = FALSE)
    }
    if (!is.null(t_star) &&
        (!is.numeric(t_star) || length(t_star) != 1L || !is.finite(t_star))) {
        stop("'t_star' must be NULL or a single finite number.", call. = FALSE)
    }
    if (!inherits(control, "postexport_control")) {
        stop("'control' must be created with postexport_control().",
             call. = FALSE)
    }
    all_events <- unique(data$event)
    if (is.null(events)) events <- all_events
    .check_event_names(events, all_events)
    events
}

.check_event_names <- function(events, all_events) {
    if (!is.character(events) || !length(events) || anyNA(events) ||
        anyDuplicated(events)) {
        stop("'events' must be NULL or a vector of distinct event names.",
             call. = FALSE)
    }
    absent <- setdiff(events, all_events)
    if (length(absent)) {
        stop(sprintf("Event(s) not found in 'data': %s.",
                     toString(utils::head(absent, 5L))), call. = FALSE)
    }
    invisible(TRUE)
}

# Design warnings about t_star (never blocking; inference is unchanged).
# Returns a named list of warning messages per event and emits them.
.t_star_warnings <- function(data, events, t_star) {
    out <- stats::setNames(vector("list", length(events)), events)
    if (is.null(t_star)) return(out)
    for (ev in events) {
        tt <- data$time[data$event == ev]
        acc <- new.env(parent = emptyenv())
        acc$msg <- character()
        .t_star_event(ev, min(tt), max(tt), t_star,
                      function(level, check, message, event) {
                          acc$msg <- c(acc$msg, message)
                      })
        out[[ev]] <- acc$msg
        for (m in acc$msg) warning(m, call. = FALSE)
    }
    out
}

.intervention_label <- function(t_star) {
    if (is.null(t_star)) {
        "continuous transcription (no intervention time)"
    } else {
        "transcriptional shutoff at t_star (complete shutoff assumed)"
    }
}

# Observed phase of the frozen orchestration, statement for statement
# (commons/nested_test2.r:1510-1632), plus the frozen IR and boundary
# tolerance expressions (lines 1945-1957 and 1998-2018).
.observed_fit <- function(d, t_star, control) {
    built <- tryCatch(
        build_Ab_fullcov(
            tsampled_data = d,
            scaling_A = control$scaling_A,
            t_star = t_star,
            lambda_time = control$lambda_time,
            lambda_diag = control$lambda_diag,
            rel_floor = control$rel_floor
        ),
        error = function(e) e
    )
    if (inherits(built, "error")) {
        return(list(status = "observed_system_failed",
                    error.message = conditionMessage(built)))
    }
    fit <- fit_nnls_nested_once(
        A = built$A,
        b = built$b,
        Sigma_b = built$Sigma_b,
        col_test = 4L,
        rel_floor = control$rel_floor
    )
    if (is.null(fit)) {
        return(list(status = "observed_fit_failed",
                    error.message = "Observed GLS-NNLS fit failed.",
                    built = built))
    }
    coef_full <- fit$coef_full_scaled / built$col_norms
    names(coef_full) <- PARAM_NAMES
    null_names <- PARAM_NAMES[-4L]
    coef_null_short <- fit$coef_null_scaled / built$col_norms[-4L]
    names(coef_null_short) <- null_names
    coef_null <- stats::setNames(rep(0, length(PARAM_NAMES)), PARAM_NAMES)
    coef_null[null_names] <- coef_null_short
    coef_null["sigma_c"] <- 0
    rss_scale <- max(1, abs(fit$RSS0), abs(fit$RSS1))
    tol_zero <- 1e-10 * rss_scale
    DeltaRSS <- max(fit$RSS0 - fit$RSS1, 0)
    IR <- if (is.finite(fit$RSS0) && fit$RSS0 > 0) {
        DeltaRSS / fit$RSS0
    } else {
        NA_real_
    }
    list(status = "ok", error.message = NULL, built = built, fit = fit,
         coef_full = coef_full, coef_null = coef_null, T.obs = fit$T,
         RSS0 = fit$RSS0, RSS1 = fit$RSS1, DeltaRSS = DeltaRSS, IR = IR,
         boundary.tolerance = tol_zero)
}

# Additional diagnostics (approved in review, SF-10). Computed alongside the
# fit; never used by the fit, the statistic or the p-value.
.extra_diagnostics <- function(built, rel_floor) {
    A <- built$A
    zero <- colSums(A != 0) == 0
    out <- list(structurally_zero_columns = colnames(A)[zero],
                condition_number_nonzero_columns = NA_real_)
    W12 <- inverse_sqrt_matrix(built$Sigma_b, rel_floor = rel_floor)
    if (!is.null(W12) && any(!zero)) {
        sv <- svd(W12 %*% A[, !zero, drop = FALSE])$d
        out$condition_number_nonzero_columns <- if (min(sv) > 0) {
            max(sv) / min(sv)
        } else {
            Inf
        }
    }
    out
}

.na_coef <- function() stats::setNames(rep(NA_real_, 7L), PARAM_NAMES)

.new_fit <- function(event, obs, t_star, control, time_unit, d = NULL) {
    ok <- identical(obs$status, "ok")
    built <- obs$built
    fit <- obs$fit
    extra <- if (!is.null(built)) {
        .extra_diagnostics(built, control$rel_floor)
    } else {
        list(structurally_zero_columns = character(),
             condition_number_nonzero_columns = NA_real_)
    }
    coef_full <- if (ok) obs$coef_full else .na_coef()
    structure(
        list(
            event = event,
            status = obs$status,
            error_message = obs$error.message,
            estimates = list(
                sigma_c = unname(coef_full["sigma_c"]),
                coef_full = coef_full,
                coef_null = if (ok) obs$coef_null else .na_coef()
            ),
            fit = list(
                RSS_null = if (ok) obs$RSS0 else NA_real_,
                RSS_full = if (ok) obs$RSS1 else NA_real_,
                T_obs = if (ok) obs$T.obs else NA_real_,
                delta_RSS = if (ok) obs$DeltaRSS else NA_real_,
                IR = if (ok) obs$IR else NA_real_
            ),
            boundary = list(
                tolerance = if (ok) obs$boundary.tolerance else NA_real_,
                at_boundary = if (ok) {
                    obs$T.obs <= obs$boundary.tolerance
                } else {
                    NA
                },
                sigma_c_zero = if (ok) {
                    abs(unname(coef_full["sigma_c"])) < 1e-12
                } else {
                    NA
                }
            ),
            diagnostics = c(
                list(
                    condition_number = if (!is.null(fit)) {
                        fit$condition_number
                    } else {
                        NA_real_
                    },
                    min_singular_value = if (!is.null(fit)) {
                        fit$min_singular_value
                    } else {
                        NA_real_
                    },
                    rank_full = if (!is.null(fit)) {
                        fit$rank_full
                    } else {
                        NA_integer_
                    },
                    rank_null = if (!is.null(fit)) {
                        fit$rank_null
                    } else {
                        NA_integer_
                    },
                    pooled_covariance = if (!is.null(built)) {
                        built$summary$pooled_cov
                    } else {
                        NULL
                    }
                ),
                extra
            ),
            design = list(
                t_star = t_star,
                time_unit = time_unit,
                intervention = .intervention_label(t_star),
                times = if (!is.null(built)) built$summary$times else NULL,
                n_replicates_by_time = if (!is.null(built)) {
                    built$summary$n_rep
                } else {
                    NULL
                }
            ),
            system = built,
            data = d,
            control = control,
            provenance = .provenance()
        ),
        class = "postexport_fit"
    )
}


#' Fit the full and null post-export kinetic models
#'
#' Fits, for each event, the full model (post-export conversion rate
#' `sigma_c >= 0`) and the constrained null model (`sigma_c = 0`) to
#' compartment-resolved time-course data, without bootstrap inference.
#'
#' @section Model:
#' Four kinetic states are required: nuclear unprocessed `N`, nuclear
#' processed `N_s`, cytoplasmic unprocessed `C` and cytoplasmic processed
#' `C_s`, with
#' \deqn{dN/dt = R - (\sigma_n + \tau) N,\quad
#'       dN_s/dt = \sigma_n N - \tau_s N_s,}
#' \deqn{dC/dt = \tau N - (\sigma_c + \alpha) C,\quad
#'       dC_s/dt = \tau_s N_s + \sigma_c C - \alpha_s C_s.}
#' Parameters are estimated in the order
#' `R, tau, tau_s, sigma_c, sigma_n, alpha, alpha_s` from trapezoidal
#' interval balances between consecutive time points. The measurement
#' covariance is estimated from replicates within time points (shrinkage and
#' eigenvalue floor as set by [postexport_control()]) and propagated to the
#' interval balances; both models are fitted by non-negative least squares
#' after whitening. The transcription input is active until `t_star` and
#' zero afterwards (complete shutoff).
#'
#' @section Interpretation:
#' `sigma_c` is a phenomenological post-export conversion rate from `C` to
#' `C_s`. A positive estimate does not identify a unique molecular mechanism
#' and is not, by itself, evidence of cytoplasmic splicing. The fitted values
#' depend on the experimental design; in particular the complete-shutoff
#' assumption matters for pseudo-shutoff data, which are fitted as if
#' transcription stopped completely at `t_star`.
#'
#' @section Boundary:
#' The statistic `T = max(0, RSS0 - RSS1)` is computed on the whitened scale.
#' The fit is on the boundary when `T <= 1e-10 * max(1, |RSS0|, |RSS1|)`
#' (frozen rule); [test_postexport_conversion()] then reports `p = 1`.
#'
#' @param data A `postexport_data` object.
#' @param t_star Intervention (transcriptional shutoff) time on the time axis
#'   of `data`, or `NULL` for continuous transcription. Must be supplied
#'   explicitly.
#' @param control A [postexport_control()] object. Only the covariance and
#'   fitting settings are used.
#' @param events Optional character vector of events to fit; default all.
#'
#' @return For one event, an object of class `postexport_fit` with elements
#'   \describe{
#'     \item{`event`, `status`, `error_message`}{Frozen status codes: `"ok"`,
#'       `"observed_system_failed"` or `"observed_fit_failed"`.}
#'     \item{`estimates`}{`sigma_c` (effect-size estimate), `coef_full`,
#'       `coef_null` (named, original scale; `sigma_c = 0` in the null).}
#'     \item{`fit`}{`RSS_null`, `RSS_full` (whitened), `T_obs`,
#'       `delta_RSS`, `IR` (relative RSS improvement `delta_RSS / RSS_null`).}
#'     \item{`boundary`}{`tolerance`, `at_boundary` (frozen rule),
#'       `sigma_c_zero` (`|sigma_c| < 1e-12`).}
#'     \item{`diagnostics`}{condition number and minimum singular value of the
#'       whitened full design, ranks of the full and null designs, pooled
#'       covariance, structurally zero design columns and the condition
#'       number over the remaining columns (diagnostic only).}
#'     \item{`design`}{`t_star`, `time_unit`, intervention, time points and
#'       replicates per time point.}
#'     \item{`system`}{the interval-balance system (`A`, `b`, `Sigma_b`,
#'       ...).}
#'     \item{`data`}{the event's input rows (used by
#'       [plot()][plot.postexport]).}
#'     \item{`control`, `provenance`}{settings and frozen reference.}
#'   }
#'   For several events, a `postexport_fit_set`: a list with `summary` (one
#'   row per event) and `results` (named list of `postexport_fit`). Events
#'   are processed sequentially; an unexpected error while processing one
#'   event is recorded as status `"event_error"` (with the message in
#'   `error_message`) and the remaining events are processed. See also
#'   [as.data.frame()][as.data.frame.postexport] for a tidy table.
#'
#' @seealso [test_postexport_conversion()], [postexport_data()],
#'   [postexport_control()]
#'
#' @examples
#' set.seed(1)
#' tab <- expand.grid(replicate = 1:3, time = c(-15, 0, 30, 60, 120))
#' tab$event <- "event_1"
#' tab$N <- 60 * exp(-0.03 * pmax(tab$time, 0)) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$N_s <- 20 * exp(-0.01 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C <- 25 * exp(-0.02 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C_s <- 40 * exp(-0.005 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' x <- postexport_data(tab, time_unit = "min")
#' fit <- fit_postexport_model(x, t_star = 0)
#' fit
#' summary(fit)
#'
#' @export
fit_postexport_model <- function(data, t_star, control = postexport_control(),
                                 events = NULL) {
    events <- .check_inputs(data, if (missing(t_star)) NULL else t_star,
                            missing(t_star), control, events)
    unit <- attr(data, "time_unit")
    design_warnings <- .t_star_warnings(data, events, t_star)
    one <- function(ev) {
        d <- .event_data(data, ev)
        obs <- .observed_fit(d, t_star, control)
        r <- .new_fit(ev, obs, t_star, control, unit, d)
        r$design$warnings <- design_warnings[[ev]]
        r
    }
    if (length(events) == 1L) return(one(events))
    res <- lapply(events, function(ev) {
        .event_or_error(one(ev), ev, function(msg) {
            .new_fit(ev, list(status = "event_error", error.message = msg),
                     t_star, control, unit, .event_data(data, ev))
        })
    })
    names(res) <- events
    .new_set(res, "postexport_fit_set", t_star, control, unit)
}


#' Test for an additional post-export conversion component
#'
#' Compares, for each event, the constrained null model (`sigma_c = 0`) with
#' the full model (`sigma_c >= 0`); the scientific alternative is
#' `sigma_c > 0`. The observed statistic `T = max(0, RSS0 - RSS1)` (whitened
#' non-negative least squares) is calibrated by a replicate-level generative
#' bootstrap under the fitted null model.
#'
#' @section Procedure:
#' The procedure is the frozen manuscript implementation (tag
#' `manuscript-revision-v1.0`), called unchanged:
#' \enumerate{
#'   \item interval-balance system and whitened NNLS fits of the full and
#'     null models (as in [fit_postexport_model()]);
#'   \item null mean trajectory by Crank-Nicolson propagation of the fitted
#'     null model from the observed mean at the first time point;
#'   \item `B` bootstrap datasets: at each time point, as many independent
#'     multivariate normal samples as observed replicates, around the null
#'     means, with the estimated within-time covariance;
#'   \item in every bootstrap dataset the means, covariances, interval
#'     balances and propagated covariance are rebuilt and both models are
#'     refitted, giving `T*`;
#'   \item if more than `max_failure_rate` of the replicates fail, the
#'     p-value is `NA` (status `"bootstrap_unstable"`);
#'   \item boundary rule: if `T <= 1e-10 * max(1, |RSS0|, |RSS1|)` the
#'     p-value is `1`; otherwise the add-one p-value
#'     `(1 + #{T* >= T}) / (B_valid + 1)`.
#' }
#' This is not a likelihood-ratio test: no likelihood is evaluated, and the
#' statistic is a difference of whitened residual sums of squares.
#'
#' @section Interpretation:
#' `sigma_c` is a phenomenological post-export conversion rate. A small
#' p-value indicates kinetic evidence consistent with an additional
#' post-export conversion component within the model; `sigma_c > 0` does not
#' identify a unique molecular mechanism and is not, by itself, evidence of
#' cytoplasmic splicing. Calibration of the bootstrap is design dependent
#' (sampling times relative to `t_star`, replication, noise), and
#' pseudo-shutoff data are fitted as if transcription stopped completely at
#' `t_star`. The p-value is the inferential quantity; `sigma_c` is an
#' effect-size estimate; neither is a ranking score. No multiple-testing
#' adjustment is applied: for several events, adjust the p-values
#' explicitly, e.g. with [stats::p.adjust()].
#'
#' @section Reproducibility:
#' With a fixed `seed`, the bootstrap draws are reproducible within a matched
#' numerical environment (operating system, LAPACK/BLAS, R and package
#' versions). Across LAPACK/BLAS builds the draws, and hence Monte-Carlo
#' p-values, can differ even under the same seed, because the frozen
#' bootstrap uses [MASS::mvrnorm()]. With an explicit seed, the frozen
#' implementation calls [set.seed()] before the observed fit; the caller's
#' random-number state is saved before and restored after each event, so the
#' call does not alter it. With `seed = NULL`, the global random-number stream
#' is used and consumed, as in the frozen implementation.
#'
#' @inheritParams fit_postexport_model
#' @param control A [postexport_control()] object; `B` and `seed` control
#'   the bootstrap.
#'
#' @return For one event, an object of class
#'   `c("postexport_test", "postexport_fit")` with all elements of a
#'   `postexport_fit` (values taken from the frozen result) plus
#'   \describe{
#'     \item{`inference`}{`p_value` (bootstrap, one-sided), `B`,
#'       `n_bootstrap_valid`, `bootstrap_failure_rate`, `atom_zero`
#'       (fraction of `T*` at the boundary), `T_boot`, and descriptions of
#'       the statistic, alternative and method.}
#'     \item{`bootstrap_diagnostics`}{condition-number summaries and
#'       rank-deficient fraction over bootstrap replicates.}
#'     \item{`null_means`}{null mean trajectory used by the bootstrap.}
#'     \item{`rng`}{seed, `RNGkind()` and, for `seed = NULL`, the
#'       random-number state before the test.}
#'     \item{`raw`}{the complete frozen result list.}
#'   }
#'   Frozen status codes: `"ok"`, `"observed_system_failed"`,
#'   `"observed_fit_failed"`, `"null_trajectory_failed"`,
#'   `"bootstrap_unstable"`. For several events, a `postexport_test_set`
#'   with `summary` and `results`; events are processed sequentially and an
#'   unexpected per-event error is recorded as status `"event_error"`. Use
#'   [adjust_postexport_pvalues()] for q-values,
#'   [rank_postexport_candidates()] for exploratory ranking and
#'   [as.data.frame()][as.data.frame.postexport] for a tidy table.
#'
#' @seealso [fit_postexport_model()], [postexport_control()]
#'
#' @examples
#' set.seed(1)
#' tab <- expand.grid(replicate = 1:3, time = c(-15, 0, 30, 60, 120))
#' tab$event <- "event_1"
#' tab$N <- 60 * exp(-0.03 * pmax(tab$time, 0)) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$N_s <- 20 * exp(-0.01 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C <- 25 * exp(-0.02 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C_s <- 40 * exp(-0.005 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' x <- postexport_data(tab, time_unit = "min")
#' res <- test_postexport_conversion(
#'     x, t_star = 0, control = postexport_control(B = 19, seed = 1)
#' )
#' res
#'
#' @export
test_postexport_conversion <- function(data, t_star,
                                       control = postexport_control(),
                                       events = NULL) {
    events <- .check_inputs(data, if (missing(t_star)) NULL else t_star,
                            missing(t_star), control, events)
    seeds <- .event_seeds(control$seed, events)
    unit <- attr(data, "time_unit")
    design_warnings <- .t_star_warnings(data, events, t_star)
    one <- function(ev) {
        d <- .event_data(data, ev)
        seed <- seeds[[ev]]
        rng_before <- if (is.null(seed) &&
                          exists(".Random.seed", envir = globalenv())) {
            get(".Random.seed", envir = globalenv())
        } else {
            NULL
        }
        raw <- .with_caller_rng(!is.null(seed), test_sigma_nested(
            tsampled_data = d,
            scaling_A = control$scaling_A,
            t_star = t_star,
            B_n = control$B,
            seed = seed,
            lambda_time = control$lambda_time,
            lambda_diag = control$lambda_diag,
            rel_floor = control$rel_floor,
            truncate_nonnegative_boot = control$truncate_nonnegative_boot,
            max_failure_rate = control$max_failure_rate,
            return_boot = TRUE
        ))
        obs <- .observed_fit(d, t_star, control)
        r <- .new_test(ev, raw, obs, t_star, control, unit, seed, rng_before,
                       d)
        r$design$warnings <- design_warnings[[ev]]
        r
    }
    if (length(events) == 1L) return(one(events))
    res <- lapply(events, function(ev) {
        .event_or_error(one(ev), ev, function(msg) {
            fail <- list(status = "event_error", error.message = msg)
            .new_test(ev, c(list(p.value = NA_real_), fail), fail, t_star,
                      control, unit, seeds[[ev]], NULL, .event_data(data, ev))
        })
    })
    names(res) <- events
    .new_set(res, "postexport_test_set", t_star, control, unit)
}

# Public-API RNG hygiene (approved in review of PHASE2_REPORT.md): with an
# explicit seed, the frozen orchestrator still calls set.seed(seed) exactly as
# in the manuscript implementation, but the caller's random-number state is
# saved before and restored afterwards, so the call leaves the global state
# unchanged. The computed result is not affected. With seed = NULL the frozen
# behaviour is kept: the global stream is consumed and not restored.
.with_caller_rng <- function(restore, expr) {
    if (!restore) return(expr)
    genv <- globalenv()
    had_seed <- exists(".Random.seed", envir = genv, inherits = FALSE)
    saved <- if (had_seed) get(".Random.seed", envir = genv) else NULL
    on.exit({
        if (had_seed) {
            assign(".Random.seed", saved, envir = genv)
        } else if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
            rm(".Random.seed", envir = genv)
        }
    }, add = TRUE)
    expr
}

# Multi-event runs: an unexpected R error while processing one event is
# recorded as that event's status ("event_error") so that the remaining
# events are still processed. The frozen computation already converts its
# own failures into frozen status codes; this only guards the package layer.
# Single-event calls are not wrapped and behave exactly as before.
.event_or_error <- function(expr, event, make_failed) {
    tryCatch(expr, error = function(e) {
        make_failed(sprintf("Event %s: %s", event, conditionMessage(e)))
    })
}

.event_seeds <- function(seed, events) {
    out <- stats::setNames(vector("list", length(events)), events)
    if (is.null(seed)) return(out)
    if (length(seed) == 1L && is.null(names(seed))) {
        if (length(events) > 1L) {
            stop("A single seed would give every event the same bootstrap ",
                 "random-number stream. Supply one seed per event as a ",
                 "named vector, or seed = NULL.", call. = FALSE)
        }
        out[[1L]] <- seed
        return(out)
    }
    absent <- setdiff(events, names(seed))
    if (length(absent)) {
        stop(sprintf("No seed supplied for event(s): %s.",
                     toString(utils::head(absent, 5L))), call. = FALSE)
    }
    for (ev in events) out[[ev]] <- unname(seed[[ev]])
    out
}

.field <- function(raw, name, default) {
    v <- raw[[name]]
    if (is.null(v)) default else v
}

.new_test <- function(event, raw, obs, t_star, control, unit, seed,
                      rng_before, d = NULL) {
    base <- .new_fit(event, obs, t_star, control, unit, d)
    has_fit <- !is.null(raw$T.obs)
    coef_full <- .field(raw, "coef_full", base$estimates$coef_full)
    coef_null <- .field(raw, "coef_null", base$estimates$coef_null)
    base$status <- raw$status
    base$error_message <- raw$error.message
    base$estimates <- list(
        sigma_c = if (has_fit) unname(raw$Sigma) else NA_real_,
        coef_full = coef_full,
        coef_null = coef_null
    )
    base$fit <- list(
        RSS_null = .field(raw, "RSS0", NA_real_),
        RSS_full = .field(raw, "RSS1", NA_real_),
        T_obs = .field(raw, "T.obs", NA_real_),
        delta_RSS = base$fit$delta_RSS,
        IR = .field(raw, "IR", base$fit$IR)
    )
    tol <- .field(raw, "boundary.tolerance", base$boundary$tolerance)
    base$boundary <- list(
        tolerance = tol,
        at_boundary = if (has_fit) raw$T.obs <= tol else NA,
        sigma_c_zero = if (has_fit) abs(unname(raw$Sigma)) < 1e-12 else NA
    )
    frozen_names <- c(condition_number = "condition.number",
                      min_singular_value = "min.singular.value",
                      rank_full = "rank.full", rank_null = "rank.null")
    for (k in names(frozen_names)) {
        v <- raw[[frozen_names[[k]]]]
        if (!is.null(v)) base$diagnostics[[k]] <- v
    }
    base$inference <- list(
        p_value = raw$p.value,
        B = control$B,
        n_bootstrap_valid = .field(raw, "n.bootstrap.valid", NA_integer_),
        bootstrap_failure_rate = .field(raw, "bootstrap.failure.rate",
                                        NA_real_),
        atom_zero = .field(raw, "atom.zero", NA_real_),
        T_boot = raw$T.boot,
        statistic = paste("T = max(0, RSS0 - RSS1), whitened NNLS residual",
                          "sums of squares"),
        alternative = "sigma_c > 0 (null: sigma_c = 0; full: sigma_c >= 0)",
        method = paste("replicate-level generative bootstrap under the fitted",
                       "null model with reconstruction of the interval",
                       "system in every replicate; add-one p-value;",
                       "boundary rule p = 1")
    )
    base$bootstrap_diagnostics <- list(
        condition_median = .field(raw, "bootstrap.condition.median", NA_real_),
        condition_q95 = .field(raw, "bootstrap.condition.q95", NA_real_),
        condition_max = .field(raw, "bootstrap.condition.max", NA_real_),
        rank_deficient_fraction = .field(
            raw, "bootstrap.rank.deficient.fraction", NA_real_)
    )
    base$null_means <- raw$null.means
    base$rng <- list(
        seed = seed,
        kind = RNGkind(),
        random_seed_before = rng_before,
        note = if (is.null(seed)) {
            paste("seed = NULL: the global random-number stream was used and",
                  "consumed (not reset, not restored)")
        } else {
            paste("set.seed(seed) was called before the observed fit (frozen",
                  "behaviour); the caller's random-number state was restored",
                  "afterwards")
        }
    )
    base$raw <- raw
    class(base) <- c("postexport_test", "postexport_fit")
    base
}

.set_summary_row <- function(r) {
    row <- data.frame(
        event = r$event,
        status = r$status,
        sigma_c = r$estimates$sigma_c,
        IR = r$fit$IR,
        T_obs = r$fit$T_obs,
        RSS_null = r$fit$RSS_null,
        RSS_full = r$fit$RSS_full,
        at_boundary = r$boundary$at_boundary,
        condition_number = r$diagnostics$condition_number,
        rank_full = r$diagnostics$rank_full,
        stringsAsFactors = FALSE
    )
    if (inherits(r, "postexport_test")) {
        row$p_value <- r$inference$p_value
        row$B <- r$inference$B
        row$n_bootstrap_valid <- r$inference$n_bootstrap_valid
        row$bootstrap_failure_rate <- r$inference$bootstrap_failure_rate
        row$atom_zero <- r$inference$atom_zero
    }
    row
}

.new_set <- function(results, class, t_star, control, unit) {
    summary_tab <- do.call(rbind, lapply(results, .set_summary_row))
    rownames(summary_tab) <- NULL
    structure(
        list(summary = summary_tab, results = results, t_star = t_star,
             time_unit = unit, control = control, provenance = .provenance()),
        class = class
    )
}
