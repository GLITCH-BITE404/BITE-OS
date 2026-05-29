#!/usr/bin/env bash
# ━━━ BITE-OS — wallpaper restore ━━━
# hypr autostart launches `awww-daemon`, but a bare daemon paints nothing —
# the screen stays black until something runs `awww img`. This re-applies the
# last wallpaper you picked, or the shipped BITE-OS default on a fresh user
# (the live ISO, or a freshly installed system on its first login).
set -uo pipefail

CACHE="$HOME/.cache/quickshell/wallpaper_picker/current_wallpaper.png"
DEFAULT="$HOME/.config/glitch/wallpapers/bite-os-default.png"

# Wait for the wallpaper daemon to accept connections (~6s max).
for _ in $(seq 1 30); do
    awww query >/dev/null 2>&1 && break
    sleep 0.2
done

WALL="$DEFAULT"
[[ -f "$CACHE" ]] && WALL="$CACHE"
[[ -f "$WALL" ]] || exit 0

awww img "$WALL" \
    --transition-type fade --transition-fps 144 --transition-duration 1 \
    >/dev/null 2>&1 || true
exit 0
