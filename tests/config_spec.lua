describe("config", function()
  it("merges defaults with user options", function()
    local config = require("neovim-docker.config")
    config.setup({
      ui = { open_strategy = "tab" },
      keymaps = { global = { containers = "<leader>xc" } },
    })

    eq("docker", config.get().docker_cmd)
    eq("tab", config.get().ui.open_strategy)
    eq("<leader>xc", config.get().keymaps.global.containers)
    eq("<leader>Di", config.get().keymaps.global.images)
  end)

  it("supports replacing notifier and opener hooks", function()
    local config = require("neovim-docker.config")
    local notified = false
    config.setup({
      notify = function()
        notified = true
      end,
      ui = {
        open = function() end,
      },
    })

    config.get().notify("info", "hello")
    truthy(notified)
    eq("function", type(config.get().ui.open))
  end)
end)
