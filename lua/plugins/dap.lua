-- debug.lua
--
-- Example plugin spec (kickstart.nvim style)
-- Merging your Python DAP setup & environment loader
-- with an existing Go DAP config, Rust config, and basic DAP keymaps.
return {
  -- Primary DAP plugin
  "mfussenegger/nvim-dap",

  dependencies = {
    -- DAP UI
    "rcarriga/nvim-dap-ui",

    -- Required dependency for nvim-dap-ui
    "nvim-neotest/nvim-nio",

    -- Installs debug adapters
    "williamboman/mason.nvim",
    "jay-babu/mason-nvim-dap.nvim",

    -- For Go debugging
    "leoluz/nvim-dap-go",

    -- For Python debugging
    "mfussenegger/nvim-dap-python",

    -- For Python testing with pytest + DAP
    "nvim-neotest/neotest",
    "nvim-neotest/neotest-python",

    -- For selecting Python files to debug
    -- (only if you want the telescope-based selection!)
    "nvim-telescope/telescope.nvim",
  },

  --------------------------------------------------------------------------------
  --  1) KEYMAPS
  --------------------------------------------------------------------------------
  keys = {
    -- Basic debugging keymaps (Go, Python, etc.)
  },

  --------------------------------------------------------------------------------
  --  2) CONFIG FUNCTION
  --------------------------------------------------------------------------------
  config = function()
    ----------------------------------------------------------------------------
    -- CORE REQUIRE
    ----------------------------------------------------------------------------
    local dap = require("dap")
    local dapui = require("dapui")

    ----------------------------------------------------------------------------
    -- RUST ANALYZER LSP SETUP (from rust_full.lua)
    ----------------------------------------------------------------------------
    require("lspconfig").rust_analyzer.setup({
      settings = {
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
          },
          checkOnSave = {
            command = "clippy",
          },
        },
      },
    })

    ----------------------------------------------------------------------------
    -- MASON + CODELLDB DAP SETUP (from rust_full.lua)
    ----------------------------------------------------------------------------
    local mason_path = vim.fn.glob(vim.fn.stdpath("data") .. "/mason/")
    local codelldb_path = mason_path .. "packages/codelldb/extension/adapter/codelldb"
    local liblldb_path = mason_path .. "packages/codelldb/extension/lldb/lib/liblldb.so"

    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = codelldb_path,
        args = { "--port", "${port}" },
      },
      -- liblldb = liblldb_path, -- if needed, uncomment for extended debugging
    }

    -- Helper to get crate name from cargo metadata
    local function get_crate_name_from_metadata()
      local output = vim.fn.system("cargo metadata --no-deps --format-version=1")
      if vim.v.shell_error ~= 0 or output == "" then
        return nil
      end

      local ok, decoded = pcall(vim.fn.json_decode, output)
      if not ok or not decoded or not decoded.packages then
        return nil
      end

      -- Di solito il primo package è il crate principale
      if decoded.packages[1] and decoded.packages[1].name then
        return decoded.packages[1].name
      end
      return nil
    end

    -- DAP configurations for Rust
    dap.configurations.rust = {
      -- Esempio di debug binario in debug
      {
        name = "Debug (auto cargo build, crate name from Cargo.toml)",
        type = "codelldb",
        request = "launch",
        program = function()
          -- 1) Build
          local build_cmd = "cargo build"
          print("Running: " .. build_cmd)
          local output = vim.fn.system(build_cmd)
          if vim.v.shell_error ~= 0 then
            vim.notify("Cargo build failed:\n" .. output, vim.log.levels.ERROR)
            return nil
          end

          -- 2) Determine crate name
          local crate_name = get_crate_name_from_metadata()
          if not crate_name then
            vim.notify("Unable to determine crate name from Cargo.toml!", vim.log.levels.ERROR)
            return nil
          end

          -- 3) Construct the binary path
          return vim.fn.getcwd() .. "/target/debug/" .. crate_name
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
      -- Esempio di debug binario in release
      {
        name = "Release (auto cargo build, crate name from Cargo.toml)",
        type = "codelldb",
        request = "launch",
        program = function()
          -- 1) Build
          local build_cmd = "cargo build --release"
          print("Running: " .. build_cmd)
          local output = vim.fn.system(build_cmd)
          if vim.v.shell_error ~= 0 then
            vim.notify("Cargo build failed:\n" .. output, vim.log.levels.ERROR)
            return nil
          end

          -- 2) Determine crate name
          local crate_name = get_crate_name_from_metadata()
          if not crate_name then
            vim.notify("Unable to determine crate name from Cargo.toml!", vim.log.levels.ERROR)
            return nil
          end

          -- 3) Construct the binary path
          return vim.fn.getcwd() .. "/target/release/" .. crate_name
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
      -- Esempio di debug binario esistente (prompt)
      {
        name = "Debug (prompt for existing binary)",
        type = "codelldb",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },

      -- A D D   C A R G O   T E S T   D E B U G   C O N F I G   (aggiunto!)
      {
        name = "Debug cargo test (no-run)",
        type = "codelldb",
        request = "launch",
        program = function()
          -- 1) Compila i test senza eseguirli
          local build_cmd = "cargo test --no-run"
          print("Running: " .. build_cmd)
          local output = vim.fn.system(build_cmd)
          if vim.v.shell_error ~= 0 then
            vim.notify("Cargo test build failed:\n" .. output, vim.log.levels.ERROR)
            return nil
          end

          -- 2) Recupera il nome del crate
          local crate_name = get_crate_name_from_metadata()
          if not crate_name then
            vim.notify("Unable to determine crate name from Cargo.toml!", vim.log.levels.ERROR)
            return nil
          end

          -- 3) Trova il binario test in target/debug/deps
          --    (cargo test produce file tipo: crate_name-<hash>, ecc.)
          local pattern = crate_name:gsub("%-", "%%-") .. "-*"
          local test_binary = vim.fn.glob(vim.fn.getcwd() .. "/target/debug/deps/" .. pattern)
          if test_binary == "" then
            vim.notify(
              "No test binary found. Possibly multiple tests or custom pattern.\nExtend logic if needed.",
              vim.log.levels.ERROR
            )
            return nil
          end

          return test_binary
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        args = {},
      },
    }

    ----------------------------------------------------------------------------
    -- 3a) MASON-NVIM-DAP SETUP
    ----------------------------------------------------------------------------
    require("mason-nvim-dap").setup({
      automatic_installation = true,
      handlers = {},
      ensure_installed = {
        -- For Go
        "delve",
        -- If you also want mason-nvim-dap to manage debugpy, uncomment below:
        -- 'python',
        -- For Rust (codelldb), it’s typically included by default,
        -- but you can ensure it here if you like: 'codelldb'
      },
    })

    ----------------------------------------------------------------------------
    -- 3b) DAP-UI SETUP
    ----------------------------------------------------------------------------
    dapui.setup({
      icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
      controls = {
        icons = {
          pause = "⏸",
          play = "▶",
          step_into = "⏎",
          step_over = "⏭",
          step_out = "⏮",
          step_back = "b",
          run_last = "▶▶",
          terminate = "⏹",
          disconnect = "⏏",
        },
      },
    })

    -- Open/close dapui automatically
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Environment Loader
    ---------------------
    local function load_env_file()
      local env_file = vim.fn.getcwd() .. "/.env"
      if vim.fn.filereadable(env_file) == 1 then
        local env_vars = {}
        for line in io.lines(env_file) do
          -- Skip comments & blank lines
          if not line:match("^%s*#") and line:match("%S") then
            local key, value = line:match("^%s*([^=]+)%s*=%s*(.+)%s*$")
            if key and value then
              key = key:match("^%s*(.-)%s*$")
              value = value:match("^%s*(.-)%s*$")
              -- Remove quotes if present
              value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
              env_vars[key] = value
            end
          end
        end
        return env_vars
      end
      return nil
    end

    -----------------------
    -- Python Path Resolver
    -----------------------
    local function get_python_path()
      local uv_venv = vim.fn.getcwd() .. "/.devenv/state/venv/bin/python"
      if vim.fn.filereadable(uv_venv) == 1 then
        return uv_venv
      end
      -- Try Poetry
      local poetry_path = vim.fn.trim(vim.fn.system("poetry env info --path"))
      if vim.v.shell_error == 0 then
        return poetry_path .. "/bin/python"
      end
      -- Fall back to system Python
      return vim.fn.exepath("python3") or vim.fn.exepath("python")
    end

    ---------------------------------
    -- Setup dap-python (debugpy)
    ---------------------------------
    pcall(function()
      require("dap-python").setup(get_python_path())
    end)

    ---------------------------------
    -- Python DAP Configurations
    ---------------------------------
    dap.configurations.python = dap.configurations.python or {}
    table.insert(dap.configurations.python, 1, {
      type = "python",
      request = "launch",
      name = "Debug pytest with -s",
      module = "pytest",
      args = { "-s" },
      justMyCode = false,
      console = "integratedTerminal",
      env = function()
        return load_env_file()
      end,
      python = function()
        local uv_venv = vim.fn.getcwd() .. "/.devenv/state/venv/bin/python"
        if vim.fn.filereadable(uv_venv) == 1 then
          return uv_venv
        end

        local poetry_env = vim.fn.trim(vim.fn.system("poetry env info --path"))
        if vim.v.shell_error == 0 then
          return poetry_env .. "/bin/python"
        else
          return "/usr/bin/python"
        end
      end,
    })
    table.insert(dap.configurations.python, 2, {
      type = "python",
      request = "launch",
      name = "Debug single pytest",
      module = "pytest",
      args = function()
        local tests = vim.fn.systemlist("pytest --collect-only -q")
        local choices = {}
        for _, test in ipairs(tests) do
          if test:match("^[^=]") and test ~= "no tests ran" then
            table.insert(choices, test)
          end
        end

        local test = vim.fn.inputlist(vim.list_extend({ " Select test to run:" }, choices))
        if test == 0 then
          return nil
        end

        return { "-s", choices[test] }
      end,
      justMyCode = false,
      console = "integratedTerminal",
      env = function()
        return load_env_file()
      end,
      python = function()
        local uv_venv = vim.fn.getcwd() .. "/.devenv/state/venv/bin/python"
        if vim.fn.filereadable(uv_venv) == 1 then
          return uv_venv
        end

        local poetry_env = vim.fn.trim(vim.fn.system("poetry env info --path"))
        if vim.v.shell_error == 0 then
          return poetry_env .. "/bin/python"
        else
          return "/usr/bin/python"
        end
      end,
    })
    table.insert(dap.configurations.python, 3, {
      type = "python",
      request = "launch",
      name = "Debug current test file",
      module = "pytest",
      args = function()
        local current_file = vim.fn.expand("%:p")
        return { "-s", current_file }
      end,
      justMyCode = false,
      console = "integratedTerminal",
      env = function()
        return load_env_file()
      end,
      python = function()
        local uv_venv = vim.fn.getcwd() .. "/.devenv/state/venv/bin/python"
        if vim.fn.filereadable(uv_venv) == 1 then
          return uv_venv
        end

        local poetry_env = vim.fn.trim(vim.fn.system("poetry env info --path"))
        if vim.v.shell_error == 0 then
          return poetry_env .. "/bin/python"
        else
          return "/usr/bin/python"
        end
      end,
    })
    ----------------------------------------------------------------------------
    -- 3e) NEOTEST SETUP FOR PYTHON (pytest)
    ----------------------------------------------------------------------------
    require("neotest").setup({
      adapters = {
        require("neotest-python")({
          dap = {
            justMyCode = false,
            env = function()
              return load_env_file()
            end,
          },
          runner = "pytest",
          python = function()
            local poetry_env = vim.fn.trim(vim.fn.system("poetry env info --path"))
            if vim.v.shell_error == 0 then
              return poetry_env .. "/bin/python"
            end
            return nil
          end,
        }),
      },
    })

    ----------------------------------------------------------------------------
    -- 3f) OPTIONAL: TELESCOPE PICKER TO DEBUG A SELECTED PYTHON FILE
    ----------------------------------------------------------------------------
    local telescope_ok, telescope = pcall(require, "telescope.builtin")
    if telescope_ok then
      _G.debug_selected_python_file = function()
        telescope.find_files({
          prompt_title = "Select Python file to debug",
          cwd = vim.fn.getcwd(),
          find_command = { "rg", "--files", "--type", "py" },
          attach_mappings = function(_, map)
            map("i", "<CR>", function(prompt_bufnr)
              local selection = require("telescope.actions.state").get_selected_entry()
              require("telescope.actions").close(prompt_bufnr)
              if selection then
                dap.run({
                  type = "python",
                  request = "launch",
                  name = "Debug Selected File",
                  program = selection.path,
                  pythonPath = get_python_path(),
                  console = "integratedTerminal",
                  env = load_env_file(),
                })
              end
            end)
            return true
          end,
        })
      end
    else
      _G.debug_selected_python_file = function()
        vim.notify("Telescope not found; cannot select file for debug.", vim.log.levels.ERROR)
      end
    end
  end,
}
