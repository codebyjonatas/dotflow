#!/usr/bin/env bash
# lib/doctor.sh - diagnostico e verificacao de segredos.
[[ -n ${DOTFLOW_DOCTOR_SH:-} ]] && return 0
DOTFLOW_DOCTOR_SH=1

tool_installed() {
  if [[ -n ${TOOL_VERIFY_CMD:-} ]]; then
    bash -c "$TOOL_VERIFY_CMD" >/dev/null 2>&1
  elif [[ -n ${TOOL_BIN:-} ]]; then
    command -v "$TOOL_BIN" >/dev/null 2>&1
  else
    return 1
  fi
}

tool_version() {
  [[ -n ${TOOL_VERSION_CMD:-} ]] || return 0
  local out
  out=$(timeout 5 bash -c "$TOOL_VERSION_CMD" 2>&1 || true)
  extract_version "$out"
}

# Instalado E com versao minima satisfeita (quando declarada).
tool_ready() {
  tool_installed || return 1
  [[ -n ${TOOL_MIN_VERSION:-} ]] || return 0
  local v
  v=$(tool_version)
  [[ -z $v ]] && return 0
  version_ge "$v" "$TOOL_MIN_VERSION"
}

_link_into_repo() {
  [[ -L $1 ]] || return 1
  case $(readlink -f -- "$1" 2>/dev/null || true) in
    "$DOTFLOW_ROOT"/*) return 0 ;;
  esac
  return 1
}

_path_status() {
  local p=$1 f total=0 linked=0 real=0
  if _link_into_repo "$p"; then echo link; return 0; fi
  if [[ -L $p ]]; then echo ext; return 0; fi
  if [[ -d $p ]]; then
    while IFS= read -r -d '' f; do
      total=$((total + 1))
      if _link_into_repo "$f"; then linked=$((linked + 1)); else real=$((real + 1)); fi
    done < <(find "$p" -type f -print0)
    if ((total == 0)); then echo empty
    elif ((real == 0)); then echo link
    elif ((linked == 0)); then echo real
    else echo partial
    fi
    return 0
  fi
  if [[ -e $p ]]; then echo real; else echo miss; fi
}

tool_config_status() {
  local out="" paths p rel
  # Quando existe pacote Stow, valida exatamente os paths do manifest
  # (ignora estado do app, como fish_variables).
  if manifest_exists "${TOOL_ID:-}"; then
    while IFS= read -r rel; do
      [[ -n $rel ]] || continue
      out+="$(_path_status "$HOME/$rel") "
    done < <(manifest_paths "$TOOL_ID")
    [[ -n $out ]] && { echo "${out% }"; return 0; }
  fi
  paths=$(tool_get TOOL_CONFIG_PATHS)
  [[ -n $paths ]] || { echo "-"; return 0; }
  for p in $paths; do
    p=${p/#\~/$HOME}
    if [[ -e $p ]]; then out+="present "; else out+="miss "; fi
  done
  echo "${out% }"
}

tool_auth_status() {
  [[ -n ${TOOL_AUTH_CHECK:-} ]] || { echo "-"; return 0; }
  if bash -c "$TOOL_AUTH_CHECK" >/dev/null 2>&1; then echo ok; else echo pendente; fi
}

# doctor_run <id...>
doctor_run() {
  (($#)) || return 0
  local id status ver cfg auth fail=0
  printf '%-12s %-5s %-12s %-9s %-10s %-9s %s\n' FERRAMENTA TIPO VERSION MIN CONFIG AUTH STATUS
  printf '%.0s-' {1..72}; echo
  for id in "$@"; do
    if ! registry_load "$id"; then
      printf '%-12s %s\n' "$id" "entrada invalida"
      fail=1
      continue
    fi
    status=ok; ver="-"; cfg="-"; auth="-"
    if tool_installed; then
      if [[ -n ${TOOL_VERSION_CMD:-} ]]; then
        ver=$(tool_version); ver=${ver:--}
        if [[ -n ${TOOL_MIN_VERSION:-} ]] && [[ $ver != "-" ]] \
          && ! version_ge "$ver" "$TOOL_MIN_VERSION"; then
          status="versao<min"; fail=1
        fi
      fi
      auth=$(tool_auth_status)
      [[ $auth == pendente ]] && status=auth
    elif tool_is_manual; then
      status=manual
    else
      status=ausente; fail=1
    fi
    cfg=$(tool_config_status)
    case $cfg in
      *miss*|*ext*|*real*|*partial*|*empty*) status=config; fail=1 ;;
    esac
    printf '%-12s %-5s %-12s %-9s %-10s %-9s %s\n' \
      "$id" "${TOOL_TYPE:--}" "$ver" "${TOOL_MIN_VERSION:--}" "$cfg" "$auth" "$status"
  done
  return $fail
}

# Procura padroes de segredo no repo (nunca imprime o conteudo).
doctor_secret_scan() {
  local hits=0
  local patterns=(
    'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY'
    'gh[pousr]_[A-Za-z0-9]{20,}'
    'github''_pat_[A-Za-z0-9_]{20,}'
    'tskey-[A-Za-z0-9]+'
    'ANTHROPIC''_API_KEY='
    'AWS_SECRET''_ACCESS_KEY='
  )
  local p
  for p in "${patterns[@]}"; do
    if grep -rIlE --exclude-dir=.git --exclude-dir=backups --exclude-dir=capture \
      -- "$p" "$DOTFLOW_ROOT" >/dev/null 2>&1; then
      warn "possivel segredo no repo (padrao: ${p%%\[*})"
      hits=1
    fi
  done
  return $hits
}

doctor_checks_extra() {
  local rc=0
  fonts_check || rc=1
  shell_check || rc=1
  doctor_secret_scan || rc=1
  return $rc
}
