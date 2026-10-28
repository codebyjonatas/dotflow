# Testes sem VM

O projeto parte de uma restrição explícita: **não existe VM nem máquina
descartável**. Toda a validação usa três camadas que não tocam no `$HOME` real
nem instalam nada no host.

## 1. Lint estrutural

```bash
tests/lint.sh
```

Não precisa de rede, root nem docker. Verifica:

| Checagem | O que quebra o lint |
|---|---|
| Sintaxe bash | `bash -n` falha em `bin/`, `lib/`, `registry/`, `tests/`, `install.sh` |
| Registry | `TOOL_ID` diferente do nome do arquivo, `TOOL_TYPE` vazio |
| Manuais | ferramenta manual sem `TOOL_MANUAL_HINT*` |
| Perfis | id listado em `profiles/*.list` sem `registry/tools/<id>.sh` |
| Manifests | arquivo no pacote Stow fora do manifest, ou manifest apontando path inexistente |
| Segredos | chave privada, token GitHub `ghp_*`/`gho_*` ou PAT fino versionado |

Saída esperada:

```text
== sintaxe bash ==
sintaxe verificada                                    ok
...
lint: tudo ok
```

## 2. Shellcheck

O host pode não ter shellcheck; a forma reproduzível é via container:

```bash
docker run --rm -v "$PWD":/mnt -w /mnt koalaman/shellcheck:stable \
  --severity=error --shell=bash -x bin/* lib/*.sh tests/*.sh registry/tools/*.sh install.sh
```

O CI roda exatamente esse comando, então erro de shellcheck é falha de build.
Warnings conhecidos e aceitos:

- `SC2034` em `registry/tools/*.sh` — as variáveis são lidas por `source`.
- `SC1007`, `SC2088`, `SC2155` em pontos isolados, sem impacto funcional.

## 3. Smoke test em container

```bash
tests/container.sh arch
tests/container.sh ubuntu
tests/container.sh debian
```

Cada execução:

1. baixa a imagem (`archlinux:latest`, `ubuntu:24.04`, `debian:stable-slim`);
2. instala `git`, `curl`, `unzip`, `stow` e `sudo` **dentro** do container;
3. cria o usuário não-root `tester` com `sudo` sem senha;
4. copia o repositório para `/home/tester/dotflow`;
5. roda `bin/bootstrap` em `--dry-run`;
6. roda `bin/bootstrap` de verdade e, no mesmo container, `bin/verify`;
7. descarta o container (`--rm`).

O perfil usado é `container` (subconjunto seguro, sem GUI e sem `leaf`), mais
`--skip-fonts --skip-runtimes --skip-nvim`. Nada do host é alterado além da
imagem em cache.

Variações úteis:

```bash
tests/container.sh ubuntu --dry-run-only
tests/container.sh debian -- --only ghostty        # caminho manual + lembrete
tests/container.sh debian -- --only fish,git
DOTFLOW_TEST_IMAGE=ubuntu:22.04 tests/container.sh ubuntu
```

O teste `--only ghostty` cobre o caso mais delicado: a ferramenta é manual, o
bootstrap precisa terminar com exit 0 e o lembrete precisa aparecer.

## 4. `HOME` isolado

Para validar só a camada de dotfiles, sem pacotes:

```bash
HOME=/tmp/dotflow-test ./bin/apply --only fish,git --yes --skip-fonts --skip-shell
HOME=/tmp/dotflow-test ./bin/verify --only fish,git
HOME=/tmp/dotflow-test ./bin/unstow --only fish,git
```

Isso exercita Stow, backups datados, manifests e `verify` sem tocar no `$HOME`
real. É o teste mais rápido para mudanças em `stow/` e `manifests/`.

## 5. Dry-run no host

Seguro por construção: só imprime o plano.

```bash
./bin/bootstrap --dry-run --profile core
./bin/bootstrap --dry-run --profile flow-gui
./bin/bootstrap --dry-run --profile container
```

Útil para revisar a ordem de resolução antes de rodar em outra máquina.

## O que **não** é coberto

| Área | Motivo |
|---|---|
| GUI (ghostty, spotify, ghostwriter, bitwarden-app) | não roda em container sem display |
| systemd (`docker`, `tailscale`) | container não tem systemd como PID 1 |
| `chsh` e login real | exige sessão de usuário real |
| Autenticação (`gh`, `bw`, `tailscale up`, chave SSH) | interativa por design |
| LazyVim/plugins | depende de rede e de `nvim` interativo |
| Nerd Fonts no terminal | só faz sentido com terminal gráfico |

Para esses casos existe o `pending.md`: o que não dá para validar
automaticamente vira lembrete explícito depois da instalação.

## Checklist antes de publicar uma versão

```bash
tests/lint.sh
docker run --rm -v "$PWD":/mnt -w /mnt koalaman/shellcheck:stable \
  --severity=error --shell=bash -x bin/* lib/*.sh tests/*.sh registry/tools/*.sh install.sh
tests/container.sh arch
tests/container.sh ubuntu
tests/container.sh debian
./bin/bootstrap --dry-run --profile core
```

Se os cinco passarem, o tag pode ser criado.
