#!/usr/bin/env bash
# lib/fonts.sh - instalacao de fontes no usuario, independente de distro.
[[ -n ${DOTFLOW_FONTS_SH:-} ]] && return 0
DOTFLOW_FONTS_SH=1

: "${DOTFLOW_FONT_DIR:=${HOME}/.local/share/fonts}"
: "${DOTFLOW_FONT_MANIFEST:=${DOTFLOW_ROOT}/fonts/manifest.tsv}"

fonts_manifest_version() {
  sed -n 's/^# *version=//p' "$DOTFLOW_FONT_MANIFEST" 2>/dev/null | head -n1
}

fonts_family_installed() {
  local family=$1
  # Sem grep -q: com pipefail, o SIGPIPE do grep faria o pipeline falhar.
  fc-list : family 2>/dev/null | tr ',' '\n' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | grep -ix -- "$family" >/dev/null 2>&1
}

# Linhas: familia<TAB>arquivo-zip<TAB>licenca<TAB>url
fonts_install_all() {
  [[ -f $DOTFLOW_FONT_MANIFEST ]] || { warn "manifest de fontes ausente"; return 0; }
  command -v curl >/dev/null 2>&1 || { warn "curl ausente; pulando fontes"; return 0; }
  local family zip license url tmp
  while IFS=$'\t' read -r family zip license url; do
    [[ -z $family || $family == \#* ]] && continue
    if fonts_family_installed "$family"; then
      debug "fonte ja instalada: $family"
      continue
    fi
    info "instalando fonte: $family ($license)"
    if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
      printf '[dry-run] baixar %s e extrair em %s\n' "$url" "$DOTFLOW_FONT_DIR"
      continue
    fi
    tmp=$(mktemp -d) || continue
    if curl -fsSL --retry 3 --proto '=https' "$url" -o "$tmp/font.zip"; then
      mkdir -p "$DOTFLOW_FONT_DIR/$family"
      if extract_zip "$tmp/font.zip" "$DOTFLOW_FONT_DIR/$family"; then
        find "$DOTFLOW_FONT_DIR/$family" -type f \( -name '*.md' -o -name '*.txt' \) -delete 2>/dev/null || true
        ok "fonte instalada: $family"
      else
        warn "falha ao extrair fonte $family"
      fi
    else
      warn "falha ao baixar fonte $family ($url)"
    fi
    rm -rf "$tmp"
  done <"$DOTFLOW_FONT_MANIFEST"

  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] fc-cache -f\n'
  else
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
  fi
}

fonts_check() {
  local family missing=0
  [[ -f $DOTFLOW_FONT_MANIFEST ]] || return 0
  while IFS=$'\t' read -r family _; do
    [[ -z $family || $family == \#* ]] && continue
    if ! fonts_family_installed "$family"; then
      warn "fonte ausente: $family"
      missing=1
    fi
  done <"$DOTFLOW_FONT_MANIFEST"
  return $missing
}
