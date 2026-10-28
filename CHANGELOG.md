# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento [SemVer](https://semver.org/lang/pt-BR/).

## [1.0.0] - 2026-10-28

Primeira versão utilizável em máquina real.

### Adicionado

- Instalador `install.sh` em dois estágios, com tag imutável e checksum
  opcional (`DOTFLOW_REF`, `DOTFLOW_SHA256`).
- Registry declarativo com 24 ferramentas (`registry/tools/<id>.sh`).
- Perfis `core`, `flow-gui`, `container`, `desktop-kde` e `wm-hyprland`.
- GNU Stow com manifest explícito, `--no-folding` e backup datado.
- Categorias **automático**, **manual** e **opcional**; pendências persistidas em
  `~/.local/state/dotflow/pending.md`.
- OpenCode instalado via npm com verificação sha512; instalador oficial apenas
  como fallback com `--no-modify-path`.
- Runtimes (Node, Rust, Java, Postgres, Ruby) via `mise`.
- LazyVim com overlay versionado e `lazy-lock.json`.
- Nerd Fonts instaladas no usuário.
- `bin/doctor`, `bin/verify`, `bin/capture` e `bin/unstow`.
- Harness de teste em container (Arch, Ubuntu 24.04, Debian stable) e lint
  estrutural.
- Documentação em pt-BR: arquitetura, decisões, matriz de suporte, instalações
  manuais, como adicionar ferramenta e testes.
- CI com lint e shellcheck.

### Notas

- `ghostty`, `leaf`, `spotify` e `bitwarden-app` são manuais em Debian/Ubuntu.
- `docker`, `tailscale` e `ghostwriter` são opcionais e não bloqueiam a execução.
