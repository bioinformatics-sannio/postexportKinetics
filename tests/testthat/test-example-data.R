# Example dataset: structure, provenance and a smoke test of the documented
# workflow. No numerical expectations are imposed beyond validity.

test_that("example data have the documented structure", {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    data(postexport_example_truth, package = "postexportKinetics",
         envir = environment())
    expect_identical(names(postexport_example),
                     c("event", "time", "replicate", "N", "N_s", "C", "C_s"))
    expect_identical(nrow(postexport_example), 200L)
    expect_false(anyNA(postexport_example))
    ev <- c(paste0("alt_", 1:4), paste0("null_", 1:4))
    expect_identical(unique(postexport_example$event), ev)
    expect_identical(sort(unique(postexport_example$time)),
                     332 + c(-10, 0, 10, 20, 30))
    expect_true(all(table(postexport_example$event,
                          postexport_example$time) == 5L))
    expect_identical(postexport_example_truth$event, ev)
    expect_identical(postexport_example_truth$sigma_c > 0,
                     startsWith(ev, "alt"))
    expect_true(all(postexport_example_truth$t_star == 332))
    v <- validate_postexport_data(postexport_example, t_star = 332)
    expect_identical(c(nrow(v$errors), nrow(v$warnings), nrow(v$info)),
                     c(0L, 0L, 0L))
})

test_that("the long-format example file holds the same observations", {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    long <- utils::read.csv(system.file("extdata",
                                        "postexport_example_long.csv",
                                        package = "postexportKinetics"))
    x <- postexport_data(postexport_example, time_unit = "min")
    y <- postexport_data(long, time_unit = "min", format = "long")
    cols <- c("event", "time", "replicate", "N", "N_s", "C", "C_s")
    expect_equal(as.data.frame(unclass(y))[, cols],
                 as.data.frame(unclass(x))[, cols],
                 ignore_attr = TRUE, tolerance = 1e-14)
})

test_that("the example design is an exact benchmark design", {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    x <- postexport_data(postexport_example, time_unit = "min")
    dom <- check_operational_domain(x, regime = "SHUTOFF", t_star = 332,
                                    platform = "rnaseq",
                                    noise_level = "very_low")
    expect_identical(unique(dom$designs$match_type), "exact")
})

test_that("the documented workflow runs on the example data", {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    ev <- c("alt_3", "null_1")
    x <- postexport_data(
        postexport_example[postexport_example$event %in% ev, ],
        time_unit = "min")
    res <- test_postexport_conversion(
        x, t_star = 332,
        control = postexport_control(B = 19, seed = c(alt_3 = 1, null_1 = 2)))
    expect_identical(res$summary$status, c("ok", "ok"))
    adj <- adjust_postexport_pvalues(res)
    rk <- rank_postexport_candidates(adj)
    expect_s3_class(rk, "postexport_ranking")
    expect_s3_class(plot(res$results$alt_3), "ggplot")
})

test_that("the defaults used for reporting match postexport_control()", {
    f <- formals(postexport_control)
    for (k in names(.FROZEN_CONTROL_DEFAULTS)) {
        expect_identical(eval(f[[k]]), .FROZEN_CONTROL_DEFAULTS[[k]],
                         label = k)
    }
})
