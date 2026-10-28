#!/usr/bin/env bash
# lib/capture.sh - snapshot do sistema atual para revisao (nunca sobrescreve o repo).
[[ -n ${DOTFLOW_CAPTURE_SH:-} ]] && return 0
DOTFLOW_CAPTURE_SH=1

_capture_dest() {
  printf '%s/capture/%s' "$DOTFLOW_ROOT" "$(date '+%Y%m%d-%H%M%S')"
}

_redact() {
  sed -E \
    -e 's/((token|password|secret|api[_-]?key|access[_-]?key)[A-Za-z0-9_-]*)([[:space:]]*[=:][[:space:]]*).*/\1\3<REDACTED>/Ig' \
    -e 's/(Bearer[[:space:]]+)[A-Za-z0-9._~+\/=-]+/\1<REDACTED>/Ig'
}

_capture_file() { # <origem> <destino-relativo>
  local src=$1 rel=$2 dest f sub
  if [[ -d $src ]]; then
    while IFS= read -r -d '' f; do
      sub=${f#"$src/"}
      dest="$CAPTURE_DEST/files/$rel/$sub"
      mkdir -p "$(dirname -- "$dest")"
      _redact <"$f" >"$dest"
    done < <(find "$src" -type f -print0)
    return 0
  fi
  [[ -f $src ]] || return 0
  dest="$CAPTURE_DEST/files/$rel"
  mkdir -p "$(dirname -- "$dest")"
  _redact <"$src" >"$dest"
}

capture_main() {
  CAPTURE_DEST=$(_capture_dest)
  local mkdir_dest=$CAPTURE_DEST
  info "capturando estado em $mkdir_dest"
  if [[ $DOTFLOW_DRY_RUN == 1 ]]; then
    printf '[dry-run] criar %s\n' "$mkdir_dest"
    return 0
  fi
  mkdir -p "$CAPTURE_DEST/files" "$CAPTURE_DEST/packages"

  if [[ $DOTFLOW_FAMILY == arch ]]; then
    pacman -Qqen >"$CAPTURE_DEST/packages/pacman-explicit-repo.txt" 2>/dev/null || true
    pacman -Qqem >"$CAPTURE_DEST/packages/pacman-explicit-aur.txt"  2>/dev/null || true
    pacman -Qqe  >"$CAPTURE_DEST/packages/pacman-explicit-all.txt"  2>/dev/null || true
  elif [[ $DOTFLOW_FAMILY == debian ]]; then
    apt-mark showmanual >"$CAPTURE_DEST/packages/apt-manual.txt" 2>/dev/null || true
  fi

  command -v flatpak >/dev/null 2>&1 \
    && flatpak list --app --columns=application,origin,version \
       >"$CAPTURE_DEST/packages/flatpak.txt" 2>/dev/null || true
  command -v mise >/dev/null 2>&1 \
    && mise ls --current >"$CAPTURE_DEST/packages/mise.txt" 2>/dev/null || true
  command -v npm >/dev/null 2>&1 \
    && npm ls -g --depth=0 >"$CAPTURE_DEST/packages/npm-global.txt" 2>/dev/null || true
  command -v cargo >/dev/null 2>&1 \
    && cargo install --list >"$CAPTURE_DEST/packages/cargo.txt" 2>/dev/null || true
  command -v fc-list >/dev/null 2>&1 \
    && fc-list : family | tr ',' '\n' | sort -u >"$CAPTURE_DEST/fonts.txt" || true

  # Somente configs candidatas; segredos sao redigidos e chaves nunca entram.
  local rel
  for rel in \
    .config/fish/config.fish \
    .config/fish/conf.d \
    .config/fish/functions \
    .config/starship.toml \
    .config/yazi/yazi.toml \
    .config/yazi/keymap.toml \
    .config/yazi/theme.toml \
    .config/ghostty/config \
    .config/tmux/tmux.conf \
    .config/opencode/opencode.jsonc \
    .config/git/config \
    .gitconfig \
    .ssh/config \
    .zshrc
  do
    _capture_file "$HOME/$rel" "$rel"
  done

  # nvim: apenas lockfile e overlays, nunca o repo inteiro.
  _capture_file "$HOME/.config/nvim/lazy-lock.json" "nvim/lazy-lock.json"
  _capture_file "$HOME/.config/nvim/lua/plugins/dotflow.lua" "nvim/lua/plugins/dotflow.lua"

  cat >"$CAPTURE_DEST/INVENTORY.md" <<EOF
# Inventario capturado em $(date '+%Y-%m-%d %H:%M:%S')

- distro: ${DOTFLOW_DISTRO_ID:-?} (${DOTFLOW_FAMILY:-?})
- pacotes explicitos: $(wc -l <"$CAPTURE_DEST/packages/pacman-explicit-all.txt" 2>/dev/null || echo 0)
- fontes distintas: $(wc -l <"$CAPTURE_DEST/fonts.txt" 2>/dev/null || echo 0)

## Proximo passo

Revise os arquivos em \`files/\` e promova manualmente para \`stow/<ferramenta>/\`
+ \`manifests/<ferramenta>.txt\`. Nada e promovido automaticamente.
Segredos foram redigidos, mas revise antes de commitar.
EOF

  ok "captura concluida: $CAPTURE_DEST"
  info "revise com: diff -ru $CAPTURE_DEST/files stow/"
}
