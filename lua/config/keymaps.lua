-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: h tps://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })
vim.keymap.set("n", "ss", ":w<CR>", { desc = "Save file with ss", silent = true })

vim.keymap.set("n", "rn", function()
  local function rename_and_save()
    local current_name = vim.fn.expand("<cword>")
    vim.ui.input({ prompt = "New name: ", default = current_name }, function(new_name)
      if new_name and new_name ~= "" and new_name ~= current_name then
        vim.lsp.buf.rename(new_name)
        vim.defer_fn(function()
          vim.cmd("wa")
          print("Rinomina completata e file salvati.")
        end, 500)
      end
    end)
  end
  rename_and_save()
end, { noremap = true, silent = true })
