----------------------------------------------------------------------
-- rounded rectangle ipelet
----------------------------------------------------------------------
--
-- Adds a "Rounded Rectangle" action to the Ipelets menu that starts an
-- interactive drag tool, mirroring Ipe's own built-in rectangle tool
-- (BOXTOOL in tools.lua): click to anchor one corner, drag to the
-- opposite corner, release to insert. While dragging, ]/[ adjusts the
-- corner radius live; the radius is remembered for next time.
--
-- Unlike BOXTOOL, this tool is started from a menu click rather than a
-- canvas click, so the menu selection itself must NOT count as the
-- first corner: the tool waits for an explicit first click on the
-- canvas before it starts tracking a second corner.
----------------------------------------------------------------------

label = "Rounded Rectangle"

about = [[
Draw a rounded rectangle: click to set the first corner, move the
mouse, then click again to set the opposite corner. While dragging,
press ] or [ to adjust the corner radius (remembered for next time).
]]

local V = ipe.Vector

local DEFAULT_RADIUS = 8 -- pt
local RADIUS_STEP = 2 -- pt per ]/[ press

-- "+"/"-" collide with Ipe's built-in fit_objects/fit_width shortcuts
-- (see shortcuts.lua), so ]/[ are used for the live radius adjustment
-- instead.

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
  model.ui:explain("rounded rectangle: click to set the first corner")
  return tool
end

function ROUNDEDBOXTOOL:compute()
  self.shape = roundedBoxShape(self.v[1], self.v[2], self.radius)
end

function ROUNDEDBOXTOOL:explainRadius()
  self.model.ui:explain(string.format("rounded rectangle: radius %.1fpt (]/[ to adjust)", self.radius))
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
  elseif self.started and text == "]" then
    self.radius = self.radius + RADIUS_STEP
    self:compute()
    self.setShape({ self.shape })
    self.model.ui:update(false)
    self:explainRadius()
    return true
  elseif self.started and text == "[" then
    self.radius = math.max(0, self.radius - RADIUS_STEP)
    self:compute()
    self.setShape({ self.shape })
    self.model.ui:update(false)
    self:explainRadius()
    return true
  else
    return false
  end
end

----------------------------------------------------------------------

function run(model)
  ROUNDEDBOXTOOL:new(model)
end
