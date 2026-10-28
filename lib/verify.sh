#!/usr/bin/env bash
# lib/verify.sh - verificacao profunda do estado da maquina vs repo.
[[ -n ${DOTFLOW_VERIFY_SH:-} ]] && return 0
DOTFLOW_VERIFY_SH=1

verify_manifests() {
  local f pkg rc=0
  for f in "$DOTFLOW_ROOT"/stow/*/; do
    [[ -d $f ]] || continue
    pkg=$(basename "$f")
    manifest_check "$pkg" || rc=1
  done
  return $rc
}

verify_stow_links() {
  local pkg status rc=0
  local -a pkgs=("$@")
  if ((${#pkgs[@]} == 0)); then
    local f
    for f in "$DOTFLOW_ROOT"/stow/*/; do
      [[ -d $f ]] || continue
      pkgs+=("$(basename "$f")")
    done
  fi
  for pkg in "${pkgs[@]}"; do
    stow_pkg_exists "$pkg" || continue
    manifest_exists "$pkg" || continue
    status=$(stow_status "$pkg")
    case $status in
      linked)  debug "stow ok: $pkg" ;;
      missing) warn "stow nao aplicado: $pkg"; rc=1 ;;
      real)    warn "conflito (arquivo real, nao link): $pkg"; rc=1 ;;
      partial) warn "stow parcial: $pkg"; rc=1 ;;
    esac
  done
  return $rc
}

verify_lockfile() {
  local lock="$HOME/.config/nvim/lazy-lock.json" rc=0
  [[ -f $lock ]] || { warn "lazy-lock.json ausente"; return 1; }
  if [[ -f $DOTFLOW_ROOT/nvim/lazy-lock.json ]]; then
    if cmp -s "$lock" "$DOTFLOW_ROOT/nvim/lazy-lock.json"; then
      ok "lazy-lock.json identico ao do repo"
    else
      warn "lazy-lock.json divergente do repo (rode bin/capture ou commit o lock)"
      rc=1
    fi
  else
    warn "repo sem nvim/lazy-lock.json; rode bin/capture apos :Lazy sync"
    rc=1
  fi
  return $rc
}

verify_main() {
  local -a tools=()
  local rc=0
  engine_parse_args "$@"
  detect_platform
  mapfile -t tools < <(engine_selected_tools)

  echo "== manifesto e stow =="
  verify_manifests || rc=1
  local -a pkgs=()
  local id
  for id in "${tools[@]}"; do
    stow_pkg_exists "$id" && pkgs+=("$id")
  done
  stow_pkg_exists environment && [[ " ${pkgs[*]} " != *" environment "* ]] && pkgs+=(environment)
  verify_stow_links "${pkgs[@]}" || rc=1

  echo
  echo "== ferramentas =="
  local -a check_ids=()
  for id in "${tools[@]}"; do
    [[ $id == neovim && ${DOTFLOW_SKIP_NVIM:-0} == 1 ]] && continue
    check_ids+=("$id")
  done
  doctor_run "${check_ids[@]}" || rc=1

  echo
  echo "== neovim =="
  if [[ " ${tools[*]} " == *" neovim "* && ${DOTFLOW_SKIP_NVIM:-0} != 1 ]]; then
    nvim_check || rc=1
    verify_lockfile || rc=1
  fi

  echo
  echo "== fontes e shell =="
  # Em execucao --only, checagens globais nao fazem sentido.
  if [[ -z ${DOTFLOW_ONLY:-} && ${DOTFLOW_SKIP_FONTS:-0} != 1 ]]; then
    fonts_check || rc=1
  fi
  if [[ " ${tools[*]} " == *" fish "* && ${DOTFLOW_SKIP_SHELL:-0} != 1 ]]; then
    shell_check || rc=1
  fi

  echo
  echo "== segredos =="
  doctor_secret_scan || rc=1

  echo
  if ((rc == 0)); then ok "verify: tudo consistente"; else err "verify: divergencias encontradas"; fi
  return $rc
}
