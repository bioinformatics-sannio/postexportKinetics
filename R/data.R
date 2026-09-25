# =============================================================================
# Public data model: postexport_data() and validate_postexport_data()
#
# The canonical representation is WIDE: one row per destructive biological
# sample with columns event, time, replicate, N, N_s, C, C_s. Replicate labels
# identify samples within a time point only; they are never used to pair
# samples across time points (frozen semantics, commons/nested_test2.r).
#
# Validation never modifies values: no imputation, no zero-filling, no
# truncation of negative values. Row order is preserved.
# =============================================================================

.ID_COLS <- c("event", "time", "replicate")
.LONG_COLS <- c("event", "time", "replicate", "compartment", "state",
                "abundance")

# Explicit, documented mapping of long-format labels to kinetic states.
.LONG_STATE_MAP <- data.frame(
    compartment = c("nuclear", "nuclear", "cytoplasmic", "cytoplasmic"),
    state = c("unprocessed", "processed", "unprocessed", "processed"),
    kinetic_state = c("N", "N_s", "C", "C_s"),
    stringsAsFactors = FALSE
)

.NEGATIVE_WARNING <- paste(
    "Negative abundances are present. The kinetic states N, N_s, C and C_s",
    "have a non-negative biological interpretation, but negative values can",
    "arise after normalization or noise processing. They are accepted by the",
    "frozen numerical core and are used as supplied: they are not truncated,",
    "imputed or replaced."
)


#' Create a validated post-export kinetics data object
#'
#' Builds the canonical representation of compartment-resolved time-course
#' measurements for the four kinetic states used by the model:
#' nuclear unprocessed (`N`), nuclear processed (`N_s`), cytoplasmic
#' unprocessed (`C`) and cytoplasmic processed (`C_s`) RNA.
#'
#' @section Input formats:
#' \describe{
#'   \item{`format = "wide"` (canonical)}{One row per destructive biological
#'     sample, with columns `event`, `time`, `replicate`, `N`, `N_s`, `C`,
#'     `C_s`.}
#'   \item{`format = "long"`}{One row per sample and state, with columns
#'     `event`, `time`, `replicate`, `compartment`, `state`, `abundance`.
#'     `compartment` must be `"nuclear"` or `"cytoplasmic"` and `state` must
#'     be `"unprocessed"` or `"processed"`. The mapping is fixed:
#'     nuclear/unprocessed = `N`, nuclear/processed = `N_s`,
#'     cytoplasmic/unprocessed = `C`, cytoplasmic/processed = `C_s`. For
#'     retained-intron events quantified by rMATS, inclusion corresponds to
#'     `unprocessed` and skipping to `processed`; that assignment is the
#'     user's responsibility and is not inferred. Every sample must have
#'     exactly one value for each of the four states.}
#' }
#' Column names are matched exactly. Different names can be declared with
#' `columns`, a named character vector mapping canonical names to the names
#' in `x` (for example `c(event = "event_id", time = "minutes")`). No other
#' column is interpreted.
#'
#' @section Design semantics:
#' Each row is a destructive sample: replicate labels identify samples within
#' a time point and are never used to pair samples across time points.
#' Unequal numbers of replicates per time point are allowed. Row order is
#' preserved.
#'
#' @section Missing values:
#' Missing states are an error. The constructor never converts missing values
#' or missing states to zero and never imputes them. Samples with incomplete
#' measurements must be removed (or completed) explicitly before
#' construction.
#'
#' @param x A data frame in wide or long format.
#' @param time_unit Character string naming the unit of `time` (for example
#'   `"min"`). Required: kinetic rates, including `sigma_c`, are expressed
#'   per this unit.
#' @param format Either `"wide"` (default, canonical) or `"long"`.
#' @param columns Optional named character vector mapping canonical column
#'   names to column names of `x`.
#'
#' @return An object of class `postexport_data`: a data frame with columns
#'   `event` (character), `time` (numeric), `replicate` (character), `N`,
#'   `N_s`, `C`, `C_s` (numeric), and attributes `time_unit`, `format` (the
#'   input format) and `validation` (a `postexport_validation` object).
#'
#' @seealso [validate_postexport_data()], [fit_postexport_model()],
#'   [test_postexport_conversion()]
#'
#' @examples
#' # Wide format (synthetic example data; see ?postexport_example).
#' data(postexport_example)
#' x <- postexport_data(postexport_example, time_unit = "min")
#' x
#'
#' # Long format: one row per sample and state.
#' long <- read.csv(system.file("extdata", "postexport_example_long.csv",
#'                              package = "postexportKinetics"))
#' head(long)
#' y <- postexport_data(long, time_unit = "min", format = "long")
#'
#' @export
postexport_data <- function(x, time_unit, format = c("wide", "long"),
                            columns = NULL) {
    format <- match.arg(format)
    if (missing(time_unit) || !is.character(time_unit) ||
        length(time_unit) != 1L || is.na(time_unit) || !nzchar(time_unit)) {
        stop("'time_unit' must be a single non-empty character string, ",
             "for example \"min\".", call. = FALSE)
    }
    val <- validate_postexport_data(x, format = format, columns = columns)
    if (nrow(val$errors) > 0L) {
        msgs <- utils::head(sprintf("- %s", val$errors$message), 10L)
        if (nrow(val$errors) > 10L) msgs <- c(msgs, "- ...")
        details <- paste(msgs, collapse = "\n")
        stop("Invalid post-export kinetics data:\n", details, call. = FALSE)
    }
    for (w in val$warnings$message) warning(w, call. = FALSE)
    out <- .canonical_wide(x, format, columns)
    attr(out, "time_unit") <- time_unit
    attr(out, "format") <- format
    attr(out, "validation") <- val
    class(out) <- c("postexport_data", "data.frame")
    out
}


#' Validate post-export kinetics data
#'
#' Checks compartment-resolved time-course data before model fitting and
#' reports findings at three levels. Validation never modifies the data.
#'
#' @section Errors:
#' \itemize{
#'   \item missing identifier columns (`event`, `time`, `replicate`) or state
#'     columns (`N`, `N_s`, `C`, `C_s`), or malformed long-format structure;
#'   \item missing identifier values; non-numeric or non-finite `time`;
#'   \item non-numeric state columns;
#'   \item missing (`NA`) or non-finite state observations;
#'   \item duplicated `event`/`time`/`replicate` samples;
#'   \item an event with fewer than two distinct time points (the frozen core
#'     requires at least two);
#'   \item an event without any time point having at least two replicates
#'     (the frozen core cannot estimate the within-time covariance);
#'   \item an invalid intervention time `t_star` (not `NULL` and not a single
#'     finite number).
#' }
#'
#' @section Warnings:
#' Negative abundances (accepted and used unchanged). An intervention time
#' `t_star` at or before the first sampled time of an event (the
#' transcription rate `R` is then not estimable), or at or after the last
#' sampled time (no post-intervention interval is observed; the fit equals
#' continuous transcription). Warnings never block or alter inference.
#'
#' @section Diagnostic information:
#' Unsorted time points; unequal replication across time points; time points
#' with a single replicate (the frozen core then uses the pooled covariance
#' for that time point); events with exactly two time points. These are
#' reported for information only and are not thresholds.
#'
#' @param x A data frame (wide or long format) or a `postexport_data` object.
#' @param format Either `"wide"` or `"long"`; ignored for `postexport_data`.
#' @param columns Optional named character vector mapping canonical column
#'   names to column names of `x`; ignored for `postexport_data`.
#' @param t_star Optional intervention (transcriptional shutoff) time, on the
#'   time axis of the data, used for design diagnostics.
#'
#' @return An object of class `postexport_validation`: a list with data
#'   frames `errors`, `warnings` and `info` (columns `event`, `check`,
#'   `message`) and `design` (one row per event: number of samples, time
#'   points, and minimum/maximum replicates per time point).
#'
#' @seealso [postexport_data()]
#'
#' @examples
#' tab <- data.frame(
#'     event = "e1", time = rep(c(0, 30, 60), each = 2), replicate = 1:2,
#'     N = c(10, 11, 8, 9, 6, 7), N_s = c(5, 6, 5, 5, 4, 5),
#'     C = c(3, 3, 3, 2, 2, 2), C_s = c(9, 8, 9, 9, 8, -0.1)
#' )
#' validate_postexport_data(tab, t_star = 0)
#'
#' @export
validate_postexport_data <- function(x, format = c("wide", "long"),
                                     columns = NULL, t_star = NULL) {
    acc <- new.env(parent = emptyenv())
    acc$findings <- list()
    add <- function(level, check, message, event = NA_character_) {
        acc$findings[[length(acc$findings) + 1L]] <- data.frame(
            level = level, event = as.character(event), check = check,
            message = message, stringsAsFactors = FALSE
        )
    }
    design <- NULL

    if (inherits(x, "postexport_data")) {
        wide <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
        wide <- wide[, c(.ID_COLS, KINETIC_VARS)]
        ok <- TRUE
    } else {
        format <- match.arg(format)
        if (!is.data.frame(x)) {
            add("error", "input", "'x' must be a data frame.")
            return(.new_validation(acc$findings, design))
        }
        x <- .rename_columns(x, columns, format, add)
        if (is.null(x)) return(.new_validation(acc$findings, design))
        wide <- if (format == "wide") {
            .check_wide_columns(x, add)
        } else {
            .long_to_wide(x, add)
        }
        ok <- !is.null(wide)
    }

    if (ok) {
        design <- .check_wide_values(wide, add)
    }

    if (!is.null(t_star)) {
        if (!is.numeric(t_star) || length(t_star) != 1L ||
            !is.finite(t_star)) {
            add("error", "t_star",
                "'t_star' must be NULL or a single finite number.")
        } else if (ok && !is.null(design)) {
            .t_star_info(wide, t_star, add)
        }
    }
    .new_validation(acc$findings, design)
}


# -----------------------------------------------------------------------------
# Internal helpers
# -----------------------------------------------------------------------------

.new_validation <- function(findings, design) {
    empty <- data.frame(event = character(), check = character(),
                        message = character(), stringsAsFactors = FALSE)
    tab <- if (length(findings)) do.call(rbind, findings) else NULL
    pick <- function(level) {
        if (is.null(tab)) return(empty)
        out <- tab[tab$level == level, c("event", "check", "message"),
                   drop = FALSE]
        rownames(out) <- NULL
        out
    }
    structure(
        list(errors = pick("error"), warnings = pick("warning"),
             info = pick("info"), design = design),
        class = "postexport_validation"
    )
}

.rename_columns <- function(x, columns, format, add) {
    if (is.null(columns)) return(x)
    allowed <- if (format == "wide") c(.ID_COLS, KINETIC_VARS) else .LONG_COLS
    if (!is.character(columns) || is.null(names(columns)) ||
        any(!nzchar(names(columns))) || anyDuplicated(names(columns))) {
        add("error", "columns",
            "'columns' must be a named character vector (canonical = actual).")
        return(NULL)
    }
    bad <- setdiff(names(columns), allowed)
    if (length(bad)) {
        add("error", "columns", sprintf(
            "Unknown canonical column name(s) in 'columns': %s. Allowed: %s.",
            toString(bad), toString(allowed)))
        return(NULL)
    }
    absent <- setdiff(unname(columns), names(x))
    if (length(absent)) {
        add("error", "columns", sprintf(
            "Column(s) named in 'columns' not found in 'x': %s.",
            toString(absent)))
        return(NULL)
    }
    clash <- intersect(setdiff(names(x), unname(columns)), names(columns))
    if (length(clash)) {
        add("error", "columns", sprintf(
            "Column(s) %s exist in 'x' and are also targets of 'columns'.",
            toString(clash)))
        return(NULL)
    }
    idx <- match(unname(columns), names(x))
    names(x)[idx] <- names(columns)
    x
}

.check_wide_columns <- function(x, add) {
    miss_id <- setdiff(.ID_COLS, names(x))
    miss_st <- setdiff(KINETIC_VARS, names(x))
    if (length(miss_id)) {
        add("error", "identifiers", sprintf(
            "Missing identifier column(s): %s.", toString(miss_id)))
    }
    if (length(miss_st)) {
        add("error", "states", sprintf(
            paste0("Missing kinetic state column(s): %s. All four states N, ",
                   "N_s, C and C_s are required."),
            toString(miss_st)))
    }
    if (length(miss_id) || length(miss_st)) return(NULL)
    as.data.frame(x[, c(.ID_COLS, KINETIC_VARS)], stringsAsFactors = FALSE)
}

.long_to_wide <- function(x, add) {
    miss <- setdiff(.LONG_COLS, names(x))
    if (length(miss)) {
        add("error", "long format", sprintf(
            "Missing long-format column(s): %s.", toString(miss)))
        return(NULL)
    }
    if (!is.numeric(x$abundance)) {
        add("error", "states", "Column 'abundance' must be numeric.")
        return(NULL)
    }
    lab <- paste(x$compartment, x$state, sep = "/")
    valid <- paste(.LONG_STATE_MAP$compartment, .LONG_STATE_MAP$state,
                   sep = "/")
    bad <- unique(lab[!lab %in% valid])
    if (length(bad)) {
        add("error", "long format", sprintf(
            paste0("Invalid compartment/state label(s): %s. Allowed: ",
                   "compartment in {nuclear, cytoplasmic}, state in ",
                   "{unprocessed, processed}."),
            toString(utils::head(bad, 5L))))
        return(NULL)
    }
    if (anyNA(x$event) || anyNA(x$time) || anyNA(x$replicate)) {
        add("error", "identifiers",
            "Missing values in event, time or replicate.")
        return(NULL)
    }
    kstate <- .LONG_STATE_MAP$kinetic_state[match(lab, valid)]
    key <- paste(x$event, x$time, x$replicate, sep = "\r")
    dup <- duplicated(paste(key, kstate, sep = "\r"))
    if (any(dup)) {
        add("error", "duplicates", sprintf(
            paste0("%d duplicated event/time/replicate/compartment/state ",
                   "observation(s); values are never aggregated implicitly."),
            sum(dup)))
        return(NULL)
    }
    first <- !duplicated(key)
    wide <- data.frame(event = x$event[first], time = x$time[first],
                       replicate = x$replicate[first],
                       stringsAsFactors = FALSE)
    ukey <- key[first]
    for (s in KINETIC_VARS) {
        sel <- kstate == s
        wide[[s]] <- x$abundance[sel][match(ukey, key[sel])]
    }
    missing_state <- is.na(match(ukey, key[kstate == "N"])) |
        is.na(match(ukey, key[kstate == "N_s"])) |
        is.na(match(ukey, key[kstate == "C"])) |
        is.na(match(ukey, key[kstate == "C_s"]))
    if (any(missing_state)) {
        add("error", "missing states", sprintf(
            paste0("%d sample(s) lack one or more of the four kinetic states ",
                   "(first: event %s, time %s, replicate %s). Missing states ",
                   "are never filled in."),
            sum(missing_state), wide$event[missing_state][1],
            format(wide$time[missing_state][1]),
            wide$replicate[missing_state][1]))
        return(NULL)
    }
    wide
}

.check_wide_values <- function(w, add) {
    if (anyNA(w$event) || anyNA(w$replicate)) {
        add("error", "identifiers", "Missing values in event or replicate.")
        return(NULL)
    }
    if (!is.numeric(w$time) || any(!is.finite(w$time))) {
        add("error", "identifiers",
            "Column 'time' must be numeric with finite values.")
        return(NULL)
    }
    nonnum <- KINETIC_VARS[!vapply(w[KINETIC_VARS], is.numeric, logical(1))]
    if (length(nonnum)) {
        add("error", "states", sprintf(
            "Non-numeric kinetic state column(s): %s.", toString(nonnum)))
        return(NULL)
    }
    vals <- as.matrix(w[KINETIC_VARS])
    if (any(!is.finite(vals))) {
        bad_rows <- which(rowSums(!is.finite(vals)) > 0L)
        add("error", "missing states", sprintf(
            paste0("%d sample(s) contain missing or non-finite state values ",
                   "(first: event %s, time %s, replicate %s). Missing states ",
                   "are never filled in; remove or complete these samples ",
                   "explicitly."),
            length(bad_rows), w$event[bad_rows[1]],
            format(w$time[bad_rows[1]]), w$replicate[bad_rows[1]]))
    }
    key <- paste(w$event, w$time, w$replicate, sep = "\r")
    if (anyDuplicated(key)) {
        add("error", "duplicates", sprintf(
            "%d duplicated event/time/replicate sample(s).",
            sum(duplicated(key))))
    }
    if (any(vals < 0, na.rm = TRUE)) {
        add("warning", "negative abundances", .NEGATIVE_WARNING)
    }

    events <- unique(as.character(w$event))
    design <- do.call(rbind, lapply(events, function(ev) {
        d <- w[as.character(w$event) == ev, , drop = FALSE]
        tt <- sort(unique(d$time))
        nk <- as.integer(table(factor(d$time, levels = tt)))
        if (length(tt) < 2L) {
            add("error", "time points", sprintf(
                paste0("Event %s has %d distinct time point(s); at least two ",
                       "are required."),
                ev, length(tt)), ev)
        }
        if (length(tt) >= 1L && all(nk < 2L)) {
            add("error", "replication", sprintf(
                paste0("Event %s has no time point with at least two ",
                       "replicates; the within-time covariance cannot be ",
                       "estimated."),
                ev), ev)
        }
        if (is.unsorted(d$time)) {
            add("info", "time order", sprintf(
                paste0("Event %s: rows are not sorted by time (they are ",
                       "sorted internally by the core)."),
                ev), ev)
        }
        if (length(unique(nk)) > 1L) {
            add("info", "replication", sprintf(
                "Event %s: unequal replication across time points (%s).",
                ev, paste(nk, collapse = ", ")), ev)
        }
        if (any(nk == 1L) && any(nk >= 2L)) {
            add("info", "replication", sprintf(
                paste0("Event %s: time point(s) %s have a single replicate; ",
                       "the pooled within-time covariance is used there."),
                ev, toString(format(tt[nk == 1L]))), ev)
        }
        if (length(tt) == 2L) {
            add("info", "time points", sprintf(
                paste0("Event %s has exactly two time points (four balance ",
                       "equations for seven parameters)."),
                ev), ev)
        }
        data.frame(event = ev, n_samples = nrow(d), n_times = length(tt),
                   min_replicates = min(nk), max_replicates = max(nk),
                   first_time = min(tt), last_time = max(tt),
                   stringsAsFactors = FALSE)
    }))
    design
}

.t_star_info <- function(w, t_star, add) {
    for (ev in unique(as.character(w$event))) {
        tt <- w$time[as.character(w$event) == ev]
        .t_star_event(ev, min(tt), max(tt), t_star, add)
    }
}

.t_star_event <- function(ev, first, last, t_star, add) {
    if (t_star <= first) {
        add("warning", "t_star", sprintf(paste0(
            "Event %s: t_star = %s is at or before the first sample (%s). ",
            "The transcription input is zero in every sampled interval, so ",
            "the transcription rate R is not estimable: its design column is ",
            "identically zero, R is fitted as 0 and the condition number is ",
            "infinite by construction. Inference proceeds unchanged."),
            ev, format(t_star), format(first)), ev)
    }
    if (t_star >= last) {
        add("warning", "t_star", sprintf(paste0(
            "Event %s: t_star = %s is at or after the last sample (%s). ",
            "Transcription is active throughout the sampled window, so no ",
            "post-intervention interval is observed and the fit is the same ",
            "as for continuous transcription (t_star = NULL). Inference ",
            "proceeds unchanged."),
            ev, format(t_star), format(last)), ev)
    }
}

.canonical_wide <- function(x, format, columns) {
    if (!is.null(columns)) {
        idx <- match(unname(columns), names(x))
        names(x)[idx] <- names(columns)
    }
    w <- if (format == "wide") {
        as.data.frame(x[, c(.ID_COLS, KINETIC_VARS)], stringsAsFactors = FALSE)
    } else {
        .long_to_wide(x, function(...) NULL)
    }
    w$event <- as.character(w$event)
    w$time <- as.numeric(w$time)
    w$replicate <- as.character(w$replicate)
    for (s in KINETIC_VARS) w[[s]] <- as.numeric(w[[s]])
    rownames(w) <- NULL
    w
}

# Rows of one event, in input order, as passed to the frozen core.
.event_data <- function(x, event) {
    d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
    d <- d[d$event == event, c("time", "replicate", KINETIC_VARS),
           drop = FALSE]
    rownames(d) <- NULL
    d
}


#' @export
print.postexport_data <- function(x, ...) {
    val <- attr(x, "validation")
    d <- val$design
    cat("<postexport_data>", nrow(x), "samples,", length(unique(x$event)),
        "event(s); time unit:", attr(x, "time_unit"), "\n")
    if (!is.null(d)) {
        show <- utils::head(d, 5L)
        for (i in seq_len(nrow(show))) {
            cat(sprintf(paste0("  %s: %d time points (%s..%s), ",
                               "%s replicates per time\n"),
                        show$event[i], show$n_times[i],
                        format(show$first_time[i]), format(show$last_time[i]),
                        if (show$min_replicates[i] == show$max_replicates[i])
                            show$min_replicates[i] else
                            paste0(show$min_replicates[i], "-",
                                   show$max_replicates[i])))
        }
        if (nrow(d) > 5L) cat("  ...", nrow(d) - 5L, "more event(s)\n")
    }
    nw <- nrow(val$warnings)
    ni <- nrow(val$info)
    if (nw + ni > 0L) {
        cat(sprintf("  validation: %d warning(s), %d note(s); see summary()\n",
                    nw, ni))
    }
    invisible(x)
}

#' @export
summary.postexport_data <- function(object, ...) {
    attr(object, "validation")
}

#' @export
print.postexport_validation <- function(x, ...) {
    cat("<postexport_validation>", nrow(x$errors), "error(s),",
        nrow(x$warnings), "warning(s),", nrow(x$info), "note(s)\n")
    show <- function(tab, label) {
        if (!nrow(tab)) return(invisible())
        cat("\n", label, ":\n", sep = "")
        for (i in seq_len(nrow(tab))) {
            cat("  - ", tab$message[i], "\n", sep = "")
        }
    }
    show(x$errors, "Errors")
    show(x$warnings, "Warnings")
    show(x$info, "Diagnostic information")
    invisible(x)
}
