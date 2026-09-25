# =============================================================================
# Exhaustive hygiene inspection of a built package tarball (release gate).
#
# Usage: Rscript tools/ci/inspect_tarball.R <postexportKinetics_x.y.z.tar.gz>
#
# FAILS (exit status 1) on:
#   - top-level entries other than the intended package files;
#   - development files (phase reports, plans, BIOCONDUCTOR_AUDIT.md,
#     PROJECT_STATE.md,
#     RELEASE_* files, CLAUDE.md, tools/, data-raw/, .github/, .zenodo.json,
#     CITATION.cff), scratch, check or backup artefacts;
#   - user-specific or temporary absolute paths (/Users/, /home/, /private/,
#     /tmp/, /var/folders/, C:\Users\) in any text file or in any string,
#     name, factor level or attribute of any .rds/.rda object (including
#     hidden objects);
#   - credential-like strings (tokens, private keys, password assignments).
# REPORTS for review: every other absolute path found in binary data (e.g.
# the system R framework LAPACK/BLAS paths kept as fixture provenance) and
# the DESCRIPTION "Packaged:" line written by R CMD build.
# =============================================================================

tarball <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(tarball) || !file.exists(tarball)) {
    stop("Usage: Rscript tools/ci/inspect_tarball.R <tarball>")
}
failures <- character()
fail <- function(...) failures <<- c(failures, sprintf(...))

files <- utils::untar(tarball, list = TRUE)
files <- files[!grepl("/$", files)]
rel <- sub("^postexportKinetics/", "", files)
cat(sprintf("Tarball: %s (%d files, %s bytes)\n", basename(tarball),
            length(rel), format(file.size(tarball), big.mark = ",")))

allowed_top <- c("DESCRIPTION", "NAMESPACE", "LICENSE", "NEWS.md",
                 "README.md", "R", "man", "data", "inst", "vignettes",
                 "build", "tests")
top <- unique(sub("/.*$", "", rel))
for (t in setdiff(top, allowed_top)) fail("unexpected top-level entry: %s", t)

forbidden <- paste(c("PHASE[0-9A-Za-z_]*_REPORT", "PACKAGE_PLAN", "STOP_CONDITION",
                     "BIOCONDUCTOR_AUDIT",
                     "PROJECT_STATE", "RELEASE_", "CLAUDE\\.md", "^tools/",
                     "/tools/", "data-raw", "\\.github", "\\.zenodo\\.json",
                     "CITATION\\.cff", "\\.Rproj", "\\.DS_Store",
                     "\\.Rhistory", "\\.RData$", "\\.Rcheck", "scratch",
                     "frozen.export", "\\.orig$", "~$", "\\.log$", "\\.swp$",
                     "\\.tar\\.gz$"), collapse = "|")
for (f in rel[grepl(forbidden, rel)]) fail("forbidden file: %s", f)

user_path <- paste0("(/Users/|/home/|/private/|/tmp/|/var/folders/|",
                    "[A-Za-z]:[\\\\/]Users[\\\\/])")
credential <- paste0("(ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|",
                     "BEGIN (RSA|OPENSSH|PGP|EC) PRIVATE|AKIA[0-9A-Z]{16}|",
                     "(password|passwd|secret|api[_-]?key)\\s*[:=]\\s*\\S+)")

exdir <- tempfile("inspect-")
utils::untar(tarball, exdir = exdir)
root <- file.path(exdir, "postexportKinetics")
paths <- file.path(root, rel)
is_binary <- grepl("[.](rds|rda|RData|png|jpg|gz|pdf)$", rel)

for (i in which(!is_binary)) {
    txt <- tryCatch(readLines(paths[i], warn = FALSE), error = function(e) "")
    hit_p <- grep(user_path, txt, value = TRUE)
    hit_c <- grep(credential, txt, value = TRUE, ignore.case = TRUE)
    if (length(hit_p)) fail("%s: local path: %s", rel[i], substr(hit_p[1], 1, 100))
    if (length(hit_c)) fail("%s: credential-like string", rel[i])
}

walk <- function(o) {
    out <- character()
    if (!is.null(names(o))) out <- c(out, names(o))
    if (is.character(o)) out <- c(out, o)
    if (is.factor(o)) out <- c(out, levels(o))
    at <- attributes(o)
    at$names <- NULL
    for (a in at) out <- c(out, walk(a))
    if (is.list(o)) for (e in o) out <- c(out, walk(e))
    out
}
other_abs <- character()
n_strings <- 0L
for (i in which(grepl("[.](rds|rda|RData)$", rel))) {
    o <- if (grepl("[.]rds$", rel[i])) readRDS(paths[i]) else {
        e <- new.env()
        load(paths[i], envir = e)
        as.list(e, all.names = TRUE)
    }
    s <- unique(walk(o))
    n_strings <- n_strings + length(s)
    hp <- s[grepl(user_path, s)]
    hc <- s[grepl(credential, s, ignore.case = TRUE)]
    if (length(hp)) fail("%s: local path: %s", rel[i], substr(hp[1], 1, 100))
    if (length(hc)) fail("%s: credential-like string", rel[i])
    abs <- unlist(regmatches(s, gregexpr("(^|[ '\"(=])(/[A-Za-z][^ '\"]*|[A-Z]:[\\\\/][^ '\"]*)", s)))
    other_abs <- c(other_abs, trimws(sub("^[ '\"(=]", "", abs)))
}
cat(sprintf("Binary objects: %d files, %d distinct strings scanned\n",
            sum(grepl("[.](rds|rda|RData)$", rel)), n_strings))
other_abs <- sort(unique(other_abs))
cat("Other absolute paths in binary data (for review):",
    if (length(other_abs)) paste0("\n  ", other_abs, collapse = "") else "none",
    "\n")
desc <- read.dcf(file.path(root, "DESCRIPTION"))
cat("DESCRIPTION Version:", desc[, "Version"], "\n")
if ("Packaged" %in% colnames(desc)) cat("DESCRIPTION Packaged:", desc[, "Packaged"], "\n")
cat("Top-level entries:", paste(sort(top), collapse = ", "), "\n")
unlink(exdir, recursive = TRUE)

if (length(failures)) {
    cat("\nTARBALL INSPECTION FAILED:\n", paste0("  ", failures, "\n"), sep = "")
    quit(status = 1L)
}
cat("\nTARBALL INSPECTION PASSED\n")
