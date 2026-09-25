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
#' @section Main functions:
#' \itemize{
#'   \item [postexport_data()] and [validate_postexport_data()]: validated
#'     input data;
#'   \item [postexport_control()]: numerical and inferential settings
#'     (frozen defaults);
#'   \item [fit_postexport_model()]: full and `sigma_c = 0` null fits
#'     without bootstrap;
#'   \item [test_postexport_conversion()]: bootstrap test of the null
#'     `sigma_c = 0` against `sigma_c > 0`;
#'   \item [simulate_postexport_kinetics()]: simulation with the frozen
#'     manuscript simulator (onset, common intervention time, replicates,
#'     assay noise);
#'   \item [check_operational_domain()]: diagnostic comparison of a design
#'     with the manuscript benchmark (not a calibration guarantee).
#' }
#'
#' @section Development status:
#' Development version. Exploratory ranking, plotting and batch execution are
#' not yet available.
#'
#' @keywords internal
"_PACKAGE"
