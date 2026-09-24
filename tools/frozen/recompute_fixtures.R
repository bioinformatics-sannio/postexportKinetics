# =============================================================================
# Recompute frozen-reference outputs on the CURRENT platform from the
# COMMITTED fixture inputs.
#
# Usage (from the package root):
#   FROZEN=$(tools/frozen/export_frozen.sh)
#   Rscript tools/frozen/recompute_fixtures.R "$FROZEN" tests/testthat/fixtures <out_dir>
#
# Every case keeps its committed input (and reference values) unchanged; only
# the frozen output is recomputed by sourcing commons/nested_test2.r from the
# export. No input is regenerated: in particular the synthetic example data
# (originally simulated with deSolve) are reused as stored, so the numerical
# core is isolated from cross-platform ODE-solver differences.
#
# The committed fixtures are never modified; results go to <out_dir>, with
# provenance describing the current platform and a pointer to the provenance
# of the committed inputs. Used for same-platform package-vs-frozen
# validation on platforms other than the fixture platform (e.g. Linux CI).
# =============================================================================

FROZEN_TAG <- "manuscript-revision-v1.0"
FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3L) {
  stop("Usage: Rscript tools/frozen/recompute_fixtures.R <frozen_export> <committed_dir> <out_dir>")
}

snap <- normalizePath(args[1], mustWork = TRUE)
in_dir <- normalizePath(args[2], mustWork = TRUE)
out_dir <- args[3]

if (!identical(readLines(file.path(snap, ".frozen_commit")), FROZEN_COMMIT)) {
  stop("Frozen export does not carry the expected commit marker.")
}
if (normalizePath(out_dir, mustWork = FALSE) == in_dir) {
  stop("Refusing to overwrite the committed fixtures.")
}
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

core_file <- file.path(snap, "commons", "nested_test2.r")
frozen <- new.env(parent = globalenv())
sys.source(core_file, envir = frozen)
core_lines <- readLines(core_file, warn = FALSE)

capture <- function(expr) {
  tryCatch(list(value = expr), error = function(e) list(error = conditionMessage(e)))
}

current_provenance <- function(committed) {
  list(
    frozen_tag = FROZEN_TAG,
    frozen_commit = FROZEN_COMMIT,
    frozen_md5 = tools::md5sum(c(core = core_file)),
    generated_by = "tools/frozen/recompute_fixtures.R",
    generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    inputs_from = list(
      generated_by = committed$generated_by,
      generated_at = committed$generated_at,
      platform = committed$platform,
      La_library = committed$La_library
    ),
    R_version = R.version.string,
    platform = R.version$platform,
    sysname = unname(Sys.info()["sysname"]),
    machine = unname(Sys.info()["machine"]),
    La_version = La_version(),
    La_library = La_library(),
    BLAS = unname(extSoftVersion()["BLAS"]),
    RNGkind = RNGkind(),
    packages = vapply(
      c("nnls", "MASS"),
      function(p) as.character(utils::packageVersion(p)),
      character(1)
    )
  )
}

# Same frozen call as in tools/frozen/make_fixtures.R (run_frozen_test).
run_frozen_test <- function(d, t_star, B, seed) {
  capture(frozen$test_sigma_nested(
    tsampled_data = d, scaling_A = TRUE, t_star = t_star, B_n = B,
    seed = seed, lambda_time = 0.5, lambda_diag = 0.1, rel_floor = 1e-8,
    truncate_nonnegative_boot = FALSE, max_failure_rate = 0.05,
    return_boot = TRUE
  ))
}

# Same frozen computation as in tools/frozen/make_fixtures.R (section 9).
run_frozen_real <- function(d) {
  bo <- frozen$build_Ab_fullcov(d, scaling_A = TRUE, t_star = 0,
                                lambda_time = 0.5, lambda_diag = 0.1,
                                rel_floor = 1e-8)
  fo <- frozen$fit_nnls_nested_once(bo$A, bo$b, bo$Sigma_b, col_test = 4L,
                                    rel_floor = 1e-8)
  coef_full <- fo$coef_full_scaled / bo$col_norms
  names(coef_full) <- frozen$PARAM_NAMES
  list(value = list(built = bo, fit = fo, coef_full = coef_full,
                    sigma_c = unname(coef_full["sigma_c"]),
                    IR = max(fo$RSS0 - fo$RSS1, 0) / fo$RSS0))
}

recompute_case <- function(fixture, case) {
  inp <- case$input
  if (startsWith(fixture, "fx_source")) {
    return(list(text = core_lines[inp$lines[1]:inp$lines[2]]))
  }
  if (fixture == "fx_test_sigma_nested") {
    return(run_frozen_test(inp$data, inp$t_star, inp$B_n, inp$seed))
  }
  if (fixture == "fx_real_mesc") {
    return(run_frozen_real(inp$data))
  }
  f <- get(inp$fun, envir = frozen, mode = "function")
  if (fixture == "fx_bootstrap") {
    set.seed(inp$seed)
    if (identical(inp$n_calls, 2L)) {
      first <- capture(do.call(f, inp$args))
      second <- capture(do.call(f, inp$args))
      return(list(value = list(first = first, second = second)))
    }
    return(capture(do.call(f, inp$args)))
  }
  # Phase 2 orchestration cases: the frozen call used seed = NULL after
  # set.seed(pre_seed) on the global RNG.
  if (!is.null(inp$pre_seed)) set.seed(inp$pre_seed)
  capture(do.call(f, inp$args))
}

for (file in sort(list.files(in_dir, pattern = "\\.rds$"))) {
  fixture <- sub("\\.rds$", "", file)
  fx <- readRDS(file.path(in_dir, file))
  stopifnot(identical(fx$provenance$frozen_commit, FROZEN_COMMIT))
  out <- fx
  out$provenance <- current_provenance(fx$provenance)
  for (key in names(fx$cases)) {
    out$cases[[key]]$output <- recompute_case(fixture, fx$cases[[key]])
  }
  saveRDS(out, file.path(out_dir, file), version = 3)
  cat(sprintf("  %-28s %4d cases recomputed\n", fixture, length(fx$cases)))
}
