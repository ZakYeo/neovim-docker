describe("table", function()
  it("filters and sorts rows", function()
    local table_view = require("neovim-docker.table")
    local rows = {
      { name = "web", status = "running" },
      { name = "db", status = "exited" },
    }

    local filtered = table_view.apply(rows, { filter = "run", sort_column = "name" }, { "name", "status" })
    eq(1, #filtered)
    eq("web", filtered[1].name)

    local sorted = table_view.apply(rows, { sort_column = "name", sort_desc = false }, { "name", "status" })
    eq("db", sorted[1].name)
    eq("web", sorted[2].name)
  end)
end)
