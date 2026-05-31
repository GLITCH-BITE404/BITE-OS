#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS  ·  © 2026 GLITCH-BITE404  ·  // THE SYSTEM BIT YOU
#  https://github.com/GLITCH-BITE404/BITE-OS  ·  GPLv3 — keep this notice
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BITE-OS Spaceship chooser — fuzzel menu asking HOW hard to push the CPU when
# the rocket (power-profiles-daemon performance profile) is engaged.
# Called by ppd-spaceship-watch.sh; can also be run standalone to re-pick.
set -u

HELPER="/usr/local/bin/bite-spaceship-power"

choice="$(printf '%s\n' \
    "🚀  Max on demand   ·  instant full speed, idles down (low usage)" \
    "🔥  Pinned max 24/7  ·  cores locked at max, runs hot, true battery waster" \
    | fuzzel --dmenu --prompt "🛸 SPACESHIP ▸ " --lines 2 --width 64 2>/dev/null)"

# Match on keywords, not the emoji (more robust than multibyte glob prefixes).
case "$choice" in
    *"on demand"*) mode=ondemand; label="Max on demand · idle stays low" ;;
    *Pinned*)      mode=pinned;   label="Pinned max 24/7 · battery be damned" ;;
    *)             exit 0 ;;   # dismissed (Esc) — change nothing
esac

sudo -n "$HELPER" "$mode" 2>/dev/null || true
scxctl switch -s scx_lavd -m gaming 2>/dev/null || true
command -v notify-send >/dev/null 2>&1 && notify-send -a "BITE-OS" -t 4500 "🛸 SPACESHIP — engaged" "$label"
