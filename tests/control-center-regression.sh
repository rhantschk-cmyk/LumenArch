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

grep -Fxq 'obs-studio-plugin-browser' "$root_dir/profiles/creator/packages.pacman" && fail 'obsolete OBS browser split package is still required'
grep -Fq 'sudo pacman -Syu --needed --noconfirm' "$root_dir/scripts/install-system.sh" && fail 'system upgrades must not auto-decline package replacements'
grep -Fq 'Lumen tries its local repository first' "$root_dir/scripts/install-system.sh" || fail 'local-first update policy is missing'
grep -Fq 'update_with_local_repo_fallback()' "$root_dir/scripts/install-system.sh" || fail 'system update has no local-repository fallback'
grep -Fq 'retrying with official repositories' "$root_dir/scripts/install-system.sh" || fail 'local repository fallback is not explained'
grep -Fq 'sudo pacman -Syyu --needed' "$root_dir/scripts/install-system.sh" || fail 'local repository is not attempted first'
grep -Fq 'run "$repo_dir/scripts/install-system.sh"' "$root_dir/home/.config/lumen/bin/lumenctl" || fail 'Control Center does not delegate system updates to the guarded installer'
! grep -Fq 'run sudo pacman -Syu' "$root_dir/home/.config/lumen/bin/lumenctl" || fail 'Control Center still bypasses the guarded system updater'
grep -Fq 'sed -i "/^LocalFileSigLevel = /a $include_line" /etc/pacman.conf' "$root_dir/system/usr/lib/lumen/lumen-repo-sync" || fail 'local repository is not restored to priority position'
grep -Fxq 'nftables' "$root_dir/profiles/base/packages.pacman" || fail 'nftables is not part of the base profile'
test -x "$root_dir/system/usr/lib/lumen/lumen-network-guard" || fail 'network guard helper is missing'
test -x "$root_dir/system/usr/lib/lumen/lumen-network-guard-system" || fail 'network guard root helper is missing'
grep -q 'policy drop' "$root_dir/system/etc/nftables.conf" || fail 'firewall does not default-deny inbound traffic'
grep -q 'network guard' "$root_dir/system/usr/local/bin/lumen" || fail 'network guard is not exposed through the Lumen CLI'
grep -q 'lumen network guard idle' "$root_dir/home/.config/hypr/hypridle.conf" || fail 'network guard is not bound to idle lock state'
grep -q 'pause \[minutes\]' "$root_dir/system/usr/lib/lumen/lumen-network-guard" || fail 'network guard cannot be temporarily paused'
test -x "$root_dir/system/usr/lib/lumen/lumen-theme" || fail 'theme helper is missing'
grep -q 'theme <command>' "$root_dir/system/usr/local/bin/lumen" || fail 'theme engine is not exposed through the Lumen CLI'
grep -q 'fastfetch' "$root_dir/home/.zshrc" || fail 'interactive shell does not show Fastfetch'
grep -q 'Lumen Arch' "$root_dir/home/.config/fastfetch/config.jsonc" || fail 'Fastfetch does not brand the OS as Lumen Arch'
grep -q 'Theme Studio' "$root_dir/home/.config/lumen/bin/lumenctl" || fail 'Control Center has no Theme Studio'
grep -q '^\[general\]$' "$root_dir/home/.config/alacritty/alacritty.toml" || fail 'Alacritty uses deprecated top-level import'
grep -q 'import "qs/Commons" as LumenCommons' "$root_dir/home/.config/quickshell/lumen/shell.qml" || fail 'Quickshell theme import is not local and resolvable'

printf 'Control Center regression tests passed.\n'
