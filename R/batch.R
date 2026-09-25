# =============================================================================
# Batch results: multiple-testing adjustment, exploratory ranking and tidy
# result tables.
#
# Frozen provenance (real_datasets/run_real_datasets_revision.R at tag
# manuscript-revision-v1.0):
#   valid tests          status == "ok" & is.finite(p.value)      L1389
#   BH within dataset    p.adjust(p.value, "BH") on valid tests   L1440
#   IR                   DeltaRSS / RSS0 if RSS0 > 0, else NA     L1468-1471
#   evidence             min(-log10(max(q.value, 1e-10)), 6)      L1453, 1506,
#                                                                 1516, 1531
#   score_sigma_IR_q     Sigma * IR * evidence                    L1614
#   exploratory order    order(dataset, -score_sigma_IR_q)        L1841
# The same composite is used by the synthetic ablation
# (synthetic_dataset/analyze_composite_score_ablation.R:186-218).
# =============================================================================

.RANK_Q_FLOOR <- 1e-10
.RANK_EVIDENCE_CAP <- 6

.RANKING_NOTE <- paste(
    "Exploratory prioritization only: score = sigma_c * IR *",
    "min(-log10(max(q, 1e-10)), 6), the composite of the manuscript. It is",
    "not an inferential quantity and not an optimized discrimination score;",
    "p- and q-values are the statistical evidence, sigma_c is the effect-size",
    "estimate and IR the fit improvement."
)

.valid_tests <- function(s) {
    s$status == "ok" & is.finite(s$p_value)
}


#' Adjust bootstrap p-values for multiple testing
#'
#' Computes q-values for a set of events tested with
#' [test_postexport_conversion()], using [stats::p.adjust()]. Only valid tests
#' (status `"ok"` and a finite p-value) enter the adjustment; other events keep
#' their status and receive `q_value = NA`. Raw p-values are never modified.
#'
#' @section Families:
#' In the manuscript, Benjamini-Hochberg adjustment was applied separately
#' within each dataset. By default all events of `x` form one family; with
#' `groups`, the adjustment is performed separately within each group (for
#' example one group per dataset). Combining events from different datasets in
#' one family changes the q-values.
#'
#' @param x A `postexport_test_set` (from [test_postexport_conversion()] with
#'   several events).
#' @param method Adjustment method passed to [stats::p.adjust()]; default
#'   `"BH"` (Benjamini-Hochberg), as in the manuscript.
#' @param groups Optional family labels: a vector with one label per event in
#'   the order of `x$summary$event`, or a vector named by event. `NULL`
#'   (default) uses a single family.
#'
#' @return `x` with a `q_value` column (and `adjustment_group`) added to
#'   `x$summary`, `q_value` added to each result's `inference`, and an
#'   `adjustment` element (method, families, numbers of adjusted and excluded
#'   events). Existing fields are unchanged.
#'
#' @seealso [rank_postexport_candidates()], [stats::p.adjust()]
#'
#' @examples
#' set.seed(1)
#' mk <- function(ev, rate) {
#'     tab <- expand.grid(replicate = 1:3, time = c(-15, 0, 30, 60, 120))
#'     tab$event <- ev
#'     tab$N <- 60 * exp(-0.03 * pmax(tab$time, 0)) *
#'         exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$N_s <- 20 * exp(-0.01 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$C <- 25 * exp(-rate * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$C_s <- 40 * exp(-0.005 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab
#' }
#' x <- postexport_data(rbind(mk("e1", 0.02), mk("e2", 0.04)),
#'                      time_unit = "min")
#' res <- test_postexport_conversion(
#'     x, t_star = 0, control = postexport_control(B = 19,
#'                                                 seed = c(e1 = 1, e2 = 2)))
#' res <- adjust_postexport_pvalues(res)
#' res$summary[, c("event", "status", "p_value", "q_value")]
#'
#' @export
adjust_postexport_pvalues <- function(x, method = "BH", groups = NULL) {
    if (!inherits(x, "postexport_test_set")) {
        stop("'x' must be a postexport_test_set, i.e. the result of ",
             "test_postexport_conversion() for several events.",
             call. = FALSE)
    }
    if (!is.character(method) || length(method) != 1L ||
        !method %in% stats::p.adjust.methods) {
        stop(sprintf("'method' must be one of: %s.",
                     toString(stats::p.adjust.methods)), call. = FALSE)
    }
    s <- x$summary
    fam <- .adjustment_groups(groups, s$event)
    valid <- .valid_tests(s)
    q <- rep(NA_real_, nrow(s))
    for (g in unique(fam)) {
        idx <- which(fam == g & valid)
        if (length(idx)) {
            q[idx] <- stats::p.adjust(s$p_value[idx], method = method)
        }
    }
    x$summary$q_value <- q
    x$summary$adjustment_group <- fam
    for (i in seq_along(x$results)) {
        x$results[[i]]$inference$q_value <- q[i]
        x$results[[i]]$inference$adjustment_method <- method
    }
    x$adjustment <- list(
        method = method,
        groups = unique(fam),
        n_adjusted = sum(valid),
        n_excluded = sum(!valid),
        note = paste("q-values computed with stats::p.adjust() over valid",
                     "tests (status ok, finite p-value) within each family;",
                     "raw p-values unchanged.")
    )
    x
}

.adjustment_groups <- function(groups, events) {
    if (is.null(groups)) return(rep("all", length(events)))
    if (!is.null(names(groups))) {
        absent <- setdiff(events, names(groups))
        if (length(absent)) {
            stop(sprintf("'groups' has no label for event(s): %s.",
                         toString(utils::head(absent, 5L))), call. = FALSE)
        }
        groups <- groups[events]
    }
    if (length(groups) != length(events) || anyNA(groups)) {
        stop("'groups' must give one non-missing label per event.",
             call. = FALSE)
    }
    as.character(unname(groups))
}


#' Rank candidate events for exploratory follow-up
#'
#' Orders tested events by the manuscript's exploratory composite score
#' \deqn{score = \sigma_c \times IR \times \min(-\log_{10}(\max(q, 10^{-10})),
#'       6)}
#' within each adjustment family. This is an exploratory prioritization; it
#' is not inferential evidence and not an optimized discrimination score.
#' Statistical evidence is given by the p- and q-values, `sigma_c` is the
#' effect-size estimate and `IR` the relative fit improvement.
#'
#' @section Provenance:
#' The score is `score_sigma_IR_q` of the frozen manuscript real-data
#' analysis (`real_datasets/run_real_datasets_revision.R`, lines 1453-1614;
#' ordering `order(dataset, -score_sigma_IR_q)`, line 1841), the same
#' composite as in the synthetic score ablation. `IR` is `NA` when the null
#' residual sum of squares is not positive (frozen convention), which makes
#' the score `NA`.
#'
#' @section Handling:
#' \itemize{
#'   \item q-values are required; raw p-values are never substituted.
#'   \item `q = 0` is floored at `1e-10`, so the evidence term is capped at 6.
#'   \item Events that are not rankable (status other than `"ok"`, missing q,
#'     `sigma_c` or `IR`) are kept with `score = NA` and `rank = NA` and are
#'     listed last.
#'   \item Boundary events (`sigma_c = 0`) have score 0 and are ranked.
#'   \item Ties share the same (minimum) rank; tied events keep their input
#'     order.
#' }
#'
#' @param x A `postexport_test_set` processed by
#'   [adjust_postexport_pvalues()].
#'
#' @return An object of class `c("postexport_ranking", "data.frame")`, one row
#'   per event, ordered by adjustment family and decreasing score, with
#'   columns `rank`, `event`, `status`, `score`, `evidence`, `p_value`,
#'   `q_value`, `sigma_c`, `IR`, `at_boundary`, `sigma_c_zero`,
#'   `adjustment_group`, `n_bootstrap_valid`, `bootstrap_failure_rate`,
#'   `condition_number`, `rank_full`.
#'
#' @seealso [adjust_postexport_pvalues()]
#'
#' @examples
#' set.seed(1)
#' mk <- function(ev, rate) {
#'     tab <- expand.grid(replicate = 1:3, time = c(-15, 0, 30, 60, 120))
#'     tab$event <- ev
#'     tab$N <- 60 * exp(-0.03 * pmax(tab$time, 0)) *
#'         exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$N_s <- 20 * exp(-0.01 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$C <- 25 * exp(-rate * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab$C_s <- 40 * exp(-0.005 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#'     tab
#' }
#' x <- postexport_data(rbind(mk("e1", 0.02), mk("e2", 0.04)),
#'                      time_unit = "min")
#' res <- test_postexport_conversion(
#'     x, t_star = 0, control = postexport_control(B = 19,
#'                                                 seed = c(e1 = 1, e2 = 2)))
#' rank_postexport_candidates(adjust_postexport_pvalues(res))
#'
#' @export
rank_postexport_candidates <- function(x) {
    if (!inherits(x, "postexport_test_set")) {
        stop("'x' must be a postexport_test_set.", call. = FALSE)
    }
    if (is.null(x$adjustment) || !"q_value" %in% names(x$summary)) {
        stop("q-values are required: call adjust_postexport_pvalues() ",
             "first. Raw p-values are never substituted.", call. = FALSE)
    }
    s <- x$summary
    evidence <- pmin(-log10(pmax(s$q_value, .RANK_Q_FLOOR)),
                     .RANK_EVIDENCE_CAP)
    score <- s$sigma_c * s$IR * evidence
    rankable <- s$status == "ok" & is.finite(score)
    score[!rankable] <- NA_real_
    evidence[!is.finite(s$q_value)] <- NA_real_
    out <- data.frame(
        rank = NA_integer_,
        event = s$event,
        status = s$status,
        score = score,
        evidence = evidence,
        p_value = s$p_value,
        q_value = s$q_value,
        sigma_c = s$sigma_c,
        IR = s$IR,
        at_boundary = s$at_boundary,
        sigma_c_zero = vapply(x$results, function(r) r$boundary$sigma_c_zero,
                              logical(1)),
        adjustment_group = s$adjustment_group,
        n_bootstrap_valid = s$n_bootstrap_valid,
        bootstrap_failure_rate = s$bootstrap_failure_rate,
        condition_number = s$condition_number,
        rank_full = s$rank_full,
        stringsAsFactors = FALSE
    )
    for (g in unique(out$adjustment_group)) {
        idx <- which(out$adjustment_group == g)
        out$rank[idx] <- as.integer(rank(-out$score[idx], ties.method = "min",
                                         na.last = "keep"))
    }
    grp <- match(out$adjustment_group, unique(out$adjustment_group))
    out <- out[order(grp, -out$score, na.last = TRUE), , drop = FALSE]
    rownames(out) <- NULL
    attr(out, "definition") <- .RANKING_NOTE
    attr(out, "provenance") <- paste(
        "real_datasets/run_real_datasets_revision.R L1453-1614, L1841;",
        "synthetic_dataset/analyze_composite_score_ablation.R L186-218",
        "(manuscript-revision-v1.0)")
    class(out) <- c("postexport_ranking", "data.frame")
    out
}

#' @export
print.postexport_ranking <- function(x, ...) {
    cat("<postexport_ranking> exploratory prioritization,", nrow(x),
        "events (", sum(!is.na(x$rank)), "ranked )\n")
    cat(strwrap(attr(x, "definition"), width = 76, prefix = "  "),
        sep = "\n")
    show <- as.data.frame(unclass(x))[, c("rank", "event", "status", "score",
                                          "q_value", "sigma_c", "IR",
                                          "at_boundary")]
    print(utils::head(show, 20L), row.names = FALSE, digits = 4)
    if (nrow(x) > 20L) cat("...", nrow(x) - 20L, "more rows\n")
    invisible(x)
}


# -----------------------------------------------------------------------------
# Tidy result tables
# -----------------------------------------------------------------------------

.COLUMN_ROLES <- c(
    event = "identifier", status = "status", error_message = "status",
    p_value = "inference", q_value = "inference",
    adjustment_group = "inference", B = "inference",
    n_bootstrap_valid = "inference", bootstrap_failure_rate = "inference",
    atom_zero = "inference",
    sigma_c = "effect size",
    IR = "fit", T_obs = "fit", RSS_null = "fit", RSS_full = "fit",
    at_boundary = "boundary", sigma_c_zero = "boundary",
    boundary_tolerance = "boundary",
    condition_number = "diagnostic",
    condition_number_nonzero_columns = "diagnostic",
    min_singular_value = "diagnostic", rank_full = "diagnostic",
    rank_null = "diagnostic", structurally_zero_columns = "diagnostic",
    t_star = "design", time_unit = "design", n_time_points = "design",
    min_replicates = "design", design_warnings = "design"
)

.result_row <- function(r, t_star, unit) {
    dg <- r$diagnostics
    row <- data.frame(
        event = r$event,
        status = r$status,
        error_message = if (is.null(r$error_message)) NA_character_ else
            r$error_message,
        sigma_c = r$estimates$sigma_c,
        IR = r$fit$IR,
        T_obs = r$fit$T_obs,
        RSS_null = r$fit$RSS_null,
        RSS_full = r$fit$RSS_full,
        at_boundary = r$boundary$at_boundary,
        sigma_c_zero = r$boundary$sigma_c_zero,
        boundary_tolerance = r$boundary$tolerance,
        condition_number = dg$condition_number,
        condition_number_nonzero_columns = dg$condition_number_nonzero_columns,
        min_singular_value = dg$min_singular_value,
        rank_full = dg$rank_full,
        rank_null = dg$rank_null,
        structurally_zero_columns = paste(dg$structurally_zero_columns,
                                          collapse = ","),
        t_star = if (is.null(t_star)) NA_real_ else t_star,
        time_unit = unit,
        n_time_points = length(r$design$times),
        min_replicates = if (length(r$design$n_replicates_by_time)) {
            min(r$design$n_replicates_by_time)
        } else {
            NA_integer_
        },
        design_warnings = paste(r$design$warnings, collapse = " | "),
        stringsAsFactors = FALSE
    )
    if (inherits(r, "postexport_test")) {
        inf <- r$inference
        row$p_value <- inf$p_value
        row$q_value <- if (is.null(inf$q_value)) NA_real_ else inf$q_value
        row$B <- inf$B
        row$n_bootstrap_valid <- inf$n_bootstrap_valid
        row$bootstrap_failure_rate <- inf$bootstrap_failure_rate
        row$atom_zero <- inf$atom_zero
    }
    row
}

.tidy_results <- function(results, t_star, unit, adjusted) {
    rows <- lapply(results, .result_row, t_star = t_star, unit = unit)
    out <- do.call(rbind, rows)
    rownames(out) <- NULL
    first <- c("event", "status", "p_value", "q_value", "sigma_c", "IR",
               "T_obs", "at_boundary")
    if (!adjusted) first <- setdiff(first, "q_value")
    keep <- c(intersect(first, names(out)),
              setdiff(names(out), c(first, if (!adjusted) "q_value")))
    out <- out[, keep, drop = FALSE]
    attr(out, "column_roles") <- .COLUMN_ROLES[names(out)]
    out
}

#' Tidy result tables
#'
#' Flat, stable, user-facing tables of fit and test results, suitable for
#' saving (for example with [utils::write.csv()]). Internal matrices are not
#' included; the per-event result objects remain available unchanged.
#'
#' @section Columns:
#' \describe{
#'   \item{identifier / status}{`event`, `status`, `error_message`.}
#'   \item{inference}{`p_value` (bootstrap, one-sided), `q_value` (only
#'     after [adjust_postexport_pvalues()]; otherwise absent),
#'     `adjustment_group`, `B`, `n_bootstrap_valid`,
#'     `bootstrap_failure_rate`, `atom_zero`.}
#'   \item{effect size}{`sigma_c` (phenomenological post-export conversion
#'     rate).}
#'   \item{fit}{`IR` (relative RSS improvement), `T_obs`, `RSS_null`,
#'     `RSS_full`.}
#'   \item{boundary}{`at_boundary` (frozen rule), `sigma_c_zero`,
#'     `boundary_tolerance`.}
#'   \item{diagnostics}{`condition_number`,
#'     `condition_number_nonzero_columns`, `min_singular_value`,
#'     `rank_full`, `rank_null`, `structurally_zero_columns`.}
#'   \item{design}{`t_star`, `time_unit`, `n_time_points`,
#'     `min_replicates`, `design_warnings`.}
#' }
#' The role of every column is also given in the attribute
#' `"column_roles"`.
#'
#' @param x A `postexport_fit`, `postexport_test`, `postexport_fit_set` or
#'   `postexport_test_set`.
#' @param row.names,optional Ignored (for compatibility with the generic).
#' @param ... Ignored.
#'
#' @return A data frame with one row per event.
#'
#' @name as.data.frame.postexport
#' @examples
#' set.seed(1)
#' tab <- expand.grid(replicate = 1:3, time = c(-15, 0, 30, 60, 120))
#' tab$event <- "event_1"
#' tab$N <- 60 * exp(-0.03 * pmax(tab$time, 0)) *
#'     exp(rnorm(nrow(tab), 0, 0.05))
#' tab$N_s <- 20 * exp(-0.01 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C <- 25 * exp(-0.02 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' tab$C_s <- 40 * exp(-0.005 * tab$time) * exp(rnorm(nrow(tab), 0, 0.05))
#' fit <- fit_postexport_model(postexport_data(tab, time_unit = "min"),
#'                             t_star = 0)
#' as.data.frame(fit)
NULL

#' @rdname as.data.frame.postexport
#' @export
as.data.frame.postexport_fit <- function(x, row.names = NULL,
                                         optional = FALSE, ...) {
    .tidy_results(list(x), x$design$t_star, x$design$time_unit,
                  adjusted = !is.null(x$inference$q_value))
}

#' @rdname as.data.frame.postexport
#' @export
as.data.frame.postexport_fit_set <- function(x, row.names = NULL,
                                             optional = FALSE, ...) {
    .tidy_results(x$results, x$t_star, x$time_unit, adjusted = FALSE)
}

#' @rdname as.data.frame.postexport
#' @export
as.data.frame.postexport_test_set <- function(x, row.names = NULL,
                                              optional = FALSE, ...) {
    out <- .tidy_results(x$results, x$t_star, x$time_unit,
                         adjusted = !is.null(x$adjustment))
    if (!is.null(x$adjustment)) {
        out$adjustment_group <- x$summary$adjustment_group[
            match(out$event, x$summary$event)]
        attr(out, "column_roles") <- .COLUMN_ROLES[names(out)]
    }
    out
}
