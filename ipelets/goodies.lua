----------------------------------------------------------------------
-- goodies ipelet (extended with Rounded Rectangle)
----------------------------------------------------------------------
--[[

    This file is part of the extensible drawing editor Ipe.
    Copyright (c) 1993-2024 Otfried Cheong

    Extended with "Insert rounded rectangle", "Round selected rectangle",
    and "Set corner radius" for unified workflow.

--]]

label = "Goodies"

revertOriginal = _G.revertOriginal

about = [[
Several small functions, like precise scale and rotate, rounded rectangle,
precise boxes, marking circle centers, regular k-gons.

This ipelet is part of Ipe (custom extended).
]]

local V = ipe.Vector

local DEFAULT_RADIUS = 8 -- pt
local RADIUS_STEP = 2 -- pt per key press

local function bounding_box(p)
  local box = ipe.Rect()
  for i,obj,sel,layer in p:objects() do
    if sel then box:add(p:bbox(i)) end
  end
  return box
end

local function boxshape(v1, v2)
  return { type="curve", closed=true;
	   { type="segment"; v1, V(v1.x, v2.y) },
	   { type="segment"; V(v1.x, v2.y), v2 },
	   { type="segment"; v2, V(v2.x, v1.y) } }
end

----------------------------------------------------------------------
-- Rounded Rectangle Implementation
----------------------------------------------------------------------

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
  if r <= 1e-9 then return boxshape(v1, v2) end

  local halfpi = math.pi / 2
  local arcBR, brStart, brEnd = roundedCorner(x1 - r, y0 + r, r, -halfpi)
  local arcTR, trStart, trEnd = roundedCorner(x1 - r, y1 - r, r, 0)
  local arcTL, tlStart, tlEnd = roundedCorner(x0 + r, y1 - r, r, halfpi)
  local arcBL, blStart, blEnd = roundedCorner(x0 + r, y0 + r, r, math.pi)

  return { type = "curve", closed = true;
    { type = "segment"; blEnd, brStart }, -- bottom edge
    arcBR,
    { type = "segment"; brEnd, trStart }, -- right edge
    arcTR,
    { type = "segment"; trEnd, tlStart }, -- top edge
    arcTL,
    { type = "segment"; tlEnd, blStart }, -- left edge
    arcBL,
  }
end

ROUNDEDBOXTOOL = {}
ROUNDEDBOXTOOL.__index = ROUNDEDBOXTOOL

function ROUNDEDBOXTOOL:new(model)
  local tool = {}
  _G.setmetatable(tool, ROUNDEDBOXTOOL)
  tool.model = model
  tool.radius = model.rounded_rectangle_radius or DEFAULT_RADIUS
  tool.started = false
  local v = model.ui:pos()
  tool.v = { v, v }
  model.ui:shapeTool(tool)
  tool.setColor(1.0, 0, 0)
  tool.setSnapping(true, true)
  tool:explainRadius()
  return tool
end

function ROUNDEDBOXTOOL:compute()
  self.shape = roundedBoxShape(self.v[1], self.v[2], self.radius)
end

function ROUNDEDBOXTOOL:explainRadius()
  if not self.started then
    self.model.ui:explain(string.format("rounded rectangle: click 1st corner | radius %.1fpt (]/[ or +/- to adjust, r: enter value)", self.radius))
  else
    self.model.ui:explain(string.format("rounded rectangle: click 2nd corner | radius %.1fpt (]/[ or +/- to adjust, r: enter value)", self.radius))
  end
end

function ROUNDEDBOXTOOL:mouseButton(button, modifiers, press)
  if not press then return end
  if not self.started then
    self.started = true
    local v = self.model.ui:pos()
    self.v = { v, v }
    self:explainRadius()
    return
  end
  self.v[2] = self.model.ui:pos()
  self:compute()
  self.model.ui:finishTool()
  self.model.rounded_rectangle_radius = self.radius
  local obj = ipe.Path(self.model.attributes, { self.shape })
  self.model:creation("create rounded rectangle", obj)
end

function ROUNDEDBOXTOOL:mouseMove()
  if not self.started then return end
  self.v[2] = self.model.ui:pos()
  self:compute()
  self.setShape({ self.shape })
  self.model.ui:update(false)
end

function ROUNDEDBOXTOOL:key(text, modifiers)
  if text == "\027" then
    self.model.ui:finishTool()
    return true
  elseif text == "]" or text == "+" or text == "=" or text == "」" then
    self.radius = self.radius + RADIUS_STEP
    self.model.rounded_rectangle_radius = self.radius
    if self.started then
      self:compute()
      self.setShape({ self.shape })
      self.model.ui:update(false)
    end
    self:explainRadius()
    return true
  elseif text == "[" or text == "-" or text == "_" or text == "「" then
    self.radius = math.max(0, self.radius - RADIUS_STEP)
    self.model.rounded_rectangle_radius = self.radius
    if self.started then
      self:compute()
      self.setShape({ self.shape })
      self.model.ui:update(false)
    end
    self:explainRadius()
    return true
  elseif text == "r" or text == "R" then
    local str = self.model:getString("Corner radius (pt):", "Set Radius", tostring(self.radius))
    local val = tonumber(str)
    if val and val >= 0 then
      self.radius = val
      self.model.rounded_rectangle_radius = self.radius
      if self.started then
        self:compute()
        self.setShape({ self.shape })
        self.model.ui:update(false)
      end
      self:explainRadius()
    end
    return true
  else
    return false
  end
end

local function setRadiusDialog(model)
  local cur = model.rounded_rectangle_radius or DEFAULT_RADIUS
  local str = model:getString("Default corner radius (pt):", "Set Corner Radius", tostring(cur))
  local val = tonumber(str)
  if val and val >= 0 then
    model.rounded_rectangle_radius = val
    model.ui:explain(string.format("Default rounded rectangle radius set to %.1fpt", val))
  end
end

local function roundSelectedPath(model)
  local p = model:page()
  local prim = p:primarySelection()
  if not prim or p[prim]:type() ~= "path" then
    model.ui:explain("Please select a rectangle path first")
    return
  end
  local obj = p[prim]
  local box = obj:bbox()
  local cur = model.rounded_rectangle_radius or DEFAULT_RADIUS
  local str = model:getString("Corner radius (pt):", "Round Selected Rectangle", tostring(cur))
  local val = tonumber(str)
  if not (val and val >= 0) then return end
  model.rounded_rectangle_radius = val

  local shape = roundedBoxShape(box:bottomLeft(), box:topRight(), val)
  local newObj = ipe.Path(obj:matrix() * model.attributes, { shape })
  local t = { label = "round corners of rectangle", pno = model.pno, vno = model.vno,
              layer = p:layerOf(prim), primary = prim, original = obj, final = newObj }
  function t:redo(d)
    d[self.pno]:replace(self.primary, self.final)
  end
  function t:undo(d)
    d[self.pno]:replace(self.primary, self.original)
  end
  model:register(t)
end

----------------------------------------------------------------------
-- Built-in Goodies Functions
----------------------------------------------------------------------

function preciseTransform(model, num)
  -- num shifted by 3 because of the 3 rounded rectangle items
  local actualNum = num - 3
  local p = model:page()
  if not p:hasSelection() then
    model.ui:explain("no selection")
    return
  end
  local center = V(0,0)
  if model.snap.with_axes then
    center = model.snap.origin
  else
    center = bounding_box(p):center()
  end
  local m = nil
  if actualNum == 1 then
    m = ipe.Matrix(-1, 0, 0, 1, 2 * center.x, 0)
  elseif actualNum == 2 then
    m = ipe.Matrix(1, 0, 0, -1, 0, 2 * center.y)
  elseif actualNum == 3 then
    m = ipe.Matrix(1, 0, 0, -1, 0, 0)
  elseif actualNum == 4 then
    m = ipe.Matrix(-1, 0, 0, 1, 0, 0)
  elseif actualNum == 5 then
    m = ipe.Translation(center) * ipe.Rotation(math.pi / 2.0) * ipe.Translation(-center)
  elseif actualNum == 6 then
    m = ipe.Translation(center) * ipe.Rotation(math.pi) * ipe.Translation(-center)
  elseif actualNum == 7 then
    m = ipe.Translation(center) * ipe.Rotation(3.0 * math.pi / 2.0) * ipe.Translation(-center)
  elseif actualNum == 8 then
    local str = model:getString("Enter angle in degrees")
    if not str or str:match("^%s*$") then return end
    local degrees = tonumber(str)
    if not degrees then
      model:warning("Please enter angle in degrees")
      return
    end
    local rad = math.pi * degrees / 180.0
    m = ipe.Translation(center) * ipe.Rotation(rad) * ipe.Translation(-center)
  elseif actualNum == 9 then
    local str = model:getString("Enter stretch factor (e.g. '0.5' or '2 1.5')")
    if not str or str:match("^%s*$") then return end
    local sx, sy = str:match("^([%+%-%d%.]+)%s+([%+%-%d%.]+)$")
    if not sx then
      sx = str:match("^([%+%-%d%.]+)$")
      sy = sx
    end
    if not sx then
      model:warning("Please enter one or two numbers")
      return
    end
    sx, sy = tonumber(sx), tonumber(sy)
    m = ipe.Translation(center) * ipe.Matrix(sx, 0, 0, sy) * ipe.Translation(-center)
  end
  model:transformSelection(m)
end

function rotateAxis(model)
  if not model.snap.with_axes then
    model:warning("Cannot rotate coordinate system", "The coordinate system has not been set")
    return
  end
  local str = model:getString("Enter angle in degrees")
  if not str or str:match("^%s*$") then return end
  local degrees = tonumber(str)
  if not degrees then
    model:warning("Please enter angle in degrees")
    return
  end
  local rad = math.pi * degrees / 180.0
  model.snap.orientation = model.snap.orientation + rad
  if model.snap.orientation >= 2 * math.pi then
    model.snap.orientation = model.snap.orientation - 2 * math.pi
  elseif model.snap.orientation < 0 then
    model.snap.orientation = model.snap.orientation + 2 * math.pi
  end
  model:setSnap()
end

function preciseBox(model)
  local dpmm = 72.0 / 25.4
  local str = model:getString("Enter width and height in mm")
  if not str or str:match("^%s*$") then return end
  local ssx, ssy = str:match("^([%+%-%d%.]+)%s+([%+%-%d%.]+)$")
  if not ssx then
    model:warning("Please enter width and height in mm", "Separate the two numbers by a space.")
    return
  end
  local sx, sy = tonumber(ssx), tonumber(ssy)
  local corner = V(sx * dpmm, sy * dpmm)
  local origin = V(0,0)
  if model.snap.with_axes then
    origin = model.snap.origin
  end
  local shape = { boxshape(origin, origin + corner) }
  local obj = ipe.Path(model.attributes, shape)
  model:creation("create precise box", obj)
end

function boundingBox(model)
  if not model:page():hasSelection() then
    model.ui:explain("no selection")
    return
  end
  local box = bounding_box(model:page())
  local shape = { boxshape(box:bottomLeft(), box:topRight()) }
  local obj = ipe.Path(model.attributes, shape)
  model:creation("create bounding box", obj)
end

function mediaBox(model)
  local layout = model.doc:sheets():find("layout")
  local shape = { boxshape(-layout.origin, -layout.origin + layout.papersize) }
  local obj = ipe.Path(model.attributes, shape)
  model:creation("create mediabox", obj)
end

function checkPrimaryIsCircle(model, arc_ok)
  local p = model:page()
  local prim = p:primarySelection()
  if not prim then model.ui:explain("no selection") return end
  local obj = p[prim]
  if obj:type() == "path" then
    local shape = obj:shape()
    if #shape == 1 then
      local s = shape[1]
      if s.type == "ellipse" then
        return prim, obj, s[1]:translation(), shape
      end
      if arc_ok and s.type == "curve" and #s == 1 and s[1].type == "arc" then
        return prim, obj, s[1].arc:matrix():translation(), shape
      end
    end
  end
  if arc_ok then
    model:warning("Primary selection is not an arc, a circle, or an ellipse")
  else
    model:warning("Primary selection is not a circle or an ellipse")
  end
end

function markCircleCenter(model)
  local prim, obj, pos, shape = checkPrimaryIsCircle(model, true)
  if not prim then return end
  local obj = ipe.Reference(model.attributes, model.attributes.markshape,
			    obj:matrix() * pos)
  model:creation("mark circle center", obj)
end

local function incorrect_input(model)
  model:warning("Cannot create parabolas",
		"Primary selection is not a segment, or " ..
		  "other selected objects are not marks")
end

function parabola(model)
  local p = model:page()
  local prim = p:primarySelection()
  if not prim then model.ui:explain("no selection") return end
  local seg = p[prim]
  if seg:type() ~= "path" then incorrect_input(model) return end
  local shape = seg:shape()
  if #shape ~= 1 or shape[1].type ~= "curve" or
    #shape[1] ~= 1 or shape[1][1].type ~= "segment" then
    incorrect_input(model)
    return
  end

  local marks = {}
  for i,obj,sel,layer in p:objects() do
    if sel == 2 then
      if obj:type() ~= "reference" or obj:symbol():sub(1,5) ~= "mark/" then
        incorrect_input(model)
        return
      end
      marks[#marks + 1] = obj:matrix() * obj:position()
    end
  end

  if #marks == 0 then incorrect_input(model) return end

  local p0 = seg:matrix() * shape[1][1][1]
  local p1 = seg:matrix() * shape[1][1][2]

  local tfm = ipe.Translation(p0) * ipe.Rotation((p1 - p0):angle())
  local inv = tfm:inverse()
  local xmax = (p1 - p0):len()

  local parabolas = { }
  for i,pos in ipairs(marks) do
    local mrk = inv * pos
    local a = -mrk.x
    local b = xmax - mrk.x

    local q0 = V(a, a*a)
    local q1 = V(0.5*(a + b), a*b)
    local q2 = V(b, b*b)

    local curve = { type="curve", closed=false; { type="spline", q0, q1, q2 } }

    local obj = ipe.Path(model.attributes, { curve } )
    local stretch = 2.0 * mrk.y;
    local offs = V(mrk.x, mrk.y / 2.0)
    local m = (tfm * ipe.Translation(offs) *
	     ipe.Matrix(1, 0, 0, 1.0/stretch, 0, 0))
    obj:setMatrix(m);
    parabolas[#parabolas + 1] = obj
  end

  if #parabolas > 1 then
    local obj = ipe.Group(parabolas)
    model:creation("create parabolas", obj)
  else
    model:creation("create parabola", parabolas[1])
  end
end

function regularKGon(model)
  local prim, obj, pos, shape = checkPrimaryIsCircle(model, false)
  if not prim then return end

  local str = model:getString("Enter number of corners")
  if not str or str:match("^%s*$)") then return end
  local k = tonumber(str)
  if not k then
    model:warning("Enter a number between 3 and 1000!")
    return
  end

  local m = shape[1][1]
  local center = m:translation()
  local v = m * V(1,0)
  local radius = (v - center):len()

  local curve = { type="curve", closed=true }
  local alpha = 2 * math.pi / k
  local v0 = center + radius * V(1,0)
  for i = 1,k-1 do
    local v1 = center + radius * ipe.Direction(i * alpha)
    curve[#curve + 1] = { type="segment", v0, v1 }
    v0 = v1
  end

  local kgon = ipe.Path(model.attributes, { curve } )
  kgon:setMatrix(obj:matrix())
  model:creation("create regular k-gon", kgon)
end

function ellipse(model)
  local p = model:page()
  local foci = {}
  local pt
  for i,obj,sel,layer in p:objects() do
    if sel then
      if obj:type() ~= "reference" or obj:symbol():sub(1,5) ~= "mark/" then
        model:warning("Cannot create ellipse", "You must select exactly three marks")
        return
      end
      local v = obj:matrix() * obj:position()
      if sel == 1 then
        pt = v
      else
        foci[#foci + 1] = v
      end
    end
  end

  if #foci ~= 2 then
    model:warning("Cannot create ellipse", "You must select exactly three marks")
    return
  end

  local center = 0.5 * (foci[1] + foci[2])
  local c = (foci[1] - foci[2]):len() / 2
  local a = ((pt - foci[1]):len() + (pt - foci[2]):len()) / 2
  local b = math.sqrt(a*a - c*c)
  local m = ipe.Translation(center) * ipe.Rotation((foci[2] - foci[1]):angle()) * ipe.Matrix(a, 0, 0, b)
  
  local curve = { type="ellipse", m }
  local ellipse = ipe.Path(model.attributes, { curve } )
  model:creation("create ellipse from foci and third point", ellipse)
end

methods = {
  { label = "Insert rounded rectangle", run = function(model) ROUNDEDBOXTOOL:new(model) end },
  { label = "Round selected rectangle...", run = roundSelectedPath },
  { label = "Set corner radius...", run = setRadiusDialog },
  { label = "Mirror horizontal", run = preciseTransform },
  { label = "Mirror vertical", run = preciseTransform },
  { label = "Mirror at x-axis", run = preciseTransform },
  { label = "Mirror at y-axis", run = preciseTransform },
  { label = "Turn 90 degrees", run = preciseTransform },
  { label = "Turn 180 degrees", run = preciseTransform },
  { label = "Turn 270 degrees", run = preciseTransform },
  { label = "Precise rotate", run = preciseTransform },
  { label = "Precise stretch", run = preciseTransform },
  { label = "Rotate coordinate system", run = rotateAxis },
  { label = "Insert precise box", run = preciseBox },
  { label = "Insert bounding box", run = boundingBox },
  { label = "Insert media box", run = mediaBox },
  { label = "Mark circle center", run = markCircleCenter },
  { label = "Make parabolas", run = parabola },
  { label = "Regular k-gon", run = regularKGon },
  { label = "Ellipse from foci", run = ellipse },
}
