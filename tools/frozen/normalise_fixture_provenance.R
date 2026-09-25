# =============================================================================
# Normalise the provenance of the committed fixtures: replace the
# machine-specific absolute paths in names(provenance$frozen_md5) by paths
# relative to the frozen export (e.g. "commons/nested_test2.r").
#
# Usage (from the package root):
#   FROZEN=$(sh tools/frozen/export_frozen.sh "$HOME/postexport-kinetics")
#   Rscript tools/frozen/normalise_fixture_provenance.R "$FROZEN"          # check only
#   Rscript tools/frozen/normalise_fixture_provenance.R "$FROZEN" --apply  # rewrite
#
# This is the ONLY change made (approved in review of
# RELEASE_CANDIDATE_0.1.0.md). For every fixture the script:
#   1. maps each name to the unique export-relative path it ends with;
#   2. verifies each stored MD5 value against that file in a fresh
#      `git archive` export of manuscript-revision-v1.0;
#   3. builds the normalised object and proves that restoring the original
#      names gives an object identical() to the committed one, i.e. nothing
#      else (inputs, outputs, references, generated_at, other provenance,
#      attributes) changes;
#   4. only if EVERY fixture passes 1-3 and --apply is given, writes the
#      normalised objects (saveRDS version 3, as the generators do), reads
#      them back and re-checks both identities.
# Fixtures whose names are already relative are verified and left untouched.
# The fixtures are NOT regenerated. Exit status 1 on any unexpected difference.
# =============================================================================

FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) || length(args) > 2L ||
    (length(args) == 2L && args[2] != "--apply")) {
    stop("Usage: Rscript tools/frozen/normalise_fixture_provenance.R ",
         "<frozen_export> [--apply]")
}
snap <- normalizePath(args[1], mustWork = TRUE)
apply_changes <- length(args) == 2L
if (!identical(readLines(file.path(snap, ".frozen_commit")), FROZEN_COMMIT)) {
    stop("Frozen export does not carry the expected commit marker.")
}
fx_dir <- file.path("tests", "testthat", "fixtures")
files <- sort(list.files(fx_dir, pattern = "[.]rds$", full.names = TRUE))
if (!length(files)) stop("No fixtures found; run from the package root.")

export_files <- list.files(snap, recursive = TRUE, all.files = FALSE)

relative_name <- function(path) {
    if (file.exists(file.path(snap, path)) && !startsWith(path, "/")) {
        return(path)
    }
    hits <- export_files[endsWith(path, paste0("/", export_files))]
    if (length(hits) != 1L) {
        stop(sprintf("Cannot map '%s' to a unique file of the export (%d matches).",
                     path, length(hits)))
    }
    hits
}

failures <- character()
fail <- function(...) failures <<- c(failures, sprintf(...))
n_changed <- 0L
pending <- list()
for (f in files) {
    original <- readRDS(f)
    md5 <- original$provenance$frozen_md5
    if (is.null(md5) || is.null(names(md5))) {
        fail("%s: no named provenance$frozen_md5", basename(f))
        next
    }
    old_names <- names(md5)
    new_names <- vapply(old_names, relative_name, "", USE.NAMES = FALSE)
    fresh <- unname(tools::md5sum(file.path(snap, new_names)))
    if (!identical(unname(md5), fresh)) {
        fail("%s: stored MD5 values differ from the fresh export", basename(f))
        next
    }
    normalised <- original
    names(normalised$provenance$frozen_md5) <- new_names
    restored <- normalised
    names(restored$provenance$frozen_md5) <- old_names
    if (!identical(restored, original)) {
        fail("%s: object differs beyond the approved names", basename(f))
        next
    }
    if (!identical(unname(normalised$provenance$frozen_md5), unname(md5))) {
        fail("%s: MD5 values changed", basename(f))
        next
    }
    changed <- !identical(old_names, new_names)
    cat(sprintf("%-28s %d name(s) %s -> %s\n", basename(f), length(old_names),
                if (changed) "to rewrite" else "already relative",
                paste(new_names, collapse = ", ")))
    if (changed) {
        pending[[f]] <- list(normalised = normalised, original = original,
                             old_names = old_names)
    }
}

# Nothing is written unless every fixture passed verification.
if (length(failures)) {
    cat("\nFAILED (nothing written):\n", paste0("  ", failures, "\n"), sep = "")
    quit(status = 1L)
}
if (apply_changes) {
    for (f in names(pending)) {
        p <- pending[[f]]
        saveRDS(p$normalised, f, version = 3)
        back <- readRDS(f)
        restored_back <- back
        names(restored_back$provenance$frozen_md5) <- p$old_names
        if (!identical(back, p$normalised) ||
            !identical(restored_back, p$original)) {
            fail("%s: read-back check failed", basename(f))
        }
        n_changed <- n_changed + 1L
    }
    if (length(failures)) {
        cat("\nFAILED after writing:\n", paste0("  ", failures, "\n"),
            sep = "")
        quit(status = 1L)
    }
}
cat(sprintf("\n%d fixture(s) verified; %s.\n", length(files),
            if (apply_changes) sprintf("%d rewritten", n_changed) else
                "check only (use --apply to rewrite)"))
