local root = vim.fn.getcwd()
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. root .. "/tests/?.lua;" .. package.path

local tests = {}

function _G.describe(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

function _G.it(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    error(name .. "\n" .. tostring(err), 2)
  end
end

function _G.eq(expected, actual)
  assert(
    vim.deep_equal(expected, actual),
    "\nexpected: " .. vim.inspect(expected) .. "\nactual:   " .. vim.inspect(actual)
  )
end

function _G.truthy(value)
  assert(value, "expected truthy value")
end

local files = {
  "config_spec",
  "docker_spec",
  "actions_spec",
  "init_spec",
  "views_spec",
  "logs_spec",
  "exec_spec",
  "async_spec",
  "table_spec",
  "compat_spec",
}

for _, file in ipairs(files) do
  require(file)
end

local failed = 0
for _, test in ipairs(tests) do
  local ok, err = pcall(test.fn)
  if ok then
    print("PASS " .. test.name)
  else
    failed = failed + 1
    print("FAIL " .. test.name)
    print(err)
  end
end

if failed > 0 then
  vim.cmd("cquit")
end
