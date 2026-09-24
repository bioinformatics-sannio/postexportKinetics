# =============================================================================
# Run the installed package's testthat suite in CI and report failures.
#
# Usage (from the package root):
#   Rscript tools/ci/run_tests_ci.R
#
# Prints per-file counts and, on GitHub Actions, emits one ::error::
# annotation per failing test file containing the first failure messages, so
# that details are visible without access to raw job logs. Skips are listed
# with their reasons. Exits with status 1 on any failure or error.
# =============================================================================

suppressPackageStartupMessages({
  library(testthat)
  library(postexportKinetics)
})

res <- test_dir(
  "tests/testthat",
  package = "postexportKinetics",
  load_package = "installed",
  reporter = "silent",
  stop_on_failure = FALSE
)

df <- as.data.frame(res)
print(aggregate(cbind(expectations = nb, failed, skipped, error) ~ file, df, sum),
      row.names = FALSE)

on_gha <- identical(Sys.getenv("GITHUB_ACTIONS"), "true")

gha_escape <- function(x) {
  x <- gsub("%", "%25", x, fixed = TRUE)
  x <- gsub("\r", "%0D", x, fixed = TRUE)
  gsub("\n", "%0A", x, fixed = TRUE)
}

failures <- list()
skips <- character()

for (t in res) {
  for (r in t$results) {
    msg <- conditionMessage(r)
    if (inherits(r, "expectation_failure") || inherits(r, "expectation_error")) {
      failures[[t$file]] <- c(failures[[t$file]],
                              sprintf("[%s] %s", t$test, substr(msg, 1, 600)))
    } else if (inherits(r, "expectation_skip")) {
      skips <- c(skips, sprintf("%s [%s]: %s", t$file, t$test, msg))
    }
  }
}

if (length(skips)) {
  cat("\nSkipped tests:\n")
  cat(paste0("  ", unique(skips)), sep = "\n")
}

if (length(failures)) {
  cat("\nFailures:\n")
  for (f in names(failures)) {
    cat("\n==", f, "(", length(failures[[f]]), "failures )\n")
    cat(paste0("  ", utils::head(failures[[f]], 30)), sep = "\n")
    if (on_gha) {
      body <- paste(utils::head(failures[[f]], 15), collapse = "\n")
      cat(sprintf("::error title=%s (%d failures)::%s\n", f,
                  length(failures[[f]]), gha_escape(body)))
    }
  }
}

if (sum(df$failed) > 0 || any(df$error)) quit(status = 1L)
