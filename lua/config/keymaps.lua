-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: h tps://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
vim.keymap.set("n", "ss", ":w<CR>", { desc = "Save file with ss", silent = true })
