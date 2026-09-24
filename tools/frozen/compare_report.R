# =============================================================================
# Report exact identity / maximum differences between the installed package
# and the frozen-reference fixtures.
#
# Usage (from the package root, package installed):
#   Rscript tools/frozen/compare_report.R [out.tsv]
#
# For every fixture case of a ported component, the package function is run on
# the stored input and compared with the stored frozen output:
#   identical  = identical() on the captured result (value or error message)
#   max_abs / max_rel = largest elementwise differences over numeric leaves
# Bootstrap-draw cases set the stored seed first, as in the tests.
# =============================================================================

suppressPackageStartupMessages(library(postexportKinetics))

source(file.path("tests", "testthat", "helper-compare.R"))

fx_dir <- file.path("tests", "testthat", "fixtures")
ns <- asNamespace("postexportKinetics")

capture <- function(expr) {
  tryCatch(list(value = expr), error = function(e) list(error = conditionMessage(e)))
}

rows <- list()

add_row <- function(fixture, key, actual, expected) {
  d <- max_differences(actual$value, expected$value)
  rows[[length(rows) + 1L]] <<- data.frame(
    fixture = fixture,
    case = key,
    identical = identical(actual, expected),
    error_case = !is.null(expected$error),
    max_abs = d[["abs"]],
    max_rel = d[["rel"]]
  )
}

for (fixture in c("fx_matrix", "fx_covariance", "fx_interval_balance",
                  "fx_fit", "fx_crank_nicolson")) {
  fx <- readRDS(file.path(fx_dir, paste0(fixture, ".rds")))
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    f <- get(case$input$fun, envir = ns)
    add_row(fixture, key, capture(do.call(f, case$input$args)), case$output)
  }
}

fx <- readRDS(file.path(fx_dir, "fx_bootstrap.rds"))
for (key in names(fx$cases)) {
  case <- fx$cases[[key]]
  f <- get(case$input$fun, envir = ns)
  set.seed(case$input$seed)
  if (case$input$n_calls == 2L) {
    first <- capture(do.call(f, case$input$args))
    second <- capture(do.call(f, case$input$args))
    add_row("fx_bootstrap", paste(key, "first"), first, case$output$value$first)
    add_row("fx_bootstrap", paste(key, "second"), second, case$output$value$second)
  } else {
    add_row("fx_bootstrap", key, capture(do.call(f, case$input$args)), case$output)
  }
}

fx <- readRDS(file.path(fx_dir, "fx_real_mesc.rds"))
for (key in names(fx$cases)) {
  case <- fx$cases[[key]]
  d <- case$input$data
  built <- ns$build_Ab_fullcov(d, TRUE, 0, 0.5, 0.1, 1e-8)
  fit <- ns$fit_nnls_nested_once(built$A, built$b, built$Sigma_b, 4L, 1e-8)
  coef_full <- fit$coef_full_scaled / built$col_norms
  names(coef_full) <- ns$PARAM_NAMES
  got <- list(value = list(built = built, fit = fit, coef_full = coef_full,
                           sigma_c = unname(coef_full["sigma_c"]),
                           IR = max(fit$RSS0 - fit$RSS1, 0) / fit$RSS0))
  add_row("fx_real_mesc", key, got, case$output)
  ref <- list(value = c(case$reference$sigma_c_final, case$reference$IR_final))
  add_row("fx_real_mesc_vs_tsv", key,
          list(value = c(got$value$sigma_c, got$value$IR)), ref)
}

res <- do.call(rbind, rows)

summary_tab <- do.call(rbind, lapply(split(res, res$fixture), function(x) {
  data.frame(
    fixture = x$fixture[1],
    cases = nrow(x),
    error_cases = sum(x$error_case),
    identical = sum(x$identical),
    max_abs = max(x$max_abs, na.rm = TRUE),
    max_rel = max(x$max_rel, na.rm = TRUE)
  )
}))

print(summary_tab, row.names = FALSE)

out <- commandArgs(trailingOnly = TRUE)
if (length(out) >= 1L) {
  utils::write.table(res, out[1], sep = "\t", quote = FALSE, row.names = FALSE)
}
