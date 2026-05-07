local M = {}

local function value(item, key)
  return item[key] or item[string.lower(key)] or item.raw and item.raw[key] or ""
end

local function lower(value_)
  return string.lower(tostring(value_ or ""))
end

function M.value(item, key)
  return value(item, key)
end

function M.apply(items, state, columns)
  local filtered = {}
  local filter = state.filter and lower(state.filter) or ""
  for _, item in ipairs(items or {}) do
    local include = filter == ""
    if not include then
      for _, column in ipairs(columns or {}) do
        if lower(value(item, column)):find(filter, 1, true) then
          include = true
          break
        end
      end
    end
    if include then
      filtered[#filtered + 1] = item
    end
  end

  local sort_column = state.sort_column
  if sort_column then
    table.sort(filtered, function(left, right)
      local left_value = lower(value(left, sort_column))
      local right_value = lower(value(right, sort_column))
      if state.sort_desc then
        return left_value > right_value
      end
      return left_value < right_value
    end)
  end

  return filtered
end

function M.next_sort_column(columns, current)
  if not columns or #columns == 0 then
    return nil
  end
  if not current then
    return columns[1]
  end
  for index, column in ipairs(columns) do
    if column == current then
      return columns[(index % #columns) + 1]
    end
  end
  return columns[1]
end

return M
