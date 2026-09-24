# =============================================================================
# Generate frozen-reference regression fixtures.
#
# Usage (from the package root):
#   FROZEN=$(tools/frozen/export_frozen.sh)
#   Rscript tools/frozen/make_fixtures.R "$FROZEN"
#
# The script sources ONLY function definitions from the frozen export:
#   commons/nested_test2.r   (inference core; pure definitions + library calls)
#   ode_model/ode.r          (ODE simulator; used only to build example data)
#   commons/platforms.r      (assay noise; used only to build example data)
# No top-level analysis script is executed. The real-data fixture reproduces
# the frozen conversion in real_datasets/GSE256335/gen_RMATS_table.r:36-150
# (event id, time/replicate parsing, state map, sum, dcast) for a small set of
# events only.
#
# Output: tests/testthat/fixtures/*.rds. Each file is a list with elements
#   provenance  frozen tag/commit/file checksums and the generating platform
#   cases       named list; each case = list(input = <args>, output = <value
#               or list(error = <message>)>)
#
# Fixtures are regenerated only by this script and never edited by hand.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
})

FROZEN_TAG <- "manuscript-revision-v1.0"
FROZEN_COMMIT <- "65c3b7368fb7686bfde3dab857f98c393bb534c5"

args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1L) {
  stop("Usage: Rscript tools/frozen/make_fixtures.R <frozen_export_dir> [out_dir]")
}

snap <- normalizePath(args[1], mustWork = TRUE)
out_dir <- if (length(args) >= 2L) args[2] else "tests/testthat/fixtures"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

commit_file <- file.path(snap, ".frozen_commit")

if (!file.exists(commit_file) ||
    !identical(readLines(commit_file), FROZEN_COMMIT)) {
  stop("Frozen export does not carry the expected commit marker.")
}

core_file <- file.path(snap, "commons", "nested_test2.r")
ode_file <- file.path(snap, "ode_model", "ode.r")
platforms_file <- file.path(snap, "commons", "platforms.r")


# -----------------------------------------------------------------------------
# Frozen environments
# -----------------------------------------------------------------------------

frozen <- new.env(parent = globalenv())
sys.source(core_file, envir = frozen)

sim <- new.env(parent = globalenv())
sys.source(ode_file, envir = sim)
sys.source(platforms_file, envir = sim)


# -----------------------------------------------------------------------------
# Provenance
# -----------------------------------------------------------------------------

provenance <- list(
  frozen_tag = FROZEN_TAG,
  frozen_commit = FROZEN_COMMIT,
  frozen_md5 = tools::md5sum(c(
    core = core_file,
    ode = ode_file,
    platforms = platforms_file
  )),
  generated_by = "tools/frozen/make_fixtures.R",
  generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
  R_version = R.version.string,
  platform = R.version$platform,
  sysname = unname(Sys.info()["sysname"]),
  machine = unname(Sys.info()["machine"]),
  La_version = La_version(),
  La_library = La_library(),
  BLAS = unname(extSoftVersion()["BLAS"]),
  RNGkind = RNGkind(),
  packages = vapply(
    c("nnls", "MASS", "deSolve", "data.table"),
    function(p) as.character(utils::packageVersion(p)),
    character(1)
  )
)

capture <- function(expr) {
  tryCatch(
    list(value = expr),
    error = function(e) list(error = conditionMessage(e))
  )
}

save_fixture <- function(name, cases, extra = list()) {
  obj <- c(list(provenance = provenance, cases = cases), extra)
  saveRDS(obj, file.path(out_dir, paste0(name, ".rds")), version = 3)
  cat(sprintf("  %-28s %4d cases\n", name, length(cases)))
}

cat("Writing fixtures to", out_dir, "\n")


# =============================================================================
# 0. Frozen source text of every ported object (verbatim-port check)
# =============================================================================

port_ranges <- list(
  KINETIC_VARS = c(29, 34),
  PARAM_NAMES = c(36, 44),
  make_spd = c(51, 145),
  inverse_sqrt_matrix = c(148, 192),
  time_summary_cov_shrink = c(199, 448),
  build_sigma_means = c(455, 533),
  build_difference_matrix = c(536, 573),
  build_Ab_fullcov = c(580, 889),
  fit_nnls_nested_once = c(896, 1079),
  kinetic_matrix = c(1093, 1126),
  cn_interval = c(1147, 1213),
  predict_null_cn = c(1216, 1310),
  simulate_destructive_null = c(1317, 1440)
)

core_lines <- readLines(core_file, warn = FALSE)

source_cases <- lapply(names(port_ranges), function(nm) {
  r <- port_ranges[[nm]]
  txt <- core_lines[r[1]:r[2]]
  if (!startsWith(txt[1], paste0(nm, " <-"))) {
    stop("Unexpected first line for ", nm, ": ", txt[1])
  }
  list(
    input = list(name = nm, file = "commons/nested_test2.r", lines = r),
    output = list(text = txt)
  )
})
names(source_cases) <- names(port_ranges)

save_fixture("fx_source", source_cases)


# =============================================================================
# 1. Matrix utilities
# =============================================================================

set.seed(101)
M4 <- matrix(stats::rnorm(16), 4, 4)
S_spd <- crossprod(M4) + diag(0.1, 4)
S_asym <- S_spd
S_asym[1, 2] <- S_asym[1, 2] + 1e-9

matrices <- list(
  spd = S_spd,
  asymmetric = S_asym,
  indefinite = matrix(c(2, 3, 0, 3, 2, 0, 0, 0, 1), 3, 3),
  zero_diag = matrix(c(0, 1, 1, 0), 2, 2),
  rank1 = tcrossprod(c(1, 2, 3, 4)),
  one_by_one = matrix(4, 1, 1),
  tiny_scale = S_spd * 1e-20,
  huge_scale = S_spd * 1e12,
  all_zero = matrix(0, 3, 3),
  non_finite = matrix(c(1, NA, NA, 1), 2, 2),
  non_square = matrix(1, 2, 3),
  named = structure(S_spd, dimnames = list(letters[1:4], letters[1:4]))
)

matrix_cases <- list()

for (nm in names(matrices)) {
  S <- matrices[[nm]]
  for (rf in c(1e-8, 1e-4)) {
    key <- sprintf("make_spd/%s/rel_floor=%g", nm, rf)
    matrix_cases[[key]] <- list(
      input = list(fun = "make_spd", args = list(S = S, rel_floor = rf)),
      output = capture(frozen$make_spd(S, rel_floor = rf))
    )
    key <- sprintf("inverse_sqrt_matrix/%s/rel_floor=%g", nm, rf)
    matrix_cases[[key]] <- list(
      input = list(fun = "inverse_sqrt_matrix",
                   args = list(Sigma = S, rel_floor = rf)),
      output = capture(frozen$inverse_sqrt_matrix(S, rel_floor = rf))
    )
  }
}

save_fixture("fx_matrix", matrix_cases)


# =============================================================================
# 2. Hand-built destructive-sampling datasets
# =============================================================================

make_dataset <- function(times, n_rep, seed, level = 1) {
  set.seed(seed)
  rows <- list()
  for (k in seq_along(times)) {
    tt <- times[k]
    nk <- if (length(n_rep) == 1L) n_rep else n_rep[k]
    base <- c(
      N = 60 * exp(-0.020 * tt),
      N_s = 25 * exp(-0.010 * tt) + 5,
      C = 30 * exp(-0.015 * tt) + 2,
      C_s = 40 + 0.05 * tt
    )
    for (r in seq_len(nk)) {
      shared <- stats::rnorm(1, 0, 0.05)
      vals <- base * exp(shared + stats::rnorm(4, 0, 0.08))
      rows[[length(rows) + 1L]] <- data.frame(
        time = tt,
        replicate = r,
        N = level * vals[["N"]],
        N_s = level * vals[["N_s"]],
        C = level * vals[["C"]],
        C_s = level * vals[["C_s"]]
      )
    }
  }
  do.call(rbind, rows)
}

times5 <- c(0, 10, 20, 40, 80)

datasets <- list()
datasets$basic <- make_dataset(times5, 3, seed = 11)
set.seed(12)
datasets$unsorted <- datasets$basic[sample(nrow(datasets$basic)), ]
datasets$single_rep_time <- make_dataset(times5, c(3, 3, 3, 1, 3), seed = 13)
datasets$na_row <- make_dataset(times5, c(3, 4, 3, 3, 3), seed = 14)
datasets$na_row$C_s[5] <- NA
datasets$unequal <- make_dataset(times5, c(2, 3, 4, 3, 5), seed = 15)
datasets$two_times <- make_dataset(c(0, 10), 3, seed = 16)
datasets$tiny_scale <- make_dataset(times5, 3, seed = 17, level = 1e-10)
datasets$ten_reps <- make_dataset(c(0, 5, 15, 30, 60, 120), 10, seed = 18)

bad_datasets <- list(
  one_time = make_dataset(0, 3, seed = 21),
  no_replication = make_dataset(times5, 1, seed = 22),
  time_all_na = {
    d <- make_dataset(times5, 3, seed = 23)
    d$N[d$time == 20] <- NA
    d
  },
  missing_column = make_dataset(times5, 3, seed = 24)[, c("time", "replicate",
                                                          "N", "N_s", "C")]
)

lambda_grid <- list(
  default = c(lambda_time = 0.5, lambda_diag = 0.1),
  none = c(lambda_time = 0, lambda_diag = 0),
  full = c(lambda_time = 1, lambda_diag = 1),
  mixed = c(lambda_time = 0.2, lambda_diag = 0.7)
)


# =============================================================================
# 3. Covariance estimation and propagation
# =============================================================================

cov_cases <- list()

for (dn in names(datasets)) {
  for (ln in names(lambda_grid)) {
    lam <- lambda_grid[[ln]]
    a <- list(
      df = datasets[[dn]],
      lambda_time = lam[["lambda_time"]],
      lambda_diag = lam[["lambda_diag"]],
      rel_floor = 1e-8
    )
    cov_cases[[sprintf("time_summary_cov_shrink/%s/%s", dn, ln)]] <- list(
      input = list(fun = "time_summary_cov_shrink", args = a),
      output = capture(do.call(frozen$time_summary_cov_shrink, a))
    )
  }
}

for (dn in names(bad_datasets)) {
  a <- list(df = bad_datasets[[dn]])
  cov_cases[[sprintf("time_summary_cov_shrink/%s/default", dn)]] <- list(
    input = list(fun = "time_summary_cov_shrink", args = a),
    output = capture(do.call(frozen$time_summary_cov_shrink, a))
  )
}

for (bad in list(c(-0.1, 0.1), c(0.5, 1.1))) {
  a <- list(df = datasets$basic, lambda_time = bad[1], lambda_diag = bad[2])
  cov_cases[[sprintf("time_summary_cov_shrink/basic/invalid_%g_%g",
                     bad[1], bad[2])]] <- list(
    input = list(fun = "time_summary_cov_shrink", args = a),
    output = capture(do.call(frozen$time_summary_cov_shrink, a))
  )
}

for (dn in names(datasets)) {
  S <- frozen$time_summary_cov_shrink(datasets[[dn]])
  cov_cases[[sprintf("build_sigma_means/%s", dn)]] <- list(
    input = list(fun = "build_sigma_means", args = list(summary_obj = S)),
    output = capture(frozen$build_sigma_means(S))
  )
}

for (K in 1:6) {
  cov_cases[[sprintf("build_difference_matrix/K=%d", K)]] <- list(
    input = list(fun = "build_difference_matrix", args = list(K = K)),
    output = capture(frozen$build_difference_matrix(K))
  )
}

save_fixture("fx_covariance", cov_cases)


# =============================================================================
# 4. Interval-balance construction
# =============================================================================

tstar_grid <- list(
  "NULL" = NULL,
  "-5" = -5,
  "0" = 0,
  "15" = 15,
  "20" = 20,
  "80" = 80,
  "200" = 200
)

ib_cases <- list()

for (dn in names(datasets)) {
  for (tn in names(tstar_grid)) {
    for (sc in c(TRUE, FALSE)) {
      a <- list(
        tsampled_data = datasets[[dn]],
        scaling_A = sc,
        t_star = tstar_grid[[tn]],
        lambda_time = 0.5,
        lambda_diag = 0.1,
        rel_floor = 1e-8
      )
      key <- sprintf("build_Ab_fullcov/%s/t_star=%s/scaling=%s", dn, tn, sc)
      ib_cases[[key]] <- list(
        input = list(fun = "build_Ab_fullcov", args = a),
        output = capture(do.call(frozen$build_Ab_fullcov, a))
      )
    }
  }
}

for (ln in names(lambda_grid)[-1]) {
  lam <- lambda_grid[[ln]]
  a <- list(
    tsampled_data = datasets$basic,
    scaling_A = TRUE,
    t_star = 15,
    lambda_time = lam[["lambda_time"]],
    lambda_diag = lam[["lambda_diag"]],
    rel_floor = 1e-8
  )
  ib_cases[[sprintf("build_Ab_fullcov/basic/t_star=15/lambda=%s", ln)]] <- list(
    input = list(fun = "build_Ab_fullcov", args = a),
    output = capture(do.call(frozen$build_Ab_fullcov, a))
  )
}

for (bad in list(c(1, 2), NA_real_, Inf)) {
  a <- list(tsampled_data = datasets$basic, t_star = bad)
  ib_cases[[sprintf("build_Ab_fullcov/basic/invalid_t_star=%s",
                    paste(bad, collapse = ","))]] <- list(
    input = list(fun = "build_Ab_fullcov", args = a),
    output = capture(do.call(frozen$build_Ab_fullcov, a))
  )
}

for (dn in names(bad_datasets)) {
  a <- list(tsampled_data = bad_datasets[[dn]])
  ib_cases[[sprintf("build_Ab_fullcov/%s/default", dn)]] <- list(
    input = list(fun = "build_Ab_fullcov", args = a),
    output = capture(do.call(frozen$build_Ab_fullcov, a))
  )
}

save_fixture("fx_interval_balance", ib_cases)


# =============================================================================
# 5. NNLS fitting
# =============================================================================

fit_cases <- list()

for (key in names(ib_cases)) {
  built <- ib_cases[[key]]$output$value
  if (is.null(built)) next
  for (rf in c(1e-8, 1e-4)) {
    a <- list(A = built$A, b = built$b, Sigma_b = built$Sigma_b,
              col_test = 4L, rel_floor = rf)
    fkey <- sprintf("fit_nnls_nested_once/%s/rel_floor=%g",
                    sub("^build_Ab_fullcov/", "", key), rf)
    fit_cases[[fkey]] <- list(
      input = list(fun = "fit_nnls_nested_once", args = a),
      output = capture(do.call(frozen$fit_nnls_nested_once, a))
    )
  }
}

ref <- ib_cases[["build_Ab_fullcov/basic/t_star=15/scaling=TRUE"]]$output$value

malformed <- list(
  dimension_mismatch = list(A = ref$A, b = ref$b[-1], Sigma_b = ref$Sigma_b),
  non_finite_A = list(A = replace(ref$A, 1, NA), b = ref$b, Sigma_b = ref$Sigma_b),
  non_finite_b = list(A = ref$A, b = replace(ref$b, 2, Inf), Sigma_b = ref$Sigma_b),
  indefinite_Sigma = list(
    A = ref$A, b = ref$b,
    Sigma_b = ref$Sigma_b - diag(max(diag(ref$Sigma_b)), nrow(ref$Sigma_b))
  ),
  col_test_1 = list(A = ref$A, b = ref$b, Sigma_b = ref$Sigma_b, col_test = 1L)
)

for (nm in names(malformed)) {
  a <- malformed[[nm]]
  fit_cases[[sprintf("fit_nnls_nested_once/malformed/%s", nm)]] <- list(
    input = list(fun = "fit_nnls_nested_once", args = a),
    output = capture(do.call(frozen$fit_nnls_nested_once, a))
  )
}

save_fixture("fx_fit", fit_cases)


# =============================================================================
# 6. Crank-Nicolson propagation
# =============================================================================

theta_list <- list(
  typical = c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1,
              sigma_n = 0.1, alpha = 0.2, alpha_s = 0.08),
  null = c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0,
           sigma_n = 0.1, alpha = 0.2, alpha_s = 0.08),
  fast = c(R = 5, tau = 0.06, tau_s = 0.03, sigma_c = 0.2,
           sigma_n = 0.2, alpha = 0.69, alpha_s = 0.23),
  zero = c(R = 0, tau = 0, tau_s = 0, sigma_c = 0,
           sigma_n = 0, alpha = 0, alpha_s = 0)
)

x0_list <- list(
  steady = c(N = 769.2, N_s = 1025.6, C = 76.9, C_s = 1394.2),
  empty = c(N = 0, N_s = 0, C = 0, C_s = 0),
  mixed = c(N = 12.7, N_s = 0.6, C = 3.1, C_s = 0.1)
)

cn_cases <- list()

for (tn in names(theta_list)) {
  cn_cases[[sprintf("kinetic_matrix/%s", tn)]] <- list(
    input = list(fun = "kinetic_matrix", args = list(theta = theta_list[[tn]])),
    output = capture(frozen$kinetic_matrix(theta_list[[tn]]))
  )
}

for (tn in names(theta_list)) {
  for (xn in names(x0_list)) {
    for (dt in c(0.5, 10, 50)) {
      for (Radt in unique(c(0, dt / 2, dt))) {
        a <- list(x0 = x0_list[[xn]], dt = dt, theta = theta_list[[tn]],
                  R_active_dt = Radt)
        cn_cases[[sprintf("cn_interval/%s/%s/dt=%g/Radt=%g",
                          tn, xn, dt, Radt)]] <- list(
          input = list(fun = "cn_interval", args = a),
          output = capture(do.call(frozen$cn_interval, a))
        )
      }
    }
  }
}

for (dt in c(0, -1, NA_real_)) {
  a <- list(x0 = x0_list$mixed, dt = dt, theta = theta_list$typical,
            R_active_dt = 0)
  cn_cases[[sprintf("cn_interval/invalid_dt=%s", dt)]] <- list(
    input = list(fun = "cn_interval", args = a),
    output = capture(do.call(frozen$cn_interval, a))
  )
}

pred_times <- list(
  observed = c(0, 10, 20, 40, 80),
  unsorted_dup = c(40, 0, 10, 10, 80, 20),
  single = 5,
  dense = seq(0, 240, by = 30)
)

tstar_cn <- list("NULL" = NULL, "-5" = -5, "0" = 0, "15" = 15, "1000" = 1000)

for (pn in names(pred_times)) {
  for (tn in c("typical", "fast")) {
    for (sn in names(tstar_cn)) {
      a <- list(times = pred_times[[pn]], x0 = x0_list$mixed,
                theta0 = theta_list[[tn]], t_star = tstar_cn[[sn]])
      cn_cases[[sprintf("predict_null_cn/%s/%s/t_star=%s", pn, tn, sn)]] <- list(
        input = list(fun = "predict_null_cn", args = a),
        output = capture(do.call(frozen$predict_null_cn, a))
      )
    }
  }
}

neg <- theta_list$typical
neg["alpha"] <- -0.1
a <- list(times = pred_times$observed, x0 = x0_list$mixed, theta0 = neg)
cn_cases[["predict_null_cn/invalid_negative_theta"]] <- list(
  input = list(fun = "predict_null_cn", args = a),
  output = capture(do.call(frozen$predict_null_cn, a))
)

a <- list(times = pred_times$observed, x0 = x0_list$mixed,
          theta0 = unname(theta_list$typical))
cn_cases[["predict_null_cn/unnamed_theta"]] <- list(
  input = list(fun = "predict_null_cn", args = a),
  output = capture(do.call(frozen$predict_null_cn, a))
)

save_fixture("fx_crank_nicolson", cn_cases)


# =============================================================================
# 7. Bootstrap generation
# =============================================================================

boot_cases <- list()

for (dn in c("basic", "single_rep_time", "unequal", "ten_reps")) {
  S <- frozen$time_summary_cov_shrink(datasets[[dn]])
  nm_theta <- theta_list$null
  nm <- frozen$predict_null_cn(S$times, S$means[1, ], nm_theta, t_star = 0)
  for (tr in c(FALSE, TRUE)) {
    for (seed in c(1L, 20260924L)) {
      set.seed(seed)
      first <- capture(frozen$simulate_destructive_null(nm, S, tr))
      second <- capture(frozen$simulate_destructive_null(nm, S, tr))
      boot_cases[[sprintf("simulate_destructive_null/%s/truncate=%s/seed=%d",
                          dn, tr, seed)]] <- list(
        input = list(
          fun = "simulate_destructive_null",
          args = list(null_means = nm, summary_obj = S,
                      truncate_nonnegative = tr),
          seed = seed,
          n_calls = 2L
        ),
        output = list(value = list(first = first, second = second))
      )
    }
  }
}

S <- frozen$time_summary_cov_shrink(datasets$basic)
bad_nm <- matrix(1, nrow = 3, ncol = 4)
set.seed(1)
boot_cases[["simulate_destructive_null/invalid_dimensions"]] <- list(
  input = list(fun = "simulate_destructive_null",
               args = list(null_means = bad_nm, summary_obj = S), seed = 1L,
               n_calls = 1L),
  output = capture(frozen$simulate_destructive_null(bad_nm, S))
)

save_fixture("fx_bootstrap", boot_cases)


# =============================================================================
# 8. Complete frozen tests on simulated null / alternative data
#
# Example data are simulated with the frozen ODE simulator and frozen assay
# noise functions. The complete frozen test_sigma_nested() output (with
# return_boot = TRUE) is stored so that the ported primitives can be composed
# and compared replicate by replicate.
# =============================================================================

make_params <- function(sigma_c, alpha, alpha_s) {
  # List order matters for the replicate-level RNG draws in
  # generate_ODE_states(): tau, tau_s, alpha, alpha_s, sigma_n, sigma_c, R.
  list(tau = 0.03, tau_s = 0.015, alpha = alpha, alpha_s = alpha_s,
       sigma_n = 0.1, sigma_c = sigma_c, R = 100)
}

# Example designs.
#   SHUTOFF: common t_star = 300, one pre-shutoff sample, samples at t_star and
#            four post-shutoff samples at spacing 20.
#   NONE:    continuous transcription, benchmark-style u^3 spacing.
design_times <- list(
  SHUTOFF = c(290, 300, 320, 340, 360, 380),
  NONE = c(1, 12, 41, 98, 192)
)

simulate_example <- function(e, sim_seed, noise_seed) {
  y0 <- c(N = 0, N_s = 0, C = 0, C_s = 0)
  stimes <- design_times[[e$design]]
  t_star <- if (e$design == "SHUTOFF") 300 else NULL
  set.seed(sim_seed)
  dd <- sim$generate_ODE_states(
    base_params = make_params(e$sigma_c, e$alpha, e$alpha_s),
    y0 = y0,
    times = 0:600,
    n_replicates = e$n_rep,
    stimes = stimes,
    shutofftimes = stimes,
    t_star = t_star,
    post_R_fraction = 0,
    use_onset_shift = FALSE,
    max_shift = 0,
    nominal_onset_time = 0
  )
  latent <- if (e$design == "SHUTOFF") {
    dd$intervention_tsampled_data
  } else {
    dd$tsampled_data
  }
  latent <- latent[, c("time", "replicate", "N", "N_s", "C", "C_s")]
  set.seed(noise_seed)
  noisy <- if (e$platform == "GAUSS_Low") {
    sim$add_gaussian_noise(latent, c("N", "C", "C_s", "N_s"), 0.05)
  } else {
    as.data.frame(sim$simulate_rnaseq(
      latent,
      targets = c("N", "C", "C_s", "N_s"),
      scale_counts = 1000,
      mean_disp = 0.10 * 0.25,
      cv_disp = 0.8
    ))
  }
  rownames(noisy) <- NULL
  list(data = noisy, t_star = t_star)
}

# Noise seeds were chosen once (by inspection with the frozen code) so that
# the null examples are off the boundary and the alternative shows a signal;
# they are fixed here and not searched.
examples <- list(
  null_shutoff_gauss = list(sigma_c = 0, alpha = 0.05, alpha_s = 0.03,
                            design = "SHUTOFF", n_rep = 5,
                            platform = "GAUSS_Low", noise_seed = 2L),
  alt_shutoff_gauss = list(sigma_c = 0.2, alpha = 0.2, alpha_s = 0.08,
                           design = "SHUTOFF", n_rep = 5,
                           platform = "GAUSS_Low", noise_seed = 2000L),
  alt_shutoff_rnaseq = list(sigma_c = 0.2, alpha = 0.2, alpha_s = 0.08,
                            design = "SHUTOFF", n_rep = 5,
                            platform = "RNAseq_Medium", noise_seed = 2000L),
  null_none_gauss = list(sigma_c = 0, alpha = 0.05, alpha_s = 0.03,
                         design = "NONE", n_rep = 3,
                         platform = "GAUSS_Low", noise_seed = 2000L)
)

test_cases <- list()

run_frozen_test <- function(d, t_star, B, seed) {
  capture(frozen$test_sigma_nested(
    tsampled_data = d,
    scaling_A = TRUE,
    t_star = t_star,
    B_n = B,
    seed = seed,
    lambda_time = 0.5,
    lambda_diag = 0.1,
    rel_floor = 1e-8,
    truncate_nonnegative_boot = FALSE,
    max_failure_rate = 0.05,
    return_boot = TRUE
  ))
}

for (en in names(examples)) {
  e <- examples[[en]]
  ex <- simulate_example(e, sim_seed = 1000L, noise_seed = e$noise_seed)
  for (B in c(19L, 99L)) {
    test_cases[[sprintf("test_sigma_nested/%s/B=%d", en, B)]] <- list(
      input = list(fun = "test_sigma_nested", data = ex$data,
                   t_star = ex$t_star, B_n = B, seed = 20260924L,
                   example = e),
      output = run_frozen_test(ex$data, ex$t_star, B, 20260924L)
    )
  }
}

# Boundary example: first noise seed for which the observed full fit places
# sigma_c on the boundary (T.obs <= tol_zero), deterministic search.
boundary_found <- FALSE
e_boundary <- list(sigma_c = 0, alpha = 0.2, alpha_s = 0.08,
                   design = "SHUTOFF", n_rep = 3, platform = "GAUSS_Low")

for (ns in 1:500) {
  ex <- simulate_example(e_boundary, sim_seed = 1000L, noise_seed = ns)
  bo <- frozen$build_Ab_fullcov(ex$data, TRUE, ex$t_star)
  fo <- frozen$fit_nnls_nested_once(bo$A, bo$b, bo$Sigma_b)
  tol <- 1e-10 * max(1, abs(fo$RSS0), abs(fo$RSS1))
  if (fo$T <= tol) {
    e_boundary$noise_seed <- ns
    test_cases[["test_sigma_nested/boundary_null_shutoff/B=99"]] <- list(
      input = list(fun = "test_sigma_nested", data = ex$data,
                   t_star = ex$t_star, B_n = 99L, seed = 20260924L,
                   example = e_boundary),
      output = run_frozen_test(ex$data, ex$t_star, 99L, 20260924L)
    )
    boundary_found <- TRUE
    break
  }
}

if (!boundary_found) stop("No boundary example found.")

# Observed-system failure (single time point) for status handling.
test_cases[["test_sigma_nested/observed_system_failed"]] <- list(
  input = list(fun = "test_sigma_nested", data = bad_datasets$one_time,
               t_star = NULL, B_n = 19L, seed = 1L),
  output = run_frozen_test(bad_datasets$one_time, NULL, 19L, 1L)
)

save_fixture("fx_test_sigma_nested", test_cases)


# =============================================================================
# 9. Real data: mESC (GSE256335) events from the final audit
#
# Deterministic observed-fit quantities only (no bootstrap). References from
# real_datasets/final_real_data_audit/final_mesc_FDR10_events.tsv, which
# includes the two representative events (Ppp1r36dn, Nsd1).
# =============================================================================

ref_tab <- fread(file.path(snap, "real_datasets", "final_real_data_audit",
                           "final_mesc_FDR10_events.tsv"))
rep_tab <- fread(file.path(snap, "real_datasets", "final_real_data_audit",
                           "final_representative_events.tsv"))

d_rmats <- fread(file.path(snap, "real_datasets", "GSE256335",
                           "gse256335_mouse_normalized.csv"))

# Frozen conversion, real_datasets/GSE256335/gen_RMATS_table.r (event id,
# parsing, state map, sum by event/time/replicate/state, dcast fill = 0).
d_rmats[, event := paste(
  gene, chr, strand,
  upstreamES, upstreamEE, downstreamES, downstreamEE,
  sep = ":"
)]
d_rmats <- d_rmats[event %in% ref_tab$event_final]
d_rmats[, time := as.numeric(sub("_", ".", sub("^t", "", timepoint)))]
d_rmats[, replicate := as.integer(sub("^r", "", replicate))]
d_rmats[, State := fifelse(
  compartment == "nuc" & version == "inclusion", "N",
  fifelse(
    compartment == "nuc" & version == "skipping", "N_s",
    fifelse(
      compartment == "cyt" & version == "inclusion", "C",
      fifelse(
        compartment == "cyt" & version == "skipping", "C_s",
        NA_character_
      )
    )
  )
)]
agg <- d_rmats[, .(Value = sum(count, na.rm = TRUE)),
               by = .(event, time, replicate, State)]
rmats_dt <- dcast(agg, event + time + replicate ~ State,
                  value.var = "Value", fill = 0)

real_cases <- list()

for (i in seq_len(nrow(ref_tab))) {
  ev <- ref_tab$event_final[i]
  d <- as.data.frame(rmats_dt[event == ev,
                              .(time, replicate, N, N_s, C, C_s)])
  bo <- frozen$build_Ab_fullcov(d, scaling_A = TRUE, t_star = 0,
                                lambda_time = 0.5, lambda_diag = 0.1,
                                rel_floor = 1e-8)
  fo <- frozen$fit_nnls_nested_once(bo$A, bo$b, bo$Sigma_b, col_test = 4L,
                                    rel_floor = 1e-8)
  coef_full <- fo$coef_full_scaled / bo$col_norms
  names(coef_full) <- frozen$PARAM_NAMES
  real_cases[[sprintf("%s|%s", ref_tab$gene_final[i], ev)]] <- list(
    input = list(fun = "real_mesc_fit", event = ev,
                 gene = ref_tab$gene_final[i], data = d, t_star = 0),
    output = list(value = list(
      built = bo,
      fit = fo,
      coef_full = coef_full,
      sigma_c = unname(coef_full["sigma_c"]),
      IR = max(fo$RSS0 - fo$RSS1, 0) / fo$RSS0
    )),
    reference = list(
      sigma_c_final = ref_tab$sigma_c_final[i],
      IR_final = ref_tab$IR_final[i],
      p_final = ref_tab$p_final[i],
      q_final = ref_tab$q_final[i],
      source = "real_datasets/final_real_data_audit/final_mesc_FDR10_events.tsv"
    )
  )
}

save_fixture(
  "fx_real_mesc",
  real_cases,
  extra = list(representative = as.data.frame(rep_tab))
)

cat("Done.\n")
