# Assisted-by: Claude Code (Anthropic)
# =============================================================================
# Operational-domain diagnostics: check_operational_domain()
#
# Compares an experimental design with the configurations of the manuscript's
# corrected factorial benchmark (internal table .pek_benchmark, built by
# data-raw/benchmark_domain.R from the frozen tag). Diagnostic only: it never
# blocks or alters inference and never states that a dataset is calibrated.
# =============================================================================

.DOMAIN_REGIMES <- c("NONE", "SHUTOFF", "PSEUDO_SHUTOFF")
.BENCHMARK_MINUTE_UNITS <- c("min", "minute", "minutes")


#' Compare a design with the manuscript benchmark (diagnostic only)
#'
#' Reports how configurations of the manuscript's corrected factorial
#' benchmark that match (or are nearest to) an experimental design behaved:
#' empirical Type-I error at alpha = 0.05 with its Wilson 95% interval,
#' whether the manuscript's operational criterion was met for those benchmark
#' configurations, and power. This is an empirical comparison with simulated
#' benchmark designs; it is not a calibration guarantee for any dataset, it
#' never blocks or alters inference and it gives no valid/invalid verdict.
#'
#' @section Benchmark:
#' 1152 configurations of the corrected factorial benchmark (tag
#' `manuscript-revision-v1.0`): regimes `NONE` (continuous transcription) and
#' `SHUTOFF` (complete shutoff); platforms `gaussian`, `rnaseq`, `rtqpcr`;
#' noise levels `very_low`, `low`, `medium`, `high`; 3, 5 or 10 replicates;
#' sampling intervals 5, 10, 20, 50; nominal 3, 5, 10 or 20 time points
#' (matching uses the effective number of distinct sampling times). Each
#' configuration simulated 2000 genes (about 20% with `sigma_c > 0`) with
#' rates per minute, a common shutoff time 332, onset shifts between -100 and
#' 100
#' and B = 1999 bootstrap replicates. SHUTOFF designs sampled one point at
#' `t_star - interval`, one at `t_star` and the remaining points at spacing
#' `interval` after `t_star`. Pseudo-shutoff designs are not part of this
#' benchmark. The operational criterion of the manuscript
#' (`analyze_benchmark_corrected_onset_final.R`) is that the Wilson 95%
#' interval of the empirical Type-I error contains 0.05; the Type-I error
#' lying in \[0.025, 0.075\] is reported as a secondary descriptive flag.
#'
#' @section Matching:
#' A benchmark configuration matches exactly when the regime, the platform
#' and noise level (when supplied; otherwise all are included), the number of
#' time points, the number of replicates and, for `SHUTOFF`, the sampling
#' interval are equal. The sampling interval is compared only when it is
#' exactly regular and the time unit is minutes (the benchmark time scale);
#' units are never converted. Without an exact match, the set of nearest
#' evaluated benchmark designs (not equivalent designs) is returned: among
#' configurations with the same regime, platform and noise level, for every
#' ordering of the design dimensions (sampling interval, number of time
#' points, number of replicates) the configurations at the nearest evaluated
#' level of each dimension in turn are kept, ties included, and the union
#' over all orderings is reported. No single configuration is singled out as
#' the closest, no calibration is interpolated and no score is computed.
#' Each returned configuration lists the dimensions in which it differs
#' (`differs_in`).
#'
#' @section Vocabulary:
#' Package labels map one to one to the manuscript benchmark labels:
#' platforms `gaussian` = GAUSS, `rnaseq` = RNA-seq, `rtqpcr` = RT-qPCR;
#' noise levels `very_low` = Very low, `low` = Low, `medium` = Medium,
#' `high` = High.
#'
#' @param data Optional `postexport_data` object. The number of time points,
#'   the minimum number of replicates per time point, the sampling interval
#'   (if regular) and the time unit are then taken from each event. Do not
#'   combine with `n_time_points`, `n_replicates`, `sampling_interval` or
#'   `time_unit`.
#' @param regime `"NONE"`, `"SHUTOFF"` or `"PSEUDO_SHUTOFF"`; required. Not
#'   inferred from the data.
#' @param t_star Intervention time (for `data` with a shutoff regime); used to
#'   describe the sampling layout around `t_star`.
#' @param platform Optional measurement platform (`"gaussian"`, `"rnaseq"`,
#'   `"rtqpcr"`); never inferred from abundances. `NULL` reports all
#'   platforms.
#' @param noise_level Optional noise level (`"very_low"`, `"low"`,
#'   `"medium"`, `"high"`); never inferred. `NULL` reports all levels.
#' @param n_time_points,n_replicates,sampling_interval Explicit design
#'   (without `data`): number of distinct sampling times, replicates per time
#'   point and regular sampling interval (`NA` if irregular).
#' @param time_unit Time unit of `sampling_interval` (without `data`).
#'
#' @return An object of class `postexport_domain_check`: a list with
#'   `designs` (one row per distinct design and the events sharing it),
#'   `checks` (per design: `design`, `match_type` = `"exact"`, `"nearest"` or
#'   `"not_benchmarked"`, `matches` (benchmark configurations), `differences`
#'   (for nearest designs: user value and benchmark levels per dimension),
#'   `summary`, `statements` and `caveats`) and `provenance`. For nearest
#'   designs, `matches` has an additional column `differs_in`.
#'
#' @seealso [test_postexport_conversion()]
#'
#' @examples
#' check_operational_domain(regime = "SHUTOFF", platform = "rnaseq",
#'                          noise_level = "medium", n_time_points = 5,
#'                          n_replicates = 3, sampling_interval = 10,
#'                          time_unit = "min")
#' check_operational_domain(regime = "NONE", n_time_points = 5,
#'                          n_replicates = 3)
#'
#' @export
check_operational_domain <- function(data = NULL, regime, t_star = NULL,
                                     platform = NULL, noise_level = NULL,
                                     n_time_points = NULL,
                                     n_replicates = NULL,
                                     sampling_interval = NULL,
                                     time_unit = NULL) {
    if (missing(regime) || !is.character(regime) || length(regime) != 1L ||
        !regime %in% .DOMAIN_REGIMES) {
        stop("'regime' must be supplied: \"NONE\", \"SHUTOFF\" or ",
             "\"PSEUDO_SHUTOFF\".", call. = FALSE)
    }
    if (!is.null(platform) &&
        !(length(platform) == 1L && platform %in% names(.NOISE_PLATFORMS))) {
        stop("'platform' must be NULL, \"gaussian\", \"rnaseq\" or ",
             "\"rtqpcr\".", call. = FALSE)
    }
    if (!is.null(noise_level) &&
        !(length(noise_level) == 1L && noise_level %in% names(.NOISE_LEVELS))) {
        stop("'noise_level' must be NULL, \"very_low\", \"low\", ",
             "\"medium\" or \"high\".", call. = FALSE)
    }
    if (regime == "NONE" && !is.null(t_star)) {
        stop("Regime \"NONE\" has no intervention time; use t_star = NULL.",
             call. = FALSE)
    }
    if (!is.null(t_star) &&
        (!is.numeric(t_star) || length(t_star) != 1L || !is.finite(t_star))) {
        stop("'t_star' must be NULL or a single finite number.", call. = FALSE)
    }
    designs <- if (!is.null(data)) {
        if (!inherits(data, "postexport_data")) {
            stop("'data' must be a postexport_data object.", call. = FALSE)
        }
        if (!is.null(n_time_points) || !is.null(n_replicates) ||
            !is.null(sampling_interval) || !is.null(time_unit)) {
            stop("Supply either 'data' or the explicit design arguments, ",
                 "not both.", call. = FALSE)
        }
        .designs_from_data(data, t_star)
    } else {
        .design_from_arguments(n_time_points, n_replicates, sampling_interval,
                               time_unit)
    }
    checks <- lapply(seq_len(nrow(designs)), function(i) {
        .domain_check_design(designs[i, , drop = FALSE], regime, t_star,
                             platform, noise_level)
    })
    designs$regime <- regime
    designs$platform <- if (is.null(platform)) NA_character_ else platform
    designs$noise_level <- if (is.null(noise_level)) NA_character_ else
        noise_level
    designs$match_type <- vapply(checks, `[[`, character(1), "match_type")
    structure(
        list(designs = designs, checks = checks,
             provenance = .pek_benchmark_provenance),
        class = "postexport_domain_check"
    )
}

.design_from_arguments <- function(n_time_points, n_replicates,
                                   sampling_interval, time_unit) {
    whole <- function(v, nm) {
        if (!is.numeric(v) || length(v) != 1L || !is.finite(v) || v < 1 ||
            v != round(v)) {
            stop(sprintf("'%s' must be a single positive whole number.", nm),
                 call. = FALSE)
        }
        as.integer(v)
    }
    if (is.null(n_time_points) || is.null(n_replicates)) {
        stop("Without 'data', supply 'n_time_points' and 'n_replicates'.",
             call. = FALSE)
    }
    si <- if (is.null(sampling_interval)) NA_real_ else sampling_interval
    if (!is.numeric(si) || length(si) != 1L ||
        (!is.na(si) && (!is.finite(si) || si <= 0))) {
        stop("'sampling_interval' must be NULL, NA or a positive number.",
             call. = FALSE)
    }
    if (!is.null(time_unit) &&
        (!is.character(time_unit) || length(time_unit) != 1L)) {
        stop("'time_unit' must be NULL or a character string.", call. = FALSE)
    }
    data.frame(events = NA_character_,
               n_time_points = whole(n_time_points, "n_time_points"),
               n_replicates = whole(n_replicates, "n_replicates"),
               sampling_interval = as.numeric(si),
               time_unit = if (is.null(time_unit)) NA_character_ else
                   time_unit,
               n_before_t_star = NA_integer_,
               stringsAsFactors = FALSE)
}

.designs_from_data <- function(data, t_star) {
    unit <- attr(data, "time_unit")
    per_event <- do.call(rbind, lapply(unique(data$event), function(ev) {
        tm <- data$time[data$event == ev]
        tt <- sort(unique(tm))
        nk <- as.integer(table(factor(tm, levels = tt)))
        dd <- unique(round(diff(tt), 10))
        data.frame(
            event = ev,
            n_time_points = length(tt),
            n_replicates = min(nk),
            sampling_interval = if (length(dd) == 1L) dd else NA_real_,
            time_unit = unit,
            n_before_t_star = if (is.null(t_star)) NA_integer_ else
                sum(tt < t_star),
            stringsAsFactors = FALSE
        )
    }))
    key <- paste(per_event$n_time_points, per_event$n_replicates,
                 per_event$sampling_interval, per_event$n_before_t_star)
    first <- !duplicated(key)
    out <- per_event[first, setdiff(names(per_event), "event"), drop = FALSE]
    out$events <- vapply(key[first], function(k) {
        toString(per_event$event[key == k])
    }, character(1))
    rownames(out) <- NULL
    out[, c("events", setdiff(names(out), "events"))]
}

# Nearest evaluated benchmark designs, without a score: for every ordering of
# the design dimensions, keep (lexicographically) the configurations at the
# nearest evaluated level of each dimension in turn, retaining ties; return
# the union over all orderings. When the per-dimension nearest levels are
# jointly evaluated this is exactly their combinations; otherwise every
# relevant nearest design is returned rather than a single arbitrary one.
# Rows are ordered lexicographically for display, and `differs_in` lists the
# dimensions in which a configuration differs from the design.
.nearest_designs <- function(cand, dims, user_vals) {
    perms <- function(v) {
        if (length(v) <= 1L) return(list(v))
        out <- list()
        for (i in seq_along(v)) {
            for (p in perms(v[-i])) out[[length(out) + 1L]] <- c(v[i], p)
        }
        out
    }
    keep <- rep(FALSE, nrow(cand))
    for (ord in perms(dims)) {
        sel <- rep(TRUE, nrow(cand))
        for (d in ord) {
            lv <- .nearest_levels(cand[[d]][sel], user_vals[[d]])
            sel <- sel & cand[[d]] %in% lv
        }
        keep <- keep | sel
    }
    out <- cand[keep, , drop = FALSE]
    out <- out[do.call(order, unname(as.list(out[dims]))), , drop = FALSE]
    out$differs_in <- vapply(seq_len(nrow(out)), function(i) {
        dd <- dims[vapply(dims, function(d) {
            is.na(user_vals[[d]]) || out[[d]][i] != user_vals[[d]]
        }, logical(1))]
        if (length(dd)) paste(dd, collapse = ", ") else "none"
    }, character(1))
    out
}

.nearest_levels <- function(values, target) {
    if (is.na(target)) return(sort(unique(values)))
    d <- abs(values - target)
    sort(unique(values[d == min(d)]))
}

.fmt_range <- function(x) {
    x <- x[is.finite(x)]
    if (!length(x)) return("NA")
    r <- range(x)
    if (r[1] == r[2]) .fmt(r[1], 3) else
        paste(.fmt(r[1], 3), "to", .fmt(r[2], 3))
}

.domain_check_design <- function(design, regime, t_star, platform,
                                 noise_level) {
    caveats <- .domain_caveats(design, regime, platform, noise_level)
    bench <- .pek_benchmark
    interval_comparable <- regime == "SHUTOFF" &&
        !is.na(design$sampling_interval) &&
        (is.na(design$time_unit) ||
         design$time_unit %in% .BENCHMARK_MINUTE_UNITS)
    if (regime == "SHUTOFF" && !is.na(design$sampling_interval) &&
        !interval_comparable) {
        caveats <- c(caveats, sprintf(paste0(
            "The sampling interval is in '%s', not in minutes (the benchmark ",
            "time scale); it is not compared."), design$time_unit))
    }
    if (regime == "PSEUDO_SHUTOFF") {
        return(list(
            design = design, match_type = "not_benchmarked",
            matches = bench[0, ], differences = NULL, summary = NULL,
            statements = paste(
                "Pseudo-shutoff (residual transcription) designs are not part",
                "of the manuscript's factorial benchmark packaged here, so no",
                "benchmark configuration is reported. The manuscript examined",
                "residual transcription in a separate sensitivity analysis;",
                "pseudo-shutoff data are fitted as if transcription stopped",
                "completely at t_star."),
            caveats = caveats))
    }
    cand <- bench[bench$regime == regime, , drop = FALSE]
    if (!is.null(platform)) cand <- cand[cand$platform == platform, ]
    if (!is.null(noise_level)) cand <- cand[cand$noise_level == noise_level, ]
    user_si <- if (interval_comparable) design$sampling_interval else NA_real_
    exact <- cand[cand$n_time_points == design$n_time_points &
                  cand$n_replicates == design$n_replicates &
                  (regime == "NONE" | (!is.na(user_si) &
                                       cand$sampling_interval %in% user_si)), ,
                  drop = FALSE]
    differences <- NULL
    if (nrow(exact)) {
        matches <- exact
        match_type <- "exact"
    } else {
        dims <- c(if (regime == "SHUTOFF") "sampling_interval",
                  "n_time_points", "n_replicates")
        user_vals <- c(sampling_interval = user_si,
                       n_time_points = design$n_time_points,
                       n_replicates = design$n_replicates)
        matches <- .nearest_designs(cand, dims, user_vals)
        differences <- do.call(rbind, lapply(dims, function(d) {
            lv <- sort(unique(matches[[d]]))
            data.frame(dimension = d, user_value = unname(user_vals[[d]]),
                       benchmark_levels = paste(format(lv, trim = TRUE),
                                                collapse = ", "),
                       stringsAsFactors = FALSE)
        }))
        rownames(differences) <- NULL
        match_type <- "nearest"
    }
    rownames(matches) <- NULL
    smry <- list(
        n_configurations = nrow(matches),
        type1_005_range = range(matches$type1_005),
        wilson_low_range = range(matches$type1_005_wilson_low),
        wilson_high_range = range(matches$type1_005_wilson_high),
        n_criterion_met = sum(matches$ci_contains_005),
        n_practical_band = sum(matches$practical_near_nominal),
        power_005_range = range(matches$power_005)
    )
    scope <- sprintf("%s platform(s), %s noise level(s)",
                     if (is.null(platform)) "all" else platform,
                     if (is.null(noise_level)) "all" else noise_level)
    body <- sprintf(paste0(
        "had empirical Type-I error at alpha = 0.05 of %s (Wilson 95%% ",
        "intervals from %s to %s); the manuscript's operational criterion ",
        "(Wilson 95%% interval containing 0.05) was met in %d of %d of these ",
        "benchmark configurations; power at alpha = 0.05 was %s."),
        .fmt_range(matches$type1_005), .fmt(smry$wilson_low_range[1], 3),
        .fmt(smry$wilson_high_range[2], 3), smry$n_criterion_met,
        smry$n_configurations, .fmt_range(matches$power_005))
    statements <- if (match_type == "exact") {
        sprintf(paste0("In the manuscript benchmark, the %d configuration(s) ",
                       "matching this design (%s) %s"),
                nrow(matches), scope, body)
    } else {
        diff_dims <- differences$dimension[
            is.na(differences$user_value) |
            differences$benchmark_levels !=
                format(differences$user_value, trim = TRUE)]
        sprintf(paste0(
            "No configuration of the manuscript benchmark matches this design ",
            "exactly. The nearest evaluated benchmark designs (not equivalent ",
            "designs; %d configuration(s), %s; differing in: %s) %s"),
            nrow(matches), scope,
            if (length(diff_dims)) toString(diff_dims) else "none", body)
    }
    if (regime == "NONE") {
        all_none <- bench[bench$regime == "NONE", ]
        statements <- c(statements, sprintf(paste0(
            "In the manuscript benchmark, continuous-transcription (NONE) ",
            "designs were strongly anti-conservative across all tested ",
            "configurations: the operational criterion was met in %d of %d ",
            "NONE configurations (median empirical Type-I error %s at ",
            "alpha = 0.05)."), sum(all_none$ci_contains_005), nrow(all_none),
            .fmt(stats::median(all_none$type1_005), 3)))
    }
    list(design = design, match_type = match_type, matches = matches,
         differences = differences, summary = smry, statements = statements,
         caveats = caveats)
}

.domain_caveats <- function(design, regime, platform, noise_level) {
    out <- c(
        paste("Benchmark results describe simulated data under the",
              "manuscript's benchmark assumptions (parameter ranges, rates",
              "per minute, simulated assay models, destructive sampling);",
              "they are not a calibration guarantee for any dataset."),
        paste("Matching compares design descriptors only; kinetic rates and",
              "noise of real data may differ from the benchmark.")
    )
    if (is.null(platform) || is.null(noise_level)) {
        out <- c(out, paste("Platform and/or noise level not supplied: the",
                            "report covers all benchmark platforms and noise",
                            "levels. They are never inferred from the data."))
    }
    if (regime == "SHUTOFF") {
        if (is.na(design$sampling_interval)) {
            out <- c(out, paste("The sampling interval is irregular or not",
                                "supplied; the benchmark evaluated regular",
                                "intervals only, so it is not compared."))
        }
        if (!is.na(design$n_before_t_star) && design$n_before_t_star != 1L) {
            out <- c(out, sprintf(paste0(
                "Benchmark SHUTOFF designs had one sample before t_star (at ",
                "t_star - interval) and one at t_star; this design has %d ",
                "sampling time(s) before t_star."), design$n_before_t_star))
        }
    }
    if (regime == "NONE") {
        out <- c(out, paste("Benchmark NONE designs do not depend on the",
                            "sampling interval; it is not compared."))
    }
    out
}

#' @export
print.postexport_domain_check <- function(x, ...) {
    cat("<postexport_domain_check> diagnostic comparison with the manuscript",
        "benchmark\n")
    for (i in seq_along(x$checks)) {
        ck <- x$checks[[i]]
        d <- ck$design
        cat(sprintf(paste0("\nDesign %d: regime %s; %d time points; %d ",
                           "replicates; interval %s%s\n"),
                    i, x$designs$regime[i], d$n_time_points, d$n_replicates,
                    .fmt(d$sampling_interval),
                    if (!is.na(d$events)) paste0("; events: ",
                                                 substr(d$events, 1, 60))
                    else ""))
        cat("  Match:", ck$match_type, "\n")
        for (st in ck$statements) cat(strwrap(st, width = 76, prefix = "  "),
                                      sep = "\n")
        cat("  Caveats:", length(ck$caveats), "(see summary())\n")
    }
    invisible(x)
}

#' @export
summary.postexport_domain_check <- function(object, ...) {
    structure(list(object = object), class = "summary.postexport_domain_check")
}

#' @export
print.summary.postexport_domain_check <- function(x, ...) {
    o <- x$object
    print(o)
    cols <- c("platform", "noise_level", "n_time_points", "n_replicates",
              "sampling_interval", "type1_005", "type1_005_wilson_low",
              "type1_005_wilson_high", "ci_contains_005", "power_005",
              "differs_in")
    for (i in seq_along(o$checks)) {
        ck <- o$checks[[i]]
        cat(sprintf("\nDesign %d - benchmark configurations (%s):\n", i,
                    ck$match_type))
        if (nrow(ck$matches)) {
            show <- ck$matches[, intersect(cols, names(ck$matches))]
            print(utils::head(show, 24L), row.names = FALSE, digits = 3)
            if (nrow(ck$matches) > 24L) {
                cat("  ...", nrow(ck$matches) - 24L, "more\n")
            }
        } else {
            cat("  none\n")
        }
        if (!is.null(ck$differences)) {
            cat("Nearest-design dimensions:\n")
            print(ck$differences, row.names = FALSE)
        }
        cat("Caveats:\n")
        cat(paste0("  - ", ck$caveats), sep = "\n")
    }
    cat("\nBenchmark provenance:", o$provenance$frozen_tag,
        substr(o$provenance$frozen_commit, 1, 12), "-",
        o$provenance$summary_file, "\n")
    cat(strwrap(o$provenance$criterion, width = 78), sep = "\n")
    invisible(x)
}
