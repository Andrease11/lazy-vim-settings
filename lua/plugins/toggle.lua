return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      open_mapping = [[<leader>tt]],
      start_in_insert = true,
      persist_size = true,
      direction = "float",
      close_on_exit = true,
      shell = vim.o.shell,
      float_opts = {
        border = "curved",
        winblend = 0,
        highlights = {
          border = "Normal",
          background = "Normal",
        },
      },
    },
    config = function(_, opts)
      require("toggleterm").setup(opts)

      -- Create keymaps for terminals 1-9
      for i = 1, 9 do
        vim.keymap.set({ "n", "t" }, "<leader>t" .. i, function()
          -- Close any open terminal first
          local terminals = require("toggleterm.terminal").get_all()
          for _, terminal in pairs(terminals) do
            if terminal:is_open() then
              terminal:close()
            end
          end

          -- Open the requested terminal
          local term = require("toggleterm.terminal").Terminal:new({
            count = i,
            direction = "float",
          })
          term:toggle()
        end, { desc = "Toggle terminal " .. i })
      end
    end,
  },
}
