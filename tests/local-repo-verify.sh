#!/usr/bin/env bash
# Read-only fixture tests for `lumen repo verify`.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
project_helper="$root_dir/system/usr/lib/lumen/lumen-project"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mock_bin="$work_dir/bin"
repo_dir="$work_dir/repo"
projects_dir="$work_dir/projects"
config_file="$work_dir/repo.conf"
fragment="$work_dir/lumen-local.conf"
mkdir -p "$mock_bin" "$repo_dir" "$projects_dir" "$work_dir/pacman-db/sync"

cat > "$mock_bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
archive=${@: -1}
case "$(basename -- "$archive")" in
  foo-1.0-1-x86_64.pkg.tar.zst) name=foo; version=1.0-1 ;;
  bar-2.0-1-x86_64.pkg.tar.zst) name=bar; version=2.0-1 ;;
  *) exit 1 ;;
esac
if [[ "${1:-}" == -Qp && "${2:-}" == -q ]]; then
  printf '%s\n' "$name"
elif [[ "${1:-}" == -Qp ]]; then
  printf '%s %s\n' "$name" "$version"
else
  exit 2
fi
EOF

cat > "$mock_bin/repo-add" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output="$1"
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
chmod +x "$mock_bin/pacman" "$mock_bin/repo-add" "$mock_bin/pacman-conf"

printf '%s\n' 'foo archive' > "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"
cat > "$config_file" <<EOF
REPO_DIR=$repo_dir
CACHE_DIR=$work_dir/cache
REPO_NAME=lumen-local
EOF
cat > "$fragment" <<EOF
[lumen-local]
SigLevel = Optional TrustAll
Server = file://$repo_dir
EOF
PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"
cp "$repo_dir/lumen-local.db.tar.gz" "$work_dir/pacman-db/sync/lumen-local.db"

verify() {
  PATH="$mock_bin:$PATH" \
  LUMEN_REPO_CONFIG_FILE="$config_file" \
  LUMEN_PACMAN_FRAGMENT="$fragment" \
  LUMEN_PROJECT_HELPER="$project_helper" \
  LUMEN_PROJECT_ROOT="$projects_dir" \
  LUMEN_REPO_DIR="$repo_dir" \
  "$helper" verify
}

expect_failure() {
  local expected="$1" output="$work_dir/failure.log"
  if verify >"$output" 2>&1; then
    fail "verification unexpectedly passed while checking: $expected"
  fi
  grep -Fq -- "$expected" "$output" || { cat "$output" >&2; fail "missing failure detail: $expected"; }
}

# An archive-backed repository remains healthy when no projects have snapshots.
verify || fail 'no-snapshot state was not accepted'

checksum=$(sha256sum "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)
mkdir -p "$projects_dir/demo/locks"
cat > "$projects_dir/demo/locks/v000001.json" <<EOF
{"schema": 1, "packages": [{"name": "foo", "version": "1.0-1", "archive": "foo-1.0-1-x86_64.pkg.tar.zst", "sha256": "$checksum"}]}
EOF
verify | grep -Fq 'Local repository readiness: ready' || fail 'healthy repository did not pass'

mv "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst" "$work_dir/foo.saved"
expect_failure 'locked archive is missing: foo-1.0-1-x86_64.pkg.tar.zst'
mv "$work_dir/foo.saved" "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"

printf '%s\n' 'tampered' >> "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"
expect_failure 'locked archive checksum changed: foo-1.0-1-x86_64.pkg.tar.zst'
printf '%s\n' 'foo archive' > "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"

printf '%s\n' 'bar archive' > "$repo_dir/bar-2.0-1-x86_64.pkg.tar.zst"
expect_failure 'entries are stale or incomplete'
PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir"/*.pkg.tar.zst
cp "$repo_dir/lumen-local.db.tar.gz" "$work_dir/pacman-db/sync/lumen-local.db"
rm "$repo_dir/bar-2.0-1-x86_64.pkg.tar.zst"
PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst"
cp "$repo_dir/lumen-local.db.tar.gz" "$work_dir/pacman-db/sync/lumen-local.db"

: > "$fragment"
PATH="$mock_bin:$PATH" \
  LUMEN_REPO_CONFIG_FILE="$config_file" \
  LUMEN_PACMAN_FRAGMENT="$fragment" \
  "$helper" status | grep -Fqx 'Pacman source: disabled until the first archive is synced' || fail 'empty Pacman fragment was reported as enabled'
expect_failure 'does not enable [lumen-local]'
cat > "$fragment" <<EOF
[lumen-local]
SigLevel = Optional TrustAll
Server = file://$repo_dir
EOF

verify | grep -Fq 'Local repository readiness: ready' || fail 'repository did not recover after fixture repairs'
printf 'Local repository verification tests passed.\n'
