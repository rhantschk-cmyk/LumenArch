#!/usr/bin/env bash
# Fixture tests for explicit adopted recovery-kit retention locks.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
digest() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

repo_dir="$work_dir/repo"
kit="$work_dir/kit"
state="$work_dir/retained-kits"
mock_bin="$work_dir/bin"
fragment="$work_dir/lumen-local.conf"
pacman_config="$work_dir/pacman.conf"
config="$work_dir/repo.conf"
events="$work_dir/events"
mkdir -p "$repo_dir" "$kit/metadata" "$kit/packages" "$mock_bin" "$work_dir/pacman-db/sync"
printf 'alpha archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
printf 'alpha archive\n' > "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst"
checksum=$(sha256sum "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)
printf '{"packages":[{"name":"alpha","version":"1.0-1","archive":"alpha-1.0-1-x86_64.pkg.tar.zst","sha256":"%s"}]}' "$checksum" > "$kit/metadata/package-lock.json"
printf '# Lumen offline snapshot recovery kit\n\nProject: Demo\nVersion: v000001\n' > "$kit/RECOVERY.md"
printf 'kit manifest\n' > "$kit/SHA256SUMS"
printf 'REPO_DIR=%q\nCACHE_DIR=%q\nREPO_NAME=lumen-local\n' "$repo_dir" "$work_dir/cache" > "$config"
printf '[options]\nInclude = %s\n' "$fragment" > "$pacman_config"
printf '[lumen-local]\nServer = file://%s\n' "$repo_dir" > "$fragment"

cat > "$mock_bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
archive=${@: -1}
[[ "$(basename -- "$archive")" == alpha-1.0-1-x86_64.pkg.tar.zst ]] || exit 1
if [[ "${1:-}" == -Qp && "${2:-}" == -q ]]; then printf 'alpha\n'; else printf 'alpha 1.0-1\n'; fi
EOF
cat > "$mock_bin/repo-add" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=$1; shift
stage=$(mktemp -d); trap 'rm -rf -- "$stage"' EXIT
mkdir -p "$stage/alpha-1.0-1"
printf '%%NAME%%\nalpha\n\n%%VERSION%%\n1.0-1\n' > "$stage/alpha-1.0-1/desc"
tar -czf "$output" -C "$stage" .
EOF
cat > "$mock_bin/pacman-conf" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$work_dir/pacman-db"
EOF
cat > "$mock_bin/paccache" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$PACCACHE_LOG"
[[ "$*" == *'--ignore alpha'* ]] || exit 2
EOF
project_helper="$work_dir/project-helper"
cat > "$project_helper" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$1" >> "$MOCK_EVENTS"
case "$1" in
  verify-kit) [[ "$2" == "$MOCK_KIT" ]] || exit 2 ;;
  verify-locks|protected-packages|protected-archive-locks) ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$mock_bin/pacman" "$mock_bin/repo-add" "$mock_bin/pacman-conf" "$mock_bin/paccache" "$project_helper"
PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
ln -f "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/lumen-local.db"
cp "$repo_dir/lumen-local.db.tar.gz" "$work_dir/pacman-db/sync/lumen-local.db"

run() {
  unshare -Ur env PATH="$mock_bin:$PATH" MOCK_KIT="$kit" MOCK_EVENTS="$events" \
    LUMEN_REPO_CONFIG_FILE="$config" LUMEN_PACMAN_FRAGMENT="$fragment" LUMEN_PACMAN_CONFIG="$pacman_config" \
    LUMEN_PROJECT_HELPER="$project_helper" LUMEN_REPO_RETAINED_KITS_DIR="$state" "$helper" "$@"
}

if run retain-kit "$kit" >"$work_dir/no-yes.log" 2>&1; then fail 'retain-kit accepted missing confirmation'; fi
[[ ! -e "$state" ]] || fail 'missing confirmation created retention state'
: > "$events"
before_repo=$(digest "$repo_dir"); before_kit=$(digest "$kit"); before_meta=$(sha256sum "$fragment" "$pacman_config" "$work_dir/pacman-db/sync/lumen-local.db")
output=$(run retain-kit "$kit" --yes)
grep -Fq 'Recovery-kit retention: adopted 1 archive(s) for Demo v000001; lock:' <<<"$output" || fail 'retention success summary is wrong'
lock=$(printf '%s\n' "$output" | sed -n 's/.*lock: \(.*\)\.$/\1/p')
[[ -f "$lock" && ! -L "$lock" ]] || fail 'retention lock was not published'
[[ "$(stat -c '%a' "$state")" == '700' ]] || fail 'retention state is not mode 0700'
[[ "$(digest "$repo_dir")" == "$before_repo" ]] || fail 'retention changed local archive or database'
[[ "$(digest "$kit")" == "$before_kit" ]] || fail 'retention changed recovery kit'
[[ "$(sha256sum "$fragment" "$pacman_config" "$work_dir/pacman-db/sync/lumen-local.db")" == "$before_meta" ]] || fail 'retention changed local metadata'
[[ "$(tr '\n' ' ' < "$events")" == 'verify-kit verify-kit verify-locks verify-kit ' ]] || fail 'retention did not verify kit then target closure before publication'

output=$(run retain-kit "$kit" --yes)
grep -Fq 'already retained' <<<"$output" || fail 'byte-identical retention was not idempotent'
: > "$work_dir/paccache.log"
preview=$(PATH="$mock_bin:$PATH" PACCACHE_LOG="$work_dir/paccache.log" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_PACMAN_FRAGMENT="$fragment" LUMEN_PACMAN_CONFIG="$pacman_config" LUMEN_PROJECT_HELPER="$project_helper" LUMEN_REPO_RETAINED_KITS_DIR="$state" MOCK_EVENTS="$events" "$helper" prune --preview)
grep -Fq "alpha-1.0-1-x86_64.pkg.tar.zst required by retained-kits/$(basename "$lock")" <<<"$preview" || fail 'preview did not attribute retained kit protection'
grep -Fq -- '--ignore alpha' "$work_dir/paccache.log" || fail 'preview did not preserve retained package'

printf '{"schema":1,"kit_manifest_sha256":"%064d","project":"Other","version":"v000001","packages":[{"name":"alpha","archive":"alpha-1.0-1-x86_64.pkg.tar.zst","sha256":"%s"}]}' 0 "$checksum" > "$lock"
if run retain-kit "$kit" --yes >"$work_dir/collision.log" 2>&1; then fail 'different lock content at kit identity was accepted'; fi
grep -Fq 'collides with different retention content' "$work_dir/collision.log" || fail 'identity collision was not reported'
printf 'Local recovery-kit retention tests passed.\n'
