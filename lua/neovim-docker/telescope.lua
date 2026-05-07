local actions = require("neovim-docker.actions")
local docker = require("neovim-docker.docker")
local logs = require("neovim-docker.logs")

local M = {}

local function pick(kind, fetch, action_name)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    vim.notify("telescope.nvim is not installed", vim.log.levels.WARN, { title = "neovim-docker" })
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions_telescope = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  fetch({}, function(result)
    local entries = result.items or {}
    pickers
      .new({}, {
        prompt_title = "Docker " .. kind,
        finder = finders.new_table({
          results = entries,
          entry_maker = function(entry)
            return {
              value = entry,
              display = (entry.name or entry.id or "unknown") .. "  " .. (entry.status or entry.image or ""),
              ordinal = entry.name or entry.id or "",
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions_telescope.select_default:replace(function()
            local selected = action_state.get_selected_entry()
            actions_telescope.close(prompt_bufnr)
            if not selected then
              return
            end
            if action_name == "container.logs" then
              logs.open(selected.value.id or selected.value.name)
            else
              actions.run_async(action_name, selected.value)
            end
          end)
          return true
        end,
      })
      :find()
  end)
end

function M.containers()
  pick("containers", docker.containers_async, "container.logs")
end

function M.images()
  pick("images", docker.images_async, "image.inspect")
end

function M.volumes()
  pick("volumes", docker.volumes_async, "volume.inspect")
end

return M
