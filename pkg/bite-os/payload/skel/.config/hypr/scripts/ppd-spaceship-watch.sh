#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS  ·  © 2026 GLITCH-BITE404  ·  // THE SYSTEM BIT YOU
#  https://github.com/GLITCH-BITE404/BITE-OS  ·  GPLv3 — keep this notice
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BITE-OS spaceship watcher — watches power-profiles-daemon (the bar's lightning /
# scales / ROCKET buttons). Rocket (performance) -> pops the fuzzel chooser
# (on-demand vs pinned); balanced / power-saver wind the CPU back down. Runs
# standalone of caelestia's QML (which gets restored on shell restart), launched
# via hypr exec-once.
set -u

CACHE_DIR="$HOME/.cache/bite-os"
mkdir -p "$CACHE_DIR" 2>/dev/null

# Single instance — flock is race-proof (pgrep matching let duplicates through,
# which caused double fuzzel popups). Hold an exclusive lock for our lifetime;
# if another watcher already holds it, quietly exit.
exec 9>"$CACHE_DIR/spaceship-watch.lock" 2>/dev/null || exec 9>/tmp/bite-spaceship-watch.lock
flock -n 9 || exit 0

HELPER="/usr/local/bin/bite-spaceship-power"
CHOOSER="$HOME/.config/hypr/scripts/spaceship-choose.sh"

apply() {  # $1 = profile, $2 = interactive? (1 = pop chooser, 0 = silent default)
    case "$1" in
        performance)
            if [ "${2:-0}" = 1 ] && [ -x "$CHOOSER" ]; then
                "$CHOOSER"
            else
                sudo -n "$HELPER" ondemand 2>/dev/null || true
                scxctl switch -s scx_lavd -m gaming 2>/dev/null || true
            fi
            ;;
        ?*)  # any non-empty, non-performance profile (balanced / power-saver)
            sudo -n "$HELPER" off 2>/dev/null || true
            scxctl switch -s scx_lavd -m auto 2>/dev/null || true
            ;;
        *) : ;;  # empty = PPD not ready yet -> do nothing
    esac
}

# Wait up to ~30s for power-profiles-daemon to answer, then apply the current
# state SILENTLY (mode 0). This prevents the chooser from popping at every login
# just because PPD wasn't ready the instant the watcher started.
last=""
for _ in $(seq 1 30); do
    last="$(powerprofilesctl get 2>/dev/null)"
    [ -n "$last" ] && break
    sleep 1
done
apply "$last" 0

# Poll for user-initiated profile changes. Only treat a change as interactive
# (pop the chooser) when the PREVIOUS value was real — never on the empty->value
# transition at startup.
while true; do
    cur="$(powerprofilesctl get 2>/dev/null)"
    if [ -n "$cur" ] && [ -n "$last" ] && [ "$cur" != "$last" ]; then
        apply "$cur" 1
    fi
    [ -n "$cur" ] && last="$cur"
    sleep 1
done
