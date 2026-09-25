# =============================================================================
# Verify that the packaged benchmark-design table (R/sysdata.rda, built by
# data-raw/benchmark_domain.R) was built from the frozen tag's benchmark files.
#
# Usage: Rscript tools/ci/check_benchmark_provenance.R <frozen_export_dir>
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
snap <- normalizePath(args[1], mustWork = TRUE)
env <- new.env()
load(file.path("R", "sysdata.rda"), envir = env)
prov <- env$.pek_benchmark_provenance
stopifnot(identical(prov$frozen_commit, readLines(file.path(snap, ".frozen_commit"))))
md5_sum <- unname(tools::md5sum(file.path(snap, prov$summary_file)))
md5_meta <- unname(tools::md5sum(file.path(snap, prov$run_metadata_file)))
cat("summary md5 packaged:", prov$summary_md5, "frozen:", md5_sum, "\n")
cat("run metadata md5 packaged:", prov$run_metadata_md5, "frozen:", md5_meta, "\n")
if (!identical(prov$summary_md5, md5_sum) ||
    !identical(prov$run_metadata_md5, md5_meta)) {
  cat("::error::Packaged benchmark table does not match the frozen benchmark files.\n")
  quit(status = 1L)
}
cat("Packaged benchmark table matches the frozen benchmark files.\n")
