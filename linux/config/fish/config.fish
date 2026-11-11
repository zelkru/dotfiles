if status is-interactive
    # Over SSH the client's TERM may have no terminfo here (COLORTERM is not forwarded either)
    if set -q SSH_CONNECTION
        infocmp $TERM >/dev/null 2>&1; or set -gx TERM xterm-256color
        set -q COLORTERM; or set -gx COLORTERM truecolor
    end
    set -g fish_greeting
    fish_add_path ~/.local/bin

    if test -x ~/.local/bin/mise
        ~/.local/bin/mise activate fish | source
    end
    if type -q starship
        starship init fish | source
    end
    if type -q zoxide
        zoxide init fish | source
    end

    # Ash palette, same as the VS Code theme and the Windows profile
    set -g fish_color_command 6a9fb5
    set -g fish_color_param f4bf75
    set -g fish_color_quote 90a959
    set -g fish_color_operator aa759f
    set -g fish_color_keyword aa759f
    set -g fish_color_redirection aa759f
    set -g fish_color_end aa759f
    set -g fish_color_error d06060
    set -g fish_color_comment 7f7f7f
    set -g fish_color_normal d8d8d8
    set -g fish_color_autosuggestion 6b6b6b
    set -g fish_color_valid_path --underline

    alias ff fastfetch
    function dev; cd ~/dev; end
    function ep; code ~/.config/fish/config.fish; end
    set -q EDITOR; or set -gx EDITOR "code --wait"
end
