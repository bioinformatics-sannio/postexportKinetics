# =============================================================================
# Characterise cross-platform differences between two fixture sets generated
# from the frozen tag (reference = committed fixtures, candidate = fixtures
# regenerated on the CI platform). Diagnostic only: never fails the job.
#
# For every numeric leaf that is outside its elementwise tolerance tier, the
# script records the leaf name, the largest absolute difference, the largest
# elementwise relative difference, and the NORMWISE relative difference
# max|a - e| / max|e| over the leaf. For fits it also records whether the
# frozen boundary decision (T <= 1e-10 * max(1, |RSS0|, |RSS1|)) agrees, and
# whether finite/Inf condition numbers agree. Output: printed table and one
# ::notice:: annotation.
#
# Usage: Rscript tools/ci/diagnose_platform_diffs.R <reference_dir> <candidate_dir>
# =============================================================================

source(file.path("tests", "testthat", "helper-compare.R"))

args <- commandArgs(trailingOnly = TRUE)
ref_dir <- args[1]
cand_dir <- args[2]

tiers <- list(
  fx_matrix = TOL_T2, fx_covariance = TOL_T2, fx_interval_balance = TOL_T2,
  fx_fit = TOL_T2, fx_crank_nicolson = TOL_T1, fx_real_mesc = TOL_T2,
  fx_test_sigma_nested = TOL_T2, fx_bootstrap = TOL_T2
)

leaves <- function(x, path = "") {
  if (is.list(x)) {
    out <- list()
    for (i in seq_along(x)) {
      nm <- names(x)[i]
      child <- if (!is.null(nm) && nzchar(nm)) nm else paste0("[[", i, "]]")
      out <- c(out, leaves(x[[i]], paste0(path, "$", child)))
    }
    return(out)
  }
  stats::setNames(list(x), path)
}

rows <- list()

for (f in sort(list.files(ref_dir, pattern = "\\.rds$"))) {
  fixture <- sub("\\.rds$", "", f)
  if (!fixture %in% names(tiers)) next
  tol <- tiers[[fixture]]
  ref <- readRDS(file.path(ref_dir, f))
  cand <- readRDS(file.path(cand_dir, f))
  for (key in names(ref$cases)) {
    lr <- leaves(ref$cases[[key]]$output)
    lc <- leaves(cand$cases[[key]]$output)
    if (!identical(names(lr), names(lc))) {
      rows[[length(rows) + 1L]] <- data.frame(
        fixture = fixture, leaf = "<structure>", case = key, max_abs = NA,
        max_rel_elementwise = NA, normwise_rel = NA, note = "structure differs")
      next
    }
    for (p in names(lr)) {
      e <- lr[[p]]
      a <- lc[[p]]
      if (!is.numeric(e)) {
        if (!identical(a, e)) {
          rows[[length(rows) + 1L]] <- data.frame(
            fixture = fixture, leaf = p, case = key, max_abs = NA,
            max_rel_elementwise = NA, normwise_rel = NA, note = "non-numeric differs")
        }
        next
      }
      if (length(compare_close(a, e, tol)) == 0L) next
      ev <- as.vector(e)
      av <- as.vector(a)
      note <- ""
      if (!identical(is.infinite(ev), is.infinite(av))) note <- "finite/Inf mismatch"
      ok <- is.finite(ev) & is.finite(av)
      d <- abs(av[ok] - ev[ok])
      scale <- max(abs(ev[ok]), 0)
      rows[[length(rows) + 1L]] <- data.frame(
        fixture = fixture, leaf = p, case = key,
        max_abs = if (length(d)) max(d) else NA,
        max_rel_elementwise = if (length(d)) max(d / pmax(abs(ev[ok]), .Machine$double.xmin)) else NA,
        normwise_rel = if (length(d) && scale > 0) max(d) / scale else NA,
        note = note)
    }
    # Boundary decision agreement for fits.
    rv <- ref$cases[[key]]$output$value
    cv <- cand$cases[[key]]$output$value
    fit_r <- if (fixture == "fx_real_mesc") rv$fit else if (fixture == "fx_fit") rv else if (fixture == "fx_test_sigma_nested") rv else NULL
    fit_c <- if (fixture == "fx_real_mesc") cv$fit else if (fixture == "fx_fit") cv else if (fixture == "fx_test_sigma_nested") cv else NULL
    if (!is.null(fit_r) && !is.null(fit_c)) {
      gT <- function(z) if (!is.null(z$T)) z$T else z$T.obs
      if (!is.null(gT(fit_r)) && !is.null(gT(fit_c)) && !is.null(fit_r$RSS0)) {
        br <- gT(fit_r) <= 1e-10 * max(1, abs(fit_r$RSS0), abs(fit_r$RSS1))
        bc <- gT(fit_c) <= 1e-10 * max(1, abs(fit_c$RSS0), abs(fit_c$RSS1))
        if (!identical(br, bc)) {
          rows[[length(rows) + 1L]] <- data.frame(
            fixture = fixture, leaf = "<boundary decision>", case = key,
            max_abs = NA, max_rel_elementwise = NA, normwise_rel = NA,
            note = sprintf("boundary %s vs %s", br, bc))
        }
      }
    }
  }
}

if (!length(rows)) {
  cat("No differences outside tolerance.\n")
  quit(status = 0L)
}

res <- do.call(rbind, rows)
res$leaf_generic <- gsub("\\[\\[[0-9]+\\]\\]", "[[i]]", res$leaf)

agg <- do.call(rbind, lapply(split(res, paste(res$fixture, res$leaf_generic, res$note)), function(x) {
  data.frame(
    fixture = x$fixture[1], leaf = x$leaf_generic[1], note = x$note[1],
    cases = length(unique(x$case)),
    max_abs = suppressWarnings(max(x$max_abs, na.rm = TRUE)),
    max_rel_elementwise = suppressWarnings(max(x$max_rel_elementwise, na.rm = TRUE)),
    max_normwise_rel = suppressWarnings(max(x$normwise_rel, na.rm = TRUE))
  )
}))
agg <- agg[order(agg$fixture, -agg$max_normwise_rel), ]

options(width = 250)
print(agg, row.names = FALSE, digits = 3)

if (identical(Sys.getenv("GITHUB_ACTIONS"), "true")) {
  lines <- sprintf("%s %s %s | cases=%d max_abs=%.3g max_rel_elem=%.3g max_normwise_rel=%.3g",
                   agg$fixture, agg$leaf, agg$note, agg$cases, agg$max_abs,
                   agg$max_rel_elementwise, agg$max_normwise_rel)
  body <- paste(lines, collapse = "\n")
  body <- gsub("\n", "%0A", gsub("%", "%25", body, fixed = TRUE), fixed = TRUE)
  cat(sprintf("::notice title=Cross-platform frozen differences (%d leaf groups)::%s\n",
              nrow(agg), body))
}
