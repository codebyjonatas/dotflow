# Neovim / LazyVim neste repositório

- O starter do LazyVim é clonado em `~/.config/nvim` pelo `bin/bootstrap`. Ele
  **não** é um pacote Stow, justamente para não conflitar com o clone.
- O overlay versionado fica em `lua/plugins/dotflow.lua` e é copiado por cima do
  starter após o clone.
- `lazy-lock.json` deve ser commitado aqui depois do primeiro `:Lazy sync`.
  Enquanto não existir, `bin/verify` avisa que os plugins não são reproduzíveis.

## Atualizar plugins de forma controlada

```bash
nvim                 # :Lazy update
bin/capture          # copia o estado atual para capture/<timestamp>/
cp capture/<ts>/files/nvim/lazy-lock.json nvim/lazy-lock.json
git add nvim/lazy-lock.json
git commit -m "chore(nvim): atualiza lazy-lock.json"
```

Isso mantém a atualização explícita: a máquina muda, o lock muda, e a mudança
aparece no diff em vez de acontecer silenciosamente em cada máquina.

## Congelar o starter em um commit específico

```bash
DOTFLOW_LAZYVIM_REF=<commit-ou-tag> bin/bootstrap --only neovim --skip-install
```

Sem `DOTFLOW_LAZYVIM_REF`, o bootstrap usa o branch padrão do starter. Use a
variável quando precisar reproduzir exatamente o ambiente de outra máquina.

## Verificar

```bash
bin/doctor --only neovim
bin/verify --only neovim
```
