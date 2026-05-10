describe("views", function()
  local function setup_container_view(stdout, on_run)
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function(args, _, callback)
        if args[2] == "ps" then
          callback({
            ok = true,
            code = 0,
            stdout = stdout,
            stderr = {},
          })
        else
          if on_run then
            on_run(args)
          end
          callback({
            ok = true,
            code = 0,
            stdout = {},
            stderr = {},
          })
        end
        return 1
      end,
    })
    require("neovim-docker.config").setup({
      notify = function() end,
      confirm = function()
        return true
      end,
    })
    return require("neovim-docker.views").open("containers")
  end

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

  it("mentions compose group expansion in page help", function()
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
    vim.fn.maparg("?", "n", false, true).callback()

    local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
    truthy(lines:find("<CR> expand/collapse Compose projects", 1, true))
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

  it("groups compose containers and keeps standalone containers visible", function()
    local page = setup_container_view({
      '{"ID":"abc","Names":"demo-api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
      '{"ID":"def","Names":"demo-db-1","Image":"postgres","State":"exited","Status":"Exited","Labels":"com.docker.compose.project=demo,com.docker.compose.service=db"}',
      '{"ID":"ghi","Names":"cache","Image":"redis","State":"running","Status":"Up","Labels":""}',
    })

    local lines = vim.api.nvim_buf_get_lines(page.buf, 0, -1, false)
    truthy(lines[8]:match("^%[%+%]%s+demo%s+compose project%s+2 containers"))
    truthy(lines[9]:match("^ghi%s+cache%s+redis%s+Up"))
    eq(2, #page.visible_items)
  end)

  it("expands and collapses compose groups with enter", function()
    local page = setup_container_view({
      '{"ID":"abc","Names":"demo-api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
      '{"ID":"def","Names":"demo-db-1","Image":"postgres","State":"exited","Status":"Exited","Labels":"com.docker.compose.project=demo,com.docker.compose.service=db"}',
    })

    vim.api.nvim_set_current_buf(page.buf)
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    vim.fn.maparg("<CR>", "n", false, true).callback()

    local expanded_lines = vim.api.nvim_buf_get_lines(page.buf, 0, -1, false)
    truthy(expanded_lines[8]:match("^%[%-%]%s+demo%s+compose project%s+2 containers"))
    truthy(expanded_lines[9]:match("^abc%s+demo%-api%-1%s+app%s+Up"))
    truthy(expanded_lines[10]:match("^def%s+demo%-db%-1%s+postgres%s+Exited"))
    eq(3, #page.visible_items)

    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    vim.fn.maparg("<CR>", "n", false, true).callback()
    local collapsed_lines = vim.api.nvim_buf_get_lines(page.buf, 0, -1, false)
    truthy(collapsed_lines[8]:match("^%[%+%]%s+demo%s+compose project%s+2 containers"))
    eq(1, #page.visible_items)
  end)

  it("filters compose groups by project label even when names do not include the project", function()
    local page = setup_container_view({
      '{"ID":"abc","Names":"api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
      '{"ID":"def","Names":"db-1","Image":"postgres","State":"exited","Status":"Exited","Labels":"com.docker.compose.project=demo,com.docker.compose.service=db"}',
      '{"ID":"ghi","Names":"api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=other,com.docker.compose.service=api"}',
    })

    local original_input = vim.ui.input
    vim.ui.input = function(_, callback)
      callback("demo")
    end
    vim.api.nvim_set_current_buf(page.buf)
    vim.fn.maparg("/", "n", false, true).callback()
    vim.ui.input = original_input

    local lines = vim.api.nvim_buf_get_lines(page.buf, 0, -1, false)
    truthy(lines[8]:match("^%[%+%]%s+demo%s+compose project%s+2 containers"))
    eq(1, #page.visible_items)
  end)

  it("keeps compose group counts scoped to filtered container matches", function()
    local page = setup_container_view({
      '{"ID":"abc","Names":"api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
      '{"ID":"def","Names":"db-1","Image":"postgres","State":"exited","Status":"Exited","Labels":"com.docker.compose.project=demo,com.docker.compose.service=db"}',
    })

    local original_input = vim.ui.input
    vim.ui.input = function(_, callback)
      callback("postgres")
    end
    vim.api.nvim_set_current_buf(page.buf)
    vim.fn.maparg("/", "n", false, true).callback()
    vim.ui.input = original_input

    local lines = vim.api.nvim_buf_get_lines(page.buf, 0, -1, false)
    truthy(lines[8]:match("^%[%+%]%s+demo%s+compose project%s+1 container"))
    eq(1, #page.visible_items)
  end)

  it("does not run container actions on compose group rows", function()
    local ran_actions = {}
    local page = setup_container_view({
      '{"ID":"abc","Names":"demo-api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
    }, function(args)
      ran_actions[#ran_actions + 1] = args
    end)
    local original_logs_open = require("neovim-docker.logs").open
    local original_exec_open = require("neovim-docker.exec").open
    local opened_logs = false
    local opened_exec = false
    require("neovim-docker.logs").open = function()
      opened_logs = true
    end
    require("neovim-docker.exec").open = function()
      opened_exec = true
    end

    vim.api.nvim_set_current_buf(page.buf)
    for _, key in ipairs({ "i", "l", "e", "d", "s" }) do
      vim.api.nvim_win_set_cursor(0, { 8, 0 })
      vim.fn.maparg(key, "n", false, true).callback()
    end

    require("neovim-docker.logs").open = original_logs_open
    require("neovim-docker.exec").open = original_exec_open
    eq(0, #ran_actions)
    eq(false, opened_logs)
    eq(false, opened_exec)
  end)

  it("keeps enter inspect behavior for container rows", function()
    local run_args
    local page = setup_container_view({
      '{"ID":"abc","Names":"demo-api-1","Image":"app","State":"running","Status":"Up","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
    }, function(args)
      run_args = args
    end)

    vim.api.nvim_set_current_buf(page.buf)
    vim.api.nvim_win_set_cursor(0, { 8, 0 })
    vim.fn.maparg("<CR>", "n", false, true).callback()
    vim.api.nvim_win_set_cursor(0, { 9, 0 })
    vim.fn.maparg("<CR>", "n", false, true).callback()

    eq({ "docker", "inspect", "abc" }, run_args)
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
