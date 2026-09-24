# Regression: make_spd() and inverse_sqrt_matrix() against the frozen core.
# Tolerance tier T2 (eigendecomposition).

fx <- read_fixture("fx_matrix")

test_that("make_spd() and inverse_sqrt_matrix() match the frozen core", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_regression(run_case(case), case$output, TOL_T2, key,
                      fx$provenance, case)
  }
})

test_that("invalid matrices return NULL as in the frozen core", {
  for (nm in c("all_zero", "non_finite", "non_square")) {
    key <- sprintf("make_spd/%s/rel_floor=1e-08", nm)
    expect_null(fx$cases[[key]]$output$value)
    expect_null(run_case(fx$cases[[key]])$value)
  }
})

test_that("make_spd() floor is scale equivariant", {
  S <- fx$cases[["make_spd/spd/rel_floor=1e-08"]]$input$args$S
  for (s in c(1e-20, 1, 1e12)) {
    expect_close(make_spd(S * s) / s, make_spd(S), TOL_T2)
  }
})
