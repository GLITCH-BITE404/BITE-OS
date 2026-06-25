#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ BITE-OS  ·  © 2026 GLITCH-BITE404  ·  // THE SYSTEM BIT YOU
#  https://github.com/GLITCH-BITE404/BITE-OS  ·  GPLv3 — keep this notice
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# BITE-OS Glitch Mode — toggle bound to Super+B.
#
# Engage:
#   1. Two fangs slam in from top + bottom and bite the screen.
#   2. Glitch shader engages, dedsec video wallpaper kicks in, larp-hacker
#      restyle of borders and gaps, amber HUD spawns.
#   3. A popup loop pops ONE thing at a time at random — skull flash OR a
#      hacking terminal you can close — with breathing room between.
#
# Disengage restores the exact pre-engagement state: shader cleared, damage
# tracking restored, wallpaper restored, every bite window killed, original
# border/gap colour restored.

set -u

CACHE_DIR="$HOME/.cache/bite-os"
STATE="$CACHE_DIR/glitch.state"
WALL_BACKUP="$CACHE_DIR/pre-glitch-wall"
HUD_PIDFILE="$CACHE_DIR/glitch-hud.pid"
POPUP_PIDFILE="$CACHE_DIR/glitch-popup.pid"
SHADER="$HOME/.config/hypr/shaders/bite-glitch.frag"
HUD_SCRIPT="$HOME/.config/hypr/scripts/glitch-hud.fish"
POPUP_SCRIPT="$HOME/.config/hypr/scripts/glitch-popup-loop.sh"
WALLPAPER_SH="$HOME/.config/hypr/scripts/wallpaper.sh"
HYPR_WALL_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr/wallpaper"
STAGE="$HOME/.bite-os-stage"

# Cursor: hacker-amber while glitched, restore the configured normal one on exit.
# Normal theme/size are read from variables.conf so there's one source of truth.
CURSOR_GLITCH="Bibata-Modern-Amber"
CURSOR_NORMAL="$(grep -oP '^\$cursorTheme\s*=\s*\K\S+' "$HOME/.config/hypr/variables.conf" 2>/dev/null || true)"
CURSOR_NORMAL="${CURSOR_NORMAL:-Bibata-Modern-Classic}"
CURSOR_SIZE="$(grep -oP '^\$cursorSize\s*=\s*\K\S+' "$HOME/.config/hypr/variables.conf" 2>/dev/null || true)"
CURSOR_SIZE="${CURSOR_SIZE:-24}"

mkdir -p "$CACHE_DIR"

find_glitch_wall() {
    for ext in mp4 webm gif png jpg; do
        local p="$STAGE/glitch-wallpaper.$ext"
        [[ -f "$p" ]] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

# Spawn a fangs window with a transparent surface — Hyprland's window-open
# animation slides it in (rule below forces 'slide'). Killed after $hold sec.
spawn_fang() {
    local class="$1" img="$2" hold="$3"
    setsid -f mpv --no-config --really-quiet --no-audio \
        --no-osc --no-osd-bar --no-input-default-bindings \
        --no-border --keep-open=yes --loop=inf \
        --image-display-duration=inf \
        --vo=gpu --alpha=yes --background=none \
        --wayland-app-id="$class" --x11-name="$class" --title="$class" \
        "$img" >/dev/null 2>&1
    ( sleep "$hold"; pkill -f -- "wayland-app-id=$class" 2>/dev/null ) &
}

play_bite() {
    local top="$STAGE/fangs_top.png"
    local bot="$STAGE/fangs_bottom.png"
    if [[ ! -f "$top" || ! -f "$bot" ]]; then
        # fallback to combined fangs.png
        local fb="$STAGE/fangs.png"
        [[ -f "$fb" ]] && spawn_fang bite-fangs-top "$fb" 1.0
        sleep 0.9
        return 0
    fi
    spawn_fang bite-fangs-top "$top" 1.1
    spawn_fang bite-fangs-bot "$bot" 1.1
    # Wait for the bite to complete + close animation
    sleep 1.0
}

# Swap foot's config to the hacker theme; reload running foot processes.
apply_foot_hacker() {
    local foot_dir="$HOME/.config/foot"
    [[ -f "$foot_dir/foot.ini.glitch" ]] || return 0
    [[ -f "$foot_dir/foot.ini" ]] && cp "$foot_dir/foot.ini" "$foot_dir/foot.ini.pre-glitch"
    cp "$foot_dir/foot.ini.glitch" "$foot_dir/foot.ini"
    # SIGUSR1 makes running foot processes reload their config in place
    pkill -USR1 -x foot 2>/dev/null || true
}

restore_foot() {
    local foot_dir="$HOME/.config/foot"
    if [[ -f "$foot_dir/foot.ini.pre-glitch" ]]; then
        mv -f "$foot_dir/foot.ini.pre-glitch" "$foot_dir/foot.ini"
        pkill -USR1 -x foot 2>/dev/null || true
    fi
}

# Save border + gap state, then apply hacker theme.
apply_hacker_rice() {
    # Snapshot current border colours and gaps so we can restore exactly.
    {
        hyprctl -j getoption general:col.active_border 2>/dev/null
        echo "---"
        hyprctl -j getoption general:col.inactive_border 2>/dev/null
        echo "---"
        hyprctl -j getoption general:gaps_in 2>/dev/null
        echo "---"
        hyprctl -j getoption general:gaps_out 2>/dev/null
        echo "---"
        hyprctl -j getoption decoration:rounding 2>/dev/null
    } > "$CACHE_DIR/pre-glitch-theme"

    hyprctl --batch "\
        keyword general:col.active_border rgba(39ff7aff) rgba(00ff41ff) 45deg ; \
        keyword general:col.inactive_border rgba(00330077) ; \
        keyword decoration:rounding 0 ; \
        keyword general:gaps_in 2 ; \
        keyword general:gaps_out 4" >/dev/null
}

restore_rice() {
    # Reload from config — clears every keyword override we set.
    hyprctl reload >/dev/null
    rm -f "$CACHE_DIR/pre-glitch-theme"
}

engage() {
    notify-send -u low -i dialog-warning-symbolic "BITE-OS" "// GLITCH MODE ENGAGED" 2>/dev/null || true

    # 1. The bite — fangs slam in top + bottom, then retract
    play_bite

    # 2. Glitch shader + dedsec wallpaper + hacker rice + foot recolor
    hyprctl keyword debug:damage_tracking 0 >/dev/null
    hyprctl keyword decoration:screen_shader "$SHADER" >/dev/null
    apply_hacker_rice
    apply_foot_hacker
    hyprctl setcursor "$CURSOR_GLITCH" "$CURSOR_SIZE" >/dev/null

    if wall="$(find_glitch_wall)"; then
        cur="$(cat "$HYPR_WALL_STATE" 2>/dev/null || true)"
        [[ -n "$cur" && -f "$cur" ]] && printf '%s\n' "$cur" > "$WALL_BACKUP"
        bash "$WALLPAPER_SH" "$wall" >/dev/null 2>&1 &
    fi

    # 3. Amber HUD (top-right, fixed)
    setsid -f kitty \
        --class bite-hud --title bite-hud \
        -o background_opacity=0.85 \
        -o background=#000000 \
        -o foreground=#ffcc00 \
        -o cursor_shape=block -o cursor_blink_interval=0 \
        -o font_size=10 -o window_padding_width=10 \
        -o confirm_os_window_close=0 \
        fish "$HUD_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$HUD_PIDFILE"

    echo on > "$STATE"

    # 4. Popup loop — one at a time, paced
    setsid -f bash "$POPUP_SCRIPT" >/dev/null 2>&1 &
    echo $! > "$POPUP_PIDFILE"
}

disengage() {
    rm -f "$STATE"   # signals popup loop to stop after current popup

    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    hyprctl keyword debug:damage_tracking 2 >/dev/null

    # Kill every bite-mode window class
    for cls in bite-chomp bite-fangs-top bite-fangs-bot bite-skull bite-hud \
               bite-hack-1 bite-hack-2 bite-hack-3 bite-hack-4; do
        pkill -f -- "wayland-app-id=$cls" 2>/dev/null || true
        pkill -f -- "kitty --class $cls" 2>/dev/null || true
    done

    for pf in "$HUD_PIDFILE" "$POPUP_PIDFILE"; do
        [[ -f "$pf" ]] && { kill "$(cat "$pf")" 2>/dev/null || true; rm -f "$pf"; }
    done

    # Restore wallpaper
    if [[ -f "$WALL_BACKUP" ]]; then
        prev="$(cat "$WALL_BACKUP")"
        [[ -f "$prev" ]] && bash "$WALLPAPER_SH" "$prev" >/dev/null 2>&1 &
        rm -f "$WALL_BACKUP"
    fi

    # Restore borders/gaps/rounding to their config defaults
    restore_rice
    restore_foot
    # hyprctl reload (in restore_rice) does NOT re-run the startup setcursor, so
    # restore the normal cursor explicitly.
    hyprctl setcursor "$CURSOR_NORMAL" "$CURSOR_SIZE" >/dev/null

    notify-send -u low -i dialog-information-symbolic "BITE-OS" "// glitch mode disengaged" 2>/dev/null || true
}

if [[ -f "$STATE" && "$(cat "$STATE")" == "on" ]]; then
    disengage
else
    engage
fi
