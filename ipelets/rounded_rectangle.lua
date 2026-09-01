----------------------------------------------------------------------
-- rounded rectangle ipelet
----------------------------------------------------------------------
--
-- Adds a "Rounded Rectangle" action to the Ipelets menu that starts an
-- interactive drag tool, mirroring Ipe's own built-in rectangle tool
-- (BOXTOOL in tools.lua): click to anchor one corner, drag to the
-- opposite corner, release to insert.
--
-- Radius adjustment:
-- - Press ] / [ or + / - (or IME 「 / 」) to adjust radius live in 2pt steps.
-- - Press 'r' to type the exact radius in pt via a dialog.
-- - Works BOTH before the first click and while dragging!
-- - Also provides menu actions to set default radius and to round existing
--   selected rectangle paths.
----------------------------------------------------------------------

label = "Rounded Rectangle"

about = [[
Draw a rounded rectangle: click to set the first corner, move the
mouse, then click again to set the opposite corner.
While using the tool, press ] / [ or + / - (or 'r' to enter a number)
to adjust the corner radius live (remembered for next time).
]]

local V = ipe.Vector

local DEFAULT_RADIUS = 8 -- pt
local RADIUS_STEP = 2 -- pt per key press

local function boxshape(v1, v2)
  return { type = "curve", closed = true;
    { type = "segment"; v1, V(v1.x, v2.y) },
    { type = "segment"; V(v1.x, v2.y), v2 },
    { type = "segment"; v2, V(v2.x, v1.y) } }
end

-- One quarter-circle corner, going counterclockwise from angle alpha
-- to alpha + pi/2. Returns the arc segment plus its two endpoints.
local function roundedCorner(cx, cy, r, alpha)
  local beta = alpha + math.pi / 2
  local center = V(cx, cy)
  local p0 = center + r * ipe.Direction(alpha)
  local p1 = center + r * ipe.Direction(beta)
  local arc = ipe.Arc(ipe.Matrix(r, 0, 0, r, cx, cy), alpha, beta)
  return { type = "arc", arc = arc; p0, p1 }, p0, p1
end

-- A closed curve for the rectangle spanned by v1/v2, with all four
-- corners rounded to `radius` (clamped to half the shorter side).
-- Falls back to a plain rectangle when radius is (effectively) zero.
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

----------------------------------------------------------------------

ROUNDEDBOXTOOL = {}
ROUNDEDBOXTOOL.__index = ROUNDEDBOXTOOL

function ROUNDEDBOXTOOL:new(model)
  local tool = {}
  _G.setmetatable(tool, ROUNDEDBOXTOOL)
  tool.model = model
  tool.radius = model.rounded_rectangle_radius or DEFAULT_RADIUS
  tool.started = false -- waiting for the first click to anchor a corner
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
    -- first click: anchor the starting corner, now track the drag
    self.started = true
    local v = self.model.ui:pos()
    self.v = { v, v }
    self:explainRadius()
    return
  end
  -- second click: finish
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

----------------------------------------------------------------------

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

methods = {
  { label = "Draw Rounded Rectangle", run = function(model) ROUNDEDBOXTOOL:new(model) end },
  { label = "Set Corner Radius...", run = setRadiusDialog },
  { label = "Round Selected Rectangle...", run = roundSelectedPath },
}

function run(model, num)
  if num == 1 or not num then
    ROUNDEDBOXTOOL:new(model)
  elseif num == 2 then
    setRadiusDialog(model)
  elseif num == 3 then
    roundSelectedPath(model)
  end
end
