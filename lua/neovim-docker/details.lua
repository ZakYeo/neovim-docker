local ui = require("neovim-docker.ui")

local M = {}

function M.open(title, result, opts)
  local page = {
    kind = "details",
    title = title or "Docker Details",
  }
  local buf = ui.create_buffer(page)
  local lines = {
    page.title,
    string.rep("=", #page.title),
    "",
  }

  if result and result.ok then
    vim.list_extend(lines, result.stdout or {})
  else
    lines[#lines + 1] = "Docker error:"
    lines[#lines + 1] = result and result.error or "No details available"
  end

  ui.write(buf, lines)
  vim.keymap.set("n", "q", "<cmd>bdelete<cr>", { buffer = buf, silent = true, desc = "Close Docker details" })
  ui.open(buf, page, opts)
  return buf
end

return M

