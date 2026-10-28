#!/usr/bin/env bash
# lib/backup.sh - backups datados antes de qualquer sobrescrita.
[[ -n ${DOTFLOW_BACKUP_SH:-} ]] && return 0
DOTFLOW_BACKUP_SH=1

: "${DOTFLOW_BACKUP_DIR:=${DOTFLOW_ROOT}/backups}"

backup_run_dir() {
  printf '%s/%s' "$DOTFLOW_BACKUP_DIR" "$(date '+%Y%m%d-%H%M%S')"
}

# backup_path <origem> <rotulo> [caminho-relativo]
backup_path() {
  local src=$1 label=${2:-misc} rel=${3:-$(basename -- "$1")}
  [[ -e $src || -L $src ]] || return 0
  local dest
  dest="$(backup_run_dir)/${label}/${rel}"
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] backup %s -> %s\n' "$src" "$dest"
    return 0
  fi
  mkdir -p "$(dirname -- "$dest")"
  cp -a -- "$src" "$dest"
  ok "backup: $src -> $dest"
}

# backup_dir <diretorio> <rotulo>
backup_dir() {
  local src=$1 label=${2:-dir}
  [[ -d $src ]] || return 0
  local dest
  dest="$(backup_run_dir)/${label}"
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] backup diretorio %s -> %s\n' "$src" "$dest"
    return 0
  fi
  mkdir -p "$dest"
  cp -a -- "$src" "$dest/"
  ok "backup: $src -> $dest/$(basename -- "$src")"
}
