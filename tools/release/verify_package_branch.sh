#!/bin/sh
# =============================================================================
# Verify the package-only branch against its development source commit.
#
# Usage (from the repository root, on the development branch):
#   sh tools/release/verify_package_branch.sh [branch] [workdir]
#
#   branch defaults to "devel"; workdir defaults to a new temporary
#   directory. The source commit X is read from the "Source-Commit:" trailer
#   of the branch tip.
#
# Checks (exit status 1 on any failure):
#   A. the package-only export rebuilt from X is exactly the tree at the
#      branch tip;
#   B. `R CMD build` of X and of the branch tip give the same
#      package-distribution content (same file list, identical files); only
#      the R-generated "Packaged:" line of DESCRIPTION may differ. Controlled
#      exception (tools/release/compare_built_packages.R):
#      VIGNETTE_PNG_ENCODING_ONLY, i.e. the only differing file is the
#      rendered vignette HTML, identical outside its embedded PNG payloads,
#      with every decoded image pixel-identical;
#   C. tarball hygiene (tools/ci/inspect_tarball.R) passes on the branch
#      tarball;
#   D. BiocCheck::BiocCheckGitClone() on a clone of the branch reports no
#      ERROR or WARNING;
#   E. DESCRIPTION version, CITATION.cff, inst/CITATION and NAMESPACE
#      (public API) are identical between X and the branch.
# Development-only files of X are not compared.
# =============================================================================
set -eu

BRANCH="${1:-devel}"
WORK="${2:-$(mktemp -d "${TMPDIR:-/tmp}/verify-pkg-branch.XXXXXX")}"
ALLOW="tools/release/package_allowlist.txt"
ROOT=$(git rev-parse --show-toplevel)
fail=0
pass() { echo "[PASS] $*"; }
bad()  { echo "[FAIL] $*"; fail=1; }

TIP=$(git rev-parse --verify "refs/heads/$BRANCH^{commit}" 2>/dev/null || \
      git rev-parse --verify "refs/remotes/origin/$BRANCH^{commit}")
X=$(git log -1 --format=%B "$TIP" | sed -n 's/^Source-Commit: \([0-9a-f]\{40\}\)$/\1/p' | tail -1)
[ -n "$X" ] || { echo "[FAIL] $BRANCH tip $TIP has no Source-Commit trailer"; exit 1; }
git cat-file -e "$X^{commit}" || { echo "[FAIL] source commit $X not found"; exit 1; }
echo "branch $BRANCH tip $TIP; Source-Commit $X"
mkdir -p "$WORK"

# A. exact tree
. "$ROOT/tools/release/package_tree.sh"
T_EXPECT=$(package_tree "$X" "$ALLOW")
T_TIP=$(git rev-parse "$TIP^{tree}")
if [ "$T_EXPECT" = "$T_TIP" ]; then pass "A tree: export of $X == $BRANCH tip tree ($T_TIP)"
else bad "A tree: export of $X ($T_EXPECT) != $BRANCH tip tree ($T_TIP)"; fi

# B. build equivalence
for s in src dev; do rm -rf "$WORK/$s" "$WORK/build-$s"; mkdir -p "$WORK/$s" "$WORK/build-$s"; done
git archive "$X" | tar -x -C "$WORK/src"
git archive "$TIP" | tar -x -C "$WORK/dev"
( cd "$WORK/build-src" && R CMD build "$WORK/src" > build.log 2>&1 ) || bad "B R CMD build of $X failed"
( cd "$WORK/build-dev" && R CMD build "$WORK/dev" > build.log 2>&1 ) || bad "B R CMD build of $BRANCH failed"
TS=$(ls "$WORK"/build-src/*.tar.gz 2>/dev/null | head -1)
TD=$(ls "$WORK"/build-dev/*.tar.gz 2>/dev/null | head -1)
if [ -n "$TS" ] && [ -n "$TD" ]; then
  rm -rf "$WORK/xs" "$WORK/xd"; mkdir -p "$WORK/xs" "$WORK/xd"
  tar -xzf "$TS" -C "$WORK/xs"; tar -xzf "$TD" -C "$WORK/xd"
  NFILES=$(find "$WORK/xd/postexportKinetics" -type f | wc -l | tr -d ' ')
  # Decision rule in tools/release/compare_built_packages.R: IDENTICAL, the
  # controlled exception VIGNETTE_PNG_ENCODING_ONLY, or DIFFERENT.
  CMPOUT=$(Rscript "$ROOT/tools/release/compare_built_packages.R" \
             "$WORK/xs/postexportKinetics" "$WORK/xd/postexportKinetics" 2>&1) || true
  VERDICT=$(printf '%s\n' "$CMPOUT" | tail -1 | tr -d ' ')
  DETAIL=$(printf '%s\n' "$CMPOUT" | sed '$d' | tr '\n' ' ')
  if [ "$(basename "$TS")" != "$(basename "$TD")" ]; then
    bad "B tarball: file names differ ($(basename "$TS") vs $(basename "$TD"))"
  elif [ "$VERDICT" = "IDENTICAL" ]; then
    pass "B tarball: $(basename "$TD") from $X and from $BRANCH have identical content ($NFILES files; only Packaged: may differ)"
  elif [ "$VERDICT" = "VIGNETTE_PNG_ENCODING_ONLY" ]; then
    pass "B tarball: VIGNETTE_PNG_ENCODING_ONLY (controlled exception): $DETAIL($NFILES files)"
  else
    bad "B tarball: DIFFERENT: $DETAIL"
    # Diagnostic control (does not change the verdict): build X a second time
    # and apply the same rule to X against itself.
    rm -rf "$WORK/build-src2" "$WORK/xs2"; mkdir -p "$WORK/build-src2" "$WORK/xs2"
    if ( cd "$WORK/build-src2" && R CMD build "$WORK/src" > build.log 2>&1 ); then
      tar -xzf "$WORK"/build-src2/*.tar.gz -C "$WORK/xs2"
      CTRL=$(Rscript "$ROOT/tools/release/compare_built_packages.R" \
               "$WORK/xs/postexportKinetics" "$WORK/xs2/postexportKinetics" 2>&1) || true
      echo "[INFO] B control (two builds of the same source $X): $(printf '%s\n' "$CTRL" | tr '\n' ' ')"
    fi
  fi
fi

# C. hygiene
if [ -n "$TD" ] && Rscript "$ROOT/tools/ci/inspect_tarball.R" "$TD" > "$WORK/inspect.log" 2>&1; then
  pass "C hygiene: $(tail -1 "$WORK/inspect.log")"
else bad "C hygiene failed (see $WORK/inspect.log)"; tail -8 "$WORK/inspect.log"; fi

# D. BiocCheckGitClone on a clone of the branch
rm -rf "$WORK/clone"; mkdir -p "$WORK/clone"
git clone -q --branch "$BRANCH" --single-branch "$ROOT" "$WORK/clone/postexportKinetics" 2>/dev/null || \
  git clone -q --branch "$BRANCH" --single-branch "$(git remote get-url origin)" "$WORK/clone/postexportKinetics"
if ( cd "$WORK/clone" && Rscript -e '
  r <- BiocCheck::BiocCheckGitClone("postexportKinetics")
  e <- length(r$error); w <- length(r$warning); n <- length(r$note)
  cat(sprintf("BiocCheckGitClone: %d ERRORS | %d WARNINGS | %d NOTES\n", e, w, n))
  if (e + w > 0L) quit(status = 1L)' > gitclone.log 2>&1 ); then
  pass "D $(grep '^BiocCheckGitClone:' "$WORK/clone/gitclone.log")"
else bad "D BiocCheckGitClone reported ERROR/WARNING (see $WORK/clone/gitclone.log)"; tail -15 "$WORK/clone/gitclone.log"; fi

# E. version, citation metadata, public API
efail=0
for f in DESCRIPTION CITATION.cff inst/CITATION NAMESPACE; do
  if [ "$(git show "$X:$f" | git hash-object --stdin)" != "$(git show "$TIP:$f" | git hash-object --stdin)" ]; then
    bad "E $f differs between $X and $BRANCH"; efail=1
  fi
done
V=$(git show "$TIP:DESCRIPTION" | sed -n 's/^Version: //p')
[ "$efail" -ne 0 ] || pass "E identical DESCRIPTION (Version $V), CITATION.cff, inst/CITATION, NAMESPACE ($(git show "$TIP:NAMESPACE" | grep -c '^export(') exports)"

if [ "$fail" -ne 0 ]; then echo "PACKAGE BRANCH VERIFICATION FAILED"; exit 1; fi
echo "PACKAGE BRANCH VERIFICATION PASSED ($BRANCH $TIP <- $X)"
