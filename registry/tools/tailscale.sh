# tailscale - VPN mesh
TOOL_ID=tailscale
TOOL_DESC="VPN mesh (WireGuard)"
TOOL_BIN=tailscale
TOOL_TYPE=cli
TOOL_MIN_VERSION="1.50"
TOOL_VERSION_CMD="tailscale version"
TOOL_PKG_ARCH=tailscale
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_DEBIAN_SETUP=setup_tailscale_debian
TOOL_POST_INSTALL=tailscale_post_install
TOOL_AUTH_CHECK="tailscale status"
TOOL_OPTIONAL=1
TOOL_HOMEPAGE="https://tailscale.com"
TOOL_NOTES="Autenticacao interativa: sudo tailscale up."
