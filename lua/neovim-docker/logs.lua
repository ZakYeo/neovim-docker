local config = require("neovim-docker.config")
local docker = require("neovim-docker.docker")
local ui = require("neovim-docker.ui")

local M = {}

local jobs = {}
local header_line_count = 2
local highlights_ns = vim.api.nvim_create_namespace("neovim-docker-logs")

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

local function token_match(line, token)
  local start_col, end_col = line:find(token, 1, true)
  while start_col do
    local before = start_col > 1 and line:sub(start_col - 1, start_col - 1) or ""
    local after = end_col < #line and line:sub(end_col + 1, end_col + 1) or ""
    if not before:match("[%w_%-]") and not after:match("[%w_%-]") then
      return true
    end
    start_col, end_col = line:find(token, end_col + 1, true)
  end
  return false
end

local function add_highlight(buf, line_index, start_col, end_col, group, priority)
  if not group or group == "" then
    return
  end
  pcall(vim.api.nvim_buf_set_extmark, buf, highlights_ns, line_index, start_col, {
    end_col = end_col,
    hl_group = group,
    priority = priority or 100,
  })
end

local function highlight_range(buf, line_index, line, pattern, group, priority)
  local start_col, end_col = line:find(pattern)
  if start_col and end_col then
    add_highlight(buf, line_index, start_col - 1, end_col, group, priority)
  end
end

local function line_severity_group(line, groups)
  local upper = line:upper()
  if token_match(upper, "FATAL") or token_match(upper, "PANIC") or token_match(upper, "CRITICAL") then
    return groups.error
  end
  if token_match(upper, "ERROR") or upper:find("[ERR]", 1, true) then
    return groups.error
  end
  if token_match(upper, "WARN") or token_match(upper, "WARNING") then
    return groups.warn
  end
  if token_match(upper, "DEBUG") then
    return groups.debug
  end
  if token_match(upper, "TRACE") then
    return groups.trace
  end
  if token_match(upper, "INFO") then
    return groups.info
  end
  if token_match(upper, "SUCCESS") or token_match(upper, "READY") or token_match(upper, "HEALTHY") then
    return groups.success
  end
  return nil
end

local function highlight_http_status(buf, line_index, line, groups)
  local start_col, end_col, status = line:find("(%d%d%d)")
  while start_col and status do
    local before = start_col > 1 and line:sub(start_col - 1, start_col - 1) or ""
    local after = end_col < #line and line:sub(end_col + 1, end_col + 1) or ""
    local group
    if not before:match("[%w_%-]") and not after:match("[%w_%-]") then
      if status:sub(1, 1) == "2" then
        group = groups.http_2xx
      elseif status:sub(1, 1) == "3" then
        group = groups.http_3xx
      elseif status:sub(1, 1) == "4" then
        group = groups.http_4xx
      elseif status:sub(1, 1) == "5" then
        group = groups.http_5xx
      end
      if group then
        add_highlight(buf, line_index, start_col - 1, start_col + 2, group, 150)
      end
    end
    start_col, end_col, status = line:find("(%d%d%d)", end_col + 1)
  end
end

local function highlight_log_line(buf, line_index, line, groups)
  if line_index < header_line_count or line == "" then
    return
  end

  local severity_group = line_severity_group(line, groups)
  if severity_group then
    add_highlight(buf, line_index, 0, #line, severity_group, 80)
  end

  highlight_range(buf, line_index, line, "%d%d%d%d%-%d%d%-%d%d[T ][%d:%.]+Z?", groups.timestamp, 160)
  highlight_range(buf, line_index, line, "^%[[^%]]+%]", groups.timestamp, 160)
  highlight_range(buf, line_index, line, "^[%w_.-]+%s+|", groups.source, 170)
  highlight_http_status(buf, line_index, line, groups)
end

local function highlight_lines(buf, first_line, last_line)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local groups = config.get().highlights.logs or {}
  local lines = vim.api.nvim_buf_get_lines(buf, first_line, last_line + 1, false)
  for offset, line in ipairs(lines) do
    highlight_log_line(buf, first_line + offset - 1, line, groups)
  end
end

local function apply_header_highlight(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local header = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
  add_highlight(buf, 0, 0, #header, config.get().highlights.header, 100)
end

local function clear_highlights(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_clear_namespace, buf, highlights_ns, 0, -1)
  end
end

local function write_header(buf, container)
  ui.write(buf, { "Docker logs: " .. container, "" })
  clear_highlights(buf)
  apply_header_highlight(buf)
end

local function append(buf, lines, max_lines)
  if not vim.api.nvim_buf_is_valid(buf) or not lines or #lines == 0 then
    return
  end
  local modifiable = false
  local highlight_start
  local highlight_end
  local ok = pcall(function()
    vim.bo[buf].modifiable = true
    modifiable = true
    lines = bounded_append_lines(buf, lines, max_lines)
    highlight_start = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)
    trim_log_lines(buf, max_lines)
    local line_count = vim.api.nvim_buf_line_count(buf)
    highlight_end = line_count - 1
    highlight_start = math.max(header_line_count, line_count - #lines)
  end)
  if modifiable then
    pcall(function()
      vim.bo[buf].modifiable = false
    end)
  end
  if not ok then
    return
  end
  if highlight_start and highlight_end and highlight_start <= highlight_end then
    highlight_lines(buf, highlight_start, highlight_end)
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

local function attach_keymaps(buf, container)
  local maps = config.get().keymaps.logs
  vim.keymap.set("n", maps.stop, function()
    stop(buf)
    vim.cmd("bdelete")
  end, { buffer = buf, silent = true, desc = "Stop Docker logs" })
  vim.keymap.set("n", maps.clear, function()
    write_header(buf, container)
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
  write_header(buf, container)
  attach_keymaps(buf, container)
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
