# opencode - agente de codigo no terminal
TOOL_ID=opencode
TOOL_DESC="Agente de codigo no terminal"
TOOL_BIN=opencode
TOOL_TYPE=tui
TOOL_MIN_VERSION="1.0"
TOOL_VERSION_CMD="opencode --version"
TOOL_PKG_ARCH=opencode
TOOL_AUR_ARCH=opencode-bin
TOOL_CUSTOM=install_opencode_npm
TOOL_VERSION_PIN=2.1.4
TOOL_CONFIG_PATHS="~/.config/opencode"
TOOL_HOMEPAGE="https://opencode.ai"

# Debian/Ubuntu nao tem pacote. O caminho deterministico e o tarball npm
# @opencode/cli-<target> com verificacao de integrity (sha512), instalado
# em ~/.local/bin. O instalador oficial fica como fallback (--no-modify-path).
TOOL_NOTES="Nunca use o pacote npm opencode-ai (OpenCode 1) nem os .deb do app desktop."
