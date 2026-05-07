describe("actions", function()
  it("dispatches container lifecycle commands", function()
    local calls = {}
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function(args)
        calls[#calls + 1] = args
        return { ok = true, code = 0, stdout = {}, stderr = {} }
      end,
    })

    local actions = require("neovim-docker.actions")
    eq(true, actions.run("container.start", { id = "abc" }).ok)
    eq(true, actions.run("container.stop", { id = "abc" }).ok)
    eq({ "docker", "start", "abc" }, calls[1])
    eq({ "docker", "stop", "abc" }, calls[2])
  end)

  it("marks destructive actions for confirmation", function()
    local actions = require("neovim-docker.actions")
    eq(true, actions.requires_confirmation("container.remove"))
    eq(true, actions.requires_confirmation("volume.prune"))
    eq(false, actions.requires_confirmation("container.start"))
  end)

  it("dispatches registry and compose commands", function()
    local calls = {}
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function(args)
        calls[#calls + 1] = args
        return { ok = true, code = 0, stdout = {}, stderr = {} }
      end,
    })

    local actions = require("neovim-docker.actions")
    actions.run("image.pull", { name = "alpine:latest" })
    actions.run("image.push", { name = "example/app:latest" })
    actions.run("compose.up", { cwd = "/tmp/project" })
    actions.run("compose.service.build", { cwd = "/tmp/project", name = "api" })
    actions.run("image.prune", {}, { skip_confirm = true })
    actions.run("compose.service.down", { cwd = "/tmp/project", name = "api" })

    eq({ "docker", "pull", "alpine:latest" }, calls[1])
    eq({ "docker", "push", "example/app:latest" }, calls[2])
    eq({ "docker", "compose", "up", "-d" }, calls[3])
    eq({ "docker", "compose", "build", "api" }, calls[4])
    eq({ "docker", "image", "prune", "-f" }, calls[5])
    eq({ "docker", "compose", "stop", "api" }, calls[6])
  end)

  it("dispatches async actions", function()
    local calls = {}
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(args, _, callback)
        calls[#calls + 1] = args
        callback({ ok = true, code = 0, stdout = {}, stderr = {} })
        return 7
      end,
    })

    local result
    local job = require("neovim-docker.actions").run_async("container.restart", { id = "abc" }, {}, function(value)
      result = value
    end)
    eq(7, job)
    eq(true, result.ok)
    eq({ "docker", "restart", "abc" }, calls[1])
  end)
end)
