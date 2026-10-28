#!/usr/bin/env bash
# lib/reminder.sh - pendencias manuais e interativas, impressas e persistidas.
[[ -n ${DOTFLOW_REMINDER_SH:-} ]] && return 0
DOTFLOW_REMINDER_SH=1

: "${DOTFLOW_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/dotflow}"

REMINDER_MANUAL_IDS=()
REMINDER_MANUAL_HINTS=()
REMINDER_INTERACTIVE=()
REMINDER_FAILURES=()

reminder_reset() {
  REMINDER_MANUAL_IDS=()
  REMINDER_MANUAL_HINTS=()
  REMINDER_INTERACTIVE=()
  REMINDER_FAILURES=()
}

_reminder_has_interactive() {
  local needle=$1 item
  for item in "${REMINDER_INTERACTIVE[@]}"; do
    [[ $item == "$needle" ]] && return 0
  done
  return 1
}

reminder_add_interactive() {
  _reminder_has_interactive "$1" || REMINDER_INTERACTIVE+=("$1")
}

# reminder_collect <id...> - monta a lista a partir do registry carregado.
reminder_collect() {
  local id auth
  for id in "$@"; do
    registry_exists "$id" || continue
    registry_load "$id" 2>/dev/null || continue

    if tool_is_manual; then
      REMINDER_MANUAL_IDS+=("$id")
      REMINDER_MANUAL_HINTS+=("$(tool_manual_hint)")
      continue
    fi

    tool_installed || continue
    auth=$(tool_auth_status)
    case $id in
      bitwarden)
        [[ $auth == ok ]] || reminder_add_interactive "bw login   (depois: bw unlock)"
        ;;
      gh)
        [[ $auth == ok ]] || reminder_add_interactive "gh auth login"
        ;;
      tailscale)
        [[ $auth == ok ]] || reminder_add_interactive "sudo tailscale up"
        ;;
    esac
  done

  # Chave SSH: so lembra se nao existir nenhuma publica.
  if [[ " $* " == *" openssh "* ]]; then
    compgen -G "$HOME/.ssh/id_*.pub" >/dev/null 2>&1 \
      || reminder_add_interactive \
           'chave SSH: ssh-keygen -t ed25519 -a 100 -C "$USER@$(hostname)"'
  fi

  # Grupo docker so passa a valer em nova sessao.
  if [[ " $* " == *" docker "* ]] && id -nG 2>/dev/null | tr ' ' '\n' | grep -x docker >/dev/null 2>&1; then
    reminder_add_interactive "reinicie a sessao para o grupo docker valer"
  fi
}

reminder_is_empty() {
  ((${#REMINDER_MANUAL_IDS[@]} == 0)) \
    && ((${#REMINDER_INTERACTIVE[@]} == 0)) \
    && ((${#REMINDER_FAILURES[@]} == 0))
}

reminder_print() {
  echo
  echo "== Pendencias manuais =="
  if reminder_is_empty; then
    echo "  nada pendente"
    return 0
  fi
  local i
  for i in "${!REMINDER_MANUAL_IDS[@]}"; do
    printf '  - %s: %s\n' "${REMINDER_MANUAL_IDS[$i]}" "${REMINDER_MANUAL_HINTS[$i]}"
  done
  local item
  for item in "${REMINDER_INTERACTIVE[@]}"; do
    printf '  - %s\n' "$item"
  done
  if ((${#REMINDER_FAILURES[@]} > 0)); then
    echo "  falhas desta execucao:"
    for item in "${REMINDER_FAILURES[@]}"; do
      printf '    - %s\n' "$item"
    done
  fi
  echo
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    echo "  (dry-run: nada foi salvo)"
  else
    echo "  Detalhes salvos em: $DOTFLOW_STATE_DIR/pending.md"
  fi
}

reminder_persist() {
  [[ $DOTFLOW_DRY_RUN == 1 ]] && return 0
  reminder_is_empty && return 0
  local file="$DOTFLOW_STATE_DIR/pending.md"
  mkdir -p "$DOTFLOW_STATE_DIR" || return 1
  {
    echo "# Pendencias do dotflow"
    echo
    printf 'Gerado em %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf 'Sistema: %s (%s)\n\n' "${DOTFLOW_DISTRO_ID:-?}" "${DOTFLOW_FAMILY:-?}"

    if ((${#REMINDER_MANUAL_IDS[@]} > 0)); then
      echo "## Instalacao manual"
      echo
      local i
      for i in "${!REMINDER_MANUAL_IDS[@]}"; do
        printf -- '- **%s**: %s\n' "${REMINDER_MANUAL_IDS[$i]}" "${REMINDER_MANUAL_HINTS[$i]}"
      done
      echo
    fi

    if ((${#REMINDER_INTERACTIVE[@]} > 0)); then
      echo "## Passos interativos"
      echo
      local item
      for item in "${REMINDER_INTERACTIVE[@]}"; do
        printf -- '- %s\n' "$item"
      done
      echo
    fi

    if ((${#REMINDER_FAILURES[@]} > 0)); then
      echo "## Falhas desta execucao"
      echo
      local item
      for item in "${REMINDER_FAILURES[@]}"; do
        printf -- '- `%s`\n' "$item"
      done
      echo
    fi

    echo "## Como retomar"
    echo
    echo '```bash'
    echo "cd ${DOTFLOW_ROOT:-.}"
    echo "./bin/doctor --profile ${DOTFLOW_PROFILES:-core}"
    echo '```'
  } >"$file"
  return 0
}

# reminder_run "<ids separados por espaco>" <falhas...>
reminder_run() {
  local tools_str=$1; shift
  reminder_reset
  local -a tl=()
  read -r -a tl <<<"$tools_str"
  reminder_collect "${tl[@]}"
  REMINDER_FAILURES=("$@")
  reminder_print || true
  reminder_persist || warn "nao foi possivel salvar $DOTFLOW_STATE_DIR/pending.md"
  return 0
}
