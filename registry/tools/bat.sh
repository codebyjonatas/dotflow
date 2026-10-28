# bat - cat com syntax highlight
TOOL_ID=bat
TOOL_DESC="cat com syntax highlight"
TOOL_BIN=bat
TOOL_TYPE=cli
TOOL_MIN_VERSION="0.22"
# Debian/Ubuntu instalam o binario como 'batcat' por conflito de nome.
TOOL_VERIFY_CMD="command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1"
TOOL_VERSION_CMD="bat --version 2>/dev/null || batcat --version"
TOOL_PKG_ARCH=bat
TOOL_PKG_DEBIAN=bat
TOOL_PKG_FEDORA=bat
TOOL_HOMEPAGE="https://github.com/sharkdp/bat"
TOOL_NOTES="No Debian/Ubuntu o binario chama-se batcat; o doctor aceita os dois."
