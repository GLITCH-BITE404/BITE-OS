#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS  ·  © 2026 GLITCH-BITE404  ·  // THE SYSTEM BIT YOU
#  https://github.com/GLITCH-BITE404/BITE-OS  ·  GPLv3 — keep this notice
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BITE-OS Spaceship chooser — pops a fuzzel menu asking HOW hard to push the CPU
# when you engage the rocket (power-profiles-daemon performance profile).
# Called by ppd-spaceship-watch.sh. Can also be run standalone to re-pick.
set -u

HELPER="/usr/local/bin/bite-spaceship-power"

choice=$(printf '%s\n' \
    "🚀  Max on demand   ·  instant full speed, idles down (low usage)" \
    "🔥  Pinned max 24/7  ·  cores locked at max, runs hot, true battery waster" \
    | fuzzel --dmenu --prompt "🛸 SPACESHIP ▸ " --lines 2 --width 64)

case "$choice" in
    "🚀"*) mode=ondemand; label="Max on demand · idle stays low" ;;
    "🔥"*) mode=pinned;   label="Pinned max 24/7 · battery be damned" ;;
    *)     exit 0 ;;   # dismissed (Esc) — leave whatever PPD set, change nothing
esac

sudo -n "$HELPER" "$mode"
scxctl switch -s scx_lavd -m gaming 2>/dev/null
command -v notify-send >/dev/null 2>&1 && notify-send -a "BITE-OS" -t 4500 "🛸 SPACESHIP — engaged" "$label"
