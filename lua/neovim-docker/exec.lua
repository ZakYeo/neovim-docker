local config = require("neovim-docker.config")
local ui = require("neovim-docker.ui")

local M = {}

local function docker_command()
  local cmd = config.get().docker_cmd
  if type(cmd) == "table" then
    return vim.deepcopy(cmd)
  end
  return { cmd }
end

function M.args(container, shell)
  local args = docker_command()
  vim.list_extend(args, { "exec", "-it", container, shell or config.get().exec_shell })
  return args
end

function M.open(container, opts)
  opts = opts or {}
  if not container or container == "" then
    config.get().notify("error", "Docker exec requires a container id or name")
    return nil
  end

  local shell = opts.shell or config.get().exec_shell
  local page = {
    kind = "exec",
    title = "Docker Exec " .. container,
  }
  local buf = ui.create_buffer(page)
  ui.open(buf, page, opts)
  vim.fn.termopen(M.args(container, shell))
  vim.cmd("startinsert")
  return buf
end

return M
