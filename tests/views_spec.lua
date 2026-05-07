describe("views", function()
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
end)
