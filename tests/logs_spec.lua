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

  local function log_highlights(buf)
    local ns = vim.api.nvim_get_namespaces()["neovim-docker-logs"]
    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  end

  local function has_highlight(buf, line, group)
    for _, mark in ipairs(log_highlights(buf)) do
      if mark[2] == line and mark[4] and mark[4].hl_group == group then
        return true
      end
    end
    return false
  end

  local function highlight_count(buf, line, group)
    local count = 0
    for _, mark in ipairs(log_highlights(buf)) do
      if mark[2] == line and mark[4] and mark[4].hl_group == group then
        count = count + 1
      end
    end
    return count
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

  it("adds semantic highlights to log output", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({
      "api-1 | 2026-05-10T12:30:00Z INFO ready 200",
      "worker-1 | WARN retrying 429",
      "db-1 | ERROR failed 503",
      "",
    }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 0, "Title"))
    truthy(has_highlight(buf, 2, "DiagnosticInfo"))
    truthy(has_highlight(buf, 2, "Comment"))
    truthy(has_highlight(buf, 2, "Identifier"))
    truthy(has_highlight(buf, 2, "DiagnosticOk"))
    truthy(has_highlight(buf, 3, "DiagnosticWarn"))
    truthy(has_highlight(buf, 4, "DiagnosticError"))

    reset_logs_test(buf)
  end)

  it("strips ANSI color codes and uses them for log highlights", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({
      "\27[32m[Nest] 29  - \27[39m05/06/2026, 7:47:01 PM \27[32m    LOG\27[39m \27[38;5;3m[InstanceLoader] \27[39m\27[32mJwtModule dependencies initialized\27[39m\27[38;5;3m +1ms\27[39m",
      "",
    }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    eq({
      "Docker logs: web",
      "",
      "[Nest] 29  - 05/06/2026, 7:47:01 PM     LOG [InstanceLoader] JwtModule dependencies initialized +1ms",
    }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    truthy(highlight_count(buf, 2, "NeovimDockerAnsi2") >= 2)
    truthy(highlight_count(buf, 2, "NeovimDockerAnsi3") >= 2)
    eq(false, has_highlight(buf, 2, "DiagnosticInfo"))

    reset_logs_test(buf)
  end)

  it("falls back to semantic highlights when ANSI color codes are absent", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({ "api-1 | INFO ready 200", "" }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "DiagnosticInfo"))
    truthy(has_highlight(buf, 2, "DiagnosticOk"))

    reset_logs_test(buf)
  end)

  it("highlights npm notice lines without ANSI colors", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({ "NPM NOTICE package-lock metadata updated", "" }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "Special"))

    reset_logs_test(buf)
  end)

  it("uses custom log highlight groups", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      highlights = {
        logs = {
          error = "ErrorMsg",
          http_5xx = "WarningMsg",
        },
      },
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({ "api-1 | ERROR failed 503", "" }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "ErrorMsg"))
    truthy(has_highlight(buf, 2, "WarningMsg"))

    reset_logs_test(buf)
  end)

  it("uses custom npm notice log highlight groups", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      highlights = {
        logs = {
          npm_notice = "WarningMsg",
        },
      },
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({ "npm notice published 1 package", "" }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "WarningMsg"))

    reset_logs_test(buf)
  end)

  it("keeps ANSI colors ahead of npm notice fallback highlighting", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({ "\27[33mnpm notice published 1 package\27[39m", "" }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "NeovimDockerAnsi3"))
    eq(false, has_highlight(buf, 2, "Special"))

    reset_logs_test(buf)
  end)

  it("does not match severity tokens inside ordinary words", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({
      "api-1 | informational payload without a level",
      "api-1 | ERROR_CODE should not be severity",
      "api-1 | INFO_EVENT should not be severity",
      "api-1 | [ERROR] actual failure",
      "",
    }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    eq(false, has_highlight(buf, 2, "DiagnosticInfo"))
    eq(false, has_highlight(buf, 3, "DiagnosticError"))
    eq(false, has_highlight(buf, 4, "DiagnosticInfo"))
    truthy(has_highlight(buf, 5, "DiagnosticError"))

    reset_logs_test(buf)
  end)

  it("highlights only standalone HTTP-style status numbers", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local buf
    with_stubbed_logs({
      "api-1 | GET / 200",
      "api-1 | [404]",
      "api-1 | GET /users 503",
      "api-1 | route200ok status_500 v404beta id-200",
      "",
    }, function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
    end)

    truthy(has_highlight(buf, 2, "DiagnosticOk"))
    truthy(has_highlight(buf, 3, "DiagnosticWarn"))
    truthy(has_highlight(buf, 4, "DiagnosticError"))
    eq(false, has_highlight(buf, 5, "DiagnosticOk"))
    eq(false, has_highlight(buf, 5, "DiagnosticWarn"))
    eq(false, has_highlight(buf, 5, "DiagnosticError"))

    reset_logs_test(buf)
  end)

  it("highlights only appended log lines", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local callbacks = {}
    local original_jobstart = vim.fn.jobstart
    local original_jobstop = vim.fn.jobstop
    local original_clear_namespace = vim.api.nvim_buf_clear_namespace
    local original_get_lines = vim.api.nvim_buf_get_lines
    local clear_calls = 0
    local get_line_ranges = {}
    vim.fn.jobstart = function(_, opts)
      callbacks[#callbacks + 1] = opts.on_stdout
      return 1
    end
    vim.fn.jobstop = function() end
    vim.api.nvim_buf_clear_namespace = function(...)
      clear_calls = clear_calls + 1
      return original_clear_namespace(...)
    end
    vim.api.nvim_buf_get_lines = function(bufnr, start, finish, strict)
      get_line_ranges[#get_line_ranges + 1] = { start, finish }
      return original_get_lines(bufnr, start, finish, strict)
    end

    local buf
    local ok, err = pcall(function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
      clear_calls = 0
      callbacks[1](1, { "api-1 | INFO ready 200", "" })
      callbacks[1](1, { "api-1 | ERROR failed 503", "" })
    end)

    vim.fn.jobstart = original_jobstart
    vim.fn.jobstop = original_jobstop
    vim.api.nvim_buf_clear_namespace = original_clear_namespace
    vim.api.nvim_buf_get_lines = original_get_lines
    if not ok then
      reset_logs_test(buf)
      error(err)
    end

    eq(0, clear_calls)
    local append_ranges = {}
    for _, range in ipairs(get_line_ranges) do
      if range[1] >= 2 then
        append_ranges[#append_ranges + 1] = range
      end
    end
    eq({ { 2, 3 }, { 3, 4 } }, append_ranges)
    truthy(has_highlight(buf, 2, "DiagnosticInfo"))
    truthy(has_highlight(buf, 3, "DiagnosticError"))

    reset_logs_test(buf)
  end)

  it("clears log highlights and restores the header before later appends", function()
    require("neovim-docker.config").setup({
      log_max_lines = 10,
      ui = {
        open = function() end,
      },
      notify = function() end,
    })

    local callbacks = {}
    local original_jobstart = vim.fn.jobstart
    local original_jobstop = vim.fn.jobstop
    vim.fn.jobstart = function(_, opts)
      callbacks[#callbacks + 1] = opts.on_stdout
      return 1
    end
    vim.fn.jobstop = function() end

    local buf
    local ok, err = pcall(function()
      buf = require("neovim-docker.logs").open("web", { tail = 1 })
      callbacks[1](1, { "api-1 | ERROR failed 503", "" })
      truthy(has_highlight(buf, 2, "DiagnosticError"))

      vim.api.nvim_buf_call(buf, function()
        local clear_map = vim.fn.maparg("c", "n", false, true)
        clear_map.callback()
      end)

      eq({ "Docker logs: web", "" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
      eq(false, has_highlight(buf, 2, "DiagnosticError"))
      truthy(has_highlight(buf, 0, "Title"))

      callbacks[1](1, { "api-1 | INFO recovered 200", "" })
      truthy(has_highlight(buf, 2, "DiagnosticInfo"))
      truthy(has_highlight(buf, 2, "DiagnosticOk"))
    end)

    vim.fn.jobstart = original_jobstart
    vim.fn.jobstop = original_jobstop
    if not ok then
      reset_logs_test(buf)
      error(err)
    end

    reset_logs_test(buf)
  end)
end)
