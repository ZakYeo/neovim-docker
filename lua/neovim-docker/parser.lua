local M = {}

local function decode_json(line)
  if vim.json and vim.json.decode then
    return vim.json.decode(line)
  end
  return vim.fn.json_decode(line)
end

local function parse_labels(labels)
  local parsed = {}
  if type(labels) ~= "string" or labels == "" then
    return parsed
  end

  for label in labels:gmatch("[^,]+") do
    local key, value = label:match("^([^=]+)=(.*)$")
    if key and value then
      parsed[key] = value
    end
  end
  return parsed
end

local function normalize(raw)
  local item = {}
  for key, value in pairs(raw or {}) do
    item[key] = value
    item[string.lower(key)] = value
  end

  item.id = item.id or item.ID or item.containerid or item.imageid or item.name
  item.name = item.name or item.Names or item.Name or item.Repository or item.Service or item.Driver or item.id
  item.status = item.status or item.Status or item.State
  item.image = item.image or item.Image or item.Repository
  item.labels = parse_labels(item.Labels or item.labels)
  item.raw = raw
  return item
end

function M.json_lines(lines)
  local items = {}
  for _, line in ipairs(lines or {}) do
    if line and line ~= "" then
      local ok, decoded = pcall(decode_json, line)
      if ok and decoded then
        items[#items + 1] = normalize(decoded)
      end
    end
  end
  return items
end

function M.json_document(lines)
  local text = table.concat(lines or {}, "\n")
  if text == "" then
    return {}
  end

  local ok, decoded = pcall(decode_json, text)
  if not ok or not decoded then
    return M.json_lines(lines)
  end

  if vim.tbl_islist(decoded) then
    local items = {}
    for _, raw in ipairs(decoded) do
      items[#items + 1] = normalize(raw)
    end
    return items
  end

  return { normalize(decoded) }
end

return M
