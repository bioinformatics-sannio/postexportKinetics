# Assisted-by: Claude Code (Anthropic)
# =============================================================================
# Frozen-reference fixture helpers
#
# Fixtures are produced exclusively by tools/frozen/make_fixtures.R from the
# frozen tag manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5).
# =============================================================================

FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

# POSTEXPORT_FIXTURE_DIR may point to fixtures regenerated on the current
# platform by tools/frozen/make_fixtures.R (used by CI); by default the
# committed fixtures are used.
fixture_dir <- function() {
  d <- Sys.getenv("POSTEXPORT_FIXTURE_DIR", "")
  if (nzchar(d)) d else testthat::test_path("fixtures")
}

read_fixture <- function(name) {
  path <- file.path(fixture_dir(), paste0(name, ".rds"))
  fx <- readRDS(path)
  stopifnot(identical(fx$provenance$frozen_commit, FROZEN_COMMIT))
  fx
}

pkg_fun <- function(name) {
  get(name, envir = asNamespace("postexportKinetics"), mode = "function")
}

capture <- function(expr) {
  tryCatch(
    list(value = expr),
    error = function(e) list(error = conditionMessage(e))
  )
}

# Run a fixture case through the package implementation of the same function.
run_case <- function(case) {
  capture(do.call(pkg_fun(case$input$fun), case$input$args))
}

# Compare a captured package result with the captured frozen result.
expect_case <- function(actual, expected, tol, label) {
  if (!is.null(expected$error)) {
    testthat::expect(
      identical(actual$error, expected$error),
      sprintf("%s\nexpected error: %s\nactual: %s", label, expected$error,
              if (is.null(actual$error)) "<no error>" else actual$error)
    )
  } else {
    testthat::expect(
      is.null(actual$error),
      sprintf("%s\nunexpected error: %s", label, actual$error)
    )
    expect_close(actual$value, expected$value, tol, label)
  }
}

# Bootstrap draws use MASS::mvrnorm(), which relies on eigen(); results can
# differ across LAPACK/BLAS builds even under the same R seed. Same-platform
# comparisons (strict, including draws) apply only when the fixture
# provenance matches the current platform exactly.
fixture_platform_matches <- function(prov) {
  identical(prov$La_library, La_library()) &&
    identical(prov$La_version, La_version()) &&
    identical(prov$BLAS, unname(extSoftVersion()["BLAS"])) &&
    identical(prov$sysname, unname(Sys.info()["sysname"])) &&
    identical(prov$machine, unname(Sys.info()["machine"])) &&
    identical(prov$packages[["MASS"]],
              as.character(utils::packageVersion("MASS"))) &&
    identical(prov$packages[["nnls"]],
              as.character(utils::packageVersion("nnls"))) &&
    identical(prov$RNGkind, RNGkind())
}

# =============================================================================
# Regression level selection (PACKAGE_PLAN.md section 9.2; policy approved in
# review of PHASE1_5_REPORT.md):
#
#   A. same-platform (fixture provenance matches the current platform):
#      strict tiers via expect_case(); blocking; unchanged.
#   B. cross-platform (provenance differs): scale-aware scientific policy via
#      assess_cross(); blocking for scientific invariants.
#   C. deliberately extreme-conditioning fixtures across platforms: differences
#      consistent with conditioning are reported, not blocking; boundary
#      decisions remain blocking.
#
# POSTEXPORT_FORCE_CROSS_PLATFORM=true forces level B/C even when provenance
# matches; it exists only to exercise the cross-platform policy locally and is
# never set in CI.
# =============================================================================

regression_level <- function(prov) {
  if (identical(Sys.getenv("POSTEXPORT_FORCE_CROSS_PLATFORM"), "true")) {
    return("cross-platform")
  }
  if (fixture_platform_matches(prov)) "same-platform" else "cross-platform"
}

# Non-blocking cross-platform notes are appended to the file named by
# POSTEXPORT_PLATFORM_NOTES (CI prints it); otherwise they are discarded.
record_platform_notes <- function(label, notes) {
  f <- Sys.getenv("POSTEXPORT_PLATFORM_NOTES", "")
  if (!length(notes) || !nzchar(f)) return(invisible())
  cat(paste0(label, ": ", notes, "\n"), file = f, append = TRUE, sep = "")
  invisible()
}

expect_regression <- function(actual, expected, tol, label, prov, case = NULL) {
  if (identical(regression_level(prov), "same-platform")) {
    return(expect_case(actual, expected, tol, label))
  }
  res <- assess_cross(actual, expected, label, case)
  record_platform_notes(label, res$notes)
  testthat::expect(
    length(res$blocking) == 0L,
    paste0(label, " [cross-platform scientific policy]\n",
           paste(utils::head(res$blocking, 20), collapse = "\n"))
  )
}

# Bootstrap draws: blocking only at the same-platform level. Across platforms
# the draws are compared for the record and the test is skipped with the
# measured difference in the reason.
skip_bootstrap_across_platforms <- function(prov, summary = NULL) {
  if (identical(regression_level(prov), "same-platform")) return(invisible())
  testthat::skip(paste0(
    "Cross-platform: bootstrap draws depend on LAPACK/BLAS through ",
    "MASS::mvrnorm(); compared only against same-platform fixtures",
    if (!is.null(summary)) paste0(" (", summary, ")") else "",
    "."
  ))
}


# The manuscript's shutoff designs sample at t_star itself (t_star = first
# sample), which triggers the approved non-blocking t_star design warning.
# Regression tests that reproduce those designs muffle exactly that warning;
# dedicated tests check that it is emitted.
T_STAR_WARNING <- "t_star = .* is at or (before the first|after the last) sample"

quiet_tstar <- function(expr) {
    withCallingHandlers(expr, warning = function(w) {
        if (grepl(T_STAR_WARNING, conditionMessage(w))) {
            invokeRestart("muffleWarning")
        }
    })
}
