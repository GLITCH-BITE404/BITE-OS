if status is-interactive
    # ---- Branding & Core ----
    # Starship custom prompt
    starship init fish | source

    # ---- Tools & Hooks ----
    # Direnv + Zoxide
    command -v direnv &> /dev/null && direnv hook fish | source
    command -v zoxide &> /dev/null && zoxide init fish --cmd cd | source

    # ---- Aliases & Abbreviations ----
    # Better ls using eza (Industry standard for riced systems)
    alias ls='eza --icons --group-directories-first -1'
    
    # ⚡ THE OVERRIDES ⚡
    # These force the Gacha engine even when you type the standard commands
    alias ff='bash ~/.config/glitch/bin/glitch-fetch.sh'
    alias fastfetch='bash ~/.config/glitch/bin/glitch-fetch.sh'
    
    # Git shortcuts for fast commits
    abbr lg 'lazygit'
    abbr gd 'git diff'
    abbr ga 'git add .'
    abbr gc 'git commit -am'
    abbr gl 'git log'
    abbr gs 'git status'
    abbr gst 'git stash'
    abbr gsp 'git stash pop'
    abbr gp 'git push'
    abbr gpl 'git pull'
    abbr gsw 'git switch'
    abbr gsm 'git switch main'
    abbr gb 'git branch'
    abbr gbd 'git branch -d'
    abbr gco 'git checkout'
    abbr gsh 'git show'

    # Navigation & List shortcuts
    abbr l 'ls'
    abbr ll 'ls -l'
    abbr la 'ls -a'
    abbr lla 'ls -la'
    abbr tree 'eza --tree --icons --level=2'

    # ---- Aesthetic & Theme ----
    # Custom colors from Caelestia
    cat ~/.local/state/caelestia/sequences.txt 2> /dev/null

    # Jump between prompts in foot terminal
    function mark_prompt_start --on-event fish_prompt
        echo -en "\e]133;A\e\\"
    end
    
    # Load user-specific Caelestia mods
    source ~/.config/caelestia/user-config.fish 2> /dev/null

    # ─────────────────────────────────────────────────────────────────────────────
    #  GLITCH-BITE404 ENGINE :: Gacha Executor
    # ─────────────────────────────────────────────────────────────────────────────
    set -g __glitch_script "$HOME/.config/glitch/bin/glitch-fetch.sh"

    function __glitch_fetch_run
        env $argv bash $__glitch_script
        set -g __glitch_dirty 0
    end

    # Any command the user hits enter on marks the screen "dirty" — the
    # WINCH handler won't redraw fetch over real command output. Typing
    # `clear` is the explicit reset back to a fetch-only screen.
    function __glitch_mark_dirty --on-event fish_postexec
        if test "$argv[1]" = clear
            set -g __glitch_dirty 0
        else
            set -g __glitch_dirty 1
        end
    end

    if test -f $__glitch_script
        # Force a fresh gacha roll on each new fish session; resize redraws
        # later in this session reuse the cached pick.
        __glitch_fetch_run GLITCH_FRESH_ROLL=1
    else
        echo (set_color red)"[!] Master, glitch-fetch.sh not found in bin."(set_color normal)
    end

    # On resize: re-run glitch-fetch so the sixel logo + info box rescale
    # to the new terminal dimensions. A drag-resize fires many WINCHes, so
    # we debounce — each WINCH bumps a sequence number and schedules a
    # 0.35s deferred SIGUSR1; only the latest sequence's signal fires, so
    # exactly one fetch is drawn after the user stops dragging.
    set -g __glitch_resize_seq 0
    set -g __glitch_resize_seqfile "/tmp/glitch-resize-$fish_pid.seq"

    function __glitch_on_resize --on-signal WINCH
        set -g __glitch_resize_seq (math $__glitch_resize_seq + 1)
        set -l seq $__glitch_resize_seq
        echo $seq > $__glitch_resize_seqfile
        sh -c "sleep 0.35; [ \"\$(cat $__glitch_resize_seqfile 2>/dev/null)\" = '$seq' ] && kill -USR1 $fish_pid" &
        disown 2>/dev/null
    end

    function __glitch_do_redraw --on-signal SIGUSR1
        # Only redraw if the screen is still fetch-only. If the user has
        # run any command, leave their output alone — they don't want a
        # fetch dropped on top of it.
        if test "$__glitch_dirty" = 0 -a -f $__glitch_script
            clear
            __glitch_fetch_run
        end
        commandline -f repaint
    end
end
