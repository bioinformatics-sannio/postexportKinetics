# =============================================================================
# Check B decision (package-only branch verification): compare two extracted
# built packages (the contents of two `R CMD build` tarballs).
#
# Usage: Rscript tools/release/compare_built_packages.R <dirA> <dirB>
#   dirA, dirB: the extracted package directories, e.g. .../postexportKinetics
#
# Verdicts (printed on the last line; exit status in brackets):
#   IDENTICAL                    [0] every file is byte-identical; the
#                                    R-generated "Packaged:" line of
#                                    DESCRIPTION is ignored.
#   VIGNETTE_PNG_ENCODING_ONLY   [0] the ONLY differing file is
#                                    inst/doc/postexportKinetics.html, the
#                                    HTML is byte-identical once each
#                                    embedded base64 PNG payload is
#                                    replaced by a placeholder, and every
#                                    decoded PNG pair has the same count,
#                                    dimensions, channel structure and
#                                    exactly identical pixel values.
#   DIFFERENT                    [1] anything else: any other file differs,
#                                    a file is missing, the surrounding HTML
#                                    differs, image counts, dimensions or
#                                    channels differ, any pixel differs, or
#                                    a PNG cannot be decoded.
#
# This controlled exception (approved in review of
# BIOCONDUCTOR_READINESS.md) covers ONLY encoding-level differences of
# pixel-identical embedded PNGs in the rendered vignette. Development/CI
# dependencies: png and jsonlite (never package dependencies).
# =============================================================================

VIGNETTE_HTML <- "inst/doc/postexportKinetics.html"
PNG_RE <- "data:image/png;base64,[A-Za-z0-9+/=]+"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
    stop("Usage: Rscript tools/release/compare_built_packages.R <dirA> <dirB>")
}
verdict <- function(v, ...) {
    msg <- paste0(...)
    if (nzchar(msg)) cat(msg, "\n")
    cat(v, "\n")
    quit(status = if (v == "DIFFERENT") 1L else 0L)
}

list_rel <- function(d) {
    sort(list.files(d, recursive = TRUE, all.files = TRUE, no.. = TRUE))
}
read_bytes <- function(f) readBin(f, "raw", file.size(f))
description_bytes <- function(f) {
    x <- readLines(f, warn = FALSE)
    charToRaw(paste(x[!startsWith(x, "Packaged:")], collapse = "\n"))
}

a <- normalizePath(args[1], mustWork = TRUE)
b <- normalizePath(args[2], mustWork = TRUE)
fa <- list_rel(a)
fb <- list_rel(b)
if (!identical(fa, fb)) {
    verdict("DIFFERENT", "file lists differ: only in A: ",
            toString(setdiff(fa, fb)), "; only in B: ",
            toString(setdiff(fb, fa)))
}
differing <- character()
for (f in fa) {
    pa <- file.path(a, f)
    pb <- file.path(b, f)
    same <- if (f == "DESCRIPTION") {
        identical(description_bytes(pa), description_bytes(pb))
    } else {
        identical(read_bytes(pa), read_bytes(pb))
    }
    if (!same) differing <- c(differing, f)
}
if (!length(differing)) verdict("IDENTICAL", "")
if (!identical(differing, VIGNETTE_HTML)) {
    verdict("DIFFERENT", "differing files: ", toString(differing))
}

# Only the rendered vignette differs: examine the embedded PNG payloads.
for (p in c("png", "jsonlite")) {
    if (!requireNamespace(p, quietly = TRUE)) {
        verdict("DIFFERENT", "cannot run the image diagnostic: package '", p,
                "' not installed")
    }
}
html_a <- rawToChar(read_bytes(file.path(a, VIGNETTE_HTML)))
html_b <- rawToChar(read_bytes(file.path(b, VIGNETTE_HTML)))
pay_a <- regmatches(html_a, gregexpr(PNG_RE, html_a))[[1]]
pay_b <- regmatches(html_b, gregexpr(PNG_RE, html_b))[[1]]
if (length(pay_a) != length(pay_b)) {
    verdict("DIFFERENT", "embedded PNG count differs: ", length(pay_a),
            " vs ", length(pay_b))
}
strip <- function(h) gsub(PNG_RE, "data:image/png;base64,<PNG>", h)
if (!identical(strip(html_a), strip(html_b))) {
    verdict("DIFFERENT", "vignette HTML differs outside the embedded PNG ",
            "payloads")
}
decode <- function(p) {
    raw <- jsonlite::base64_dec(sub("^data:image/png;base64,", "", p))
    tryCatch(png::readPNG(raw), error = function(e) NULL)
}
n_bytes <- 0L
for (i in seq_along(pay_a)) {
    if (identical(pay_a[i], pay_b[i])) next
    n_bytes <- n_bytes + 1L
    ia <- decode(pay_a[i])
    ib <- decode(pay_b[i])
    if (is.null(ia) || is.null(ib)) {
        verdict("DIFFERENT", "embedded PNG #", i, " cannot be decoded")
    }
    if (!identical(dim(ia), dim(ib))) {
        verdict("DIFFERENT", "embedded PNG #", i, " dimensions/channels ",
                "differ: ", paste(dim(ia), collapse = "x"), " vs ",
                paste(dim(ib), collapse = "x"))
    }
    if (!identical(ia, ib)) {
        # Diagnostic detail only (the verdict is DIFFERENT regardless):
        # where the differing pixels are and how large the differences are.
        dpix <- apply(ia != ib, c(1, 2), any)
        rr <- range(which(rowSums(dpix) > 0))
        cc <- range(which(colSums(dpix) > 0))
        verdict("DIFFERENT", "embedded PNG #", i, " pixels differ (",
                sum(ia != ib), " values in ", sum(dpix), " pixels; dim ",
                paste(dim(ia), collapse = "x"), "; bounding box rows ",
                rr[1], "-", rr[2], ", cols ", cc[1], "-", cc[2],
                "; max abs difference ",
                signif(max(abs(ia - ib)), 3), ")")
    }
}
verdict("VIGNETTE_PNG_ENCODING_ONLY",
        sprintf(paste0("only %s differs; surrounding HTML identical; %d of %d ",
                       "embedded PNGs differ in encoded bytes but are ",
                       "pixel-identical (same dimensions and channels)"),
                VIGNETTE_HTML, n_bytes, length(pay_a)))
