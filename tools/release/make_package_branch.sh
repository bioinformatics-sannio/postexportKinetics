#!/bin/sh
# =============================================================================
# Export the package-distribution content of a development commit to the
# package-only branch `devel` (Bioconductor submission policy P1).
#
# Usage (from the repository root, on the development branch):
#   sh tools/release/make_package_branch.sh <source-commit-SHA> [branch]
#
#   branch defaults to "devel".
#
# - The exported paths come from tools/release/package_allowlist.txt,
#   read from the SOURCE commit.
# - The export uses git plumbing only (a temporary index, write-tree,
#   commit-tree). The working tree, the index and the current branch are
#   untouched.
# - It creates ONE normal commit on <branch>, whose parent is the current
#   <branch> tip (or no parent for the first export), with the message
#       package-only export of <short SHA>
#   and the trailer
#       Source-Commit: <full SHA>
#   <branch> only moves forward (update-ref with the expected old value);
#   its history stays linear. Nothing is pushed: push with a normal
#   `git push origin <branch>` (never --force).
# - If the exported tree equals the current <branch> tip tree, no commit is
#   created.
# =============================================================================
set -eu

SRC_ARG="${1:?Usage: make_package_branch.sh <source-commit-SHA> [branch]}"
BRANCH="${2:-devel}"
ALLOW="tools/release/package_allowlist.txt"

SRC=$(git rev-parse --verify "$SRC_ARG^{commit}")
SHORT=$(git rev-parse --short "$SRC")

. "$(dirname "$0")/package_tree.sh"
TREE=$(package_tree "$SRC" "$ALLOW")

OLD=$(git rev-parse --verify -q "refs/heads/$BRANCH" || true)
if [ -n "$OLD" ]; then
  if [ "$(git rev-parse "$OLD^{tree}")" = "$TREE" ]; then
    echo "$BRANCH is already the package-only export of this content (tree $TREE); no commit created."
    exit 0
  fi
  PARENT="-p $OLD"
else
  PARENT=""
fi

MSG=$(printf 'package-only export of %s\n\nSource-Commit: %s\n' "$SHORT" "$SRC")
# shellcheck disable=SC2086
NEW=$(printf '%s\n' "$MSG" | git commit-tree "$TREE" $PARENT)
if [ -n "$OLD" ]; then
  git update-ref "refs/heads/$BRANCH" "$NEW" "$OLD"
else
  git update-ref "refs/heads/$BRANCH" "$NEW" ""
fi
echo "$BRANCH -> $NEW (tree $TREE), package-only export of $SRC"
