# =============================================================================
# Record the exact R runtime of a CI job, for provenance only.
#
# Usage: Rscript tools/ci/record_r_provenance.R <job label>
#
# Emits one GitHub Actions ::notice:: annotation (readable through the public
# checks API without authentication) and appends the same information to the
# job summary ($GITHUB_STEP_SUMMARY). It does not change any test behaviour.
# =============================================================================

label <- commandArgs(trailingOnly = TRUE)
label <- if (length(label)) paste(label, collapse = " ") else "job"
os <- tryCatch(utils::sessionInfo()$running, error = function(e) NA_character_)
fields <- c(
    R = R.version.string,
    platform = R.version$platform,
    os = if (is.null(os)) NA_character_ else os,
    lapack = La_version(),
    rng = paste(RNGkind(), collapse = "/")
)
line <- paste(sprintf("%s: %s", names(fields), fields), collapse = " | ")
cat(sprintf("::notice title=R provenance (%s)::%s\n", label, line))

summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) {
    cat(sprintf("### R provenance (%s)\n\n", label),
        paste0("- ", names(fields), ": `", fields, "`\n"), "\n",
        sep = "", file = summary_file, append = TRUE)
}
