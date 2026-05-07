local M = {}

local defaults = {
  docker_cmd = "docker",
  compose_cmd = { "docker", "compose" },
  log_tail = 200,
  exec_shell = "/bin/sh",
  timeout = 30000,
  refresh_interval = 0,
  highlights = {
    running = "DiagnosticOk",
    exited = "DiagnosticWarn",
    error = "DiagnosticError",
    header = "Title",
    muted = "Comment",
  },
  ui = {
    default_target = "buffer",
    open_strategy = "current",
    open = nil,
    float = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
    },
  },
  integrations = {
    telescope = {
      enabled = "auto",
    },
  },
  keymaps = {
    enabled = true,
    global = {
      dashboard = "<leader>Dd",
      containers = "<leader>Dc",
      images = "<leader>Di",
      volumes = "<leader>Dv",
      networks = "<leader>Dn",
      compose = "<leader>Dp",
      registries = "<leader>Dr",
    },
    buffer = {
      refresh = "r",
      open = "<CR>",
      inspect = "i",
      logs = "l",
      exec = "e",
      start = "s",
      stop = "S",
      restart = "R",
      remove = "d",
      prune = "p",
      filter = "/",
      clear_filter = "x",
      sort = "o",
      action_menu = "a",
      help = "?",
      quit = "q",
    },
    logs = {
      stop = "q",
      clear = "c",
      bottom = "G",
    },
  },
  confirm = function(action, target)
    local name = target and (target.name or target.Name or target.id or target.ID) or ""
    local message = "Run destructive Docker action '" .. action .. "'"
    if name ~= "" then
      message = message .. " on " .. name
    end
    return vim.fn.confirm(message .. "?", "&Yes\n&No", 2) == 1
  end,
  notify = function(level, message)
    local vim_level = vim.log.levels[string.upper(level)] or vim.log.levels.INFO
    vim.notify(message, vim_level, { title = "neovim-docker" })
  end,
  formatters = {},
}

local options = vim.deepcopy(defaults)

function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  return options
end

function M.get()
  return options
end

function M.defaults()
  return vim.deepcopy(defaults)
end

return M
