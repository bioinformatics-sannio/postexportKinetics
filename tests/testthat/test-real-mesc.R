# Assisted-by: Claude Code (Anthropic)
# Regression on real data: mESC (GSE256335) events from the final manuscript
# audit. Deterministic observed-fit quantities only (no bootstrap).
#
#   package vs frozen core:            T2 (1e-10 relative)
#   package vs deposited audit table:  1e-8 relative; the TSV was written by
#                                      data.table::fwrite with 15 significant
#                                      digits.

fx <- read_fixture("fx_real_mesc")

TOL_TSV <- c(rel = 1e-8, abs = 0)

fit_event <- function(d) {
  built <- build_Ab_fullcov(d, scaling_A = TRUE, t_star = 0,
                            lambda_time = 0.5, lambda_diag = 0.1,
                            rel_floor = 1e-8)
  fit <- fit_nnls_nested_once(built$A, built$b, built$Sigma_b, col_test = 4L,
                              rel_floor = 1e-8)
  coef_full <- fit$coef_full_scaled / built$col_norms
  names(coef_full) <- PARAM_NAMES
  list(built = built, fit = fit, coef_full = coef_full,
       sigma_c = unname(coef_full["sigma_c"]),
       IR = max(fit$RSS0 - fit$RSS1, 0) / fit$RSS0)
}

test_that("fixture contains all 28 FDR < 0.10 mESC events, 15 samples each", {
  expect_length(fx$cases, 28L)
  expect_true(all(vapply(fx$cases, function(x) nrow(x$input$data), 1L) == 15L))
})

test_that("observed fits match the frozen core for every event", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    expect_regression(list(value = fit_event(case$input$data)), case$output,
                      TOL_T2, key, fx$provenance, case)
  }
})

test_that("sigma_c and IR match the deposited manuscript audit", {
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    got <- fit_event(case$input$data)
    expect_close(got$sigma_c, case$reference$sigma_c_final, TOL_TSV,
                 paste(key, "sigma_c"))
    expect_close(got$IR, case$reference$IR_final, TOL_TSV, paste(key, "IR"))
  }
})

test_that("representative events reproduce the published values", {
  targets <- list(
    Ppp1r36dn = c(sigma_c = 0.01899230, IR = 0.5350818),
    Nsd1 = c(sigma_c = 0.04742467, IR = 0.3810515)
  )
  for (gene in names(targets)) {
    key <- grep(paste0("^", gene, "\\|"), names(fx$cases), value = TRUE)
    expect_length(key, 1L)
    got <- fit_event(fx$cases[[key]]$input$data)
    # Published values are rounded to 7 significant digits.
    expect_equal(signif(got$sigma_c, 7), targets[[gene]][["sigma_c"]])
    expect_equal(signif(got$IR, 7), targets[[gene]][["IR"]])
  }
})

test_that("shutoff at the first sample leaves R unidentifiable by construction", {
  for (key in names(fx$cases)) {
    got <- fit_event(fx$cases[[key]]$input$data)
    expect_true(all(got$built$A[, "R"] == 0))
    expect_identical(got$fit$condition_number, Inf)
    expect_identical(got$fit$rank_full, 6L)
  }
})
