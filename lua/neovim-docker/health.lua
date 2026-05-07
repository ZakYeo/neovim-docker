local M = {}

local health = vim.health or {}

local function start(name)
  if health.start then
    pcall(health.start, name)
  elseif health.report_start then
    pcall(health.report_start, name)
  end
end

local function ok(message)
  if health.ok then
    pcall(health.ok, message)
  elseif health.report_ok then
    pcall(health.report_ok, message)
  end
end

local function warn(message, advice)
  if health.warn then
    pcall(health.warn, message, advice)
  elseif health.report_warn then
    pcall(health.report_warn, message, advice)
  end
end

local function error(message, advice)
  if health.error then
    pcall(health.error, message, advice)
  elseif health.report_error then
    pcall(health.report_error, message, advice)
  end
end

local function executable(cmd)
  if type(cmd) == "table" then
    return vim.fn.executable(cmd[1]) == 1
  end
  return vim.fn.executable(cmd) == 1
end

function M.check()
  local config = require("neovim-docker.config").get()
  start("neovim-docker")

  if executable(config.docker_cmd) then
    ok("Docker CLI found")
  else
    error("Docker CLI not found", { "Install Docker or configure docker_cmd" })
  end

  if executable(config.compose_cmd) then
    ok("Docker Compose command found")
  else
    warn("Docker Compose command not found", { "Compose views require docker compose" })
  end

  if config.integrations.telescope.enabled == true then
    local has_telescope = pcall(require, "telescope")
    if has_telescope then
      ok("telescope.nvim found")
    else
      warn("telescope.nvim requested but not found")
    end
  end
end

return M
