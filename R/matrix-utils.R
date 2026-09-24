# =============================================================================
# Internal matrix utilities
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Stabilise a covariance matrix to symmetric positive definite
#'
#' Symmetrises `S` and raises eigenvalues to a relative, scale-equivariant
#' floor `max(median(positive diag(S)) * rel_floor, .Machine$double.xmin)`.
#' Returns `NULL` on invalid input. Mechanical edit: `median()` ->
#' `stats::median()`.
#'
#' Frozen source: `commons/nested_test2.r:51-145`.
#' @keywords internal
#' @noRd
make_spd <- function(
  S,
  rel_floor = 1e-8
) {

  S <- as.matrix(S)

  if (
    nrow(S) != ncol(S) ||
    nrow(S) == 0L
  ) {
    return(NULL)
  }

  # numerical symmetry
  S <- (S + t(S)) / 2

  if (any(!is.finite(S))) {
    return(NULL)
  }

  # Scale reference from the diagonal.
  d <- diag(S)

  positive_d <- d[
    is.finite(d) &
      d > 0
  ]

  if (length(positive_d) > 0L) {

    scale_ref <- stats::median(positive_d)

  } else {

    positive_entries <- abs(
      S[
        is.finite(S) &
          S != 0
      ]
    )

    if (length(positive_entries) == 0L) {
      return(NULL)
    }

    scale_ref <- stats::median(positive_entries)
  }

  if (
    !is.finite(scale_ref) ||
      scale_ref <= 0
  ) {
    return(NULL)
  }

  ee <- tryCatch(
    eigen(
      S,
      symmetric = TRUE
    ),
    error = function(e) NULL
  )

  if (is.null(ee)) {
    return(NULL)
  }

  # Relative, scale-equivariant floor.
  eig_floor <- max(
    scale_ref * rel_floor,
    .Machine$double.xmin
  )

  eig_values <- pmax(
    ee$values,
    eig_floor
  )

  S_spd <- ee$vectors %*%
    diag(
      eig_values,
      nrow = length(eig_values)
    ) %*%
    t(ee$vectors)

  S_spd <- (
    S_spd +
      t(S_spd)
  ) / 2

  dimnames(S_spd) <- dimnames(S)

  S_spd
}


#' Symmetric inverse square root of a covariance matrix
#'
#' Computes `Sigma^{-1/2}` by eigendecomposition after `make_spd()`. Returns
#' `NULL` on failure. No edits.
#'
#' Frozen source: `commons/nested_test2.r:148-192`.
#' @keywords internal
#' @noRd
inverse_sqrt_matrix <- function(
  Sigma,
  rel_floor = 1e-8
) {

  Sigma <- make_spd(
    Sigma,
    rel_floor = rel_floor
  )

  if (is.null(Sigma)) {
    return(NULL)
  }

  ee <- tryCatch(
    eigen(
      Sigma,
      symmetric = TRUE
    ),
    error = function(e) NULL
  )

  if (is.null(ee)) {
    return(NULL)
  }

  if (
    any(!is.finite(ee$values)) ||
      any(ee$values <= 0)
  ) {
    return(NULL)
  }

  W12 <- ee$vectors %*%
    diag(
      1 / sqrt(ee$values),
      nrow = length(ee$values)
    ) %*%
    t(ee$vectors)

  (
    W12 +
      t(W12)
  ) / 2
}
