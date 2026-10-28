# dotflow

Reconstrói o ambiente de desenvolvimento em **Arch/CachyOS**, **Ubuntu LTS** e
**Debian stable** com um comando: instala ferramentas, aplica dotfiles, configura
shell/editor e valida o resultado. O núcleo é independente de ambiente gráfico
(KDE, Hyprland ou nenhum).

O objetivo principal é **não quebrar a máquina**. Tudo é reversível, com backup
datado antes de qualquer sobrescrita, e o que é arriscado de instalar vira uma
pendência manual claramente listada no final.

## Princípios

- **Sem root no script.** O `sudo` é chamado apenas quando necessário e sempre
  de forma visível.
- **Sem PPA, flatpak ou compilação no caminho automático.** O que depende disso
  é rebaixado para manual.
- **Stow com manifest explícito.** Nenhum diretório inteiro de configuração é
  linkado às cegas.
- **Falha isolada.** Ferramenta `opcional` gera aviso; ferramenta `manual` não
  gera falha.
- **Lembrete persistente.** Ao final, o que ficou pendente é impresso e salvo em
  `~/.local/state/dotflow/pending.md`.
- **Segredos nunca entram no repositório.** SSH privado, tokens do `gh`, vault do
  Bitwarden e estado do Tailscale ficam fora.

## Requisitos

- Bash 4.4 ou superior.
- `git`, `curl` e `unzip` (ou `bsdtar`) disponíveis.
- Usuário comum com `sudo`. O script recusa rodar como root.
- Arch/CachyOS, Ubuntu LTS recente (testado em 24.04) ou Debian stable recente.
- GNU Stow: instalado automaticamente pelo bootstrap quando ausente.

## Instalação

### Via GitHub (recomendado)

O instalador remoto exige uma tag imutável e aceita checksum. O fluxo é em dois
estágios: baixar, inspecionar e executar.

```bash
curl -fsSL https://raw.githubusercontent.com/codebyjonatas/dotflow/v1.0.0/install.sh -o /tmp/dotflow-install.sh
less /tmp/dotflow-install.sh

# checksum do tarball da tag (opcional, mas recomendado)
curl -fsSL https://codeload.github.com/codebyjonatas/dotflow/tar.gz/v1.0.0 -o /tmp/dotflow-v1.0.0.tar.gz
sha256sum /tmp/dotflow-v1.0.0.tar.gz

DOTFLOW_REF=v1.0.0 DOTFLOW_SHA256=<sha256> bash /tmp/dotflow-install.sh --dry-run
DOTFLOW_REF=v1.0.0 DOTFLOW_SHA256=<sha256> bash /tmp/dotflow-install.sh
```

`curl ... | bash` funciona, mas não é recomendado: prompts leem de `/dev/tty` e
o script chama `sudo`. O instalador recusa a ref `main` de propósito.

### Checkout local

```bash
git clone https://github.com/codebyjonatas/dotflow.git
cd dotflow
./install.sh --dry-run     # mostra o plano, não altera nada
./install.sh               # instala e aplica
```

### Adoção em degraus (recomendado sem VM)

Se você não pode testar em uma máquina virtual, entre em camadas:

```bash
./bin/bootstrap --dry-run --profile core          # 1. plano
./bin/apply --profile core --yes                  # 2. só dotfiles (com backup)
./bin/bootstrap --only fish,git,starship --yes     # 3. uma ferramenta por vez
./bin/bootstrap --profile core --yes               # 4. instalação completa
```

## Comandos

| Comando | O que faz |
|---|---|
| `bin/bootstrap` | Instala ferramentas, aplica dotfiles, roda doctor e lembrete |
| `bin/apply` | Aplica somente dotfiles (sem instalar pacotes) |
| `bin/apply --install` | Dotfiles + instalação de pacotes |
| `bin/doctor` | Tabela de estado: versão, config, autenticação, status |
| `bin/doctor --all` | Todas as entradas do registry |
| `bin/verify` | Consistência profunda: stow, lockfile, fontes, segredos |
| `bin/capture` | Snapshot da máquina em `capture/` para revisão manual |
| `bin/unstow` | Remove apenas os links gerenciados |
| `bin/bootstrap --list` | Lista ferramentas e perfis |

### Flags

| Flag | Efeito |
|---|---|
| `--profile LIST` | Perfis separados por vírgula (padrão: `core,flow-gui`) |
| `--only LIST` | Ferramentas específicas, ignorando perfis |
| `--dry-run` | Mostra o plano sem alterar nada |
| `--yes`, `-y` | Não pede confirmação |
| `--offline` | Não baixa nem instala nada ausente |
| `--no-gui` | Ignora o perfil `flow-gui` |
| `--skip-install` | Não instala pacotes (`apply` já faz isso) |
| `--install` | Força instalação no `apply` |
| `--skip-fonts` | Não instala Nerd Fonts |
| `--skip-shell` | Não altera o shell padrão |
| `--skip-nvim` | Não configura o LazyVim |
| `--skip-runtimes` | Não instala runtimes do mise |

### Perfis

| Perfil | Conteúdo |
|---|---|
| `core` | Ferramentas diárias, agnósticas de DE/WM |
| `flow-gui` | Apps GUI de fluxo de trabalho (`ghostwriter`, `spotify`) |
| `container` | Subconjunto seguro para smoke test em container |
| `desktop-kde` | Ponto de extensão para KDE (vazio por padrão) |
| `wm-hyprland` | Ponto de extensão para Hyprland (vazio por padrão) |

## Automático, manual e opcional

| Categoria | Comportamento | Hoje |
|---|---|---|
| **Automático** | Instala por repo, AUR, release, npm ou cargo. Falha é erro. | Maioria |
| **Manual** | Não instala, não falha, apenas lembra. Config via Stow continua. | `ghostty`, `leaf`, `spotify`, `bitwarden-app` em Debian/Ubuntu |
| **Opcional** | Tenta instalar; falha vira warning. | `docker`, `tailscale`, `ghostwriter` |

No Arch, `ghostty`, `leaf`, `spotify` e `bitwarden-app` continuam automáticos
quando existe pacote no repo ou AUR.

### Pendências manuais

Ao final de `bootstrap` e `apply`:

```text
== Pendencias manuais ==
  - ghostty: sem pacote oficial; compile do fonte seguindo https://ghostty.org/docs/install/build
  - leaf: cargo install --git https://github.com/RivoLink/leaf --locked
  - gh auth login
  - chave SSH: ssh-keygen -t ed25519 -a 100 -C "$USER@$(hostname)"
```

O mesmo conteúdo fica em `${XDG_STATE_HOME:-~/.local/state}/dotflow/pending.md`
e sobrevive ao fechamento do terminal. Comandos por distro:
[`docs/manual-installs.md`](docs/manual-installs.md).

## Estrutura

```text
bin/         entrypoints (bootstrap, apply, doctor, verify, capture, unstow)
lib/         distro, pacotes, stow, fontes, shell, nvim, setup, reminder
registry/    uma entrada declarativa por ferramenta (tools/<id>.sh)
profiles/    core, flow-gui, container, desktop-kde, wm-hyprland
stow/        um pacote GNU Stow por ferramenta
manifests/   paths exatos que cada pacote pode linkar
fonts/       manifesto de Nerd Fonts (metadados, nunca binários)
nvim/        overlay LazyVim versionado + lockfile
docs/        arquitetura, decisões, matriz, manuais, testes
tests/       lint estrutural e smoke test em container
.github/     CI (lint + shellcheck)
```

## Como funciona

1. Detecta distro/família e arquitetura (`/etc/os-release`, `uname -m`).
2. Carrega o registry e resolve as ferramentas dos perfis.
3. Instala GNU Stow se faltar e cada ferramenta pelo melhor método disponível.
4. Roda hooks de pós-instalação (ex.: `mise install`, serviço do Tailscale).
5. Define `fish` como shell padrão e `nvim` como editor.
6. Configura LazyVim (starter + overlay + lockfile).
7. Instala Nerd Fonts no usuário.
8. Aplica os dotfiles via Stow, com backup e manifest.
9. Roda `doctor`, imprime pendências e grava `pending.md`.

Detalhes em [`docs/arquitetura.md`](docs/arquitetura.md).

## Testes

```bash
tests/lint.sh                                  # sintaxe, registry, manifests, segredos
tests/container.sh arch                        # smoke test real em container
tests/container.sh ubuntu
tests/container.sh debian
tests/container.sh debian -- --only ghostty    # testa o caminho manual
```

O harness cria usuário não-root com `sudo` sem senha dentro do container, roda
`--dry-run`, depois a instalação real e `verify`, e descarta o container.

Também é possível testar dotfiles sem tocar no `$HOME` real:

```bash
HOME=/tmp/dotflow-test ./bin/apply --only fish,git --yes --skip-fonts --skip-shell
HOME=/tmp/dotflow-test ./bin/verify --only fish,git
```

Cobertura e limites em [`docs/testes.md`](docs/testes.md).

## Segurança

- O repositório é tratado como público: nada de chave privada, token ou cookie.
- `bin/verify` varre o repo por padrões de segredo e falha se encontrar.
- `~/.ssh/config` e chaves **públicas** podem ser versionados; a privada não.
- `bw login`, `gh auth login` e `sudo tailscale up` são interativos por design.
- Entrar no grupo `docker` equivale a root: o bootstrap avisa e exige re-login.

## Limitações conhecidas

- Configs de KDE/Hyprland não estão no core: contêm estado de máquina.
- Ghostty não tem pacote oficial em Debian/Ubuntu; é manual (sem PPA no fluxo).
- Leaf fora do Arch exige compilar do upstream; é manual. No Arch depende de
  helper AUR (`paru`/`yay`).
- Apps GUI não são testáveis em container.
- Sem VM/máquina real, a validação é: lint + dry-run + container + `HOME`
  isolado. Isso não cobre systemd, login real, GUI nem autenticação.

## Documentação

- [`docs/arquitetura.md`](docs/arquitetura.md) — camadas e fluxo de execução
- [`docs/decisions.md`](docs/decisions.md) — por que cada decisão foi tomada
- [`docs/support-matrix.md`](docs/support-matrix.md) — o que funciona onde
- [`docs/manual-installs.md`](docs/manual-installs.md) — comandos por distro
- [`docs/adding-a-tool.md`](docs/adding-a-tool.md) — como adicionar ferramenta
- [`docs/testes.md`](docs/testes.md) — como validar sem VM
- [`nvim/README.md`](nvim/README.md) — LazyVim e lockfile

## Versionamento

- `VERSION` contém a versão corrente.
- Tags seguem `vX.Y.Z`; o instalador remoto só aceita tag/commit imutável.
- Mudanças de comportamento devem atualizar `README.md`, `docs/` e `VERSION`.
- Histórico de versões em [`CHANGELOG.md`](CHANGELOG.md).
