# =============================================================================
# Citation, DOI and version audit (release gate).
#
# Usage (from the package root): Rscript tools/ci/citation_audit.R
#
# Requires (exit status 1 otherwise):
#   - one package version everywhere: DESCRIPTION, CITATION.cff, the first
#     NEWS.md heading; inst/CITATION takes it from meta$Version; no leftover
#     development version string in package files;
#   - no package DOI: no .zenodo.json, no top-level doi/identifiers in
#     CITATION.cff, and the only DOI anywhere in the package files is the
#     frozen manuscript implementation DOI 10.5281/zenodo.22944109, which is
#     always labelled as the frozen implementation;
#   - the manuscript is submitted/unpublished, with no accepted, published or
#     in-press wording.
# =============================================================================

FROZEN_DOI <- "10.5281/zenodo.22944109"
failures <- character()
check <- function(ok, msg) {
    cat(sprintf("[%s] %s\n", if (isTRUE(ok)) "PASS" else "FAIL", msg))
    if (!isTRUE(ok)) failures <<- c(failures, msg)
}

version <- unname(read.dcf("DESCRIPTION")[, "Version"])
cff <- yaml::read_yaml("CITATION.cff")
news1 <- grep("^# ", readLines("NEWS.md"), value = TRUE)[1]
inst_cit <- readLines(file.path("inst", "CITATION"))

check(identical(cff$version, version),
      sprintf("CITATION.cff version %s == DESCRIPTION %s", cff$version, version))
check(identical(news1, paste("# postexportKinetics", version)),
      sprintf("NEWS.md first heading '%s'", news1))
check(any(grepl("meta$Version", inst_cit, fixed = TRUE)) &&
          !any(grepl("development version", inst_cit, ignore.case = TRUE)),
      "inst/CITATION reports meta$Version, no development wording")

pkg_files <- c("DESCRIPTION", "NEWS.md", "README.md", "CITATION.cff",
               file.path("inst", "CITATION"),
               list.files("vignettes", "[.]Rmd$", full.names = TRUE),
               list.files("R", "[.]R$", full.names = TRUE),
               list.files("man", "[.]Rd$", full.names = TRUE))
txt <- lapply(pkg_files, readLines, warn = FALSE)
names(txt) <- pkg_files
dev <- vapply(txt, function(x) any(grepl("0\\.0\\.0\\.9000", x)), TRUE)
check(!any(dev), paste("no 0.0.0.9000 in package files",
                       if (any(dev)) paste(names(dev)[dev], collapse = ", ") else ""))

check(!file.exists(".zenodo.json"), "no .zenodo.json")
check(is.null(cff$doi) && is.null(cff$identifiers),
      "CITATION.cff has no top-level doi / identifiers (no package DOI)")
dois <- unique(unlist(lapply(txt, function(x)
    regmatches(x, gregexpr("10[.][0-9]{4,9}/[A-Za-z0-9._/-]+", x)))))
dois <- unique(sub("[.]$", "", dois))
check(identical(dois, FROZEN_DOI),
      sprintf("only DOI in package files is %s (found: %s)", FROZEN_DOI,
              paste(dois, collapse = ", ")))
labelled <- vapply(txt, function(x) {
    if (!any(grepl(FROZEN_DOI, x, fixed = TRUE))) return(TRUE)
    any(grepl("frozen", x, ignore.case = TRUE))
}, TRUE)
check(all(labelled), paste("every file citing the frozen DOI labels it as the frozen implementation",
                           if (!all(labelled)) paste(names(labelled)[!labelled], collapse = ", ") else ""))
refs_doi <- vapply(cff$references, function(r) if (is.null(r$doi)) "" else r$doi, "")
check(all(refs_doi %in% c("", FROZEN_DOI)),
      "CITATION.cff references carry no DOI other than the frozen one")

ms <- Filter(function(r) identical(r$type, "manuscript"), cff$references)
check(length(ms) == 1L && grepl("submitted", ms[[1]]$notes, ignore.case = TRUE),
      "CITATION.cff manuscript reference is 'submitted'")
check(any(grepl('bibtype = "Unpublished"', inst_cit, fixed = TRUE)),
      "inst/CITATION manuscript entry is Unpublished")
pub <- vapply(txt, function(x) any(grepl(
    "(published in|has been published|accepted for publication|in press)",
    x, ignore.case = TRUE)), TRUE)
check(!any(pub), paste("no accepted/published/in-press wording",
                       if (any(pub)) paste(names(pub)[pub], collapse = ", ") else ""))

if (length(failures)) {
    cat("\nCITATION AUDIT FAILED\n")
    quit(status = 1L)
}
cat(sprintf("\nCITATION AUDIT PASSED (version %s, no package DOI)\n", version))
