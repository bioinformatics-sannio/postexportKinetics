# Assisted-by: Claude Code (Anthropic)
# =============================================================================
# plot() methods (ggplot2). Plotting only reads result objects: it never
# modifies them, never refits and never runs inference. Fitted curves are
# display-only propagations of the fitted coefficients with the ported frozen
# ODE integrator (simulate_scheduled_trajectory()).
# =============================================================================

#' @importFrom ggplot2 .data
NULL

.STATE_LABELS <- c(N = "N (nuclear, unprocessed)",
                   N_s = "N_s (nuclear, processed)",
                   C = "C (cytoplasmic, unprocessed)",
                   C_s = "C_s (cytoplasmic, processed)")

# Colour-blind-safe (Okabe-Ito) colours; not manuscript-specific.
.PAL <- c(full = "#0072B2", null = "#D55E00", observed = "#7F7F7F",
          mean = "#000000", exact = "#0072B2", nearest = "#E69F00")

.state_factor <- function(x) {
    factor(unname(.STATE_LABELS[x]), levels = unname(.STATE_LABELS))
}

.long_states <- function(d, extra = character()) {
    do.call(rbind, lapply(KINETIC_VARS, function(s) {
        out <- data.frame(time = d$time, value = d[[s]],
                          state = .state_factor(s), stringsAsFactors = FALSE)
        for (e in extra) out[[e]] <- d[[e]]
        out
    }))
}

# Display-only trajectories of the fitted full and null models, propagated
# from the observed mean at the first time point, with transcription active
# until t_star (complete shutoff) as in the model.
.display_trajectories <- function(x, n = 200L) {
    times <- x$design$times
    if (length(times) < 2L || is.null(x$system)) return(NULL)
    x0 <- x$system$summary$means[1L, KINETIC_VARS]
    grid <- sort(unique(c(seq(min(times), max(times), length.out = n), times)))
    out <- list()
    models <- list(full = x$estimates$coef_full, null = x$estimates$coef_null)
    for (m in names(models)) {
        th <- models[[m]]
        if (any(!is.finite(th))) next
        tr <- tryCatch(
            simulate_scheduled_trajectory(
                y0 = x0, times = grid, params = as.list(th),
                onset_time = min(times), t_star = x$design$t_star,
                post_R_fraction = 0),
            error = function(e) NULL)
        if (is.null(tr)) next
        lt <- .long_states(tr)
        lt$model <- m
        out[[m]] <- lt
    }
    if (!length(out)) return(NULL)
    do.call(rbind, out)
}

.model_labels <- c(full = "full model (sigma_c >= 0)",
                   null = "null model (sigma_c = 0)")

.fit_subtitle <- function(x) {
    unit <- x$design$time_unit
    parts <- c(sprintf("event %s", x$event), sprintf("status %s", x$status))
    if (is.finite(x$estimates$sigma_c)) {
        parts <- c(parts, sprintf("sigma_c = %s %s^-1",
                                  .fmt(x$estimates$sigma_c), unit))
    }
    if (is.finite(x$fit$IR)) parts <- c(parts, sprintf("IR = %s",
                                                        .fmt(x$fit$IR)))
    if (inherits(x, "postexport_test") && is.finite(x$inference$p_value)) {
        parts <- c(parts, sprintf("bootstrap p = %s",
                                  .fmt(x$inference$p_value)))
    }
    paste(parts, collapse = "; ")
}

.plot_fit_trajectories <- function(x, show_means = TRUE) {
    unit <- x$design$time_unit
    p <- ggplot2::ggplot()
    if (!is.null(x$data) && nrow(x$data)) {
        obs <- .long_states(x$data)
        p <- p + ggplot2::geom_point(
            data = obs, ggplot2::aes(x = .data$time, y = .data$value),
            colour = .PAL[["observed"]], alpha = 0.7, size = 1.6)
    }
    if (show_means && !is.null(x$system)) {
        mm <- as.data.frame(x$system$summary$means)
        mm$time <- x$system$summary$times
        p <- p + ggplot2::geom_point(
            data = .long_states(mm),
            ggplot2::aes(x = .data$time, y = .data$value),
            colour = .PAL[["mean"]], shape = 4, size = 2.4, stroke = 1)
    }
    traj <- .display_trajectories(x)
    if (!is.null(traj)) {
        traj$model <- factor(.model_labels[traj$model],
                             levels = .model_labels)
        p <- p + ggplot2::geom_line(
            data = traj,
            ggplot2::aes(x = .data$time, y = .data$value,
                         colour = .data$model, linetype = .data$model),
            linewidth = 0.8) +
            ggplot2::scale_colour_manual(
                values = stats::setNames(c(.PAL[["full"]], .PAL[["null"]]),
                                         .model_labels), name = NULL) +
            ggplot2::scale_linetype_manual(
                values = stats::setNames(c("solid", "dashed"),
                                         .model_labels), name = NULL)
    }
    if (length(x$design$times)) {
        p <- p + ggplot2::geom_rug(
            data = data.frame(time = x$design$times),
            ggplot2::aes(x = .data$time), sides = "b", colour = "grey40")
    }
    if (!is.null(x$design$t_star)) {
        p <- p + ggplot2::geom_vline(xintercept = x$design$t_star,
                                     linetype = "dotted", colour = "grey20")
    }
    p + ggplot2::facet_wrap(~state, scales = "free_y", ncol = 2,
                            drop = FALSE) +
        ggplot2::labs(
            title = "Post-export kinetic model fit",
            subtitle = .fit_subtitle(x),
            x = sprintf("time (%s)", unit), y = "abundance",
            caption = paste0(
                "Points: replicate observations; crosses: time-point means; ",
                "rug: sampling times",
                if (!is.null(x$design$t_star)) "; dotted line: t_star" else "",
                ".\nCurves: display reconstructions, propagated from the ",
                "observed replicate-mean state at the first sampled time with ",
                "the fitted coefficients;\ninference uses the frozen ",
                "interval-balance / Crank-Nicolson machinery, not these ",
                "curves. sigma_c is a\nphenomenological post-export ",
                "conversion rate.")) +
        ggplot2::theme_bw() +
        ggplot2::theme(legend.position = "bottom")
}

.plot_bootstrap <- function(x) {
    inf <- x$inference
    tb <- inf$T_boot
    if (is.null(tb) || !length(tb)) {
        stop("No bootstrap statistics are available for this result ",
             "(status ", x$status, ").", call. = FALSE)
    }
    tol <- x$boundary$tolerance
    sub <- sprintf(paste0("event %s; T_obs = %s; bootstrap p = %s; valid ",
                          "replicates %s of %s; failure fraction %s; ",
                          "fraction of T* at the boundary %s"),
                   x$event, .fmt(x$fit$T_obs), .fmt(inf$p_value),
                   .fmt(inf$n_bootstrap_valid), inf$B,
                   .fmt(inf$bootstrap_failure_rate), .fmt(inf$atom_zero))
    d <- data.frame(T = tb, boundary = tb <= tol)
    ggplot2::ggplot(d, ggplot2::aes(x = .data$T)) +
        ggplot2::geom_histogram(ggplot2::aes(fill = .data$boundary),
                                bins = 30, colour = "white") +
        ggplot2::scale_fill_manual(
            values = c(`FALSE` = "grey60", `TRUE` = .PAL[["null"]]),
            labels = c(`FALSE` = "T* > boundary tolerance",
                       `TRUE` = "T* at the boundary (atom at zero)"),
            name = NULL, drop = FALSE) +
        ggplot2::geom_vline(xintercept = x$fit$T_obs,
                            colour = .PAL[["full"]], linewidth = 0.9) +
        ggplot2::labs(
            title = "Bootstrap null distribution of T",
            subtitle = sub,
            x = "T = max(0, RSS0 - RSS1) (whitened)",
            y = "bootstrap replicates",
            caption = paste(
                "Vertical line: observed T. Replicate-level generative",
                "bootstrap under the fitted sigma_c = 0 null model;",
                "add-one p-value.")) +
        ggplot2::theme_bw() +
        ggplot2::theme(legend.position = "bottom")
}


#' Plot post-export kinetic results
#'
#' `ggplot2` plots of fit, test, simulation and operational-domain results.
#' Plotting never modifies the object, never refits and never runs inference;
#' each method returns a `ggplot` object.
#'
#' @section Fits and tests:
#' `type = "fit"` (default) shows, for the four states `N`, `N_s`, `C` and
#' `C_s`, the replicate observations, the time-point means (`show_means`),
#' the sampling times, `t_star` and the fitted full (`sigma_c >= 0`) and null
#' (`sigma_c = 0`) models. The fitted curves are display reconstructions
#' only: they are propagated with the ODE model from the observed
#' replicate-mean state at the first sampled time using the fitted
#' coefficients and the model's transcription schedule. The fit, the test
#' statistic and the bootstrap/null calculations do not use these curves;
#' they use the validated frozen interval-balance / Crank-Nicolson machinery.
#' Plotting never refits or modifies the result. For
#' `postexport_test`, `type = "bootstrap"` shows the bootstrap distribution
#' of `T` with the observed `T`, the boundary atom, the p-value and the
#' failure fraction.
#'
#' @section Sets:
#' `type = "status"` (default): counts by status; `"boundary"`: counts by
#' boundary status; `"sigma_IR"`: `sigma_c` against `IR`. For test sets
#' after [adjust_postexport_pvalues()] also `"sigma_q"` (`sigma_c` against
#' `-log10(q)`), `"IR_q"` (`IR` against `-log10(q)`) and `"score"`
#' (distribution of the exploratory score of [rank_postexport_candidates()]).
#' The axes keep effect size, fit improvement and evidence separate.
#'
#' @section Simulations:
#' Latent trajectories per replicate (no smoothing), sampled latent states,
#' noisy observations (`show_observed`), the transcriptional onset and the
#' intervention time `t_star`.
#'
#' @section Operational domain:
#' Manuscript benchmark designs matched exactly or as nearest evaluated
#' designs, with empirical Type-I error at alpha = 0.05, Wilson 95%
#' intervals and the nominal 0.05 reference. This describes benchmark
#' simulations, not the calibration of a dataset.
#'
#' @param x A result object.
#' @param type Plot type (see Details).
#' @param show_means Logical; show time-point means (fits and tests).
#' @param show_observed Logical; show noisy observations (simulations).
#' @param ... Ignored.
#'
#' @return A `ggplot` object.
#'
#' @name plot.postexport
#' @examples
#' p <- c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,
#'        alpha = 0.2, alpha_s = 0.08)
#' sim <- simulate_postexport_kinetics(
#'     p, times = c(90, 100, 110, 130, 160), onset_time = 0, t_star = 100,
#'     regime = "SHUTOFF", time_unit = "min", n_replicates = 3,
#'     param_cv = 0.05, noise = list(platform = "gaussian", level = "low"),
#'     seed = 1)
#' plot(sim)
#'
#' data(postexport_example)
#' x <- postexport_data(
#'     postexport_example[postexport_example$event == "alt_3", ],
#'     time_unit = "min")
#' plot(fit_postexport_model(x, t_star = 332))
#' x <- postexport_data(sim$observed, time_unit = "min")
#' plot(fit_postexport_model(x, t_star = 100))
NULL

#' @rdname plot.postexport
#' @export
plot.postexport_fit <- function(x, type = "fit", show_means = TRUE, ...) {
    type <- match.arg(type, "fit")
    .plot_fit_trajectories(x, show_means = show_means)
}

#' @rdname plot.postexport
#' @export
plot.postexport_test <- function(x, type = c("fit", "bootstrap"),
                                 show_means = TRUE, ...) {
    type <- match.arg(type)
    if (type == "fit") .plot_fit_trajectories(x, show_means) else
        .plot_bootstrap(x)
}

.set_frame <- function(x) {
    s <- x$summary
    if (!"at_boundary" %in% names(s)) s$at_boundary <- NA
    s
}

.plot_set_counts <- function(s, var, title, xlab) {
    v <- s[[var]]
    lab <- ifelse(is.na(v), "NA", as.character(v))
    d <- as.data.frame(table(value = lab), stringsAsFactors = FALSE)
    ggplot2::ggplot(d, ggplot2::aes(x = .data$value, y = .data$Freq)) +
        ggplot2::geom_col(fill = "grey45") +
        ggplot2::labs(title = title, x = xlab, y = "events") +
        ggplot2::theme_bw()
}

.plot_set_scatter <- function(s, xvar, yvar, xlab, ylab, title) {
    d <- s[is.finite(s[[xvar]]) & is.finite(s[[yvar]]), , drop = FALSE]
    d$boundary <- ifelse(is.na(d$at_boundary), "NA",
                         ifelse(d$at_boundary, "at boundary",
                                "not at boundary"))
    ggplot2::ggplot(d, ggplot2::aes(x = .data[[xvar]], y = .data[[yvar]],
                                    shape = .data$boundary)) +
        ggplot2::geom_point(alpha = 0.8) +
        ggplot2::scale_shape_manual(
            values = c(`at boundary` = 1, `not at boundary` = 16, `NA` = 4),
            name = NULL) +
        ggplot2::labs(title = title, x = xlab, y = ylab,
                      caption = paste("Descriptive display; effect size,",
                                      "fit improvement and evidence are",
                                      "distinct quantities.")) +
        ggplot2::theme_bw() +
        ggplot2::theme(legend.position = "bottom")
}

.require_q <- function(x) {
    if (is.null(x$adjustment)) {
        stop("This plot needs q-values: call adjust_postexport_pvalues() ",
             "first.", call. = FALSE)
    }
}

#' @rdname plot.postexport
#' @export
plot.postexport_fit_set <- function(x, type = c("status", "boundary",
                                                "sigma_IR"), ...) {
    type <- match.arg(type)
    s <- .set_frame(x)
    unit <- x$time_unit
    switch(type,
        status = .plot_set_counts(s, "status", "Fit status by event",
                                  "status"),
        boundary = .plot_set_counts(s, "at_boundary",
                                    "Boundary status (T_obs <= tolerance)",
                                    "at boundary"),
        sigma_IR = .plot_set_scatter(
            s, "sigma_c", "IR",
            sprintf("sigma_c (effect-size estimate, %s^-1)", unit),
            "IR (relative RSS improvement)", "Effect size and fit improvement"))
}

#' @rdname plot.postexport
#' @export
plot.postexport_test_set <- function(x, type = c("status", "boundary",
                                                 "sigma_IR", "sigma_q",
                                                 "IR_q", "score"), ...) {
    type <- match.arg(type)
    s <- .set_frame(x)
    unit <- x$time_unit
    if (type %in% c("sigma_q", "IR_q", "score")) .require_q(x)
    if (type %in% c("sigma_q", "IR_q")) s$neglog10_q <- -log10(s$q_value)
    switch(type,
        status = .plot_set_counts(s, "status", "Test status by event",
                                  "status"),
        boundary = .plot_set_counts(s, "at_boundary",
                                    "Boundary status (T_obs <= tolerance)",
                                    "at boundary"),
        sigma_IR = .plot_set_scatter(
            s, "sigma_c", "IR",
            sprintf("sigma_c (effect-size estimate, %s^-1)", unit),
            "IR (relative RSS improvement)", "Effect size and fit improvement"),
        sigma_q = .plot_set_scatter(
            s, "sigma_c", "neglog10_q",
            sprintf("sigma_c (effect-size estimate, %s^-1)", unit),
            sprintf("-log10(q) (%s-adjusted bootstrap p-value)",
                    x$adjustment$method),
            "Effect size and adjusted evidence"),
        IR_q = .plot_set_scatter(
            s, "IR", "neglog10_q", "IR (relative RSS improvement)",
            sprintf("-log10(q) (%s-adjusted bootstrap p-value)",
                    x$adjustment$method),
            "Fit improvement and adjusted evidence"),
        score = {
            r <- rank_postexport_candidates(x)
            d <- data.frame(score = r$score[is.finite(r$score)])
            ggplot2::ggplot(d, ggplot2::aes(x = .data$score)) +
                ggplot2::geom_histogram(bins = 30, fill = "grey45",
                                        colour = "white") +
                ggplot2::labs(
                    title = "Exploratory prioritization score",
                    subtitle = sprintf("%d ranked events; %d not rankable",
                                       sum(!is.na(r$rank)),
                                       sum(is.na(r$rank))),
                    x = "score = sigma_c * IR * min(-log10(max(q, 1e-10)), 6)",
                    y = "events",
                    caption = paste("Exploratory prioritization, not",
                                    "inferential evidence.")) +
                ggplot2::theme_bw()
        })
}

#' @rdname plot.postexport
#' @export
plot.postexport_simulation <- function(x, show_observed = TRUE, ...) {
    tm <- x$timing
    lat <- .long_states(x$latent, "replicate")
    smp <- .long_states(x$sampled, "replicate")
    p <- ggplot2::ggplot() +
        ggplot2::geom_line(
            data = lat,
            ggplot2::aes(x = .data$time, y = .data$value,
                         group = .data$replicate),
            colour = .PAL[["full"]], alpha = 0.6) +
        ggplot2::geom_point(
            data = smp, ggplot2::aes(x = .data$time, y = .data$value),
            colour = .PAL[["full"]], size = 1.6)
    if (show_observed && !is.null(x$observed)) {
        p <- p + ggplot2::geom_point(
            data = .long_states(x$observed),
            ggplot2::aes(x = .data$time, y = .data$value),
            colour = .PAL[["null"]], shape = 17, size = 1.8, alpha = 0.8)
    }
    markers <- data.frame(time = tm$onset_time,
                          marker = "transcriptional onset")
    if (!is.null(tm$t_star)) {
        markers <- rbind(markers, data.frame(time = tm$t_star,
                                             marker = "intervention t_star"))
    }
    p + ggplot2::geom_vline(
            data = markers,
            ggplot2::aes(xintercept = .data$time, linetype = .data$marker),
            colour = "grey20") +
        ggplot2::scale_linetype_manual(
            values = c(`transcriptional onset` = "dotted",
                       `intervention t_star` = "dashed"), name = NULL) +
        ggplot2::facet_wrap(~state, scales = "free_y", ncol = 2,
                            drop = FALSE) +
        ggplot2::labs(
            title = "Simulated post-export kinetics",
            subtitle = sprintf(
                paste0("regime %s%s; onset %s; t_star %s %s; ",
                       "%d replicate(s); noise %s"),
                tm$regime,
                if (identical(tm$regime, "PSEUDO_SHUTOFF"))
                    sprintf(" (residual fraction %s)",
                            .fmt(tm$residual_fraction)) else "",
                .fmt(tm$onset_time),
                if (is.null(tm$t_star)) "NULL" else .fmt(tm$t_star),
                x$time_unit, x$replication$n_replicates,
                if (is.null(x$noise)) "none" else
                    paste(x$noise$platform, x$noise$level)),
            x = sprintf("time (%s)", x$time_unit), y = "abundance",
            caption = paste0(
                "Lines: latent trajectories (no smoothing); circles: sampled ",
                "latent states",
                if (show_observed && !is.null(x$observed))
                    "; triangles: noisy observations" else "",
                ".\nSimulated data do not establish a molecular mechanism.")) +
        ggplot2::theme_bw() +
        ggplot2::theme(legend.position = "bottom")
}

#' @rdname plot.postexport
#' @export
plot.postexport_domain_check <- function(x, ...) {
    rows <- list()
    for (i in seq_along(x$checks)) {
        ck <- x$checks[[i]]
        if (!nrow(ck$matches)) next
        m <- ck$matches
        rows[[i]] <- data.frame(
            design = sprintf("design %d (%s)", i, ck$match_type),
            match_type = ifelse(ck$match_type == "exact", "exact match",
                                "nearest evaluated design"),
            configuration = sprintf("%s / %s / %d tp / %d rep / int %s",
                                    m$platform, m$noise_level,
                                    m$n_time_points, m$n_replicates,
                                    format(m$sampling_interval)),
            type1 = m$type1_005, low = m$type1_005_wilson_low,
            high = m$type1_005_wilson_high,
            criterion = ifelse(m$ci_contains_005,
                               "Wilson interval contains 0.05",
                               "Wilson interval excludes 0.05"),
            stringsAsFactors = FALSE)
    }
    title <- "Manuscript benchmark designs"
    caption <- paste("Empirical results for simulated benchmark data; not a",
                     "calibration guarantee for any dataset.")
    if (!length(rows)) {
        return(ggplot2::ggplot() +
            ggplot2::annotate("text", x = 0, y = 0, label = paste(
                "No manuscript benchmark designs to show",
                "(for example: pseudo-shutoff designs are not benchmarked).")) +
            ggplot2::labs(title = title, caption = caption) +
            ggplot2::theme_void())
    }
    d <- do.call(rbind, rows)
    ggplot2::ggplot(d, ggplot2::aes(y = .data$configuration, x = .data$type1,
                                    colour = .data$match_type,
                                    shape = .data$criterion)) +
        ggplot2::geom_vline(xintercept = 0.05, linetype = "dashed",
                            colour = "grey30") +
        ggplot2::geom_errorbar(ggplot2::aes(xmin = .data$low,
                                            xmax = .data$high),
                               width = 0.3, orientation = "y") +
        ggplot2::geom_point(size = 2) +
        ggplot2::scale_colour_manual(
            values = c(`exact match` = .PAL[["exact"]],
                       `nearest evaluated design` = .PAL[["nearest"]]),
            name = NULL) +
        ggplot2::scale_shape_manual(
            values = c(`Wilson interval contains 0.05` = 16,
                       `Wilson interval excludes 0.05` = 1), name = NULL) +
        ggplot2::facet_wrap(~design, scales = "free_y") +
        ggplot2::labs(
            title = title,
            subtitle = paste("Empirical Type-I error at alpha = 0.05 with",
                             "Wilson 95% intervals; dashed line: nominal 0.05"),
            x = "empirical Type-I error (benchmark)", y = NULL,
            caption = caption) +
        ggplot2::theme_bw() +
        ggplot2::theme(legend.position = "bottom",
                       axis.text.y = ggplot2::element_text(size = 7))
}
