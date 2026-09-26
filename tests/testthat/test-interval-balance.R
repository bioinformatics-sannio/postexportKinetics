# Assisted-by: Claude Code (Anthropic)
# Regression: interval-balance system (A, b, Sigma_m, D, Sigma_b, col_norms,
# summary) against the frozen core. Tolerance tier T2.

fx <- read_fixture("fx_interval_balance")

test_that("build_Ab_fullcov() matches the frozen core", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_regression(run_case(case), case$output, TOL_T2, key,
                      fx$provenance, case)
  }
})

test_that("transcription input is truncated at t_star only in the R column", {
  case <- fx$cases[["build_Ab_fullcov/basic/t_star=15/scaling=FALSE"]]
  out <- run_case(case)$value
  times <- c(0, 10, 20, 40, 80)
  dt <- diff(times)
  expected_R_dt <- pmax(0, pmin(dt, 15 - times[-5]))
  expect_identical(unname(out$A[1:4, "R"]), expected_R_dt)
  expect_true(all(out$A[-(1:4), "R"] == 0))
})

test_that("t_star at or before the first sample gives a zero R column", {
  for (ts in c("-5", "0")) {
    case <- fx$cases[[sprintf("build_Ab_fullcov/basic/t_star=%s/scaling=TRUE",
                              ts)]]
    out <- run_case(case)$value
    expect_true(all(out$A[, "R"] == 0))
    expect_identical(unname(out$col_norms[1]), 1)
  }
})

test_that("rows are species-major and columns follow PARAM_NAMES", {
  out <- run_case(fx$cases[["build_Ab_fullcov/basic/t_star=NULL/scaling=TRUE"]])$value
  expect_identical(colnames(out$A), PARAM_NAMES)
  expect_identical(nrow(out$A), 4L * 4L)
  X <- out$summary$means
  expect_identical(out$b, c(diff(X[, "N"]), diff(X[, "N_s"]),
                            diff(X[, "C"]), diff(X[, "C_s"])))
})
