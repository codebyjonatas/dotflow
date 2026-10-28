# Arquitetura

O dotflow é dividido em camadas pequenas, todas em Bash, para rodar em uma
instalação limpa sem dependências além de `git`, `curl` e coreutils.

```text
install.sh          entrega (local ou via curl + tag + checksum)
└── bin/bootstrap   entrypoint de instalação + apply + validação
    ├── bin/apply   somente dotfiles
    ├── bin/doctor  diagnóstico
    ├── bin/verify  checagem profunda
    ├── bin/capture snapshot da máquina
    └── bin/unstow  remove links gerenciados
        └── lib/*
            ├── log.sh        log, cores, dry-run, confirmação em TTY
            ├── platform.sh   distro, pacotes, downloads, integridade npm
            ├── registry.sh   carregamento do registry e helpers
            ├── backup.sh     backups datados
            ├── stow.sh       Stow com manifest e detecção de conflito
            ├── fonts.sh      Nerd Fonts no usuário
            ├── shell.sh      fish como shell padrão + variáveis universais
            ├── nvim.sh       LazyVim + overlay + lockfile
            ├── setup.sh      instaladores específicos (docker, gh, mise, ...)
            ├── doctor.sh     tabela de estado e varredura de segredos
            ├── verify.sh     consistência entre máquina e repo
            ├── capture.sh    snapshot com redação de segredos
            ├── reminder.sh   pendências manuais e interativas
            └── engine.sh     orquestração
```

## Fluxo do bootstrap

```text
1. parse de flags
2. recusa root; exige git
3. detect_platform()
4. garante GNU Stow
5. resolve ferramentas (perfis ou --only)
6. para cada ferramenta:
     registry_load
     manual?        → não instala, entra no lembrete
     já instalada?  → sai
     senão: setup → repo → AUR → flatpak → tarball → binário → cargo → npm → custom
     opcional?      → falha vira warning
7. hooks TOOL_POST_INSTALL (mise, tailscale, ...)
8. fish como shell padrão (opcional)
9. LazyVim (opcional)
10. Nerd Fonts (opcional)
11. Stow de cada ferramenta + environment
12. doctor
13. reminder (imprime e grava pending.md)
14. resumo com falhas reais
```

As etapas 8–10 podem ser desligadas com `--skip-shell`, `--skip-nvim` e
`--skip-fonts`. A instalação inteira pode ser simulada com `--dry-run`.

## Registry como fonte de verdade

Cada ferramenta é um arquivo `registry/tools/<id>.sh` com pares `CHAVE=valor`.
Não há parser de TOML/YAML: os arquivos são locais e confiáveis, carregados com
`source` em um shell que limpa as variáveis `TOOL_*` antes de cada carga.

Campos principais:

| Campo | Uso |
|---|---|
| `TOOL_ID` | Identificador (deve bater com o nome do arquivo) |
| `TOOL_BIN` | Binário procurado no PATH |
| `TOOL_VERIFY_CMD` | Alternativa ao `command -v` (flatpak, nome diferente) |
| `TOOL_VERSION_CMD` / `TOOL_MIN_VERSION` | Versão mínima |
| `TOOL_PKG_ARCH/DEBIAN/FEDORA` | Nome do pacote nativo |
| `TOOL_AUR_ARCH` | Pacote AUR |
| `TOOL_TARBALL_URL` / `TOOL_BIN_URL` | Release oficial |
| `TOOL_CARGO_CRATE` / `TOOL_NPM_PKG` | Gerenciadores de linguagem |
| `TOOL_<FAMILIA>_SETUP` / `TOOL_CUSTOM` | Função em `lib/setup.sh` |
| `TOOL_MANUAL*` | Rebaixa para pendência manual |
| `TOOL_OPTIONAL` | Falha não bloqueia |
| `TOOL_VERSION_PIN` | Versão fixa (OpenCode) |
| `TOOL_CONFIG_PATHS` | Caminhos exibidos no doctor |

## Stow sem surpresa

- Um pacote por ferramenta em `stow/<id>/`.
- `manifests/<id>.txt` lista **exatamente** os paths relativos ao `$HOME`.
- O apply falha se existir arquivo no pacote fora do manifest.
- `--no-folding` evita linkar diretórios inteiros.
- Qualquer alvo real é copiado para `backups/<data>/<pacote>/` antes de virar
  link.
- `bin/unstow` remove apenas links; nunca apaga backup nem configuração real.

## Distros e famílias

`detect_platform` mapeia `ID`/`ID_LIKE` para três famílias: `arch`, `debian` e
`fedora`. A camada de pacotes (`lib/platform.sh`) expõe:

- `pkg_is_installed`, `pkg_available`, `pkg_install`
- `aur_install` (somente Arch, com `paru` ou `yay`)
- `flatpak_install`
- `download_verify`, `install_single_binary`, `install_tree_tarball`
- `verify_npm_integrity`, `platform_is_musl`, `extract_zip`

Tudo respeita `DOTFLOW_DRY_RUN`.

## Falhas e pendências

- Falha obrigatória entra em `failures` e muda o exit code no final.
- Falha opcional apenas avisa.
- Ferramenta manual nunca é instalada e sempre aparece no lembrete.
- Passos interativos (`bw login`, `gh auth login`, `tailscale up`, chave SSH)
  são detectados pelo estado atual e listados.

## Decisões relacionadas

O racional de cada escolha está em [`decisions.md`](decisions.md). A matriz de
suporte por distro está em [`support-matrix.md`](support-matrix.md).
