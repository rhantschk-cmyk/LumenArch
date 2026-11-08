#!/usr/bin/env bash
# Fixture tests for `lumen repo import-kit --preview`.
set -Eeuo pipefail

root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$root_dir/system/usr/lib/lumen/lumen-repo-sync"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
digest_tree() { (cd "$1" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); }

repo_dir="$work_dir/repo"
kit="$work_dir/kit"
mkdir -p "$repo_dir" "$kit/metadata" "$kit/packages"
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
printf 'REPO_DIR=%q\nCACHE_DIR=%q\nREPO_NAME=lumen-local\n' "$repo_dir" "$work_dir/cache" > "$config"
: > "$exclude"
project_helper="$work_dir/project-helper"
cat > "$project_helper" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == verify-kit && "$2" == "$MOCK_KIT" ]] || exit 2
[[ "${MOCK_REJECT_KIT:-}" != 1 ]] || { echo 'kit verification rejected' >&2; exit 1; }
printf 'Offline recovery kit verified: %s\n' "$2"
EOF
chmod +x "$project_helper"

before_repo=$(digest_tree "$repo_dir")
before_kit=$(digest_tree "$kit")
output=$(MOCK_KIT="$kit" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit --preview "$kit")
grep -Fq 'Already present (byte-identical):' <<<"$output" || fail 'identical archive section missing'
grep -Fq 'packages/alpha-1.0-1-x86_64.pkg.tar.zst' <<<"$output" || fail 'identical archive missing'
grep -Fq 'Would import:' <<<"$output" || fail 'import candidate section missing'
grep -Fq 'packages/beta-1.0-1-x86_64.pkg.tar.zst' <<<"$output" || fail 'missing archive was not offered'
grep -Fq 'Import bytes: 4' <<<"$output" || fail 'import byte total is wrong'
[[ "$(digest_tree "$repo_dir")" == "$before_repo" ]] || fail 'preview changed local repository'
[[ "$(digest_tree "$kit")" == "$before_kit" ]] || fail 'preview changed recovery kit'

printf 'different' > "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
if MOCK_KIT="$kit" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit --preview "$kit" >"$work_dir/conflict.log" 2>&1; then
  fail 'same-name checksum conflict was accepted'
fi
grep -Fq 'same name has a different SHA-256 locally' "$work_dir/conflict.log" || fail 'checksum conflict was not reported'
rm "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
ln -s /missing-local-archive "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
if MOCK_KIT="$kit" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit --preview "$kit" >"$work_dir/symlink.log" 2>&1; then
  fail 'symlinked local archive was accepted'
fi
grep -Fq 'local archive is unsafe or unreadable' "$work_dir/symlink.log" || fail 'unsafe local archive was not reported'
rm "$repo_dir/beta-1.0-1-x86_64.pkg.tar.zst"
printf 'beta\n' > "$exclude"
if MOCK_KIT="$kit" LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit --preview "$kit" >"$work_dir/excluded.log" 2>&1; then
  fail 'excluded kit package was accepted'
fi
grep -Fq 'excluded by current local repository policy' "$work_dir/excluded.log" || fail 'policy exclusion was not reported'
if MOCK_KIT="$kit" MOCK_REJECT_KIT=1 LUMEN_REPO_CONFIG_FILE="$config" LUMEN_REPO_EXCLUDE_FILE="$exclude" LUMEN_PROJECT_HELPER="$project_helper" "$helper" import-kit --preview "$kit" >"$work_dir/invalid.log" 2>&1; then
  fail 'kit rejected by verification reached preview'
fi
grep -Fq 'kit verification rejected' "$work_dir/invalid.log" || fail 'kit verification rejection was hidden'

printf 'Local recovery-kit import preview tests passed.\n'
