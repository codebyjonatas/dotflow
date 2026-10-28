#!/usr/bin/env bash
# lib/log.sh - logging, execucao com dry-run e confirmacao em TTY.
[[ -n ${DOTFLOW_LOG_SH:-} ]] && return 0
DOTFLOW_LOG_SH=1

: "${DOTFLOW_LOG_FILE:=${XDG_STATE_HOME:-$HOME/.local/state}/dotflow/dotflow.log}"
: "${DOTFLOW_DRY_RUN:=0}"
: "${DOTFLOW_YES:=0}"
: "${DOTFLOW_DEBUG:=0}"

# Binarios instalados pelo proprio dotflow (releases, npm --prefix, cargo).
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GRN=$'\033[32m'
  C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_CYN=$'\033[36m'; C_DIM=$'\033[2m'
else
  C_RESET=; C_RED=; C_GRN=; C_YEL=; C_BLU=; C_CYN=; C_DIM=
fi

_log() {
  local level=$1; shift
  mkdir -p "$(dirname -- "$DOTFLOW_LOG_FILE")" 2>/dev/null || true
  printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" \
    >>"$DOTFLOW_LOG_FILE" 2>/dev/null || true
}

info()  { _log INFO "$*";  printf '%s::%s %s\n'   "$C_BLU" "$C_RESET" "$*"; }
ok()    { _log OK "$*";    printf '%s ok %s %s\n' "$C_GRN" "$C_RESET" "$*"; }
warn()  { _log WARN "$*";  printf '%s !! %s %s\n' "$C_YEL" "$C_RESET" "$*" >&2; }
err()   { _log ERROR "$*"; printf '%s erro %s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }
debug() { [[ $DOTFLOW_DEBUG == 1 ]] && printf '%s dbg %s %s\n' "$C_DIM" "$C_RESET" "$*" >&2; return 0; }

# run executa o comando, ou apenas imprime em dry-run.
run() {
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '%s[dry-run]%s %s\n' "$C_YEL" "$C_RESET" "$*"
    _log DRYRUN "$*"
    return 0
  fi
  _log RUN "$*"
  "$@"
}

# confirm le do terminal, nunca do stdin (curl | bash nao tem stdin util).
confirm() {
  local prompt=${1:-Continuar?}
  [[ $DOTFLOW_YES == 1 ]] && return 0
  [[ $DOTFLOW_DRY_RUN == 1 ]] && return 0
  if [[ ! -r /dev/tty ]]; then
    warn "sem TTY para responder '$prompt'; assumindo nao"
    return 1
  fi
  local ans=
  printf '%s [s/N] ' "$prompt" >&2
  IFS= read -r ans </dev/tty || return 1
  [[ $ans =~ ^[sSyY]$ ]]
}

# version_ge A B -> verdadeiro se A >= B (usa sort -V)
version_ge() {
  local a=${1#v} b=${2#v}
  [[ -z $b ]] && return 0
  [[ $a == "$b" ]] && return 0
  [[ $(printf '%s\n%s\n' "$b" "$a" | sort -V | head -n1) == "$b" ]]
}

# extract_version <texto> -> primeira sequencia tipo semver (uma unica linha)
extract_version() {
  awk 'match($0, /[0-9]+(\.[0-9]+)+/) {
         print substr($0, RSTART, RLENGTH); exit
       }' <<<"$1"
}
