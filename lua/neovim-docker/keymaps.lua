local M = {}

local function set(lhs, rhs, desc)
  if lhs and lhs ~= "" then
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
  end
end

function M.setup(opts)
  if opts.keymaps.enabled == false then
    return
  end

  local maps = opts.keymaps.global
  set(maps.dashboard, "<cmd>DockerDashboard<cr>", "Docker dashboard")
  set(maps.containers, "<cmd>DockerContainers<cr>", "Docker containers")
  set(maps.images, "<cmd>DockerImages<cr>", "Docker images")
  set(maps.volumes, "<cmd>DockerVolumes<cr>", "Docker volumes")
  set(maps.networks, "<cmd>DockerNetworks<cr>", "Docker networks")
  set(maps.compose, "<cmd>DockerCompose<cr>", "Docker compose")
  set(maps.registries, "<cmd>DockerRegistries<cr>", "Docker registries")
end

return M
