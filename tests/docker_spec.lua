describe("docker cli", function()
  it("builds list calls and parses json lines", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function(args)
        eq({ "docker", "ps", "-a", "--format", "{{json .}}" }, args)
        return {
          ok = true,
          code = 0,
          stdout = {
            '{"ID":"abc","Names":"web","Image":"nginx","State":"running","Status":"Up 1 minute"}',
            '{"ID":"def","Names":"db","Image":"postgres","State":"exited","Status":"Exited"}',
          },
          stderr = {},
        }
      end,
    })

    local result = docker.containers()
    eq(true, result.ok)
    eq(2, #result.items)
    eq("web", result.items[1].name)
    eq("abc", result.items[1].id)
  end)

  it("returns a clear unavailable error", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function()
        return {
          ok = false,
          code = 127,
          stdout = {},
          stderr = { "docker: command not found" },
        }
      end,
    })

    local result = docker.images()
    eq(false, result.ok)
    truthy(result.error:match("docker"))
  end)

  it("builds compose calls with configured cwd", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function(args, opts)
        eq({ "docker", "compose", "ps", "-a", "--format", "json" }, args)
        eq("/tmp/project", opts.cwd)
        return {
          ok = true,
          code = 0,
          stdout = { '[{"Name":"api","Service":"api","State":"running"}]' },
          stderr = {},
        }
      end,
    })

    local result = docker.compose_services({ cwd = "/tmp/project" })
    eq(true, result.ok)
    eq("api", result.items[1].name)
  end)

  it("builds compose calls with configured compose files", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function(args, opts)
        eq({
          "docker",
          "compose",
          "-f",
          "/tmp/project/custom.yml",
          "-f",
          "/tmp/project/compose.override.yml",
          "ps",
          "-a",
          "--format",
          "json",
        }, args)
        eq("/tmp/project", opts.cwd)
        return {
          ok = true,
          code = 0,
          stdout = { '[{"Name":"api","Service":"api","State":"running"}]' },
          stderr = {},
        }
      end,
    })

    local result = docker.compose_services({
      cwd = "/tmp/project",
      config_files = "/tmp/project/custom.yml,/tmp/project/compose.override.yml",
    })
    eq(true, result.ok)
    eq("api", result.items[1].name)
  end)

  it("preserves multiple compose config files from labels", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function()
        return {
          ok = true,
          code = 0,
          stdout = {
            '{"ID":"abc","Names":"demo-api-1","State":"running","Labels":"com.docker.compose.project=demo,com.docker.compose.project.config_files=/tmp/demo/custom.yml,/tmp/demo/compose.override.yml,com.docker.compose.service=api,com.docker.compose.project.working_dir=/tmp/demo"}',
          },
          stderr = {},
        }
      end,
    })

    local result = docker.compose_projects()
    eq(true, result.ok)
    eq("/tmp/demo/custom.yml,/tmp/demo/compose.override.yml", result.items[1].config_files)
  end)

  it("groups compose projects from container labels", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function()
        return {
          ok = true,
          code = 0,
          stdout = {
            '{"ID":"abc","Names":"demo-api-1","State":"running","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api,com.docker.compose.project.working_dir=/tmp/demo"}',
            '{"ID":"def","Names":"demo-db-1","State":"exited","Labels":"com.docker.compose.project=demo,com.docker.compose.service=db,com.docker.compose.project.working_dir=/tmp/demo"}',
          },
          stderr = {},
        }
      end,
    })

    local result = docker.compose_projects()
    eq(true, result.ok)
    eq(1, #result.items)
    eq("demo", result.items[1].project)
    eq("1 running / 2 total", result.items[1].status)
    eq("api,db", result.items[1].services)
    eq("/tmp/demo", result.items[1].cwd)
  end)

  it("filters compose containers by project", function()
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner = function()
        return {
          ok = true,
          code = 0,
          stdout = {
            '{"ID":"abc","Names":"demo-api-1","State":"running","Labels":"com.docker.compose.project=demo,com.docker.compose.service=api"}',
            '{"ID":"def","Names":"other-api-1","State":"running","Labels":"com.docker.compose.project=other,com.docker.compose.service=api"}',
          },
          stderr = {},
        }
      end,
    })

    local result = docker.compose_containers({ project = "demo" })
    eq(true, result.ok)
    eq(1, #result.items)
    eq("api", result.items[1].service)
  end)

  it("discovers compose files in a directory", function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    vim.fn.writefile({ "services: {}" }, dir .. "/compose.yaml")

    local result = require("neovim-docker.docker").discover_compose_files(dir)
    eq(true, result.ok)
    eq(1, #result.items)
    eq("compose.yaml", result.items[1].name)
    eq(dir, result.items[1].cwd)
  end)

  it("builds live log calls with configurable initial tail", function()
    require("neovim-docker.config").setup({ log_tail = 50 })

    local docker = require("neovim-docker.docker")
    eq({ "logs", "--follow", "--tail", "50", "web" }, docker.logs_args("web"))
    eq({ "logs", "--follow", "--tail", "5", "web" }, docker.logs_args("web", { tail = 5 }))
  end)
end)
