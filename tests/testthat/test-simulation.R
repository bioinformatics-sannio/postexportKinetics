# Simulation: regression against the frozen simulator (ode_model/ode.r,
# commons/platforms.r, benchmark noise presets) and public-API behaviour.
#   A. same-platform: strict (T1 for ODE outputs; exact for draws);
#   B. cross-platform: scale-aware deterministic policy;
#   C. noisy observations: platform-sensitive stochastic (reported only).

fx_ode <- read_fixture("fx_ode")
fx_gen <- read_fixture("fx_generate")
fx_noise <- read_fixture("fx_noise")
fx_sim <- read_fixture("fx_simulation")

# Ported assay functions return data frames; the frozen ones return
# data.tables, which carry no row names. Row names are therefore reset before
# comparison (values, column names and classes are compared).
reset_rownames <- function(x) {
    if (is.data.frame(x)) rownames(x) <- NULL
    if (is.list(x) && !is.data.frame(x)) x[] <- lapply(x, reset_rownames)
    x
}

test_that("ODE-layer functions match the frozen simulator", {
    for (key in names(fx_ode$cases)) {
        case <- fx_ode$cases[[key]]
        expect_regression(run_case(case), case$output, TOL_T1, key,
                          fx_ode$provenance, case)
    }
})

test_that("assay-noise functions match the frozen functions", {
    for (key in names(fx_noise$cases)) {
        case <- fx_noise$cases[[key]]
        set.seed(case$input$pre_seed)
        got <- capture(do.call(pkg_fun(case$input$fun), case$input$args))
        if (!is.null(got$value) && is.data.frame(got$value)) {
            got$value <- as.data.frame(got$value)
        }
        expect_regression(reset_rownames(got), reset_rownames(case$output),
                          TOL_T1, key, fx_noise$provenance, case)
    }
})

test_that("the internal composition matches the frozen composition", {
    for (key in names(fx_gen$cases)) {
        case <- fx_gen$cases[[key]]
        got <- capture(.simulate_composition(case$input$args))
        expect_regression(reset_rownames(got), reset_rownames(case$output),
                          TOL_T1, key, fx_gen$provenance, case)
    }
})

public_args <- function(a) {
    noise <- if (is.null(a$noise_platform)) NULL else list(
        platform = names(.NOISE_PLATFORMS)[.NOISE_PLATFORMS == a$noise_platform],
        level = names(.NOISE_LEVELS)[.NOISE_LEVELS == a$noise_level])
    list(params = a$params, times = a$times, onset_time = a$onset_time,
         t_star = if (a$regime == "NONE") NULL else a$t_star,
         regime = a$regime, time_unit = "min",
         residual_fraction = if (a$regime == "PSEUDO_SHUTOFF")
             a$residual_fraction else NULL,
         n_replicates = a$n_replicates, param_cv = a$param_cv, noise = noise,
         y0 = a$y0, origin = min(a$grid), grid_step = 1,
         horizon = max(a$grid), seed = a$seed)
}

strip_public <- function(sim) {
    drop_event <- function(x) {
        if (is.null(x)) return(NULL)
        x$event <- NULL
        x
    }
    list(latent = drop_event(sim$latent), sampled = drop_event(sim$sampled),
         observed = drop_event(sim$observed),
         parameters = sim$replicate_parameters, ss_data = sim$steady_state)
}

frozen_view <- function(out) {
    keep <- function(x, cols) {
        if (is.null(x)) return(NULL)
        x <- as.data.frame(x)[, cols]
        rownames(x) <- NULL
        x
    }
    state <- c("time", "replicate", KINETIC_VARS, "R")
    list(latent = keep(out$latent, state), sampled = keep(out$sampled, state),
         observed = keep(out$observed, c("time", "replicate", KINETIC_VARS)),
         parameters = out$parameters, ss_data = out$ss_data)
}

test_that("simulate_postexport_kinetics() reproduces the frozen simulator", {
    for (key in c(names(fx_sim$cases), names(fx_gen$cases))) {
        case <- if (key %in% names(fx_sim$cases)) fx_sim$cases[[key]] else
            fx_gen$cases[[key]]
        prov <- if (key %in% names(fx_sim$cases)) fx_sim$provenance else
            fx_gen$provenance
        sim <- do.call(simulate_postexport_kinetics,
                       public_args(case$input$args))
        expect_s3_class(sim, "postexport_simulation")
        expect_regression(list(value = strip_public(sim)),
                          list(value = frozen_view(case$output$value)),
                          TOL_T1, paste(key, "[public]"), prov, case)
    }
})

base_p <- c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,
            alpha = 0.2, alpha_s = 0.08)
shut_times <- c(95, 100, 110, 130, 160)

sim_det <- function(onset, regime = "SHUTOFF", t_star = 100, rho = NULL,
                    times = shut_times, ...) {
    simulate_postexport_kinetics(base_p, times = times, onset_time = onset,
                                 t_star = if (regime == "NONE") NULL else t_star,
                                 regime = regime, time_unit = "min",
                                 residual_fraction = rho, ...)
}

test_that("onset changes the history but never the intervention time", {
    sims <- lapply(c(-30, 0, 20, 60), sim_det)
    for (s in sims) {
        lat <- s$latent
        expect_true(all(lat$R[lat$time >= 100] == 0))
        expect_true(all(lat$R[lat$time < 100 &
                                  lat$time >= s$timing$onset_time] == 100))
        expect_true(all(lat$R[lat$time < s$timing$onset_time] == 0))
        # The transcription schedule changes at t_star = 100 for every onset.
        expect_identical(min(lat$time[lat$R == 0 & lat$time > 60]), 100)
        expect_identical(s$timing$t_star, 100)
    }
    # Pre-intervention history (and hence the states) differ between onsets.
    pre <- function(s) s$sampled[s$sampled$time == 95, KINETIC_VARS]
    expect_false(isTRUE(all.equal(pre(sims[[1]]), pre(sims[[3]]))))
    # Before t_star, SHUTOFF and NONE with the same onset coincide exactly.
    none <- sim_det(20, regime = "NONE", times = c(40, 95))
    shut <- sim_det(20, times = c(40, 95, 110))
    expect_identical(none$sampled[, KINETIC_VARS],
                     shut$sampled[shut$sampled$time < 100, KINETIC_VARS])
})

test_that("no hidden time shift or random draw is made", {
    set.seed(42)
    before <- .Random.seed
    sim <- sim_det(-30)
    expect_identical(.Random.seed, before)
    expect_identical(sim$timing$onset_time, -30)
    expect_true(is.null(sim$rng$seed))
})

test_that("residual transcription after t_star follows the frozen rule", {
    s <- sim_det(0, regime = "PSEUDO_SHUTOFF", rho = 0.25)
    expect_true(all(s$latent$R[s$latent$time >= 100] == 25))
    expect_identical(s$timing$post_R_fraction, 0.25)
})

test_that("parameter order is taken from names, never from position", {
    shuffled <- base_p[c("alpha_s", "R", "sigma_c", "tau", "alpha",
                         "sigma_n", "tau_s")]
    a <- sim_det(0, n_replicates = 3, param_cv = 0.05, seed = 3)
    b <- simulate_postexport_kinetics(
        shuffled, times = shut_times, onset_time = 0, t_star = 100,
        regime = "SHUTOFF", time_unit = "min", n_replicates = 3,
        param_cv = 0.05, seed = 3)
    expect_identical(a$latent, b$latent)
    expect_identical(names(b$params), PARAM_NAMES)
    expect_identical(b$params, base_p[PARAM_NAMES])
    expect_error(simulate_postexport_kinetics(
        unname(base_p), times = shut_times, onset_time = 0, t_star = 100,
        regime = "SHUTOFF", time_unit = "min"), "unnamed")
})

test_that("inputs are validated", {
    call_sim <- function(...) {
        args <- utils::modifyList(list(
            params = base_p, times = shut_times, onset_time = 0,
            t_star = 100, regime = "SHUTOFF", time_unit = "min"), list(...))
        do.call(simulate_postexport_kinetics, args)
    }
    expect_error(call_sim(params = base_p[-1]), "exactly the names")
    expect_error(call_sim(params = c(base_p, extra = 1)), "unknown: extra")
    p_neg <- base_p; p_neg["tau"] <- -0.1
    expect_error(call_sim(params = p_neg), "non-negative")
    p_na <- base_p; p_na["alpha"] <- NA
    expect_error(call_sim(params = p_na), "finite")
    expect_error(call_sim(times = c(95, 95, 100)), "distinct")
    expect_error(call_sim(times = c(-5, 10)), ">= 'origin'")
    expect_error(call_sim(regime = "NONE"), "t_star = NULL")
    expect_error(simulate_postexport_kinetics(
        base_p, times = shut_times, onset_time = 0, t_star = NULL,
        regime = "SHUTOFF", time_unit = "min"), "single finite 't_star'")
    expect_error(call_sim(horizon = 150), "'horizon'")
    expect_error(call_sim(regime = "PSEUDO_SHUTOFF"), "residual_fraction")
    expect_error(call_sim(regime = "PSEUDO_SHUTOFF", residual_fraction = 0),
                 "residual_fraction")
    expect_error(call_sim(residual_fraction = 0.5), "applies only")
    expect_error(call_sim(regime = "pseudo"), "'regime' must be one of")
    expect_error(call_sim(n_replicates = 0), "positive whole")
    expect_error(call_sim(param_cv = -1), "param_cv")
    expect_error(call_sim(noise = list(platform = "microarray", level = "low")),
                 "'noise' must be")
    expect_error(call_sim(y0 = c(1, 2, 3, 4)), "'y0'")
    expect_error(call_sim(seed = 1.5), "whole number")
    expect_error(simulate_postexport_kinetics(base_p, times = shut_times,
                                              onset_time = 0, regime = "SHUTOFF",
                                              time_unit = "min"),
                 "t_star")
    expect_error(simulate_postexport_kinetics(base_p, times = shut_times,
                                              t_star = 100, regime = "SHUTOFF",
                                              time_unit = "min"),
                 "onset_time")
    expect_warning(call_sim(onset_time = 150, times = c(95, 100, 160)),
                   "before onset_time")
    unsorted <- call_sim(times = c(160, 95, 130, 100, 110))
    expect_identical(unsorted$timing$sampling_times, shut_times)
    expect_identical(unsorted$sampled, call_sim()$sampled)
})

test_that("explicit seeds reproduce and leave the caller's state unchanged", {
    set.seed(10)
    before <- .Random.seed
    a <- sim_det(0, n_replicates = 3, param_cv = 0.05, seed = 7,
                 noise = list(platform = "rnaseq", level = "medium"))
    expect_identical(.Random.seed, before)
    b <- sim_det(0, n_replicates = 3, param_cv = 0.05, seed = 7,
                 noise = list(platform = "rnaseq", level = "medium"))
    expect_identical(a$observed, b$observed)
    expect_identical(a$replicate_parameters, b$replicate_parameters)
})

test_that("seed = NULL consumes the stream exactly like the frozen order", {
    set.seed(10)
    s <- sim_det(0, n_replicates = 3, param_cv = 0.05,
                 noise = list(platform = "gaussian", level = "low"))
    after <- .Random.seed
    set.seed(10)
    a <- s$rng
    ref <- .simulate_composition(list(
        params = base_p, regime = "SHUTOFF", times = shut_times,
        grid = seq(0, 160, by = 1), onset_time = 0, t_star = 100,
        residual_fraction = NULL, y0 = c(N = 0, N_s = 0, C = 0, C_s = 0),
        n_replicates = 3L, param_cv = 0.05, seed = NULL,
        noise_platform = "GAUSS", noise_level = "Low"))
    expect_identical(.Random.seed, after)
    expect_identical(s$observed$N, ref$observed$N)
    expect_false(is.null(a$random_seed_before))
})

test_that("deterministic latent and noisy observations are separated", {
    s <- sim_det(0, n_replicates = 2, param_cv = 0.05, seed = 1,
                 noise = list(platform = "gaussian", level = "high"))
    expect_true(all(c("latent", "sampled", "observed") %in% names(s)))
    expect_false("R" %in% names(s$observed))
    expect_identical(names(s$observed),
                     c("event", "time", "replicate", KINETIC_VARS))
    expect_false(isTRUE(all.equal(s$observed$N, s$sampled$N)))
    expect_null(sim_det(0)$observed)
    x <- postexport_data(s$observed, time_unit = s$time_unit)
    expect_s3_class(x, "postexport_data")
})

test_that("printed output does not claim a mechanism", {
    s <- sim_det(0, n_replicates = 2, param_cv = 0.05, seed = 1,
                 noise = list(platform = "gaussian", level = "low"))
    txt <- paste(c(utils::capture.output(print(s)),
                   utils::capture.output(print(summary(s)))), collapse = "\n")
    expect_false(grepl("splicing|detected", txt, ignore.case = TRUE))
    expect_true(grepl("do not establish", txt))
})
