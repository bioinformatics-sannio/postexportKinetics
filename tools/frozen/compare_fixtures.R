# =============================================================================
# Cross-platform comparison of the FROZEN implementation with itself.
#
# Usage (from the package root):
#   Rscript tools/frozen/compare_fixtures.R <reference_dir> <candidate_dir>
#
# reference_dir: committed fixtures (fixture platform).
# candidate_dir: fixtures recomputed on the current platform from the SAME
#                committed inputs (tools/frozen/recompute_fixtures.R).
#
# Policy (approved in review of PHASE1_5_REPORT.md; implemented in
# tests/testthat/helper-compare.R, assess_cross()):
#   - inputs must be identical (they are copied, never regenerated);
#   - scientific outputs: scale-aware cross-platform rules and identical
#     frozen boundary classification -> BLOCKING;
#   - deliberately extreme-conditioning fixtures: differences consistent with
#     100 * kappa * eps are REPORTED, not blocking (boundary still blocking);
#   - bootstrap draws and draw-dependent fields: REPORTED, not blocking.
# Exits with status 1 if any blocking condition fails.
# =============================================================================

source(file.path("tests", "testthat", "helper-compare.R"))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: Rscript tools/frozen/compare_fixtures.R <reference_dir> <candidate_dir>")
}
ref_dir <- args[1]
cand_dir <- args[2]

files <- sort(list.files(ref_dir, pattern = "\\.rds$"))
stopifnot(identical(files, sort(list.files(cand_dir, pattern = "\\.rds$"))))

rows <- list()
record <- function(fixture, case, level, blocking, notes) {
  rows[[length(rows) + 1L]] <<- data.frame(
    fixture = fixture, case = case, level = level,
    blocking = paste(blocking, collapse = "; "),
    notes = paste(notes, collapse = "; ")
  )
}

for (f in files) {
  fixture <- sub("\\.rds$", "", f)
  ref <- readRDS(file.path(ref_dir, f))
  cand <- readRDS(file.path(cand_dir, f))
  stopifnot(identical(ref$provenance$frozen_commit, cand$provenance$frozen_commit))
  stopifnot(identical(names(ref$cases), names(cand$cases)))

  for (key in names(ref$cases)) {
    r <- ref$cases[[key]]
    c <- cand$cases[[key]]

    if (!identical(r$input, c$input)) {
      record(fixture, key, "input", "inputs differ (must be identical)", character())
      next
    }

    if (startsWith(fixture, "fx_source")) {
      record(fixture, key, "source",
             if (identical(r$output, c$output)) character() else "source text differs",
             character())
      next
    }

    if (fixture == "fx_bootstrap") {
      d <- max_scaled_diff(c$output, r$output)
      record(fixture, key, "bootstrap draws", character(),
             if (d > 0) sprintf("draws differ (max scaled diff %.3g); platform-dependent, not compared", d)
             else character())
      next
    }

    res <- assess_cross(c$output, r$output, key, r)
    level <- if (is_extreme_case(key)) "extreme conditioning" else "scientific"
    record(fixture, key, level, res$blocking, res$notes)
  }
}

res <- do.call(rbind, rows)
res$is_blocking <- nzchar(res$blocking)
res$has_note <- nzchar(res$notes)

prov_ref <- readRDS(file.path(ref_dir, files[1]))$provenance
prov_cand <- readRDS(file.path(cand_dir, files[1]))$provenance
cat("Reference: ", prov_ref$platform, "|", prov_ref$La_library, "|", prov_ref$BLAS, "\n")
cat("Candidate: ", prov_cand$platform, "|", prov_cand$La_library, "|", prov_cand$BLAS, "\n\n")

summary_tab <- do.call(rbind, lapply(split(res, list(res$fixture, res$level), drop = TRUE),
                                     function(x) data.frame(
  fixture = x$fixture[1], level = x$level[1], cases = nrow(x),
  blocking_failures = sum(x$is_blocking), reported_differences = sum(x$has_note))))
print(summary_tab[order(summary_tab$fixture, summary_tab$level), ], row.names = FALSE)

notes <- res[res$has_note, c("fixture", "case", "notes")]
if (nrow(notes)) {
  cat("\nReported (non-blocking) cross-platform differences:\n")
  for (i in seq_len(nrow(notes))) {
    cat(sprintf("  %s | %s | %s\n", notes$fixture[i], notes$case[i], notes$notes[i]))
  }
}

on_gha <- identical(Sys.getenv("GITHUB_ACTIONS"), "true")
esc <- function(x) gsub("\n", "%0A", gsub("%", "%25", x, fixed = TRUE), fixed = TRUE)

if (on_gha && nrow(notes)) {
  agg <- aggregate(case ~ fixture, notes, length)
  cat(sprintf("::notice title=Cross-platform differences reported (non-blocking)::%s\n",
              esc(paste(sprintf("%s: %d cases", agg$fixture, agg$case), collapse = "\n"))))
}

bad <- res[res$is_blocking, ]
if (nrow(bad)) {
  cat("\nBLOCKING CROSS-PLATFORM FAILURES:\n")
  for (i in seq_len(min(nrow(bad), 50L))) {
    cat(sprintf("  %s | %s | %s\n", bad$fixture[i], bad$case[i], bad$blocking[i]))
  }
  if (on_gha) {
    body <- paste(utils::head(sprintf("%s | %s | %s", bad$fixture, bad$case, bad$blocking), 15),
                  collapse = "\n")
    cat(sprintf("::error title=Cross-platform scientific policy (%d blocking failures)::%s\n",
                nrow(bad), esc(body)))
  }
  quit(status = 1L)
}

cat("\nCross-platform scientific policy satisfied: no blocking failures.\n")
