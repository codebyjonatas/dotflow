# Como adicionar uma ferramenta

Adicionar uma ferramenta deve custar **dois arquivos** (registry + manifesto) e,
no máximo, três se ela tiver configuração própria para versionar. Esse é o
critério de aceite do projeto: se exigir mais que isso, o engine está incompleto.

## 1. Registry

Crie `registry/tools/<id>.sh`. O nome do arquivo é o id e precisa bater com
`TOOL_ID`.

```bash
# minhaferramenta - uma linha sobre o que ela faz
TOOL_ID=minhaferramenta
TOOL_DESC="O que ela faz"
TOOL_BIN=minhaferramenta
TOOL_TYPE=cli                 # cli | tui | gui
TOOL_MIN_VERSION="1.2"
TOOL_VERSION_CMD="minhaferramenta --version"
TOOL_VERIFY_CMD=              # substitui `command -v`
TOOL_PKG_ARCH=minhaferramenta
TOOL_PKG_DEBIAN=
TOOL_PKG_FEDORA=
TOOL_AUR_ARCH=
TOOL_FLATPAK=                 # não usado no fluxo padrão
TOOL_TARBALL_URL=
TOOL_TARBALL_BINS=
TOOL_BIN_URL=
TOOL_CARGO_CRATE=
TOOL_NPM_PKG=
TOOL_ARCH_SETUP=              # função em lib/setup.sh
TOOL_DEBIAN_SETUP=
TOOL_FEDORA_SETUP=
TOOL_CUSTOM=                  # último recurso: função em lib/setup.sh
TOOL_VERSION_PIN=             # fixa a versão instalada
TOOL_POST_INSTALL=            # hook executado depois da instalação
TOOL_AUTH_CHECK=              # comando exibido na coluna AUTH do doctor
TOOL_INTERACTIVE=             # 1 se exige passo manual de login
TOOL_CONFIG_PATHS="~/.config/minhaferramenta"
TOOL_HOMEPAGE="https://..."
TOOL_NOTES=""

# Rebaixa a instalação para pendência manual (por família ou global)
TOOL_MANUAL_DEBIAN=1
TOOL_MANUAL_HINT_ARCH="sudo pacman -S minhaferramenta"
TOOL_MANUAL_HINT_DEBIAN="flatpak install flathub org.exemplo.App"
TOOL_MANUAL_DOC="docs/manual-installs.md#minhaferramenta"

# Falha não bloqueia o bootstrap
TOOL_OPTIONAL=1
```

### Regras

- Deixe vazio o que não se aplica. O engine testa os métodos em ordem:
  setup → repo → AUR → flatpak → tarball → binário → cargo → npm → custom.
- `TOOL_VERIFY_CMD` substitui `command -v` — útil para flatpak, GUI ou binário
  com nome diferente (`batcat`).
- `TOOL_AUTH_CHECK` aparece na coluna AUTH do `doctor` (ex.: `gh auth status`).
- `TOOL_MIN_VERSION` + `TOOL_VERSION_CMD` fazem o engine reinstalar quando a
  versão da distro é antiga (caso do `neovim` e do `fzf`).
- `TOOL_MANUAL=1` (ou `TOOL_MANUAL_<FAMILIA>=1`) **exige** um hint genérico ou
  por família. `tests/lint.sh` falha se o hint estiver faltando.
- Se `TOOL_MANUAL_DOC` apontar para um arquivo, o anchor precisa existir em
  `docs/manual-installs.md`.
- `TOOL_OPTIONAL=1` só faz sentido para o que não bloqueia o workflow.
- Não invente nome de pacote: rode `bin/doctor --only <id>` na distro alvo.

## 2. Pacote Stow + manifest

```bash
mkdir -p stow/minhaferramenta/.config/minhaferramenta
# copie e revise a configuração
printf '.config/minhaferramenta/config.toml\n' > manifests/minhaferramenta.txt
```

O manifest lista **exatamente** os paths relativos ao `$HOME`, um por linha. O
apply falha se houver arquivo dentro do pacote fora do manifest — é a proteção
contra linkar estado de máquina e segredos por acidente.

Se a ferramenta não tiver configuração para versionar, pule esta etapa.

## 3. Perfil

Adicione o id em `profiles/core.list` (ou `flow-gui.list` para GUI). Se a
ferramenta não roda em container, **não** a coloque em `container.list`.

## 4. Validar

```bash
tests/lint.sh
bin/bootstrap --only minhaferramenta --dry-run
bin/bootstrap --only minhaferramenta
bin/doctor --only minhaferramenta
bin/verify --only minhaferramenta
```

Se ela puder ser instalada sem root, rode também:

```bash
HOME=/tmp/dotflow-test ./bin/apply --only minhaferramenta --yes
```

## O que nunca fazer

- Copiar diretório de configuração inteiro sem revisar (tokens, device IDs,
  estado local).
- Linkar `~/.config` inteiro.
- Adicionar `sudo` dentro de funções de dotfiles.
- Versionar arquivo gerado pelo app (`fish_variables`, caches, bancos locais).
- Instalar via PPA comunitário, flatpak ou compilação no caminho automático —
  nesses casos, use `TOOL_MANUAL_*`.
