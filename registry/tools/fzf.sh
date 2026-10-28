# fzf - fuzzy finder
TOOL_ID=fzf
TOOL_DESC="Fuzzy finder"
TOOL_BIN=fzf
TOOL_TYPE=cli
TOOL_MIN_VERSION="0.48"
TOOL_VERSION_CMD="fzf --version"
TOOL_PKG_ARCH=fzf
TOOL_PKG_DEBIAN=fzf
TOOL_PKG_FEDORA=fzf
# Ubuntu 24.04 traz 0.44, que nao tem 'fzf --fish'; release oficial cobre isso.
TOOL_CUSTOM=install_fzf_release
TOOL_HOMEPAGE="https://github.com/junegunn/fzf"
TOOL_NOTES="Integracao com fish via 'fzf --fish | source' (requer >= 0.48)."
