# Shared helper (sourced): package_tree <commit> <allowlist path>
# Prints the git tree id containing only the allowlisted paths of <commit>
# (allowlist read from <commit> itself). Uses a temporary index; does not
# touch the working tree or the real index.
package_tree() {
  _src="$1"; _allow="$2"
  _idx=$(mktemp "${TMPDIR:-/tmp}/pkgidx.XXXXXX")
  rm -f "$_idx"
  _paths=$(git show "$_src:$_allow" | sed -e 's/#.*$//' -e 's/[[:space:]]*$//' | grep -v '^$')
  GIT_INDEX_FILE="$_idx" git read-tree --empty
  for _p in $_paths; do
    case "$_p" in
      */) _d=${_p%/}
          git ls-tree -r --full-tree "$_src" -- "$_d" ;;
      *)  git ls-tree --full-tree "$_src" -- "$_p" ;;
    esac
  done | GIT_INDEX_FILE="$_idx" git update-index --index-info
  GIT_INDEX_FILE="$_idx" git write-tree
  rm -f "$_idx"
}
