local actions = require("neovim-docker.actions")
local config = require("neovim-docker.config")
local details = require("neovim-docker.details")
local docker = require("neovim-docker.docker")
local exec = require("neovim-docker.exec")
local logs = require("neovim-docker.logs")
local table_view = require("neovim-docker.table")
local ui = require("neovim-docker.ui")

local M = {}

local pages = {}
local compose_project_label = "com.docker.compose.project"
local compose_project_working_dir_label = "com.docker.compose.project.working_dir"
local compose_project_config_files_label = "com.docker.compose.project.config_files"

local compose_group_actions = {
  up = "compose.project.up",
  start = "compose.project.start",
  stop = "compose.project.stop",
  restart = "compose.project.restart",
  remove = "compose.project.down",
}

local function is_container_page(page)
  return page and page.kind == "containers"
end

local function is_compose_group(item)
  return type(item) == "table" and item.__docker_view_kind == "compose_project"
end

local function compose_project_name(item)
  local labels = item and item.labels or {}
  return labels[compose_project_label]
end

local function first_compose_label(containers, label)
  for _, container in ipairs(containers or {}) do
    local labels = container.labels or {}
    if labels[label] and labels[label] ~= "" then
      return labels[label]
    end
  end
  return ""
end

local function lower(value)
  return string.lower(tostring(value or ""))
end

local function container_matches_filter(item, filter_text, columns)
  if filter_text == "" then
    return true
  end

  for _, column in ipairs(columns or {}) do
    if lower(table_view.value(item, column)):find(filter_text, 1, true) then
      return true
    end
  end

  return lower(compose_project_name(item)):find(filter_text, 1, true) ~= nil
end

local function apply_container_items(items, state, columns)
  local filtered = {}
  local filter_text = state.filter and lower(state.filter) or ""
  for _, item in ipairs(items or {}) do
    if container_matches_filter(item, filter_text, columns) then
      filtered[#filtered + 1] = item
    end
  end

  return table_view.apply(filtered, {
    sort_column = state.sort_column,
    sort_desc = state.sort_desc,
  }, columns)
end

local specs = {
  containers = {
    title = "Docker Containers",
    fetch = docker.containers,
    fetch_async = docker.containers_async,
    columns = { "id", "name", "image", "status" },
    actions = {
      start = "container.start",
      stop = "container.stop",
      restart = "container.restart",
      remove = "container.remove",
      inspect = "container.inspect",
      logs = "container.logs",
      exec = "container.exec",
    },
  },
  images = {
    title = "Docker Images",
    fetch = docker.images,
    fetch_async = docker.images_async,
    columns = { "id", "Repository", "Tag", "Size" },
    actions = {
      remove = "image.remove",
      inspect = "image.inspect",
      history = "image.history",
      prune = "image.prune",
    },
  },
  image_history = {
    title = "Docker Image History",
    fetch = function(opts)
      return docker.image_history(opts.image)
    end,
    fetch_async = docker.image_history_async,
    columns = { "ID", "CreatedSince", "CreatedBy", "Size", "Comment" },
    actions = {},
  },
  image_search = {
    title = "Docker Image Search",
    fetch = function(opts)
      return docker.search_images(opts.query)
    end,
    fetch_async = docker.search_images_async,
    columns = { "Name", "Description", "StarCount", "IsOfficial" },
    actions = {
      pull = "image.pull",
    },
  },
  volumes = {
    title = "Docker Volumes",
    fetch = docker.volumes,
    fetch_async = docker.volumes_async,
    columns = { "name", "Driver", "Mountpoint" },
    actions = {
      remove = "volume.remove",
      prune = "volume.prune",
      inspect = "volume.inspect",
    },
  },
  networks = {
    title = "Docker Networks",
    fetch = docker.networks,
    fetch_async = docker.networks_async,
    columns = { "id", "name", "Driver", "Scope" },
    actions = {
      remove = "network.remove",
      inspect = "network.inspect",
    },
  },
  compose = {
    title = "Docker Compose",
    fetch = docker.compose_services,
    fetch_async = docker.compose_services_async,
    columns = { "name", "Service", "State", "Status" },
    actions = {
      up = "compose.service.up",
      down = "compose.service.down",
      build = "compose.service.build",
      start = "compose.start",
      stop = "compose.stop",
      restart = "compose.restart",
      logs = "compose.service.logs",
      remove = "compose.down",
    },
  },
  compose_files = {
    title = "Docker Compose Files",
    fetch = docker.discover_compose_files,
    fetch_async = docker.discover_compose_files_async,
    columns = { "name", "cwd", "path", "status" },
    actions = {},
  },
  projects = {
    title = "Docker Compose Projects",
    fetch = docker.compose_projects,
    fetch_async = docker.compose_projects_async,
    columns = { "project", "status", "services", "cwd" },
    actions = {
      start = "compose.project.start",
      stop = "compose.project.stop",
      restart = "compose.project.restart",
      remove = "compose.project.down",
    },
  },
  compose_containers = {
    title = "Docker Compose Containers",
    fetch = docker.compose_containers,
    fetch_async = docker.compose_containers_async,
    columns = { "id", "name", "service", "status" },
    actions = {
      start = "container.start",
      stop = "container.stop",
      restart = "container.restart",
      logs = "container.logs",
      inspect = "container.inspect",
    },
  },
  registry_status = {
    title = "Docker Registry Status",
    fetch = docker.registry_auth_status,
    fetch_async = docker.registry_auth_status_async,
    columns = { "name", "status", "secure", "mirrors" },
    actions = {},
  },
}

local function row_for(item, columns)
  local cells = {}
  for _, column in ipairs(columns) do
    local cell = tostring(table_view.value(item, column) or "")
    if column == "id" and #cell > 12 then
      cell = cell:sub(1, 12)
    end
    cells[#cells + 1] = cell
  end
  return table.concat(cells, "  ")
end

local function create_compose_group(project_name, containers, expanded)
  local marker = expanded and "[-]" or "[+]"
  local cwd = first_compose_label(containers, compose_project_working_dir_label)
  local config_files = first_compose_label(containers, compose_project_config_files_label)
  return {
    __docker_view_kind = "compose_project",
    id = marker,
    name = project_name,
    image = "compose project",
    status = tostring(#containers) .. " container" .. (#containers == 1 and "" or "s"),
    project = project_name,
    cwd = cwd,
    config_files = config_files,
    labels = {
      [compose_project_label] = project_name,
      [compose_project_working_dir_label] = cwd,
      [compose_project_config_files_label] = config_files,
    },
    containers = containers,
  }
end

local function grouped_container_items(items, state)
  local projects = {}
  local standalone = {}
  local top_level_order = {}

  for _, item in ipairs(items or {}) do
    local project_name = compose_project_name(item)
    if project_name and project_name ~= "" then
      if not projects[project_name] then
        projects[project_name] = {}
        top_level_order[#top_level_order + 1] = { type = "project", name = project_name }
      end
      projects[project_name][#projects[project_name] + 1] = item
    else
      standalone[#standalone + 1] = item
      top_level_order[#top_level_order + 1] = { type = "container", index = #standalone }
    end
  end

  local expanded_projects = state.expanded_projects or {}
  local grouped = {}
  for _, entry in ipairs(top_level_order) do
    if entry.type == "project" then
      local containers = projects[entry.name]
      grouped[#grouped + 1] = create_compose_group(entry.name, containers, expanded_projects[entry.name] == true)
      if expanded_projects[entry.name] then
        for _, container in ipairs(containers) do
          grouped[#grouped + 1] = container
        end
      end
    else
      grouped[#grouped + 1] = standalone[entry.index]
    end
  end

  return grouped
end

local function render(page)
  local lines = {
    page.spec.title,
    string.rep("=", #page.spec.title),
    "state: "
      .. (page.loading and "loading" or "ready")
      .. " | filter: "
      .. ((page.state.filter and page.state.filter ~= "") and page.state.filter or "<none>")
      .. " | sort: "
      .. (page.state.sort_column or "<none>")
      .. (page.state.sort_desc and " desc" or " asc"),
    "keys: r refresh  / filter  x clear  o sort  a actions  l logs  ? help  <C-o>/<C-i> back/forward  q close",
    "",
  }

  if page.loading then
    lines[#lines + 1] = "Loading Docker " .. page.kind .. "..."
    return lines
  end

  if not page.result.ok then
    lines[#lines + 1] = "Docker error:"
    lines[#lines + 1] = page.result.error
    return lines
  end

  if is_container_page(page) then
    local visible_items = apply_container_items(page.items, page.state, page.spec.columns)
    page.visible_items = grouped_container_items(visible_items, page.state)
  else
    local visible_items = table_view.apply(page.items, page.state, page.spec.columns)
    page.visible_items = visible_items
  end

  if #page.visible_items == 0 then
    lines[#lines + 1] = "No Docker " .. page.kind .. " found."
    return lines
  end

  lines[#lines + 1] = table.concat(page.spec.columns, "  ")
  lines[#lines + 1] = string.rep("-", 72)
  for _, item in ipairs(page.visible_items) do
    lines[#lines + 1] = row_for(item, page.spec.columns)
  end
  return lines
end

local function apply_highlights(page)
  if not vim.api.nvim_buf_is_valid(page.buf) or not page.ns then
    return
  end
  local highlights = config.get().highlights
  pcall(vim.api.nvim_buf_clear_namespace, page.buf, page.ns, 0, -1)
  pcall(vim.api.nvim_buf_add_highlight, page.buf, page.ns, highlights.header, 0, 0, -1)
  pcall(vim.api.nvim_buf_add_highlight, page.buf, page.ns, highlights.muted, 2, 0, -1)
  pcall(vim.api.nvim_buf_add_highlight, page.buf, page.ns, highlights.muted, 3, 0, -1)
  for index, item in ipairs(page.visible_items or {}) do
    local state = string.lower(tostring(item.status or item.State or item.state or ""))
    local group
    if state:find("running", 1, true) or state:find("up", 1, true) then
      group = highlights.running
    elseif state:find("error", 1, true) or state:find("dead", 1, true) then
      group = highlights.error
    elseif state ~= "" then
      group = highlights.exited
    end
    if group then
      pcall(vim.api.nvim_buf_add_highlight, page.buf, page.ns, group, index + 6, 0, -1)
    end
  end
end

local function write_page(page)
  ui.write(page.buf, render(page))
  apply_highlights(page)
end

local function current_item(page)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local index = line - 7
  return page.visible_items and page.visible_items[index]
end

local function refresh(page)
  if page.job then
    docker.cancel(page.job)
    page.job = nil
  end
  page.loading = true
  write_page(page)
  page.job = page.spec.fetch_async(page.opts, function(result)
    if not vim.api.nvim_buf_is_valid(page.buf) then
      return
    end
    page.job = nil
    page.loading = false
    page.result = result
    page.items = result.items or {}
    write_page(page)
  end)
end

local function run_page_action(page, action_key)
  local item = action_key == "prune" and {} or current_item(page)
  local action_name = page.spec.actions[action_key]
  if action_key ~= "prune" and is_compose_group(item) then
    action_name = compose_group_actions[action_key]
  end
  if not action_name then
    return
  end

  if not item and action_key ~= "prune" then
    return
  end

  if action_name == "container.logs" then
    if item then
      logs.open(item.id or item.name)
    end
    return
  end

  if action_name == "compose.service.logs" then
    if item then
      local target = vim.tbl_extend("force", item, { cwd = page.opts.cwd })
      actions.run_async(action_name, target, {}, function(result)
        if result and result.ok then
          details.open("Docker Compose Logs", result)
        end
      end)
    end
    return
  end

  if action_name == "image.history" then
    if item then
      M.open(
        "image_history",
        { image = item.Repository and (item.Repository .. ":" .. (item.Tag or "latest")) or item.name or item.id }
      )
    end
    return
  end

  if action_name == "container.exec" then
    if item then
      exec.open(item.id or item.name)
    end
    return
  end

  if type(item) == "table" and page.opts.cwd then
    item = vim.tbl_extend("force", item, { cwd = page.opts.cwd })
  end

  page.loading = true
  write_page(page)
  page.job = actions.run_async(action_name, item, {}, function(result)
    page.job = nil
    page.loading = false
    if result and result.ok and action_key == "inspect" then
      write_page(page)
      details.open("Docker Inspect", result)
    elseif result and result.ok then
      refresh(page)
    else
      write_page(page)
    end
  end)
end

local function toggle_compose_group(page, item)
  page.state.expanded_projects = page.state.expanded_projects or {}
  page.state.expanded_projects[item.project] = not page.state.expanded_projects[item.project]
  write_page(page)
end

local function open_current_row(page)
  local item = current_item(page)
  if is_compose_group(item) then
    toggle_compose_group(page, item)
    return
  end
  run_page_action(page, "inspect")
end

local function help(page)
  local buf = details.open("Docker Page Help", {
    ok = true,
    stdout = {
      page.spec.title,
      "",
      "r refresh",
      "/ filter rows",
      "x clear filter",
      "o cycle sort column",
      "a open action menu (Compose project rows include up/start/stop/restart/down)",
      "<CR> expand/collapse Compose projects or inspect/open details",
      "i inspect/open details",
      "l tail logs where supported",
      "e exec shell where supported",
      "s/S/R start/stop/restart where supported",
      "d remove/down where supported",
      "p prune where supported",
      "b go back to the previous Docker page",
      "<C-o>/<C-i> move backward/forward through Docker pages",
      "q close",
    },
  })
  if buf then
    vim.keymap.set("n", "b", function()
      if not ui.back() then
        ui.focus(page.buf)
      end
    end, { buffer = buf, silent = true, desc = "Docker help back" })
  end
end

local function filter(page)
  vim.ui.input({ prompt = "Docker filter: ", default = page.state.filter or "" }, function(input)
    if input == nil then
      return
    end
    page.state.filter = input
    write_page(page)
  end)
end

local function sort(page)
  page.state.sort_column = table_view.next_sort_column(page.spec.columns, page.state.sort_column)
  if page.state.last_sort_column == page.state.sort_column then
    page.state.sort_desc = not page.state.sort_desc
  else
    page.state.sort_desc = false
  end
  page.state.last_sort_column = page.state.sort_column
  write_page(page)
end

local function action_menu(page)
  local names = {}
  local by_label = {}
  local item = current_item(page)
  local available_actions = page.spec.actions or {}
  if is_container_page(page) and is_compose_group(item) then
    available_actions = compose_group_actions
  end
  for key in pairs(available_actions) do
    names[#names + 1] = key
    by_label[key] = key
  end
  table.sort(names)
  vim.ui.select(names, { prompt = "Docker action" }, function(choice)
    if choice then
      run_page_action(page, by_label[choice])
    end
  end)
end

local function map(buf, lhs, fn, desc)
  if lhs and lhs ~= "" then
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
end

local function attach_keymaps(page)
  local maps = config.get().keymaps.buffer
  map(page.buf, maps.refresh, function()
    refresh(page)
  end, "Docker refresh")
  map(page.buf, maps.filter, function()
    filter(page)
  end, "Docker filter")
  map(page.buf, maps.clear_filter, function()
    page.state.filter = ""
    write_page(page)
  end, "Docker clear filter")
  map(page.buf, maps.sort, function()
    sort(page)
  end, "Docker sort")
  map(page.buf, maps.action_menu, function()
    action_menu(page)
  end, "Docker action menu")
  map(page.buf, maps.help, function()
    help(page)
  end, "Docker help")
  map(page.buf, maps.inspect, function()
    run_page_action(page, "inspect")
  end, "Docker inspect")
  map(page.buf, maps.logs, function()
    run_page_action(page, "logs")
  end, "Docker logs")
  map(page.buf, maps.exec, function()
    run_page_action(page, "exec")
  end, "Docker exec shell")
  map(page.buf, maps.open, function()
    open_current_row(page)
  end, "Docker open details")
  map(page.buf, maps.start, function()
    run_page_action(page, "start")
  end, "Docker start")
  map(page.buf, maps.stop, function()
    run_page_action(page, "stop")
  end, "Docker stop")
  map(page.buf, maps.restart, function()
    run_page_action(page, "restart")
  end, "Docker restart")
  map(page.buf, maps.remove, function()
    run_page_action(page, "remove")
  end, "Docker remove")
  map(page.buf, maps.prune, function()
    run_page_action(page, "prune")
  end, "Docker prune")
  map(page.buf, maps.quit, function()
    vim.cmd("bdelete")
  end, "Close Docker page")
end

function M.open(kind, opts)
  local spec = specs[kind]
  if not spec then
    config.get().notify("error", "Unknown Docker page: " .. tostring(kind))
    return nil
  end

  local page = {
    kind = kind,
    title = spec.title,
    spec = spec,
    opts = opts or {},
    state = {
      filter = "",
      sort_column = nil,
      sort_desc = false,
      expanded_projects = {},
    },
    result = { ok = true, items = {} },
    items = {},
    visible_items = {},
    loading = true,
  }
  page.buf = ui.create_buffer(page)
  page.ns = vim.api.nvim_create_namespace("neovim-docker-" .. kind .. "-" .. tostring(page.buf))
  pages[page.buf] = page
  write_page(page)
  attach_keymaps(page)
  ui.open(page.buf, page, opts)
  refresh(page)
  local interval = config.get().refresh_interval
  if interval and interval > 0 then
    page.timer = vim.loop.new_timer()
    page.timer:start(interval, interval, function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(page.buf) then
          refresh(page)
        end
      end)
    end)
  end
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = page.buf,
    once = true,
    callback = function()
      if page.job then
        docker.cancel(page.job)
      end
      if page.timer then
        page.timer:stop()
        page.timer:close()
      end
      pages[page.buf] = nil
    end,
  })
  return page
end

function M.get(buf)
  return pages[buf or vim.api.nvim_get_current_buf()]
end

function M.current_item(page)
  return current_item(page or M.get())
end

function M.registry(opts)
  opts = opts or {}
  local page = {
    kind = "registries",
    title = "Docker Registries",
  }
  page.buf = ui.create_buffer(page)
  ui.write(page.buf, {
    "Docker Registries",
    "=================",
    "",
    "Use :DockerRegistryStatus, :DockerSearch <query>, :DockerPull <image>, :DockerPush <image>, and :DockerTag <source> <target>.",
    "Authentication is handled by the Docker CLI login state.",
    "This plugin never stores registry credentials.",
  })
  ui.open(page.buf, page, opts)
  return page
end

return M
