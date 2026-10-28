#!/usr/bin/env bash
# lib/nvim.sh - LazyVim gerenciado com pin e lockfile.
[[ -n ${DOTFLOW_NVIM_SH:-} ]] && return 0
DOTFLOW_NVIM_SH=1

: "${DOTFLOW_LAZYVIM_STARTER:=https://github.com/LazyVim/starter}"
: "${DOTFLOW_LAZYVIM_REF:=}"
: "${DOTFLOW_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/dotflow}"

nvim_min_ok() {
  local v
  command -v nvim >/dev/null 2>&1 || return 1
  v=$(extract_version "$(nvim --version 2>/dev/null | head -n1)")
  version_ge "${v:-0}" "0.10"
}

setup_lazyvim() {
  local dir="$HOME/.config/nvim"
  local overlay="$DOTFLOW_ROOT/nvim"

  if [[ -d $dir && ! -f $dir/.dotflow-managed ]]; then
    warn "~/.config/nvim ja existe e nao foi criado pelo dotflow"
    if ! confirm "mover ~/.config/nvim para backups e instalar o LazyVim?"; then
      warn "LazyVim nao configurado (mantendo config existente)"
      return 1
    fi
    backup_dir "$dir" nvim
    run rm -rf -- "$dir"
  fi

  if [[ ! -d $dir ]]; then
    info "clonando LazyVim starter"
    if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
      printf '[dry-run] git clone %s %s\n' "$DOTFLOW_LAZYVIM_STARTER" "$dir"
      return 0
    fi
    mkdir -p "$(dirname -- "$dir")"
    if [[ -n $DOTFLOW_LAZYVIM_REF ]]; then
      git clone --depth 1 --branch "$DOTFLOW_LAZYVIM_REF" "$DOTFLOW_LAZYVIM_STARTER" "$dir" \
        || { err "falha ao clonar LazyVim (ref=$DOTFLOW_LAZYVIM_REF)"; return 1; }
    else
      git clone --depth 1 "$DOTFLOW_LAZYVIM_STARTER" "$dir" \
        || { err "falha ao clonar LazyVim"; return 1; }
    fi
    rm -rf "$dir/.git"
    : >"$dir/.dotflow-managed"
  fi

  # Overlay de plugins do repo (versionado).
  if [[ -d $overlay/lua/plugins ]]; then
    mkdir -p "$dir/lua/plugins"
    if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
      printf '[dry-run] copiar %s/lua/plugins -> %s/lua/plugins\n' "$overlay" "$dir"
    else
      cp -a -- "$overlay/lua/plugins/." "$dir/lua/plugins/"
    fi
  fi

  # Lockfile versionado: fixa versoes de plugins.
  if [[ -f $overlay/lazy-lock.json && $DOTFLOW_DRY_RUN == 0 ]]; then
    cp -a -- "$overlay/lazy-lock.json" "$dir/lazy-lock.json"
  fi

  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] nvim --headless "+Lazy! sync" +qa\n'
    return 0
  fi

  nvim_min_ok || { err "Neovim >= 0.10 e obrigatorio para o LazyVim"; return 1; }

  if [[ -f $dir/lazy-lock.json ]]; then
    nvim --headless "+Lazy! restore" +qa >/dev/null 2>&1 || true
  fi
  info "sincronizando plugins (Lazy sync); isso pode demorar"
  if nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1; then
    ok "LazyVim pronto"
  else
    warn "Lazy sync retornou erro; abra o nvim e rode :Lazy sync"
  fi

  mkdir -p "$DOTFLOW_STATE_DIR"
  git -C "$DOTFLOW_ROOT" rev-parse --short HEAD >/dev/null 2>&1 \
    && git -C "$DOTFLOW_ROOT" rev-parse --short HEAD >"$DOTFLOW_STATE_DIR/dotflow.commit" 2>/dev/null || true
  [[ -f $dir/lazy-lock.json ]] && cp -a -- "$dir/lazy-lock.json" "$DOTFLOW_STATE_DIR/lazy-lock.json" 2>/dev/null || true
}

nvim_check() {
  local dir="$HOME/.config/nvim" rc=0
  nvim_min_ok || { warn "Neovim < 0.10 ou ausente"; rc=1; }
  [[ -f $dir/init.lua ]] || { warn "init.lua do LazyVim ausente"; rc=1; }
  [[ -f $dir/lazy-lock.json ]] || { warn "lazy-lock.json ausente (plugins nao reproduziveis)"; rc=1; }
  return $rc
}
