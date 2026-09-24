# Data model, validation and control object.

make_wide <- function(n_rep = 3, times = c(0, 15, 30, 60), event = "e1") {
    set.seed(3)
    tab <- expand.grid(replicate = seq_len(n_rep), time = times)
    tab$event <- event
    for (s in c("N", "N_s", "C", "C_s")) {
        tab[[s]] <- 10 * exp(-0.01 * tab$time) + stats::runif(nrow(tab))
    }
    tab[, c("event", "time", "replicate", "N", "N_s", "C", "C_s")]
}

wide_to_long <- function(w) {
    map <- data.frame(kin = c("N", "N_s", "C", "C_s"),
                      compartment = c("nuclear", "nuclear", "cytoplasmic",
                                      "cytoplasmic"),
                      state = c("unprocessed", "processed", "unprocessed",
                                "processed"))
    do.call(rbind, lapply(seq_len(nrow(map)), function(i) {
        data.frame(event = w$event, time = w$time, replicate = w$replicate,
                   compartment = map$compartment[i], state = map$state[i],
                   abundance = w[[map$kin[i]]])
    }))
}

test_that("wide input is accepted unchanged and row order is preserved", {
    w <- make_wide()
    w <- w[c(5, 1, 9, 2, 3, 4, 6, 7, 8, 10, 11, 12), ]
    x <- postexport_data(w, time_unit = "min")
    expect_s3_class(x, "postexport_data")
    expect_identical(attr(x, "time_unit"), "min")
    for (s in KINETIC_VARS) expect_identical(x[[s]], as.numeric(w[[s]]))
    expect_identical(x$time, as.numeric(w$time))
})

test_that("long input converts unambiguously to the same wide data", {
    w <- make_wide()
    xw <- postexport_data(w, time_unit = "min")
    xl <- postexport_data(wide_to_long(w), time_unit = "min", format = "long")
    expect_identical(as.data.frame(unclass(xl))[KINETIC_VARS],
                     as.data.frame(unclass(xw))[KINETIC_VARS])
})

test_that("explicit column mapping is supported; nothing is guessed", {
    w <- make_wide()
    names(w)[names(w) == "event"] <- "event_id"
    expect_error(postexport_data(w, time_unit = "min"), "event")
    x <- postexport_data(w, time_unit = "min",
                         columns = c(event = "event_id"))
    expect_identical(unique(x$event), "e1")
    names(w)[names(w) == "N"] <- "nuc_unspliced"
    expect_error(postexport_data(w, time_unit = "min",
                                 columns = c(event = "event_id")),
                 "Missing kinetic state column")
})

test_that("time_unit is required", {
    expect_error(postexport_data(make_wide()), "time_unit")
})

test_that("validation errors are reported and block construction", {
    w <- make_wide()
    expect_error(postexport_data(w[, -4], time_unit = "min"),
                 "Missing kinetic state column")
    w_na <- w; w_na$C_s[3] <- NA
    expect_error(postexport_data(w_na, time_unit = "min"),
                 "missing or non-finite state values")
    w_dup <- rbind(w, w[1, ])
    expect_error(postexport_data(w_dup, time_unit = "min"), "duplicated")
    w_chr <- w; w_chr$N <- as.character(w_chr$N)
    expect_error(postexport_data(w_chr, time_unit = "min"), "Non-numeric")
    expect_error(postexport_data(make_wide(times = 0), time_unit = "min"),
                 "at least two are required")
    expect_error(postexport_data(make_wide(n_rep = 1), time_unit = "min"),
                 "at least two replicates")
    w_id <- w; w_id$replicate[2] <- NA
    expect_error(postexport_data(w_id, time_unit = "min"), "Missing values")
    v <- validate_postexport_data(w, t_star = c(1, 2))
    expect_true(any(v$errors$check == "t_star"))
    v <- validate_postexport_data(w, t_star = NA_real_)
    expect_true(any(v$errors$check == "t_star"))
})

test_that("missing states are never converted to zero", {
    l <- wide_to_long(make_wide())
    l <- l[-1, ]
    expect_error(postexport_data(l, time_unit = "min", format = "long"),
                 "lack one or more of the four kinetic states")
    l <- wide_to_long(make_wide())
    l$compartment[1] <- "nucleus"
    expect_error(postexport_data(l, time_unit = "min", format = "long"),
                 "Invalid compartment/state")
    l <- wide_to_long(make_wide())
    expect_error(postexport_data(rbind(l, l[1, ]), time_unit = "min",
                                 format = "long"),
                 "never aggregated")
})

test_that("negative abundances warn and are kept unchanged", {
    w <- make_wide()
    w$C_s[2] <- -0.5
    expect_warning(x <- postexport_data(w, time_unit = "min"),
                   "accepted by the frozen numerical core")
    expect_identical(x$C_s[2], -0.5)
    v <- validate_postexport_data(w)
    expect_identical(nrow(v$errors), 0L)
    expect_identical(nrow(v$warnings), 1L)
})

test_that("design diagnostics are information, not errors", {
    w <- make_wide()
    w <- w[-(1:2), ]
    v <- validate_postexport_data(w, t_star = 0)
    expect_identical(nrow(v$errors), 0L)
    expect_true(any(grepl("single replicate", v$info$message)))
    expect_true(any(grepl("identically zero", v$info$message)))
    v <- validate_postexport_data(make_wide(), t_star = 100)
    expect_true(any(grepl("at or after the last sample", v$info$message)))
})

test_that("control defaults are the frozen defaults", {
    ctl <- postexport_control()
    f <- formals(test_sigma_nested)
    expect_identical(ctl$B, as.integer(eval(f$B_n)))
    expect_identical(ctl$seed, eval(f$seed))
    expect_identical(ctl$lambda_time, eval(f$lambda_time))
    expect_identical(ctl$lambda_diag, eval(f$lambda_diag))
    expect_identical(ctl$rel_floor, eval(f$rel_floor))
    expect_identical(ctl$max_failure_rate, eval(f$max_failure_rate))
    expect_identical(ctl$scaling_A, eval(f$scaling_A))
    expect_identical(ctl$truncate_nonnegative_boot,
                     eval(f$truncate_nonnegative_boot))
    expect_false("lambda_var" %in% names(formals(postexport_control)))
    expect_false("lambda_var" %in% names(ctl))
})

test_that("control arguments are validated", {
    expect_error(postexport_control(B = 0), "positive whole")
    expect_error(postexport_control(B = 10.5), "positive whole")
    expect_error(postexport_control(lambda_time = 2), "\\[0, 1\\]")
    expect_error(postexport_control(max_failure_rate = -1), "\\[0, 1\\]")
    expect_error(postexport_control(rel_floor = 0), "positive")
    expect_error(postexport_control(seed = c(1, 2)), "named vector")
    expect_error(postexport_control(scaling_A = NA), "TRUE or FALSE")
})

test_that("t_star must be given explicitly and validly", {
    x <- postexport_data(make_wide(), time_unit = "min")
    expect_error(fit_postexport_model(x), "must be supplied explicitly")
    expect_error(test_postexport_conversion(x), "must be supplied explicitly")
    expect_error(fit_postexport_model(x, t_star = c(0, 1)), "single finite")
    expect_error(fit_postexport_model(make_wide(), t_star = 0),
                 "postexport_data")
    expect_s3_class(fit_postexport_model(x, t_star = NULL), "postexport_fit")
})

test_that("printed output uses cautious interpretation only", {
    x <- postexport_data(make_wide(), time_unit = "min")
    res <- test_postexport_conversion(
        x, t_star = 0, control = postexport_control(B = 9, seed = 1))
    out <- c(utils::capture.output(print(res)),
             utils::capture.output(print(summary(res))),
             utils::capture.output(print(fit_postexport_model(x, t_star = 0))),
             utils::capture.output(print(x)),
             utils::capture.output(print(postexport_control())))
    txt <- paste(out, collapse = "\n")
    expect_false(grepl("splicing", txt, ignore.case = TRUE))
    expect_false(grepl("detected", txt, ignore.case = TRUE))
    expect_true(grepl("post-export conversion component", txt))
    expect_true(grepl("not a likelihood-ratio test", txt))
    expect_false(grepl("q-value|q_value", txt))
})
