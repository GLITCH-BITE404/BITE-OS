#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS  ·  © 2026 GLITCH-BITE404  ·  // THE SYSTEM BIT YOU
#  https://github.com/GLITCH-BITE404/BITE-OS  ·  GPLv3 — keep this notice
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BITE-OS spaceship watcher — watches the power-profiles-daemon profile (the bar's
# lightning / scales / ROCKET buttons). When you hit the rocket (performance), it
# pops the spaceship chooser (fuzzel) asking which max mode. Balanced / power-saver
# wind the CPU back down. Lives independently of caelestia's QML (which gets
# restored on shell restart), so it survives. Launch via hypr exec-once.
set -u

# single instance — kill any older watcher so we don't double-poll / double-popup
for pid in $(pgrep -f "ppd-spaceship-watch.sh" 2>/dev/null); do
    [ "$pid" != "$$" ] && kill "$pid" 2>/dev/null
done

HELPER="/usr/local/bin/bite-spaceship-power"
CHOOSER="$HOME/.config/hypr/scripts/spaceship-choose.sh"

apply() {  # $1 = profile, $2 = interactive? (1 pops the chooser, 0 = silent default)
    case "$1" in
        performance)
            if [ "${2:-0}" = 1 ]; then
                "$CHOOSER"                                   # ask: on-demand vs pinned
            else
                sudo -n "$HELPER" ondemand                   # login default: silent on-demand
                scxctl switch -s scx_lavd -m gaming 2>/dev/null
            fi
            ;;
        *)  # balanced / power-saver
            sudo -n "$HELPER" off
            scxctl switch -s scx_lavd -m auto 2>/dev/null
            ;;
    esac
}

# apply current state once, silently (no popup on login)
last="$(powerprofilesctl get 2>/dev/null)"
apply "$last" 0

# poll for user-initiated changes
while true; do
    cur="$(powerprofilesctl get 2>/dev/null)"
    if [ -n "$cur" ] && [ "$cur" != "$last" ]; then
        apply "$cur" 1
        last="$cur"
    fi
    sleep 1
done
