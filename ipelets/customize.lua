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
-- Text White Background Extension (under Goodies)
----------------------------------------------------------------------
local V = ipe.Vector

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

-- Hook into Goodies ipelet
if _G.ipelets then
  for _, ip in ipairs(_G.ipelets) do
    if ip.name == "goodies" and ip.methods then
      ip.methods[#ip.methods + 1] = {
        label = "Add white background to text",
        run = addWhiteBackgroundToText,
      }
      local methodIdx = #ip.methods
      shortcuts["ipelet_" .. methodIdx .. "_goodies"] = "Alt+W"
      break
    end
  end
end
