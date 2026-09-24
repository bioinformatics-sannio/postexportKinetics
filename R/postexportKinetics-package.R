#' postexportKinetics: kinetic model comparison for post-export RNA conversion
#'
#' Compartment-resolved four-state RNA kinetics (`N`, `N_s`, `C`, `C_s`) and a
#' constrained nested-model comparison of a null model with `sigma_c = 0`
#' against a full model with `sigma_c >= 0`, calibrated by a replicate-level
#' generative bootstrap.
#'
#' @section Interpretation:
#' `sigma_c` is a phenomenological post-export conversion rate (from `C` to
#' `C_s`) within the kinetic model. A positive estimate or a small bootstrap
#' p-value indicates kinetic evidence consistent with an additional
#' post-export conversion component within the model. It does not identify a
#' unique molecular mechanism and is not, by itself, evidence of cytoplasmic
#' splicing. The test statistic is a difference of whitened non-negative
#' least-squares residual sums of squares; it is not a likelihood-ratio test.
#'
#' @section Provenance:
#' The numerical core is ported verbatim from the frozen manuscript
#' implementation (tag `manuscript-revision-v1.0`, commit
#' `65c3b7368fb7686bfde3dab857f98c393bb534c5`) and is regression-tested
#' against fixtures generated from that tag.
#'
#' @section Development status:
#' Phase 1: internal numerical core and regression infrastructure only. No
#' user-facing functions are exported yet.
#'
#' @keywords internal
"_PACKAGE"
