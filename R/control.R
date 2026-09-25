# =============================================================================
# Public control object: postexport_control()
#
# Numerical and inferential settings of the frozen implementation
# (commons/nested_test2.r::test_sigma_nested, lines 1447-1475). Defaults are
# the frozen defaults. The frozen compatibility alias `lambda_var` and the
# unused `verbose` argument are deliberately not exposed.
# =============================================================================

.FROZEN_CONTROL_DEFAULTS <- list(
    B = 1999L,
    seed = NULL,
    lambda_time = 0.5,
    lambda_diag = 0.1,
    rel_floor = 1e-8,
    max_failure_rate = 0.05,
    scaling_A = TRUE,
    truncate_nonnegative_boot = FALSE
)


#' Numerical and inferential settings
#'
#' Collects the settings passed to the frozen numerical core. All defaults
#' are those of the frozen manuscript implementation (tag
#' `manuscript-revision-v1.0`); results obtained with the defaults are the
#' manuscript procedure. The intervention time `t_star` is a property of the
#' experimental design and is therefore an explicit argument of
#' [fit_postexport_model()] and [test_postexport_conversion()], not a control
#' setting.
#'
#' @param B Number of bootstrap replicates. Frozen default `1999`. The
#'   bootstrap p-value is `(1 + #{T* >= T_obs}) / (B_valid + 1)`, so `B`
#'   determines its resolution and Monte-Carlo error; it does not change the
#'   observed fit. Used by [test_postexport_conversion()] only.
#' @param seed `NULL` (frozen default: the random-number generator is not
#'   reset) or an integer seed passed to [set.seed()] immediately before the
#'   observed fit, exactly as in the frozen implementation. For several events,
#'   a named integer vector with one seed per event. A fixed seed reproduces
#'   the bootstrap draws within a matched numerical environment; across
#'   LAPACK/BLAS builds the draws can differ because the frozen bootstrap uses
#'   [MASS::mvrnorm()]. The frozen implementation calls [set.seed()]; the
#'   public API saves the caller's random-number state before and restores
#'   it afterwards, so an explicit seed leaves the global state unchanged
#'   (the result is not affected). With `seed = NULL` the global stream is
#'   used and consumed, as in the frozen implementation.
#' @param lambda_time Shrinkage of each time point's within-time covariance
#'   towards the pooled covariance, in `[0, 1]`. Frozen default `0.5`.
#'   Changing it changes the estimated covariance, the whitening and hence the
#'   fit, the statistic and the p-value.
#' @param lambda_diag Shrinkage of the pooled within-time covariance towards
#'   its diagonal, in `[0, 1]`. Frozen default `0.1`. Changing it changes the
#'   statistical behaviour as for `lambda_time`.
#' @param rel_floor Relative eigenvalue floor used to stabilise covariance
#'   matrices (eigenvalues are raised to `rel_floor` times the median positive
#'   diagonal element). Frozen default `1e-8`. It only matters for
#'   near-singular covariances; changing it can change the fit in such cases.
#' @param max_failure_rate Largest acceptable fraction of failed bootstrap
#'   replicates, in `[0, 1]`. Frozen default `0.05`. If exceeded, the p-value
#'   is `NA` with status `"bootstrap_unstable"`. It does not change p-values
#'   that are reported.
#' @param scaling_A **Advanced option.** Logical; scale the design-matrix
#'   columns to unit norm before the NNLS fits. Frozen default `TRUE`. This
#'   is a numerical conditioning step (coefficients are returned on the
#'   original scale), but it changes the floating-point path of the fits and
#'   can change results for ill-conditioned designs. Changing it changes the
#'   analysis relative to the manuscript procedure.
#' @param truncate_nonnegative_boot **Advanced option.** Logical; set
#'   negative values of simulated bootstrap samples to zero. Frozen default
#'   `FALSE`. Changing it changes the bootstrap null distribution, hence the
#'   p-value, and therefore the analysis relative to the manuscript
#'   procedure.
#'
#' @section Advanced options:
#' `scaling_A` and `truncate_nonnegative_boot` exist in the frozen
#' implementation and are exposed for completeness. Their frozen defaults
#' define the manuscript procedure; non-default values change the analysis.
#' `print()` flags every setting that differs from the frozen default.
#'
#' @return An object of class `postexport_control` (a named list).
#'
#' @seealso [fit_postexport_model()], [test_postexport_conversion()]
#'
#' @examples
#' postexport_control()
#' postexport_control(B = 199, seed = 1)
#'
#' @export
postexport_control <- function(B = 1999L, seed = NULL, lambda_time = 0.5,
                               lambda_diag = 0.1, rel_floor = 1e-8,
                               max_failure_rate = 0.05, scaling_A = TRUE,
                               truncate_nonnegative_boot = FALSE) {
    is_scalar_num <- function(v) {
        is.numeric(v) && length(v) == 1L && is.finite(v)
    }
    if (!is_scalar_num(B) || B < 1 || B != round(B)) {
        stop("'B' must be a single positive whole number.", call. = FALSE)
    }
    if (!is.null(seed)) {
        if (!is.numeric(seed) || !length(seed) || any(!is.finite(seed)) ||
            any(seed != round(seed))) {
            stop("'seed' must be NULL or whole number(s).", call. = FALSE)
        }
        if (length(seed) > 1L &&
            (is.null(names(seed)) || any(!nzchar(names(seed))) ||
             anyDuplicated(names(seed)))) {
            stop("Several seeds must be given as a named vector ",
                 "(one seed per event, named by event).", call. = FALSE)
        }
    }
    for (nm in c("lambda_time", "lambda_diag", "max_failure_rate")) {
        v <- get(nm)
        if (!is_scalar_num(v) || v < 0 || v > 1) {
            stop(sprintf("'%s' must be a single number in [0, 1].", nm),
                 call. = FALSE)
        }
    }
    if (!is_scalar_num(rel_floor) || rel_floor <= 0) {
        stop("'rel_floor' must be a single positive number.", call. = FALSE)
    }
    for (nm in c("scaling_A", "truncate_nonnegative_boot")) {
        v <- get(nm)
        if (!is.logical(v) || length(v) != 1L || is.na(v)) {
            stop(sprintf("'%s' must be TRUE or FALSE.", nm), call. = FALSE)
        }
    }
    structure(
        list(B = as.integer(B), seed = seed, lambda_time = lambda_time,
             lambda_diag = lambda_diag, rel_floor = rel_floor,
             max_failure_rate = max_failure_rate, scaling_A = scaling_A,
             truncate_nonnegative_boot = truncate_nonnegative_boot),
        class = "postexport_control"
    )
}

.control_differences <- function(control) {
    nm <- names(.FROZEN_CONTROL_DEFAULTS)
    same <- vapply(nm, function(k) {
        v <- control[[k]]
        d <- .FROZEN_CONTROL_DEFAULTS[[k]]
        identical(v, d) ||
            (is.numeric(v) && is.numeric(d) && isTRUE(all.equal(v, d)))
    }, logical(1))
    nm[!same]
}

#' @export
print.postexport_control <- function(x, ...) {
    diff <- .control_differences(x)
    cat("<postexport_control>",
        if (length(diff)) "non-default settings:" else
            "frozen manuscript defaults", toString(diff), "\n")
    for (k in names(.FROZEN_CONTROL_DEFAULTS)) {
        v <- x[[k]]
        shown <- if (is.null(v)) "NULL" else paste(format(v), collapse = ", ")
        cat(sprintf("  %-26s %s%s\n", k, shown,
                    if (k %in% diff) "  (frozen default differs)" else ""))
    }
    invisible(x)
}
