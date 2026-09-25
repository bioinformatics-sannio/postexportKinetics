# =============================================================================
# Clean-installation smoke test of a built package tarball (release gate).
#
# Usage: Rscript tools/ci/smoke_install.R <postexportKinetics_x.y.z.tar.gz>
#
# Installs the tarball into a new, empty temporary library and runs a
# workflow in a fresh R process (--vanilla), asserting that the package is
# loaded from that library: library(); data(postexport_example); a minimal
# fit; a small bootstrap test (B = 49, for speed only); a simulation; an
# operational-domain check; citation(); vignette availability. Dependencies
# come from the existing libraries. Exit status 1 on any failure.
# =============================================================================

tarball <- normalizePath(commandArgs(trailingOnly = TRUE)[1], mustWork = TRUE)
lib <- tempfile("cleanlib-")
dir.create(lib)
r_bin <- file.path(R.home("bin"), "R")
out <- system2(r_bin, c("CMD", "INSTALL", paste0("--library=", shQuote(lib)),
                        shQuote(tarball)), stdout = TRUE, stderr = TRUE)
if (!is.null(attr(out, "status"))) {
    cat(out, sep = "\n")
    stop("Installation from the tarball failed.")
}
stopifnot(identical(list.files(lib), "postexportKinetics"))
cat("Installed", basename(tarball), "into empty library", lib, "\n")

script <- tempfile(fileext = ".R")
writeLines(c(
    sprintf("lib <- %s", deparse(normalizePath(lib))),
    sprintf(".libPaths(c(lib, %s))", deparse(.libPaths())),
    "library(postexportKinetics)",
    "stopifnot(identical(normalizePath(find.package('postexportKinetics')),",
    "                    normalizePath(file.path(lib, 'postexportKinetics'))))",
    "cat('loaded from:', find.package('postexportKinetics'), 'version',",
    "    as.character(packageVersion('postexportKinetics')), '\\n')",
    "data(postexport_example)",
    "x <- postexport_data(postexport_example, time_unit = 'min')",
    "sel <- postexport_example$event == 'alt_3'",
    "one <- postexport_data(postexport_example[sel, ], time_unit = 'min')",
    "fit <- fit_postexport_model(one, t_star = 332)",
    "stopifnot(identical(fit$status, 'ok'))",
    "cat('fit: sigma_c', signif(fit$estimates$sigma_c, 6), 'IR', signif(fit$fit$IR, 6), '\\n')",
    "res <- test_postexport_conversion(one, t_star = 332,",
    "    control = postexport_control(B = 49, seed = 1))",
    "stopifnot(identical(res$status, 'ok'), is.finite(res$inference$p_value))",
    "cat('bootstrap test (B = 49): p', res$inference$p_value, '\\n')",
    "sim <- simulate_postexport_kinetics(",
    "    c(R = 100, tau = 0.03, tau_s = 0.015, sigma_c = 0.1, sigma_n = 0.1,",
    "      alpha = 0.2, alpha_s = 0.08),",
    "    times = c(90, 100, 110, 120, 130), onset_time = 0, t_star = 100,",
    "    regime = 'SHUTOFF', time_unit = 'min', n_replicates = 3,",
    "    param_cv = 0.05, noise = list(platform = 'rnaseq', level = 'low'), seed = 1)",
    "stopifnot(nrow(sim$observed) == 15L)",
    "cat('simulation: observed rows', nrow(sim$observed), '\\n')",
    "dom <- check_operational_domain(x, regime = 'SHUTOFF', t_star = 332,",
    "    platform = 'rnaseq', noise_level = 'very_low')",
    "stopifnot(identical(dom$designs$match_type, 'exact'))",
    "cat('domain: match', dom$designs$match_type, '\\n')",
    "print(citation('postexportKinetics'), style = 'text')",
    "v <- vignette(package = 'postexportKinetics')$results",
    "stopifnot('postexportKinetics' %in% v[, 'Item'])",
    "stopifnot(nzchar(system.file('doc', 'postexportKinetics.html', package = 'postexportKinetics')))",
    "cat('vignette available:', v[, 'Item'], '\\n')",
    "cat('SMOKE TEST PASSED\\n')"
), script)
res <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script)))
if (res != 0L) stop("Smoke test failed.")
