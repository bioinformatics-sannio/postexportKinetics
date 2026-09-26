# DIAGNOSTIC driver: n fresh-process runs of text_probe_one.R; classify runs
# by rendered PNG (decoded pixels) and compare the text/grob records.
n <- as.integer(commandArgs(TRUE)[1]); if (is.na(n)) n <- 15L
dir <- tempfile("textprobe-"); dir.create(dir)
rs <- file.path(R.home("bin"), "Rscript")
one <- file.path("tools", "ci", "text_probe_one.R")
res <- data.frame(run = seq_len(n), png_md5 = NA_character_, pix = NA_character_,
                  txt_md5 = NA_character_, env_md5 = NA_character_, stringsAsFactors = FALSE)
for (k in seq_len(n)) {
    pre <- file.path(dir, sprintf("run%02d", k))
    system2(rs, c(one, shQuote(pre)), stdout = FALSE, stderr = FALSE)
    img <- png::readPNG(paste0(pre, ".png"))
    res$png_md5[k] <- unname(tools::md5sum(paste0(pre, ".png")))
    res$pix[k] <- paste(dim(img), collapse = "x") |> paste(format(sum(img * seq_along(img)), digits = 17))
    res$txt_md5[k] <- unname(tools::md5sum(paste0(pre, ".txt")))
    res$env_md5[k] <- unname(tools::md5sum(paste0(pre, ".env.txt")))
}
res$png_class <- match(res$pix, unique(res$pix))
print(res[, c("run", "png_class", "png_md5", "txt_md5", "env_md5")], row.names = FALSE)
note <- function(t, m) cat(sprintf("::notice title=%s::%s\n", t, gsub("\n", "%0A", m)))
cls <- table(res$png_class)
note("Text probe PNG classes", sprintf("%d runs; %d PNG class(es); counts %s", n, length(cls), paste(as.integer(cls), collapse = ",")))
note("Text probe text/grob records", sprintf("%d distinct text/grob record(s); %d distinct environment record(s)",
                                             length(unique(res$txt_md5)), length(unique(res$env_md5))))
by_class <- tapply(res$txt_md5, res$png_class, function(v) paste(unique(v), collapse = ","))
note("Text probe records by PNG class", paste(names(by_class), by_class, sep = ": ", collapse = " ; "))
if (length(cls) >= 2) {
    r1 <- readLines(file.path(dir, sprintf("run%02d.txt", which(res$png_class == 1)[1])))
    r2 <- readLines(file.path(dir, sprintf("run%02d.txt", which(res$png_class == 2)[1])))
    d <- setdiff(union(r1, r2), intersect(r1, r2))
    if (length(d)) {
        note("Text probe verdict", "A: text/grob records DIFFER between the PNG classes")
        dd <- c(paste("class1:", setdiff(r1, r2)), paste("class2:", setdiff(r2, r1)))
        note("Text probe differing lines", paste(substr(utils::head(dd, 12), 1, 300), collapse = "\n"))
    } else {
        note("Text probe verdict", "B: text/grob records IDENTICAL while PNG pixels differ (rasterisation)")
    }
    e1 <- readLines(file.path(dir, sprintf("run%02d.env.txt", which(res$png_class == 1)[1])))
    e2 <- readLines(file.path(dir, sprintf("run%02d.env.txt", which(res$png_class == 2)[1])))
    note("Text probe environment", if (identical(e1, e2)) "environment records identical across PNG classes" else paste(setdiff(union(e1, e2), intersect(e1, e2)), collapse = "\n"))
} else note("Text probe verdict", "only one PNG class observed in this run")
cat(readLines(file.path(dir, "run01.env.txt"))[1:12], sep = "\n")
