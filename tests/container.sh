#!/usr/bin/env bash
# tests/container.sh - smoke test em container (Arch, Ubuntu, Debian).
#
# Requer docker e um usuario fora de root. O container usa um usuario 'tester'
# com sudo sem senha; nada do host e alterado alem da imagem baixada.
#
# Uso:
#   tests/container.sh arch
#   tests/container.sh ubuntu --dry-run-only
#   tests/container.sh debian -- --only fish,git
#
# Variaveis:
#   DOTFLOW_TEST_IMAGE  sobrescreve a imagem (ex.: ubuntu:22.04)
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_ONLY=0
DISTRO=
EXTRA=()

while (($#)); do
  case $1 in
    arch|ubuntu|debian) DISTRO=$1 ;;
    --dry-run-only) DRY_ONLY=1 ;;
    --) shift; EXTRA=("$@"); break ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "argumento desconhecido: $1" >&2; exit 2 ;;
  esac
  shift
done

[[ -n $DISTRO ]] || { echo "uso: tests/container.sh <arch|ubuntu|debian> [--dry-run-only] [-- flags]" >&2; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "docker e obrigatorio" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "docker daemon indisponivel" >&2; exit 1; }

case $DISTRO in
  arch)   IMAGE=${DOTFLOW_TEST_IMAGE:-archlinux:latest} ;;
  ubuntu) IMAGE=${DOTFLOW_TEST_IMAGE:-ubuntu:24.04} ;;
  debian) IMAGE=${DOTFLOW_TEST_IMAGE:-debian:stable-slim} ;;
esac

RUN_FLAGS=("--profile" "container" "--skip-fonts" "--skip-runtimes" "--skip-nvim" "--yes")
if ((${#EXTRA[@]})); then
  RUN_FLAGS+=("${EXTRA[@]}")
fi

prep_arch='
set -euo pipefail
pacman -Sy --noconfirm archlinux-keyring >/dev/null
pacman -S --noconfirm --needed git sudo curl unzip stow >/dev/null
useradd -m -G wheel tester
echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester
'

prep_debian='
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends sudo git curl unzip ca-certificates stow >/dev/null
useradd -m -s /bin/bash tester
echo "tester ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/tester
chmod 440 /etc/sudoers.d/tester
'

case $DISTRO in
  arch) PREP=$prep_arch ;;
  *)    PREP=$prep_debian ;;
esac

BASE=(
  "$PREP"
  'cp -a /src /home/tester/dotflow'
  'chown -R tester:tester /home/tester'
)

run_container() {
  local file rc
  file=$(mktemp)
  printf '%s\n' "$@" >"$file"
  docker run --rm -v "$ROOT":/src:ro -v "$file":/run.sh:ro "$IMAGE" bash /run.sh </dev/null
  rc=$?
  rm -f "$file"
  return $rc
}

echo "== $DISTRO ($IMAGE) =="
echo "-- dry-run --"
run_container "${BASE[@]}" \
  "su - tester -c 'cd ~/dotflow && ./bin/bootstrap ${RUN_FLAGS[*]} --dry-run'"

if ((DRY_ONLY)); then
  echo "ok: dry-run concluido ($DISTRO)"
  exit 0
fi

echo
echo "-- instalacao real + verify --"
run_container "${BASE[@]}" \
  'rc=0' \
  'vrc=0' \
  "su - tester -c 'cd ~/dotflow && ./bin/bootstrap ${RUN_FLAGS[*]}' || rc=\$?" \
  "su - tester -c 'cd ~/dotflow && ./bin/verify ${RUN_FLAGS[*]}' || vrc=\$?" \
  '[ "$rc" -eq 0 ] && rc=$vrc' \
  'exit "$rc"'

echo "ok: $DISTRO"
