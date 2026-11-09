#!/usr/bin/env bash
# Fixture tests for the explicit root-only recovery-kit archive import.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
digest_tree() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

repo_dir="$work_dir/repo"
kit="$work_dir/kit"
mock_bin="$work_dir/bin"
mkdir -p "$repo_dir" "$kit/metadata" "$kit/packages" "$mock_bin" "$work_dir/pacman-db/sync"
printf 'alpha' > "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst"
printf 'beta' > "$kit/packages/beta-1.0-1-x86_64.pkg.tar.zst"
cp "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst" "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
cat > "$kit/metadata/package-lock.json" <<EOF
{"packages":[
 {"name":"alpha","version":"1.0-1","archive":"alpha-1.0-1-x86_64.pkg.tar.zst","sha256":"$(sha256sum "$kit/packages/alpha-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)"},
 {"name":"beta","version":"1.0-1","archive":"beta-1.0-1-x86_64.pkg.tar.zst","sha256":"$(sha256sum "$kit/packages/beta-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)"}
]}
EOF
config="$work_dir/repo.conf"
exclude="$work_dir/exclude"
fragment="$work_dir/lumen-local.conf"
pacman_config="$work_dir/pacman.conf"
printf 'REPO_DIR=%q\nCACHE_DIR=%q\nREPO_NAME=lumen-local\n' "$repo_dir" "$work_dir/cache" > "$config"
printf '[options]\n' > "$pacman_config"
: > "$exclude"
cat > "$mock_bin/pacman" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -Qp && "$2" == -q ]] && { basename "$3" | cut -d- -f1; exit 0; }
exit 2
EOF
cat > "$mock_bin/pacman-conf" <<EOF
#!/usr/bin/env bash
printf '%s\n' "$work_dir/pacman-db"
EOF
cat > "$mock_bin/repo-add" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
empty_dir="$(dirname "$1")/repo-add-empty"
mkdir -p "$(dirname "$1")" "$empty_dir"
tar -czf "$1" -C "$empty_dir" .
EOF
project_helper="$work_dir/project-helper"
cat > "$project_helper" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == verify-locks ]]; then exit 0; fi
[[ "$1" == verify-kit && "$2" == "$MOCK_KIT" ]] || exit 2
[[ "${MOCK_REJECT_KIT:-}" != 1 ]] || { echo 'kit verification rejected' >&2; exit 1; }
printf 'Offline recovery kit verified: %s\n' "$2"
EOF
chmod +x "$mock_bin/pacman" "$mock_bin/pacman-conf" "$mock_bin/repo-add" "$project_helper"
PATH="$mock_bin:$PATH" repo-add "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/alpha-1.0-1-x86_64.pkg.tar.zst"
ln "$repo_dir/lumen-local.db.tar.gz" "$repo_dir/lumen-local.db"
printf '[lumen-local]\nServer = file://%s\n' "$repo_dir" > "$fragment"
printf '[options]\nInclude = %s\n' "$fragment" > "$pacman_config"

run_import() {
  unshare -Ur env \
    PATH="$mock_bin:$PATH" MOCK_KIT="$kit" \
    LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" \
    LUMEN_PACMAN_FRAGMENT="$fragment" LUMEN_PACMAN_CONFIG="$pacman_config" \
    LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit "$kit" --yes
}

before_kit=$(digest_tree "$kit")
output=$(run_import)
grep -Fq 'Recovery-kit archives imported: 1; already present: 1; imported bytes: 4.' <<<"$output" || fail 'partial import summary is wrong'
[[ -f "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst" ]] || fail 'missing kit archive was not imported'
[[ -f "$repo_dir/lumen-local.db.tar.gz" && -f "$repo_dir/lumen-local.db" ]] || fail 'local repository database was not published'
grep -Fqx "Server = file://$repo_dir" "$fragment" || fail 'local source does not point at imported repository'
grep -Fqx "Include = $fragment" "$pacman_config" || fail 'local source was not included in Pacman configuration'
[[ "$(digest_tree "$kit")" == "$before_kit" ]] || fail 'confirmed import changed recovery kit'

output=$(run_import)
grep -Fq 'nothing to import; 2 archive(s) are already byte-identical' <<<"$output" || fail 'all-present import did not remain a no-op'
printf 'different' > "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
if run_import >"$work_dir/conflict.log" 2>&1; then fail 'same-name hash conflict was accepted'; fi
grep -Fq 'different SHA-256 locally' "$work_dir/conflict.log" || fail 'hash conflict was not reported'
printf 'Local recovery-kit confirmed import tests passed.\n'
