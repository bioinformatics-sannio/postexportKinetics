# Regression fixtures

These fixtures are small, derived regression references for the package's
test suite. They are shipped with the package so that `R CMD check` runs the
scientific regression tests.

**Provenance.** They were generated only by `tools/frozen/make_fixtures*.R`
(in the source repository, not in the package) from the frozen manuscript
implementation:

- repository `bioinformatics-sannio/postexport-kinetics`;
- tag `manuscript-revision-v1.0`, commit
  `65c3b7368fb7686bfde3dab857f98c393bb534c5`;
- archived at doi:10.5281/zenodo.22944109.

Each file carries a `provenance` element: tag, commit, the MD5 of the frozen
source files (named by their path within the tagged repository), the
generating script, the date, and the R, LAPACK/BLAS and package versions.

The fixtures are never edited by hand. The only post-generation change is the
approved normalisation of the MD5 names from machine-specific absolute paths
to repository-relative paths (`tools/frozen/normalise_fixture_provenance.R`),
which leaves every other element bit-for-bit identical.

| Files | Purpose |
|---|---|
| `fx_matrix`, `fx_covariance`, `fx_interval_balance`, `fx_fit`, `fx_crank_nicolson`, `fx_bootstrap`, `fx_test_sigma_nested` | inputs and frozen outputs of the ported numerical core |
| `fx_orchestrator` | frozen orchestrator outputs for the public API regression |
| `fx_ode`, `fx_noise`, `fx_generate`, `fx_simulation` | frozen simulator and assay-noise outputs |
| `fx_source`, `fx_source_orchestrator`, `fx_source_simulation` | frozen function source, used by the verbatim-port tests to check that the ported code equals the tagged code, apart from the documented mechanical edits. The source is from the same authors, under the same MIT license. |
| `fx_real_mesc` | 28 mESC events × 15 samples: a small derived subset of the public GEO series GSE256335, extracted by the frozen conversion. It carries the deposited manuscript audit values for `sigma_c` and IR (deterministic fit quantities only). |

No frozen scripts, figures, manuscript files or raw benchmark outputs are
shipped.

The regression levels (strict same-platform vs scale-aware cross-platform)
are described in `tools/frozen/README.md` in the source repository.
