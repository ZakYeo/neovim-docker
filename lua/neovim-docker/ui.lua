local config = require("neovim-docker.config")

local M = {}

local docker_buffers = {}
local history = {
  back = {},
  forward = {},
}

local function window_size(value, total)
  if value < 1 then
    return math.max(1, math.floor(total * value))
  end
  return value
end

local function open_float(buf)
  local float = config.get().ui.float
  local width = window_size(float.width, vim.o.columns)
  local height = window_size(float.height, vim.o.lines - vim.o.cmdheight)
  local row = math.max(0, math.floor(((vim.o.lines - vim.o.cmdheight) - height) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))

  return vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = float.border,
  })
end

local function slug(value)
  value = tostring(value or ""):lower()
  value = value:gsub("[^%w._-]+", "-")
  value = value:gsub("^%-+", ""):gsub("%-+$", "")
  if value == "" then
    return nil
  end
  return value:sub(1, 48)
end

local function buffer_name(page, buf)
  local kind = slug(page.kind) or "page"
  local title = slug(page.title)
  if title and title ~= kind then
    return string.format("docker://%s/%s-%d", kind, title, buf)
  end
  return string.format("docker://%s/%d", kind, buf)
end

local function valid_docker_buffer(buf)
  return buf and docker_buffers[buf] and vim.api.nvim_buf_is_valid(buf)
end

local function current_docker_buffer()
  local ok, buf = pcall(vim.api.nvim_get_current_buf)
  if ok and valid_docker_buffer(buf) then
    return buf
  end
  return nil
end

local function buffer_entry(buf)
  if not valid_docker_buffer(buf) then
    return nil
  end
  return docker_buffers[buf]
end

local function update_buffer_window(buf, win)
  local entry = buffer_entry(buf)
  if not entry or not win or not vim.api.nvim_win_is_valid(win) then
    return
  end
  entry.win = win
  entry.tab = vim.api.nvim_win_get_tabpage(win)
end

local function current_window_for_buffer(buf)
  local ok, win = pcall(vim.api.nvim_get_current_win)
  if ok and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    update_buffer_window(buf, win)
  end
end

local function push_unique(stack, buf)
  if not valid_docker_buffer(buf) then
    return
  end
  if stack[#stack] ~= buf then
    stack[#stack + 1] = buf
  end
end

local function pop_valid_buffer(stack)
  while #stack > 0 do
    local buf = table.remove(stack)
    if valid_docker_buffer(buf) then
      return buf
    end
  end
  return nil
end

local function valid_window_showing_buffer(win, buf)
  return win
    and vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_buf(win) == buf
    and vim.api.nvim_tabpage_is_valid(vim.api.nvim_win_get_tabpage(win))
end

local function find_window_showing_buffer(buf)
  local entry = buffer_entry(buf)
  if entry and valid_window_showing_buffer(entry.win, buf) then
    return entry.win
  end

  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if valid_window_showing_buffer(win, buf) then
        return win
      end
    end
  end
  return nil
end

local function update_visible_window(buf)
  local win = find_window_showing_buffer(buf)
  if win then
    update_buffer_window(buf, win)
  end
end

local function restore_window(win)
  local tab = vim.api.nvim_win_get_tabpage(win)
  if vim.api.nvim_get_current_tabpage() ~= tab then
    vim.api.nvim_set_current_tabpage(tab)
  end
  vim.api.nvim_set_current_win(win)
end

local function switch_to_buffer(buf)
  if not valid_docker_buffer(buf) then
    return false
  end
  local win = find_window_showing_buffer(buf)
  if win then
    restore_window(win)
    update_buffer_window(buf, win)
    return true
  end

  vim.api.nvim_set_current_buf(buf)
  current_window_for_buffer(buf)
  return true
end

local function attach_navigation_keymaps(buf)
  vim.keymap.set("n", "<C-o>", M.back, { buffer = buf, silent = true, desc = "Docker back" })
  vim.keymap.set("n", "<C-i>", M.forward, { buffer = buf, silent = true, desc = "Docker forward" })
end

function M.create_buffer(page)
  local buf = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(buf, buffer_name(page, buf))
  docker_buffers[buf] = {}
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "docker-" .. page.kind
  attach_navigation_keymaps(buf)
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = buf,
    once = true,
    callback = function()
      docker_buffers[buf] = nil
    end,
  })
  return buf
end

function M.write(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.open(buf, page, opts)
  opts = opts or {}
  local previous = current_docker_buffer()
  local open_hook = config.get().ui.open
  if open_hook then
    local opened = open_hook({
      buf = buf,
      kind = page.kind,
      title = page.title,
      opts = opts,
    })
    if opened == false then
      return false
    end
    update_visible_window(buf)
    M.record_navigation(previous, buf, opts)
    return opened
  end

  local strategy = opts.strategy or config.get().ui.open_strategy
  if strategy == "split" then
    vim.cmd("split")
  elseif strategy == "vsplit" then
    vim.cmd("vsplit")
  elseif strategy == "tab" then
    vim.cmd("tabnew")
  elseif strategy == "float" then
    local win = open_float(buf)
    update_buffer_window(buf, win)
    M.record_navigation(previous, buf, opts)
    return win
  end

  vim.api.nvim_set_current_buf(buf)
  current_window_for_buffer(buf)
  M.record_navigation(previous, buf, opts)
  return vim.api.nvim_get_current_win()
end

function M.record_navigation(previous, current, opts)
  opts = opts or {}
  if opts.history == false or previous == current then
    return
  end
  if valid_docker_buffer(previous) and valid_docker_buffer(current) then
    push_unique(history.back, previous)
    history.forward = {}
  end
end

function M.back()
  local current = current_docker_buffer()
  local previous = pop_valid_buffer(history.back)
  if not previous then
    return false
  end
  if current and current ~= previous then
    push_unique(history.forward, current)
  end
  return switch_to_buffer(previous)
end

function M.forward()
  local current = current_docker_buffer()
  local next_buf = pop_valid_buffer(history.forward)
  if not next_buf then
    return false
  end
  if current and current ~= next_buf then
    push_unique(history.back, current)
  end
  return switch_to_buffer(next_buf)
end

function M.focus(buf)
  return switch_to_buffer(buf)
end

function M.reset_navigation()
  history.back = {}
  history.forward = {}
end

return M
