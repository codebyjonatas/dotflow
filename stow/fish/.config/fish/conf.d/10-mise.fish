# mise: ativa shims apenas se o binario existir
if command -q mise
    mise activate fish | source
end
