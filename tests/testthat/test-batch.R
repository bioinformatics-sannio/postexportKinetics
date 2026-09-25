# Batch usability, multiple-testing adjustment, exploratory ranking and tidy
# tables. None of these change the single-event computation.

fx <- read_fixture("fx_orchestrator")

batch_data <- function() {
    cases <- c(alt = "orchestrator/alt_shutoff_gauss/default",
               null = "orchestrator/null_shutoff_gauss/default",
               rnaseq = "orchestrator/alt_shutoff_rnaseq/default",
               boundary = "orchestrator/boundary_null_shutoff/default")
    tab <- do.call(rbind, lapply(names(cases), function(ev) {
        cbind(event = ev, fx$cases[[cases[[ev]]]]$input$args$tsampled_data,
              stringsAsFactors = FALSE)
    }))
    postexport_data(tab, time_unit = "min")
}

run_batch <- function(x = batch_data(), B = 99L) {
    ev <- unique(x$event)
    test_postexport_conversion(
        x, t_star = 300,
        control = postexport_control(B = B,
                                     seed = stats::setNames(rep(20260924L,
                                                                length(ev)),
                                                            ev)))
}

res <- run_batch()

test_that("batch results equal single-event results and keep per-event objects", {
    expect_s3_class(res, "postexport_test_set")
    expect_identical(names(res$results), c("alt", "null", "rnaseq", "boundary"))
    for (ev in names(res$results)) {
        single <- test_postexport_conversion(
            batch_data(), t_star = 300, events = ev,
            control = postexport_control(B = 99, seed = 20260924L))
        expect_identical(res$results[[ev]]$raw, single$raw)
    }
    expect_identical(res$results$boundary$inference$p_value, 1)
})

test_that("an unexpected per-event error becomes an event status", {
    x <- batch_data()
    real <- .observed_fit
    local_mocked_bindings(.observed_fit = function(d, t_star, control) {
        if (nrow(d) == 18L) stop("simulated failure") else
            real(d, t_star, control)
    })
    x2 <- postexport_data(
        rbind(as.data.frame(unclass(x))[x$event %in% c("alt", "null"), ],
              transform(as.data.frame(unclass(x))[x$event == "boundary", ],
                        event = "three_reps")),
        time_unit = "min")
    out <- test_postexport_conversion(
        x2, t_star = 300,
        control = postexport_control(B = 9, seed = c(alt = 1L, null = 2L,
                                                     three_reps = 3L)))
    expect_identical(out$summary$status, c("ok", "ok", "event_error"))
    expect_match(out$results$three_reps$error_message, "simulated failure")
    expect_true(is.na(out$summary$p_value[3]))
    fits <- fit_postexport_model(x2, t_star = 300)
    expect_identical(fits$summary$status, c("ok", "ok", "event_error"))
    # A single-event call is not wrapped: the error propagates as before.
    expect_error(fit_postexport_model(x2, t_star = 300, events = "three_reps"),
                 "simulated failure")
})

test_that("BH adjustment equals stats::p.adjust on valid tests only", {
    adj <- adjust_postexport_pvalues(res)
    s <- adj$summary
    valid <- s$status == "ok" & is.finite(s$p_value)
    expect_identical(s$q_value[valid],
                     stats::p.adjust(res$summary$p_value[valid], "BH"))
    expect_identical(s$p_value, res$summary$p_value)
    expect_identical(adj$adjustment$method, "BH")
    expect_identical(adj$adjustment$n_adjusted, sum(valid))
    for (i in seq_along(adj$results)) {
        expect_identical(adj$results[[i]]$inference$q_value, s$q_value[i])
        expect_identical(adj$results[[i]]$raw, res$results[[i]]$raw)
    }
    # Other methods are passed through.
    hol <- adjust_postexport_pvalues(res, method = "holm")
    expect_identical(hol$summary$q_value,
                     stats::p.adjust(res$summary$p_value, "holm"))
    expect_error(adjust_postexport_pvalues(res, method = "fdr2"), "'method'")
})

test_that("invalid and failed events are excluded and keep their status", {
    r2 <- res
    r2$summary$status[2] <- "bootstrap_unstable"
    r2$summary$p_value[2] <- NA_real_
    adj <- adjust_postexport_pvalues(r2)
    expect_true(is.na(adj$summary$q_value[2]))
    expect_identical(adj$summary$status[2], "bootstrap_unstable")
    keep <- c(1, 3, 4)
    expect_identical(adj$summary$q_value[keep],
                     stats::p.adjust(r2$summary$p_value[keep], "BH"))
    expect_identical(adj$adjustment$n_excluded, 1L)
    # Status decides validity even when a finite p-value is present.
    r3 <- res
    r3$summary$status[3] <- "observed_fit_failed"
    adj3 <- adjust_postexport_pvalues(r3)
    expect_true(is.na(adj3$summary$q_value[3]))
    keep3 <- c(1, 2, 4)
    expect_identical(adj3$summary$q_value[keep3],
                     stats::p.adjust(r3$summary$p_value[keep3], "BH"))
})

test_that("groups adjust separately within each family", {
    g <- c(alt = "d1", null = "d1", rnaseq = "d2", boundary = "d2")
    adj <- adjust_postexport_pvalues(res, groups = g)
    p <- res$summary$p_value
    expect_identical(adj$summary$q_value[1:2], stats::p.adjust(p[1:2], "BH"))
    expect_identical(adj$summary$q_value[3:4], stats::p.adjust(p[3:4], "BH"))
    expect_identical(adj$summary$adjustment_group, unname(g))
    expect_error(adjust_postexport_pvalues(res, groups = c(alt = "d1")),
                 "no label")
    expect_error(adjust_postexport_pvalues(res, groups = c("a", "b")),
                 "one non-missing label")
})

test_that("ranking requires q-values and uses the frozen formula exactly", {
    expect_error(rank_postexport_candidates(res), "q-values are required")
    adj <- adjust_postexport_pvalues(res)
    rk <- rank_postexport_candidates(adj)
    expect_s3_class(rk, "postexport_ranking")
    s <- adj$summary[match(rk$event, adj$summary$event), ]
    expected <- s$sigma_c * s$IR * pmin(-log10(pmax(s$q_value, 1e-10)), 6)
    expected[s$status != "ok"] <- NA
    expect_identical(rk$score, expected)
    expect_identical(rk$p_value, s$p_value)
    expect_true(all(diff(rk$score[!is.na(rk$score)]) <= 0))
    expect_identical(rk$rank[1], 1L)
    b <- rk[rk$event == "boundary", ]
    expect_identical(b$score, 0)
    expect_true(b$at_boundary)
    expect_match(attr(rk, "definition"), "not an inferential quantity")
    expect_match(attr(rk, "provenance"), "run_real_datasets_revision.R")
})

test_that("q = 0, q = NA, caps, failed events and ties are handled", {
    adj <- adjust_postexport_pvalues(res)
    adj$summary$q_value <- c(0, 1e-12, NA, 0.5)
    adj$summary$sigma_c <- c(0.2, 0.2, 0.2, 0.1)
    adj$summary$IR <- c(0.5, 0.5, 0.5, 0.2)
    adj$summary$status <- c("ok", "ok", "ok", "ok")
    rk <- rank_postexport_candidates(adj)
    ev <- rk[order(match(rk$event, adj$summary$event)), ]
    # q = 0 and q = 1e-12 are floored at 1e-10: evidence capped at 6.
    expect_identical(ev$evidence[1:2], c(6, 6))
    expect_identical(ev$score[1:2], c(0.2 * 0.5 * 6, 0.2 * 0.5 * 6))
    # Ties share the minimum rank and keep input order.
    expect_identical(ev$rank[1:2], c(1L, 1L))
    expect_identical(rk$event[1:2], c("alt", "null"))
    # q = NA: retained, not rankable, listed last.
    expect_true(is.na(ev$score[3]) && is.na(ev$rank[3]))
    expect_identical(rk$event[nrow(rk)], "rnaseq")
    expect_identical(ev$rank[4], 3L)
    expect_equal(ev$evidence[4], -log10(0.5))
    # A failed event is retained with NA score and rank.
    adj$summary$status[4] <- "bootstrap_unstable"
    rk2 <- rank_postexport_candidates(adj)
    f <- rk2[rk2$event == "boundary", ]
    expect_true(is.na(f$score) && is.na(f$rank))
    expect_identical(f$status, "bootstrap_unstable")
    expect_identical(nrow(rk2), 4L)
})

test_that("ranking is computed within adjustment families", {
    g <- c(alt = "d1", null = "d1", rnaseq = "d2", boundary = "d2")
    rk <- rank_postexport_candidates(adjust_postexport_pvalues(res, groups = g))
    expect_identical(unique(rk$adjustment_group), c("d1", "d2"))
    expect_identical(sort(rk$rank[rk$adjustment_group == "d1"]), 1:2)
    expect_identical(sort(rk$rank[rk$adjustment_group == "d2"]), 1:2)
})

test_that("tidy tables have stable user-facing columns and roles", {
    tab <- as.data.frame(res)
    for (cl in c("event", "status", "sigma_c", "IR", "T_obs", "p_value",
                 "at_boundary", "n_bootstrap_valid", "bootstrap_failure_rate",
                 "condition_number", "rank_full")) {
        expect_true(cl %in% names(tab), label = cl)
    }
    expect_false("q_value" %in% names(tab))
    expect_false(any(vapply(tab, is.list, logical(1))))
    expect_identical(tab$p_value, res$summary$p_value)
    roles <- attr(tab, "column_roles")
    expect_identical(names(roles), names(tab))
    expect_identical(unname(roles[c("p_value", "sigma_c", "IR",
                                    "condition_number")]),
                     c("inference", "effect size", "fit", "diagnostic"))
    tq <- as.data.frame(adjust_postexport_pvalues(res))
    expect_true(all(c("q_value", "adjustment_group") %in% names(tq)))
    ft <- as.data.frame(fit_postexport_model(batch_data(), t_star = 300))
    expect_false("p_value" %in% names(ft))
    one <- as.data.frame(res$results$alt)
    expect_identical(nrow(one), 1L)
    expect_identical(one$p_value, res$results$alt$inference$p_value)
    # Existing summary and per-event objects are unchanged.
    expect_identical(names(res$summary)[1:3], c("event", "status", "sigma_c"))
})

test_that("a single test is adjusted as a family of size one", {
    one <- res$results$alt
    for (m in c("BH", "holm", "bonferroni")) {
        adj <- expect_no_warning(adjust_postexport_pvalues(one, method = m))
        expect_s3_class(adj, "postexport_test")
        expect_identical(adj$inference$q_value,
                         stats::p.adjust(one$inference$p_value, method = m))
        expect_identical(adj$inference$adjustment_method, m)
        expect_identical(adj$inference$p_value, one$inference$p_value)
        expect_identical(adj$raw, one$raw)
        expect_identical(adj$adjustment$n_adjusted, 1L)
    }
    # Under BH a one-test family gives q = p.
    expect_identical(adjust_postexport_pvalues(one)$inference$q_value,
                     one$inference$p_value)
    # Invalid single tests are excluded.
    bad <- one
    bad$status <- "bootstrap_unstable"
    ab <- adjust_postexport_pvalues(bad)
    expect_true(is.na(ab$inference$q_value))
    expect_identical(ab$adjustment$n_excluded, 1L)
    # Tidy table gains q_value; ranking still requires a set.
    tab <- as.data.frame(adjust_postexport_pvalues(one))
    expect_identical(tab$q_value, one$inference$p_value)
    expect_error(rank_postexport_candidates(adjust_postexport_pvalues(one)),
                 "postexport_test_set")
    expect_error(adjust_postexport_pvalues(fit_postexport_model(
        batch_data(), t_star = 300, events = "alt")), "postexport_test")
})
