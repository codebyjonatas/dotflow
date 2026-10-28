# ghostty - terminal
TOOL_ID=ghostty
TOOL_DESC="Terminal GPU"
TOOL_BIN=ghostty
TOOL_TYPE=gui
TOOL_VERSION_CMD="ghostty --version"
TOOL_PKG_ARCH=ghostty
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_CONFIG_PATHS="~/.config/ghostty"
TOOL_HOMEPAGE="https://ghostty.org"

# Arch instala pelo repo (automatico). Debian/Ubuntu nao tem pacote oficial e
# PPA comunitario ficou fora do fluxo padrao: vira pendencia manual.
TOOL_MANUAL_DEBIAN=1
TOOL_MANUAL_HINT_ARCH="sudo pacman -S ghostty"
TOOL_MANUAL_HINT_DEBIAN="sem pacote oficial; compile do fonte seguindo https://ghostty.org/docs/install/build"
TOOL_MANUAL_DOC="docs/manual-installs.md#ghostty"
TOOL_NOTES="Config via Stow e inofensiva sem o binario."
