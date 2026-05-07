local config = require("neovim-docker.config")

local M = {}

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

function M.create_buffer(page)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "docker://" .. page.kind)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "docker-" .. page.kind
  return buf
end

function M.write(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

function M.open(buf, page, opts)
  opts = opts or {}
  local open_hook = config.get().ui.open
  if open_hook then
    return open_hook({
      buf = buf,
      kind = page.kind,
      title = page.title,
      opts = opts,
    })
  end

  local strategy = opts.strategy or config.get().ui.open_strategy
  if strategy == "split" then
    vim.cmd("split")
  elseif strategy == "vsplit" then
    vim.cmd("vsplit")
  elseif strategy == "tab" then
    vim.cmd("tabnew")
  elseif strategy == "float" then
    return open_float(buf)
  end

  vim.api.nvim_set_current_buf(buf)
  return vim.api.nvim_get_current_win()
end

return M
