# Regression: internal port of the frozen orchestration test_sigma_nested()
# (commons/nested_test2.r:1447-2166) against the frozen tag.
#
# Every case reruns the ported function with the complete frozen argument
# list stored in the fixture (and the same global-RNG preparation for
# seed = NULL cases) and compares the complete frozen result list:
#   same-platform: strict tier T2 for continuous values; p-values, status,
#     bootstrap counts and failure rates exactly;
#   cross-platform: approved scale-aware policy (bootstrap-draw fields
#     reported only; boundary classification blocking).

fx <- read_fixture("fx_orchestrator")

run_orchestrator <- function(case) {
  if (!is.null(case$input$pre_seed)) set.seed(case$input$pre_seed)
  capture(do.call(test_sigma_nested, case$input$args))
}

exact_fields <- c("status", "p.value", "n.bootstrap.valid",
                  "bootstrap.failure.rate", "atom.zero", "rank.full",
                  "rank.null", "error.message")

test_that("fixture covers the required regression cases", {
  keys <- names(fx$cases)
  for (k in c("orchestrator/null_shutoff_gauss/default",
              "orchestrator/alt_shutoff_gauss/default",
              "orchestrator/alt_shutoff_rnaseq/default",
              "orchestrator/boundary_null_shutoff/default",
              "orchestrator/null_none_gauss/default",
              "orchestrator/observed_system_failed",
              "orchestrator/real_mesc/Ppp1r36dn",
              "orchestrator/real_mesc/Nsd1")) {
    expect_true(k %in% keys, label = k)
  }
})

test_that("test_sigma_nested() port reproduces the frozen results", {
  same <- identical(regression_level(fx$provenance), "same-platform")
  for (key in names(fx$cases)) {
    case <- fx$cases[[key]]
    got <- run_orchestrator(case)
    expect_regression(got, case$output, TOL_T2, key, fx$provenance, case)
    if (same && is.null(case$output$error)) {
      for (f in intersect(exact_fields, names(case$output$value))) {
        expect_identical(got$value[[f]], case$output$value[[f]],
                         label = paste(key, f))
      }
      expect_identical(names(got$value), names(case$output$value),
                       label = paste(key, "field set"))
    }
  }
})

test_that("frozen status codes and field sets are preserved", {
  st <- vapply(fx$cases, function(x) x$output$value$status, character(1))
  expect_identical(unname(st[["orchestrator/observed_system_failed"]]),
                   "observed_system_failed")
  expect_identical(
    unname(st[["orchestrator/alt_shutoff_gauss/bootstrap_unstable"]]),
    "bootstrap_unstable")
  u <- fx$cases[["orchestrator/alt_shutoff_gauss/bootstrap_unstable"]]$output$value
  expect_true(is.na(u$p.value))
  expect_false("IR" %in% names(u))
  f <- fx$cases[["orchestrator/observed_system_failed"]]$output$value
  expect_identical(names(f), c("p.value", "status", "error.message"))
})

test_that("frozen p-values follow the add-one and boundary rules", {
  for (key in names(fx$cases)) {
    o <- fx$cases[[key]]$output$value
    if (!identical(o$status, "ok") || is.null(o$T.boot)) next
    if (o$T.obs <= o$boundary.tolerance) {
      expect_identical(o$p.value, 1, label = key)
    } else {
      expect_identical(
        o$p.value,
        (1 + sum(o$T.boot >= o$T.obs)) / (length(o$T.boot) + 1),
        label = key
      )
    }
  }
})

test_that("return_boot = FALSE changes only the returned bootstrap vectors", {
  for (ex in c("null_shutoff_gauss", "alt_shutoff_gauss",
               "alt_shutoff_rnaseq", "null_none_gauss")) {
    a <- fx$cases[[sprintf("orchestrator/%s/default", ex)]]$output$value
    b <- fx$cases[[sprintf("orchestrator/%s/return_boot=FALSE", ex)]]$output$value
    boot_only <- c("T.boot", "bootstrap.condition", "bootstrap.rank")
    expect_identical(a[setdiff(names(a), boot_only)], b)
  }
})
