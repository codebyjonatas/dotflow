# ~/.config/fish/config.fish - gerenciado pelo dotflow (GNU Stow)

if status is-interactive
    set -g fish_greeting
end

# Editor e paginacao
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SUDO_EDITOR nvim
set -gx PAGER less

# Binarios do usuario (releases, npm --prefix, cargo)
if test -d $HOME/.local/bin
    fish_add_path --global --move $HOME/.local/bin
end

# Fallback do instalador oficial do OpenCode (o caminho normal e ~/.local/bin)
if test -d $HOME/.opencode/bin
    fish_add_path --global --move $HOME/.opencode/bin
end

# Prompt
if command -q starship
    starship init fish | source
end

# Navegacao
if command -q zoxide
    zoxide init fish | source
end

# fzf (keybindings e completion)
if command -q fzf
    fzf --fish 2>/dev/null | source
end

# Yazi como file manager principal: cd ao sair
function y
    set tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if set cwd (cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        cd -- "$cwd"
    end
    rm -f -- "$tmp"
end
