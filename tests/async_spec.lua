describe("async docker cli", function()
  it("builds async container list calls", function()
    local docker = require("neovim-docker.docker")
    local seen_args
    docker.setup({
      runner_async = function(args, opts, callback)
        seen_args = args
        callback({
          ok = true,
          code = 0,
          stdout = { '{"ID":"abc","Names":"web","State":"running"}' },
          stderr = {},
        })
        return 42
      end,
    })

    local callback_result
    local job = docker.containers_async({}, function(result)
      callback_result = result
    end)

    eq(42, job)
    eq({ "docker", "ps", "-a", "--format", "{{json .}}" }, seen_args)
    eq(true, callback_result.ok)
    eq("web", callback_result.items[1].name)
  end)

  it("can cancel async jobs", function()
    local stopped
    local docker = require("neovim-docker.docker")
    docker.setup({
      runner_async = function()
        return 99
      end,
      stopper = function(job)
        stopped = job
      end,
    })

    docker.cancel(99)
    eq(99, stopped)
  end)
end)
