# =============================================================================
# Maintainer wrapper: regenerate the example data shipped with the package.
#
# Run from the package root with the package installed:
#   Rscript data-raw/postexport_example.R
#
# The generation code, the design and the provenance documentation live in
# inst/scripts/generate_postexport_example.R. That script is distributed with
# the package, as Bioconductor prefers. This wrapper only writes its output
# into the package source tree:
#   data/postexport_example.rda, data/postexport_example_truth.rda and
#   inst/extdata/postexport_example_long.csv.
# =============================================================================

suppressPackageStartupMessages(library(postexportKinetics))
source(file.path("inst", "scripts", "generate_postexport_example.R"))
write_postexport_example(".")
invisible(postexport_data(get(load("data/postexport_example.rda")),
                          time_unit = "min"))
