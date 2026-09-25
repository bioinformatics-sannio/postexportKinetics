# Assisted-by: Claude Code (Anthropic)
# Operational-domain diagnostics against the packaged manuscript benchmark
# table (built from synthetic_dataset/benchmark_main_corrected_onset_summary.tsv
# of the frozen tag by data-raw/benchmark_domain.R).

bench <- .pek_benchmark
prov <- .pek_benchmark_provenance

check_text <- function(x) {
    paste(c(utils::capture.output(print(x)),
            utils::capture.output(print(summary(x)))), collapse = "\n")
}

test_that("packaged benchmark table has the documented provenance", {
    expect_identical(prov$frozen_commit, FROZEN_COMMIT)
    expect_identical(prov$frozen_tag, "manuscript-revision-v1.0")
    expect_identical(prov$summary_file,
                     "synthetic_dataset/benchmark_main_corrected_onset_summary.tsv")
    expect_match(prov$summary_md5, "^[0-9a-f]{32}$")
    expect_identical(as.integer(prov$run_metadata$N_BOOT), 1999L)
    expect_identical(as.integer(prov$run_metadata$common_T_star), 332L)
    expect_identical(nrow(bench), 1152L)
    expect_identical(as.integer(table(bench$regime)), c(576L, 576L))
    expect_identical(bench$ci_contains_005,
                     bench$calibration_class == "CI includes 0.05")
    expect_identical(sum(bench$ci_contains_005[bench$regime == "SHUTOFF"]), 68L)
    expect_identical(sum(bench$ci_contains_005[bench$regime == "NONE"]), 0L)
    # Effective numbers of sampling times (generator design).
    expect_setequal(unique(bench$n_time_points[bench$regime == "NONE"]),
                    c(3L, 5L, 9L, 17L))
    expect_setequal(unique(bench$n_time_points[bench$regime == "SHUTOFF"]),
                    c(3L, 5L, 10L, 15L, 20L))
    shut <- bench[bench$regime == "SHUTOFF" & bench$n_time_points_nominal == 5 &
                      bench$sampling_interval == 10, ]
    expect_identical(unique(shut$sampling_times_relative_to_t_star),
                     "-10,0,10,20,30")
})

test_that("an exact benchmark design meeting the criterion is reported", {
    row <- bench[bench$regime == "SHUTOFF" & bench$platform == "rnaseq" &
                     bench$noise_level == "low" & bench$n_time_points == 5 &
                     bench$n_replicates == 3 & bench$sampling_interval == 10, ]
    expect_true(row$ci_contains_005)
    r <- check_operational_domain(regime = "SHUTOFF", platform = "rnaseq",
                                  noise_level = "low", n_time_points = 5,
                                  n_replicates = 3, sampling_interval = 10,
                                  time_unit = "min")
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "exact")
    expect_identical(nrow(ck$matches), 1L)
    expect_identical(ck$matches$type1_005, row$type1_005)
    expect_identical(ck$summary$n_criterion_met, 1L)
    expect_match(ck$statements[1],
                 "In the manuscript benchmark, the 1 configuration")
    expect_match(ck$statements[1], "was met in 1 of 1")
})

test_that("an exact benchmark design not meeting the criterion is reported", {
    r <- check_operational_domain(regime = "SHUTOFF", platform = "gaussian",
                                  noise_level = "high", n_time_points = 5,
                                  n_replicates = 3, sampling_interval = 50,
                                  time_unit = "min")
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "exact")
    expect_false(ck$matches$ci_contains_005)
    expect_identical(ck$matches$calibration_class, "Anti-conservative")
    expect_match(ck$statements[1], "was met in 0 of 1")
})

test_that("continuous transcription reports the anti-conservative NONE result", {
    r <- check_operational_domain(regime = "NONE", n_time_points = 5,
                                  n_replicates = 3)
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "exact")
    expect_identical(nrow(ck$matches), 48L)
    expect_true(any(grepl("strongly anti-conservative", ck$statements)))
    expect_true(any(grepl("met in 0 of 576 NONE configurations",
                          ck$statements)))
})

test_that("designs outside the benchmark report nearest designs only", {
    r <- check_operational_domain(regime = "SHUTOFF", n_time_points = 7,
                                  n_replicates = 4, sampling_interval = 15,
                                  time_unit = "min")
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "nearest")
    expect_match(ck$statements[1], "No configuration of the manuscript benchmark")
    expect_match(ck$statements[1],
                 "nearest evaluated benchmark designs (not equivalent designs",
                 fixed = TRUE)
    d <- ck$differences
    expect_identical(d$dimension,
                     c("sampling_interval", "n_time_points", "n_replicates"))
    expect_identical(d$benchmark_levels, c("10, 20", "5", "3, 5"))
    expect_true(all(ck$matches$sampling_interval %in% c(10, 20)))
    expect_true(all(ck$matches$n_time_points == 5L))
    expect_true(all(ck$matches$n_replicates %in% c(3L, 5L)))
    # All tied nearest designs are returned (both intervals, both replicate
    # levels, all platforms and noise levels), not one closest design.
    expect_identical(nrow(ck$matches), 2L * 2L * 3L * 4L)
    expect_setequal(unique(ck$matches$sampling_interval), c(10, 20))
    expect_setequal(unique(ck$matches$n_replicates), c(3L, 5L))
    expect_true(all(ck$matches$differs_in ==
                        "sampling_interval, n_time_points, n_replicates"))
})

test_that("nearest designs expose every relevant design when levels do not co-occur", {
    # 15 effective time points exist only at interval 50; interval 10 exists
    # only with 3/5/10/20 time points. Both nearest designs are returned.
    r <- check_operational_domain(regime = "SHUTOFF", platform = "gaussian",
                                  noise_level = "low", n_time_points = 16,
                                  n_replicates = 5, sampling_interval = 10,
                                  time_unit = "min")
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "nearest")
    got <- unique(ck$matches[, c("n_time_points", "sampling_interval")])
    rownames(got) <- NULL
    expect_identical(got, data.frame(n_time_points = c(20L, 15L),
                                     sampling_interval = c(10, 50)))
    expect_true(all(ck$matches$n_replicates == 5L))
    expect_setequal(ck$matches$differs_in,
                    c("n_time_points", "sampling_interval, n_time_points"))
    expect_match(ck$statements[1],
                 "nearest evaluated benchmark designs \\(not equivalent designs")
})

test_that("designs are derived from data; platform and noise are not inferred", {
    fx <- read_fixture("fx_real_mesc")
    d <- fx$cases[[1]]$input$data
    x <- postexport_data(cbind(event = "mesc", d), time_unit = "min")
    r <- check_operational_domain(x, regime = "SHUTOFF", t_star = 0)
    ck <- r$checks[[1]]
    expect_identical(ck$design$n_time_points, 5L)
    expect_identical(ck$design$n_replicates, 3L)
    expect_true(is.na(ck$design$sampling_interval))
    expect_identical(ck$design$n_before_t_star, 0L)
    expect_identical(ck$match_type, "nearest")
    expect_true(is.na(r$designs$platform))
    expect_true(any(grepl("never inferred", ck$caveats)))
    expect_true(any(grepl("irregular", ck$caveats)))
    expect_true(any(grepl("0 sampling time\\(s\\) before t_star", ck$caveats)))
    expect_setequal(unique(ck$matches$platform), c("gaussian", "rnaseq",
                                                   "rtqpcr"))
    expect_error(check_operational_domain(x, regime = "SHUTOFF",
                                          n_time_points = 5),
                 "not both")
})

test_that("pseudo-shutoff designs are not matched to the factorial benchmark", {
    r <- check_operational_domain(regime = "PSEUDO_SHUTOFF", n_time_points = 5,
                                  n_replicates = 3, sampling_interval = 10,
                                  time_unit = "min")
    expect_identical(r$checks[[1]]$match_type, "not_benchmarked")
    expect_identical(nrow(r$checks[[1]]$matches), 0L)
})

test_that("non-minute time units are not compared on the sampling interval", {
    r <- check_operational_domain(regime = "SHUTOFF", n_time_points = 5,
                                  n_replicates = 3, sampling_interval = 10,
                                  time_unit = "h")
    ck <- r$checks[[1]]
    expect_identical(ck$match_type, "nearest")
    expect_true(any(grepl("not in minutes", ck$caveats)))
})

test_that("wording never states that a dataset is calibrated or valid", {
    outs <- list(
        check_operational_domain(regime = "SHUTOFF", platform = "rnaseq",
                                 noise_level = "low", n_time_points = 5,
                                 n_replicates = 3, sampling_interval = 10,
                                 time_unit = "min"),
        check_operational_domain(regime = "NONE", n_time_points = 9,
                                 n_replicates = 10),
        check_operational_domain(regime = "SHUTOFF", n_time_points = 7,
                                 n_replicates = 4, sampling_interval = 15),
        check_operational_domain(regime = "PSEUDO_SHUTOFF", n_time_points = 5,
                                 n_replicates = 3)
    )
    for (o in outs) {
        txt <- check_text(o)
        expect_false(grepl("is calibrated|are calibrated|calibrated for",
                           txt, ignore.case = TRUE))
        expect_false(grepl("\\bvalid design|\\binvalid|verdict", txt,
                           ignore.case = TRUE))
        expect_false(grepl("your dataset", txt, ignore.case = TRUE))
        expect_true(grepl("not a calibration guarantee", txt))
    }
})

test_that("the check is diagnostic only and validates its inputs", {
    expect_error(check_operational_domain(n_time_points = 5, n_replicates = 3),
                 "'regime' must be supplied")
    expect_error(check_operational_domain(regime = "NONE", t_star = 0,
                                          n_time_points = 5, n_replicates = 3),
                 "no intervention time")
    expect_error(check_operational_domain(regime = "SHUTOFF",
                                          platform = "microarray",
                                          n_time_points = 5, n_replicates = 3),
                 "'platform'")
    expect_false("calibrated" %in% names(check_operational_domain(
        regime = "SHUTOFF", n_time_points = 5, n_replicates = 3)))
})
