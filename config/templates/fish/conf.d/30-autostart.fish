# -----------------------------------------------------
# AUTOSTART
# -----------------------------------------------------

if status is-interactive
    if test ! -f "$HOME/.config/ml4w/settings/hide-fastfetch"
        if test -n "$KITTY_WINDOW_ID"; and command -q rustmon
            set -l term_value xterm-256color
            set -l colorterm_value truecolor
            if set -q TERM
                set term_value "$TERM"
            end
            if set -q COLORTERM
                set colorterm_value "$COLORTERM"
            end
            env -u NO_COLOR TERM="$term_value" COLORTERM="$colorterm_value" rustmon print --name random --shiny 0.2
            printf '\n'
            env -u NO_COLOR fastfetch --logo none
        else
            fastfetch
        end
    end
end
