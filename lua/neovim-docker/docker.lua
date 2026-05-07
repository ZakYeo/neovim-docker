local config = require("neovim-docker.config")
local parser = require("neovim-docker.parser")

local M = {}

local state = {
  runner = nil,
  runner_async = nil,
  stopper = nil,
}

local function list_extend(left, right)
  local result = vim.deepcopy(left)
  for _, value in ipairs(right or {}) do
    result[#result + 1] = value
  end
  return result
end

local function default_runner(_, opts)
  return {
    ok = false,
    code = 1,
    stdout = {},
    stderr = { "Synchronous Docker execution is disabled; use async APIs" },
    cwd = opts and opts.cwd or nil,
  }
end

local function default_stopper(job)
  if job then
    vim.fn.jobstop(job)
  end
end

local function default_runner_async(args, opts, callback)
  opts = opts or {}
  local stdout = {}
  local stderr = {}
  local completed = false
  local timer

  local job = vim.fn.jobstart(args, {
    cwd = opts.cwd,
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          stdout[#stdout + 1] = line
        end
      end
    end,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= "" then
          stderr[#stderr + 1] = line
        end
      end
    end,
    on_exit = function(_, code)
      if completed then
        return
      end
      completed = true
      if timer then
        timer:stop()
        timer:close()
      end
      vim.schedule(function()
        callback({
          ok = code == 0,
          code = code,
          stdout = stdout,
          stderr = stderr,
          cwd = opts.cwd,
        })
      end)
    end,
  })

  if job <= 0 then
    vim.schedule(function()
      callback({
        ok = false,
        code = 127,
        stdout = {},
        stderr = { "Failed to start Docker command" },
        cwd = opts.cwd,
      })
    end)
    return nil
  end

  local timeout = opts.timeout or config.get().timeout
  if timeout and timeout > 0 then
    timer = vim.loop.new_timer()
    timer:start(timeout, 0, function()
      if completed then
        return
      end
      completed = true
      default_stopper(job)
      vim.schedule(function()
        callback({
          ok = false,
          code = 124,
          stdout = stdout,
          stderr = { "Docker command timed out after " .. tostring(timeout) .. "ms" },
          cwd = opts.cwd,
        })
      end)
      timer:stop()
      timer:close()
    end)
  end

  return job
end

local function command_prefix()
  local opts = config.get()
  if type(opts.docker_cmd) == "table" then
    return vim.deepcopy(opts.docker_cmd)
  end
  return { opts.docker_cmd }
end

local function compose_prefix()
  local opts = config.get()
  if type(opts.compose_cmd) == "table" then
    return vim.deepcopy(opts.compose_cmd)
  end
  return { opts.compose_cmd }
end

local function error_message(result)
  local stderr = table.concat(result.stderr or {}, "\n")
  if stderr == "" then
    stderr = table.concat(result.stdout or {}, "\n")
  end
  if stderr == "" then
    stderr = "Docker command failed with exit code " .. tostring(result.code)
  end
  return stderr
end

function M.setup(opts)
  state.runner = opts and opts.runner or nil
  state.runner_async = opts and opts.runner_async or nil
  state.stopper = opts and opts.stopper or nil
end

function M.run(args, opts)
  local full_args = list_extend(command_prefix(), args)
  local runner = state.runner or default_runner
  local result = runner(full_args, opts or {})
  result.ok = result.ok and result.code == 0
  if not result.ok then
    result.error = error_message(result)
  end
  return result
end

function M.run_async(args, opts, callback)
  local full_args = list_extend(command_prefix(), args)
  local runner = state.runner_async or default_runner_async
  return runner(full_args, opts or {}, function(result)
    result.ok = result.ok and result.code == 0
    if not result.ok then
      result.error = error_message(result)
    end
    callback(result)
  end)
end

function M.run_compose(args, opts)
  local full_args = list_extend(compose_prefix(), args)
  local runner = state.runner or default_runner
  local result = runner(full_args, opts or {})
  result.ok = result.ok and result.code == 0
  if not result.ok then
    result.error = error_message(result)
  end
  return result
end

function M.run_compose_async(args, opts, callback)
  local full_args = list_extend(compose_prefix(), args)
  local runner = state.runner_async or default_runner_async
  return runner(full_args, opts or {}, function(result)
    result.ok = result.ok and result.code == 0
    if not result.ok then
      result.error = error_message(result)
    end
    callback(result)
  end)
end

function M.list(args, parse, opts)
  local result = M.run(args, opts)
  if result.ok then
    result.items = parse(result.stdout)
  else
    result.items = {}
  end
  return result
end

function M.list_async(args, parse, opts, callback)
  return M.run_async(args, opts, function(result)
    if result.ok then
      result.items = parse(result.stdout)
    else
      result.items = {}
    end
    callback(result)
  end)
end

function M.containers(opts)
  return M.list({ "ps", "-a", "--format", "{{json .}}" }, parser.json_lines, opts)
end

function M.containers_async(opts, callback)
  return M.list_async({ "ps", "-a", "--format", "{{json .}}" }, parser.json_lines, opts, callback)
end

function M.images(opts)
  return M.list({ "images", "--format", "{{json .}}" }, parser.json_lines, opts)
end

function M.images_async(opts, callback)
  return M.list_async({ "images", "--format", "{{json .}}" }, parser.json_lines, opts, callback)
end

function M.volumes(opts)
  return M.list({ "volume", "ls", "--format", "{{json .}}" }, parser.json_lines, opts)
end

function M.volumes_async(opts, callback)
  return M.list_async({ "volume", "ls", "--format", "{{json .}}" }, parser.json_lines, opts, callback)
end

function M.networks(opts)
  return M.list({ "network", "ls", "--format", "{{json .}}" }, parser.json_lines, opts)
end

function M.networks_async(opts, callback)
  return M.list_async({ "network", "ls", "--format", "{{json .}}" }, parser.json_lines, opts, callback)
end

function M.compose_services(opts)
  local result = M.run_compose({ "ps", "-a", "--format", "json" }, opts)
  if result.ok then
    result.items = parser.json_document(result.stdout)
  else
    result.items = {}
  end
  return result
end

function M.compose_services_async(opts, callback)
  return M.run_compose_async({ "ps", "-a", "--format", "json" }, opts, function(result)
    if result.ok then
      result.items = parser.json_document(result.stdout)
    else
      result.items = {}
    end
    callback(result)
  end)
end

local compose_file_names = {
  "compose.yaml",
  "compose.yml",
  "docker-compose.yaml",
  "docker-compose.yml",
}

function M.discover_compose_files(root)
  root = root or vim.fn.getcwd()
  local found = {}
  local seen = {}
  local scan_roots = { root }

  for _, dir in ipairs(scan_roots) do
    for _, name in ipairs(compose_file_names) do
      local path = dir .. "/" .. name
      if vim.fn.filereadable(path) == 1 and not seen[path] then
        seen[path] = true
        found[#found + 1] = {
          id = path,
          name = name,
          path = path,
          cwd = dir,
          status = "file",
        }
      end
    end
  end

  table.sort(found, function(left, right)
    return left.path < right.path
  end)
  return { ok = true, code = 0, items = found, stdout = {}, stderr = {} }
end

function M.discover_compose_files_async(opts, callback)
  vim.schedule(function()
    callback(M.discover_compose_files(opts and opts.cwd or vim.fn.getcwd()))
  end)
  return nil
end

function M.compose_projects(opts)
  local result = M.containers(opts)
  local projects = {}
  local order = {}

  if not result.ok then
    result.items = {}
    return result
  end

  for _, container in ipairs(result.items or {}) do
    local labels = container.labels or {}
    local project_name = labels["com.docker.compose.project"]
    if project_name then
      if not projects[project_name] then
        projects[project_name] = {
          id = project_name,
          name = project_name,
          project = project_name,
          cwd = labels["com.docker.compose.project.working_dir"] or "",
          config_files = labels["com.docker.compose.project.config_files"] or "",
          services = {},
          running = 0,
          stopped = 0,
          total = 0,
        }
        order[#order + 1] = project_name
      end

      local project = projects[project_name]
      local service = labels["com.docker.compose.service"]
      if service and not project.services[service] then
        project.services[service] = true
      end
      project.total = project.total + 1
      if container.State == "running" or container.state == "running" then
        project.running = project.running + 1
      else
        project.stopped = project.stopped + 1
      end
    end
  end

  local items = {}
  table.sort(order)
  for _, name in ipairs(order) do
    local project = projects[name]
    local services = {}
    for service in pairs(project.services) do
      services[#services + 1] = service
    end
    table.sort(services)
    project.services = table.concat(services, ",")
    project.status = tostring(project.running) .. " running / " .. tostring(project.total) .. " total"
    items[#items + 1] = project
  end

  result.items = items
  return result
end

function M.compose_projects_async(opts, callback)
  return M.containers_async(opts, function(result)
    local projects = {}
    local order = {}

    if not result.ok then
      result.items = {}
      callback(result)
      return
    end

    for _, container in ipairs(result.items or {}) do
      local labels = container.labels or {}
      local project_name = labels["com.docker.compose.project"]
      if project_name then
        if not projects[project_name] then
          projects[project_name] = {
            id = project_name,
            name = project_name,
            project = project_name,
            cwd = labels["com.docker.compose.project.working_dir"] or "",
            config_files = labels["com.docker.compose.project.config_files"] or "",
            services = {},
            running = 0,
            stopped = 0,
            total = 0,
          }
          order[#order + 1] = project_name
        end
        local project = projects[project_name]
        local service = labels["com.docker.compose.service"]
        if service and not project.services[service] then
          project.services[service] = true
        end
        project.total = project.total + 1
        if container.State == "running" or container.state == "running" then
          project.running = project.running + 1
        else
          project.stopped = project.stopped + 1
        end
      end
    end

    local items = {}
    table.sort(order)
    for _, name in ipairs(order) do
      local project = projects[name]
      local services = {}
      for service in pairs(project.services) do
        services[#services + 1] = service
      end
      table.sort(services)
      project.services = table.concat(services, ",")
      project.status = tostring(project.running) .. " running / " .. tostring(project.total) .. " total"
      items[#items + 1] = project
    end
    result.items = items
    callback(result)
  end)
end

function M.compose_containers(opts)
  opts = opts or {}
  local result = M.containers(opts)
  if not result.ok or not opts.project then
    return result
  end
  local items = {}
  for _, item in ipairs(result.items or {}) do
    local labels = item.labels or {}
    if labels["com.docker.compose.project"] == opts.project then
      item.service = labels["com.docker.compose.service"] or item.service
      item.project = opts.project
      items[#items + 1] = item
    end
  end
  result.items = items
  return result
end

function M.compose_containers_async(opts, callback)
  return M.containers_async(opts, function(result)
    if result.ok and opts and opts.project then
      local items = {}
      for _, item in ipairs(result.items or {}) do
        local labels = item.labels or {}
        if labels["com.docker.compose.project"] == opts.project then
          item.service = labels["com.docker.compose.service"] or item.service
          item.project = opts.project
          items[#items + 1] = item
        end
      end
      result.items = items
    end
    callback(result)
  end)
end

function M.cancel(job)
  local stopper = state.stopper or default_stopper
  stopper(job)
end

function M.inspect(target)
  return M.run({ "inspect", target })
end

function M.image_history(target)
  return M.list({ "history", "--format", "{{json .}}", target }, parser.json_lines)
end

function M.image_history_async(opts, callback)
  return M.list_async({ "history", "--format", "{{json .}}", opts.image }, parser.json_lines, opts, callback)
end

function M.search_images(query)
  return M.list({ "search", "--format", "{{json .}}", query }, parser.json_lines)
end

function M.search_images_async(opts, callback)
  return M.list_async({ "search", "--format", "{{json .}}", opts.query or "" }, parser.json_lines, opts, callback)
end

function M.registry_auth_status()
  local result = M.run({ "info", "--format", "{{json .RegistryConfig.IndexConfigs}}" })
  if not result.ok then
    result.items = {}
    return result
  end
  local text = table.concat(result.stdout or {}, "\n")
  local ok, decoded = pcall(function()
    if vim.json and vim.json.decode then
      return vim.json.decode(text)
    end
    return vim.fn.json_decode(text)
  end)
  local items = {}
  if ok and type(decoded) == "table" then
    for name, cfg in pairs(decoded) do
      items[#items + 1] = {
        id = name,
        name = name,
        secure = tostring(cfg.Secure or cfg.secure or ""),
        mirrors = table.concat(cfg.Mirrors or cfg.mirrors or {}, ","),
        status = "configured",
      }
    end
  end
  table.sort(items, function(left, right)
    return left.name < right.name
  end)
  result.items = items
  return result
end

local function parse_registry_status(result)
  local text = table.concat(result.stdout or {}, "\n")
  local ok, decoded = pcall(function()
    if vim.json and vim.json.decode then
      return vim.json.decode(text)
    end
    return vim.fn.json_decode(text)
  end)
  local items = {}
  if ok and type(decoded) == "table" then
    for name, cfg in pairs(decoded) do
      items[#items + 1] = {
        id = name,
        name = name,
        secure = tostring(cfg.Secure or cfg.secure or ""),
        mirrors = table.concat(cfg.Mirrors or cfg.mirrors or {}, ","),
        status = "configured",
      }
    end
  end
  table.sort(items, function(left, right)
    return left.name < right.name
  end)
  return items
end

function M.registry_auth_status_async(opts, callback)
  return M.run_async({ "info", "--format", "{{json .RegistryConfig.IndexConfigs}}" }, opts, function(result)
    if result.ok then
      result.items = parse_registry_status(result)
    else
      result.items = {}
    end
    callback(result)
  end)
end

function M.logs_args(container, opts)
  opts = opts or {}
  return {
    "logs",
    "--follow",
    "--tail",
    tostring(opts.tail or config.get().log_tail),
    container,
  }
end

return M
