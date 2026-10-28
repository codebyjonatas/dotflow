#!/usr/bin/env bash
# lib/platform.sh - deteccao de distro e camada de gerenciador de pacotes.
[[ -n ${DOTFLOW_PLATFORM_SH:-} ]] && return 0
DOTFLOW_PLATFORM_SH=1

DOTFLOW_FAMILY=
DOTFLOW_DISTRO_ID=
DOTFLOW_DISTRO_LIKE=
DOTFLOW_DISTRO_VER=
DOTFLOW_CODENAME=
DOTFLOW_ARCH=
DOTFLOW_SUDO=()
DOTFLOW_APT_UPDATED=0

if [[ ${EUID:-0} -ne 0 ]] && command -v sudo >/dev/null 2>&1; then
  DOTFLOW_SUDO=(sudo)
fi

detect_platform() {
  local id= like= ver= code= pretty=
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id=${ID:-}; like=${ID_LIKE:-}; ver=${VERSION_ID:-}
    code=${VERSION_CODENAME:-}; pretty=${PRETTY_NAME:-}
  fi
  DOTFLOW_DISTRO_ID=$id
  DOTFLOW_DISTRO_LIKE=$like
  DOTFLOW_DISTRO_VER=$ver
  DOTFLOW_CODENAME=$code
  DOTFLOW_ARCH=$(uname -m)

  case " $id $like " in
    *arch*|*cachyos*|*endeavouros*|*manjaro*|*garuda*|*artix*) DOTFLOW_FAMILY=arch ;;
    *debian*|*ubuntu*|*linuxmint*|*pop*|*zorin*|*elementary*) DOTFLOW_FAMILY=debian ;;
    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*)             DOTFLOW_FAMILY=fedora ;;
    *)                                                       DOTFLOW_FAMILY=unknown ;;
  esac
  debug "distro=${pretty:-$id} family=$DOTFLOW_FAMILY arch=$DOTFLOW_ARCH codename=${code:-?}"
}

arch_tag() {
  case ${DOTFLOW_ARCH:-$(uname -m)} in
    x86_64|amd64)  echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *)             uname -m ;;
  esac
}

debian_arch() {
  case ${DOTFLOW_ARCH:-$(uname -m)} in
    x86_64)  echo amd64 ;;
    aarch64) echo arm64 ;;
    *)       echo "${DOTFLOW_ARCH}" ;;
  esac
}

pkg_is_installed() {
  local p=$1
  case $DOTFLOW_FAMILY in
    arch)   pacman -Qq "$p" >/dev/null 2>&1 ;;
    debian) dpkg -s "$p" >/dev/null 2>&1 ;;
    fedora) rpm -q "$p" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

pkg_available() {
  local p=$1
  case $DOTFLOW_FAMILY in
    arch)   pacman -Si "$p" >/dev/null 2>&1 ;;
    debian) apt-cache show "$p" >/dev/null 2>&1 ;;
    fedora) dnf -q list --available "$p" >/dev/null 2>&1 ;;
    *)      return 1 ;;
  esac
}

pkg_owner() {
  local path=${1:-}
  case $DOTFLOW_FAMILY in
    arch)   pacman -Qoq "$path" 2>/dev/null ;;
    debian) dpkg -S "$path" 2>/dev/null | cut -d: -f1 ;;
    fedora) rpm -qf "$path" 2>/dev/null ;;
    *)      return 1 ;;
  esac
}

apt_update_once() {
  [[ $DOTFLOW_FAMILY == debian ]] || return 0
  [[ $DOTFLOW_APT_UPDATED == 1 ]] && return 0
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] %s apt-get update\n' "${DOTFLOW_SUDO[*]}"
    DOTFLOW_APT_UPDATED=1
    return 0
  fi
  info "atualizando indices do apt (uma vez por execucao)"
  "${DOTFLOW_SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get update -qq \
    || { warn "apt-get update falhou"; return 1; }
  DOTFLOW_APT_UPDATED=1
}

pkg_install() {
  (($#)) || return 0
  case $DOTFLOW_FAMILY in
    arch)
      # --needed evita reinstalacao. Um upgrade completo e recomendado a parte.
      run "${DOTFLOW_SUDO[@]}" pacman -S --needed --noconfirm -- "$@"
      ;;
    debian)
      apt_update_once || return 1
      run "${DOTFLOW_SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends -- "$@"
      ;;
    fedora)
      run "${DOTFLOW_SUDO[@]}" dnf install -y -- "$@"
      ;;
    *)
      err "familia de distro nao suportada: ${DOTFLOW_FAMILY:-?}"
      return 1
      ;;
  esac
}

aur_install() {
  (($#)) || return 0
  [[ $DOTFLOW_FAMILY == arch ]] || return 1
  local helper=
  local h
  for h in paru yay; do
    command -v "$h" >/dev/null 2>&1 && { helper=$h; break; }
  done
  [[ -n $helper ]] || { warn "nenhum helper AUR (paru/yay) encontrado"; return 1; }
  run "$helper" -S --needed --noconfirm -- "$@"
}

flatpak_available() { command -v flatpak >/dev/null 2>&1; }

flatpak_ensure_remote() {
  flatpak_available || return 1
  if ! flatpak remotes --columns=name 2>/dev/null | grep -x flathub >/dev/null 2>&1; then
    info "adicionando remote flathub"
    run "${DOTFLOW_SUDO[@]}" flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo
  fi
}

flatpak_install() {
  local id=$1
  flatpak_ensure_remote || { warn "flatpak indisponivel"; return 1; }
  run flatpak install -y flathub "$id"
}

# Baixa e valida (quando ha checksum) um arquivo.
download_verify() {
  local url=$1 dest=$2 sha=${3:-}
  info "baixando $url"
  curl -fsSL --retry 3 --proto '=https' "$url" -o "$dest" \
    || { err "falha no download: $url"; return 1; }
  if [[ -n $sha ]]; then
    printf '%s  %s\n' "$sha" "$dest" | sha256sum -c - >/dev/null 2>&1 \
      || { err "checksum invalido: $url"; return 1; }
    debug "checksum ok: $(basename "$dest")"
  else
    warn "sem checksum para $(basename "$dest")"
  fi
}

# Instala um unico binario em ~/.local/bin.
install_single_binary() {
  local id=$1 url=$2 sha=${3:-} bin=${4:-$1}
  local tmp; tmp=$(mktemp -d) || return 1
  local out="$tmp/$bin"
  if [[ $url == *.tar.gz || $url == *.tgz ]]; then
    download_verify "$url" "$tmp/pkg.tgz" "$sha" || return 1
    tar -xzf "$tmp/pkg.tgz" -C "$tmp" || return 1
    out=$(find "$tmp" -type f -name "$bin" | head -n1)
  else
    download_verify "$url" "$out" "$sha" || return 1
  fi
  [[ -n $out && -f $out ]] || { err "binario '$bin' nao encontrado no pacote"; return 1; }
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$out" "$HOME/.local/bin/$bin"
  rm -rf "$tmp"
}

# Verifica integridade no formato npm: sha512-<base64>, sha256-<base64>, sha1-<base64>.
verify_npm_integrity() {
  local file=$1 integrity=$2 algo hex actual
  [[ -n $integrity ]] || { warn "sem integrity para $(basename "$file")"; return 0; }
  algo=${integrity%%-*}
  hex=${integrity#*-}
  hex=$(printf '%s' "$hex" | base64 -d 2>/dev/null | od -An -tx1 | tr -d ' \n') || true
  [[ -n $hex ]] || { warn "integrity invalida; seguindo sem verificar"; return 0; }
  case $algo in
    sha512) actual=$(sha512sum "$file" | cut -d' ' -f1) ;;
    sha256) actual=$(sha256sum "$file" | cut -d' ' -f1) ;;
    sha1)   actual=$(sha1sum   "$file" | cut -d' ' -f1) ;;
    *)      warn "algoritmo de integrity desconhecido: $algo"; return 0 ;;
  esac
  if [[ $actual == "$hex" ]]; then
    debug "integrity ok ($algo)"
    return 0
  fi
  err "integrity nao confere ($algo) para $(basename "$file")"
  return 1
}

# Detecta musl (Alpine, alguns containers Arch minimal nao, mas e barato).
platform_is_musl() {
  local first
  if command -v ldd >/dev/null 2>&1; then
    first=$(ldd --version 2>&1 | sed -n '1p' || true)
    [[ $first == *musl* ]] && return 0
  fi
  compgen -G '/lib/ld-musl-*' >/dev/null 2>&1 && return 0
  return 1
}

github_latest_tag() {
  local repo=$1
  curl -fsSL --proto '=https' "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p'
}

# Extrai zip com unzip ou bsdtar (Arch minimal pode nao ter unzip).
extract_zip() {
  local zip=$1 dest=$2
  mkdir -p "$dest"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$zip" -d "$dest"
  elif command -v bsdtar >/dev/null 2>&1; then
    bsdtar -xf "$zip" -C "$dest"
  else
    err "unzip ou bsdtar e necessario para extrair $zip"
    return 1
  fi
}

# Extrai uma arvore completa em ~/.local/opt/<id> e linka binarios.
install_tree_tarball() {
  local id=$1 url=$2 sha=${3:-}; shift 3 || true
  local bins=("$@")
  local tmp; tmp=$(mktemp -d) || return 1
  download_verify "$url" "$tmp/pkg.tgz" "$sha" || return 1
  rm -rf "${HOME:?}/.local/opt/$id"
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  if [[ $url == *.zip ]]; then
    mkdir -p "$tmp/x"
    extract_zip "$tmp/pkg.tgz" "$tmp/x" || return 1
    local root
    root=$(find "$tmp/x" -maxdepth 1 -mindepth 1 -type d | head -n1)
    [[ -n $root ]] && mv "$root" "$tmp/extracted" || cp -a "$tmp/x" "$tmp/extracted"
    mv "$tmp/extracted" "$HOME/.local/opt/$id"
  else
    tar -xzf "$tmp/pkg.tgz" -C "$tmp" || return 1
    local root
    root=$(find "$tmp" -maxdepth 1 -mindepth 1 -type d | head -n1)
    [[ -n $root ]] || root=$tmp
    mv "$root" "$HOME/.local/opt/$id"
  fi
  local b found
  for b in "${bins[@]}"; do
    found=$(find "$HOME/.local/opt/$id" -type f -name "$b" -perm -u+x | head -n1)
    [[ -n $found ]] || { warn "binario '$b' nao encontrado em $id"; continue; }
    ln -sf "$found" "$HOME/.local/bin/$b"
  done
  rm -rf "$tmp"
}
