describe("views", function()
  it("opens repeated pages with unique listed buffer names", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(_, _, callback)
        callback({
          ok = true,
          code = 0,
          stdout = {},
          stderr = {},
        })
        return 1
      end,
    })
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })

    local views = require("neovim-docker.views")
    local first = views.open("containers")
    local second = views.open("containers")

    truthy(first.buf ~= second.buf)
    truthy(vim.api.nvim_buf_get_name(first.buf):match("docker://containers/"))
    truthy(vim.api.nvim_buf_get_name(second.buf):match("docker://containers/"))
    truthy(vim.api.nvim_buf_get_name(first.buf) ~= vim.api.nvim_buf_get_name(second.buf))
    truthy(vim.bo[first.buf].buflisted)
    truthy(vim.bo[second.buf].buflisted)
  end)

  it("navigates backward and forward between Docker buffers", function()
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    local ui = require("neovim-docker.ui")
    ui.reset_navigation()

    local first_page = { kind = "containers", title = "Docker Containers" }
    local second_page = { kind = "details", title = "Docker Inspect" }
    local first = ui.create_buffer(first_page)
    local second = ui.create_buffer(second_page)

    ui.open(first, first_page)
    ui.open(second, second_page)

    eq(second, vim.api.nvim_get_current_buf())
    truthy(ui.back())
    eq(first, vim.api.nvim_get_current_buf())
    truthy(ui.forward())
    eq(second, vim.api.nvim_get_current_buf())
  end)

  it("skips wiped Docker buffers when navigating backward", function()
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    local ui = require("neovim-docker.ui")
    ui.reset_navigation()

    local first_page = { kind = "containers", title = "Docker Containers" }
    local second_page = { kind = "details", title = "Docker Inspect" }
    local third_page = { kind = "logs", title = "Docker Logs web" }
    local first = ui.create_buffer(first_page)
    local second = ui.create_buffer(second_page)
    local third = ui.create_buffer(third_page)

    ui.open(first, first_page)
    ui.open(second, second_page)
    ui.open(third, third_page)
    vim.api.nvim_buf_delete(second, { force = true })

    truthy(ui.back())
    eq(first, vim.api.nvim_get_current_buf())
  end)

  it("restores the existing window when navigating back from a float", function()
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    local ui = require("neovim-docker.ui")
    ui.reset_navigation()

    local first_page = { kind = "containers", title = "Docker Containers" }
    local help_page = { kind = "details", title = "Docker Page Help" }
    local first = ui.create_buffer(first_page)
    local help = ui.create_buffer(help_page)

    ui.open(first, first_page)
    local first_win = vim.api.nvim_get_current_win()
    ui.open(help, help_page, { strategy = "float" })

    truthy(vim.api.nvim_get_current_win() ~= first_win)
    truthy(ui.back())
    eq(first_win, vim.api.nvim_get_current_win())
    eq(first, vim.api.nvim_get_current_buf())
  end)

  it("does not record navigation when a custom ui.open hook returns false", function()
    local config = require("neovim-docker.config")
    config.setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    local ui = require("neovim-docker.ui")
    ui.reset_navigation()

    local first_page = { kind = "containers", title = "Docker Containers" }
    local second_page = { kind = "details", title = "Docker Inspect" }
    local first = ui.create_buffer(first_page)
    local second = ui.create_buffer(second_page)

    ui.open(first, first_page)
    ui.reset_navigation()
    config.setup({
      ui = {
        open = function()
          return false
        end,
      },
      notify = function() end,
      confirm = function()
        return true
      end,
    })

    eq(false, ui.open(second, second_page))
    eq(false, ui.back())
  end)

  it("returns from help with an explicit back key", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(_, _, callback)
        callback({
          ok = true,
          code = 0,
          stdout = {},
          stderr = {},
        })
        return 1
      end,
    })
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    require("neovim-docker.ui").reset_navigation()

    local page = require("neovim-docker.views").open("containers")
    vim.api.nvim_set_current_buf(page.buf)
    local help_map = vim.fn.maparg("?", "n", false, true)
    help_map.callback()

    truthy(vim.api.nvim_get_current_buf() ~= page.buf)
    local back_map = vim.fn.maparg("b", "n", false, true)
    back_map.callback()
    eq(page.buf, vim.api.nvim_get_current_buf())
  end)

  it("selects the item under the cursor", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(_, _, callback)
        callback({
          ok = true,
          code = 0,
          stdout = {
            '{"ID":"abc","Names":"web","Image":"nginx","State":"running","Status":"Up"}',
            '{"ID":"def","Names":"db","Image":"postgres","State":"exited","Status":"Exited"}',
          },
          stderr = {},
        })
        return 1
      end,
    })
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })

    local page = require("neovim-docker.views").open("containers")
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    eq("abc", require("neovim-docker.views").current_item(page).id)
    vim.api.nvim_win_set_cursor(0, { 9, 0 })
    eq("def", require("neovim-docker.views").current_item(page).id)
  end)

  it("exposes log actions on native container pages", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(_, _, callback)
        callback({
          ok = true,
          code = 0,
          stdout = {},
          stderr = {},
        })
        return 1
      end,
    })
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })

    local containers = require("neovim-docker.views").open("containers")
    local compose_containers = require("neovim-docker.views").open("compose_containers")

    eq("container.logs", containers.spec.actions.logs)
    eq("container.logs", compose_containers.spec.actions.logs)
  end)
end)
