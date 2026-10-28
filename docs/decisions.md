# Decisões de arquitetura

O racional de cada escolha, em ordem cronológica. O **o quê** está em
[`arquitetura.md`](arquitetura.md); aqui está o **por quê**.

## 1. Registry como fonte de verdade

`pacman -Qqem` descreve uma máquina Arch e não é traduzível para Ubuntu/Debian.
Por isso a fonte de verdade é `registry/tools/<id>.sh`, com instalação por família
de distro e fallback declarado. O inventário do Arch (`bin/capture`) é insumo para
criar/ajustar entradas, não o artefato portável.

## 2. Bash + pares chave=valor

O bootstrap precisa rodar em container limpo com bash, coreutils, curl e git.
Um parser de TOML/YAML adicionaria dependência antes de qualquer instalação. Os
arquivos do registry são `.sh` locais e confiáveis, carregados com `source`.

## 3. Stow com manifest, nunca stow cego

`stow` em `~/.config` inteiro arrasta estado de máquina e segredos. Cada pacote
tem `manifests/<pkg>.txt` com os paths exatos; o apply falha se existir arquivo
no pacote fora do manifest, e faz backup do alvo real antes de linkar.
`--no-folding` evita linkar diretórios inteiros.

## 4. Core x perfis

O core é agnóstico de DE/WM. `desktop-kde` e `wm-hyprland` existem como pontos de
extensão, mas ficam vazios por padrão: arquivos como `kdeglobals` e
`hyprland.conf` contêm telas, dispositivos e keybinds específicos da máquina.
Documentar é melhor que versionar cópia cega.

## 5. Identidade e segredos

- SSH: só `config` e `.pub`; a chave privada é recriada localmente.
- Bitwarden: instalação apenas; `login`/`unlock` são manuais.
- `gh`: instalação apenas; `hosts.yml` nunca é versionado.
- Tailscale: instalação; `tailscale up` é manual.
- `bin/verify` faz varredura por padrões de segredo e falha se encontrar algo.

## 6. LazyVim reprodutível

O starter é clonado (opcionalmente pinado por `DOTFLOW_LAZYVIM_REF`), o `.git` é
removido e o overlay de `nvim/lua/plugins` é copiado. O `lazy-lock.json` é
versionado; sem ele, cada máquina instala versões diferentes de plugins.

## 7. Entrega via curl com tag fixa

`install.sh` recusa `main`, exige `DOTFLOW_REF` e aceita `DOTFLOW_SHA256`. O fluxo
recomendado baixa, inspeciona e executa em dois estágios. O modo `curl | bash`
continua disponível, mas prompts usam `/dev/tty`.

## 8. Docker e grupo docker

Instalar o engine é simples; entrar no grupo `docker` concede root efetivo. A
decisão é instalar, avisar explicitamente e exigir re-login.

## 9. Runtimes via mise

Node, Rust, Java, Postgres e Ruby são gerenciados pelo mise com versões pinadas.
Isso evita depender da versão empacotada por cada distro e mantém o mesmo
comportamento em Arch, Ubuntu e Debian.

## 10. Automático, manual e opcional

Sem VM/máquina real para validar, o critério é "não tocar no que não dá para
reverter". O fluxo padrão não usa PPA comunitário, flatpak nem compilação.
Ferramentas que dependem disso viram `TOOL_MANUAL` (por família de distro) e são
apenas lembradas no fim, com comando específico e cópia em `pending.md`.
Ferramentas que dependem de systemd ou de repositório próprio (docker, tailscale)
são `TOOL_OPTIONAL`: falha não derruba o bootstrap. As configs continuam sendo
aplicadas via Stow, pois são inofensivas sem o binário.

## 11. OpenCode sem instalador interativo

Debian/Ubuntu não têm pacote de OpenCode e o pacote npm `opencode-ai` é a major 1.
O caminho escolhido é o pacote `@opencode/cli-<target>` (OpenCode 2) baixado do
registry npm, com verificação de `dist.integrity` (sha512) e instalação de um
único binário em `~/.local/bin`. Vantagens: sem root, sem editar config de shell
(o instalador oficial mexe em `~/.config/fish/config.fish`, que é symlink para o
repo), reversível apagando um arquivo e reproduzível por pin. O instalador
oficial só roda como fallback, sempre com `--no-modify-path`.

## 12. Releases do GitHub quando o repositório da distro fica velho

Dois casos concretos:

- **fzf**: o Ubuntu 24.04 entrega a versão 0.44, mas a integração `--fish` exige
  0.48 ou superior. O pacote do repositório seria instalado e simplesmente não
  funcionaria no shell padrão.
- **starship**: não existe em Ubuntu/Debian, e compilar via cargo custa minutos
  em toda instalação.

A solução é a mesma para os dois: baixar o release oficial e instalar o binário
em `~/.local/bin`. Starship valida um sidecar `.sha256`; se ele não existir, cai
para o checksum calculado localmente. Nada de root e nada de toolchain.

## 13. Lembrete persistente em vez de aviso passageiro

Aviso no terminal se perde quando o usuário fecha a aba. Por isso toda pendência
(manual, opcional que falhou e passo interativo) é impressa no fim e gravada em
`${XDG_STATE_HOME:-~/.local/state}/dotflow/pending.md`. O arquivo é reescrito a
cada execução real — nunca sob `--dry-run` — e o cabeçalho aparece sempre,
mesmo quando não há nada pendente, para deixar claro que a checagem rodou.

## 14. Teste em container em vez de "na minha máquina"

O harness `tests/container.sh` sobe Arch, Ubuntu 24.04 e Debian stable, cria um
usuário não-root com `sudo` sem senha e executa bootstrap + `verify` no mesmo
container. É a única forma honesta de validar resolução de pacotes e fallbacks
sem arriscar a máquina real ou exigir uma VM completa. GUI, systemd e login real
ficam explicitamente fora do escopo.
