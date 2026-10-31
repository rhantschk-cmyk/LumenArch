-- Lumen's Neovim entry point. LazyVim and its plugins bootstrap on first run.
require("config.lazy")
pcall(require, "config.lumen_theme")
