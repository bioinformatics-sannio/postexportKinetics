# SummarizedExperiment (layout A) input: conversion, errors, and identity of
# all downstream results with the canonical wide-table input.

example_se <- function(assay_names = c(N = "N", N_s = "N_s", C = "C",
                                       C_s = "C_s"),
                       time = "time", replicate = "replicate") {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    ex <- postexport_example
    events <- unique(ex$event)
    samples <- unique(ex[, c("time", "replicate")])
    rownames(samples) <- sprintf("t%g_r%d", samples$time, samples$replicate)
    cell <- cbind(match(ex$event, events),
                  match(paste(ex$time, ex$replicate),
                        paste(samples$time, samples$replicate)))
    state_matrix <- function(state) {
        m <- matrix(NA_real_, length(events), nrow(samples),
                    dimnames = list(events, rownames(samples)))
        m[cell] <- ex[[state]]
        m
    }
    a <- lapply(names(assay_names), state_matrix)
    names(a) <- unname(assay_names[names(assay_names)])
    cd <- samples
    names(cd) <- c(time, replicate)
    SummarizedExperiment::SummarizedExperiment(assays = a, colData = cd)
}

canonical <- function() {
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    postexport_data(postexport_example, time_unit = "min")
}

test_that("the shipped example converts exactly to the canonical object", {
    se <- example_se()
    x <- postexport_data_from_se(se, time_unit = "min")
    expect_s3_class(x, "postexport_data")
    expect_identical(x, canonical())
    # One row per (event, sample) cell, ordered by event then sample.
    expect_identical(nrow(x), nrow(se) * ncol(se))
    expect_identical(unique(x$event), rownames(se))
    # Subclasses are accepted.
    rse <- as(se, "RangedSummarizedExperiment")
    expect_identical(postexport_data_from_se(rse, time_unit = "min"),
                     canonical())
})

test_that("custom assay and colData names are honoured", {
    an <- c(N = "nuc_unproc", N_s = "nuc_proc", C = "cyt_unproc",
            C_s = "cyt_proc")
    se <- example_se(assay_names = an, time = "minutes", replicate = "rep")
    x <- postexport_data_from_se(se, time_unit = "min", assays = an,
                                 time = "minutes", replicate = "rep")
    expect_identical(x, canonical())
    # The assays argument may list the states in any order.
    x2 <- postexport_data_from_se(se, time_unit = "min", assays = rev(an),
                                  time = "minutes", replicate = "rep")
    expect_identical(x2, canonical())
})

test_that("missing assays, rownames and colData fields are errors", {
    se <- example_se()
    se_no_cs <- se
    SummarizedExperiment::assays(se_no_cs) <-
        SummarizedExperiment::assays(se)[c("N", "N_s", "C")]
    expect_error(postexport_data_from_se(se_no_cs, time_unit = "min"),
                 "Assay\\(s\\) not found in 'se': C_s")
    se_norn <- se
    rownames(se_norn) <- NULL
    expect_error(postexport_data_from_se(se_norn, time_unit = "min"),
                 "non-missing, non-empty rownames")
    se_dup <- se[c(1, 1), ]
    expect_error(postexport_data_from_se(se_dup, time_unit = "min"),
                 "must be unique")
    expect_error(postexport_data_from_se(se, time_unit = "min",
                                         time = "minutes"),
                 "colData\\(se\\) column\\(s\\) not found: minutes")
    expect_error(postexport_data_from_se(se, time_unit = "min",
                                         replicate = "rep"),
                 "colData\\(se\\) column\\(s\\) not found: rep")
    expect_error(postexport_data_from_se(se, time_unit = "min",
                                         assays = c(N = "N", N_s = "N_s",
                                                    C = "C")),
                 "'assays' must be a character vector")
    expect_error(postexport_data_from_se(canonical(), time_unit = "min"),
                 "must be a SummarizedExperiment")
    expect_error(postexport_data_from_se(se), "time_unit")
})

test_that("non-numeric assays and missing values are errors, never filled", {
    se <- example_se()
    se_chr <- se
    m <- SummarizedExperiment::assay(se, "N")
    storage.mode(m) <- "character"
    SummarizedExperiment::assay(se_chr, "N") <- m
    expect_error(postexport_data_from_se(se_chr, time_unit = "min"),
                 "Assay 'N' \\(state N\\) must be numeric")
    se_na <- se
    m <- SummarizedExperiment::assay(se, "C")
    m[2, 3] <- NA
    SummarizedExperiment::assay(se_na, "C") <- m
    expect_error(postexport_data_from_se(se_na, time_unit = "min"),
                 "Invalid post-export kinetics data")
    se_tna <- se
    SummarizedExperiment::colData(se_tna)$time[1] <- NA
    expect_error(postexport_data_from_se(se_tna, time_unit = "min"),
                 "Invalid post-export kinetics data")
})

test_that("dimensions are consistent and empty objects are rejected", {
    se <- example_se()
    # SummarizedExperiment itself refuses assays of incompatible dimensions.
    m <- SummarizedExperiment::assay(se, "N")
    expect_error(SummarizedExperiment::SummarizedExperiment(
        assays = list(N = m, N_s = m[, -1])))
    expect_error(postexport_data_from_se(se[0, ], time_unit = "min"),
                 "at least one event")
    expect_error(postexport_data_from_se(se[, 0], time_unit = "min"),
                 "at least one event")
    sub <- se[2:3, 1:10]
    x <- postexport_data_from_se(sub, time_unit = "min")
    expect_identical(nrow(x), 2L * 10L)
})

test_that("canonical and SE-derived inputs give identical results", {
    x_can <- canonical()
    x_se <- postexport_data_from_se(example_se(), time_unit = "min")
    data(postexport_example, package = "postexportKinetics",
         envir = environment())
    expect_identical(
        validate_postexport_data(as.data.frame(unclass(x_se))[, 1:7],
                                 t_star = 332),
        validate_postexport_data(postexport_example, t_star = 332))
    expect_identical(attr(x_se, "validation"), attr(x_can, "validation"))
    expect_identical(fit_postexport_model(x_se, t_star = 332),
                     fit_postexport_model(x_can, t_star = 332))
    ev <- c("alt_3", "null_1")
    ctl <- postexport_control(B = 19, seed = c(alt_3 = 11L, null_1 = 12L))
    set.seed(1)
    r_se <- test_postexport_conversion(x_se, t_star = 332, control = ctl,
                                       events = ev)
    set.seed(1)
    r_can <- test_postexport_conversion(x_can, t_star = 332, control = ctl,
                                        events = ev)
    expect_identical(r_se, r_can)
    for (e in ev) expect_identical(r_se$results[[e]]$raw,
                                   r_can$results[[e]]$raw)
})
