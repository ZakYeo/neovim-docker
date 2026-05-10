describe("logs", function()
  local function numbered_lines(count)
    local lines = {}
    for index = 1, count do
      lines[index] = tostring(index)
    end
    lines[#lines + 1] = ""
    return lines
  end

  local function with_stubbed_logs(batch, fn)
    local original_jobstart = vim.fn.jobstart
    local original_jobstop = vim.fn.jobstop
    vim.fn.jobstart = function(_, opts)
      opts.on_stdout(1, batch)
      return 1
    end
    vim.fn.jobstop = function() end

    local ok, err = pcall(fn)
    vim.fn.jobstart = original_jobstart
    vim.fn.jobstop = original_jobstop
    if not ok then
      error(err)
    end
  end

  local function reset_logs_test(buf)
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    require("neovim-docker.ui").reset_navigation()
    require("neovim-docker.config").setup({})
  end

  it("bounds retained live log output lines", function()
    require("neovim-docker.config").setup({
      docker_cmd = { "sh", "-c", "printf 'one\\ntwo\\nthree\\nfour\\nfive\\n'" },
      log_max_lines = 3,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf = require("neovim-docker.logs").open("web", { tail = 1 })
    truthy(buf and vim.api.nvim_buf_is_valid(buf))
    vim.wait(1000, function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      return vim.tbl_contains(lines, "five")
    end)

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq({
      "Docker logs: web",
      "",
      "three",
      "four",
      "five",
    }, lines)

    vim.api.nvim_buf_delete(buf, { force = true })
    require("neovim-docker.ui").reset_navigation()
    require("neovim-docker.config").setup({})
  end)

  it("falls back to the default line cap for invalid log_max_lines values", function()
    for _, invalid_max_lines in ipairs({ 0, -10, "not-a-number" }) do
      require("neovim-docker.config").setup({
        log_max_lines = invalid_max_lines,
        ui = {
          open = function() end,
        },
        notify = function() end,
      })

      local buf
      with_stubbed_logs(numbered_lines(5002), function()
        buf = require("neovim-docker.logs").open("web", { tail = 1 })
      end)

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      eq(5002, #lines)
      eq("Docker logs: web", lines[1])
      eq("", lines[2])
      eq("3", lines[3])
      eq("5002", lines[#lines])

      reset_logs_test(buf)
    end
  end)

  it("pre-truncates large log batches before appending", function()
    require("neovim-docker.config").setup({
      log_max_lines = 3,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local original_set_lines = vim.api.nvim_buf_set_lines
    local largest_insert = 0
    vim.api.nvim_buf_set_lines = function(buf, start, finish, strict, replacement)
      if start == -1 and finish == -1 then
        largest_insert = math.max(largest_insert, #replacement)
      end
      return original_set_lines(buf, start, finish, strict, replacement)
    end

    local buf
    local ok, err = pcall(function()
      with_stubbed_logs(numbered_lines(1000), function()
        buf = require("neovim-docker.logs").open("web", { tail = 1 })
      end)
    end)
    vim.api.nvim_buf_set_lines = original_set_lines
    if not ok then
      reset_logs_test(buf)
      error(err)
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    eq(3, largest_insert)
    eq({
      "Docker logs: web",
      "",
      "998",
      "999",
      "1000",
    }, lines)

    reset_logs_test(buf)
  end)

  it("restores log buffers to non-modifiable when appending fails", function()
    require("neovim-docker.config").setup({
      log_max_lines = 3,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local original_set_lines = vim.api.nvim_buf_set_lines
    vim.api.nvim_buf_set_lines = function(buf, start, finish, strict, replacement)
      if start == -1 and finish == -1 then
        error("append failed")
      end
      return original_set_lines(buf, start, finish, strict, replacement)
    end

    local buf
    local ok, err = pcall(function()
      with_stubbed_logs({ "one", "" }, function()
        buf = require("neovim-docker.logs").open("web", { tail = 1 })
      end)
    end)
    vim.api.nvim_buf_set_lines = original_set_lines
    if not ok then
      reset_logs_test(buf)
      error(err)
    end

    eq(false, vim.bo[buf].modifiable)

    reset_logs_test(buf)
  end)
end)
