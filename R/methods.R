# =============================================================================
# print() and summary() methods for fit and test results
#
# Wording rules: sigma_c is reported as an effect-size estimate of a
# phenomenological post-export conversion rate; the bootstrap p-value is the
# inferential quantity; no mechanistic conclusion is ever printed.
# =============================================================================

.fmt <- function(x, digits = 4L) {
    if (is.null(x) || length(x) == 0L) return("NA")
    if (is.character(x)) return(paste(x, collapse = ", "))
    if (is.logical(x)) return(ifelse(is.na(x), "NA", ifelse(x, "yes", "no")))
    out <- ifelse(is.na(x), "NA", formatC(x, digits = digits, format = "g"))
    paste(trimws(out), collapse = ", ")
}

.rate_unit <- function(unit) paste0(unit, "^-1")

.error_text <- function(msg) {
    if (is.null(msg)) "" else paste0("(", msg, ")")
}

.design_line <- function(x) {
    d <- x$design
    nt <- length(d$times)
    reps <- d$n_replicates_by_time
    rep_txt <- if (!length(reps)) {
        "NA"
    } else if (length(unique(reps)) == 1L) {
        as.character(reps[1L])
    } else {
        paste0(min(reps), "-", max(reps))
    }
    times_txt <- if (nt) {
        sprintf("%d time points (%s..%s %s)", nt, .fmt(min(d$times)),
                .fmt(max(d$times)), d$time_unit)
    } else {
        "time points unavailable"
    }
    ts <- if (is.null(d$t_star)) {
        "continuous transcription (t_star = NULL)"
    } else {
        sprintf("shutoff at t_star = %s %s (complete shutoff assumed)",
                .fmt(d$t_star), d$time_unit)
    }
    sprintf("%s; %s, %s replicate(s) per time", ts, times_txt, rep_txt)
}

.print_estimate_lines <- function(x) {
    unit <- .rate_unit(x$design$time_unit)
    cat(sprintf(paste0("  Effect size : sigma_c = %s %s (phenomenological ",
                       "post-export conversion rate)\n"),
                .fmt(x$estimates$sigma_c), unit))
    cat(sprintf(paste0("  Fit         : IR = %s (relative RSS improvement ",
                       "over the sigma_c = 0 null); T_obs = %s\n"),
                .fmt(x$fit$IR), .fmt(x$fit$T_obs)))
    cat(sprintf("  Boundary    : %s\n",
                if (isTRUE(x$boundary$at_boundary)) {
                    paste0("yes (T_obs <= frozen tolerance; sigma_c on the ",
                           "non-negativity boundary)")
                } else if (identical(x$boundary$at_boundary, FALSE)) {
                    "no"
                } else {
                    "NA"
                }))
}

#' @export
print.postexport_fit <- function(x, ...) {
    cat("<postexport_fit> event:", x$event, "\n")
    cat("  Status      :", x$status,
        .error_text(x$error_message),
        "\n")
    cat("  Design      :", .design_line(x), "\n")
    if (identical(x$status, "ok")) .print_estimate_lines(x)
    cat("  No bootstrap inference; see test_postexport_conversion().\n")
    invisible(x)
}

#' @export
print.postexport_test <- function(x, ...) {
    cat("<postexport_test> event:", x$event, "\n")
    cat("  Status      :", x$status,
        .error_text(x$error_message),
        "\n")
    cat("  Design      :", .design_line(x), "\n")
    if (!is.na(x$fit$T_obs)) .print_estimate_lines(x)
    inf <- x$inference
    cat(sprintf(paste0("  Inference   : bootstrap p = %s (one-sided, ",
                       "sigma_c > 0; B = %d, %s valid; add-one)\n"),
                .fmt(inf$p_value), inf$B, .fmt(inf$n_bootstrap_valid)))
    cat(strwrap(.INTERPRETATION, width = 76, prefix = "    ",
                initial = "  Note: "), sep = "\n")
    invisible(x)
}

.coef_table <- function(x) {
    data.frame(
        parameter = PARAM_NAMES,
        full = unname(x$estimates$coef_full),
        null = unname(x$estimates$coef_null),
        row.names = NULL
    )
}

#' @export
summary.postexport_fit <- function(object, ...) {
    structure(list(object = object, coefficients = .coef_table(object)),
              class = "summary.postexport_fit")
}

#' @export
summary.postexport_test <- function(object, ...) {
    structure(list(object = object, coefficients = .coef_table(object)),
              class = c("summary.postexport_test", "summary.postexport_fit"))
}

#' @export
print.summary.postexport_fit <- function(x, ...) {
    o <- x$object
    is_test <- inherits(o, "postexport_test")
    cat(if (is_test) "Post-export conversion test" else
        "Post-export kinetic model fit", "- event:", o$event, "\n")
    cat("Status:", o$status,
        .error_text(o$error_message),
        "\n\n")
    cat("Design\n")
    cat("  ", .design_line(o), "\n", sep = "")
    cat("  times:", .fmt(o$design$times), "\n")
    cat("  replicates per time:", .fmt(o$design$n_replicates_by_time), "\n\n")

    cat("Estimates (rates per ", o$design$time_unit, ")\n", sep = "")
    tab <- x$coefficients
    tab$full <- vapply(tab$full, .fmt, character(1))
    tab$null <- vapply(tab$null, .fmt, character(1))
    print(tab, row.names = FALSE, right = FALSE)
    cat("  sigma_c (effect-size estimate):", .fmt(o$estimates$sigma_c), "\n\n")

    cat("Fit (whitened scale)\n")
    cat("  RSS null (sigma_c = 0):", .fmt(o$fit$RSS_null), "\n")
    cat("  RSS full (sigma_c >= 0):", .fmt(o$fit$RSS_full), "\n")
    cat("  T_obs = max(0, RSS0 - RSS1):", .fmt(o$fit$T_obs), "\n")
    cat("  IR (relative RSS improvement):", .fmt(o$fit$IR), "\n\n")

    cat("Boundary\n")
    cat("  frozen tolerance 1e-10 * max(1, |RSS0|, |RSS1|):",
        .fmt(o$boundary$tolerance), "\n")
    cat("  at boundary (T_obs <= tolerance):", .fmt(o$boundary$at_boundary),
        "\n")
    cat("  sigma_c exactly zero (|sigma_c| < 1e-12):",
        .fmt(o$boundary$sigma_c_zero), "\n")
    if (is_test) {
        cat("  fraction of T* at the boundary (atom.zero):",
            .fmt(o$inference$atom_zero), "\n")
    }
    cat("\n")

    if (is_test) {
        inf <- o$inference
        cat("Inference\n")
        cat("  bootstrap p-value (one-sided, sigma_c > 0):",
            .fmt(inf$p_value), "\n")
        cat("  B:", inf$B, "; valid replicates:", .fmt(inf$n_bootstrap_valid),
            "; failure rate:", .fmt(inf$bootstrap_failure_rate),
            "(limit", .fmt(o$control$max_failure_rate), ")\n")
        cat("  statistic:", inf$statistic, "\n")
        cat("  method:", inf$method, "\n")
        cat("  not a likelihood-ratio test; no multiple-testing adjustment\n\n")
    }

    dg <- o$diagnostics
    cat("Diagnostics\n")
    cat("  condition number (whitened full design):",
        .fmt(dg$condition_number), "\n")
    cat("  minimum singular value:", .fmt(dg$min_singular_value), "\n")
    cat("  rank full / null:", .fmt(dg$rank_full), "/", .fmt(dg$rank_null),
        "(of 7 / 6 columns)\n")
    cat("  structurally zero design columns:",
        if (length(dg$structurally_zero_columns))
            .fmt(dg$structurally_zero_columns) else "none", "\n")
    cat("  condition number over non-zero columns (diagnostic only):",
        .fmt(dg$condition_number_nonzero_columns), "\n")
    if (is_test) {
        bd <- o$bootstrap_diagnostics
        cat("  bootstrap condition number median / q95 / max:",
            .fmt(bd$condition_median), "/", .fmt(bd$condition_q95), "/",
            .fmt(bd$condition_max), "\n")
        cat("  bootstrap rank-deficient fraction:",
            .fmt(bd$rank_deficient_fraction), "\n")
    }
    cat("\n")

    diff <- .control_differences(o$control)
    cat("Control:", if (length(diff)) paste("non-default:", toString(diff))
        else "frozen manuscript defaults", "\n")
    if (is_test) {
        cat("Reproducibility: seed =", .fmt(o$rng$seed), "; RNG kind:",
            .fmt(o$rng$kind), "\n")
        cat("  ", o$rng$note, "\n", sep = "")
    }
    cat("Frozen reference:", o$provenance$frozen_tag,
        substr(o$provenance$frozen_commit, 1, 12), "\n\n")
    cat(strwrap(.INTERPRETATION, width = 78), sep = "\n")
    invisible(x)
}

#' @export
print.postexport_fit_set <- function(x, ...) {
    .print_set(x, "<postexport_fit_set>")
}

#' @export
print.postexport_test_set <- function(x, ...) {
    .print_set(x, "<postexport_test_set>")
}

.print_set <- function(x, header) {
    s <- x$summary
    cat(header, nrow(s), "events;",
        if (is.null(x$t_star)) "t_star = NULL" else
            paste("t_star =", .fmt(x$t_star), x$time_unit), "\n")
    cols <- intersect(c("event", "status", "sigma_c", "IR", "at_boundary",
                        "p_value"), names(s))
    show <- utils::head(s[, cols, drop = FALSE], 10L)
    print(show, row.names = FALSE, digits = 4)
    if (nrow(s) > 10L) cat("...", nrow(s) - 10L, "more; see $summary\n")
    if ("p_value" %in% names(s)) {
        cat("p_value is the per-event bootstrap p-value (no multiple-testing",
            "adjustment).\n")
    }
    invisible(x)
}

#' @export
summary.postexport_fit_set <- function(object, ...) {
    .summarise_set(object)
}

#' @export
summary.postexport_test_set <- function(object, ...) {
    .summarise_set(object)
}

.summarise_set <- function(object) {
    s <- object$summary
    structure(list(
        n_events = nrow(s),
        status = table(s$status, useNA = "ifany"),
        n_at_boundary = sum(s$at_boundary %in% TRUE),
        n_with_p = if ("p_value" %in% names(s)) sum(!is.na(s$p_value)) else NA,
        summary = s
    ), class = "summary.postexport_set")
}

#' @export
print.summary.postexport_set <- function(x, ...) {
    cat("Events:", x$n_events, "\n")
    cat("Status:\n")
    print(x$status)
    cat("At the boundary (T_obs <= tolerance):", x$n_at_boundary, "\n")
    if (!is.na(x$n_with_p)) {
        cat("With a bootstrap p-value:", x$n_with_p, "\n")
        cat("No multiple-testing adjustment has been applied.\n")
    }
    invisible(x)
}
