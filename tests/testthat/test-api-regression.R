# Regression of the public API against the frozen tag.
#
# test_postexport_conversion() must return, in `$raw`, the frozen
# test_sigma_nested() result for every orchestration fixture case that the
# public control can express; fit_postexport_model() must reproduce the
# frozen observed quantities. Same-platform: strict (T2; p-values, status,
# counts exact). Cross-platform: approved scale-aware policy.

fx <- read_fixture("fx_orchestrator")
same_platform <- identical(regression_level(fx$provenance), "same-platform")

as_public_data <- function(d, event = "ev") {
    tab <- cbind(event = event, d, stringsAsFactors = FALSE)
    postexport_data(tab, time_unit = "min")
}

public_control <- function(a) {
    postexport_control(
        B = a$B_n, seed = a$seed, lambda_time = a$lambda_time,
        lambda_diag = a$lambda_diag, rel_floor = a$rel_floor,
        max_failure_rate = a$max_failure_rate, scaling_A = a$scaling_A,
        truncate_nonnegative_boot = a$truncate_nonnegative_boot
    )
}

public_cases <- Filter(function(case) {
    a <- case$input$args
    a$max_failure_rate >= 0 && is.null(case$output$error) &&
        !identical(case$output$value$status, "observed_system_failed") &&
        isTRUE(a$return_boot)
}, fx$cases)

run_public_test <- function(case) {
    a <- case$input$args
    x <- as_public_data(a$tsampled_data)
    if (!is.null(case$input$pre_seed)) set.seed(case$input$pre_seed)
    quiet_tstar(test_postexport_conversion(x, t_star = a$t_star,
                                           control = public_control(a)))
}

test_that("public test covers the required cases", {
    keys <- names(public_cases)
    for (k in c("orchestrator/null_shutoff_gauss/default",
                "orchestrator/alt_shutoff_gauss/default",
                "orchestrator/alt_shutoff_rnaseq/default",
                "orchestrator/boundary_null_shutoff/default",
                "orchestrator/null_none_gauss/default",
                "orchestrator/real_mesc/Ppp1r36dn",
                "orchestrator/real_mesc/Nsd1")) {
        expect_true(k %in% keys, label = k)
    }
})

test_that("test_postexport_conversion() returns the frozen result", {
    for (key in names(public_cases)) {
        case <- public_cases[[key]]
        res <- run_public_test(case)
        expect_s3_class(res, "postexport_test")
        expect_regression(list(value = res$raw), case$output, TOL_T2,
                          paste(key, "[public]"), fx$provenance, case)
        if (same_platform) {
            expect_identical(res$raw, case$output$value,
                             label = paste(key, "bitwise"))
        }
    }
})

test_that("public result fields are the frozen fields, not recomputations", {
    for (key in names(public_cases)) {
        res <- run_public_test(public_cases[[key]])
        raw <- res$raw
        expect_identical(res$status, raw$status)
        expect_identical(res$inference$p_value, raw$p.value)
        expect_identical(res$estimates$sigma_c, unname(raw$Sigma))
        expect_identical(res$estimates$coef_full, raw$coef_full)
        expect_identical(res$estimates$coef_null, raw$coef_null)
        expect_identical(res$fit$RSS_null, raw$RSS0)
        expect_identical(res$fit$RSS_full, raw$RSS1)
        expect_identical(res$fit$T_obs, raw$T.obs)
        expect_identical(res$fit$IR, raw$IR)
        expect_identical(res$boundary$tolerance, raw$boundary.tolerance)
        expect_identical(res$boundary$at_boundary,
                         raw$T.obs <= raw$boundary.tolerance)
        expect_identical(res$inference$n_bootstrap_valid,
                         raw$n.bootstrap.valid)
        expect_identical(res$inference$bootstrap_failure_rate,
                         raw$bootstrap.failure.rate)
        expect_identical(res$inference$atom_zero, raw$atom.zero)
        expect_identical(res$inference$T_boot, raw$T.boot)
        expect_identical(res$diagnostics$condition_number,
                         raw$condition.number)
        expect_identical(res$diagnostics$rank_full, raw$rank.full)
        expect_identical(res$diagnostics$rank_null, raw$rank.null)
        expect_identical(res$null_means, raw$null.means)
        expect_identical(res$inference$B, public_cases[[key]]$input$args$B_n)
    }
})

test_that("fit_postexport_model() reproduces the frozen observed fit", {
    for (key in names(public_cases)) {
        case <- public_cases[[key]]
        a <- case$input$args
        fit <- quiet_tstar(fit_postexport_model(
            as_public_data(a$tsampled_data), t_star = a$t_star,
            control = public_control(a)))
        expect_s3_class(fit, "postexport_fit")
        raw <- case$output$value
        got <- list(
            coef_full = fit$estimates$coef_full,
            coef_null = fit$estimates$coef_null,
            T.obs = fit$fit$T_obs, RSS0 = fit$fit$RSS_null,
            RSS1 = fit$fit$RSS_full, IR = fit$fit$IR,
            boundary.tolerance = fit$boundary$tolerance,
            condition.number = fit$diagnostics$condition_number,
            min.singular.value = fit$diagnostics$min_singular_value,
            rank.full = fit$diagnostics$rank_full,
            rank.null = fit$diagnostics$rank_null,
            pooled.covariance = fit$diagnostics$pooled_covariance,
            n.replicates.by.time = fit$design$n_replicates_by_time,
            times = fit$design$times
        )
        expect_regression(list(value = got), list(value = raw[names(got)]),
                          TOL_T2, paste(key, "[fit]"), fx$provenance, case)
        if (same_platform) {
            expect_identical(got, raw[names(got)],
                             label = paste(key, "[fit] bitwise"))
        }
        expect_identical(fit$boundary$at_boundary,
                         raw$T.obs <= raw$boundary.tolerance)
    }
})

test_that("real mESC events reproduce the published values", {
    targets <- list(
        Ppp1r36dn = c(sigma_c = 0.01899230, IR = 0.5350818),
        Nsd1 = c(sigma_c = 0.04742467, IR = 0.3810515)
    )
    for (gene in names(targets)) {
        case <- fx$cases[[sprintf("orchestrator/real_mesc/%s", gene)]]
        x <- as_public_data(case$input$args$tsampled_data, gene)
        expect_warning(fit <- fit_postexport_model(x, t_star = 0),
                       "not estimable")
        expect_equal(signif(fit$estimates$sigma_c, 7),
                     targets[[gene]][["sigma_c"]])
        expect_equal(signif(fit$fit$IR, 7), targets[[gene]][["IR"]])
        expect_identical(fit$diagnostics$structurally_zero_columns, "R")
    }
})

test_that("several events are processed sequentially and equal single runs", {
    a1 <- fx$cases[["orchestrator/alt_shutoff_gauss/default"]]$input$args
    a2 <- fx$cases[["orchestrator/null_shutoff_gauss/default"]]$input$args
    tab <- rbind(cbind(event = "alt", a1$tsampled_data),
                 cbind(event = "null", a2$tsampled_data))
    x <- postexport_data(tab, time_unit = "min")
    ctl <- postexport_control(B = 99, seed = c(alt = 20260924L,
                                               null = 20260924L))
    set_res <- test_postexport_conversion(x, t_star = 300, control = ctl)
    expect_s3_class(set_res, "postexport_test_set")
    expect_identical(set_res$summary$event, c("alt", "null"))
    single <- test_postexport_conversion(
        x, t_star = 300, events = "alt",
        control = postexport_control(B = 99, seed = 20260924L))
    expect_identical(set_res$results$alt$raw, single$raw)
    expect_identical(set_res$summary$p_value,
                     c(set_res$results$alt$inference$p_value,
                       set_res$results$null$inference$p_value))
    expect_error(
        test_postexport_conversion(x, t_star = 300,
                                   control = postexport_control(B = 9,
                                                                seed = 1)),
        "same bootstrap random-number stream")
    expect_error(
        test_postexport_conversion(
            x, t_star = 300,
            control = postexport_control(B = 9, seed = c(alt = 1L))),
        "No seed supplied")
    fits <- fit_postexport_model(x, t_star = 300)
    expect_s3_class(fits, "postexport_fit_set")
    expect_false("p_value" %in% names(fits$summary))
})

test_that("seed = NULL uses the global random-number state as frozen", {
    case <- fx$cases[["orchestrator/alt_shutoff_gauss/seed=NULL/pre_seed=7"]]
    res <- run_public_test(case)
    expect_null(res$rng$seed)
    expect_false(is.null(res$rng$random_seed_before))
    if (same_platform) {
        expect_identical(res$raw$p.value, case$output$value$p.value)
    }
})
