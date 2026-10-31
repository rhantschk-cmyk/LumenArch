#!/usr/bin/env bash
# Regression tests for Control Center update-channel and curated-app behavior.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$root_dir/home/.config/lumen/bin/lumenctl"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Load the function definitions without executing the Control Center's main loop.
sed '/^if \[\[ "${1:-}" == --update \]\]; then/,$d' "$source_file" > "$work_dir/lumenctl-functions"
# shellcheck source=/dev/null
source "$work_dir/lumenctl-functions"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mock_bin="$work_dir/bin"
mkdir -p "$mock_bin"
export MOCK_GIT_LOG="$work_dir/git.log"
cat > "$mock_bin/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$MOCK_GIT_LOG"
case "$*" in
  *' diff --quiet'*|*' diff --cached --quiet'*|*' fetch --prune origin'*) exit 0 ;;
  *' branch --show-current'*) printf '%s\n' "${MOCK_BRANCH:-main}" ;;
  *' show-ref --verify --quiet refs/heads/'*) exit 1 ;;
  *' branch --track '*) exit 0 ;;
  *' switch '*) exit 0 ;;
  *' merge --ff-only origin/'*) exit 0 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$mock_bin/git"

PATH="$mock_bin:$PATH"
update_source "$work_dir/source"
grep -Fqx -- "-C $work_dir/source switch stable" "$MOCK_GIT_LOG" || fail 'legacy main checkout was not migrated to stable'
grep -Fqx -- "-C $work_dir/source merge --ff-only origin/stable" "$MOCK_GIT_LOG" || fail 'stable was not fast-forwarded'

export MOCK_GUM_OUTPUT=$'discord\tDiscord\tofficial\nspotify\tSpotify\tAUR'
export MOCK_LUMEN_LOG="$work_dir/lumen.log"
cat > "$mock_bin/gum" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  choose) printf '%s\n' "$MOCK_GUM_OUTPUT" ;;
  confirm) exit 0 ;;
  style|input) exit 0 ;;
  *) exit 0 ;;
esac
EOF
cat > "$mock_bin/lumen" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MOCK_LUMEN_LOG"
EOF
chmod +x "$mock_bin/gum" "$mock_bin/lumen"

curated_apps
grep -Fqx 'install discord' "$MOCK_LUMEN_LOG" || fail 'Discord was not installed as an individual curated selection'
grep -Fqx 'install spotify' "$MOCK_LUMEN_LOG" || fail 'Spotify was not installed as an individual curated selection'
[[ "$(wc -l < "$MOCK_LUMEN_LOG")" -eq 2 ]] || fail 'curated selections were batched instead of invoked individually'

printf 'Control Center regression tests passed.\n'
