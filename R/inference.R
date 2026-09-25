# =============================================================================
# Internal bootstrap test orchestration
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. The function body is unchanged except for the
# mechanical edits listed below. Equivalence with the frozen source is
# asserted by tests/testthat/test-verbatim-port.R and the orchestration
# regression tests.
# =============================================================================


#' Bootstrap-calibrated constrained nested-model test of sigma_c (frozen)
#'
#' Frozen orchestration: observed interval-balance system, whitened NNLS fits
#' of the full and `sigma_c = 0` null models, statistic
#' `T = max(0, RSS0 - RSS1)`, Crank-Nicolson null mean trajectory,
#' replicate-level generative bootstrap with reconstruction of A*, b* and
#' Sigma_b* in every replicate, bootstrap failure-rate rule, deterministic
#' boundary rule and add-one p-value. Returns the frozen result list with the
#' frozen status codes (`ok`, `observed_system_failed`, `observed_fit_failed`,
#' `null_trajectory_failed`, `bootstrap_unstable`).
#'
#' Mechanical edits: `median()` -> `stats::median()`, `quantile()` ->
#' `stats::quantile()`, `setNames()` -> `stats::setNames()`. The frozen
#' arguments `lambda_var` (compatibility alias) and `verbose` (unused) are
#' retained here for verbatim equivalence and are not exposed by the public
#' API.
#'
#' Frozen source: `commons/nested_test2.r:1447-2166`.
#' @keywords internal
#' @noRd
test_sigma_nested <- function(
  tsampled_data,

  scaling_A = TRUE,

  t_star = NULL,

  B_n = 1999,

  seed = NULL,

  # New covariance shrinkage parameters
  lambda_time = 0.5,
  lambda_diag = 0.1,

  # Backward-compatible alias:
  # if provided, lambda_var overrides lambda_time.
  lambda_var = NULL,

  rel_floor = 1e-8,

  truncate_nonnegative_boot = FALSE,

  max_failure_rate = 0.05,

  return_boot = FALSE,

  verbose = FALSE
) {

  # ---------------------------------------------------------------------------
  # Compatibility with old experimental script.
  # ---------------------------------------------------------------------------

  if (!is.null(lambda_var)) {

    lambda_time <-
      lambda_var
  }

  if (
    length(B_n) != 1L ||
      !is.finite(B_n) ||
      B_n < 1
  ) {

    stop(
      "B_n must be a positive integer."
    )
  }

  B_n <-
    as.integer(B_n)

  if (!is.null(seed)) {

    set.seed(seed)
  }

  # ===========================================================================
  # Observed system
  # ===========================================================================

  obs_error <-
    NULL

  built_obs <- tryCatch(

    build_Ab_fullcov(
      tsampled_data =
        tsampled_data,

      scaling_A =
        scaling_A,

      t_star =
        t_star,

      lambda_time =
        lambda_time,

      lambda_diag =
        lambda_diag,

      rel_floor =
        rel_floor
    ),

    error = function(e) {

      obs_error <<-
        conditionMessage(e)

      NULL
    }
  )

  if (is.null(built_obs)) {

    return(
      list(
        p.value =
          NA_real_,

        status =
          "observed_system_failed",

        error.message =
          obs_error
      )
    )
  }

  # ===========================================================================
  # Observed NNLS fit
  # ===========================================================================

  fit_obs <- fit_nnls_nested_once(
    A =
      built_obs$A,

    b =
      built_obs$b,

    Sigma_b =
      built_obs$Sigma_b,

    col_test =
      4L,

    rel_floor =
      rel_floor
  )

  if (is.null(fit_obs)) {

    return(
      list(
        p.value =
          NA_real_,

        status =
          "observed_fit_failed",

        error.message =
          "Observed GLS-NNLS fit failed."
      )
    )
  }

  # ===========================================================================
  # Rescale coefficients
  # ===========================================================================

  coef_full <-
    fit_obs$coef_full_scaled /
    built_obs$col_norms

  names(coef_full) <-
    PARAM_NAMES

  null_names <-
    PARAM_NAMES[-4L]

  coef_null_short <-
    fit_obs$coef_null_scaled /
    built_obs$col_norms[-4L]

  names(coef_null_short) <-
    null_names

  coef_null <- stats::setNames(
    rep(
      0,
      length(PARAM_NAMES)
    ),
    PARAM_NAMES
  )

  coef_null[
    null_names
  ] <- coef_null_short

  coef_null[
    "sigma_c"
  ] <- 0

  # ===========================================================================
  # Null mean trajectory
  # ===========================================================================

  times <-
    built_obs$summary$times

  x0 <-
    built_obs$summary$means[
      1,
      KINETIC_VARS
    ]

  null_error <-
    NULL

  null_means <- tryCatch(

    predict_null_cn(
      times =
        times,

      x0 =
        x0,

      theta0 =
        coef_null,

      t_star =
        t_star
    ),

    error = function(e) {

      null_error <<-
        conditionMessage(e)

      NULL
    }
  )

  if (
    is.null(null_means) ||
      any(!is.finite(null_means))
  ) {

    return(
      list(
        p.value =
          NA_real_,

        Sigma =
          coef_full["sigma_c"],

        Alpha =
          coef_full["alpha"],

        T.obs =
          fit_obs$T,

        RSS0 =
          fit_obs$RSS0,

        RSS1 =
          fit_obs$RSS1,

        status =
          "null_trajectory_failed",

        error.message =
          null_error
      )
    )
  }

  # ===========================================================================
  # Bootstrap
  # ===========================================================================

  T_boot <-
    rep(
      NA_real_,
      B_n
    )

  condition_boot <-
    rep(
      NA_real_,
      B_n
    )

  rank_boot <-
    rep(
      NA_integer_,
      B_n
    )

  failed <-
    logical(
      B_n
    )

  for (
    bb in seq_len(B_n)
  ) {

    # -------------------------------------------------------------------------
    # New independent destructive samples.
    # -------------------------------------------------------------------------

    data_star <- tryCatch(

      simulate_destructive_null(
        null_means =
          null_means,

        summary_obj =
          built_obs$summary,

        truncate_nonnegative =
          truncate_nonnegative_boot
      ),

      error = function(e)
        NULL
    )

    if (is.null(data_star)) {

      failed[bb] <-
        TRUE

      next
    }

    # -------------------------------------------------------------------------
    # Reconstruct A*, b*, Sigma_b*.
    # -------------------------------------------------------------------------

    built_star <- tryCatch(

      build_Ab_fullcov(
        tsampled_data =
          data_star,

        scaling_A =
          scaling_A,

        t_star =
          t_star,

        lambda_time =
          lambda_time,

        lambda_diag =
          lambda_diag,

        rel_floor =
          rel_floor
      ),

      error = function(e)
        NULL
    )

    if (is.null(built_star)) {

      failed[bb] <-
        TRUE

      next
    }

    # -------------------------------------------------------------------------
    # Null/full NNLS on bootstrap data.
    # -------------------------------------------------------------------------

    fit_star <-
      fit_nnls_nested_once(
        A =
          built_star$A,

        b =
          built_star$b,

        Sigma_b =
          built_star$Sigma_b,

        col_test =
          4L,

        rel_floor =
          rel_floor
      )

    if (
      is.null(fit_star) ||
        !is.finite(fit_star$T)
    ) {

      failed[bb] <-
        TRUE

      next
    }

    T_boot[bb] <-
      fit_star$T

    condition_boot[bb] <-
      fit_star$condition_number

    rank_boot[bb] <-
      fit_star$rank_full
  }

  valid <-
    !failed &
    is.finite(T_boot)

  T_ok <-
    T_boot[
      valid
    ]

  condition_ok <-
    condition_boot[
      valid
    ]

  rank_ok <-
    rank_boot[
      valid
    ]

  failure_rate <-
    mean(
      !valid
    )

  if (
    length(T_ok) == 0L ||
      failure_rate >
      max_failure_rate
  ) {

    return(
      list(
        p.value =
          NA_real_,

        Sigma =
          coef_full["sigma_c"],

        Alpha =
          coef_full["alpha"],

        T.obs =
          fit_obs$T,

        RSS0 =
          fit_obs$RSS0,

        RSS1 =
          fit_obs$RSS1,

        coef_full =
          coef_full,

        coef_null =
          coef_null,

        bootstrap.failure.rate =
          failure_rate,

        n.bootstrap.valid =
          length(T_ok),

        condition.number =
          fit_obs$condition_number,

        rank.full =
          fit_obs$rank_full,

        rank.null =
          fit_obs$rank_null,

        status =
          "bootstrap_unstable",

        error.message =
          paste(
            "Bootstrap failure rate =",
            signif(
              failure_rate,
              4
            )
          )
      )
    )
  }

  # ===========================================================================
  # Boundary tolerance
  # ===========================================================================

  # T = RSS0 - RSS1 is computed on the whitened scale.
  #
  # Values much smaller than numerical precision relative to the RSS scale
  # are interpreted as the NNLS boundary T = 0.

  rss_scale <- max(
    1,
    abs(
      fit_obs$RSS0
    ),
    abs(
      fit_obs$RSS1
    )
  )

  tol_zero <-
    1e-10 *
    rss_scale

  # ===========================================================================
  # Bootstrap p-value
  # ===========================================================================

  if (
    fit_obs$T <=
      tol_zero
  ) {

    p_val <-
      1

  } else {

    p_val <-
      (
        1 +
        sum(
          T_ok >=
            fit_obs$T
        )
      ) /
      (
        length(T_ok) +
        1
      )
  }

  # Empirical point mass at boundary.
  atom_zero <-
    mean(
      T_ok <=
        tol_zero
    )

  # ===========================================================================
  # Fit improvement
  # ===========================================================================

  DeltaRSS <- max(
    fit_obs$RSS0 -
      fit_obs$RSS1,
    0
  )

  IR <- if (
    is.finite(
      fit_obs$RSS0
    ) &&
      fit_obs$RSS0 >
      0
  ) {

    DeltaRSS /
      fit_obs$RSS0

  } else {

    NA_real_
  }

  # ===========================================================================
  # Bootstrap diagnostics
  # ===========================================================================

  condition_median <-
    stats::median(
      condition_ok,
      na.rm = TRUE
    )

  condition_q95 <-
    as.numeric(
      stats::quantile(
        condition_ok,
        probs = 0.95,
        na.rm = TRUE,
        names = FALSE
      )
    )

  condition_max <-
    max(
      condition_ok,
      na.rm = TRUE
    )

  rank_deficient_fraction <-
    mean(
      rank_ok <
        ncol(
          built_obs$A
        ),
      na.rm = TRUE
    )

  # ===========================================================================
  # Output
  # ===========================================================================

  retval <- list(
    p.value =
      p_val,

    Sigma =
      coef_full["sigma_c"],

    Alpha =
      coef_full["alpha"],

    T.obs =
      fit_obs$T,

    RSS0 =
      fit_obs$RSS0,

    RSS1 =
      fit_obs$RSS1,

    IR =
      IR,

    coef_full =
      coef_full,

    coef_null =
      coef_null,

    # Boundary diagnostic
    atom.zero =
      atom_zero,

    boundary.tolerance =
      tol_zero,

    # Bootstrap diagnostics
    bootstrap.failure.rate =
      failure_rate,

    n.bootstrap.valid =
      length(T_ok),

    bootstrap.condition.median =
      condition_median,

    bootstrap.condition.q95 =
      condition_q95,

    bootstrap.condition.max =
      condition_max,

    bootstrap.rank.deficient.fraction =
      rank_deficient_fraction,

    # Observed identifiability diagnostics
    condition.number =
      fit_obs$condition_number,

    min.singular.value =
      fit_obs$min_singular_value,

    rank.full =
      fit_obs$rank_full,

    rank.null =
      fit_obs$rank_null,

    # Shrinkage
    lambda.time =
      lambda_time,

    lambda.diag =
      lambda_diag,

    # Other useful information
    null.means =
      null_means,

    pooled.covariance =
      built_obs$summary$pooled_cov,

    n.replicates.by.time =
      built_obs$summary$n_rep,

    times =
      times,

    status =
      "ok",

    error.message =
      NULL
  )

  if (return_boot) {

    retval$T.boot <-
      T_ok

    retval$bootstrap.condition <-
      condition_ok

    retval$bootstrap.rank <-
      rank_ok
  }

  retval
}