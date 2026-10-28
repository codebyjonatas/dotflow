#!/usr/bin/env bash
# lib/shell.sh - fish como shell padrao, EDITOR/VISUAL e integracoes.
[[ -n ${DOTFLOW_SHELL_SH:-} ]] && return 0
DOTFLOW_SHELL_SH=1

fish_path() { command -v fish 2>/dev/null || true; }

shell_ensure_fish_default() {
  local fish
  fish=$(fish_path)
  if [[ -z $fish ]]; then
    if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
      printf '[dry-run] definir fish como shell padrao (fish sera instalado antes)\n'
      return 0
    fi
    warn "fish nao encontrado; shell padrao nao alterado"
    return 1
  fi

  if ! grep -qxF -- "$fish" /etc/shells 2>/dev/null; then
    info "adicionando $fish em /etc/shells"
    if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
      printf '[dry-run] echo %s | sudo tee -a /etc/shells\n' "$fish"
    else
      printf '%s\n' "$fish" | "${DOTFLOW_SUDO[@]}" tee -a /etc/shells >/dev/null \
        || { warn "falha ao atualizar /etc/shells"; return 1; }
    fi
  fi

  if [[ ${SHELL:-} == "$fish" ]]; then
    ok "fish ja e o shell padrao"
    return 0
  fi

  info "definindo fish como shell padrao (chsh)"
  if run "${DOTFLOW_SUDO[@]}" chsh -s "$fish" "$USER"; then
    ok "shell padrao: $fish (faca logout/login para valer em todas as sessoes)"
  else
    warn "chsh falhou; rode manualmente: chsh -s $fish"
    return 1
  fi
}

# Variaveis universais do fish (estado local, nao versionado).
shell_set_universal_vars() {
  local fish
  fish=$(fish_path)
  [[ -n $fish ]] || return 0
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] fish -c "set -Ux EDITOR nvim; set -Ux VISUAL nvim; set -Ux SUDO_EDITOR nvim"\n'
    return 0
  fi
  "$fish" -c 'set -Ux EDITOR nvim; set -Ux VISUAL nvim; set -Ux SUDO_EDITOR nvim' \
    && ok "variaveis universais do fish definidas" \
    || warn "falha ao definir variaveis universais do fish"
}

shell_check() {
  local fish rc=0
  fish=$(fish_path)
  if [[ -z $fish ]]; then
    if [[ ${DOTFLOW_DRY_RUN:-0} == 1 ]]; then
      return 0
    fi
    warn "fish ausente"; rc=1
  fi
  [[ ${SHELL:-} == "$fish" ]] || { warn "shell atual (${SHELL:-?}) nao e fish"; rc=1; }
  return $rc
}
