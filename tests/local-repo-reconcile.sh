#!/usr/bin/env bash
# Fixture tests for explicit metadata-only local repository reconciliation.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
digest_archives() { (cd "$1" && find . -maxdepth 1 -type f -name '*.pkg.tar.*' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

repo_dir="$work_dir/repo"
mock_bin="$work_dir/bin"
fragment="$work_dir/lumen-local.conf"
pacman_config="$work_dir/pacman.conf"
exclude="$work_dir/exclude"
config="$work_dir/repo.conf"
project_helper="$work_dir/project-helper"
mkdir -p "$repo_dir" "$mock_bin" "$work_dir/pacman-db/sync"
printf 'foo archive\n' > "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"
printf 'bar archive\n' > "$repo_dir/bar-2.0-1-x86_64.pkg.tar.zst"
printf 'REPO_DIR=%q\nCACHE_DIR=%q\nREPO_NAME=lumen-local\n' "$repo_dir" "$work_dir/cache" > "$config"
printf '[options]\n' > "$pacman_config"
: > "$exclude"

cat > "$mock_bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
archive=${@: -1}
case "$(basename -- "$archive")" in
  foo-1.0-1-x86_64.pkg.tar.zst) name=foo; version=1.0-1 ;;
  bar-2.0-1-x86_64.pkg.tar.zst) name=bar; version=2.0-1 ;;
  *) exit 1 ;;
esac
if [[ "${1:-}" == -Qp && "${2:-}" == -q ]]; then printf '%s\n' "$name"; else printf '%s %s\n' "$name" "$version"; fi
EOF
cat > "$mock_bin/repo-add" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=$1
shift
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
for archive in "$@"; do
  read -r name version < <(pacman -Qp "$archive")
  mkdir -p "$stage/$name-$version"
  printf '%%NAME%%\n%s\n\n%%VERSION%%\n%s\n' "$name" "$version" > "$stage/$name-$version/desc"
done
tar -czf "$output" -C "$stage" .
EOF
cat > "$mock_bin/pacman-conf" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$work_dir/pacman-db"
EOF
cat > "$project_helper" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == verify-locks ]] || exit 2
exit 0
EOF
chmod +x "$mock_bin/pacman" "$mock_bin/repo-add" "$mock_bin/pacman-conf" "$project_helper"

run() {
  unshare -Ur env PATH="$mock_bin:$PATH" \
    LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" \
    LUMEN_PACMAN_FRAGMENT="$fragment" LUMEN_PACMAN_CONFIG="$pacman_config" \
    LUMEN_PROJECT_HELPER="$project_helper" "$helper" "$@"
}
verify() {
  PATH="$mock_bin:$PATH" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" \
    LUMEN_PACMAN_FRAGMENT="$fragment" LUMEN_PACMAN_CONFIG="$pacman_config" \
    LUMEN_PROJECT_HELPER="$project_helper" "$helper" verify
}

before=$(digest_archives "$repo_dir")
if run reconcile >"$work_dir/no-yes.log" 2>&1; then fail 'reconciliation accepted missing confirmation'; fi
run reconcile --yes | grep -Fq 'metadata reconciled: 2 archive(s)' || fail 'initial reconciliation did not publish metadata'
verify | grep -Fq 'Local repository readiness: ready' || fail 'verification did not pass after reconciliation'
[[ "$(digest_archives "$repo_dir")" == "$before" ]] || fail 'reconciliation changed archive payloads'

: > "$fragment"
rm -f "$work_dir/pacman-db/sync/lumen-local.db"
if verify >"$work_dir/stale.log" 2>&1; then fail 'verification accepted missing metadata'; fi
grep -Fq 'Pacman sync database: missing' "$work_dir/stale.log" || fail 'missing sync metadata was not diagnosed'
run reconcile --yes | grep -Fq 'metadata reconciled: 2 archive(s)' || fail 'stale metadata was not reconciled'
verify | grep -Fq 'Local repository readiness: ready' || fail 'verification did not recover after reconciliation'
[[ "$(digest_archives "$repo_dir")" == "$before" ]] || fail 'repair changed archive payloads'

printf 'foo archive\n' > "$repo_dir/unsafe-1.0-1-x86_64.pkg.tar.zst"
if run reconcile --yes >"$work_dir/unsafe.log" 2>&1; then fail 'unreadable archive was accepted'; fi
grep -Fq 'archive metadata is unreadable' "$work_dir/unsafe.log" || fail 'unsafe archive blocker was not reported'
rm "$repo_dir/unsafe-1.0-1-x86_64.pkg.tar.zst"

rm -f "$repo_dir"/*.pkg.tar.* "$repo_dir"/lumen-local.db "$repo_dir"/lumen-local.db.tar.gz
run reconcile --yes | grep -Fq 'empty archive; local-first Pacman source disabled' || fail 'empty repository metadata was not reconciled'
[[ ! -e "$work_dir/pacman-db/sync/lumen-local.db" ]] || fail 'empty reconciliation left stale Pacman sync metadata'
[[ ! -s "$fragment" ]] || fail 'empty reconciliation did not disable the local source'

printf 'Local repository reconciliation tests passed.\n'
