# =============================================================================
# Internal Crank-Nicolson null propagation
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Continuous-time kinetic matrix
#'
#' Four-state kinetic matrix in `KINETIC_VARS` order for a named parameter
#' vector. No edits.
#'
#' Frozen source: `commons/nested_test2.r:1093-1126`.
#' @keywords internal
#' @noRd
kinetic_matrix <- function(
  theta
) {

  matrix(
    c(
      -(theta["sigma_n"] + theta["tau"]),
      0,
      0,
      0,

      theta["sigma_n"],
      -theta["tau_s"],
      0,
      0,

      theta["tau"],
      0,
      -(theta["sigma_c"] + theta["alpha"]),
      0,

      0,
      theta["tau_s"],
      theta["sigma_c"],
      -theta["alpha_s"]
    ),
    nrow = 4,
    byrow = TRUE,
    dimnames = list(
      KINETIC_VARS,
      KINETIC_VARS
    )
  )
}


#' One Crank-Nicolson interval
#'
#' Solves `(I - dt/2 K) x1 = (I + dt/2 K) x0 + input` with transcription input
#' `R * R_active_dt` on `N`. No edits.
#'
#' Frozen source: `commons/nested_test2.r:1147-1213`.
#' @keywords internal
#' @noRd
cn_interval <- function(
  x0,
  dt,
  theta,
  R_active_dt
) {

  if (
    !is.finite(dt) ||
      dt <= 0
  ) {

    stop(
      "Invalid interval length."
    )
  }

  Kmat <-
    kinetic_matrix(theta)

  I4 <-
    diag(4)

  lhs <-
    I4 -
    (dt / 2) *
      Kmat

  rhs <-
    (
      I4 +
      (dt / 2) *
        Kmat
    ) %*%
    x0

  rhs <-
    as.numeric(rhs)

  rhs[1] <-
    rhs[1] +
    theta["R"] *
      R_active_dt

  x1 <- tryCatch(
    solve(
      lhs,
      rhs
    ),
    error = function(e) NULL
  )

  if (
    is.null(x1) ||
      any(!is.finite(x1))
  ) {

    stop(
      "Crank-Nicolson propagation failed."
    )
  }

  names(x1) <-
    KINETIC_VARS

  x1
}


#' Crank-Nicolson mean trajectory under the null
#'
#' Propagates `x0` across the observed times with `sigma_c` forced to 0 and
#' transcription truncated at `t_star`. No edits.
#'
#' Frozen source: `commons/nested_test2.r:1216-1310`.
#' @keywords internal
#' @noRd
predict_null_cn <- function(
  times,
  x0,
  theta0,
  t_star = NULL
) {

  times <-
    sort(
      unique(times)
    )

  theta0 <-
    as.numeric(theta0)

  names(theta0) <-
    PARAM_NAMES

  theta0["sigma_c"] <- 0

  if (
    any(!is.finite(theta0)) ||
      any(theta0 < 0)
  ) {

    stop(
      "Invalid null parameter estimates."
    )
  }

  x0 <-
    as.numeric(x0)

  names(x0) <-
    KINETIC_VARS

  X <- matrix(
    NA_real_,
    nrow = length(times),
    ncol = 4,
    dimnames = list(
      as.character(times),
      KINETIC_VARS
    )
  )

  X[1, ] <-
    x0

  if (length(times) == 1L) {
    return(X)
  }

  for (
    k in seq_len(
      length(times) - 1L
    )
  ) {

    t0 <-
      times[k]

    t1 <-
      times[k + 1L]

    dt <-
      t1 - t0

    R_active_dt <-
      dt

    if (!is.null(t_star)) {

      R_active_dt <- max(
        0,
        min(
          dt,
          t_star - t0
        )
      )
    }

    X[
      k + 1L,
    ] <- cn_interval(
      x0 = X[k, ],
      dt = dt,
      theta = theta0,
      R_active_dt =
        R_active_dt
    )
  }

  X
}
