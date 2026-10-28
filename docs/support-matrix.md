# Matriz de suporte

Legenda: `repo` = repositório nativo da distro; `aur` = AUR; `release` =
binário/tarball oficial; `npm`/`cargo` = gerenciador de linguagem; `setup` =
script ou repositório oficial do fornecedor; **manual** = não automatizado, vira
pendência no fim; *opcional* = tenta instalar, falha só gera warning.

| Ferramenta | Arch/CachyOS | Ubuntu LTS | Debian stable | Fallback |
|---|---|---|---|---|
| mise | repo | setup | setup | instalador oficial |
| git | repo | repo | repo | — |
| openssh | repo | repo | repo | — |
| fish | repo | repo | repo | — |
| starship | repo | release (sha256) | release (sha256) | cargo |
| neovim | repo | repo (≥ 0.10) | repo | release oficial |
| tmux | repo | repo | repo | — |
| fzf | repo | release (≥ 0.48) | release (≥ 0.48) | — |
| zoxide | repo | repo | repo | cargo |
| eza | repo | repo | repo (validar) | cargo |
| bat | repo | repo (`batcat`) | repo (`batcat`) | — |
| yazi | repo | release | release | zip oficial |
| ghostty | repo | **manual** | **manual** | compilar (fora do fluxo) |
| lazygit | repo | repo | repo | release |
| docker | repo | setup (repo oficial) | setup (repo oficial) | *opcional* |
| lazydocker | repo | release | release | — |
| opencode | repo/CachyOS, `opencode-bin` (Arch) | npm (sha512) | npm (sha512) | instalador oficial |
| leaf | aur | **manual** | **manual** | cargo do upstream |
| tailscale | repo | setup | setup | *opcional* |
| bitwarden (CLI `bw`) | repo | npm | npm | — |
| bitwarden-app | repo (`bitwarden`) | **manual** | **manual** | flatpak |
| gh | repo (`github-cli`) | setup | setup | — |
| ghostwriter | repo | repo | repo | *opcional* |
| spotify | repo (`spotify-launcher`) | **manual** | **manual** | flatpak |

## Regras aplicadas

- O fluxo padrão não usa PPA comunitário, flatpak nem compilação.
- Ferramenta **manual** não é instalada, não conta como falha e continua com a
  config aplicada via Stow (inofensiva sem o binário).
- Falha de ferramenta *opcional* (docker, tailscale, ghostwriter) não derruba a
  execução; vira warning e entra no lembrete.
- No Debian/Ubuntu, `bat` é instalado como `batcat` e exposto como `bat` por um
  symlink em `~/.local/bin`.
- OpenCode no Debian/Ubuntu usa `@opencode/cli-<target>` com verificação sha512
  em `~/.local/bin`; o instalador oficial é apenas fallback, com
  `--no-modify-path`.
- Nomes de pacote mudam entre releases: o engine chama `pkg_available` antes de
  instalar. Valide com `bin/doctor` na distro alvo.

## Como validar sem VM

```bash
tests/lint.sh
bin/bootstrap --dry-run --profile container
tests/container.sh arch
tests/container.sh ubuntu
tests/container.sh debian
tests/container.sh debian -- --only ghostty    # caminho manual + lembrete
```

O container cobre resolução de pacotes, fallbacks, Stow, `doctor`, `verify` e
`capture`. Não cobre systemd, login real, GUI nem autenticação. Detalhes em
[`testes.md`](testes.md).
