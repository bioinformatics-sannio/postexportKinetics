# =============================================================================
# Regression comparison helpers
#
# compare_close() compares an actual object with a frozen reference:
#   - structure must match exactly: type/class, names, dim, dimnames, length,
#     NA/NaN/Inf pattern, and all non-structural attributes;
#   - non-numeric leaves must be identical;
#   - finite numeric leaves must satisfy, ELEMENTWISE,
#       |actual - expected| <= abs + rel * |expected|.
# This is stricter than testthat::expect_equal(tolerance =), whose tolerance
# is a mean relative difference.
#
# Tolerance tiers (PACKAGE_PLAN.md section 9.2):
#   TOL_T0: exact
#   TOL_T1: 1e-12 relative, pure arithmetic without decompositions
#   TOL_T2: 1e-10 relative, quantities through eigen/svd/solve/NNLS
# =============================================================================

TOL_T0 <- c(rel = 0, abs = 0)
TOL_T1 <- c(rel = 1e-12, abs = 1e-14)
TOL_T2 <- c(rel = 1e-10, abs = 1e-14)

structural_attrs <- c("names", "dim", "dimnames")

compare_close <- function(actual, expected, tol = TOL_T2, path = "<root>") {
  problems <- character()
  add <- function(msg) problems <<- c(problems, paste0(path, ": ", msg))

  if (is.null(expected)) {
    if (!is.null(actual)) add("expected NULL")
    return(problems)
  }

  if (!identical(typeof(actual), typeof(expected))) {
    add(sprintf("typeof %s vs expected %s", typeof(actual), typeof(expected)))
    return(problems)
  }

  if (!identical(class(actual), class(expected))) {
    add(sprintf("class %s vs expected %s",
                paste(class(actual), collapse = "/"),
                paste(class(expected), collapse = "/")))
    return(problems)
  }

  for (a in structural_attrs) {
    if (!identical(attr(actual, a), attr(expected, a))) {
      add(sprintf("attribute '%s' differs", a))
    }
  }

  other <- setdiff(union(names(attributes(actual)), names(attributes(expected))),
                   c(structural_attrs, "class"))
  for (a in other) {
    if (!identical(attr(actual, a), attr(expected, a))) {
      add(sprintf("attribute '%s' differs", a))
    }
  }

  if (length(actual) != length(expected)) {
    add(sprintf("length %d vs expected %d", length(actual), length(expected)))
    return(problems)
  }

  if (is.list(expected)) {
    for (i in seq_along(expected)) {
      nm <- names(expected)[i]
      child <- if (!is.null(nm) && nzchar(nm)) nm else paste0("[[", i, "]]")
      problems <- c(problems,
                    compare_close(actual[[i]], expected[[i]], tol,
                                  paste0(path, "$", child)))
    }
    return(problems)
  }

  if (is.numeric(expected) || is.complex(expected)) {
    a <- as.vector(actual)
    e <- as.vector(expected)
    if (!identical(is.na(a), is.na(e)) || !identical(is.nan(a), is.nan(e))) {
      add("NA/NaN pattern differs")
      return(problems)
    }
    inf_e <- !is.na(e) & is.infinite(e)
    inf_a <- !is.na(a) & is.infinite(a)
    if (!identical(inf_a, inf_e) || !identical(a[inf_e], e[inf_e])) {
      add("infinite values differ")
      return(problems)
    }
    fin <- !is.na(e) & !inf_e
    if (any(fin)) {
      d <- abs(a[fin] - e[fin])
      lim <- tol[["abs"]] + tol[["rel"]] * abs(e[fin])
      if (any(d > lim)) {
        rel <- d / pmax(abs(e[fin]), .Machine$double.xmin)
        add(sprintf("max abs diff %.3g, max rel diff %.3g exceeds tolerance",
                    max(d), max(rel)))
      }
    }
    return(problems)
  }

  if (!identical(actual, expected)) add("values differ")
  problems
}

expect_close <- function(actual, expected, tol = TOL_T2, label = "") {
  problems <- compare_close(actual, expected, tol)
  testthat::expect(
    length(problems) == 0L,
    paste0(label, if (nzchar(label)) "\n" else "",
           paste(utils::head(problems, 20), collapse = "\n"))
  )
  invisible(problems)
}

# Largest elementwise differences between two objects (for reporting only).
max_differences <- function(actual, expected) {
  a <- unlist(actual, use.names = FALSE)
  e <- unlist(expected, use.names = FALSE)
  if (!is.numeric(a) || !is.numeric(e) || length(a) != length(e)) {
    return(c(abs = NA_real_, rel = NA_real_))
  }
  ok <- is.finite(a) & is.finite(e)
  if (!any(ok)) return(c(abs = 0, rel = 0))
  d <- abs(a[ok] - e[ok])
  c(abs = max(d), rel = max(d / pmax(abs(e[ok]), .Machine$double.xmin)))
}
