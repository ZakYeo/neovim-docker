describe("config", function()
  it("merges defaults with user options", function()
    local config = require("neovim-docker.config")
    config.setup({
      ui = { open_strategy = "tab" },
      keymaps = { global = { containers = "<leader>xc" } },
    })

    eq("docker", config.get().docker_cmd)
    eq(200, config.get().log_tail)
    eq(5000, config.get().log_max_lines)
    eq("tab", config.get().ui.open_strategy)
    eq("auto", config.get().integrations.which_key.enabled)
    eq(false, config.get().integrations.which_key.action_menu)
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
