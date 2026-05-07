local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

require("neovim-docker").setup({
  keymaps = { enabled = false },
  confirm = function()
    return true
  end,
})

local docker = require("neovim-docker.docker")
local function await(fetch, opts)
  local done = false
  local value
  fetch(opts or {}, function(result)
    value = result
    done = true
  end)
  vim.wait(10000, function()
    return done
  end)
  return value
end

local checks = {
  containers = await(docker.containers_async),
  images = await(docker.images_async),
  volumes = await(docker.volumes_async),
  networks = await(docker.networks_async),
  projects = await(docker.compose_projects_async),
  registry_status = await(docker.registry_auth_status_async),
}

for kind, result in pairs(checks) do
  assert(result.ok, kind .. ": " .. tostring(result.error))
  print(kind .. "=" .. tostring(#result.items))
end

for _, kind in ipairs({ "containers", "images", "volumes", "networks", "projects" }) do
  local page = require("neovim-docker").open(kind)
  assert(page, kind .. ": page was not created")
  vim.wait(5000, function()
    return not page.loading
  end)
  assert(page.result.ok, kind .. ": " .. tostring(page.result.error))
  print(kind .. " page lines=" .. tostring(vim.api.nvim_buf_line_count(page.buf)))
end

local containers = await(docker.containers_async)
if containers.ok and #containers.items > 0 then
  local buf = require("neovim-docker.logs").open(containers.items[1].id, { tail = 1 })
  assert(buf and vim.api.nvim_buf_is_valid(buf), "logs buffer was not created")
  vim.wait(3000, function()
    return vim.api.nvim_buf_line_count(buf) > 2
  end)
  print("logs lines=" .. tostring(vim.api.nvim_buf_line_count(buf)))
end

local images = await(docker.images_async)
if images.ok and #images.items > 0 then
  local image = images.items[1].Repository and (images.items[1].Repository .. ":" .. (images.items[1].Tag or "latest"))
    or images.items[1].name
  local history = await(docker.image_history_async, { image = image })
  assert(history.ok, "image history: " .. tostring(history.error))
  print("image_history=" .. tostring(#history.items))
end

local projects = await(docker.compose_projects_async)
if projects.ok and #projects.items > 0 and projects.items[1].cwd ~= "" then
  local services = await(docker.compose_services_async, { cwd = projects.items[1].cwd })
  assert(services.ok, "compose services: " .. tostring(services.error))
  print("compose_services=" .. tostring(#services.items))
end
