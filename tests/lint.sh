#!/usr/bin/env bash
# tests/lint.sh - validacoes estruturais que nao exigem rede nem root.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

say() { printf '%-52s %s\n' "$1" "$2"; }
bad() { say "$1" "FALHOU"; fail=1; }
good() { say "$1" "ok"; }

echo "== sintaxe bash =="
while IFS= read -r -d '' f; do
  if bash -n "$f" 2>/dev/null; then
    :
  else
    bad "sintaxe: $f"
  fi
done < <(find bin lib registry tests -type f -name '*.sh' -print0; \
         find bin -type f -print0; printf 'install.sh\0')
good "sintaxe verificada"

echo
echo "== registry =="
for f in registry/tools/*.sh; do
  id=$(basename "$f" .sh)
  out=$(bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    . "$1"
    printf "%s|%s|%s" "${TOOL_ID:-}" "${TOOL_TYPE:-}" "${TOOL_DESC:-}"
  ' _ "$f" 2>/dev/null) || { bad "registry: $f"; continue; }
  rid=${out%%|*}
  rest=${out#*|}
  rtype=${rest%%|*}
  [[ $rid == "$id" ]] || bad "TOOL_ID '$rid' != arquivo '$id'"
  [[ -n $rtype ]] || bad "TOOL_TYPE vazio em $id"
done
good "registry carregado"

echo
echo "== manuais =="
for f in registry/tools/*.sh; do
  id=$(basename "$f" .sh)
  out=$(bash -c '
    set -euo pipefail
    # shellcheck disable=SC1090
    . "$1"
    manual=0
    [[ ${TOOL_MANUAL:-0} == 1 ]] && manual=1
    for v in "${!TOOL_MANUAL_@}"; do
      [[ $v == TOOL_MANUAL_HINT* ]] && continue
      [[ ${!v} == 1 ]] && manual=1
    done
    ((manual)) || exit 0
    if [[ -n ${TOOL_MANUAL_HINT:-}${TOOL_MANUAL_HINT_ARCH:-}${TOOL_MANUAL_HINT_DEBIAN:-}${TOOL_MANUAL_HINT_FEDORA:-} ]]; then
      echo ok
    else
      echo missing
    fi
  ' _ "$f" 2>/dev/null) || { bad "registry: $f"; continue; }
  [[ -z $out || $out == ok ]] || bad "ferramenta manual sem hint: $id"
done
good "manuais com hint"

echo
echo "== perfis =="
for pf in profiles/*.list; do
  while IFS= read -r t; do
    [[ -z $t || $t == \#* ]] && continue
    [[ -f registry/tools/$t.sh ]] || bad "perfil $(basename "$pf") -> $t nao existe no registry"
  done < "$pf"
done
good "perfis consistentes"

echo
echo "== manifests x pacotes stow =="
for d in stow/*/; do
  pkg=$(basename "$d")
  man="manifests/$pkg.txt"
  [[ -f $man ]] || { bad "pacote '$pkg' sem manifest"; continue; }
  while IFS= read -r -d '' f; do
    rel=${f#"$d"}
    grep -qxF -- "$rel" "$man" || bad "arquivo fora do manifest: $pkg/$rel"
  done < <(find "$d" -type f -print0)
  while IFS= read -r rel; do
    [[ -z $rel || $rel == \#* ]] && continue
    [[ -e "$d/$rel" ]] || bad "manifest aponta path inexistente: $pkg/$rel"
  done < "$man"
done
good "manifests consistentes"

echo
echo "== segredos =="
if grep -rIlE --exclude-dir=.git --exclude-dir=backups --exclude-dir=capture \
  -- 'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY|gh[pousr]_[A-Za-z0-9]{20,}|github''_pat_' . >/dev/null 2>&1; then
  bad "padrao de segredo encontrado"
else
  good "nenhum padrao de segredo"
fi

echo
if ((fail)); then
  echo "lint: falhas encontradas"
  exit 1
fi
echo "lint: tudo ok"
