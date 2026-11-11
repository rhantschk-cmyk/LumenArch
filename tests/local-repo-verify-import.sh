#!/usr/bin/env bash
# Fixture tests for read-only recovery-kit import completion verification.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
digest_tree() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

repo_dir="$work_dir/repo"
kit="$work_dir/kit"
mock_bin="$work_dir/bin"
fragment="$work_dir/lumen-local.conf"
pacman_config="$work_dir/pacman.conf"
config="$work_dir/repo.conf"
events="$work_dir/events"
mkdir -p "$repo_dir" "$kit/metadata" "$kit/packages" "$mock_bin" "$work_dir/pacman-db/sync"
printf 'alpha archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
printf 'beta archive\n' > "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
printf 'alpha archive\n' > "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst"
cat > "$kit/metadata/package-lock.json" <<EOF
{"packages":[{"name":"alpha","version":"1.0-1","archive":"alpha-1.0-1-x86_64.pkg.tar.zst","sha256":"$(sha256sum "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)"}]}
EOF
printf 'REPO_DIR=%q\nCACHE_DIR=%q\nREPO_NAME=lumen-local\n' "$repo_dir" "$work_dir/cache" > "$config"
printf '[options]\nInclude = %s\n' "$fragment" > "$pacman_config"
printf '[lumen-local]\nServer = file://%s\n' "$repo_dir" > "$fragment"

cat > "$mock_bin/pacman" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
archive=${@: -1}
case "$(basename -- "$archive")" in
  alpha-1.0-1-x86_64.pkg.tar.zst) name=alpha; version=1.0-1 ;;
  beta-1.0-1-x86_64.pkg.tar.zst) name=beta; version=1.0-1 ;;
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
project_helper="$work_dir/project-helper"
cat > "$project_helper" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$1" >> "$MOCK_EVENTS"
case "$1" in
  verify-kit)
    [[ "$2" == "$MOCK_KIT" ]] || exit 2
    [[ "${MOCK_REJECT_KIT:-}" != 1 ]] || { echo 'kit verification rejected' >&2; exit 1; }
    printf 'Offline recovery kit verified: %s\n' "$2"
    ;;
  verify-locks) printf 'Saved project locks: ready\n' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$mock_bin/pacman" "$mock_bin/repo-add" "$mock_bin/pacman-conf" "$project_helper"

publish_metadata() {
  PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir"/*.pkg.tar.zst
  ln -f "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/lumen-local.db"
  cp "$repo_dir/lumen-local.db.tar.gz" "$work_dir/pacman-db/sync/lumen-local.db"
}
run_verify() {
  : > "$events"
  PATH="$mock_bin:$PATH" MOCK_KIT="$kit" MOCK_EVENTS="$events" \
    LUMEN_REPO_CONFIG_FILE="$config" LUMEN_PACMAN_FRAGMENT="$fragment" \
    LUMEN_PACMAN_CONFIG="$pacman_config" LUMEN_PROJECT_HELPER="$project_helper" \
    "$helper" verify-import "$kit"
}

publish_metadata
before_repo=$(digest_tree "$repo_dir")
before_kit=$(digest_tree "$kit")
before_metadata=$(sha256sum "$fragment" "$pacman_config" "$work_dir/pacman-db/sync/lumen-local.db")
output=$(run_verify)
grep -Fq 'Recovery-kit import completion: ready; 1 kit archive(s) are retained locally; target-only archives: 1.' <<<"$output" || fail 'ready completion summary is wrong'
[[ "$(tr '\n' ' ' < "$events")" == 'verify-kit verify-locks ' ]] || fail 'kit verification and target readiness did not run in order'
[[ "$(digest_tree "$repo_dir")" == "$before_repo" ]] || fail 'completion verification changed local archive'
[[ "$(digest_tree "$kit")" == "$before_kit" ]] || fail 'completion verification changed recovery kit'
[[ "$(sha256sum "$fragment" "$pacman_config" "$work_dir/pacman-db/sync/lumen-local.db")" == "$before_metadata" ]] || fail 'completion verification changed local metadata'

rm "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata
if run_verify >"$work_dir/missing.log" 2>&1; then fail 'missing imported archive was accepted'; fi
grep -Fq 'Missing from local archive:' "$work_dir/missing.log" || fail 'missing archive header was not reported'
grep -Fq 'packages/alpha-1.0-1-x86_64.pkg.tar.zst' "$work_dir/missing.log" || fail 'missing archive path was not reported'
printf 'alpha archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata

printf 'different archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata
if run_verify >"$work_dir/conflict.log" 2>&1; then fail 'same-name checksum conflict was accepted'; fi
grep -Fq 'same name has a different SHA-256 locally' "$work_dir/conflict.log" || fail 'checksum conflict was not reported'
printf 'alpha archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata

rm "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
ln -s /missing-target-archive "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata
if run_verify >"$work_dir/symlink.log" 2>&1; then fail 'symlinked target archive was accepted'; fi
grep -Fq 'local archive is unsafe or unreadable' "$work_dir/symlink.log" || fail 'unsafe target archive was not reported'
rm "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
printf 'alpha archive\n' > "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
publish_metadata

: > "$fragment"
if run_verify >"$work_dir/stale.log" 2>&1; then fail 'stale target metadata was accepted'; fi
grep -Fq 'does not enable [lumen-local]' "$work_dir/stale.log" || fail 'stale target metadata did not require reconciliation'
printf '[lumen-local]\nServer = file://%s\n' "$repo_dir" > "$fragment"

if MOCK_REJECT_KIT=1 run_verify >"$work_dir/kit.log" 2>&1; then fail 'changed kit was accepted'; fi
grep -Fq 'kit verification rejected' "$work_dir/kit.log" || fail 'kit rejection was not reported'
[[ "$(tr '\n' ' ' < "$events")" == 'verify-kit ' ]] || fail 'target readiness ran after kit rejection'
printf 'Local recovery-kit import completion verification tests passed.\n'
