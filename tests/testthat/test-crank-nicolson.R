# Regression: kinetic matrix, Crank-Nicolson step and null trajectory against
# the frozen core. Tolerance tier T1 (small linear solves, no
# eigendecomposition).

fx <- read_fixture("fx_crank_nicolson")

test_that("Crank-Nicolson components match the frozen core", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_case(run_case(case), case$output, TOL_T1, key)
  }
})

test_that("kinetic matrix encodes the four-state ODE", {
  theta <- fx$cases[["kinetic_matrix/typical"]]$input$args$theta
  K <- kinetic_matrix(theta)
  x <- c(N = 3, N_s = 5, C = 7, C_s = 11)
  rhs <- c(
    N = -(theta[["sigma_n"]] + theta[["tau"]]) * x[["N"]],
    N_s = theta[["sigma_n"]] * x[["N"]] - theta[["tau_s"]] * x[["N_s"]],
    C = theta[["tau"]] * x[["N"]] -
      (theta[["sigma_c"]] + theta[["alpha"]]) * x[["C"]],
    C_s = theta[["tau_s"]] * x[["N_s"]] + theta[["sigma_c"]] * x[["C"]] -
      theta[["alpha_s"]] * x[["C_s"]]
  )
  expect_close(drop(K %*% x), rhs, TOL_T1)
})

test_that("predict_null_cn() forces sigma_c to zero", {
  args <- fx$cases[["predict_null_cn/observed/typical/t_star=NULL"]]$input$args
  with_sc <- do.call(predict_null_cn, args)
  args$theta0["sigma_c"] <- 0
  expect_identical(do.call(predict_null_cn, args), with_sc)
})

test_that("Crank-Nicolson agrees with the exact transition to second order", {
  skip_if_not_installed("expm")
  theta <- fx$cases[["kinetic_matrix/typical"]]$input$args$theta
  K <- kinetic_matrix(theta)
  x0 <- c(N = 12.7, N_s = 0.6, C = 3.1, C_s = 0.1)
  err <- vapply(c(1, 0.5, 0.25), function(dt) {
    cn <- cn_interval(x0, dt, theta, R_active_dt = 0)
    ex <- drop(expm::expm(K * dt) %*% x0)
    sqrt(sum((cn - ex)^2)) / sqrt(sum(ex^2))
  }, numeric(1))
  # Local error of the trapezoidal rule is O(dt^3): halving dt divides it by
  # about 8.
  expect_true(all(err[-1] / err[-length(err)] < 0.2))
})
