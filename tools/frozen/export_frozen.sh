#!/bin/sh
# =============================================================================
# Export the frozen manuscript implementation into a scratch directory.
#
# Usage:
#   tools/frozen/export_frozen.sh [FROZEN_REPO] [DEST_DIR]
#
# Defaults:
#   FROZEN_REPO = $HOME/postexport-kinetics
#   DEST_DIR    = a new temporary directory
#
# The frozen repository is only read: `git rev-parse` and `git archive` do not
# change its working tree, index, refs or HEAD. The export is taken from the
# tag, never from the working tree, and the tag must resolve to the expected
# commit.
# =============================================================================

set -eu

TAG="manuscript-revision-v1.0"
EXPECTED_COMMIT="65c3b7368fb7686bfde3dab857f98c393bb534c5"

REPO="${1:-$HOME/postexport-kinetics}"
DEST="${2:-$(mktemp -d)/postexport-kinetics-frozen}"

ACTUAL_COMMIT="$(git -C "$REPO" rev-parse "$TAG^{commit}")"

if [ "$ACTUAL_COMMIT" != "$EXPECTED_COMMIT" ]; then
  echo "Tag $TAG resolves to $ACTUAL_COMMIT, expected $EXPECTED_COMMIT." >&2
  exit 1
fi

mkdir -p "$DEST"

if [ -n "$(ls -A "$DEST")" ]; then
  echo "Destination $DEST is not empty." >&2
  exit 1
fi

git -C "$REPO" archive "$TAG" | tar -x -C "$DEST"

printf '%s\n' "$EXPECTED_COMMIT" > "$DEST/.frozen_commit"

echo "$DEST"
