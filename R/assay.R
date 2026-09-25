# =============================================================================
# Internal assay (measurement-noise) models and benchmark presets
#
# Ported verbatim from postexport-kinetics@manuscript-revision-v1.0
# (65c3b7368fb7686bfde3dab857f98c393bb534c5),
# commons/platforms.r and
# synthetic_dataset/run_benchmark_main_corrected_onset_revision.R. Function
# bodies are unchanged except for the mechanical
# edits listed next to each function. Equivalence with the frozen source is
# asserted by tests/testthat/test-verbatim-port.R.
# =============================================================================


#' Gaussian noise with standard deviation proportional to the signal
#'
#' x + N(0, (max(0, x) * noise_sd)^2), no truncation. No edits.
#'
#' Frozen source: `commons/platforms.r:45-54`.
#' @keywords internal
#' @noRd
add_gaussian_noise <- function(df, cols, noise_sd) {
  for (col in cols) {
    df[[col]] <- df[[col]] + stats::rnorm(
      nrow(df),
      mean = 0,
      sd   = pmax(0, df[[col]]) * noise_sd
    )
  }
  return(df)
}


#' Gamma-distributed dispersion
#'
#' Mechanical edit: rgamma() -> stats::rgamma().
#'
#' Frozen source: `commons/platforms.r:67-71`.
#' @keywords internal
#' @noRd
sample_dispersion_gamma <- function(n_genes, mean_disp, cv_disp) {
  shape <- 1 / (cv_disp^2)
  scale <- mean_disp * cv_disp^2
  stats::rgamma(n_genes, shape = shape, scale = scale)
}


#' RNA-seq-like negative-binomial counts
#'
#' One dispersion per target and call; counts rescaled by scale_counts.
#' Mechanical edits: copy(as.data.table(dt)) -> as.data.frame(dt) and dt[] ->
#' dt (data.table not required; numerically identical, asserted by fixtures).
#'
#' Frozen source: `commons/platforms.r:89-125`.
#' @keywords internal
#' @noRd
simulate_rnaseq <- function(
  dt,
  targets       = c("N","N_s","C","C_s"),
  scale_counts  = 200,
  mean_disp=0.1, cv_disp=0.5
){
  dt <- as.data.frame(dt)
  stopifnot(all(targets %in% names(dt)))
  
  for (tg in targets) {
    # Enforce non-negative latent abundances.
    latent <- pmax(dt[[tg]], 0)
    latent[is.na(latent)] <- 0
    
    # Expected count scale for the target.
    mu_counts <- latent * scale_counts
    
    # Sample one dispersion value for the current target.
    disp = sample_dispersion_gamma(1, mean_disp, cv_disp)
    
    # Convert dispersion to theta parameterization used by rnegbin().
    # Large theta corresponds to weaker overdispersion.
    theta <- if (disp > 0) 1/disp else 1e6
    
    # Draw counts; zero expected mean gives zero observed counts.
    counts <- ifelse(
        mu_counts > 0,
        MASS::rnegbin(length(mu_counts), mu = mu_counts, theta = theta),
        0L
    )
    
    # Rescale counts back to a continuous scale comparable to the latent input.
    dt[[tg]] <- counts / scale_counts
  }
  
  dt
}


#' RT-qPCR-like Poisson copies, Ct noise and detection limit
#'
#' Output 2^-Ct (not rescaled by scale_copies). Mechanical edits:
#' copy(as.data.table(dt)) -> as.data.frame(dt), dt[] -> dt, rpois()/rnorm()
#' -> stats::rpois()/stats::rnorm().
#'
#' Frozen source: `commons/platforms.r:145-182`.
#' @keywords internal
#' @noRd
simulate_rt_qpcr <- function(dt,
  targets      = c("N", "C", "C_s", "N_s"),
  scale_copies = 10,
  ct_intercept = 35,
  ct_sd        = 0.25,
  lod_ct       = 40
){
  dt <- as.data.frame(dt)
  stopifnot(all(targets %in% names(dt)))
  
  for (tg in targets) {
    
    # Convert latent abundance into expected copy number.
    lambda <- pmax(dt[[tg]], 0) * scale_copies
    lambda[is.na(lambda)] <- 0
    
    # Poisson sampling noise on molecular copies.
    copies <- stats::rpois(nrow(dt), lambda)
    
    # Enforce at least one copy to avoid log2(0) in Ct conversion.
    copies[copies < 1] <- 1L
    
    # Ideal Ct transformation plus Gaussian technical noise.
    Ct <- ct_intercept - log2(copies)
    Ct <- Ct + stats::rnorm(nrow(dt), 0, ct_sd)
    
    # Apply a simple limit of detection.
    # Values above the threshold are censored just beyond the LOD.
    Ct[Ct > lod_ct] <- lod_ct + 0.5
    # Alternative option:
    # Ct[Ct > lod_ct] <- NA_real_
    
    # Map Ct back to a positive signal-like quantity.
    dt[[tg]] <- 2^(-Ct)
  }
  
  dt
}

#' Gaussian noise presets of the corrected factorial benchmark
#'
#' Relative noise standard deviations by noise level. No edits.
#'
#' Frozen source:
#' `synthetic_dataset/run_benchmark_main_corrected_onset_revision.R:469-474`.
#' @keywords internal
#' @noRd
RANGE_GAUSS_NOISE <- c(
  "Very low" = 0.02,
  "Low"      = 0.05,
  "Medium"   = 0.10,
  "High"     = 0.20
)


#' Benchmark platform/noise-level presets
#'
#' Targets in RNG order N, C, C_s, N_s. Mechanical edit:
#' copy(as.data.table(dt)) -> as.data.frame(dt).
#'
#' Frozen source:
#' `synthetic_dataset/run_benchmark_main_corrected_onset_revision.R:538-645`.
#' @keywords internal
#' @noRd
add_platform_noise_main <- function(
  dt,
  platform,
  noise
) {

  dt <- as.data.frame(dt)

  targets <- c(
    "N",
    "C",
    "C_s",
    "N_s"
  )


  if (platform == "GAUSS") {

    noise_sd <- unname(
      RANGE_GAUSS_NOISE[noise]
    )

    return(
      add_gaussian_noise(
        dt,
        cols = targets,
        noise_sd = noise_sd
      )
    )
  }


  if (platform == "RT-qPCR") {

    ct_sd <- switch(
      noise,
      "Very low" = 0.01,
      "Low"      = 0.05,
      "Medium"   = 0.10,
      "High"     = 0.25
    )

    scale_copies <- switch(
      noise,
      "Very low" = 20,
      "Low"      = 15,
      "Medium"   = 10,
      "High"     = 5
    )

    return(
      simulate_rt_qpcr(
        dt,
        targets = targets,
        ct_sd = ct_sd,
        scale_copies = scale_copies
      )
    )
  }


  if (platform == "RNA-seq") {

    scale_counts <- switch(
      noise,
      "Very low" = 10000,
      "Low"      = 5000,
      "Medium"   = 1000,
      "High"     = 200
    )

    mean_disp <- switch(
      noise,
      "Very low" = 0.01,
      "Low"      = 0.05,
      "Medium"   = 0.10,
      "High"     = 0.25
    ) * 0.25

    cv_disp <- switch(
      noise,
      "Very low" = 0.5,
      "Low"      = 0.7,
      "Medium"   = 0.8,
      "High"     = 1.0
    )

    return(
      simulate_rnaseq(
        dt,
        targets = targets,
        scale_counts = scale_counts,
        mean_disp = mean_disp,
        cv_disp = cv_disp
      )
    )
  }


  stop(
    paste(
      "Unknown platform:",
      platform
    )
  )
}
