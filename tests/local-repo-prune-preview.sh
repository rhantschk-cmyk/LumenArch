#!/usr/bin/env bash
# Read-only fixture tests for `lumen repo prune --preview`.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
lumen="$root_dir/system/usr/local/bin/lumen"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

mock_bin="$work_dir/bin"
repo_dir="$work_dir/repo"
projects_dir="$work_dir/projects"
config_file="$work_dir/repo.conf"
mkdir -p "$mock_bin" "$repo_dir" "$projects_dir"
cat > "$config_file" <<EOF
REPO_DIR=$repo_dir
CACHE_DIR=$work_dir/cache
REPO_NAME=lumen-local
EOF

cat > "$mock_bin/paccache" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$PACCACHE_LOG"
[[ "$*" == *'-dk2'* ]] || exit 2
if [[ "$*" == *'--ignore foo'* ]]; then
  printf '%s\n' "$PREVIEW_REPO/bar-1.0-1-x86_64.pkg.tar.zst"
else
  printf '%s\n' "$PREVIEW_REPO/foo-1.0-1-x86_64.pkg.tar.zst" "$PREVIEW_REPO/bar-1.0-1-x86_64.pkg.tar.zst"
fi
EOF
chmod +x "$mock_bin/paccache"

for archive in foo-1.0-1 foo-2.0-1 foo-3.0-1 bar-1.0-1 bar-2.0-1 bar-3.0-1; do
  printf '%s\n' "$archive" > "$repo_dir/$archive-x86_64.pkg.tar.zst"
done
checksum=$(sha256sum "$repo_dir/foo-1.0-1-x86_64.pkg.tar.zst" | cut -d' ' -f1)
mkdir -p "$projects_dir/demo/locks"
cat > "$projects_dir/demo/locks/v000001.json" <<EOF
{"schema": 1, "packages": [{"name": "foo", "version": "1.0-1", "archive": "foo-1.0-1-x86_64.pkg.tar.zst", "sha256": "$checksum"}]}
EOF

preview() {
  PATH="$mock_bin:$PATH" \
  PACCACHE_LOG="$work_dir/paccache.log" \
  PREVIEW_REPO="$repo_dir" \
  LUMEN_REPO_CONFIG_FILE="$config_file" \
  LUMEN_PROJECT_HELPER="$root_dir/system/usr/lib/lumen/lumen-project" \
  LUMEN_PROJECT_ROOT="$projects_dir" \
  LUMEN_REPO_DIR="$repo_dir" \
  "$lumen" repo prune --preview
}

tree_hash() {
  find "$repo_dir" "$projects_dir" -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1
}

before=$(tree_hash)
output=$(preview)
after=$(tree_hash)
[[ "$before" == "$after" ]] || fail 'preview modified repository or saved locks'
printf '%s\n' "$output" | grep -Fq 'Removal candidates:' || fail 'preview did not list cleanup candidates'
printf '%s\n' "$output" | grep -Fq -- "- $repo_dir/bar-1.0-1-x86_64.pkg.tar.zst" || fail 'ordinary old archive was not listed'
printf '%s\n' "$output" | grep -Fq "Reclaimable bytes: $(stat -c '%s' "$repo_dir/bar-1.0-1-x86_64.pkg.tar.zst")" || fail 'reclaimable byte count is wrong'
printf '%s\n' "$output" | grep -Fq 'foo-1.0-1-x86_64.pkg.tar.zst required by demo/locks/v000001.json' || fail 'saved snapshot protection was not attributed'
! printf '%s\n' "$output" | grep -Fq -- "- $repo_dir/foo-1.0-1-x86_64.pkg.tar.zst" || fail 'snapshot-protected package was offered for deletion'
grep -Fq -- '--ignore foo' "$work_dir/paccache.log" || fail 'preview did not preserve destructive prune protection semantics'

if PATH="/usr/bin:/bin" LUMEN_REPO_CONFIG_FILE="$config_file" LUMEN_PROJECT_HELPER="$root_dir/system/usr/lib/lumen/lumen-project" LUMEN_PROJECT_ROOT="$projects_dir" LUMEN_REPO_DIR="$repo_dir" "$lumen" repo prune --preview >"$work_dir/no-paccache.log" 2>&1; then
  fail 'preview accepted an archive repository without paccache'
fi
grep -Fq 'paccache is unavailable' "$work_dir/no-paccache.log" || fail 'missing paccache was not explained'

printf '{"packages": [{"name": "foo", "archive": "../unsafe.pkg.tar.zst", "sha256": "%s"}]}' "$checksum" > "$projects_dir/demo/locks/v000001.json"
before=$(tree_hash)
if preview >"$work_dir/malformed.log" 2>&1; then
  fail 'preview accepted an unsafe saved-lock archive name'
fi
after=$(tree_hash)
[[ "$before" == "$after" ]] || fail 'failed preview modified fixture state'
grep -Fq 'run `lumen repo verify` before pruning' "$work_dir/malformed.log" || fail 'malformed lock lacks verification remediation'

printf '{"packages": [{"name": "foo", "archive": "missing-1.0-1-x86_64.pkg.tar.zst", "sha256": "%s"}]}' "$checksum" > "$projects_dir/demo/locks/v000001.json"
if preview >"$work_dir/missing.log" 2>&1; then
  fail 'preview accepted a missing locked archive'
fi
grep -Fq 'locked archive is missing: missing-1.0-1-x86_64.pkg.tar.zst' "$work_dir/missing.log" || fail 'missing lock archive was not named'

empty_repo="$work_dir/empty-repo"
empty_config="$work_dir/empty.conf"
mkdir -p "$empty_repo"
printf 'REPO_DIR=%s\nCACHE_DIR=%s\nREPO_NAME=lumen-local\n' "$empty_repo" "$work_dir/cache" > "$empty_config"
PATH="$mock_bin:$PATH" LUMEN_REPO_CONFIG_FILE="$empty_config" LUMEN_PROJECT_HELPER="$root_dir/system/usr/lib/lumen/lumen-project" LUMEN_PROJECT_ROOT="$work_dir/empty-projects" LUMEN_REPO_DIR="$empty_repo" "$lumen" repo prune --preview | grep -Fq 'Archive cleanup preview: local repository is empty.' || fail 'empty repository preview was not handled'

printf 'Local repository prune preview tests passed.\n'
