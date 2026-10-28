# leaf - visualizador de markdown no terminal
TOOL_ID=leaf
TOOL_DESC="Visualizador TUI de markdown"
TOOL_BIN=leaf
TOOL_TYPE=tui
TOOL_VERSION_CMD="leaf --version"
TOOL_PKG_ARCH=
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_AUR_ARCH=leaf-markdown-viewer-bin
TOOL_HOMEPAGE="https://github.com/RivoLink/leaf"

# Arch usa AUR (automatico). Fora do Arch exigiria compilar Rust: manual.
TOOL_MANUAL_DEBIAN=1
TOOL_MANUAL_HINT_ARCH="paru -S leaf-markdown-viewer-bin"
TOOL_MANUAL_HINT_DEBIAN="cargo install --git https://github.com/RivoLink/leaf --locked"
TOOL_MANUAL_DOC="docs/manual-installs.md#leaf"
TOOL_NOTES="Compilacao nao entra no fluxo padrao."
