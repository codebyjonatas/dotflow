#!/usr/bin/env bash
# install.sh - ponto de entrada para instalação via curl.
#
# Uso remoto (recomendado, dois estágios):
#   curl -fsSL https://raw.githubusercontent.com/codebyjonatas/dotflow/v1.0.0/install.sh -o /tmp/dotflow-install.sh
#   less /tmp/dotflow-install.sh
#   DOTFLOW_REF=v1.0.0 DOTFLOW_SHA256=<sha256-do-tarball> bash /tmp/dotflow-install.sh --dry-run
#   DOTFLOW_REF=v1.0.0 DOTFLOW_SHA256=<sha256-do-tarball> bash /tmp/dotflow-install.sh
#
# Uso local (checkout):
#   ./install.sh --profile core
#
# Variáveis:
#   DOTFLOW_REPO_SLUG  owner/repo (default: codebyjonatas/dotflow)
#   DOTFLOW_REF        tag/branch/commit. Obrigatório no modo remoto; `main` é recusado.
#   DOTFLOW_SHA256     checksum do tarball baixado. Sem ele, aviso + confirmação.
#   DOTFLOW_CACHE      diretório de cache (default: ~/.cache/dotflow)
set -euo pipefail

readonly HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_SLUG="${DOTFLOW_REPO_SLUG:-codebyjonatas/dotflow}"
readonly REF="${DOTFLOW_REF:-}"
readonly WANT_SHA="${DOTFLOW_SHA256:-}"
readonly CACHE="${DOTFLOW_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/dotflow}"

die() { printf 'erro: %s\n' "$*" >&2; exit 1; }
say() { printf ':: %s\n' "$*"; }

# 1) Checkout local: delega direto para o bootstrap.
if [[ -x $HERE/bin/bootstrap ]]; then
  exec "$HERE/bin/bootstrap" "$@"
fi

# 2) Modo remoto.
[[ ${EUID:-0} -ne 0 ]] || die "nao execute como root. O script chama sudo quando necessario."
command -v curl >/dev/null 2>&1 || die "curl e obrigatorio."
command -v tar  >/dev/null 2>&1 || die "tar e obrigatorio."

[[ -n $REF ]] || die "defina DOTFLOW_REF com uma tag (ex.: v0.1.0). Nao usamos main por padrao."
if [[ $REF == "main" || $REF == "master" ]]; then
  die "ref '$REF' recusada: use uma tag imutavel para instalacao reproduzivel."
fi

url="https://codeload.github.com/${REPO_SLUG}/tar.gz/${REF}"
dest="${CACHE}/${REF//\//_}"
tarball="${dest}.tar.gz"

if [[ ! -f $tarball ]]; then
  say "baixando ${url}"
  mkdir -p "$CACHE"
  curl -fsSL --retry 3 --proto '=https' "$url" -o "$tarball" \
    || die "falha ao baixar $url"
else
  say "usando cache: $tarball"
fi

if [[ -n $WANT_SHA ]]; then
  printf '%s  %s\n' "$WANT_SHA" "$tarball" | sha256sum -c - >/dev/null 2>&1 \
    || die "checksum nao confere para $tarball"
  say "checksum ok"
else
  printf 'aviso: DOTFLOW_SHA256 nao definido; o tarball nao foi verificado.\n' >&2
  if [[ -r /dev/tty && ${DOTFLOW_YES:-0} != 1 ]]; then
    printf 'continuar mesmo assim? [s/N] ' >&2
    IFS= read -r ans </dev/tty || ans=
    [[ $ans =~ ^[sSyY]$ ]] || die "abortado pelo usuario"
  fi
fi

rm -rf "$dest"
mkdir -p "$dest"
tar -xzf "$tarball" -C "$dest" --strip-components=1 \
  || die "falha ao extrair $tarball"

[[ -x "$dest/bin/bootstrap" ]] || die "tarball invalido: bin/bootstrap ausente"

say "executando bootstrap de $dest"
exec "$dest/bin/bootstrap" "$@"
