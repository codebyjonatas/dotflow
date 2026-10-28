# Instalações manuais

Estas ferramentas ficaram **fora do fluxo automático** para reduzir risco: PPA
comunitário, flatpak ausente por padrão, compilação ou app GUI opcional. O
`bootstrap`/`apply` continua aplicando as configs via Stow (inofensivas sem o
binário) e termina com sucesso, listando o que falta.

O mesmo conteúdo é gravado em
`${XDG_STATE_HOME:-~/.local/state}/dotflow/pending.md` a cada execução real
(nunca sob `--dry-run`). Para rever depois, basta abrir esse arquivo.

## Ghostty

Terminal com renderização por GPU. Existe no repositório do Arch/CachyOS; não há
pacote oficial em Debian/Ubuntu — o PPA comunitário foi deliberadamente removido
do fluxo.

Arch/CachyOS:

```bash
sudo pacman -S ghostty
```

Debian/Ubuntu (compilar do fonte, quando quiser):

```bash
# siga https://ghostty.org/docs/install/build
```

Enquanto não instalar, use outro terminal. A configuração em
`~/.config/ghostty/config` já está no lugar.

## Leaf

Visualizador TUI de markdown. No Arch vem do AUR (`leaf-markdown-viewer-bin`);
fora dele exigiria compilar Rust, por isso é manual.

Arch/CachyOS:

```bash
paru -S leaf-markdown-viewer-bin
```

Debian/Ubuntu (precisa de toolchain Rust; o `mise` já fornece):

```bash
cargo install --git https://github.com/RivoLink/leaf --locked
```

## Spotify

GUI opcional. No Arch o `spotify-launcher` está no repositório; em Debian/Ubuntu
o caminho normal é flatpak, que não vem instalado por padrão.

Arch/CachyOS:

```bash
sudo pacman -S spotify-launcher
```

Debian/Ubuntu:

```bash
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.spotify.Client
```

## Bitwarden (app desktop)

O CLI (`bw`) é instalado automaticamente via npm; o app desktop é GUI e fica
manual fora do Arch.

Arch/CachyOS:

```bash
sudo pacman -S bitwarden
```

Debian/Ubuntu:

```bash
sudo apt install flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.bitwarden.desktop
```

## Ferramentas opcionais

Estas são tentadas automaticamente, mas uma falha vira apenas warning:

| Ferramenta | Observação |
|---|---|
| `docker` | Instala o engine; entrar no grupo `docker` equivale a root |
| `tailscale` | Serviço systemd; `tailscale up` é manual |
| `ghostwriter` | Editor markdown GUI; só faz sentido no perfil `flow-gui` |

## Passos interativos (sempre manuais)

Nunca automatizados por envolverem segredo ou identidade:

```bash
bw login            # depois: bw unlock
gh auth login
sudo tailscale up
ssh-keygen -t ed25519 -a 100 -C "$USER@$(hostname)"
```

Depois de entrar no grupo `docker` e depois de `chsh`, é preciso **sair e entrar
de novo** na sessão para o efeito valer.

## OpenCode (automático, mas com ressalva)

Não aparece como pendência: em Debian/Ubuntu o binário vem do pacote npm
`@opencode/cli-<target>` com verificação sha512, instalado em
`~/.local/bin/opencode`. O instalador oficial só é usado como fallback, sempre
com `--no-modify-path`.

Se o fallback rodar e o binário for para `~/.opencode/bin`, o `config.fish` do
repo já inclui esse diretório no `PATH`.
