local config = require("neovim-docker.config")

local M = {}

local commands = {
  "DockerDashboard",
  "DockerContainers",
  "DockerImages",
  "DockerVolumes",
  "DockerNetworks",
  "DockerCompose",
  "DockerComposeCwd",
  "DockerComposeProjects",
  "DockerComposeFiles",
  "DockerComposeContainers",
  "DockerRegistries",
  "DockerLogs",
  "DockerExec",
  "DockerPull",
  "DockerPush",
  "DockerTag",
  "DockerSearch",
  "DockerImageHistory",
  "DockerImagePrune",
  "DockerRegistryStatus",
  "DockerAction",
  "DockerTelescopeContainers",
  "DockerTelescopeImages",
  "DockerTelescopeVolumes",
}

local function nargs_target(opts)
  if opts.args and opts.args ~= "" then
    return opts.args
  end
  return nil
end

local function complete_actions()
  return require("neovim-docker.actions").names()
end

local function create_commands()
  for _, name in ipairs(commands) do
    pcall(vim.api.nvim_del_user_command, name)
  end

  vim.api.nvim_create_user_command("DockerDashboard", function(opts)
    require("neovim-docker.dashboard").open({ strategy = opts.bang and "float" or nil })
  end, { bang = true, desc = "Open Docker dashboard" })

  vim.api.nvim_create_user_command("DockerContainers", function()
    M.open("containers")
  end, { desc = "Open Docker containers" })

  vim.api.nvim_create_user_command("DockerImages", function()
    M.open("images")
  end, { desc = "Open Docker images" })

  vim.api.nvim_create_user_command("DockerVolumes", function()
    M.open("volumes")
  end, { desc = "Open Docker volumes" })

  vim.api.nvim_create_user_command("DockerNetworks", function()
    M.open("networks")
  end, { desc = "Open Docker networks" })

  vim.api.nvim_create_user_command("DockerCompose", function()
    M.open("compose", { cwd = vim.fn.getcwd() })
  end, { desc = "Open Docker Compose services" })

  vim.api.nvim_create_user_command("DockerComposeCwd", function(opts)
    if opts.args ~= "" then
      M.open("compose", { cwd = opts.args })
      return
    end
    vim.ui.input({ prompt = "Docker Compose cwd: ", default = vim.fn.getcwd(), completion = "dir" }, function(input)
      if input and input ~= "" then
        M.open("compose", { cwd = input })
      end
    end)
  end, { nargs = "?", complete = "dir", desc = "Open Docker Compose services from a chosen cwd" })

  vim.api.nvim_create_user_command("DockerComposeProjects", function()
    M.open("projects")
  end, { desc = "Open Docker Compose projects" })

  vim.api.nvim_create_user_command("DockerComposeFiles", function(opts)
    M.open("compose_files", { cwd = opts.args ~= "" and opts.args or vim.fn.getcwd() })
  end, { nargs = "?", complete = "dir", desc = "Discover Docker Compose files" })

  vim.api.nvim_create_user_command("DockerComposeContainers", function(opts)
    M.open("compose_containers", { project = opts.args })
  end, { nargs = 1, desc = "Open Docker Compose containers for a project" })

  vim.api.nvim_create_user_command("DockerRegistries", function()
    require("neovim-docker.views").registry()
  end, { desc = "Open Docker registry workflows" })

  vim.api.nvim_create_user_command("DockerLogs", function(opts)
    require("neovim-docker.logs").open(nargs_target(opts))
  end, { nargs = "?", complete = "shellcmd", desc = "Tail Docker container logs" })

  vim.api.nvim_create_user_command("DockerExec", function(opts)
    require("neovim-docker.exec").open(opts.fargs[1], { shell = opts.fargs[2] })
  end, { nargs = "*", complete = "shellcmd", desc = "Open a shell in a Docker container" })

  vim.api.nvim_create_user_command("DockerPull", function(opts)
    require("neovim-docker.actions").run_async("image.pull", { name = opts.args })
  end, { nargs = 1, desc = "Pull Docker image" })

  vim.api.nvim_create_user_command("DockerPush", function(opts)
    require("neovim-docker.actions").run_async("image.push", { name = opts.args })
  end, { nargs = 1, desc = "Push Docker image" })

  vim.api.nvim_create_user_command("DockerTag", function(opts)
    if #opts.fargs < 2 then
      config.get().notify("error", "DockerTag requires source and target image names")
      return
    end
    require("neovim-docker.actions").run_async("image.tag", { source = opts.fargs[1], tag = opts.fargs[2] })
  end, { nargs = "*", desc = "Tag Docker image" })

  vim.api.nvim_create_user_command("DockerSearch", function(opts)
    M.open("image_search", { query = opts.args })
  end, { nargs = 1, desc = "Search Docker Hub images" })

  vim.api.nvim_create_user_command("DockerImageHistory", function(opts)
    M.open("image_history", { image = opts.args })
  end, { nargs = 1, complete = "shellcmd", desc = "Show Docker image history" })

  vim.api.nvim_create_user_command("DockerImagePrune", function()
    require("neovim-docker.actions").run_async("image.prune", {})
  end, { desc = "Prune dangling Docker images" })

  vim.api.nvim_create_user_command("DockerRegistryStatus", function()
    M.open("registry_status")
  end, { desc = "Show Docker registry status" })

  vim.api.nvim_create_user_command("DockerAction", function(opts)
    if #opts.fargs < 1 then
      config.get().notify("error", "DockerAction requires an action name")
      return
    end
    require("neovim-docker.actions").run_async(opts.fargs[1], { id = opts.fargs[2], name = opts.fargs[2] })
  end, { nargs = "*", complete = complete_actions, desc = "Run Docker action" })

  vim.api.nvim_create_user_command("DockerTelescopeContainers", function()
    require("neovim-docker.telescope").containers()
  end, { desc = "Pick Docker containers with Telescope" })

  vim.api.nvim_create_user_command("DockerTelescopeImages", function()
    require("neovim-docker.telescope").images()
  end, { desc = "Pick Docker images with Telescope" })

  vim.api.nvim_create_user_command("DockerTelescopeVolumes", function()
    require("neovim-docker.telescope").volumes()
  end, { desc = "Pick Docker volumes with Telescope" })
end

function M.setup(opts)
  local resolved = config.setup(opts)
  require("neovim-docker.docker").setup(resolved.cli or {})
  create_commands()
  require("neovim-docker.keymaps").setup(resolved)
  return resolved
end

function M.open(kind, opts)
  return require("neovim-docker.views").open(kind, opts)
end

function M.logs(container, opts)
  return require("neovim-docker.logs").open(container, opts)
end

function M.action(action_name, target, opts)
  return require("neovim-docker.actions").run_async(action_name, target, opts)
end

return M
