# -----------------------------------------------------
# AUTOSTART
# -----------------------------------------------------

if status is-interactive
    if test ! -f "$HOME/.config/ml4w/settings/hide-fastfetch"
        set -l show_fastfetch 1
        if set -q TMUX TMUX_PANE; and command -q tmux
            set -l fastfetch_shown (tmux show-options -qv -t "$TMUX_PANE" @ml4w_fastfetch_shown 2>/dev/null)
            if test "$fastfetch_shown" = 1
                set show_fastfetch 0
            else
                tmux set-option -q -t "$TMUX_PANE" @ml4w_fastfetch_shown 1 >/dev/null 2>&1
            end
        end

        if test "$show_fastfetch" = 1
            if test -n "$KITTY_WINDOW_ID"; and command -q rustmon
                set -l term_value xterm-256color
                set -l colorterm_value truecolor
                set -l rustmon_logo "$HOME/.cache/rustmon/fastfetch-logo.ansi"
                if set -q TERM
                    set term_value "$TERM"
                end
                if set -q COLORTERM
                    set colorterm_value "$COLORTERM"
                end
                mkdir -p "$HOME/.cache/rustmon"
                env -u NO_COLOR TERM="$term_value" COLORTERM="$colorterm_value" rustmon print --name random --shiny 0.2 --hide-name > "$rustmon_logo"
                env -u NO_COLOR fastfetch --file-raw "$rustmon_logo" --logo-padding-left 0 --logo-padding-right 2 --logo-padding-top 0 --logo-print-remaining false
            else
                fastfetch
            end
        end
    end
end
