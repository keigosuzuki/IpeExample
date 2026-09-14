----------------------------------------------------------------------
-- Export PDF Handout ipelet for Ipe
----------------------------------------------------------------------
--
-- Generates a handout PDF (<name>_handout.pdf) using `ipetoipe -markedview`,
-- automatically excluding Appendix slides (slides containing or following
-- the `pagenumbers_appendix` / `appendix` layer or labeled as Appendix).
--
----------------------------------------------------------------------

local _G = _G
local type = _G.type or type
local tostring = _G.tostring or tostring
local tonumber = _G.tonumber or tonumber
local ipairs = _G.ipairs or ipairs
local pairs = _G.pairs or pairs
local string = _G.string or string
local table = _G.table or table
local io = _G.io or io
local os = _G.os or os

label = "Export PDF Handout"

about = [[
Export PDF Handout (excluding Appendix pages)
]]

local last_dir = nil

-- Check if a page has a specific layer
local function page_has_layer(p, layer)
  for _, l in ipairs(p:layers()) do
    if l == layer then
      return true
    end
  end
  return false
end

-- Identify whether a page is the start of or belongs to the Appendix
local function is_appendix_page(p)
  -- 1. Layer-based detection (standard in this repository)
  if page_has_layer(p, "pagenumbers_appendix") or page_has_layer(p, "appendix") then
    return true
  end

  -- 2. Title/Section-based detection
  local t = p:titles()
  if t then
    if type(t.title) == "string" and t.title:lower():match("appendix") then
      return true
    end
    if type(t.section) == "string" and t.section:lower():match("appendix") then
      return true
    end
  end

  return false
end

local function is_success(res)
  if res == true or res == 0 then
    return true
  end
  return false
end

function run(model)
  local initial_dir = last_dir
  if not initial_dir and model and model.file_name then
    initial_dir = model.file_name:match("^(.*)[/\\][^/\\]+$")
  end
  initial_dir = initial_dir or "."

  local win = (model and model.ui and model.ui.win and model.ui:win()) or nil
  local file = ipeui.fileDialog(win, "open", "Open PDF/IPE File for Handout",
    {
      "PDF, IPE (*.pdf *.ipe *.xml)", "*.pdf;*.ipe;*.xml",
      "All files (*.*)", "*.*"
    },
    initial_dir, nil)
  if not file then return end

  last_dir = file:match("^(.*)[/\\][^/\\]+$") or initial_dir

  -- Determine handout file path
  local name = file:match("^(.*)%.[^/\\]+$") or file
  local handout = name .. "_handout.pdf"

  -- Locate ipetoipe executable
  local ipetoipe_cmd = "ipetoipe"
  if config and config.platform == "apple" then
    ipetoipe_cmd = "/Applications/Ipe.app/Contents/MacOS/ipetoipe"
  end

  -- Load document to filter out appendix pages
  local doc = ipe.Document(file)
  local target_file = file
  local tmpipe = nil

  if doc then
    local in_appendix = false
    for i = 1, #doc do
      local p = doc[i]
      if is_appendix_page(p) then
        in_appendix = true
      end
      if in_appendix then
        p:setMarked(false)
        for v = 1, p:countViews() do
          p:setMarkedView(v, false)
        end
      end
    end

    tmpipe = name .. ".tmp_handout.ipe"
    doc:save(tmpipe)
    target_file = tmpipe
  end

  local cmd = string.format('%s -pdf -markedview "%s" "%s"', ipetoipe_cmd, target_file, handout)
  local ret = _G.os.execute(cmd)

  if tmpipe and ipe.fileExists(tmpipe) then
    _G.os.remove(tmpipe)
  end

  if not is_success(ret) then
    model:warning("Failed to convert to PDF handout", file)
    return
  end

  if model and model.ui and model.ui.explain then
    model.ui:explain(string.format("Handout exported: %s", handout))
  end
end
