# DIAGNOSTIC (one fresh process): text/grob record + PNG render of figure 5.
# Usage: Rscript text_probe_one.R <out_prefix>
out <- commandArgs(TRUE)[1]
suppressPackageStartupMessages(library(postexportKinetics))
data(postexport_example)
x <- postexport_data(postexport_example, time_unit = "min")
dom <- check_operational_domain(x, regime = "SHUTOFF", t_star = 332,
                                platform = "rnaseq", noise_level = "very_low")
g <- plot(dom)
rec <- character()
add <- function(...) rec <<- c(rec, paste0(...))
fmt <- function(v) paste(format(v, digits = 17), collapse = ",")
# labels and theme text elements (resolved)
for (n in names(g$labels)) add("label ", n, " = ", paste(format(g$labels[[n]]), collapse = " "))
b <- ggplot2::ggplot_build(g)
th <- tryCatch(ggplot2:::plot_theme(b$plot), error = function(e) NULL)
for (el in c("text", "plot.title", "plot.subtitle", "plot.caption", "axis.title.x",
             "axis.title.y", "axis.text.x", "axis.text.y", "legend.text", "legend.title",
             "strip.text")) {
    e <- tryCatch(ggplot2::calc_element(el, th), error = function(e) NULL)
    if (!is.null(e) && !inherits(e, "element_blank"))
        add("theme ", el, ": family=", e$family, " face=", e$face, " size=", fmt(e$size),
            " lineheight=", fmt(e$lineheight), " colour=", e$colour, " hjust=", fmt(e$hjust),
            " vjust=", fmt(e$vjust), " angle=", fmt(e$angle))
}
# resolved scales (breaks and labels)
pp <- b$layout$panel_params[[1]]
for (ax in c("x", "y")) {
    sc <- pp[[ax]]
    if (!is.null(sc)) add("scale ", ax, ": breaks=", fmt(sc$get_breaks()),
                          " labels=", paste(sc$get_labels(), collapse = "|"),
                          " range=", fmt(sc$continuous_range %||% sc$dimension()))
}
# built layer data (all layers)
for (i in seq_along(b$data)) {
    d <- b$data[[i]]
    add("layer ", i, " ", class(g$layers[[i]]$geom)[1], " n=", nrow(d))
    for (cn in names(d)) add("  ", cn, " = ", if (is.numeric(d[[cn]])) fmt(d[[cn]]) else paste(as.character(d[[cn]]), collapse = "|"))
}
# grob conversion and text grobs
gt <- ggplot2::ggplotGrob(g)
add("gtable layout: ", paste(apply(gt$layout[, c("name", "t", "l", "b", "r")], 1, paste, collapse = ":"), collapse = " "))
add("gtable widths: ", paste(as.character(gt$widths), collapse = " "))
add("gtable heights: ", paste(as.character(gt$heights), collapse = " "))
texts <- list()
walk <- function(gr, path) {
    if (inherits(gr, "text")) texts[[length(texts) + 1L]] <<- list(path = path, g = gr)
    kids <- c(if (inherits(gr, "gTree")) gr$children, if (inherits(gr, "gtable")) gr$grobs)
    for (k in seq_along(kids)) walk(kids[[k]], paste0(path, "/", kids[[k]]$name %||% k))
}
walk(gt, "gt")
# render on the same device used for the vignette figure; measure text first
png_file <- paste0(out, ".png")
png(png_file, width = 504, height = 360)
for (t in texts) {
    gr <- t$g; gp <- gr$gp
    w <- tryCatch(grid::convertWidth(grid::grobWidth(gr), "inches", valueOnly = TRUE), error = function(e) NA)
    h <- tryCatch(grid::convertHeight(grid::grobHeight(gr), "inches", valueOnly = TRUE), error = function(e) NA)
    add("text ", t$path, ": label=", paste(as.character(gr$label), collapse = "|"),
        " x=", paste(as.character(gr$x), collapse = ","), " y=", paste(as.character(gr$y), collapse = ","),
        " just=", paste(as.character(gr$just), collapse = ","), " hjust=", fmt(gr$hjust), " vjust=", fmt(gr$vjust),
        " rot=", fmt(gr$rot), " family=", gp$fontfamily %||% "", " face=", fmt(gp$fontface %||% NA),
        " fontsize=", fmt(gp$fontsize %||% NA), " lineheight=", fmt(gp$lineheight %||% NA),
        " col=", gp$col %||% "", " measured_w_in=", fmt(w), " measured_h_in=", fmt(h))
}
grid::grid.newpage(); grid::grid.draw(gt); invisible(dev.off())
writeLines(rec, paste0(out, ".txt"))
env <- c(capture.output(sessionInfo()), paste("locale:", Sys.getlocale()),
         paste("capabilities:", paste(names(capabilities()), capabilities(), collapse = " ")),
         paste("bitmapType:", getOption("bitmapType")),
         if (nzchar(Sys.which("fc-match"))) paste("fc-match sans:", system2("fc-match", "sans", stdout = TRUE)))
writeLines(env, paste0(out, ".env.txt"))
