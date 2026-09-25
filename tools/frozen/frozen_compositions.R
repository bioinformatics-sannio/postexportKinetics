# =============================================================================
# Frozen-code compositions shared by the fixture generator
# (tools/frozen/make_fixtures_phase3.R) and the cross-platform recompute tool
# (tools/frozen/recompute_fixtures.R).
#
# frozen_simulation(env, a) composes ONLY frozen functions found in `env`
# (sourced from ode_model/ode.r, commons/platforms.r and the benchmark
# runner's add_platform_noise_main) in the order that defines the package's
# simulate_postexport_kinetics():
#
#   1. set.seed(a$seed) if a$seed is not NULL (else: current global stream);
#   2. generate_ODE_states() with the explicit onset (no hidden onset draw:
#      use_onset_shift = FALSE, max_shift = 0), stimes = shutofftimes = the
#      sampling times, and base parameters in the frozen benchmark list order
#      tau, tau_s, alpha, alpha_s, sigma_n, sigma_c, R (the order of the
#      replicate-level random draws);
#   3. NONE uses the baseline trajectory; SHUTOFF / PSEUDO_SHUTOFF use the
#      intervention trajectory;
#   4. optional assay noise with add_platform_noise_main() on the sampled
#      states, continuing the same random-number stream.
# =============================================================================

FROZEN_PARAM_LIST_ORDER <- c("tau", "tau_s", "alpha", "alpha_s", "sigma_n",
                             "sigma_c", "R")

frozen_simulation <- function(env, a) {
    if (!is.null(a$seed)) set.seed(a$seed)
    base <- as.list(a$params[FROZEN_PARAM_LIST_ORDER])
    post <- switch(a$regime, NONE = 1, SHUTOFF = 0,
                   PSEUDO_SHUTOFF = a$residual_fraction)
    g <- env$generate_ODE_states(
        base_params = base,
        y0 = a$y0,
        times = a$grid,
        n_replicates = a$n_replicates,
        model_kinetics = env$rna_kinetics,
        param_cv = a$param_cv,
        stimes = a$times,
        shutofftimes = a$times,
        max_shift = 0,
        t_star = if (a$regime == "NONE") NULL else a$t_star,
        post_R_fraction = post,
        use_onset_shift = FALSE,
        nominal_onset_time = a$onset_time
    )
    if (a$regime == "NONE") {
        latent <- g$data
        sampled <- g$tsampled_data
    } else {
        latent <- g$intervention_data
        sampled <- g$intervention_tsampled_data
    }
    observed <- NULL
    if (!is.null(a$noise_platform)) {
        observed <- as.data.frame(env$add_platform_noise_main(
            sampled, a$noise_platform, a$noise_level))
    }
    list(latent = latent, sampled = sampled, observed = observed,
         parameters = g$parameters, ss_data = g$ss_data,
         onset_time = g$onset_time, t_star = g$t_star,
         post_R_fraction = g$post_R_fraction)
}
