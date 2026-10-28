# bitwarden-app - aplicativo desktop
TOOL_ID=bitwarden-app
TOOL_DESC="Bitwarden desktop"
TOOL_BIN=
TOOL_TYPE=gui
TOOL_VERIFY_CMD="flatpak info com.bitwarden.desktop >/dev/null 2>&1 || command -v bitwarden >/dev/null 2>&1"
TOOL_PKG_ARCH=bitwarden
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_FLATPAK=com.bitwarden.desktop
TOOL_INTERACTIVE=1
TOOL_HOMEPAGE="https://bitwarden.com/download/"

# Arch usa o pacote nativo. Debian/Ubuntu dependem de flatpak: manual.
TOOL_MANUAL_DEBIAN=1
TOOL_MANUAL_HINT_ARCH="sudo pacman -S bitwarden"
TOOL_MANUAL_HINT_DEBIAN="flatpak install flathub com.bitwarden.desktop"
TOOL_MANUAL_DOC="docs/manual-installs.md#bitwarden-app-desktop"
TOOL_NOTES="O CLI (bw) continua automatico e independente do app."
