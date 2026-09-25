# =============================================================================
# Internal bootstrap primitives
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Generate one destructive-sampling bootstrap dataset under the null
#'
#' Independent `MASS::mvrnorm()` draws of `n_k` samples per time point around
#' the null means with the shrunk per-time covariance; replicate labels are
#' local to each time point. No edits.
#'
#' Frozen source: `commons/nested_test2.r:1317-1440`.
#' @keywords internal
#' @noRd
simulate_destructive_null <- function(
  null_means,
  summary_obj,
  truncate_nonnegative = FALSE
) {

  times <-
    summary_obj$times

  if (
    nrow(null_means) !=
      length(times) ||
      ncol(null_means) !=
      length(KINETIC_VARS)
  ) {

    stop(
      "null_means dimensions are inconsistent."
    )
  }

  out <- vector(
    "list",
    length(times)
  )

  for (
    k in seq_along(times)
  ) {

    nk <-
      summary_obj$n_rep[k]

    Sigma_k <-
      summary_obj$cov_obs[[k]]

    if (
      nk < 1L ||
        is.null(Sigma_k) ||
        any(!is.finite(Sigma_k))
    ) {

      stop(
        paste(
          "Invalid bootstrap parameters at time",
          times[k]
        )
      )
    }

    # Biological samples from DIFFERENT time points
    # are generated independently.

    Y <- MASS::mvrnorm(
      n = nk,
      mu = null_means[k, ],
      Sigma = Sigma_k
    )

    if (nk == 1L) {

      Y <- matrix(
        Y,
        nrow = 1L
      )
    }

    colnames(Y) <-
      KINETIC_VARS

    if (truncate_nonnegative) {

      Y[
        Y < 0
      ] <- 0
    }

    if (any(!is.finite(Y))) {

      stop(
        "Non-finite bootstrap observations."
      )
    }

    out[[k]] <- data.frame(
      time =
        rep(
          times[k],
          nk
        ),

      # Local label only.
      #
      # There is NO relation between t1_r1 and t2_r1.
      replicate =
        paste0(
          "t",
          k,
          "_r",
          seq_len(nk)
        ),

      N =
        Y[, "N"],

      N_s =
        Y[, "N_s"],

      C =
        Y[, "C"],

      C_s =
        Y[, "C_s"],

      stringsAsFactors =
        FALSE
    )
  }

  do.call(
    rbind,
    out
  )
}
