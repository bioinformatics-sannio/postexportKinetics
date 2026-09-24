# =============================================================================
# Internal interval-balance (trapezoidal) system
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Construct the interval-balance system A, b and Sigma_b
#'
#' Trapezoidal interval balances for the four-state model, transcription input
#' truncated at `t_star` (`R_dt = pmax(0, pmin(dt, t_star - t0))`), covariance
#' propagation `Sigma_b = D Sigma_m t(D)` stabilised by `make_spd()`, optional
#' unit-norm column scaling. No edits.
#'
#' Frozen source: `commons/nested_test2.r:580-889`.
#' @keywords internal
#' @noRd
build_Ab_fullcov <- function(
  tsampled_data,
  scaling_A = TRUE,
  t_star = NULL,
  lambda_time = 0.5,
  lambda_diag = 0.1,
  rel_floor = 1e-8
) {

  S <- time_summary_cov_shrink(
    df = tsampled_data,
    lambda_time = lambda_time,
    lambda_diag = lambda_diag,
    rel_floor = rel_floor
  )

  times <- S$times

  K <- length(times)

  X <- S$means

  deltaT <- diff(times)

  if (
    any(!is.finite(deltaT)) ||
      any(deltaT <= 0)
  ) {

    stop(
      "Times must be strictly increasing."
    )
  }

  # ---------------------------------------------------------------------------
  # Observed interval changes.
  # ---------------------------------------------------------------------------

  deltaN <-
    diff(
      X[, "N"]
    )

  deltaNs <-
    diff(
      X[, "N_s"]
    )

  deltaC <-
    diff(
      X[, "C"]
    )

  deltaCs <-
    diff(
      X[, "C_s"]
    )

  # ---------------------------------------------------------------------------
  # Trapezoidal means.
  # ---------------------------------------------------------------------------

  meanN <-
    (
      X[-1, "N"] +
        X[-K, "N"]
    ) / 2

  meanNs <-
    (
      X[-1, "N_s"] +
        X[-K, "N_s"]
    ) / 2

  meanC <-
    (
      X[-1, "C"] +
        X[-K, "C"]
    ) / 2

  meanCs <-
    (
      X[-1, "C_s"] +
        X[-K, "C_s"]
    ) / 2

  IN <-
    deltaT *
    meanN

  INs <-
    deltaT *
    meanNs

  IC <-
    deltaT *
    meanC

  ICs <-
    deltaT *
    meanCs

  # ---------------------------------------------------------------------------
  # Active transcription duration.
  #
  # Only the R term is truncated by shutoff.
  # All other kinetic processes continue for the full interval.
  # ---------------------------------------------------------------------------

  R_dt <- deltaT

  if (!is.null(t_star)) {

    if (
      length(t_star) != 1L ||
        !is.finite(t_star)
    ) {

      stop(
        "t_star must be NULL or a single finite number."
      )
    }

    t0 <- times[-K]

    R_dt <- pmax(
      0,
      pmin(
        deltaT,
        t_star - t0
      )
    )
  }

  zeros <- rep(
    0,
    K - 1L
  )

  # ---------------------------------------------------------------------------
  # A matrix.
  #
  # Row ordering:
  #
  # N intervals
  # Ns intervals
  # C intervals
  # Cs intervals
  # ---------------------------------------------------------------------------

  A_N <- cbind(
    R_dt,
    -IN,
    zeros,
    zeros,
    -IN,
    zeros,
    zeros
  )

  A_Ns <- cbind(
    zeros,
    zeros,
    -INs,
    zeros,
    IN,
    zeros,
    zeros
  )

  A_C <- cbind(
    zeros,
    IN,
    zeros,
    -IC,
    zeros,
    -IC,
    zeros
  )

  A_Cs <- cbind(
    zeros,
    zeros,
    INs,
    IC,
    zeros,
    zeros,
    -ICs
  )

  A <- rbind(
    A_N,
    A_Ns,
    A_C,
    A_Cs
  )

  colnames(A) <-
    PARAM_NAMES

  b <- c(
    deltaN,
    deltaNs,
    deltaC,
    deltaCs
  )

  # ---------------------------------------------------------------------------
  # Covariance propagation.
  # ---------------------------------------------------------------------------

  Sigma_m <-
    build_sigma_means(S)

  D <-
    build_difference_matrix(K)

  if (
    ncol(D) !=
      nrow(Sigma_m)
  ) {

    stop(
      "Dimension mismatch between D and Sigma_m."
    )
  }

  Sigma_b <-
    D %*%
    Sigma_m %*%
    t(D)

  if (
    nrow(Sigma_b) !=
      length(b)
  ) {

    stop(
      "Dimension mismatch between Sigma_b and b."
    )
  }

  Sigma_b <- make_spd(
    Sigma_b,
    rel_floor = rel_floor
  )

  if (is.null(Sigma_b)) {

    stop(
      "Unable to stabilize Sigma_b."
    )
  }

  # ---------------------------------------------------------------------------
  # Optional column scaling.
  # ---------------------------------------------------------------------------

  col_norms <- rep(
    1,
    ncol(A)
  )

  if (scaling_A) {

    col_norms <-
      sqrt(
        colSums(
          A^2
        )
      )

    invalid <- (
      !is.finite(col_norms) |
        col_norms <= 0
    )

    col_norms[
      invalid
    ] <- 1

    A <- sweep(
      A,
      2,
      col_norms,
      "/"
    )
  }

  if (
    nrow(A) != length(b) ||
      nrow(Sigma_b) != length(b) ||
      ncol(Sigma_b) != length(b)
  ) {

    stop(
      "Internal A/b/Sigma_b dimension mismatch."
    )
  }

  list(
    A = A,
    b = b,
    Sigma_b = Sigma_b,
    Sigma_m = Sigma_m,
    D = D,
    col_norms = col_norms,
    summary = S
  )
}
