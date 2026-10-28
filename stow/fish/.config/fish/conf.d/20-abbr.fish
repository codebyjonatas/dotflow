# Abreviacoes (nao quebram scripts, ao contrario de alias)
if type -q eza
    abbr --add ls 'eza --icons --group-directories-first'
    abbr --add ll 'eza -lh --icons --group-directories-first'
    abbr --add la 'eza -lah --icons --group-directories-first'
    abbr --add lt 'eza --tree --level=2 --icons'
end

if type -q lazygit
    abbr --add lg lazygit
end

if type -q lazydocker
    abbr --add lzd lazydocker
end
