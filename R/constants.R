# =============================================================================
# Package constants
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5), commons/nested_test2.r:29-44.
# The ordering of both vectors is part of the scientific definition of the
# model: states are N, N_s, C, C_s and parameter column 4 is sigma_c.
# =============================================================================


#' Kinetic state names
#'
#' Order: nuclear unprocessed (`N`), nuclear processed (`N_s`), cytoplasmic
#' unprocessed (`C`), cytoplasmic processed (`C_s`).
#'
#' Frozen source: `commons/nested_test2.r:29-34`.
#' @keywords internal
#' @noRd
KINETIC_VARS <- c(
  "N",
  "N_s",
  "C",
  "C_s"
)


#' Kinetic parameter names, in design-matrix column order
#'
#' `sigma_c` (column 4) is the phenomenological post-export conversion rate
#' tested against the `sigma_c = 0` null.
#'
#' Frozen source: `commons/nested_test2.r:36-44`.
#' @keywords internal
#' @noRd
PARAM_NAMES <- c(
  "R",
  "tau",
  "tau_s",
  "sigma_c",
  "sigma_n",
  "alpha",
  "alpha_s"
)
