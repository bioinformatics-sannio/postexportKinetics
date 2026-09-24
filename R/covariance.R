# =============================================================================
# Internal covariance estimation and propagation
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Per-time means and shrunk within-time covariances
#'
#' Destructive-sampling summary: pooled within-time covariance shrunk toward
#' its diagonal (`lambda_diag`), per-time covariances shrunk toward the pooled
#' covariance (`lambda_time`), each stabilised by `make_spd()`; covariance of
#' the mean is `S_k / n_k`. Rows with any missing state are dropped per time
#' point (frozen behaviour). Mechanical edit: `complete.cases()` ->
#' `stats::complete.cases()`.
#'
#' Frozen source: `commons/nested_test2.r:199-448`.
#' @keywords internal
#' @noRd
time_summary_cov_shrink <- function(
  df,
  vars = KINETIC_VARS,
  lambda_time = 0.5,
  lambda_diag = 0.1,
  rel_floor = 1e-8
) {

  stopifnot(
    lambda_time >= 0,
    lambda_time <= 1,
    lambda_diag >= 0,
    lambda_diag <= 1
  )

  df <- as.data.frame(df)

  required_cols <- c(
    "time",
    vars
  )

  if (!all(required_cols %in% names(df))) {

    stop(
      paste(
        "Missing columns:",
        paste(
          setdiff(
            required_cols,
            names(df)
          ),
          collapse = ", "
        )
      )
    )
  }

  times <- sort(
    unique(df$time)
  )

  K <- length(times)
  P <- length(vars)

  if (K < 2L) {
    stop("At least two time points are required.")
  }

  means <- matrix(
    NA_real_,
    nrow = K,
    ncol = P,
    dimnames = list(
      as.character(times),
      vars
    )
  )

  n_rep <- integer(K)

  raw_cov <- vector(
    "list",
    K
  )

  # ---------------------------------------------------------------------------
  # Pooled WITHIN-TIME covariance.
  #
  # Mean changes between time points are explicitly excluded.
  # ---------------------------------------------------------------------------

  pooled_scatter <- matrix(
    0,
    nrow = P,
    ncol = P,
    dimnames = list(
      vars,
      vars
    )
  )

  pooled_df <- 0L

  for (k in seq_along(times)) {

    ti <- times[k]

    sub <- df[
      df$time == ti,
      vars,
      drop = FALSE
    ]

    sub <- sub[
      stats::complete.cases(sub),
      ,
      drop = FALSE
    ]

    nk <- nrow(sub)

    if (nk == 0L) {

      stop(
        paste(
          "No complete observations at time",
          ti
        )
      )
    }

    n_rep[k] <- nk

    means[k, ] <- colMeans(sub)

    if (nk >= 2L) {

      Sk <- stats::cov(sub)

      if (
        all(dim(Sk) == c(P, P)) &&
          all(is.finite(Sk))
      ) {

        raw_cov[[k]] <- Sk

        pooled_scatter <-
          pooled_scatter +
          (nk - 1L) * Sk

        pooled_df <-
          pooled_df +
          (nk - 1L)
      }
    }
  }

  if (pooled_df <= 0L) {

    stop(
      "Insufficient replication to estimate within-time covariance."
    )
  }

  S_pool <-
    pooled_scatter /
    pooled_df

  # ---------------------------------------------------------------------------
  # Scale-equivariant shrinkage toward diagonal covariance.
  # ---------------------------------------------------------------------------

  S_diag <- diag(
    diag(S_pool)
  )

  dimnames(S_diag) <-
    dimnames(S_pool)

  S_pool_shr <-
    (1 - lambda_diag) *
      S_pool +
    lambda_diag *
      S_diag

  S_pool_shr <- make_spd(
    S_pool_shr,
    rel_floor = rel_floor
  )

  if (is.null(S_pool_shr)) {

    stop(
      "Unable to stabilize pooled covariance."
    )
  }

  # ---------------------------------------------------------------------------
  # Shrink individual time-point covariance matrices toward pooled covariance.
  # ---------------------------------------------------------------------------

  cov_obs <- vector(
    "list",
    K
  )

  cov_mean <- vector(
    "list",
    K
  )

  for (k in seq_along(times)) {

    nk <- n_rep[k]

    if (
      nk >= 2L &&
        !is.null(raw_cov[[k]])
    ) {

      Sk <-
        (1 - lambda_time) *
          raw_cov[[k]] +
        lambda_time *
          S_pool_shr

    } else {

      Sk <- S_pool_shr
    }

    Sk <- make_spd(
      Sk,
      rel_floor = rel_floor
    )

    if (is.null(Sk)) {

      stop(
        paste(
          "Unable to stabilize covariance at time",
          times[k]
        )
      )
    }

    # Covariance of individual destructive samples.
    cov_obs[[k]] <- Sk

    # Covariance of the sample mean.
    cov_mean[[k]] <-
      Sk / nk
  }

  names(cov_obs) <-
    as.character(times)

  names(cov_mean) <-
    as.character(times)

  list(
    times = times,
    means = means,
    n_rep = n_rep,
    cov_obs = cov_obs,
    cov_mean = cov_mean,
    pooled_cov = S_pool_shr
  )
}


#' Block-diagonal covariance of the time-point means
#'
#' Species-major ordering `N(t1..tK), N_s(t1..tK), C(t1..tK), C_s(t1..tK)`. No
#' edits (uses the package constant `KINETIC_VARS`).
#'
#' Frozen source: `commons/nested_test2.r:455-533`.
#' @keywords internal
#' @noRd
build_sigma_means <- function(
  summary_obj
) {

  K <- length(
    summary_obj$times
  )

  P <- length(
    KINETIC_VARS
  )

  # Species-major ordering:
  #
  # N(t1)...N(tK),
  # Ns(t1)...Ns(tK),
  # C(t1)...C(tK),
  # Cs(t1)...Cs(tK)

  Sigma_m <- matrix(
    0,
    nrow = P * K,
    ncol = P * K
  )

  idx <- function(
    species,
    time_index
  ) {

    (species - 1L) *
      K +
      time_index
  }

  for (k in seq_len(K)) {

    Sk <- summary_obj$cov_mean[[k]]

    if (
      is.null(Sk) ||
        any(!is.finite(Sk))
    ) {

      stop(
        paste(
          "Invalid covariance at time",
          summary_obj$times[k]
        )
      )
    }

    for (a in seq_len(P)) {

      for (bb in seq_len(P)) {

        ia <- idx(
          a,
          k
        )

        ib <- idx(
          bb,
          k
        )

        Sigma_m[
          ia,
          ib
        ] <- Sk[
          a,
          bb
        ]
      }
    }
  }

  Sigma_m
}


#' First-difference operator for species-major stacked means
#'
#' `kronecker(diag(4), D1)` with `D1` the `(K-1) x K` first-difference matrix.
#' No edits.
#'
#' Frozen source: `commons/nested_test2.r:536-573`.
#' @keywords internal
#' @noRd
build_difference_matrix <- function(
  K
) {

  if (K < 2L) {
    stop("K must be at least 2.")
  }

  D1 <- matrix(
    0,
    nrow = K - 1L,
    ncol = K
  )

  for (
    k in seq_len(
      K - 1L
    )
  ) {

    D1[
      k,
      k
    ] <- -1

    D1[
      k,
      k + 1L
    ] <- 1
  }

  kronecker(
    diag(
      length(KINETIC_VARS)
    ),
    D1
  )
}
