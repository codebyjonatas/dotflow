#!/usr/bin/env bash
# lib/stow.sh - Stow com manifest explicito e deteccao de conflito.
[[ -n ${DOTFLOW_STOW_SH:-} ]] && return 0
DOTFLOW_STOW_SH=1

: "${DOTFLOW_ROOT:?}"
: "${DOTFLOW_STOW_DIR:=${DOTFLOW_ROOT}/stow}"
: "${DOTFLOW_MANIFEST_DIR:=${DOTFLOW_ROOT}/manifests}"

stow_pkg_dir()      { printf '%s/%s' "$DOTFLOW_STOW_DIR" "$1"; }
manifest_file()     { printf '%s/%s.txt' "$DOTFLOW_MANIFEST_DIR" "$1"; }
stow_pkg_exists()   { [[ -d $(stow_pkg_dir "$1") ]]; }
manifest_exists()   { [[ -f $(manifest_file "$1") ]]; }

manifest_paths() {
  local pkg=$1 file
  file=$(manifest_file "$pkg")
  [[ -f $file ]] || return 1
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$file" | grep -v '^$'
}

# Verifica que todo arquivo do pacote esta listado no manifest.
manifest_check() {
  local pkg=$1 dir file rel bad=0
  dir=$(stow_pkg_dir "$pkg")
  file=$(manifest_file "$pkg")
  [[ -d $dir ]] || return 0
  if [[ ! -f $file ]]; then
    warn "pacote '$pkg' sem manifest em $file; pulando verificacao"
    return 0
  fi
  while IFS= read -r -d '' f; do
    rel=${f#"$dir/"}
    if ! grep -qxF -- "$rel" "$file"; then
      err "arquivo fora do manifest em '$pkg': $rel"
      bad=1
    fi
  done < <(find "$dir" -type f -print0)
  return $bad
}

# Resolve conflitos: alvo real (nao symlink para o repo) e movido para backups.
stow_prepare() {
  local pkg=$1 rel target link_target
  while IFS= read -r rel; do
    [[ -n $rel ]] || continue
    target="$HOME/$rel"
    if [[ -L $target ]]; then
      link_target=$(readlink -f -- "$target" 2>/dev/null || true)
      case $link_target in
        "$DOTFLOW_ROOT"/*) continue ;;
        *) backup_path "$target" "$pkg" "$rel"; rm -f -- "$target" ;;
      esac
    elif [[ -e $target ]]; then
      backup_path "$target" "$pkg" "$rel"
      rm -rf -- "$target"
    fi
  done < <(manifest_paths "$pkg")
}

stow_apply() {
  local pkg=$1
  stow_pkg_exists "$pkg" || return 0
  manifest_check "$pkg" || { err "manifest invalido para '$pkg'"; return 1; }
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] stow --restow %s -> %s\n' "$pkg" "$HOME"
    return 0
  fi
  stow_prepare "$pkg"
  # --no-folding evita linkar diretorios inteiros e perder controle do conteudo.
  if ! stow --dir "$DOTFLOW_STOW_DIR" --target "$HOME" --no-folding --restow "$pkg"; then
    err "stow falhou para '$pkg' (verifique conflitos em ~)"
    return 1
  fi
  ok "dotfiles aplicados: $pkg"
}

stow_remove() {
  local pkg=$1
  stow_pkg_exists "$pkg" || return 0
  run stow --dir "$DOTFLOW_STOW_DIR" --target "$HOME" --no-folding -D "$pkg"
}

# status: linked | real | missing | partial
stow_status() {
  local pkg=$1 rel target total=0 linked=0 real=0 missing=0
  while IFS= read -r rel; do
    [[ -n $rel ]] || continue
    total=$((total + 1))
    target="$HOME/$rel"
    if [[ -L $target ]]; then
      case $(readlink -f -- "$target" 2>/dev/null || true) in
        "$DOTFLOW_ROOT"/*) linked=$((linked + 1)) ;;
        *) real=$((real + 1)) ;;
      esac
    elif [[ -e $target ]]; then
      real=$((real + 1))
    else
      missing=$((missing + 1))
    fi
  done < <(manifest_paths "$pkg")
  if ((total > 0 && linked == total)); then echo linked
  elif ((real == 0 && missing == 0)); then echo linked
  elif ((linked > 0)); then echo partial
  elif ((real > 0)); then echo real
  else echo missing
  fi
}
