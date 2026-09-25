# =============================================================================
# Generate Phase 2 frozen-reference fixtures (orchestration).
#
# Usage (from the package root):
#   FROZEN=$(tools/frozen/export_frozen.sh)
#   Rscript tools/frozen/make_fixtures_phase2.R "$FROZEN"
#
# Writes ONLY new files; the Phase 1 fixtures are never touched:
#   tests/testthat/fixtures/fx_source_orchestrator.rds
#       frozen source text of test_sigma_nested (commons/nested_test2.r:1447-2166)
#   tests/testthat/fixtures/fx_orchestrator.rds
#       complete frozen test_sigma_nested() results for orchestration options
#
# Inputs are taken from the COMMITTED Phase 1 fixtures (fx_test_sigma_nested,
# fx_real_mesc); no data are simulated here. Every case stores the complete
# argument list passed to the frozen function, and `pre_seed` when the frozen
# call uses seed = NULL (the global RNG is then set with set.seed(pre_seed)
# immediately before the call).
# =============================================================================

FROZEN_TAG <- "manuscript-revision-v1.0"
FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop("Usage: Rscript tools/frozen/make_fixtures_phase2.R <frozen_export_dir> [fixture_dir]")
}
snap <- normalizePath(args[1], mustWork = TRUE)
fx_dir <- if (length(args) >= 2L) args[2] else "tests/testthat/fixtures"

if (!identical(readLines(file.path(snap, ".frozen_commit")), FROZEN_COMMIT)) {
  stop("Frozen export does not carry the expected commit marker.")
}

for (f in c("fx_source_orchestrator.rds", "fx_orchestrator.rds")) {
  if (file.exists(file.path(fx_dir, f))) {
    stop("Refusing to overwrite existing fixture ", f)
  }
}

core_file <- file.path(snap, "commons", "nested_test2.r")
frozen <- new.env(parent = globalenv())
sys.source(core_file, envir = frozen)
core_lines <- readLines(core_file, warn = FALSE)

capture <- function(expr) {
  tryCatch(list(value = expr), error = function(e) list(error = conditionMessage(e)))
}

# MD5 of frozen files, named by their path relative to the export (never by
# a machine-specific absolute path).
frozen_md5 <- function(files) {
  md5 <- tools::md5sum(files)
  names(md5) <- substring(normalizePath(files), nchar(snap) + 2L)
  md5
}

provenance <- list(
  frozen_tag = FROZEN_TAG,
  frozen_commit = FROZEN_COMMIT,
  frozen_md5 = frozen_md5(core_file),
  generated_by = "tools/frozen/make_fixtures_phase2.R",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  inputs_from = c("fx_test_sigma_nested.rds", "fx_real_mesc.rds"),
  R_version = R.version.string,
  platform = R.version$platform,
  sysname = unname(Sys.info()["sysname"]),
  machine = unname(Sys.info()["machine"]),
  La_version = La_version(),
  La_library = La_library(),
  BLAS = unname(extSoftVersion()["BLAS"]),
  RNGkind = RNGkind(),
  packages = vapply(c("nnls", "MASS"),
                    function(p) as.character(utils::packageVersion(p)),
                    character(1))
)

save_fixture <- function(name, cases) {
  saveRDS(list(provenance = provenance, cases = cases),
          file.path(fx_dir, paste0(name, ".rds")), version = 3)
  cat(sprintf("  %-28s %4d cases\n", name, length(cases)))
}

# -----------------------------------------------------------------------------
# Frozen source text of the orchestrator
# -----------------------------------------------------------------------------

r <- c(1447, 2166)
txt <- core_lines[r[1]:r[2]]
stopifnot(startsWith(txt[1], "test_sigma_nested <-"))
save_fixture("fx_source_orchestrator", list(
  test_sigma_nested = list(
    input = list(name = "test_sigma_nested", file = "commons/nested_test2.r",
                 lines = r),
    output = list(text = txt)
  )
))

# -----------------------------------------------------------------------------
# Orchestration cases on committed inputs
# -----------------------------------------------------------------------------

fx_test <- readRDS(file.path(fx_dir, "fx_test_sigma_nested.rds"))
fx_real <- readRDS(file.path(fx_dir, "fx_real_mesc.rds"))

example_input <- function(name) {
  fx_test$cases[[sprintf("test_sigma_nested/%s/B=99", name)]]$input
}

frozen_defaults <- list(
  scaling_A = TRUE, B_n = 99L, seed = 20260924L, lambda_time = 0.5,
  lambda_diag = 0.1, rel_floor = 1e-8, truncate_nonnegative_boot = FALSE,
  max_failure_rate = 0.05, return_boot = TRUE
)

cases <- list()

add_case <- function(key, data, t_star, ..., pre_seed = NULL, meta = list()) {
  a <- utils::modifyList(frozen_defaults, list(...))
  a <- c(list(tsampled_data = data, t_star = t_star), a)
  if (!is.null(pre_seed)) set.seed(pre_seed)
  out <- capture(do.call(frozen$test_sigma_nested, a))
  cases[[key]] <<- list(
    input = list(fun = "test_sigma_nested", args = a, pre_seed = pre_seed,
                 meta = meta),
    output = out
  )
}

examples <- c("null_shutoff_gauss", "alt_shutoff_gauss", "alt_shutoff_rnaseq",
              "null_none_gauss")

for (ex in examples) {
  inp <- example_input(ex)
  add_case(sprintf("orchestrator/%s/default", ex), inp$data, inp$t_star,
           meta = list(example = ex))
  add_case(sprintf("orchestrator/%s/return_boot=FALSE", ex), inp$data,
           inp$t_star, return_boot = FALSE, meta = list(example = ex))
}

bnd <- fx_test$cases[["test_sigma_nested/boundary_null_shutoff/B=99"]]$input
add_case("orchestrator/boundary_null_shutoff/default", bnd$data, bnd$t_star,
         meta = list(example = "boundary_null_shutoff"))

alt <- example_input("alt_shutoff_gauss")
add_case("orchestrator/alt_shutoff_gauss/truncate_nonnegative_boot=TRUE",
         alt$data, alt$t_star, truncate_nonnegative_boot = TRUE)
add_case("orchestrator/alt_shutoff_gauss/scaling_A=FALSE",
         alt$data, alt$t_star, scaling_A = FALSE)
add_case("orchestrator/alt_shutoff_gauss/lambda=0.2,0.7/rel_floor=1e-6",
         alt$data, alt$t_star, lambda_time = 0.2, lambda_diag = 0.7,
         rel_floor = 1e-6)
add_case("orchestrator/alt_shutoff_gauss/t_star=305",
         alt$data, 305)
add_case("orchestrator/alt_shutoff_gauss/B=1", alt$data, alt$t_star, B_n = 1L)
add_case("orchestrator/alt_shutoff_gauss/seed=NULL/pre_seed=7",
         alt$data, alt$t_star, seed = NULL, pre_seed = 7L)
# Failure-rate rule: a negative max_failure_rate makes any failure rate
# (including 0) exceed it, exercising the frozen "bootstrap_unstable" branch.
add_case("orchestrator/alt_shutoff_gauss/bootstrap_unstable",
         alt$data, alt$t_star, max_failure_rate = -1)

one_time <- fx_test$cases[["test_sigma_nested/observed_system_failed"]]$input
add_case("orchestrator/observed_system_failed", one_time$data, NULL,
         B_n = 19L, seed = 1L)

for (gene in c("Ppp1r36dn", "Nsd1")) {
  key <- grep(paste0("^", gene, "\\|"), names(fx_real$cases), value = TRUE)
  stopifnot(length(key) == 1L)
  inp <- fx_real$cases[[key]]$input
  add_case(sprintf("orchestrator/real_mesc/%s", gene), inp$data, 0,
           B_n = 199L, meta = list(event = inp$event, gene = gene))
}

save_fixture("fx_orchestrator", cases)
cat("Done.\n")
