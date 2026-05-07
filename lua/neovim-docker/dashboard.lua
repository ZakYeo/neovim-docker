local docker = require("neovim-docker.docker")
local ui = require("neovim-docker.ui")
local views = require("neovim-docker.views")

local M = {}

local function count(result)
  if result and result.ok and result.items then
    return tostring(#result.items)
  end
  return "?"
end

local function render(buf, counts)
  ui.write(buf, {
    "Docker Dashboard",
    "================",
    "",
    "Containers: " .. (counts.containers or "...") .. "   [c]",
    "Images:     " .. (counts.images or "...") .. "   [i]",
    "Volumes:    " .. (counts.volumes or "...") .. "   [v]",
    "Networks:   " .. (counts.networks or "...") .. "   [n]",
    "Projects:   " .. (counts.projects or "...") .. "   [p]",
    "",
    "Compose:    [s]",
    "Registry:   [r]",
  })
end

local function map(buf, lhs, kind, desc)
  vim.keymap.set("n", lhs, function()
    views.open(kind)
  end, { buffer = buf, silent = true, desc = desc })
end

function M.open(opts)
  local page = {
    kind = "dashboard",
    title = "Docker Dashboard",
  }
  local buf = ui.create_buffer(page)
  local counts = {}
  render(buf, counts)

  local pending = 5
  local function update(key)
    return function(result)
      counts[key] = count(result)
      pending = pending - 1
      if vim.api.nvim_buf_is_valid(buf) then
        render(buf, counts)
      end
    end
  end

  docker.containers_async({}, update("containers"))
  docker.images_async({}, update("images"))
  docker.volumes_async({}, update("volumes"))
  docker.networks_async({}, update("networks"))
  docker.compose_projects_async({}, update("projects"))

  map(buf, "c", "containers", "Docker containers")
  map(buf, "i", "images", "Docker images")
  map(buf, "v", "volumes", "Docker volumes")
  map(buf, "n", "networks", "Docker networks")
  map(buf, "p", "projects", "Docker Compose projects")
  map(buf, "s", "compose", "Docker Compose services")
  vim.keymap.set("n", "r", function()
    views.registry()
  end, { buffer = buf, silent = true, desc = "Docker registries" })
  vim.keymap.set("n", "q", "<cmd>bdelete<cr>", { buffer = buf, silent = true, desc = "Close Docker dashboard" })

  ui.open(buf, page, opts)
  return buf
end

return M
