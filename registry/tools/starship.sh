# starship - prompt
TOOL_ID=starship
TOOL_DESC="Prompt minimalista e rapido"
TOOL_BIN=starship
TOOL_TYPE=cli
TOOL_MIN_VERSION="1.16"
TOOL_VERSION_CMD="starship --version"
TOOL_PKG_ARCH=starship
TOOL_PKG_DEBIAN=starship
TOOL_PKG_FEDORA=starship
# Ubuntu nao empacota starship: release oficial com checksum .sha256.
TOOL_CUSTOM=install_starship_release
TOOL_CONFIG_PATHS="~/.config/starship.toml"
TOOL_HOMEPAGE="https://starship.rs"
TOOL_NOTES="Debian/Ubuntu usam o binario oficial; sem compilar Rust."
