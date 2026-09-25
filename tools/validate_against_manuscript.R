# =============================================================================
# End-to-end validation of postexportKinetics against the frozen manuscript
# implementation, for maintainers.
#
# Usage (from the package root):
#   Rscript tools/validate_against_manuscript.R [--frozen-repo PATH] [--quick]
#
#   --frozen-repo PATH  local clone of postexport-kinetics
#                       (default: $HOME/postexport-kinetics)
#   --quick             skip step 6 (recomputing the frozen outputs on this
#                       platform and the strict same-platform comparison)
#
# Steps (each reported as PASS or FAIL):
#   1. the tag manuscript-revision-v1.0 resolves to the expected commit;
#      the frozen repository's HEAD, status and refs are recorded;
#   2. the tag is exported read-only (git archive; tools/frozen/export_frozen.sh)
#      and the package source is installed into a temporary library, so the
#      validated package is exactly this working tree;
#   3. the packaged benchmark-design table matches the frozen benchmark files
#      (MD5; tools/ci/check_benchmark_provenance.R);
#   4. the public API reproduces the deposited manuscript values: Ppp1r36dn
#      and Nsd1 (final_representative_events.tsv) and all 28 mESC events with
#      FDR < 0.10 (final_mesc_FDR10_events.tsv), sigma_c and IR at 1e-8
#      relative (the TSVs carry 15 significant digits);
#   5. the regression test suite against the committed frozen fixtures
#      (strict on the fixture platform, scale-aware across platforms;
#      tools/frozen/README.md);
#   6. unless --quick: the frozen outputs are recomputed on this platform from
#      the committed inputs, the suite is rerun against them (strict,
#      same-platform level A), and committed and recomputed frozen outputs are
#      compared with the cross-platform policy (levels B/C);
#   7. the frozen repository is unchanged (HEAD, status, refs).
#
# The full 1,152-configuration benchmark is NOT rerun. No network access is
# needed. The frozen repository is only read (git rev-parse, git archive,
# git status, git show-ref). Exit status 1 if any step fails.
# =============================================================================

FROZEN_TAG <- "manuscript-revision-v1.0"
FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"
TSV_REL_TOL <- 1e-8

args <- commandArgs(trailingOnly = TRUE)
repo <- file.path(Sys.getenv("HOME"), "postexport-kinetics")
quick <- FALSE
i <- 1L
while (i <= length(args)) {
    if (args[i] == "--frozen-repo" && i < length(args)) {
        repo <- args[i + 1L]
        i <- i + 2L
    } else if (args[i] == "--quick") {
        quick <- TRUE
        i <- i + 1L
    } else {
        stop("Unknown argument: ", args[i],
             "\nUsage: Rscript tools/validate_against_manuscript.R ",
             "[--frozen-repo PATH] [--quick]")
    }
}
if (!file.exists("DESCRIPTION") ||
    !identical(unname(read.dcf("DESCRIPTION")[, "Package"]),
               "postexportKinetics")) {
    stop("Run this script from the postexportKinetics package root.")
}
repo <- normalizePath(repo, mustWork = TRUE)

results <- data.frame(step = character(), status = character(),
                      detail = character(), stringsAsFactors = FALSE)
record <- function(step, ok, detail) {
    status <- if (isTRUE(ok)) "PASS" else "FAIL"
    results[nrow(results) + 1L, ] <<- list(step, status, detail)
    cat(sprintf("[%s] %s: %s\n", status, step, detail))
    invisible(isTRUE(ok))
}
git <- function(...) {
    out <- suppressWarnings(system2("git", c("-C", shQuote(repo), ...),
                                    stdout = TRUE, stderr = TRUE))
    status <- attr(out, "status")
    if (!is.null(status) && status != 0L) {
        stop("git ", paste(..., collapse = " "), " failed: ",
             paste(out, collapse = "\n"))
    }
    out
}
run_r <- function(script, script_args = character(), env = character()) {
    out <- suppressWarnings(system2(
        file.path(R.home("bin"), "Rscript"), c(script, script_args),
        stdout = TRUE, stderr = TRUE, env = env))
    status <- attr(out, "status")
    list(ok = is.null(status) || status == 0L, output = out)
}
tail_text <- function(x, n = 6L) paste(utils::tail(x, n), collapse = " | ")

work <- tempfile("pek-validate-")
dir.create(work)
cat("postexportKinetics manuscript validation\n")
cat("Package source:", normalizePath("."), "\n")
cat("Frozen repository:", repo, "\n")
cat("Working directory:", work, "\n\n")

# 1. Tag and commit; frozen repository state before.
tag_commit <- git("rev-parse", paste0(FROZEN_TAG, "^{commit}"))
state_before <- list(head = git("rev-parse", "HEAD"),
                     status = git("status", "--porcelain", "--ignored"),
                     refs = git("show-ref"))
record("1 frozen tag", identical(tag_commit, FROZEN_COMMIT),
       sprintf("%s -> %s (expected %s)", FROZEN_TAG, tag_commit,
               FROZEN_COMMIT))

# 2. Read-only export of the tag; package installed into a temporary library.
export_dir <- file.path(work, "frozen-export")
exp_out <- suppressWarnings(system2("sh", c("tools/frozen/export_frozen.sh",
                                            shQuote(repo),
                                            shQuote(export_dir)),
                                    stdout = TRUE, stderr = TRUE))
export_ok <- is.null(attr(exp_out, "status")) &&
    identical(readLines(file.path(export_dir, ".frozen_commit")),
              FROZEN_COMMIT)
lib <- file.path(work, "lib")
dir.create(lib)
inst <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-test-load", paste0("--library=", shQuote(lib)),
      "."), stdout = TRUE, stderr = TRUE))
install_ok <- is.null(attr(inst, "status"))
record("2 export and install", export_ok && install_ok,
       sprintf("export %s; package installed into temporary library %s",
               if (export_ok) "ok" else "FAILED",
               if (install_ok) "ok" else "FAILED"))
if (!(export_ok && install_ok)) {
    cat(tail_text(c(exp_out, inst), 20L), "\n")
    quit(status = 1L)
}
lib_env <- paste0("R_LIBS=", paste(c(lib, .libPaths()), collapse = .Platform$path.sep))
.libPaths(c(lib, .libPaths()))
suppressPackageStartupMessages(library(postexportKinetics, lib.loc = lib))
pkg_version <- as.character(utils::packageVersion("postexportKinetics",
                                                  lib.loc = lib))

# 3. Benchmark metadata provenance.
bp <- run_r("tools/ci/check_benchmark_provenance.R", shQuote(export_dir))
record("3 benchmark provenance", bp$ok, tail_text(bp$output, 1L))

# 4. Deposited manuscript values through the public API.
fx <- readRDS(file.path("tests", "testthat", "fixtures", "fx_real_mesc.rds"))
audit_dir <- file.path(export_dir, "real_datasets", "final_real_data_audit")
rep_tsv <- utils::read.delim(file.path(audit_dir,
                                       "final_representative_events.tsv"),
                             stringsAsFactors = FALSE)
fdr_tsv <- utils::read.delim(file.path(audit_dir,
                                       "final_mesc_FDR10_events.tsv"),
                             stringsAsFactors = FALSE)
fit_public <- function(case) {
    d <- cbind(event = case$input$event, case$input$data)
    x <- postexport_data(d, time_unit = "min")
    f <- fit_postexport_model(x, t_star = case$input$t_star)
    c(sigma_c = f$estimates$sigma_c, IR = f$fit$IR)
}
rel_err <- function(a, e) abs(a - e) / max(abs(e), .Machine$double.xmin)
case_by_event <- stats::setNames(fx$cases,
                                 vapply(fx$cases, function(x) x$input$event, ""))
rep_ok <- TRUE
rep_detail <- character()
for (k in seq_len(nrow(rep_tsv))) {
    ev <- rep_tsv$event_final[k]
    case <- case_by_event[[ev]]
    if (is.null(case)) {
        rep_ok <- FALSE
        rep_detail <- c(rep_detail, paste(rep_tsv$gene_final[k], "missing"))
        next
    }
    got <- fit_public(case)
    e_s <- rel_err(got[["sigma_c"]], rep_tsv$sigma_c_final[k])
    e_i <- rel_err(got[["IR"]], rep_tsv$IR_final[k])
    ok <- e_s <= TSV_REL_TOL && e_i <= TSV_REL_TOL
    rep_ok <- rep_ok && ok
    rep_detail <- c(rep_detail, sprintf(
        "%s sigma_c %.10g (TSV %.10g, rel %.1e), IR %.10g (TSV %.10g, rel %.1e)",
        rep_tsv$gene_final[k], got[["sigma_c"]], rep_tsv$sigma_c_final[k],
        e_s, got[["IR"]], rep_tsv$IR_final[k], e_i))
}
record("4a Ppp1r36dn and Nsd1",
       rep_ok && all(c("Ppp1r36dn", "Nsd1") %in% rep_tsv$gene_final),
       paste(rep_detail, collapse = "; "))
fdr_err <- vapply(seq_len(nrow(fdr_tsv)), function(k) {
    case <- case_by_event[[fdr_tsv$event_final[k]]]
    if (is.null(case)) return(Inf)
    got <- fit_public(case)
    max(rel_err(got[["sigma_c"]], fdr_tsv$sigma_c_final[k]),
        rel_err(got[["IR"]], fdr_tsv$IR_final[k]))
}, numeric(1))
record("4b mESC FDR < 0.10 events",
       nrow(fdr_tsv) == 28L && all(fdr_err <= TSV_REL_TOL),
       sprintf("%d events; max relative difference of sigma_c/IR vs audit TSV %.2e (tolerance %.0e)",
               nrow(fdr_tsv), max(fdr_err), TSV_REL_TOL))

# 5. Regression suite against the committed frozen fixtures.
notes5 <- file.path(work, "notes-committed.txt")
t5 <- run_r("tools/ci/run_tests_ci.R",
            env = c(lib_env, paste0("POSTEXPORT_PLATFORM_NOTES=", notes5)))
n5 <- if (file.exists(notes5)) length(readLines(notes5)) else 0L
record("5 regression vs committed fixtures", t5$ok,
       sprintf("%s; %d non-blocking cross-platform difference(s) reported",
               if (t5$ok) "all tests passed" else tail_text(t5$output),
               n5))

# 6. Same-platform strict validation on recomputed frozen outputs.
if (!quick) {
    recomputed <- file.path(work, "fixtures-here")
    rc <- run_r("tools/frozen/recompute_fixtures.R",
                c(shQuote(export_dir), "tests/testthat/fixtures",
                  shQuote(recomputed)), env = lib_env)
    record("6a recompute frozen outputs", rc$ok, tail_text(rc$output, 2L))
    if (rc$ok) {
        t6 <- run_r("tools/ci/run_tests_ci.R",
                    env = c(lib_env,
                            paste0("POSTEXPORT_FIXTURE_DIR=", recomputed)))
        record("6b same-platform package vs frozen (level A)", t6$ok,
               if (t6$ok) "all tests passed, including bootstrap draws" else
                   tail_text(t6$output))
        cf <- run_r("tools/frozen/compare_fixtures.R",
                    c("tests/testthat/fixtures", shQuote(recomputed)),
                    env = lib_env)
        record("6c committed vs recomputed frozen outputs (levels B/C)",
               cf$ok, tail_text(cf$output, 2L))
    }
} else {
    cat("[SKIP] 6 same-platform recomputation (--quick)\n")
}

# 7. Frozen repository unchanged.
state_after <- list(head = git("rev-parse", "HEAD"),
                    status = git("status", "--porcelain", "--ignored"),
                    refs = git("show-ref"))
record("7 frozen repository unchanged", identical(state_before, state_after),
       sprintf("HEAD %s; status and refs %s", state_after$head,
               if (identical(state_before, state_after)) "identical" else
                   "CHANGED"))

cat("\nSummary\n")
cat(sprintf("  package version: %s\n", pkg_version))
cat(sprintf("  frozen reference: %s @ %s\n", FROZEN_TAG, FROZEN_COMMIT))
cat(sprintf("  platform: %s; %s; LAPACK %s\n", R.version.string,
            R.version$platform, La_version()))
print(results, row.names = FALSE, right = FALSE)
failed <- sum(results$status == "FAIL")
cat(sprintf("\nScientific equivalence status: %s (%d step(s) failed)\n",
            if (failed == 0L) "EQUIVALENT" else "REGRESSION", failed))
unlink(work, recursive = TRUE)
if (failed > 0L) quit(status = 1L)
