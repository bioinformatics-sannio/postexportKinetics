# DIAGNOSTIC: render the vignette's domain plot (figure #5) repeatedly, each
# in a FRESH R process, under several PNG device configurations, and count
# distinct pixel outputs per configuration. Prints annotations.
cfgs <- list(
    default         = "list()",
    nimbus_sans     = "list(family = 'Nimbus Sans')",
    tex_gyre_heros  = "list(family = 'TeX Gyre Heros')",
    cairo_png       = "list(type = 'cairo-png')",
    cairo_nimbus    = "list(type = 'cairo', family = 'Nimbus Sans')"
)
n <- as.integer(commandArgs(TRUE)[1]); if (is.na(n)) n <- 15L
out <- tempfile("probe-"); dir.create(out)
script <- file.path(out, "one.R")
writeLines(c(
    "a <- commandArgs(TRUE); args <- eval(parse(text = a[2]))",
    "suppressPackageStartupMessages(library(postexportKinetics))",
    "data(postexport_example)",
    "x <- postexport_data(postexport_example, time_unit = 'min')",
    "dom <- check_operational_domain(x, regime = 'SHUTOFF', t_star = 332, platform = 'rnaseq', noise_level = 'very_low')",
    "do.call(png, c(list(filename = a[1], width = 504, height = 360), args))",
    "print(plot(dom)); invisible(dev.off())"), script)
rs <- file.path(R.home("bin"), "Rscript")
for (nm in names(cfgs)) {
    hashes <- character()
    for (k in seq_len(n)) {
        f <- file.path(out, sprintf("%s_%02d.png", nm, k))
        system2(rs, c(script, shQuote(f), shQuote(cfgs[[nm]])), stdout = FALSE, stderr = FALSE)
        hashes[k] <- if (file.exists(f)) {
            img <- png::readPNG(f); paste(dim(img), collapse = "x") |> paste(digest_raw <- sum(img * seq_along(img)))
        } else "missing"
    }
    tab <- table(hashes)
    cat(sprintf("::notice title=Render probe %s::%d renders; %d distinct pixel output(s); counts: %s\n",
                nm, n, length(tab), paste(as.integer(tab), collapse = ",")))
}
