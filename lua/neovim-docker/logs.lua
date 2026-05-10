local config = require("neovim-docker.config")
local docker = require("neovim-docker.docker")
local ui = require("neovim-docker.ui")

local M = {}

local jobs = {}
local header_line_count = 2

local function docker_command()
  local cmd = config.get().docker_cmd
  if type(cmd) == "table" then
    return vim.deepcopy(cmd)
  end
  return { cmd }
end

local function positive_integer(value)
  local number = tonumber(value)
  if not number then
    return nil
  end
  number = math.floor(number)
  if number < 1 then
    return nil
  end
  return number
end

local function max_log_lines(opts)
  opts = opts or {}
  local default_max_lines = config.defaults().log_max_lines
  local configured_max_lines = opts.max_lines
  if configured_max_lines == nil then
    configured_max_lines = config.get().log_max_lines
  end
  return positive_integer(configured_max_lines) or default_max_lines
end

local function normalise_job_lines(lines)
  if not lines or #lines == 0 then
    return {}
  end

  local output = vim.deepcopy(lines)
  if #output > 1 and output[#output] == "" then
    output[#output] = nil
  end
  return output
end

local function slice_tail(lines, max_lines)
  local start = #lines - max_lines + 1
  local output = {}
  for index = start, #lines do
    output[#output + 1] = lines[index]
  end
  return output
end

local function trim_log_lines(buf, max_lines)
  local line_count = vim.api.nvim_buf_line_count(buf)
  local max_buffer_lines = header_line_count + max_lines
  if line_count <= max_buffer_lines then
    return
  end

  local overflow = line_count - max_buffer_lines
  local trim_start = math.min(header_line_count, line_count)
  local trim_end = math.min(trim_start + overflow, line_count)
  if trim_end <= trim_start then
    return
  end

  vim.api.nvim_buf_set_lines(buf, trim_start, trim_end, false, {})
end

local function pretrim_for_append(buf, append_line_count, max_lines)
  if append_line_count >= max_lines then
    trim_log_lines(buf, 0)
    return
  end

  local existing_log_lines = math.max(0, vim.api.nvim_buf_line_count(buf) - header_line_count)
  local allowed_existing_lines = max_lines - append_line_count
  if existing_log_lines > allowed_existing_lines then
    trim_log_lines(buf, allowed_existing_lines)
  end
end

local function bounded_append_lines(buf, lines, max_lines)
  if #lines > max_lines then
    lines = slice_tail(lines, max_lines)
  end
  pretrim_for_append(buf, #lines, max_lines)
  return lines
end

local function append(buf, lines, max_lines)
  if not vim.api.nvim_buf_is_valid(buf) or not lines or #lines == 0 then
    return
  end
  local modifiable = false
  local ok = pcall(function()
    vim.bo[buf].modifiable = true
    modifiable = true
    lines = bounded_append_lines(buf, lines, max_lines)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
    trim_log_lines(buf, max_lines)
  end)
  if modifiable then
    pcall(function()
      vim.bo[buf].modifiable = false
    end)
  end
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

  local retained_log_lines = max_log_lines(opts)
  local args = docker.logs_args(container, opts)
  local command = docker_command()
  vim.list_extend(command, args)
  jobs[buf] = vim.fn.jobstart(command, {
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      append(buf, normalise_job_lines(data), retained_log_lines)
    end,
    on_stderr = function(_, data)
      append(buf, normalise_job_lines(data), retained_log_lines)
    end,
    on_exit = function(_, code)
      jobs[buf] = nil
      if code ~= 0 then
        append(buf, { "", "docker logs exited with code " .. tostring(code) }, retained_log_lines)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = buf,
    once = true,
    callback = function()
      stop(buf)
    end,
  })

  return buf
end

return M
