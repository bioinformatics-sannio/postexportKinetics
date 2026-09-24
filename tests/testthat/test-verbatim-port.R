# The ported internals must be the frozen functions, up to the documented
# mechanical edits (namespace qualification of stats functions). Both sides are
# parsed and deparsed in the current R session without source references, so
# comments and whitespace do not matter but every expression does.

# deparse() wraps lines by width, so namespace prefixes can move line breaks;
# the comparison is therefore made on the whitespace-collapsed token stream.
normalise <- function(x) {
  x <- gsub("stats::", "", x, fixed = TRUE)
  gsub("\\s+", " ", paste(x, collapse = " "))
}

deparse_plain <- function(x) {
  deparse(x, control = c("keepNA", "keepInteger", "niceNames",
                         "showAttributes"))
}

fx <- read_fixture("fx_source")
fx_orch <- read_fixture("fx_source_orchestrator")
fx$cases <- c(fx$cases, fx_orch$cases)

test_that("fixture covers every ported object", {
  expect_setequal(
    names(fx$cases),
    c("KINETIC_VARS", "PARAM_NAMES", "make_spd", "inverse_sqrt_matrix",
      "time_summary_cov_shrink", "build_sigma_means",
      "build_difference_matrix", "build_Ab_fullcov", "fit_nnls_nested_once",
      "kinetic_matrix", "cn_interval", "predict_null_cn",
      "simulate_destructive_null", "test_sigma_nested")
  )
})

for (nm in names(fx$cases)) {
  test_that(sprintf("%s is a verbatim port of the frozen source", nm), {
    frozen_env <- new.env(parent = baseenv())
    eval(parse(text = fx$cases[[nm]]$output$text, keep.source = FALSE),
         envir = frozen_env)
    frozen_obj <- frozen_env[[nm]]
    pkg_obj <- get(nm, envir = asNamespace("postexportKinetics"))

    if (is.function(frozen_obj)) {
      expect_true(is.function(pkg_obj))
      expect_identical(
        normalise(deparse_plain(formals(pkg_obj))),
        normalise(deparse_plain(formals(frozen_obj)))
      )
      expect_identical(
        normalise(deparse_plain(body(pkg_obj))),
        normalise(deparse_plain(body(frozen_obj)))
      )
    } else {
      expect_identical(pkg_obj, frozen_obj)
    }
  })
}

test_that("only the documented mechanical edits differ from the frozen text", {
  qualified <- list(
    make_spd = c("stats::median(positive_d)", "stats::median(positive_entries)"),
    time_summary_cov_shrink = "stats::complete.cases(sub)",
    test_sigma_nested = c("stats::median(", "stats::quantile(",
                          "stats::setNames(")
  )
  for (nm in names(fx$cases)) {
    pkg_obj <- get(nm, envir = asNamespace("postexportKinetics"))
    if (!is.function(pkg_obj)) next
    pkg_txt <- paste(deparse_plain(body(pkg_obj)), collapse = "\n")
    frozen_txt <- paste(fx$cases[[nm]]$output$text, collapse = "\n")
    new_quals <- setdiff(
      regmatches(pkg_txt, gregexpr("stats::[A-Za-z.]+\\(", pkg_txt))[[1]],
      regmatches(frozen_txt, gregexpr("stats::[A-Za-z.]+\\(", frozen_txt))[[1]]
    )
    expected <- sub("\\(.*$", "(", qualified[[nm]])
    expect_setequal(new_quals, unique(expected))
  }
})
