# Assisted-by: Claude Code (Anthropic)
# plot() methods: return ggplot objects, never modify their input, show the
# required elements and use cautious wording. Image snapshots are not used.

fx <- read_fixture("fx_orchestrator")

plot_text <- function(g) {
    b <- ggplot2::ggplot_build(g)
    labs <- unlist(g$labels)
    facets <- tryCatch(unlist(b$layout$layout[, "state"]), error = function(e) NULL)
    paste(c(labs, as.character(facets)), collapse = "\n")
}

forbidden <- "cytoplasmic splicing detected|your dataset is calibrated|likelihood-ratio test|calibration of your dataset"

two_event_set <- function() {
    a1 <- fx$cases[["orchestrator/alt_shutoff_gauss/default"]]$input$args
    a2 <- fx$cases[["orchestrator/null_shutoff_gauss/default"]]$input$args
    tab <- rbind(cbind(event = "alt", a1$tsampled_data),
                 cbind(event = "null", a2$tsampled_data))
    x <- postexport_data(tab, time_unit = "min")
    test_postexport_conversion(
        x, t_star = 300,
        control = postexport_control(B = 49, seed = c(alt = 1L, null = 2L)))
}

check_plot <- function(obj, ...) {
    before <- obj
    g <- plot(obj, ...)
    expect_s3_class(g, "ggplot")
    expect_no_error(ggplot2::ggplot_build(g))
    expect_identical(obj, before)
    txt <- plot_text(g)
    expect_false(grepl(forbidden, txt, ignore.case = TRUE))
    invisible(g)
}

test_that("fit and test plots show the four states, both models and t_star", {
    set <- two_event_set()
    g <- check_plot(set$results$alt)
    expect_identical(g$labels$title, "Post-export kinetic model fit")
    b <- ggplot2::ggplot_build(g)
    expect_setequal(as.character(b$layout$layout$state),
                    unname(.STATE_LABELS))
    layer_geoms <- vapply(g$layers, function(l) class(l$geom)[1], "")
    expect_true(all(c("GeomPoint", "GeomLine", "GeomRug", "GeomVline") %in%
                        layer_geoms))
    vl <- g$layers[[which(layer_geoms == "GeomVline")]]
    expect_identical(vl$data$xintercept, 300)
    lines <- b$data[[which(layer_geoms == "GeomLine")]]
    expect_identical(length(unique(lines$colour)), 2L)
    expect_match(g$labels$caption, "display reconstructions")
    expect_match(g$labels$caption, "first sampled time")
    expect_match(g$labels$caption, "interval-balance / Crank-Nicolson")
    check_plot(set$results$alt, type = "bootstrap")
    gb <- plot(set$results$alt, type = "bootstrap")
    expect_match(gb$labels$subtitle, "bootstrap p =")
    expect_match(gb$labels$subtitle, "failure fraction")
    expect_error(plot(set$results$alt, type = "volcano"))
    x <- postexport_data(cbind(event = "e", fx$cases[[
        "orchestrator/alt_shutoff_gauss/default"]]$input$args$tsampled_data),
        time_unit = "min")
    check_plot(fit_postexport_model(x, t_star = 300))
    check_plot(fit_postexport_model(x, t_star = 300), show_means = FALSE)
})

test_that("set plots are descriptive and require q where needed", {
    set <- two_event_set()
    for (ty in c("status", "boundary", "sigma_IR")) check_plot(set, type = ty)
    expect_error(plot(set, type = "sigma_q"), "adjust_postexport_pvalues")
    adj <- adjust_postexport_pvalues(set)
    for (ty in c("sigma_q", "IR_q", "score")) check_plot(adj, type = ty)
    g <- plot(adj, type = "sigma_q")
    expect_match(g$labels$x, "effect-size estimate")
    expect_match(g$labels$y, "-log10\\(q\\)")
    expect_match(plot(adj, type = "score")$labels$caption, "not inferential")
    fs <- fit_postexport_model(postexport_data(
        do.call(rbind, lapply(set$results, function(r) {
            cbind(event = r$event, r$data)
        })), time_unit = "min"), t_star = 300)
    for (ty in c("status", "boundary", "sigma_IR")) check_plot(fs, type = ty)
})

test_that("simulation plots mark onset and t_star without smoothing", {
    p <- c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,
           alpha = 0.2, alpha_s = 0.08)
    sim <- simulate_postexport_kinetics(
        p, times = c(90, 100, 120, 160), onset_time = 20, t_star = 100,
        regime = "SHUTOFF", time_unit = "min", n_replicates = 2,
        param_cv = 0.05, noise = list(platform = "gaussian", level = "low"),
        seed = 1)
    g <- check_plot(sim)
    geoms <- vapply(g$layers, function(l) class(l$geom)[1], "")
    vl <- g$layers[[which(geoms == "GeomVline")]]$data
    expect_identical(vl$time[vl$marker == "transcriptional onset"], 20)
    expect_identical(vl$time[vl$marker == "intervention t_star"], 100)
    expect_false(any(c("GeomSmooth") %in% geoms))
    expect_match(g$labels$caption, "no smoothing")
    none <- simulate_postexport_kinetics(
        p, times = c(10, 50), onset_time = 0, t_star = NULL, regime = "NONE",
        time_unit = "min")
    g2 <- check_plot(none)
    vl2 <- g2$layers[[which(vapply(g2$layers, function(l)
        class(l$geom)[1], "") == "GeomVline")]]$data
    expect_identical(vl2$marker, "transcriptional onset")
})

test_that("operational-domain plots describe benchmark designs only", {
    ex <- check_operational_domain(regime = "SHUTOFF", platform = "rnaseq",
                                   noise_level = "low", n_time_points = 5,
                                   n_replicates = 3, sampling_interval = 10,
                                   time_unit = "min")
    g <- check_plot(ex)
    expect_identical(g$labels$title, "Manuscript benchmark designs")
    expect_match(g$labels$caption, "not a calibration guarantee")
    b <- ggplot2::ggplot_build(g)
    expect_true(any(vapply(b$data, function(d) any(d$xintercept == 0.05,
                                                    na.rm = TRUE), TRUE)))
    expect_identical(unique(g$data$match_type), "exact match")
    nr <- check_operational_domain(regime = "SHUTOFF", n_time_points = 7,
                                   n_replicates = 4, sampling_interval = 15,
                                   time_unit = "min")
    gn <- check_plot(nr)
    expect_identical(unique(gn$data$match_type), "nearest evaluated design")
    ps <- check_operational_domain(regime = "PSEUDO_SHUTOFF",
                                   n_time_points = 5, n_replicates = 3)
    check_plot(ps)
})

test_that("operational-domain legend order is explicit and deterministic", {
    ex <- check_operational_domain(regime = "SHUTOFF", platform = "rnaseq",
                                   noise_level = "low", n_time_points = 5,
                                   n_replicates = 3, sampling_interval = 10,
                                   time_unit = "min")
    before <- ex
    legend_order <- function(g) {
        grDevices::pdf(NULL)
        on.exit(grDevices::dev.off())
        gt <- ggplot2::ggplotGrob(g)
        box <- gt$grobs[[grep("guide-box-bottom", gt$layout$name)]]
        idx <- which(box$layout$name == "guides")
        idx <- idx[order(box$layout$l[idx], box$layout$t[idx])]
        labels_of <- function(gr) {
            out <- character()
            walk <- function(z) {
                if (inherits(z, "text")) out <<- c(out, as.character(z$label))
                for (k in c(if (inherits(z, "gTree")) z$children,
                            if (inherits(z, "gtable")) z$grobs)) walk(k)
            }
            walk(gr)
            out
        }
        lapply(box$grobs[idx], labels_of)
    }
    g <- plot(ex)
    expect_identical(ex, before)
    # Explicit orders: colour (match type) first, shape (criterion) second.
    expect_identical(g$scales$get_scales("colour")$guide$params$order, 1L)
    expect_identical(g$scales$get_scales("shape")$guide$params$order, 2L)
    ord <- legend_order(g)
    expect_length(ord, 2L)
    expect_true("exact match" %in% ord[[1]])
    expect_true("Wilson interval contains 0.05" %in% ord[[2]])
    # Repeated construction gives the same order.
    for (k in 1:3) expect_identical(legend_order(plot(ex)), ord)
    # Labels and plot data are unchanged by the explicit ordering.
    expect_identical(g$labels$title, "Manuscript benchmark designs")
    expect_identical(g$labels$x, "empirical Type-I error (benchmark)")
    expect_null(g$scales$get_scales("colour")$name)
    expect_null(g$scales$get_scales("shape")$name)
    expect_identical(names(g$data), c("design", "match_type", "configuration",
                                      "type1", "low", "high", "criterion"))
    expect_identical(unique(g$data$match_type), "exact match")
    b <- ggplot2::ggplot_build(g)
    pts <- b$data[[which(vapply(g$layers, function(l)
        class(l$geom)[1], "") == "GeomPoint")]]
    expect_identical(pts$x, g$data$type1)
    expect_identical(unique(pts$shape), 16)
})
