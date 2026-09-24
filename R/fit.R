# =============================================================================
# Internal constrained NNLS fitting
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/nested_test2.r. Function bodies are unchanged except for the
# mechanical edits listed next to each function. Equivalence with the frozen
# source is asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Whitened NNLS fits of the full and sigma_c = 0 null models
#'
#' GLS whitening by `Sigma_b^{-1/2}`, NNLS fits with and without column
#' `col_test` (`sigma_c`), statistic `T = max(0, RSS0 - RSS1)` on the whitened
#' scale, and identifiability diagnostics (condition number, minimum singular
#' value, ranks). Returns `NULL` on failure. No edits.
#'
#' Frozen source: `commons/nested_test2.r:896-1079`.
#' @keywords internal
#' @noRd
fit_nnls_nested_once <- function(
  A,
  b,
  Sigma_b,
  col_test = 4L,
  rel_floor = 1e-8
) {

  A <-
    as.matrix(A)

  b <-
    as.numeric(b)

  Sigma_b <-
    as.matrix(Sigma_b)

  if (
    nrow(A) != length(b) ||
      nrow(Sigma_b) != length(b) ||
      ncol(Sigma_b) != length(b)
  ) {

    return(NULL)
  }

  if (
    any(!is.finite(A)) ||
      any(!is.finite(b)) ||
      any(!is.finite(Sigma_b))
  ) {

    return(NULL)
  }

  W12 <- inverse_sqrt_matrix(
    Sigma_b,
    rel_floor = rel_floor
  )

  if (is.null(W12)) {
    return(NULL)
  }

  A_w <-
    W12 %*%
    A

  b_w <-
    as.vector(
      W12 %*%
        b
    )

  A0 <- A_w[
    ,
    -col_test,
    drop = FALSE
  ]

  fit0 <- tryCatch(
    nnls::nnls(
      A0,
      b_w
    ),
    error = function(e) NULL
  )

  fit1 <- tryCatch(
    nnls::nnls(
      A_w,
      b_w
    ),
    error = function(e) NULL
  )

  if (
    is.null(fit0) ||
      is.null(fit1)
  ) {

    return(NULL)
  }

  pred0 <-
    as.vector(
      A0 %*%
        fit0$x
    )

  pred1 <-
    as.vector(
      A_w %*%
        fit1$x
    )

  rss0 <-
    sum(
      (b_w - pred0)^2
    )

  rss1 <-
    sum(
      (b_w - pred1)^2
    )

  if (
    !is.finite(rss0) ||
      !is.finite(rss1)
  ) {

    return(NULL)
  }

  Tstat <- max(
    0,
    rss0 - rss1
  )

  # ---------------------------------------------------------------------------
  # Identifiability diagnostics.
  # ---------------------------------------------------------------------------

  singular_values <- tryCatch(
    svd(A_w)$d,
    error = function(e) numeric()
  )

  if (
    length(singular_values) > 0L &&
      all(is.finite(singular_values))
  ) {

    max_sv <-
      max(singular_values)

    min_sv <-
      min(singular_values)

    condition_number <- if (
      min_sv > 0
    ) {

      max_sv / min_sv

    } else {

      Inf
    }

  } else {

    min_sv <-
      NA_real_

    condition_number <-
      Inf
  }

  list(
    T = Tstat,

    RSS0 = rss0,
    RSS1 = rss1,

    coef_null_scaled =
      fit0$x,

    coef_full_scaled =
      fit1$x,

    condition_number =
      condition_number,

    min_singular_value =
      min_sv,

    rank_full =
      qr(A_w)$rank,

    rank_null =
      qr(A0)$rank
  )
}
