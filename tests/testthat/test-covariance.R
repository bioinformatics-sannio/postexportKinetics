# Regression: within-time covariance estimation, shrinkage, stabilisation and
# propagation structures against the frozen core.
#   time_summary_cov_shrink(): T2 (make_spd eigendecomposition)
#   build_sigma_means(), build_difference_matrix(): T0 (copying / constants)

fx <- read_fixture("fx_covariance")

tier_for <- function(key) {
  if (startsWith(key, "time_summary_cov_shrink/")) TOL_T2 else TOL_T0
}

test_that("covariance components match the frozen core", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_case(run_case(case), case$output, tier_for(key), key)
  }
})

test_that("frozen error conditions are reproduced", {
  errs <- Filter(function(x) !is.null(x$output$error), fx$cases)
  expect_true(length(errs) >= 6L)
  msgs <- vapply(errs, function(x) x$output$error, character(1))
  expect_true(any(grepl("At least two time points", msgs)))
  expect_true(any(grepl("Insufficient replication", msgs)))
  expect_true(any(grepl("No complete observations at time", msgs)))
  expect_true(any(grepl("Missing columns", msgs)))
  expect_true(any(grepl("K must be at least 2", msgs)))
})

test_that("a time point with one replicate uses the pooled covariance", {
  key <- "time_summary_cov_shrink/single_rep_time/default"
  out <- run_case(fx$cases[[key]])$value
  expect_identical(out$n_rep, c(3L, 3L, 3L, 1L, 3L))
  expect_close(out$cov_obs[["40"]], out$pooled_cov, TOL_T2)
})

test_that("rows with a missing state are dropped per time point", {
  key <- "time_summary_cov_shrink/na_row/default"
  out <- run_case(fx$cases[[key]])$value
  expect_identical(out$n_rep, c(3L, 3L, 3L, 3L, 3L))
})
