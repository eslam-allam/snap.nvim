local PlenaryPath = require("plenary.path")
local random = math.random

local M = {}

function M.File_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

function M.tableToString(tbl)
  local str = "{"

  for key, value in pairs(tbl) do
    str = str .. string.format("[%s] = %s, ", key, tostring(value))
  end

  -- Remove the trailing comma and space if the table is not empty
  if next(tbl) then
    str = str:sub(1, -3)
  end

  str = str .. "}"

  return str
end

function M.cwd()
  return vim.fn.expand("%:p:h")
end

function M.getHighlightedLines()
  local vstart = vim.fn.getpos("'<")

  local vend = vim.fn.getpos("'>")

  local line_start = vstart[2]
  local line_end = vend[2]

  -- or use api.nvim_buf_get_lines
  return vim.fn.getline(line_start, line_end)
end

function M.appendTableEntries(table, joinChar)
  local result = ""
  for _, val in pairs(table) do
    result = result .. joinChar .. val
  end
  return result
end

function M.expandAndAbsolute(fname)
  return PlenaryPath:new(PlenaryPath:new(fname):expand()):absolute()
end

function M.uuid()
  math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))

  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return (
    string.gsub(template, "[xy]", function(c)
      local v = (c == "x") and random(0, 0xf) or random(8, 0xb)
      return string.format("%x", v)
    end)
  )
end

function M.splitStr(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

function M.contains(array, value)
  for _, v in ipairs(array) do
    if v == value then
      return true
    end
  end
  return false
end

function M.silicon(options)
  if not M.contains({ "v", "vs", "V", "Vs", "CTRL+V", "CTRL+Vs" }, vim.fn.mode()) then
    vim.notify("[Silicon] not in visual mode!", 4)
    return
  end

  local keys = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
  vim.api.nvim_feedkeys(keys, "x", false)
  local unsplit_opts = options.fargs

  local opts = {}
  for _, val in pairs(unsplit_opts) do
    local split_table = M.splitStr(val, "=")
    opts = vim.tbl_extend("keep", opts, { [split_table[1]] = split_table[2] })
  end

  local highlightedText = M.appendTableEntries(M.getHighlightedLines(), "\n")

  local defaults = {
    type = "clipboard",
    file_path = Util.root() .. "/" .. M.uuid(),
  }

  if opts == nil then
    opts = {}
  end

  opts = vim.tbl_deep_extend("keep", opts, defaults)

  opts.file_path = M.appendExtension(M.expandAndAbsolute(opts.file_path), ".png")

  local command = "silicon "

  local action = ""

  if opts.type == "clipboard" then
    action = "copied image to clipboard"
    command = command .. "--to-clipboard "
  end

  if opts.type == "file" then
    action = "saved image to " .. opts.file_path
    command = command .. "-o " .. vim.fn.shellescape(opts.file_path)
  end

  command = command .. " --language " .. vim.bo.filetype

  vim.fn.system("echo " .. vim.fn.shellescape(highlightedText) .. " | " .. command)

  if vim.v.shell_error == 0 then
    vim.notify("[Silicon] Succesfully " .. action, 2)
  else
    vim.notify("[Silicon] Failed to generate image.", 4)
  end
end

function M.stringEndsWith(str, suffix)
  return str:sub(-#suffix) == suffix
end

function M.appendExtension(fname, extension)
  local final_name = fname
  if final_name ~= string.match(final_name, "^.*%.%w+$") then
    final_name = final_name .. extension
  end
  return final_name
end

function M.get_gradle_projects(gradlew_root)
  local output = vim.fn.system({
    gradlew_root .. "/gradlew",
    "projects",
    "--quiet",
    "--build-file",
    gradlew_root .. "/build.gradle",
  })
  local subprojects = { "root" }

  for subproject in output:gmatch("':([a-zA-Z0-9\\-]*)'") do
    table.insert(subprojects, subproject)
  end
  return subprojects
end

function M.ReadFile(file)
  local f = assert(io.open(file, "rb"))
  local content = f:read("*all")
  f:close()
  return content
end

local yaml = require("yaml")

function M.Expand_home(path)
  local home = os.getenv("HOME")
  if home == nil then
    return path
  end

  if string.sub(path, 1, 1) ~= "~" then
    return path
  end

  return home .. string.sub(path, 2, string.len(path))
end


function M.User_configured_gradlew(root)
  local exists = M.File_exists(config_path)
  if exists then
    local content = yaml.eval(M.ReadFile(config_path))

    for _, v in pairs(content) do
      local conf_root = M.Expand_home(v.root)
      if root == conf_root then
        return root .. "/" .. v.gradlew_dir .. "/gradlew"
      end
    end

    return
  end
  return vim.fn.findfile("gradlew", root)
end
return M
