#' Create post-export kinetics data from a SummarizedExperiment
#'
#' Converts an already state-resolved `SummarizedExperiment` (layout A) into
#' the canonical [postexport_data()] object. This is an interoperability
#' input path only. All data validation is delegated to [postexport_data()]
#' (and so to [validate_postexport_data()]), and the result is exactly the
#' object that [postexport_data()] returns for the equivalent wide table.
#'
#' @section Layout A:
#' \itemize{
#'   \item rows are events; `rownames(se)` gives `event`;
#'   \item columns are destructive samples;
#'     `colData(se)[[time]]` gives `time` and `colData(se)[[replicate]]`
#'     gives `replicate`;
#'   \item four assays hold the state-resolved abundances, mapped directly by
#'     `assays` to `N` (nuclear unprocessed), `N_s` (nuclear processed), `C`
#'     (cytoplasmic unprocessed) and `C_s` (cytoplasmic processed).
#' }
#' Each (event, sample) cell becomes one row of the wide table, ordered by
#' event (row order of `se`) and then by sample (column order of `se`).
#' `rowData`, `metadata` and other `colData` columns and assays are ignored.
#'
#' @section What the converter does not do:
#' It expects an object that already holds the four states per destructive
#' sample. It does **not** pair nuclear and cytoplasmic libraries, normalise
#' counts, convert rMATS output, or decide which quantity is "unprocessed"
#' or "processed" (for example inclusion versus skipping of a retained
#' intron). These are analysis decisions made before conversion. Missing
#' values are never zero-filled: they are errors, exactly as in
#' [postexport_data()].
#'
#' @param se A `SummarizedExperiment` (or a subclass such as
#'   `RangedSummarizedExperiment`) with events as rows and destructive samples
#'   as columns.
#' @param time_unit Character string naming the unit of `time` (for example
#'   `"min"`); passed to [postexport_data()].
#' @param assays Named character vector mapping the four states `N`, `N_s`,
#'   `C` and `C_s` to assay names of `se`.
#' @param time Name of the `colData(se)` column holding the sampling time.
#' @param replicate Name of the `colData(se)` column holding the replicate
#'   label within a time point.
#'
#' @return A `postexport_data` object, identical to
#'   `postexport_data(<wide table>, time_unit)` for the corresponding wide
#'   table.
#'
#' @seealso [postexport_data()], [validate_postexport_data()],
#'   [SummarizedExperiment::SummarizedExperiment()]
#'
#' @examples
#' # Build a layout-A SummarizedExperiment from the synthetic example data.
#' data(postexport_example)
#' ex <- postexport_example
#' events <- unique(ex$event)
#' samples <- unique(ex[, c("time", "replicate")])
#' rownames(samples) <- sprintf("t%g_r%d", samples$time, samples$replicate)
#' cell <- cbind(match(ex$event, events),
#'               match(paste(ex$time, ex$replicate),
#'                     paste(samples$time, samples$replicate)))
#' state_matrix <- function(state) {
#'     m <- matrix(NA_real_, length(events), nrow(samples),
#'                 dimnames = list(events, rownames(samples)))
#'     m[cell] <- ex[[state]]
#'     m
#' }
#' se <- SummarizedExperiment::SummarizedExperiment(
#'     assays = list(N = state_matrix("N"), N_s = state_matrix("N_s"),
#'                   C = state_matrix("C"), C_s = state_matrix("C_s")),
#'     colData = samples)
#' x <- postexport_data_from_se(se, time_unit = "min")
#' x
#'
#' @importFrom SummarizedExperiment assay assayNames colData
#' @export
postexport_data_from_se <- function(se, time_unit,
                                    assays = c(N = "N", N_s = "N_s",
                                               C = "C", C_s = "C_s"),
                                    time = "time", replicate = "replicate") {
    if (!inherits(se, "SummarizedExperiment")) {
        stop("'se' must be a SummarizedExperiment (layout A: events as ",
             "rows, destructive samples as columns).", call. = FALSE)
    }
    states <- c("N", "N_s", "C", "C_s")
    if (!is.character(assays) || is.null(names(assays)) ||
        !setequal(names(assays), states) || anyDuplicated(names(assays)) ||
        length(assays) != 4L || anyNA(assays)) {
        stop("'assays' must be a character vector with the names N, N_s, C ",
             "and C_s, each giving an assay name of 'se'.", call. = FALSE)
    }
    for (a in list(time = time, replicate = replicate)) {
        if (!is.character(a) || length(a) != 1L || is.na(a) || !nzchar(a)) {
            stop("'time' and 'replicate' must each be a single colData ",
                 "column name.", call. = FALSE)
        }
    }
    n_events <- nrow(se)
    n_samples <- ncol(se)
    if (n_events == 0L || n_samples == 0L) {
        stop("'se' must have at least one event (row) and one sample ",
             "(column).", call. = FALSE)
    }
    events <- rownames(se)
    if (is.null(events) || anyNA(events) || any(!nzchar(events))) {
        stop("'se' must have non-missing, non-empty rownames (the event ",
             "identifiers).", call. = FALSE)
    }
    if (anyDuplicated(events)) {
        stop("The rownames of 'se' (event identifiers) must be unique.",
             call. = FALSE)
    }
    absent <- setdiff(unname(assays), assayNames(se))
    if (length(absent)) {
        stop(sprintf("Assay(s) not found in 'se': %s.", toString(absent)),
             call. = FALSE)
    }
    cd <- colData(se)
    missing_cd <- setdiff(c(time, replicate), colnames(cd))
    if (length(missing_cd)) {
        stop(sprintf("colData(se) column(s) not found: %s.",
                     toString(missing_cd)), call. = FALSE)
    }
    values <- lapply(states, function(s) {
        m <- as.matrix(assay(se, assays[[s]], withDimnames = FALSE))
        if (!identical(dim(m), c(n_events, n_samples))) {
            stop(sprintf("Assay '%s' has dimensions %s, expected %d x %d.",
                         assays[[s]], paste(dim(m), collapse = " x "),
                         n_events, n_samples), call. = FALSE)
        }
        if (!is.numeric(m)) {
            stop(sprintf("Assay '%s' (state %s) must be numeric.",
                         assays[[s]], s), call. = FALSE)
        }
        as.vector(t(m))
    })
    names(values) <- states
    wide <- data.frame(
        event = rep(events, each = n_samples),
        time = rep(as.vector(cd[[time]]), times = n_events),
        replicate = rep(as.vector(cd[[replicate]]), times = n_events),
        values,
        stringsAsFactors = FALSE
    )
    postexport_data(wide, time_unit = time_unit, format = "wide")
}
