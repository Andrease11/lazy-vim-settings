return {
  "mfussenegger/nvim-dap",

  dependencies = {
    -- DAP UI
    "rcarriga/nvim-dap-ui",

    -- Required dependency for nvim-dap-ui
    "nvim-neotest/nvim-nio",

    -- Installs debug adapters
    "williamboman/mason.nvim",
    "jay-babu/mason-nvim-dap.nvim",

    -- For Python debugging
    "mfussenegger/nvim-dap-python",
    -- For Python testing with pytest + DAP
    "nvim-neotest/neotest",
    "nvim-neotest/neotest-python",
    -- For selecting Python files to debug
    -- (only if you want the telescope-based selection!)
    "nvim-telescope/telescope.nvim",
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = {
      "mfussenegger/nvim-dap",
    },
    config = function()
      local dap = require("dap")
      local dap_python = require("dap-python")

      -- Configure dap-python to use uv's Python interpreter

      local function get_python_path()
        local venv_python = os.getenv("VIRTUAL_ENV")
        if venv_python then
          local venv_path = venv_python .. "/bin/python"
          local file = io.open(venv_path, "r")
          if file then
            file:close()
            return venv_path
          end
        end

        -- 2. Cerca .venv nella directory corrente o nelle parent
        local function find_venv(dir)
          local venv_path = dir .. "/.venv/bin/python"
          local file = io.open(venv_path, "r")
          if file then
            file:close()
            return venv_path
          end

          -- Risali di una directory
          local parent = vim.fn.fnamemodify(dir, ":h")
          if parent ~= dir then
            return find_venv(parent)
          end
          return nil
        end

        local local_venv = find_venv(vim.fn.getcwd())
        if local_venv then
          return local_venv
        end

        -- 3. Prova con uv se disponibile
        local handle = io.popen("command -v uv >/dev/null 2>&1 && uv run which python 2>/dev/null")
        if handle then
          local result = handle:read("*a")
          handle:close()

          if result and vim.trim(result) ~= "" then
            return vim.trim(result)
          end
        end

        -- 4. Fallback finale
        return "python3"
      end

      -- Initialize dap-python with uv's Python
      dap_python.setup(get_python_path())

      -- Custom configurations for different debugging scenarios
      dap.configurations.python = {
        -- Debug the current file
        {
          type = "python",
          request = "launch",
          name = "Debug Current File",
          program = "${file}",
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
          env = function()
            local vars = {}
            for k, v in pairs(vim.fn.environ()) do
              vars[k] = v
            end
            return vars
          end,
          pythonPath = get_python_path(),
        },
        --debug main module
        {
          type = "python",
          request = "launch",
          name = "Debug Main File (Module)",
          module = function()
            -- Look for common main file names in various locations
            local main_files = {
              "main.py",
              "app.py",
              "run.py",
              "__main__.py",
              "src/main.py",
              "src/app.py",
              "src/run.py",
              "app/main.py",
              "app/app.py",
              "app/run.py",
            }

            for _, filename in ipairs(main_files) do
              if vim.fn.filereadable(filename) == 1 then
                -- Convert file path to module notation
                local module_name = filename:gsub("%.py$", ""):gsub("/", ".")
                return module_name
              end
            end

            local input_file = vim.fn.input("Module name (e.g. src.main): ", "", "file")
            return input_file
          end,
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
          pythonPath = get_python_path(),
        },
        -- Debug all tests
        {
          type = "python",
          request = "launch",
          name = "Debug All Tests",
          module = "pytest",
          args = { "-v", "--tb=short" },
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
          pythonPath = get_python_path(),
        },

        -- Debug current test file
        {
          type = "python",
          request = "launch",
          name = "Debug Current Test File",
          module = "pytest",
          args = function()
            local relative_file = vim.fn.expand("%:~:.")
            if string.match(relative_file, "test_.*%.py$") or string.match(relative_file, ".*_test%.py$") then
              return { "-v", "--tb=short", relative_file }
            else
              return { "-v", "--tb=short", vim.fn.input("Test file path: ", "", "file") }
            end
          end,
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
          pythonPath = get_python_path(),
        },
      }

      -- Key mappings for easy access
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
      vim.keymap.set("n", "<leader>dc", dap.continue, { desc = "Continue debugging" })
      vim.keymap.set("n", "<leader>ds", dap.step_over, { desc = "Step over" })
      vim.keymap.set("n", "<leader>di", dap.step_into, { desc = "Step into" })
      vim.keymap.set("n", "<leader>do", dap.step_out, { desc = "Step out" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Open REPL" })
      vim.keymap.set("n", "<leader>dt", dap.terminate, { desc = "Terminate debugging" })
    end,
  },
}
