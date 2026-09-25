# =============================================================================
# Negative / mutation tests for tools/release/compare_built_packages.R.
#
# Usage (from the repository root):
#   Rscript tools/release/test_compare_built_packages.R [built_vignette.html]
#
# Builds pairs of synthetic extracted packages and checks each verdict. If a
# real rendered vignette HTML is given, the image tests are repeated on its
# actual embedded figures. Exit status 1 if any expectation fails.
# Development/CI dependencies: png, jsonlite.
# =============================================================================

stopifnot(requireNamespace("png", quietly = TRUE),
          requireNamespace("jsonlite", quietly = TRUE))
cmp <- file.path("tools", "release", "compare_built_packages.R")
rscript <- file.path(R.home("bin"), "Rscript")
real_html <- commandArgs(trailingOnly = TRUE)[1]
HTML <- file.path("inst", "doc", "postexportKinetics.html")

png_uri <- function(img, text = NULL) {
    raw <- if (is.null(text)) png::writePNG(img) else png::writePNG(img, text = text)
    paste0("data:image/png;base64,", gsub("[\r\n]", "", jsonlite::base64_enc(raw)))
}
make_pkg <- function(dir, html, packaged = "2026-09-26 10:00:00 UTC; a",
                     rcode = "f <- function() 1\n") {
    dir.create(file.path(dir, "inst", "doc"), recursive = TRUE)
    dir.create(file.path(dir, "R"))
    writeLines(c("Package: postexportKinetics", "Version: 0.99.0",
                 paste("Packaged:", packaged)), file.path(dir, "DESCRIPTION"))
    writeLines(rcode, file.path(dir, "R", "x.R"), sep = "")
    writeBin(charToRaw(html), file.path(dir, HTML))
    dir
}
run <- function(a, b) {
    out <- suppressWarnings(system2(rscript, c(cmp, shQuote(a), shQuote(b)),
                                    stdout = TRUE, stderr = TRUE))
    list(status = if (is.null(attr(out, "status"))) 0L else attr(out, "status"),
         verdict = trimws(utils::tail(out, 1L)), out = out)
}
results <- data.frame(case = character(), expected = character(),
                      verdict = character(), status = integer(),
                      ok = logical(), stringsAsFactors = FALSE)
expect <- function(case, a, b, expected) {
    r <- run(a, b)
    ok <- identical(r$verdict, expected) &&
        identical(r$status, if (expected == "DIFFERENT") 1L else 0L)
    results[nrow(results) + 1L, ] <<- list(case, expected, r$verdict,
                                           r$status, ok)
    cat(sprintf("[%s] %-58s expected %-27s got %s (exit %d)\n",
                if (ok) "PASS" else "FAIL", case, expected, r$verdict,
                r$status))
    if (!ok) cat(paste0("      ", r$out), sep = "\n")
}

set.seed(20260926)
img1 <- array(runif(20 * 30 * 3), c(20, 30, 3))
img1 <- round(img1 * 255) / 255
img2 <- array(round(runif(15 * 10 * 4) * 255) / 255, c(15, 10, 4))
page <- function(u1, u2, extra = "") {
    paste0("<html><body><p>Figure 1</p><img src=\"", u1, "\" />",
           "<p>Figure 2", extra, "</p><img src=\"", u2, "\" /></body></html>")
}
u1 <- png_uri(img1)
u2 <- png_uri(img2)
u1_reenc <- png_uri(img1, text = c(Software = "re-encoded"))
stopifnot(!identical(u1, u1_reenc))
img1_px <- img1
img1_px[5, 7, 2] <- if (img1[5, 7, 2] < 1) img1[5, 7, 2] + 1 / 255 else img1[5, 7, 2] - 1 / 255
img1_small <- img1[1:19, , ]

base <- tempfile("cmp-")
dir.create(base)
d <- function(name) file.path(base, name)

A <- make_pkg(d("A"), page(u1, u2))
expect("identical content (only Packaged: differs)",
       A, make_pkg(d("B1"), page(u1, u2), packaged = "2026-09-26 11:11:11 UTC; b"),
       "IDENTICAL")
expect("byte-different, pixel-identical PNG (controlled exception)",
       A, make_pkg(d("B2"), page(u1_reenc, u2)), "VIGNETTE_PNG_ENCODING_ONLY")
expect("one-pixel difference in an embedded PNG",
       A, make_pkg(d("B3"), page(png_uri(img1_px), u2)), "DIFFERENT")
expect("surrounding HTML changed (PNGs identical)",
       A, make_pkg(d("B4"), page(u1, u2, extra = ".")), "DIFFERENT")
expect("surrounding HTML changed and PNG re-encoded",
       A, make_pkg(d("B5"), page(u1_reenc, u2, extra = ".")), "DIFFERENT")
expect("non-vignette file changed",
       A, make_pkg(d("B6"), page(u1, u2), rcode = "f <- function() 2\n"),
       "DIFFERENT")
expect("non-vignette file changed and PNG re-encoded",
       A, make_pkg(d("B7"), page(u1_reenc, u2), rcode = "f <- function() 2\n"),
       "DIFFERENT")
expect("image dimensions differ",
       A, make_pkg(d("B8"), page(png_uri(img1_small), u2)), "DIFFERENT")
expect("channel structure differs (RGB vs RGBA)",
       A, make_pkg(d("B9"), page(png_uri(array(c(img1, array(1, c(20, 30, 1))),
                                                c(20, 30, 4))), u2)),
       "DIFFERENT")
expect("image count differs",
       A, make_pkg(d("B10"), paste0(page(u1, u2), "<img src=\"", u2, "\" />")),
       "DIFFERENT")
extra_dir <- make_pkg(d("B11"), page(u1, u2))
writeLines("x", file.path(extra_dir, "R", "extra.R"))
expect("additional file", A, extra_dir, "DIFFERENT")

if (!is.na(real_html) && file.exists(real_html)) {
    h <- rawToChar(readBin(real_html, "raw", file.size(real_html)))
    re <- "data:image/png;base64,[A-Za-z0-9+/=]+"
    uris <- regmatches(h, gregexpr(re, h))[[1]]
    cat(sprintf("real vignette: %d embedded PNGs\n", length(uris)))
    k <- 1L
    img <- png::readPNG(jsonlite::base64_dec(sub("^data:image/png;base64,", "", uris[k])))
    replace_k <- function(new_uri) {
        pos <- regexpr(re, h)
        paste0(substr(h, 1, pos - 1L), new_uri,
               substr(h, pos + attr(pos, "match.length"), nchar(h)))
    }
    RA <- make_pkg(d("RA"), h)
    expect("real vignette: figure 1 re-encoded, pixel-identical",
           RA, make_pkg(d("RB1"), replace_k(png_uri(img, text = c(Software = "re-encoded")))),
           "VIGNETTE_PNG_ENCODING_ONLY")
    img_px <- img
    img_px[1, 1, 1] <- if (img[1, 1, 1] < 1) img[1, 1, 1] + 1 / 255 else img[1, 1, 1] - 1 / 255
    expect("real vignette: figure 1 one-pixel difference",
           RA, make_pkg(d("RB2"), replace_k(png_uri(img_px))), "DIFFERENT")
    expect("real vignette: one character of text changed",
           RA, make_pkg(d("RB3"), sub("Introduction", "Introductiom", h, fixed = TRUE)),
           "DIFFERENT")
}

unlink(base, recursive = TRUE)
cat(sprintf("\n%d of %d expectations met\n", sum(results$ok), nrow(results)))
if (!all(results$ok)) quit(status = 1L)
cat("COMPARE_BUILT_PACKAGES TESTS PASSED\n")
