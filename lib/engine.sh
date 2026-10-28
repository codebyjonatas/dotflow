#!/usr/bin/env bash
# lib/engine.sh - orquestracao de bootstrap/apply.
[[ -n ${DOTFLOW_ENGINE_SH:-} ]] && return 0
DOTFLOW_ENGINE_SH=1

DOTFLOW_PROFILES=${DOTFLOW_PROFILES:-core,flow-gui}
DOTFLOW_ONLY=${DOTFLOW_ONLY:-}
DOTFLOW_NO_GUI=${DOTFLOW_NO_GUI:-0}
DOTFLOW_OFFLINE=${DOTFLOW_OFFLINE:-0}
DOTFLOW_SKIP_INSTALL=${DOTFLOW_SKIP_INSTALL:-0}
DOTFLOW_SKIP_FONTS=${DOTFLOW_SKIP_FONTS:-0}
DOTFLOW_SKIP_SHELL=${DOTFLOW_SKIP_SHELL:-0}
DOTFLOW_SKIP_NVIM=${DOTFLOW_SKIP_NVIM:-0}
DOTFLOW_SKIP_RUNTIMES=${DOTFLOW_SKIP_RUNTIMES:-0}

engine_usage() {
  cat <<'EOF'
dotflow - reconstroi o ambiente em Arch/CachyOS, Ubuntu e Debian

Uso:
  bin/bootstrap [opcoes]     instala ferramentas, aplica dotfiles e valida
  bin/apply     [opcoes]     aplica somente dotfiles (sem instalar pacotes)

Opcoes:
  --profile LIST   perfis separados por virgula (default: core,flow-gui)
  --only LIST      ferramentas especificas, ignorando perfis
  --dry-run        mostra o plano sem alterar nada
  --yes, -y        nao pedir confirmacao
  --offline        nao baixar/instalar nada ausente
  --no-gui         ignora o perfil flow-gui
  --skip-install   nao instala pacotes (apply ja faz isso por padrao)
  --install        forca instalacao no apply
  --skip-fonts     nao instala fontes
  --skip-shell     nao altera shell padrao
  --skip-nvim      nao configura LazyVim
  --skip-runtimes  nao instala runtimes do mise (node, rust, java, postgres, ruby)
  --list           lista ferramentas do registry e perfis
  --help, -h       esta ajuda

Exemplos:
  ./install.sh --profile core --dry-run
  bin/bootstrap --only neovim,fish
  bin/apply --profile core --yes
  bin/doctor --profile core
EOF
}

engine_parse_args() {
  while (($#)); do
    case $1 in
      --profile)   shift || die "--profile exige valor"; DOTFLOW_PROFILES=$1 ;;
      --profile=*) DOTFLOW_PROFILES=${1#*=} ;;
      --only)      shift || die "--only exige valor"; DOTFLOW_ONLY=$1 ;;
      --only=*)    DOTFLOW_ONLY=${1#*=} ;;
      --dry-run)   DOTFLOW_DRY_RUN=1 ;;
      --yes|-y)    DOTFLOW_YES=1 ;;
      --offline)   DOTFLOW_OFFLINE=1 ;;
      --no-gui)    DOTFLOW_NO_GUI=1 ;;
      --skip-install) DOTFLOW_SKIP_INSTALL=1 ;;
      --install)   DOTFLOW_SKIP_INSTALL=0 ;;
      --skip-fonts) DOTFLOW_SKIP_FONTS=1 ;;
      --skip-shell) DOTFLOW_SKIP_SHELL=1 ;;
      --skip-nvim)  DOTFLOW_SKIP_NVIM=1 ;;
      --skip-runtimes) DOTFLOW_SKIP_RUNTIMES=1 ;;
      --list)      engine_list; exit 0 ;;
      --help|-h)   engine_usage; exit 0 ;;
      *)           die "argumento desconhecido: $1 (use --help)" ;;
    esac
    shift
  done
  export DOTFLOW_DRY_RUN DOTFLOW_YES
}

engine_list() {
  local id f
  echo "Ferramentas no registry:"
  for f in "$DOTFLOW_ROOT"/registry/tools/*.sh; do
    id=$(basename "$f" .sh)
    registry_load "$id" 2>/dev/null || true
    printf '  %-12s %-8s %s\n' "$id" "${TOOL_TYPE:--}" "${TOOL_DESC:-}"
  done
  echo
  echo "Perfis:"
  for f in "$DOTFLOW_ROOT"/profiles/*.list; do
    [[ -e $f ]] || continue
    printf '  %-12s (%s ferramentas)\n' "$(basename "$f" .list)" \
      "$(profile_tools "$(basename "$f" .list)" | wc -l)"
  done
}

_tool_rank() {
  case $1 in
    mise)         echo 10 ;;
    git)          echo 15 ;;
    openssh)      echo 20 ;;
    fish)         echo 25 ;;
    starship)     echo 30 ;;
    neovim)       echo 35 ;;
    *)            echo 50 ;;
  esac
}

engine_selected_tools() {
  local ids=() t p
  local profiles=()
  if [[ -n $DOTFLOW_ONLY ]]; then
    IFS=',' read -r -a ids <<<"$DOTFLOW_ONLY"
  else
    IFS=',' read -r -a profiles <<<"$DOTFLOW_PROFILES"
    for p in "${profiles[@]}"; do
      [[ $p == flow-gui && $DOTFLOW_NO_GUI == 1 ]] && continue
      if ! profile_exists "$p"; then
        err "perfil inexistente: $p"
        continue
      fi
      while IFS= read -r t; do
        [[ -n $t ]] && ids+=("$t")
      done < <(profile_tools "$p")
    done
  fi

  local seen=" " out=()
  for t in "${ids[@]}"; do
    [[ -z $t ]] && continue
    [[ $seen == *" $t "* ]] && continue
    seen+="$t "
    out+=("$t")
  done

  local i j tmp
  for ((i = 0; i < ${#out[@]}; i++)); do
    for ((j = i + 1; j < ${#out[@]}; j++)); do
      if (($(_tool_rank "${out[j]}") < $(_tool_rank "${out[i]}"))); then
        tmp=${out[i]}; out[i]=${out[j]}; out[j]=$tmp
      fi
    done
  done
  printf '%s\n' "${out[@]}"
}

engine_plan_method() {
  local native setup_fn aur
  local fam=${DOTFLOW_FAMILY^^}
  setup_fn=$(tool_get "TOOL_${fam}_SETUP")
  [[ -n $setup_fn ]] && { echo "setup ${setup_fn}"; return 0; }
  native=$(tool_field_for_family)
  [[ -n $native ]] && { echo "repo (${native})"; return 0; }
  aur=$(tool_get TOOL_AUR_ARCH)
  [[ $DOTFLOW_FAMILY == arch && -n $aur ]] && { echo "AUR (${aur})"; return 0; }
  [[ -n $(tool_get TOOL_FLATPAK) ]] && { echo "flatpak"; return 0; }
  [[ -n $(tool_get TOOL_TARBALL_URL) ]] && { echo "tarball"; return 0; }
  [[ -n $(tool_get TOOL_BIN_URL) ]] && { echo "binario"; return 0; }
  [[ -n $(tool_get TOOL_CARGO_CRATE) ]] && { echo "cargo"; return 0; }
  [[ -n $(tool_get TOOL_NPM_PKG) ]] && { echo "npm"; return 0; }
  [[ -n $(tool_get TOOL_CUSTOM) ]] && { echo "custom"; return 0; }
  echo "sem metodo para ${DOTFLOW_FAMILY:-?}"
}

engine_ensure_cargo() {
  command -v cargo >/dev/null 2>&1 && return 0
  command -v mise >/dev/null 2>&1 || return 1
  info "instalando rust via mise"
  mise use -g rust@latest >/dev/null 2>&1 || return 1
  mise install >/dev/null 2>&1 || true
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  command -v cargo >/dev/null 2>&1
}

engine_ensure_npm() {
  command -v npm >/dev/null 2>&1 && return 0
  command -v mise >/dev/null 2>&1 || return 1
  info "instalando node via mise"
  mise use -g node@lts >/dev/null 2>&1 || return 1
  mise install >/dev/null 2>&1 || true
  export PATH="$HOME/.local/share/mise/shims:$PATH"
  command -v npm >/dev/null 2>&1
}

engine_install_one() {
  local id=$1 fam native aur flatpak crate npm_pkg custom setup_fn post tmp
  registry_load "$id" || return 1

  # Ferramenta manual nunca e instalada pelo engine.
  if tool_is_manual; then
    debug "$id e manual nesta distro; nada a instalar"
    return 0
  fi

  if tool_ready; then
    debug "$id ja instalado e compativel"
    return 0
  fi
  if tool_installed; then
    warn "$id $(tool_version || true) < ${TOOL_MIN_VERSION:-?}; tentando atualizar"
  fi

  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '%s[dry-run]%s %-12s -> %s\n' "$C_YEL" "$C_RESET" "$id" "$(engine_plan_method)"
    return 0
  fi

  if [[ $DOTFLOW_OFFLINE == 1 ]]; then
    warn "$id ausente e --offline foi usado (nada baixado)"
    return 1
  fi

  fam=${DOTFLOW_FAMILY^^}
  setup_fn=$(tool_get "TOOL_${fam}_SETUP")
  native=$(tool_field_for_family)
  aur=$(tool_get TOOL_AUR_ARCH)
  flatpak=$(tool_get TOOL_FLATPAK)
  crate=$(tool_get TOOL_CARGO_CRATE)
  npm_pkg=$(tool_get TOOL_NPM_PKG)
  custom=$(tool_get TOOL_CUSTOM)

  if [[ -n $setup_fn ]] && declare -F "$setup_fn" >/dev/null 2>&1; then
    "$setup_fn" && tool_ready && { ok "$id instalado (${setup_fn})"; return 0; }
    warn "setup $setup_fn nao resolveu $id"
  fi

  if [[ -n $native ]] && pkg_available "$native"; then
    pkg_install "$native" && tool_ready && { ok "$id instalado (repo)"; return 0; }
  fi

  if [[ $DOTFLOW_FAMILY == arch && -n $aur ]]; then
    aur_install "$aur" && tool_ready && { ok "$id instalado (AUR)"; return 0; }
  fi

  if [[ -n $flatpak ]]; then
    flatpak_install "$flatpak" && tool_ready && { ok "$id instalado (flatpak)"; return 0; }
  fi

  local tarball bins
  tarball=$(tool_get TOOL_TARBALL_URL)
  if [[ -n $tarball ]]; then
    tarball=${tarball//\{arch\}/$(arch_tag)}
    bins=$(tool_get TOOL_TARBALL_BINS)
    # shellcheck disable=SC2086
    install_tree_tarball "$id" "$tarball" "$(tool_get TOOL_TARBALL_SHA256)" $bins \
      && tool_ready && { ok "$id instalado (tarball)"; return 0; }
  fi

  local bin_url
  bin_url=$(tool_get TOOL_BIN_URL)
  if [[ -n $bin_url ]]; then
    bin_url=${bin_url//\{arch\}/$(arch_tag)}
    install_single_binary "$id" "$bin_url" "$(tool_get TOOL_BIN_SHA256)" "${TOOL_BIN:-$id}" \
      && tool_ready && { ok "$id instalado (binario)"; return 0; }
  fi

  if [[ -n $crate ]]; then
    engine_ensure_cargo && run cargo install --locked "$crate" \
      && tool_ready && { ok "$id instalado (cargo)"; return 0; }
  fi

  if [[ -n $npm_pkg ]]; then
    engine_ensure_npm && run npm install -g --prefix "$HOME/.local" "$npm_pkg" \
      && tool_ready && { ok "$id instalado (npm)"; return 0; }
  fi

  if [[ -n $custom ]] && declare -F "$custom" >/dev/null 2>&1; then
    "$custom" && tool_ready && { ok "$id instalado ($custom)"; return 0; }
  fi

  if tool_installed; then
    warn "$id segue na versao da distro (abaixo de ${TOOL_MIN_VERSION:-?})"
    return 0
  fi

  err "nao foi possivel instalar $id em ${DOTFLOW_FAMILY}"
  [[ -n ${TOOL_HOMEPAGE:-} ]] && warn "instrucoes manuais: $TOOL_HOMEPAGE"
  return 1
}

engine_apply_one() {
  local id=$1
  if stow_pkg_exists "$id"; then
    stow_apply "$id" || return 1
  fi
}

engine_summary() {
  local -a failures=("$@")
  echo
  if ((${#failures[@]} == 0)); then
    ok "concluido sem falhas"
  else
    warn "concluido com ${#failures[@]} pendencia(s):"
    printf '  - %s\n' "${failures[@]}"
  fi
  echo "  log: $DOTFLOW_LOG_FILE"
  return $((${#failures[@]} > 0))
}

engine_main() {
  local mode=$1; shift
  engine_parse_args "$@"

  [[ ${EUID:-0} -ne 0 ]] || die "nao rode como root; use um usuario comum (sudo e chamado quando necessario)"
  command -v git >/dev/null 2>&1 || die "git e obrigatorio para o bootstrap"

  # GNU Stow e dependencia do projeto, nao uma ferramenta do registry.
  if ! command -v stow >/dev/null 2>&1; then
    if [[ $DOTFLOW_DRY_RUN == 1 || $DOTFLOW_OFFLINE == 1 ]]; then
      warn "GNU Stow ausente; o dry-run segue sem ele"
    elif [[ $DOTFLOW_SKIP_INSTALL == 1 ]]; then
      die "GNU Stow ausente; instale com 'pacman -S stow' ou 'apt install stow'"
    else
      info "instalando GNU Stow"
      pkg_install stow || die "GNU Stow e obrigatorio para aplicar os dotfiles"
    fi
  fi

  detect_platform
  if [[ $DOTFLOW_FAMILY == unknown ]]; then
    warn "distro nao reconhecida (${DOTFLOW_DISTRO_ID:-?}); apenas fallbacks portaveis serao usados"
  fi

  local -a tools=()
  mapfile -t tools < <(engine_selected_tools)
  ((${#tools[@]})) || die "nenhuma ferramenta selecionada"

  # Aceita ids que existam no registry ou apenas como pacote Stow (ex.: environment).
  local -a valid=()
  local -a doctor_ids=()
  for id in "${tools[@]}"; do
    if registry_exists "$id"; then
      valid+=("$id"); doctor_ids+=("$id")
    elif stow_pkg_exists "$id"; then
      valid+=("$id")
    else
      warn "id desconhecido (nem registry nem stow): $id"
    fi
  done
  tools=("${valid[@]}")
  ((${#tools[@]})) || die "nenhuma ferramenta valida apos filtro"

  local mode_label=$mode
  [[ $mode == apply && $DOTFLOW_SKIP_INSTALL == 0 ]] && mode_label="apply+install"

  info "dotflow ${DOTFLOW_VERSION:-dev} | ${DOTFLOW_DISTRO_ID:-?} (${DOTFLOW_FAMILY}) | modo=$mode_label"
  info "perfis=${DOTFLOW_PROFILES:-only} ferramentas=${#tools[@]} dry-run=$DOTFLOW_DRY_RUN"
  printf '  %s\n' "${tools[@]}"

  local -a failures=()
  local id

  if [[ $DOTFLOW_SKIP_INSTALL == 0 ]]; then
    local optional
    for id in "${tools[@]}"; do
      registry_exists "$id" || continue
      registry_load "$id" 2>/dev/null || continue
      if tool_is_manual; then
        info "$id: instalacao manual (ver lembrete ao final)"
        continue
      fi
      optional=0
      tool_is_optional && optional=1
      if ! engine_install_one "$id"; then
        if ((optional)); then
          warn "opcional indisponivel: $id (segue sem ele)"
        else
          failures+=("install:$id")
        fi
      fi
    done
  fi

  # Hooks de pos-instalacao declarados no registry (auth, servicos, runtimes).
  local post
  for id in "${tools[@]}"; do
    registry_exists "$id" || continue
    registry_load "$id" 2>/dev/null || continue
    tool_is_manual && continue
    [[ $id == mise && $DOTFLOW_SKIP_RUNTIMES == 1 ]] && continue
    post=$(tool_get TOOL_POST_INSTALL)
    if [[ -n $post ]] && declare -F "$post" >/dev/null 2>&1; then
      "$post" || warn "pos-instalacao falhou: $id ($post)"
    fi
  done

  if [[ " ${tools[*]} " == *" fish "* && $DOTFLOW_SKIP_SHELL != 1 ]]; then
    shell_ensure_fish_default || failures+=("shell:chsh")
    shell_set_universal_vars
  fi

  if [[ " ${tools[*]} " == *" neovim "* && $DOTFLOW_SKIP_NVIM != 1 ]]; then
    setup_lazyvim || failures+=("nvim:lazyvim")
  fi

  if [[ $DOTFLOW_SKIP_FONTS != 1 ]]; then
    fonts_install_all
  fi

  for id in "${tools[@]}"; do
    engine_apply_one "$id" || failures+=("stow:$id")
  done

  # Pacote nao vinculado a uma ferramenta: variaveis de ambiente.
  if stow_pkg_exists environment && [[ " ${tools[*]} " != *" environment "* ]]; then
    stow_apply environment || failures+=("stow:environment")
  fi

  # ~/.ssh precisa de permissoes corretas apos o stow.
  if [[ -d $HOME/.ssh && $DOTFLOW_DRY_RUN == 0 ]]; then
    chmod 700 "$HOME/.ssh" 2>/dev/null || true
    find "$HOME/.ssh" -maxdepth 1 -type f -name 'config' -exec chmod 600 {} + 2>/dev/null || true
  fi

  echo
  doctor_run "${doctor_ids[@]}" || true
  reminder_run "${tools[*]}" "${failures[@]}"
  engine_summary "${failures[@]}"
}
