-- -- check prefs.lua for additional preference parameters
prefs.autosave_filename = "./%s.autosave"
prefs.autosave_interval = nil
prefs.editor_size = { 500, 500 }
-- external editor settings for visual studio code
-- if config.platform == "win" then
-- 	prefs.external_editor = "code.cmd --wait %s"
-- elseif config.platform == "apple" then
-- 	prefs.external_editor = "code --wait %s"
-- end
-- prefs.editable_textfile = config.latexdir .. "/temp.tex"
-- default stylesheets added to newly created docs
prefs.styles = { "basic", "preamble" }
-- default latex engine setting
-- prefs.tex_engine = "luatex"
-- default latex autorun setting
prefs.auto_run_latex = true
-- auto export document when saved as .ipe
prefs.auto_export = {"pdf"}

-- -- check shortcuts.lua for additional shortcut parameters
shortcuts.previous_view = "Up"
shortcuts.next_view = "Down"
shortcuts.previous_page = "Left"
shortcuts.next_page = "Right"

-- Free Alt+W from change_width so it can be used for white background
shortcuts.change_width = nil

shortcuts.ipelet_1_rounded_rectangle = "Alt+B"

----------------------------------------------------------------------
-- Object Inspection & Z-Order Helpers
----------------------------------------------------------------------
local V = ipe.Vector
local type = _G.type or type
local tostring = _G.tostring or tostring
local tonumber = _G.tonumber or tonumber
local string = _G.string or string
local table = _G.table or table
local ipairs = _G.ipairs or ipairs
local pairs = _G.pairs or pairs
local math = _G.math or math

local function formatColor(c)
  if not c or c == "" or c == "none" then return nil end
  if type(c) == "string" then
    return c
  elseif type(c) == "table" then
    if c.r and c.g and c.b then
      if c.r == 1 and c.g == 1 and c.b == 1 then return "white" end
      if c.r == 0 and c.g == 0 and c.b == 0 then return "black" end
      return string.format("rgb(%.2f,%.2f,%.2f)", c.r, c.g, c.b)
    else
      return "custom"
    end
  else
    return tostring(c)
  end
end

local function describeObject(obj)
  if not obj then return "nil" end
  local t = obj:type()
  if t == "text" then
    local str = obj:text() or ""
    str = str:gsub("[\r\n\t]+", " "):gsub("%s+", " ")
    if #str > 28 then str = str:sub(1, 25) .. "..." end
    return string.format("Text '%s'", str)
  elseif t == "path" then
    local f = formatColor(obj:get("fill"))
    local s = formatColor(obj:get("stroke"))
    local details = {}
    if f then details[#details + 1] = "fill=" .. f end
    if s then details[#details + 1] = "stroke=" .. s end
    if #details == 0 then details[#details + 1] = "path" end
    return string.format("Path [%s]", table.concat(details, ", "))
  elseif t == "group" then
    local cnt = obj:count()
    local kinds = {}
    for i = 1, math.min(cnt, 3) do
      kinds[#kinds + 1] = obj:elementType(i)
    end
    if cnt > 3 then kinds[#kinds + 1] = "..." end
    return string.format("Group [%d items: %s]", cnt, table.concat(kinds, ", "))
  elseif t == "image" then
    return "Image"
  elseif t == "reference" then
    return string.format("Mark '%s'", tostring(obj:symbol()))
  else
    return tostring(t)
  end
end

local function getSelectionZInfo(model)
  local p = model:page()
  local total = #p
  if total == 0 then return "Empty page (0 objects)" end

  local sel = model:selection()
  if #sel == 0 then
    local layers = p:layers()
    return string.format("No selection | Page total: %d objects across %d layer(s) (%s)",
      total, #layers, table.concat(layers, ", "))
  elseif #sel == 1 then
    local idx = sel[1]
    local obj = p[idx]
    local layer = p:layerOf(idx)

    local layerTotal = 0
    local layerIdx = 0
    for i, o, s, l in p:objects() do
      if l == layer then
        layerTotal = layerTotal + 1
        if i == idx then layerIdx = layerTotal end
      end
    end

    local posDesc
    if idx == total then
      posDesc = "Top"
    elseif idx == 1 then
      posDesc = "Bottom"
    else
      posDesc = string.format("%d from top", total - idx)
    end

    return string.format("Selected [Z: %d/%d (%s)] | Layer: '%s' (%d/%d) | %s",
      idx, total, posDesc, layer, layerIdx, layerTotal, describeObject(obj))
  else
    local zIndices = {}
    local layersMap = {}
    for _, idx in ipairs(sel) do
      zIndices[#zIndices + 1] = tostring(idx)
      layersMap[p:layerOf(idx)] = true
    end
    local layersList = {}
    for l in pairs(layersMap) do layersList[#layersList + 1] = l end

    return string.format("Selected %d objects | Z-order: [%s] of %d | Layers: %s",
      #sel, table.concat(zIndices, ", "), total, table.concat(layersList, ", "))
  end
end

local function inspectZOrder(model)
  model.ui:explain(getSelectionZInfo(model))
end

----------------------------------------------------------------------
-- Hook Z-Order Movement Shortcuts (Front, Back, Forward, Backward)
----------------------------------------------------------------------
if _G.MODEL then
  local orig_front = _G.MODEL.saction_front
  if orig_front then
    _G.MODEL.saction_front = function(self)
      orig_front(self)
      local sel = self:selection()
      if #sel == 1 then
        local idx = sel[1]
        local p = self:page()
        self.ui:explain(string.format("Front -> Z: %d/%d (Top) | Layer: '%s' | %s",
          idx, #p, p:layerOf(idx), describeObject(p[idx])))
      elseif #sel > 1 then
        self.ui:explain(getSelectionZInfo(self))
      end
    end
  end

  local orig_back = _G.MODEL.saction_back
  if orig_back then
    _G.MODEL.saction_back = function(self)
      orig_back(self)
      local sel = self:selection()
      if #sel == 1 then
        local idx = sel[1]
        local p = self:page()
        self.ui:explain(string.format("Back -> Z: %d/%d (Bottom) | Layer: '%s' | %s",
          idx, #p, p:layerOf(idx), describeObject(p[idx])))
      elseif #sel > 1 then
        self.ui:explain(getSelectionZInfo(self))
      end
    end
  end

  local orig_forward = _G.MODEL.saction_forward
  if orig_forward then
    _G.MODEL.saction_forward = function(self)
      orig_forward(self)
      local sel = self:selection()
      if #sel == 1 then
        local idx = sel[1]
        local p = self:page()
        self.ui:explain(string.format("Forward -> Z: %d/%d | Layer: '%s' | %s",
          idx, #p, p:layerOf(idx), describeObject(p[idx])))
      elseif #sel > 1 then
        self.ui:explain(getSelectionZInfo(self))
      end
    end
  end

  local orig_backward = _G.MODEL.saction_backward
  if orig_backward then
    _G.MODEL.saction_backward = function(self)
      orig_backward(self)
      local sel = self:selection()
      if #sel == 1 then
        local idx = sel[1]
        local p = self:page()
        self.ui:explain(string.format("Backward -> Z: %d/%d | Layer: '%s' | %s",
          idx, #p, p:layerOf(idx), describeObject(p[idx])))
      elseif #sel > 1 then
        self.ui:explain(getSelectionZInfo(self))
      end
    end
  end
end

----------------------------------------------------------------------
-- Text White Background Extension (under Goodies)
----------------------------------------------------------------------
local DEFAULT_PAD_X = 3 -- pt
local DEFAULT_PAD_Y = 2 -- pt

local function boxshape(v1, v2)
  return { type = "curve", closed = true;
    { type = "segment"; v1, V(v1.x, v2.y) },
    { type = "segment"; V(v1.x, v2.y), v2 },
    { type = "segment"; v2, V(v2.x, v1.y) } }
end

local function addWhiteBackgroundToText(model)
  local p = model:page()
  if not p:hasSelection() then
    model.ui:explain("Please select one or more text objects first")
    return
  end

  model:autoRunLatex()

  local padX = DEFAULT_PAD_X
  local padY = DEFAULT_PAD_Y

  local selection = model:selection()
  local items = {}
  for _, idx in ipairs(selection) do
    local obj = p[idx]
    local b = p:bbox(idx)
    if not b:isEmpty() then
      local isAlreadyBgGroup = false
      local targetContent = obj:clone()
      if obj:type() == "group" and obj:count() == 2 then
        local el1 = obj:element(1)
        local el2 = obj:element(2)
        if el1:type() == "path" and (el2:type() == "text" or el2:type() == "group") then
          isAlreadyBgGroup = true
          targetContent = el2:clone()
        end
      end

      local v1 = V(b:left() - padX, b:bottom() - padY)
      local v2 = V(b:right() + padX, b:top() + padY)
      local bgPath = ipe.Path({ pathmode = "filled", fill = "white" }, { boxshape(v1, v2) })

      local newGroup
      if isAlreadyBgGroup then
        newGroup = ipe.Group({ bgPath, targetContent })
        if not obj:matrix():isIdentity() then
          newGroup:setMatrix(obj:matrix())
        end
      else
        newGroup = ipe.Group({ bgPath, targetContent })
      end

      items[#items + 1] = {
        index = idx,
        original = obj:clone(),
        final = newGroup,
      }
    end
  end

  if #items == 0 then
    model.ui:explain("No valid text objects found in selection")
    return
  end

  local t = {
    label = "add white background to text",
    pno = model.pno,
    vno = model.vno,
    items = items,
  }
  t.undo = function(t, doc)
    local page = doc[t.pno]
    for _, it in ipairs(t.items) do
      page:replace(it.index, it.original)
      page:setSelect(it.index, 2)
    end
    page:ensurePrimarySelection()
  end
  t.redo = function(t, doc)
    local page = doc[t.pno]
    for _, it in ipairs(t.items) do
      page:replace(it.index, it.final)
      page:setSelect(it.index, 2)
    end
    page:ensurePrimarySelection()
  end
  model:register(t)
  model.ui:explain(string.format("Added white background to %d text object(s)", #items))
end

----------------------------------------------------------------------
-- Register Goodies methods & shortcuts
----------------------------------------------------------------------
if _G.ipelets then
  for _, ip in ipairs(_G.ipelets) do
    if ip.name == "goodies" and ip.methods then
      -- 1. Add white background method (Alt+W)
      ip.methods[#ip.methods + 1] = {
        label = "Add white background to text",
        run = addWhiteBackgroundToText,
      }
      local bgMethodIdx = #ip.methods
      shortcuts["ipelet_" .. bgMethodIdx .. "_goodies"] = "Alt+W"

      -- 2. Inspect selected object Z-order method (Menu only)
      ip.methods[#ip.methods + 1] = {
        label = "Inspect selected object Z-order",
        run = inspectZOrder,
      }
      break
    end
  end
end
