local config = require("neovim-docker.config")
local docker = require("neovim-docker.docker")
local ui = require("neovim-docker.ui")

local M = {}

local jobs = {}
local header_line_count = 2
local highlights_ns = vim.api.nvim_create_namespace("neovim-docker-logs")
local ansi_groups = {}

local ansi_basic_colors = {
  [0] = "#1f2937",
  [1] = "#dc2626",
  [2] = "#16a34a",
  [3] = "#ca8a04",
  [4] = "#2563eb",
  [5] = "#9333ea",
  [6] = "#0891b2",
  [7] = "#e5e7eb",
  [8] = "#6b7280",
  [9] = "#ef4444",
  [10] = "#22c55e",
  [11] = "#eab308",
  [12] = "#3b82f6",
  [13] = "#a855f7",
  [14] = "#06b6d4",
  [15] = "#f9fafb",
}

local ansi_color_cube = { 0, 95, 135, 175, 215, 255 }

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

local function hex(value)
  return string.format("%02x", value)
end

local function xterm_color(index)
  if index < 0 or index > 255 then
    return nil
  end
  if index < 16 then
    return ansi_basic_colors[index]
  end
  if index >= 232 then
    local level = 8 + ((index - 232) * 10)
    return "#" .. hex(level) .. hex(level) .. hex(level)
  end

  local adjusted = index - 16
  local red = math.floor(adjusted / 36)
  local green = math.floor((adjusted % 36) / 6)
  local blue = adjusted % 6
  return "#" .. hex(ansi_color_cube[red + 1]) .. hex(ansi_color_cube[green + 1]) .. hex(ansi_color_cube[blue + 1])
end

local function ansi_group(index)
  local color = xterm_color(index)
  if not color then
    return nil
  end

  local name = "NeovimDockerAnsi" .. tostring(index)
  if not ansi_groups[name] then
    pcall(vim.api.nvim_set_hl, 0, name, { fg = color })
    ansi_groups[name] = true
  end
  return name
end

local function sgr_codes(value)
  if value == "" then
    return { 0 }
  end

  local codes = {}
  for code in value:gmatch("%d+") do
    codes[#codes + 1] = tonumber(code)
  end
  if #codes == 0 then
    codes[1] = 0
  end
  return codes
end

local function apply_sgr_codes(codes, active_group)
  local index = 1
  while index <= #codes do
    local code = codes[index]
    if code == 0 or code == 39 then
      active_group = nil
    elseif code and code >= 30 and code <= 37 then
      active_group = ansi_group(code - 30)
    elseif code and code >= 90 and code <= 97 then
      active_group = ansi_group(code - 90 + 8)
    elseif code == 38 and codes[index + 1] == 5 and codes[index + 2] then
      active_group = ansi_group(codes[index + 2])
      index = index + 2
    end
    index = index + 1
  end
  return active_group
end

local function parse_ansi_line(line)
  local output = {}
  local segments = {}
  local active_group
  local plain_col = 0
  local cursor = 1
  local has_ansi = false

  while true do
    local escape_start, escape_end, codes = line:find("\27%[([%d;]*)m", cursor)
    if not escape_start then
      break
    end

    has_ansi = true
    local text = line:sub(cursor, escape_start - 1)
    if text ~= "" then
      output[#output + 1] = text
      if active_group then
        segments[#segments + 1] = {
          start_col = plain_col,
          end_col = plain_col + #text,
          group = active_group,
        }
      end
      plain_col = plain_col + #text
    end

    active_group = apply_sgr_codes(sgr_codes(codes), active_group)
    cursor = escape_end + 1
  end

  local text = line:sub(cursor)
  if text ~= "" then
    output[#output + 1] = text
    if active_group then
      segments[#segments + 1] = {
        start_col = plain_col,
        end_col = plain_col + #text,
        group = active_group,
      }
    end
  end

  if not has_ansi then
    return line, nil
  end
  return table.concat(output), segments
end

local function parse_ansi_lines(lines)
  local output = {}
  local ansi_segments = {}
  local has_ansi = false

  for index, line in ipairs(lines) do
    local clean_line, segments = parse_ansi_line(line)
    output[index] = clean_line
    if segments and #segments > 0 then
      ansi_segments[index] = segments
      has_ansi = true
    end
  end

  return output, has_ansi and ansi_segments or nil
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

local function slice_ansi_segments(segments, original_count, retained_count)
  if not segments or retained_count == original_count then
    return segments
  end

  local offset = original_count - retained_count
  local output = {}
  for index = offset + 1, original_count do
    if segments[index] then
      output[index - offset] = segments[index]
    end
  end
  return output
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

local function is_npm_notice(line)
  return line:lower():find("npm notice", 1, true) ~= nil
end

local function highlight_log_line(buf, line_index, line, groups)
  if line_index < header_line_count or line == "" then
    return
  end

  local line_group = is_npm_notice(line) and groups.npm_notice or line_severity_group(line, groups)
  if line_group then
    add_highlight(buf, line_index, 0, #line, line_group, 80)
  end

  highlight_range(buf, line_index, line, "%d%d%d%d%-%d%d%-%d%d[T ][%d:%.]+Z?", groups.timestamp, 160)
  highlight_range(buf, line_index, line, "^%[[^%]]+%]", groups.timestamp, 160)
  highlight_range(buf, line_index, line, "^[%w_.-]+%s+|", groups.source, 170)
  highlight_http_status(buf, line_index, line, groups)
end

local function highlight_ansi_segments(buf, line_index, segments)
  for _, segment in ipairs(segments or {}) do
    add_highlight(buf, line_index, segment.start_col, segment.end_col, segment.group, 180)
  end
end

local function highlight_lines(buf, first_line, last_line, ansi_segments)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end

  local groups = config.get().highlights.logs or {}
  local lines = vim.api.nvim_buf_get_lines(buf, first_line, last_line + 1, false)
  for offset, line in ipairs(lines) do
    local line_index = first_line + offset - 1
    local segments = ansi_segments and ansi_segments[offset]
    if segments then
      highlight_ansi_segments(buf, line_index, segments)
    else
      highlight_log_line(buf, line_index, line, groups)
    end
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
  local ansi_segments
  local ok = pcall(function()
    vim.bo[buf].modifiable = true
    modifiable = true
    lines, ansi_segments = parse_ansi_lines(lines)
    local original_count = #lines
    lines = bounded_append_lines(buf, lines, max_lines)
    ansi_segments = slice_ansi_segments(ansi_segments, original_count, #lines)
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
    highlight_lines(buf, highlight_start, highlight_end, ansi_segments)
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
