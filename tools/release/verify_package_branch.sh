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
#      the R-generated "Packaged:" line of DESCRIPTION may differ;
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
  for d in xs xd; do
    grep -v '^Packaged:' "$WORK/$d/postexportKinetics/DESCRIPTION" > "$WORK/$d/DESCRIPTION.cmp"
    mv "$WORK/$d/DESCRIPTION.cmp" "$WORK/$d/postexportKinetics/DESCRIPTION"
  done
  if [ "$(basename "$TS")" = "$(basename "$TD")" ] && \
     diff -r "$WORK/xs/postexportKinetics" "$WORK/xd/postexportKinetics" > "$WORK/tarball.diff" 2>&1; then
    pass "B tarball: $(basename "$TD") from $X and from $BRANCH have identical content ($(find "$WORK/xd/postexportKinetics" -type f | wc -l | tr -d ' ') files; only Packaged: may differ)"
  else
    bad "B tarball: content differs (see $WORK/tarball.diff)"; head -20 "$WORK/tarball.diff"
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
