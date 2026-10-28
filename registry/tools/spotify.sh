# spotify - musica
TOOL_ID=spotify
TOOL_DESC="Spotify (GUI)"
TOOL_BIN=
TOOL_TYPE=gui
TOOL_VERIFY_CMD="command -v spotify >/dev/null 2>&1 || command -v spotify-launcher >/dev/null 2>&1 || flatpak info com.spotify.Client >/dev/null 2>&1"
TOOL_PKG_ARCH=spotify-launcher
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_FLATPAK=com.spotify.Client
TOOL_PROFILES=flow-gui
TOOL_HOMEPAGE="https://www.spotify.com"

# Arch instala spotify-launcher pelo repo. Debian/Ubuntu dependem de flatpak,
# que nao vem por padrao: manual.
TOOL_MANUAL_DEBIAN=1
TOOL_MANUAL_HINT_ARCH="sudo pacman -S spotify-launcher"
TOOL_MANUAL_HINT_DEBIAN="flatpak install flathub com.spotify.Client"
TOOL_MANUAL_DOC="docs/manual-installs.md#spotify"
TOOL_NOTES="GUI opcional; nao afeta o workflow de terminal."
