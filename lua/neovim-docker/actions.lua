local config = require("neovim-docker.config")
local docker = require("neovim-docker.docker")

local M = {}

local destructive = {
  ["container.remove"] = true,
  ["image.remove"] = true,
  ["image.prune"] = true,
  ["volume.remove"] = true,
  ["volume.prune"] = true,
  ["network.remove"] = true,
  ["compose.down"] = true,
  ["compose.project.down"] = true,
}

local function target_id(target)
  if type(target) == "string" then
    return target
  end
  return target and (target.id or target.ID or target.name or target.Name)
end

local function image_name(target)
  if type(target) == "string" then
    return target
  end
  return target and (target.name or target.Repository or target.id)
end

local handlers = {
  ["container.start"] = function(target)
    return docker.run({ "start", target_id(target) })
  end,
  ["container.stop"] = function(target)
    return docker.run({ "stop", target_id(target) })
  end,
  ["container.restart"] = function(target)
    return docker.run({ "restart", target_id(target) })
  end,
  ["container.remove"] = function(target)
    return docker.run({ "rm", target_id(target) })
  end,
  ["container.inspect"] = function(target)
    return docker.inspect(target_id(target))
  end,
  ["image.remove"] = function(target)
    return docker.run({ "rmi", image_name(target) })
  end,
  ["image.pull"] = function(target)
    return docker.run({ "pull", image_name(target) })
  end,
  ["image.push"] = function(target)
    return docker.run({ "push", image_name(target) })
  end,
  ["image.tag"] = function(target)
    return docker.run({ "tag", target.source, target.tag })
  end,
  ["image.inspect"] = function(target)
    return docker.inspect(image_name(target))
  end,
  ["image.history"] = function(target)
    return docker.image_history(image_name(target))
  end,
  ["image.prune"] = function()
    return docker.run({ "image", "prune", "-f" })
  end,
  ["volume.remove"] = function(target)
    return docker.run({ "volume", "rm", target_id(target) })
  end,
  ["volume.prune"] = function()
    return docker.run({ "volume", "prune", "-f" })
  end,
  ["volume.inspect"] = function(target)
    return docker.run({ "volume", "inspect", target_id(target) })
  end,
  ["network.remove"] = function(target)
    return docker.run({ "network", "rm", target_id(target) })
  end,
  ["network.inspect"] = function(target)
    return docker.run({ "network", "inspect", target_id(target) })
  end,
  ["compose.up"] = function(target)
    return docker.run_compose({ "up", "-d" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.down"] = function(target)
    return docker.run_compose({ "down" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.start"] = function(target)
    return docker.run_compose({ "start", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.stop"] = function(target)
    return docker.run_compose({ "stop", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.restart"] = function(target)
    return docker.run_compose({ "restart", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.project.up"] = function(target)
    return docker.run_compose({ "up", "-d" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.project.down"] = function(target)
    return docker.run_compose({ "down" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.project.start"] = function(target)
    return docker.run_compose({ "start" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.project.stop"] = function(target)
    return docker.run_compose({ "stop" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.project.restart"] = function(target)
    return docker.run_compose({ "restart" }, { cwd = target and target.cwd or nil })
  end,
  ["compose.service.up"] = function(target)
    return docker.run_compose({ "up", "-d", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.service.down"] = function(target)
    return docker.run_compose({ "stop", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.service.build"] = function(target)
    return docker.run_compose({ "build", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
  ["compose.service.logs"] = function(target)
    return docker.run_compose({ "logs", "--tail", "200", target_id(target) }, { cwd = target and target.cwd or nil })
  end,
}

local async_handlers = {
  ["container.start"] = function(target, callback)
    return docker.run_async({ "start", target_id(target) }, {}, callback)
  end,
  ["container.stop"] = function(target, callback)
    return docker.run_async({ "stop", target_id(target) }, {}, callback)
  end,
  ["container.restart"] = function(target, callback)
    return docker.run_async({ "restart", target_id(target) }, {}, callback)
  end,
  ["container.remove"] = function(target, callback)
    return docker.run_async({ "rm", target_id(target) }, {}, callback)
  end,
  ["container.inspect"] = function(target, callback)
    return docker.run_async({ "inspect", target_id(target) }, {}, callback)
  end,
  ["image.remove"] = function(target, callback)
    return docker.run_async({ "rmi", image_name(target) }, {}, callback)
  end,
  ["image.pull"] = function(target, callback)
    return docker.run_async({ "pull", image_name(target) }, {}, callback)
  end,
  ["image.push"] = function(target, callback)
    return docker.run_async({ "push", image_name(target) }, {}, callback)
  end,
  ["image.tag"] = function(target, callback)
    return docker.run_async({ "tag", target.source, target.tag }, {}, callback)
  end,
  ["image.inspect"] = function(target, callback)
    return docker.run_async({ "inspect", image_name(target) }, {}, callback)
  end,
  ["image.history"] = function(target, callback)
    return docker.list_async({ "history", "--format", "{{json .}}", image_name(target) }, require("neovim-docker.parser").json_lines, {}, callback)
  end,
  ["image.prune"] = function(_, callback)
    return docker.run_async({ "image", "prune", "-f" }, {}, callback)
  end,
  ["volume.remove"] = function(target, callback)
    return docker.run_async({ "volume", "rm", target_id(target) }, {}, callback)
  end,
  ["volume.prune"] = function(_, callback)
    return docker.run_async({ "volume", "prune", "-f" }, {}, callback)
  end,
  ["volume.inspect"] = function(target, callback)
    return docker.run_async({ "volume", "inspect", target_id(target) }, {}, callback)
  end,
  ["network.remove"] = function(target, callback)
    return docker.run_async({ "network", "rm", target_id(target) }, {}, callback)
  end,
  ["network.inspect"] = function(target, callback)
    return docker.run_async({ "network", "inspect", target_id(target) }, {}, callback)
  end,
  ["compose.up"] = function(target, callback)
    return docker.run_compose_async({ "up", "-d" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.down"] = function(target, callback)
    return docker.run_compose_async({ "down" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.start"] = function(target, callback)
    return docker.run_compose_async({ "start", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.stop"] = function(target, callback)
    return docker.run_compose_async({ "stop", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.restart"] = function(target, callback)
    return docker.run_compose_async({ "restart", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.project.up"] = function(target, callback)
    return docker.run_compose_async({ "up", "-d" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.project.down"] = function(target, callback)
    return docker.run_compose_async({ "down" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.project.start"] = function(target, callback)
    return docker.run_compose_async({ "start" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.project.stop"] = function(target, callback)
    return docker.run_compose_async({ "stop" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.project.restart"] = function(target, callback)
    return docker.run_compose_async({ "restart" }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.service.up"] = function(target, callback)
    return docker.run_compose_async({ "up", "-d", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.service.down"] = function(target, callback)
    return docker.run_compose_async({ "stop", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.service.build"] = function(target, callback)
    return docker.run_compose_async({ "build", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
  ["compose.service.logs"] = function(target, callback)
    return docker.run_compose_async({ "logs", "--tail", "200", target_id(target) }, { cwd = target and target.cwd or nil }, callback)
  end,
}

function M.requires_confirmation(action_name)
  return destructive[action_name] == true
end

function M.run(action_name, target, opts)
  opts = opts or {}
  local handler = handlers[action_name]
  if not handler then
    return { ok = false, error = "Unknown Docker action: " .. tostring(action_name) }
  end

  if not opts.skip_confirm and M.requires_confirmation(action_name) then
    local confirm = config.get().confirm
    if confirm and not confirm(action_name, target) then
      return { ok = false, cancelled = true, error = "Action cancelled" }
    end
  end

  local result = handler(target or {})
  if result and result.ok then
    config.get().notify("info", "Docker action completed: " .. action_name)
  elseif result and not result.cancelled then
    config.get().notify("error", result.error or "Docker action failed: " .. action_name)
  end
  return result
end

function M.run_async(action_name, target, opts, callback)
  opts = opts or {}
  local handler = async_handlers[action_name]
  if not handler then
    local result = { ok = false, error = "Unknown Docker action: " .. tostring(action_name) }
    if callback then
      callback(result)
    end
    return nil
  end

  if not opts.skip_confirm and M.requires_confirmation(action_name) then
    local confirm = config.get().confirm
    if confirm and not confirm(action_name, target) then
      local result = { ok = false, cancelled = true, error = "Action cancelled" }
      if callback then
        callback(result)
      end
      return nil
    end
  end

  return handler(target or {}, function(result)
    if result and result.ok then
      config.get().notify("info", "Docker action completed: " .. action_name)
    elseif result and not result.cancelled then
      config.get().notify("error", result.error or "Docker action failed: " .. action_name)
    end
    if callback then
      callback(result)
    end
  end)
end

function M.names()
  local names = {}
  for name in pairs(handlers) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

return M
