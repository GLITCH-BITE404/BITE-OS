#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS — one-shot: verify changes → build local repo → build the ISO
#  // THE SYSTEM BIT YOU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Runs the whole pipeline in the right order with the right privileges:
#   1. PRE-FLIGHT  — confirm this tree actually contains the 2026-06-26 fixes
#                    (apps, browser/editor, Super+W, cursor, fastfetch+fish,
#                    kiosk verify guard). Aborts if the tree is stale.
#   2. build-repo  — as YOUR user (makepkg/paru refuse root): rebuilds the
#                    bite-os package + the AUR set incl. vscodium-bin.
#   3. build-iso   — via sudo: overlays iso/ onto releng + runs mkarchiso.
#   4. report      — prints the ISO path, size and SHA256.
#
# Run as your normal user (it will sudo for the ISO step only):
#     bash build-all.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -uo pipefail

DISTRO="$(cd "$(dirname "$0")" && pwd)"
cd "$DISTRO"

c_g=$'\e[32m'; c_r=$'\e[31m'; c_y=$'\e[33m'; c_b=$'\e[1m'; c_0=$'\e[0m'
ok()   { printf '  %s✓%s %s\n'  "$c_g" "$c_0" "$1"; }
bad()  { printf '  %s✗%s %s\n'  "$c_r" "$c_0" "$1"; FAIL=1; }
step() { printf '\n%s==> %s%s\n' "$c_b" "$1" "$c_0"; }

# --- 0. must be a normal user (build-repo can't run as root) ------------------
if [ "$(id -u)" -eq 0 ]; then
    echo "${c_r}Run as your normal user, not root.${c_0} build-repo needs makepkg/paru" >&2
    echo "(which refuse root). This script sudo's only for the ISO step." >&2
    exit 1
fi

# --- 1. PRE-FLIGHT: are this session's changes present? -----------------------
step "Pre-flight: verifying the 2026-06-26 changes are in this tree"
FAIL=0
P=pkg/bite-os/payload/skel/.config/hypr

# apps added to the install list
for p in foot vscodium-bin eza zoxide direnv; do
    grep -qxF "$p" iso/packages.x86_64 && ok "packages.x86_64 has $p" || bad "packages.x86_64 MISSING $p"
done
# vscodium-bin must also be in the AUR build list or it won't be in the repo
grep -qxF vscodium-bin repo/foreign-packages.txt && ok "foreign-packages.txt has vscodium-bin" \
    || bad "foreign-packages.txt MISSING vscodium-bin (repo build won't produce it)"
# rice fixes
grep -qE '^\$browser = firefox' "$P/variables.conf"        && ok "browser -> firefox" || bad "variables.conf browser not firefox"
grep -qF 'caelestia toggle wallpaper' "$P/hyprland/keybinds.conf" && ok "Super+W -> wallpaper picker" || bad "keybinds.conf Super+W not rebound"
# cursor (set via customize, NOT the package — default-cursors owns the file) + pkgrel bump
grep -qE '^pkgrel=([7-9]|[1-9][0-9]+)$' pkg/bite-os/PKGBUILD && ok "PKGBUILD pkgrel bumped (>=7)" || bad "PKGBUILD pkgrel not bumped (>=7) — pacman won't see the new pkg"
grep -qF 'Inherits=Bibata-Modern-Classic' iso/airootfs/root/customize_airootfs.sh && ok "customize sets Bibata default cursor" || bad "customize_airootfs missing the Bibata cursor block"
if grep -qF 'install -Dm644 cursor/index.theme' pkg/bite-os/PKGBUILD; then
    bad "PKGBUILD still installs the cursor — WILL CONFLICT with default-cursors and break the build (remove it)"
else
    ok "PKGBUILD does not own the cursor (no default-cursors conflict)"
fi
# fastfetch / fish wiring
[ -f "$P/../fastfetch/config.jsonc" ] && ok "skel fastfetch config present" || bad "skel fastfetch config MISSING"
[ -f "$P/../fastfetch/bite-os.txt" ]  && ok "skel ASCII logo (bite-os.txt) present" || bad "skel bite-os.txt MISSING (TTY fallback)"
[ -f pkg/bite-os/payload/skel/.config/fish/functions/fish_greeting.fish ] && ok "skel fish_greeting present" || bad "skel fish_greeting MISSING"
[ -f iso/airootfs/usr/share/bite-os/skel-config.fish ] && ok "fish config overlay asset present" || bad "skel-config.fish overlay MISSING"
grep -qF 'skel-config.fish' iso/airootfs/root/customize_airootfs.sh && ok "customize drops fish config into /etc/skel" || bad "customize_airootfs missing the fish-config step"
# IMPORTANT: config.fish must NOT be in the package skel (cachyos-fish-config owns that path -> build conflict)
if [ -f pkg/bite-os/payload/skel/.config/fish/config.fish ]; then
    bad "package skel still has config.fish — WILL CONFLICT with cachyos-fish-config and break the build (remove it)"
else
    ok "package skel has no conflicting config.fish"
fi
# kiosk verify guard
[ -f iso/airootfs/usr/local/bin/bite-os-verify-install ] && ok "bite-os-verify-install script present" || bad "bite-os-verify-install MISSING"
grep -qF 'bite-os-verify-install' iso/profiledef.sh && ok "profiledef makes verify-install executable" || bad "profiledef missing verify-install perms (would ship non-executable)"
grep -qF 'bite-os-verify-install' iso/airootfs/root/customize_airootfs.sh && ok "customize injects the verify step" || bad "customize_airootfs missing verify injection"

if [ "$FAIL" -ne 0 ]; then
    echo
    echo "${c_r}Pre-flight failed — this tree is missing some changes.${c_0}"
    echo "If you're on a different machine, sync first (e.g. git pull), then re-run."
    exit 1
fi
echo "${c_g}All changes present.${c_0}"

# --- 2. prereqs ---------------------------------------------------------------
step "Checking build prerequisites"
command -v makepkg >/dev/null || { echo "${c_r}missing base-devel (makepkg)${c_0}" >&2; exit 1; }
command -v paru    >/dev/null || { echo "${c_r}missing paru (needed for AUR pkgs)${c_0}" >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "${c_r}missing archiso — sudo pacman -S archiso${c_0}" >&2; exit 1; }
ok "makepkg, paru, mkarchiso found"

# --- 3. build the local repo (as this user) -----------------------------------
step "Building local [bite-os] repo (bite-os pkg + AUR incl. vscodium-bin — this is the slow part)"
bash repo/build-repo.sh

# repo must contain the freshly-bumped bite-os pkg + vscodium-bin
[ -f repo/x86_64/bite-os.db.tar.gz ] || { echo "${c_r}repo db not built — see build-repo.sh output above${c_0}" >&2; exit 1; }
ls repo/x86_64/bite-os-1.1-7-*.pkg.tar.* >/dev/null 2>&1 \
    && ok "bite-os 1.1-7 in repo" \
    || echo "${c_y}  ! warning: bite-os 1.1-7 not found in repo — check the makepkg output${c_0}"
ls repo/x86_64/vscodium-bin-*.pkg.tar.* >/dev/null 2>&1 \
    && ok "vscodium-bin in repo" \
    || echo "${c_y}  ! warning: vscodium-bin not in repo — Super+C editor won't be installed${c_0}"

# --- 4. build the ISO (needs root) --------------------------------------------
step "Building the ISO (sudo — needs root for mkarchiso)"
BUILD_START=$(date +%s)
if ! sudo bash build-iso.sh; then
    echo "${c_r}ISO build FAILED — see the mkarchiso output above. No new ISO produced.${c_0}" >&2
    exit 1
fi

# --- 5. report ----------------------------------------------------------------
# Must be a FRESH iso (newer than the build start) — guards against reporting a
# stale out/*.iso when mkarchiso bailed but somehow returned 0.
ISO="$(ls -t out/*.iso 2>/dev/null | head -1)"
step "Done"
if [ -n "$ISO" ] && [ "$(stat -c %Y "$ISO" 2>/dev/null || echo 0)" -ge "$BUILD_START" ]; then
    echo "  ISO:    $ISO"
    echo "  Size:   $(du -h "$ISO" | cut -f1)"
    echo "  SHA256: $(sha256sum "$ISO" | cut -d' ' -f1)"
    echo
    echo "  Next: boot it in a VM. After installing, before rebooting out, grab"
    echo "        /mnt/var/log/bite-os-install.log (or /tmp/calamares.log) to confirm"
    echo "        the user account + password were created."
else
    echo "${c_r}  Build returned success but there's no FRESH ISO in out/ — treat as FAILED.${c_0}" >&2
    exit 1
fi
