# Regression: bootstrap primitives against the frozen core.
#
# 1. simulate_destructive_null() draws under a fixed seed.
# 2. Composition: the ported primitives, called in the frozen order of
#    test_sigma_nested() (commons/nested_test2.r:1501-1985), reproduce the
#    frozen observed statistic, coefficients, null means, every bootstrap
#    statistic T*_b, the add-one p-value and the boundary rule.
#
# The orchestration in compose_frozen_test() is test code that mirrors the
# frozen function; it is not package code (the high-level wrapper is a later
# phase).

fx_boot <- read_fixture("fx_bootstrap")
fx_test <- read_fixture("fx_test_sigma_nested")

compose_frozen_test <- function(d, t_star, B_n, seed, lambda_time = 0.5,
                                lambda_diag = 0.1, rel_floor = 1e-8,
                                truncate_nonnegative_boot = FALSE,
                                max_failure_rate = 0.05) {
  set.seed(seed)
  built <- build_Ab_fullcov(d, TRUE, t_star, lambda_time, lambda_diag,
                            rel_floor)
  fit <- fit_nnls_nested_once(built$A, built$b, built$Sigma_b, 4L, rel_floor)
  coef_full <- fit$coef_full_scaled / built$col_norms
  names(coef_full) <- PARAM_NAMES
  coef_null <- stats::setNames(rep(0, length(PARAM_NAMES)), PARAM_NAMES)
  coef_null[PARAM_NAMES[-4L]] <- fit$coef_null_scaled / built$col_norms[-4L]
  coef_null["sigma_c"] <- 0
  times <- built$summary$times
  null_means <- predict_null_cn(times, built$summary$means[1, KINETIC_VARS],
                                coef_null, t_star)
  T_boot <- rep(NA_real_, B_n)
  failed <- logical(B_n)
  for (bb in seq_len(B_n)) {
    ds <- tryCatch(
      simulate_destructive_null(null_means, built$summary,
                                truncate_nonnegative_boot),
      error = function(e) NULL
    )
    if (is.null(ds)) { failed[bb] <- TRUE; next }
    bs <- tryCatch(
      build_Ab_fullcov(ds, TRUE, t_star, lambda_time, lambda_diag, rel_floor),
      error = function(e) NULL
    )
    if (is.null(bs)) { failed[bb] <- TRUE; next }
    fs <- fit_nnls_nested_once(bs$A, bs$b, bs$Sigma_b, 4L, rel_floor)
    if (is.null(fs) || !is.finite(fs$T)) { failed[bb] <- TRUE; next }
    T_boot[bb] <- fs$T
  }
  valid <- !failed & is.finite(T_boot)
  T_ok <- T_boot[valid]
  tol_zero <- 1e-10 * max(1, abs(fit$RSS0), abs(fit$RSS1))
  p <- if (fit$T <= tol_zero) 1 else (1 + sum(T_ok >= fit$T)) / (length(T_ok) + 1)
  list(T.obs = fit$T, RSS0 = fit$RSS0, RSS1 = fit$RSS1,
       coef_full = coef_full, coef_null = coef_null, null.means = null_means,
       T.boot = T_ok, p.value = p, boundary.tolerance = tol_zero,
       atom.zero = mean(T_ok <= tol_zero),
       failure.rate = mean(!valid))
}

draw_difference_summary <- function() {
  d <- vapply(names(fx_boot$cases), function(key) {
    case <- fx_boot$cases[[key]]
    set.seed(case$input$seed)
    f <- pkg_fun("simulate_destructive_null")
    got <- if (case$input$n_calls == 2L) {
      list(first = capture(do.call(f, case$input$args)),
           second = capture(do.call(f, case$input$args)))
    } else {
      capture(do.call(f, case$input$args))
    }
    ref <- if (case$input$n_calls == 2L) case$output$value else case$output
    max_scaled_diff(got, ref)
  }, numeric(1))
  sprintf("max scaled difference of draws over %d cases: %.3g", length(d),
          max(d))
}

test_that("simulate_destructive_null() reproduces frozen draws", {
  if (!identical(regression_level(fx_boot$provenance), "same-platform")) {
    summary <- draw_difference_summary()
    record_platform_notes("simulate_destructive_null draws", summary)
    skip_bootstrap_across_platforms(fx_boot$provenance, summary)
  }
  for (key in names(fx_boot$cases)) {
    case <- fx_boot$cases[[key]]
    set.seed(case$input$seed)
    f <- pkg_fun("simulate_destructive_null")
    if (case$input$n_calls == 2L) {
      first <- capture(do.call(f, case$input$args))
      second <- capture(do.call(f, case$input$args))
      expect_case(first, case$output$value$first, TOL_T2, paste(key, "first"))
      expect_case(second, case$output$value$second, TOL_T2, paste(key, "second"))
    } else {
      expect_case(capture(do.call(f, case$input$args)), case$output, TOL_T2, key)
    }
  }
})

test_that("bootstrap truncation sets negative draws to zero only when requested", {
  key <- "simulate_destructive_null/basic/truncate=TRUE/seed=1"
  out <- fx_boot$cases[[key]]$output$value$first$value
  expect_true(all(as.matrix(out[, KINETIC_VARS]) >= 0))
})

test_that("a time point with one replicate yields one bootstrap row", {
  key <- "simulate_destructive_null/single_rep_time/truncate=FALSE/seed=1"
  case <- fx_boot$cases[[key]]
  set.seed(case$input$seed)
  out <- do.call(simulate_destructive_null, case$input$args)
  expect_identical(as.integer(table(out$time)), c(3L, 3L, 3L, 1L, 3L))
})

ok_cases <- Filter(function(x) identical(x$output$value$status, "ok"),
                   fx_test$cases)

test_that("composed primitives reproduce the deterministic frozen fit", {
  for (key in names(ok_cases)) {
    case <- ok_cases[[key]]
    frozen <- case$output$value
    got <- compose_frozen_test(case$input$data, case$input$t_star,
                               B_n = 0L, seed = case$input$seed)
    fields <- c("T.obs", "RSS0", "RSS1", "coef_full", "coef_null",
                "null.means", "boundary.tolerance")
    expect_regression(list(value = got[fields]),
                      list(value = frozen[fields]),
                      TOL_T2, paste(key, "deterministic fit"),
                      fx_test$provenance, case)
  }
})

test_that("composed primitives reproduce frozen bootstrap statistics and p-values", {
  if (!identical(regression_level(fx_test$provenance), "same-platform")) {
    d <- vapply(names(ok_cases), function(key) {
      case <- ok_cases[[key]]
      got <- compose_frozen_test(case$input$data, case$input$t_star,
                                 B_n = case$input$B_n, seed = case$input$seed)
      max_scaled_diff(got$T.boot, case$output$value$T.boot)
    }, numeric(1))
    summary <- sprintf("max scaled difference of T* over %d cases: %.3g",
                       length(d), max(d))
    record_platform_notes("composed bootstrap T*", summary)
    skip_bootstrap_across_platforms(fx_test$provenance, summary)
  }
  for (key in names(ok_cases)) {
    case <- ok_cases[[key]]
    frozen <- case$output$value
    got <- compose_frozen_test(case$input$data, case$input$t_star,
                               B_n = case$input$B_n, seed = case$input$seed)
    expect_close(got$T.boot, frozen$T.boot, TOL_T2, paste(key, "T.boot"))
    expect_identical(got$p.value, frozen$p.value, label = paste(key, "p"))
    expect_identical(got$atom.zero, frozen$atom.zero,
                     label = paste(key, "atom.zero"))
    expect_identical(got$failure.rate, frozen$bootstrap.failure.rate,
                     label = paste(key, "failure rate"))
  }
})

test_that("frozen p-values follow the add-one rule and the boundary rule", {
  for (key in names(ok_cases)) {
    o <- ok_cases[[key]]$output$value
    if (o$T.obs <= o$boundary.tolerance) {
      expect_identical(o$p.value, 1)
    } else {
      expect_identical(
        o$p.value,
        (1 + sum(o$T.boot >= o$T.obs)) / (length(o$T.boot) + 1)
      )
    }
    expect_identical(o$atom.zero, mean(o$T.boot <= o$boundary.tolerance))
  }
})

test_that("bootstrap statistics for B = 19 are a prefix of B = 99", {
  for (ex in c("null_shutoff_gauss", "alt_shutoff_gauss",
               "alt_shutoff_rnaseq", "null_none_gauss")) {
    b19 <- fx_test$cases[[sprintf("test_sigma_nested/%s/B=19", ex)]]$output$value
    b99 <- fx_test$cases[[sprintf("test_sigma_nested/%s/B=99", ex)]]$output$value
    expect_identical(b19$T.boot, b99$T.boot[seq_len(19)])
  }
})

test_that("boundary example has T = 0, p = 1 and sigma_c = 0", {
  o <- fx_test$cases[["test_sigma_nested/boundary_null_shutoff/B=99"]]$output$value
  expect_true(o$T.obs <= o$boundary.tolerance)
  expect_identical(o$p.value, 1)
  expect_identical(unname(o$Sigma), 0)
  got <- compose_frozen_test(
    fx_test$cases[["test_sigma_nested/boundary_null_shutoff/B=99"]]$input$data,
    300, B_n = 0L, seed = 20260924L
  )
  expect_identical(got$p.value, 1)
})

test_that("observed-system failure is raised by the ported interval balance", {
  case <- fx_test$cases[["test_sigma_nested/observed_system_failed"]]
  expect_identical(case$output$value$status, "observed_system_failed")
  err <- capture(build_Ab_fullcov(case$input$data))$error
  expect_identical(err, case$output$value$error.message)
})
