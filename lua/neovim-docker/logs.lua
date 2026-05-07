local config = require("neovim-docker.config")
local docker = require("neovim-docker.docker")
local ui = require("neovim-docker.ui")

local M = {}

local jobs = {}

local function docker_command()
  local cmd = config.get().docker_cmd
  if type(cmd) == "table" then
    return vim.deepcopy(cmd)
  end
  return { cmd }
end

local function append(buf, lines)
  if not vim.api.nvim_buf_is_valid(buf) or not lines or #lines == 0 then
    return
  end
  local ok = pcall(function()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
    vim.bo[buf].modifiable = false
  end)
  if not ok then
    return
  end
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

local function stop(buf)
  local job = jobs[buf]
  if job then
    vim.fn.jobstop(job)
    jobs[buf] = nil
  end
end

local function attach_keymaps(buf)
  local maps = config.get().keymaps.logs
  vim.keymap.set("n", maps.stop, function()
    stop(buf)
    vim.cmd("bdelete")
  end, { buffer = buf, silent = true, desc = "Stop Docker logs" })
  vim.keymap.set("n", maps.clear, function()
    ui.write(buf, {})
  end, { buffer = buf, silent = true, desc = "Clear Docker logs" })
  vim.keymap.set("n", maps.bottom, function()
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
  end, { buffer = buf, silent = true, desc = "Docker logs bottom" })
end

function M.open(container, opts)
  opts = opts or {}
  if not container or container == "" then
    config.get().notify("error", "Docker logs require a container id or name")
    return nil
  end

  local page = {
    kind = "logs",
    title = "Docker Logs " .. container,
  }
  local buf = ui.create_buffer(page)
  ui.write(buf, { "Docker logs: " .. container, "" })
  attach_keymaps(buf)
  ui.open(buf, page, opts)

  local args = docker.logs_args(container, opts)
  local command = docker_command()
  vim.list_extend(command, args)
  jobs[buf] = vim.fn.jobstart(command, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append(buf, data)
    end,
    on_stderr = function(_, data)
      append(buf, data)
    end,
    on_exit = function(_, code)
      jobs[buf] = nil
      if code ~= 0 then
        append(buf, { "", "docker logs exited with code " .. tostring(code) })
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      stop(buf)
    end,
  })

  return buf
end

return M
