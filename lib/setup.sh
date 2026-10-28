#!/usr/bin/env bash
# lib/setup.sh - instalacoes que exigem repositorio oficial ou script upstream.
# Tudo aqui e idempotente e respeita DOTFLOW_DRY_RUN.
[[ -n ${DOTFLOW_SETUP_SH:-} ]] && return 0
DOTFLOW_SETUP_SH=1

_apt_sources_write() { # <arquivo> <conteudo>
  local file=$1 content=$2 tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" >"$tmp"
  run "${DOTFLOW_SUDO[@]}" install -m 0644 "$tmp" "$file"
  rm -f "$tmp"
}

_setup_dry_run() { [[ $DOTFLOW_DRY_RUN == 1 ]]; }

# ---------------------------------------------------------------- Docker
setup_docker_arch() {
  if _setup_dry_run; then printf '[dry-run] pacman -S docker docker-compose\n'; return 0; fi
  pkg_install docker docker-compose || return 1
  docker_post_install
}

setup_docker_debian() {
  if _setup_dry_run; then
    printf '[dry-run] repo oficial Docker (%s/%s) + docker-ce + grupo docker\n' \
      "$DOTFLOW_DISTRO_ID" "$DOTFLOW_CODENAME"
    return 0
  fi
  pkg_install ca-certificates curl gnupg || return 1
  run "${DOTFLOW_SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
  local tmp; tmp=$(mktemp -d)
  download_verify "https://download.docker.com/linux/${DOTFLOW_DISTRO_ID}/gpg" "$tmp/gpg" "" || return 1
  run "${DOTFLOW_SUDO[@]}" install -m 0644 "$tmp/gpg" /etc/apt/keyrings/docker.asc
  _apt_sources_write /etc/apt/sources.list.d/docker.list \
    "deb [arch=$(debian_arch) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${DOTFLOW_DISTRO_ID} ${DOTFLOW_CODENAME} stable"
  rm -rf "$tmp"
  DOTFLOW_APT_UPDATED=0
  apt_update_once || return 1
  pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || return 1
  docker_post_install
}

docker_post_install() {
  command -v docker >/dev/null 2>&1 || return 0
  if command -v systemctl >/dev/null 2>&1; then
    run "${DOTFLOW_SUDO[@]}" systemctl enable --now docker || warn "falha ao habilitar docker"
  fi
  if ! id -nG "$USER" | tr ' ' '\n' | grep -x docker >/dev/null 2>&1; then
    run "${DOTFLOW_SUDO[@]}" usermod -aG docker "$USER" \
      && warn "usuario adicionado ao grupo docker: equivale a root. Faca logout/login."
  fi
}

# ---------------------------------------------------------------- GitHub CLI
setup_gh_debian() {
  if _setup_dry_run; then printf '[dry-run] repo oficial cli.github.com + gh\n'; return 0; fi
  pkg_install ca-certificates curl gnupg || return 1
  run "${DOTFLOW_SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
  local tmp; tmp=$(mktemp -d)
  download_verify "https://cli.github.com/packages/githubcli-archive-keyring.gpg" "$tmp/key.gpg" "" || return 1
  run "${DOTFLOW_SUDO[@]}" install -m 0644 "$tmp/key.gpg" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  _apt_sources_write /etc/apt/sources.list.d/github-cli.list \
    "deb [arch=$(debian_arch) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main"
  rm -rf "$tmp"
  DOTFLOW_APT_UPDATED=0
  apt_update_once || return 1
  pkg_install gh
}

# ---------------------------------------------------------------- Tailscale
setup_tailscale_debian() {
  if _setup_dry_run; then printf '[dry-run] script oficial pkgs.tailscale.com + tailscale\n'; return 0; fi
  local tmp; tmp=$(mktemp -d)
  warn "usando instalador oficial do Tailscale (nao pinado)"
  download_verify "https://tailscale.com/install.sh" "$tmp/install.sh" "" || return 1
  run bash "$tmp/install.sh" || return 1
  rm -rf "$tmp"
  if command -v systemctl >/dev/null 2>&1; then
    run "${DOTFLOW_SUDO[@]}" systemctl enable --now tailscaled \
      || warn "falha ao habilitar tailscaled"
  fi
}

tailscale_post_install() {
  command -v tailscale >/dev/null 2>&1 || return 0
  if tailscale status >/dev/null 2>&1; then
    ok "tailscale ja autenticado"
  else
    warn "tailscale instalado mas nao autenticado: rode 'sudo tailscale up'"
  fi
}

# ---------------------------------------------------------------- mise
setup_mise() {
  if _setup_dry_run; then printf '[dry-run] instalador oficial mise.run\n'; return 0; fi
  command -v mise >/dev/null 2>&1 && return 0
  local tmp; tmp=$(mktemp -d)
  warn "usando instalador oficial do mise (nao pinado)"
  download_verify "https://mise.run" "$tmp/install.sh" "" || return 1
  run sh "$tmp/install.sh" || return 1
  rm -rf "$tmp"
}

mise_post_install() {
  command -v mise >/dev/null 2>&1 || { warn "mise ausente"; return 0; }
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] mise install (node, rust, java, postgres, ruby)\n'
    return 0
  fi
  if mise install >/dev/null 2>&1; then
    ok "runtimes do mise instalados (config versionada em stow/mise)"
  else
    warn "mise install falhou; rode 'mise install' manualmente"
  fi
}

# ---------------------------------------------------------------- OpenCode
# Instala o binario do pacote npm oficial (@opencode/cli-<target>) com
# verificacao de integrity. Nao edita config de shell e nao usa root.
# Escopos: OpenCode 2 publica em @opencode; @opencode-ai fica como fallback
# de versoes antigas do esquema.
_opencode_arches() {
  case $(arch_tag) in
    x86_64)  echo x64 ;;
    aarch64) echo arm64 ;;
    *) return 1 ;;
  esac
}

_opencode_targets() {
  local arch base
  arch=$(_opencode_arches) || return 1
  base="linux-${arch}"
  printf '%s\n' "$base" "${base}-baseline"
  if platform_is_musl; then
    printf '%s\n' "${base}-musl" "${base}-baseline-musl"
  fi
}

_opencode_npm_metadata() { # <target> <pin|latest> -> "url<TAB>integrity<TAB>target"
  local target=$1 pin=${2:-latest} scope meta url integrity
  for scope in '@opencode' '@opencode-ai'; do
    meta=$(curl -fsSL --proto '=https' --retry 2 \
      "https://registry.npmjs.org/${scope}%2fcli-${target}/${pin}" 2>/dev/null) || continue
    [[ -n $meta ]] || continue
    url=$(printf '%s' "$meta" | sed -n 's/.*"tarball":"\([^"]*\)".*/\1/p' | sed -n '1p')
    integrity=$(printf '%s' "$meta" | sed -n 's/.*"integrity":"\([^"]*\)".*/\1/p' | sed -n '1p')
    [[ -n $url ]] || continue
    printf '%s\t%s\t%s' "$url" "$integrity" "$target"
    return 0
  done
  return 1
}

_opencode_resolve() { # <pin> -> "url<TAB>integrity<TAB>target"
  local pin=$1 target meta
  while IFS= read -r target; do
    [[ -n $target ]] || continue
    if meta=$(_opencode_npm_metadata "$target" "$pin"); then
      printf '%s' "$meta"
      return 0
    fi
  done < <(_opencode_targets)
  return 1
}

_install_opencode_from_npm() {
  local meta url integrity target tmp bin
  meta=$(_opencode_resolve "$(tool_get TOOL_VERSION_PIN)") || return 1
  url=${meta%%$'\t'*}
  integrity=${meta#*$'\t'}
  target=${integrity#*$'\t'}
  integrity=${integrity%%$'\t'*}
  tmp=$(mktemp -d) || return 1
  info "baixando OpenCode ${target} de $url"
  if ! curl -fsSL --retry 3 --proto '=https' "$url" -o "$tmp/pkg.tgz"; then
    rm -rf "$tmp"; return 1
  fi
  if ! verify_npm_integrity "$tmp/pkg.tgz" "$integrity"; then
    rm -rf "$tmp"; return 1
  fi
  if ! tar -xzf "$tmp/pkg.tgz" -C "$tmp"; then
    rm -rf "$tmp"; return 1
  fi
  bin="$tmp/package/bin/opencode"
  [[ -f $bin ]] || bin=$(find "$tmp/package" -type f -name opencode -print -quit 2>/dev/null)
  if [[ -z $bin || ! -f $bin ]]; then
    err "binario opencode nao encontrado no pacote npm"
    rm -rf "$tmp"; return 1
  fi
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$bin" "$HOME/.local/bin/opencode"
  rm -rf "$tmp"
  ok "OpenCode instalado em ~/.local/bin/opencode"
}

_install_opencode_official() {
  local tmp
  warn "usando instalador oficial do OpenCode (fallback, sem checksum)"
  tmp=$(mktemp -d) || return 1
  if ! curl -fsSL --retry 3 --proto '=https' https://opencode.ai/v2/install -o "$tmp/install.sh"; then
    rm -rf "$tmp"; return 1
  fi
  ( cd "$tmp" && VERSION="$(tool_get TOOL_VERSION_PIN)" bash "$tmp/install.sh" --no-modify-path ) \
    || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

install_opencode_npm() {
  if _setup_dry_run; then
    printf '[dry-run] OpenCode: pacote npm @opencode/cli-<target> com sha512\n'
    return 0
  fi
  if _install_opencode_from_npm; then return 0; fi
  _install_opencode_official
}

# ---------------------------------------------------------------- Releases do GitHub
_gh_arch() {
  case $(arch_tag) in
    aarch64) echo arm64 ;;
    *)       echo x86_64 ;;
  esac
}

install_lazygit_release() {
  if _setup_dry_run; then printf '[dry-run] lazygit: release latest do GitHub\n'; return 0; fi
  local tag ver url
  tag=$(github_latest_tag jesseduffield/lazygit)
  [[ -n $tag ]] || { err "nao foi possivel obter a ultima release do lazygit"; return 1; }
  ver=${tag#v}
  url="https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_$(_gh_arch).tar.gz"
  install_single_binary lazygit "$url" "" lazygit
}

install_lazydocker_release() {
  if _setup_dry_run; then printf '[dry-run] lazydocker: release latest do GitHub\n'; return 0; fi
  local tag ver url
  tag=$(github_latest_tag jesseduffield/lazydocker)
  [[ -n $tag ]] || { err "nao foi possivel obter a ultima release do lazydocker"; return 1; }
  ver=${tag#v}
  url="https://github.com/jesseduffield/lazydocker/releases/download/${tag}/lazydocker_${ver}_Linux_$(_gh_arch).tar.gz"
  install_single_binary lazydocker "$url" "" lazydocker
}

install_leaf_from_source() {
  if _setup_dry_run; then printf '[dry-run] cargo install --git https://github.com/RivoLink/leaf\n'; return 0; fi
  declare -F engine_ensure_cargo >/dev/null 2>&1 && engine_ensure_cargo || command -v cargo >/dev/null 2>&1 || {
    err "cargo ausente para compilar o leaf"
    return 1
  }
  run cargo install --git https://github.com/RivoLink/leaf --locked
}

install_starship_release() {
  if _setup_dry_run; then printf '[dry-run] starship: release oficial com .sha256\n'; return 0; fi
  local arch url tmp expected actual
  case $(arch_tag) in
    x86_64|aarch64) arch=$(arch_tag) ;;
    *) err "sem release do starship para $(uname -m)"; return 1 ;;
  esac
  url="https://github.com/starship/starship/releases/latest/download/starship-${arch}-unknown-linux-gnu.tar.gz"
  tmp=$(mktemp -d) || return 1
  if ! curl -fsSL --retry 3 --proto '=https' "$url" -o "$tmp/starship.tar.gz"; then
    rm -rf "$tmp"; return 1
  fi
  if curl -fsSL --retry 2 --proto '=https' "${url}.sha256" -o "$tmp/starship.sha256" 2>/dev/null; then
    expected=$(awk '{print $1; exit}' "$tmp/starship.sha256")
    actual=$(sha256sum "$tmp/starship.tar.gz" | cut -d' ' -f1)
    if [[ -z $expected || $expected != "$actual" ]]; then
      err "checksum do starship nao confere"
      rm -rf "$tmp"; return 1
    fi
  else
    warn "sem checksum publicado para starship"
  fi
  tar -xzf "$tmp/starship.tar.gz" -C "$tmp" || { rm -rf "$tmp"; return 1; }
  mkdir -p "$HOME/.local/bin"
  install -m 0755 "$tmp/starship" "$HOME/.local/bin/starship" || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

install_fzf_release() {
  if _setup_dry_run; then printf '[dry-run] fzf: release latest do GitHub\n'; return 0; fi
  local tag ver arch url
  tag=$(github_latest_tag junegunn/fzf)
  [[ -n $tag ]] || { err "nao foi possivel obter a ultima release do fzf"; return 1; }
  ver=${tag#v}
  case $(arch_tag) in
    x86_64)  arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) err "sem release do fzf para $(uname -m)"; return 1 ;;
  esac
  url="https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${ver}-linux_${arch}.tar.gz"
  install_single_binary fzf "$url" "" fzf
}
