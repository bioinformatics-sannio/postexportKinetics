# DIAGNOSTIC: report fonts and PNG devices available to R (annotations).
label <- commandArgs(TRUE)[1]
note <- function(title, x) cat(sprintf("::notice title=%s (%s)::%s\n", title, label,
                                      gsub("\n", "%0A", paste(x, collapse = " | "))))
note("R", paste(R.version.string, R.version$platform))
caps <- capabilities()
note("capabilities", paste(names(caps), caps, sep = "=", collapse = " "))
note("default bitmapType", getOption("bitmapType"))
fc <- Sys.which("fc-list")
if (nzchar(fc)) {
    fam <- sort(unique(trimws(unlist(strsplit(system2(fc, c(":", "family"), stdout = TRUE), ",")))))
    note("fc-list families", paste(length(fam), "families; DejaVu Sans present:",
                                   "DejaVu Sans" %in% fam, "; first:", paste(head(fam, 25), collapse = ", ")))
    for (q in c("sans", "Helvetica", "DejaVu Sans", "Arial"))
        note(paste("fc-match", q), system2(Sys.which("fc-match"), shQuote(q), stdout = TRUE))
} else note("fc-list", "not available")
dirs <- c("/usr/share/fonts", "/Library/Fonts", "/System/Library/Fonts",
          file.path(Sys.getenv("WINDIR", "C:/Windows"), "Fonts"),
          path.expand("~/Library/Fonts"))
dv <- unlist(lapply(dirs[dir.exists(dirs)], function(d)
    list.files(d, pattern = "DejaVuSans", recursive = TRUE, full.names = TRUE)))
note("DejaVuSans font files", if (length(dv)) head(dv, 5) else "none")
test_type <- function(type) {
    f <- tempfile(fileext = ".png")
    r <- tryCatch({ png(f, width = 600, height = 400, type = type)
                    plot(1, main = "text"); dev.off(); file.exists(f) && file.size(f) > 0 },
                  error = function(e) paste("error:", conditionMessage(e)),
                  warning = function(w) paste("warning:", conditionMessage(w)))
    paste0(type, "=", r)
}
types <- c("cairo", "cairo-png", "Xlib", "quartz", "windows")
note("png types", vapply(types, test_type, ""))
f2 <- tempfile(fileext = ".png")
r2 <- tryCatch({ png(f2, width = 600, height = 400, family = "DejaVu Sans")
                 plot(1, main = "text"); dev.off(); "ok" },
               error = function(e) paste("error:", conditionMessage(e)),
               warning = function(w) paste("warning:", conditionMessage(w)))
note("png(family = 'DejaVu Sans') default type", r2)
