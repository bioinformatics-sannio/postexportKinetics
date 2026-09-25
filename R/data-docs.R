#' Small synthetic example dataset
#'
#' Simulated compartment-resolved time courses for eight events, in the
#' canonical wide format accepted by [postexport_data()]. The data are
#' synthetic: they were generated with [simulate_postexport_kinetics()] (the
#' ported manuscript simulator and assay-noise model). They contain no real
#' measurements and are intended for examples, the vignette and smoke tests.
#'
#' @section Design:
#' One design of the manuscript's corrected factorial benchmark: complete
#' transcriptional shutoff (`"SHUTOFF"`) at the common intervention time
#' `t_star = 332` min; sampling at `t_star - 10`, `t_star`, `t_star + 10`,
#' `+ 20` and `+ 30` min (5 time points); 5 destructive replicates per time
#' point; replicate-level rate variability `param_cv = 0.05`; RNA-seq assay
#' noise at level `"very_low"`; integration grid `origin = 0`,
#' `grid_step = 1`, `horizon = 1000`, `y0 = 0`. The design was selected from
#' the benchmark table before any data were generated. Among the
#' benchmark's SHUTOFF designs with at most 10 time points and 5 replicates
#' whose Type-I error interval contains 0.05, it had the highest power at
#' `alpha = 0.05`: about 0.24, with Type-I error 0.042. Most simulated
#' alternative events are therefore not expected to reach significance. The
#' example shows realistic uncertainty and does not guarantee detection.
#'
#' @section Events and parameters:
#' Events `alt_1` to `alt_4` were simulated with `sigma_c > 0` and events
#' `null_1` to `null_4` with `sigma_c = 0`. For each event, the kinetic
#' parameters were drawn once from the manuscript benchmark ranges, and a
#' transcriptional onset was drawn as a uniform integer in `[-100, 100]` min.
#' The script's seed, 20260925, was fixed a priori. Neither the design nor
#' the data were chosen by searching over seeds.
#' The true values are in [postexport_example_truth]. The draws reproduce the
#' benchmark's parameter distributions, not its per-gene random streams.
#' Generation code (distributed with the package):
#' `system.file("scripts", "generate_postexport_example.R",
#' package = "postexportKinetics")`.
#'
#' The same observations in long format are installed as
#' `system.file("extdata", "postexport_example_long.csv",
#' package = "postexportKinetics")`.
#'
#' @format A data frame with 200 rows (8 events x 5 time points x 5
#'   replicates) and 7 columns:
#' \describe{
#'   \item{event}{event identifier (character).}
#'   \item{time}{sampling time in minutes.}
#'   \item{replicate}{replicate label within a time point (integer).
#'     Replicates are independent destructive samples and are not paired
#'     across time points.}
#'   \item{N, N_s, C, C_s}{simulated abundances of nuclear unprocessed,
#'     nuclear processed, cytoplasmic unprocessed and cytoplasmic processed
#'     RNA (RNA-seq noise model, arbitrary scale).}
#' }
#'
#' @source Simulated with [simulate_postexport_kinetics()]; see
#'   `inst/scripts/generate_postexport_example.R`.
#'
#' @seealso [postexport_example_truth], [postexport_data()]
#'
#' @examples
#' data(postexport_example)
#' head(postexport_example)
#' x <- postexport_data(postexport_example, time_unit = "min")
#' x
"postexport_example"


#' Simulation truth for the example dataset
#'
#' The parameters used to simulate each event of [postexport_example].
#'
#' @format A data frame with 8 rows and 13 columns:
#' \describe{
#'   \item{event}{event identifier, matching [postexport_example].}
#'   \item{truth}{`"alternative"` (`sigma_c > 0`) or `"null"`
#'     (`sigma_c = 0`).}
#'   \item{R, tau, tau_s, sigma_c, sigma_n, alpha, alpha_s}{kinetic
#'     parameters, with rates per minute. Replicates vary these rates by
#'     `param_cv = 0.05`, except `R`.}
#'   \item{onset_time}{transcriptional onset (min).}
#'   \item{t_star}{common intervention time (min).}
#'   \item{simulation_seed}{seed passed to [simulate_postexport_kinetics()].}
#' }
#'
#' @source Simulated with [simulate_postexport_kinetics()]; see
#'   `inst/scripts/generate_postexport_example.R`.
#'
#' @seealso [postexport_example]
#'
#' @examples
#' data(postexport_example_truth)
#' postexport_example_truth[, c("event", "truth", "sigma_c")]
"postexport_example_truth"
