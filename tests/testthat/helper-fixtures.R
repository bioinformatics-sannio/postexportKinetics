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
# differ across LAPACK/BLAS builds. Exact bootstrap comparisons are therefore
# run only on a platform matching the one that generated the fixtures.
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

skip_if_platform_differs <- function(prov) {
  if (!fixture_platform_matches(prov)) {
    testthat::skip(paste(
      "Platform differs from fixture platform; bootstrap draws depend on",
      "LAPACK/BLAS through MASS::mvrnorm(). See PACKAGE_PLAN.md section 9.2."
    ))
  }
}
