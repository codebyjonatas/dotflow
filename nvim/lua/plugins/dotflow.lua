-- Overlay dotflow para o LazyVim.
-- Copiado para ~/.config/nvim/lua/plugins/ pelo bin/bootstrap.
return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-mocha" },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = { flavour = "mocha" },
  },
}
