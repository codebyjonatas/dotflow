#!/usr/bin/env bash
# lib/registry.sh - carregamento das entradas declarativas em registry/tools/.
[[ -n ${DOTFLOW_REGISTRY_SH:-} ]] && return 0
DOTFLOW_REGISTRY_SH=1

: "${DOTFLOW_ROOT:?DOTFLOW_ROOT nao definido}"

_REGISTRY_FIELDS=(
  TOOL_ID TOOL_DESC TOOL_BIN TOOL_TYPE TOOL_PROFILES TOOL_MIN_VERSION
  TOOL_VERSION_CMD TOOL_VERIFY_CMD TOOL_AUTH_CHECK TOOL_INTERACTIVE
  TOOL_PKG_ARCH TOOL_PKG_DEBIAN TOOL_PKG_FEDORA
  TOOL_AUR_ARCH
  TOOL_FLATPAK
  TOOL_TARBALL_URL TOOL_TARBALL_SHA256 TOOL_TARBALL_BINS
  TOOL_BIN_URL TOOL_BIN_SHA256
  TOOL_CARGO_CRATE TOOL_NPM_PKG
  TOOL_ARCH_SETUP TOOL_DEBIAN_SETUP TOOL_FEDORA_SETUP
  TOOL_CUSTOM TOOL_POST_INSTALL
  TOOL_CONFIG_PATHS TOOL_HOMEPAGE TOOL_NOTES
  TOOL_MANUAL TOOL_MANUAL_ARCH TOOL_MANUAL_DEBIAN TOOL_MANUAL_FEDORA
  TOOL_MANUAL_HINT TOOL_MANUAL_HINT_ARCH TOOL_MANUAL_HINT_DEBIAN
  TOOL_MANUAL_HINT_FEDORA TOOL_MANUAL_DOC
  TOOL_OPTIONAL TOOL_VERSION_PIN
)

_registry_reset() {
  local v
  for v in "${_REGISTRY_FIELDS[@]}"; do printf -v "$v" '%s' ''; done
}

registry_file() { printf '%s/registry/tools/%s.sh' "$DOTFLOW_ROOT" "$1"; }

registry_exists() { [[ -f $(registry_file "$1") ]]; }

registry_ids() {
  local f
  for f in "$DOTFLOW_ROOT"/registry/tools/*.sh; do
    [[ -e $f ]] || continue
    basename "$f" .sh
  done
}

registry_load() {
  local id=$1 file
  file=$(registry_file "$id")
  [[ -f $file ]] || { err "ferramenta desconhecida no registry: $id"; return 1; }
  _registry_reset
  # Arquivos do registry sao locais e confiaveis (parte do repo).
  # shellcheck disable=SC1090
  . "$file"
  [[ -n $TOOL_ID ]] || TOOL_ID=$id
}

# tool_get <CAMPO> -> valor ou vazio
tool_get() {
  local name=$1
  printf '%s' "${!name:-}"
}

tool_field_for_family() {
  local suffix
  case $DOTFLOW_FAMILY in
    arch)   suffix=ARCH ;;
    debian) suffix=DEBIAN ;;
    fedora) suffix=FEDORA ;;
    *)      return 1 ;;
  esac
  tool_get "TOOL_PKG_${suffix}"
}

profile_file() { printf '%s/profiles/%s.list' "$DOTFLOW_ROOT" "$1"; }

# Manual pode ser global (TOOL_MANUAL=1) ou por familia (TOOL_MANUAL_DEBIAN=1).
tool_is_manual() {
  local fam=${DOTFLOW_FAMILY:-unknown}
  fam=${fam^^}
  local v
  v=$(tool_get "TOOL_MANUAL_${fam}")
  if [[ -n $v ]]; then
    [[ $v == 1 ]]
  else
    [[ ${TOOL_MANUAL:-0} == 1 ]]
  fi
}

tool_is_optional() { [[ ${TOOL_OPTIONAL:-0} == 1 ]]; }

tool_manual_hint() {
  local fam=${DOTFLOW_FAMILY:-unknown}
  fam=${fam^^}
  local h
  h=$(tool_get "TOOL_MANUAL_HINT_${fam}")
  [[ -n $h ]] || h=$(tool_get TOOL_MANUAL_HINT)
  [[ -n $h ]] || h=${TOOL_HOMEPAGE:-}
  printf '%s' "$h"
}

profile_tools() {
  local profile=$1 file
  file=$(profile_file "$profile")
  [[ -f $file ]] || { warn "perfil inexistente: $profile"; return 1; }
  sed -e 's/#.*//' -e 's/[[:space:]]//g' "$file" | grep -v '^$'
}

profile_exists() { [[ -f $(profile_file "$1") ]]; }
