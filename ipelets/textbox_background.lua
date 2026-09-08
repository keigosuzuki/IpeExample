----------------------------------------------------------------------
-- textbox_background ipelet
----------------------------------------------------------------------
--
-- Automatically creates a white (or custom colored) background box
-- (rectangular or rounded) behind selected text box(es) or selection,
-- and groups them together in-place with full Undo / Redo support.
----------------------------------------------------------------------

label = "Textbox Background"

about = [[
Add a white or custom background box behind selected text objects.
Automatically calculates text bounding boxes and groups the text with
the background path in-place. Supports rectangular and rounded boxes,
unified selection bounding boxes, and removing existing backgrounds.
]]

local V = ipe.Vector

local DEFAULT_PAD_X = 3 -- pt
local DEFAULT_PAD_Y = 2 -- pt
local DEFAULT_RADIUS = 3 -- pt
local DEFAULT_FILL = "white"
local DEFAULT_STROKE = "none"

local function boxshape(v1, v2)
  return { type = "curve", closed = true;
    { type = "segment"; v1, V(v1.x, v2.y) },
    { type = "segment"; V(v1.x, v2.y), v2 },
    { type = "segment"; v2, V(v2.x, v1.y) } }
end

local function roundedCorner(cx, cy, r, alpha)
  local beta = alpha + math.pi / 2
  local center = V(cx, cy)
  local p0 = center + r * ipe.Direction(alpha)
  local p1 = center + r * ipe.Direction(beta)
  local arc = ipe.Arc(ipe.Matrix(r, 0, 0, r, cx, cy), alpha, beta)
  return { type = "arc", arc = arc; p0, p1 }, p0, p1
end

local function roundedBoxShape(v1, v2, radius)
  local x0, x1 = math.min(v1.x, v2.x), math.max(v1.x, v2.x)
  local y0, y1 = math.min(v1.y, v2.y), math.max(v1.y, v2.y)
  local r = math.min(radius, (x1 - x0) / 2, (y1 - y0) / 2)
  if r <= 1e-6 then return boxshape(v1, v2) end

  local halfpi = math.pi / 2
  local arcBR, brStart, brEnd = roundedCorner(x1 - r, y0 + r, r, -halfpi)
  local arcTR, trStart, trEnd = roundedCorner(x1 - r, y1 - r, r, 0)
  local arcTL, tlStart, tlEnd = roundedCorner(x0 + r, y1 - r, r, halfpi)
  local arcBL, blStart, blEnd = roundedCorner(x0 + r, y0 + r, r, math.pi)

  return { type = "curve", closed = true;
    { type = "segment"; blEnd, brStart },
    arcBR,
    { type = "segment"; brEnd, trStart },
    arcTR,
    { type = "segment"; trEnd, tlStart },
    arcTL,
    { type = "segment"; tlEnd, blStart },
    arcBL,
  }
end

local function createBgPath(v1, v2, radius, fillColor, strokeColor)
  local shape
  if radius and radius > 0 then
    shape = roundedBoxShape(v1, v2, radius)
  else
    shape = boxshape(v1, v2)
  end

  local attrs = {
    fill = fillColor or "white",
  }
  if strokeColor and strokeColor ~= "" and strokeColor ~= "none" then
    attrs.pathmode = "strokedfilled"
    attrs.stroke = strokeColor
  else
    attrs.pathmode = "filled"
  end

  return ipe.Path(attrs, { shape })
end

local function addBackground(model, isRounded, unified)
  local p = model:page()
  if not p:hasSelection() then
    model.ui:explain("Please select one or more text objects first")
    return
  end

  model:autoRunLatex()

  local padX = model.textbox_bg_padx or DEFAULT_PAD_X
  local padY = model.textbox_bg_pady or DEFAULT_PAD_Y
  local radius = isRounded and (model.textbox_bg_radius or DEFAULT_RADIUS) or 0
  local fillColor = model.textbox_bg_fill or DEFAULT_FILL
  local strokeColor = model.textbox_bg_stroke or DEFAULT_STROKE

  local selection = model:selection()

  if unified and #selection > 1 then
    -- Unified box around entire selection
    local combinedBox = ipe.Rect()
    local elements = {}
    for _, idx in ipairs(selection) do
      combinedBox:add(p:bbox(idx))
      elements[#elements + 1] = p[idx]:clone()
    end
    if combinedBox:isEmpty() then
      model.ui:explain("Selected objects have empty bounding box")
      return
    end
    local v1 = V(combinedBox:left() - padX, combinedBox:bottom() - padY)
    local v2 = V(combinedBox:right() + padX, combinedBox:top() + padY)
    local bgPath = createBgPath(v1, v2, radius, fillColor, strokeColor)

    local allElements = { bgPath }
    for _, el in ipairs(elements) do
      allElements[#allElements + 1] = el
    end
    local finalGroup = ipe.Group(allElements)

    p:deselectAll()
    local t = {
      label = isRounded and "add unified rounded background" or "add unified background",
      pno = model.pno,
      vno = model.vno,
      selection = selection,
      final = finalGroup,
      layer = p:active(model.vno),
      original = p:clone(),
    }
    t.undo = function(t, doc)
      doc[t.pno] = t.original:clone()
    end
    t.redo = function(t, doc)
      local page = doc[t.pno]
      for i = #t.selection, 1, -1 do
        page:remove(t.selection[i])
      end
      page:insert(nil, t.final, 1, t.layer)
    end
    model:register(t)
    model.ui:explain(string.format("Added unified %sbackground box around selection", isRounded and "rounded " or ""))
  else
    -- Individual background box for each selected object
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
        local bgPath = createBgPath(v1, v2, radius, fillColor, strokeColor)

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
      model.ui:explain("No valid objects found to add background to")
      return
    end

    local t = {
      label = isRounded and "add rounded background to text" or "add background to text",
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
    model.ui:explain(string.format("Added %sbackground to %d object(s)", isRounded and "rounded " or "", #items))
  end
end

local function removeBackground(model)
  local p = model:page()
  if not p:hasSelection() then
    model.ui:explain("Please select a group with a background box first")
    return
  end

  local selection = model:selection()
  local items = {}
  for _, idx in ipairs(selection) do
    local obj = p[idx]
    if obj:type() == "group" and obj:count() >= 2 then
      local el1 = obj:element(1)
      if el1:type() == "path" then
        if obj:count() == 2 then
          local restored = obj:element(2):clone()
          if not obj:matrix():isIdentity() then
            restored:setMatrix(obj:matrix() * restored:matrix())
          end
          items[#items + 1] = {
            index = idx,
            original = obj:clone(),
            final = restored,
          }
        end
      end
    end
  end

  if #items == 0 then
    model.ui:explain("No background groups found in selection to remove")
    return
  end

  local t = {
    label = "remove background from text",
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
  model.ui:explain(string.format("Removed background from %d object(s)", #items))
end

local function setPaddingDialog(model)
  local curX = model.textbox_bg_padx or DEFAULT_PAD_X
  local curY = model.textbox_bg_pady or DEFAULT_PAD_Y
  local curR = model.textbox_bg_radius or DEFAULT_RADIUS
  local defaultStr = string.format("%.1f, %.1f, %.1f", curX, curY, curR)
  local str = model:getString("Padding X, Padding Y, Corner Radius (pt):", "Textbox Background Settings", defaultStr)
  if not str then return end

  local sx, sy, sr = str:match("^%s*([%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)%s*$")
  if not sx then
    sx, sy = str:match("^%s*([%d%.]+)[%s,]+([%d%.]+)%s*$")
  end
  if not sx then
    sx = str:match("^%s*([%d%.]+)%s*$")
    sy = sx
  end

  local nx, ny, nr = tonumber(sx), tonumber(sy), tonumber(sr)
  if nx and nx >= 0 then model.textbox_bg_padx = nx end
  if ny and ny >= 0 then model.textbox_bg_pady = ny end
  if nr and nr >= 0 then model.textbox_bg_radius = nr end

  model.ui:explain(string.format("Textbox Background set to: PadX=%.1fpt, PadY=%.1fpt, Radius=%.1fpt",
    model.textbox_bg_padx or DEFAULT_PAD_X,
    model.textbox_bg_pady or DEFAULT_PAD_Y,
    model.textbox_bg_radius or DEFAULT_RADIUS))
end

local function setFillColorDialog(model)
  local cur = model.textbox_bg_fill or DEFAULT_FILL
  local str = model:getString("Background fill color (e.g., white, yellow, lightgray):", "Set Background Color", cur)
  if str and str ~= "" then
    model.textbox_bg_fill = str:match("^%s*(.-)%s*$")
    model.ui:explain(string.format("Textbox background fill set to '%s'", model.textbox_bg_fill))
  end
end

local function setStrokeDialog(model)
  local cur = model.textbox_bg_stroke or DEFAULT_STROKE
  local str = model:getString("Background border/stroke (color name or 'none'):", "Set Background Border", cur)
  if str and str ~= "" then
    model.textbox_bg_stroke = str:match("^%s*(.-)%s*$")
    model.ui:explain(string.format("Textbox background border set to '%s'", model.textbox_bg_stroke))
  end
end

methods = {
  { label = "Add White Background (Box)", run = function(model) addBackground(model, false, false) end },
  { label = "Add Rounded White Background", run = function(model) addBackground(model, true, false) end },
  { label = "Add Unified Background (Selection)", run = function(model) addBackground(model, false, true) end },
  { label = "Add Unified Rounded Background (Selection)", run = function(model) addBackground(model, true, true) end },
  { label = "Remove Background from Selected", run = function(model) removeBackground(model) end },
  { label = "Set Padding & Corner Radius...", run = setPaddingDialog },
  { label = "Set Background Fill Color...", run = setFillColorDialog },
  { label = "Set Background Border / Stroke...", run = setStrokeDialog },
}

function run(model, num)
  if methods[num] and methods[num].run then
    methods[num].run(model)
  elseif num == 1 or not num then
    addBackground(model, false, false)
  end
end
