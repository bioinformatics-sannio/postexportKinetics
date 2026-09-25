# Assisted-by: Claude Code (Anthropic)
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


# =============================================================================
# Cross-platform scientific regression policy (used ONLY when the fixture
# provenance differs from the current platform; the strict comparison above is
# unchanged and remains the same-platform check).
#
# Numeric leaves:
#   - integer leaves (ranks, replicate counts): exact;
#   - T, T.obs, RSS0, RSS1, boundary.tolerance, in an object that carries
#     RSS0 and RSS1: |a - e| <= 1e-10 * max(1, |RSS0|, |RSS1|);
#   - IR in such an object: the same absolute bound propagated through
#     IR = (RSS0 - RSS1) / RSS0, i.e. 1e-10 * max(1, |RSS0|, |RSS1|) / |RSS0|;
#   - every other matrix/vector/scalar leaf (normwise):
#       max|a - e| <= 1e-10 * max(1, max|e|).
# Structure (types, classes, names, dims, NA/NaN/Inf pattern, attributes) is
# compared exactly, as in compare_close().
# Boundary classification: for every object carrying T (or T.obs), RSS0 and
# RSS1, the frozen rule T <= 1e-10 * max(1, |RSS0|, |RSS1|) must give the SAME
# decision for actual and expected.
# =============================================================================

CROSS_REL <- 1e-10
RSS_SCALED_LEAVES <- c("T", "T.obs", "RSS0", "RSS1", "boundary.tolerance")

# Fields that depend on random draws in a platform-sensitive way (bootstrap
# draws via MASS::mvrnorm, which depends on LAPACK/BLAS; simulated assay
# noise); reported, never compared, across platforms (level C).
BOOT_FIELDS <- c("T.boot", "bootstrap.condition", "bootstrap.rank", "p.value",
                 "atom.zero", "bootstrap.failure.rate", "n.bootstrap.valid",
                 "bootstrap.condition.median", "bootstrap.condition.q95",
                 "bootstrap.condition.max",
                 "bootstrap.rank.deficient.fraction",
                 # Simulated assay noise (Phase 3): count and Ct draws are
                 # value dependent, so noisy observations computed from
                 # latent states that differ at rounding level are
                 # platform-sensitive stochastic output (level C).
                 "observed")

# Deliberately extreme-conditioning fixture families (numerical stress tests).
EXTREME_PATTERN <- "lambda=none|/none$|indefinite_Sigma|/rank1/|/zero_diag/"

is_extreme_case <- function(key) grepl(EXTREME_PATTERN, key)

frozen_boundary <- function(x) {
  Tv <- if (!is.null(x$T)) x$T else x$T.obs
  Tv <= 1e-10 * max(1, abs(x$RSS0), abs(x$RSS1))
}

has_rss_context <- function(x) {
  is.list(x) && all(c("RSS0", "RSS1") %in% names(x)) &&
    is.numeric(x$RSS0) && is.numeric(x$RSS1) &&
    length(x$RSS0) == 1L && length(x$RSS1) == 1L &&
    is.finite(x$RSS0) && is.finite(x$RSS1)
}

compare_cross <- function(actual, expected, path = "<root>", ctx = list()) {
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
    add("class differs")
    return(problems)
  }
  for (a in union(names(attributes(actual)), names(attributes(expected)))) {
    if (a == "class") next
    if (!identical(attr(actual, a), attr(expected, a))) {
      add(sprintf("attribute '%s' differs", a))
    }
  }
  if (length(actual) != length(expected)) {
    add(sprintf("length %d vs expected %d", length(actual), length(expected)))
    return(problems)
  }

  if (is.list(expected)) {
    if (has_rss_context(expected)) {
      ctx$rss_scale <- max(1, abs(expected$RSS0), abs(expected$RSS1))
      ctx$RSS0 <- expected$RSS0
      if (any(c("T", "T.obs") %in% names(expected))) {
        if (!has_rss_context(actual) ||
            !identical(frozen_boundary(actual), frozen_boundary(expected))) {
          add("boundary classification differs")
        }
      }
    }
    for (i in seq_along(expected)) {
      nm <- names(expected)[i]
      child <- if (!is.null(nm) && nzchar(nm)) nm else paste0("[[", i, "]]")
      cctx <- ctx
      cctx$name <- child
      problems <- c(problems,
                    compare_cross(actual[[i]], expected[[i]],
                                  paste0(path, "$", child), cctx))
    }
    return(problems)
  }

  if (is.numeric(expected)) {
    a <- as.vector(actual)
    e <- as.vector(expected)
    if (!identical(is.na(a), is.na(e)) || !identical(is.nan(a), is.nan(e))) {
      add("NA/NaN pattern differs")
      return(problems)
    }
    inf_e <- !is.na(e) & is.infinite(e)
    inf_a <- !is.na(a) & is.infinite(a)
    if (!identical(inf_a, inf_e) || !identical(a[inf_e], e[inf_e])) {
      add("finite/infinite pattern differs")
      return(problems)
    }
    if (is.integer(expected)) {
      if (!identical(actual, expected)) add("integer values differ")
      return(problems)
    }
    fin <- !is.na(e) & !inf_e
    if (!any(fin)) return(problems)
    nm <- if (is.null(ctx$name)) "" else ctx$name
    lim <- if (!is.null(ctx$rss_scale) && nm %in% RSS_SCALED_LEAVES) {
      CROSS_REL * ctx$rss_scale
    } else if (!is.null(ctx$rss_scale) && identical(nm, "IR") &&
               abs(ctx$RSS0) > 0) {
      CROSS_REL * ctx$rss_scale / abs(ctx$RSS0)
    } else {
      CROSS_REL * max(1, max(abs(e[fin])))
    }
    d <- max(abs(a[fin] - e[fin]))
    if (d > lim) {
      add(sprintf("max abs diff %.3g exceeds scale-aware bound %.3g", d, lim))
    }
    return(problems)
  }

  if (!identical(actual, expected)) add("values differ")
  problems
}

# Largest difference over numeric leaves, each scaled by max(1, max|e|).
max_scaled_diff <- function(actual, expected) {
  if (is.list(expected)) {
    if (!is.list(actual) || length(actual) != length(expected)) return(Inf)
    d <- vapply(seq_along(expected),
                function(i) max_scaled_diff(actual[[i]], expected[[i]]),
                numeric(1))
    return(if (length(d)) max(d) else 0)
  }
  if (!is.numeric(expected) || !is.numeric(actual) ||
      length(actual) != length(expected)) {
    return(if (identical(actual, expected)) 0 else Inf)
  }
  ok <- is.finite(expected) & is.finite(actual)
  if (!any(ok)) return(0)
  max(abs(actual[ok] - expected[ok])) / max(1, max(abs(expected[ok])))
}

# Condition number of the symmetric matrices involved in a case: square
# matrices of the expected output, and square matrices of the input arguments
# after the frozen relative eigenvalue floor (as applied by make_spd()).
case_kappa <- function(case, expected_value) {
  mats <- list()
  collect <- function(x, floored, rf) {
    if (is.list(x)) {
      for (el in x) collect(el, floored, rf)
    } else if (is.matrix(x) && is.numeric(x) && nrow(x) == ncol(x) &&
               nrow(x) >= 2L && all(is.finite(x))) {
      mats[[length(mats) + 1L]] <<- list(M = (x + t(x)) / 2, floored = floored,
                                          rf = rf)
    }
  }
  rf <- case$input$args$rel_floor
  if (is.null(rf)) rf <- 1e-8
  collect(expected_value, FALSE, rf)
  collect(case$input$args, TRUE, rf)
  k <- vapply(mats, function(m) {
    ev <- eigen(m$M, symmetric = TRUE, only.values = TRUE)$values
    if (m$floored) {
      d <- diag(m$M)
      pd <- d[is.finite(d) & d > 0]
      ref <- if (length(pd)) stats::median(pd) else
        stats::median(abs(m$M[m$M != 0]))
      ev <- pmax(ev, max(ref * m$rf, .Machine$double.xmin))
    }
    if (min(ev) <= 0) return(NA_real_)
    max(ev) / min(ev)
  }, numeric(1))
  k <- k[is.finite(k)]
  if (length(k)) max(k) else NA_real_
}

# Assess one captured result (list(value=) or list(error=)) under the
# cross-platform policy. Returns blocking problems and non-blocking notes.
assess_cross <- function(actual, expected, key, case = NULL) {
  if (!is.null(expected$error) || !is.null(actual$error)) {
    if (!identical(actual$error, expected$error)) {
      return(list(blocking = "error condition differs", notes = character()))
    }
    return(list(blocking = character(), notes = character()))
  }
  av <- actual$value
  ev <- expected$value
  notes <- character()
  if (is.list(ev) && !is.data.frame(ev) && any(BOOT_FIELDS %in% names(ev))) {
    bf <- intersect(BOOT_FIELDS, names(ev))
    d <- max_scaled_diff(av[bf], ev[bf])
    if (d > 0) {
      notes <- c(notes, sprintf(
        "bootstrap-draw-dependent fields differ (max scaled diff %.3g); not compared across platforms",
        d))
    }
    keep_a <- setdiff(names(av), bf)
    keep_e <- setdiff(names(ev), bf)
    av <- av[keep_a]
    ev <- ev[keep_e]
  }
  probs <- compare_cross(av, ev)
  boundary <- grep("boundary classification differs", probs, value = TRUE)
  other <- setdiff(probs, boundary)
  if (length(other) && is_extreme_case(key)) {
    d <- max_scaled_diff(av, ev)
    kap <- if (is.null(case)) NA_real_ else case_kappa(case, ev)
    bound <- 100 * kap * .Machine$double.eps
    if (is.finite(d) && is.finite(bound) && d <= bound) {
      notes <- c(notes, sprintf(
        "extreme-conditioning fixture: max scaled diff %.3g <= 100*kappa*eps = %.3g (kappa = %.3g); reported, not blocking",
        d, bound, kap))
      other <- character()
    } else {
      other <- c(other, sprintf(
        "extreme-conditioning fixture: diff %.3g not consistent with conditioning bound %.3g",
        d, bound))
    }
  }
  list(blocking = c(boundary, other), notes = notes)
}
