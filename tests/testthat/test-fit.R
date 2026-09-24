# Regression: whitened NNLS full/null fits, statistic and diagnostics against
# the frozen core. Tolerance tier T2; ranks are integers and compared exactly
# (class integer is enforced by compare_close()).

fx <- read_fixture("fx_fit")

test_that("fit_nnls_nested_once() matches the frozen core", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_regression(run_case(case), case$output, TOL_T2, key,
                      fx$provenance, case)
  }
})

test_that("malformed systems return NULL as in the frozen core", {
  for (nm in c("dimension_mismatch", "non_finite_A", "non_finite_b")) {
    case <- fx$cases[[sprintf("fit_nnls_nested_once/malformed/%s", nm)]]
    expect_null(case$output$value)
    expect_null(run_case(case)$value)
  }
})

test_that("statistic is max(0, RSS0 - RSS1) and coefficients are non-negative", {
  for (key in names(fx$cases)) {
    out <- run_case(fx$cases[[key]])$value
    if (is.null(out)) next
    expect_identical(out$T, max(0, out$RSS0 - out$RSS1))
    expect_true(all(out$coef_full_scaled >= 0))
    expect_true(all(out$coef_null_scaled >= 0))
  }
})

test_that("zero R column gives infinite condition number and rank 6", {
  out <- run_case(fx$cases[[
    "fit_nnls_nested_once/basic/t_star=0/scaling=TRUE/rel_floor=1e-08"]])$value
  expect_identical(out$condition_number, Inf)
  expect_identical(out$rank_full, 6L)
})
