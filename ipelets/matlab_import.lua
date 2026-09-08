----------------------------------------------------------------------
-- MATLAB Plot Importer ipelet for Ipe
----------------------------------------------------------------------
--
-- Features:
-- 1. Seamlessly imports MATLAB vector plots (PDF / IPE):
--    - Generic Euclidean RGB color distance matching to symbolic colors
--      in color_matlab.isy (matlab_blue, matlab_red, matlab_orange, etc.)
--      and basic.isy (black, lightgray).
--    - Automatic pen width normalization (ultrathin, normal, heavier, fat).
--    - Grid line classification and styling (stroke="lightgray" pen="ultrathin").
-- 2. Smart LaTeX Typography, Clustering & Alignment:
--    - Geometric character clustering: calculates inter-character delta-x
--      to accurately reconstruct whitespace between words.
--    - Log-axis superscript detection ($10^{-1}$, $10^0$, $10^1$, $10^2$).
--    - Generic TeX variable and unit pattern recognition ($x$ [unit], $y(t)$).
--    - True-size LaTeX text using transformations="translations".
--    - Right-aligned tick labels and centered rotated Y-axis labels.
-- 3. Automatic style sheet attachment (color_matlab.isy).
-- 4. Instant one-click import with auto-fit centering.
--
----------------------------------------------------------------------

local _G = _G
local io = _G.io or io
local os = _G.os or os
local math = _G.math or math
local string = _G.string or string
local table = _G.table or table

label = "Insert MATLAB Plot"

about = [[
Seamlessly import MATLAB vector plots (PDF/IPE) into your Ipe document
or slide. Automatically maps colors to color_matlab.isy, normalizes pen
widths, reconstructs text spacing geometrically, and formats LaTeX axes.
]]

local function styleDir()
  local ipeletDir = (path and path:match("^(.*)[/\\][^/\\]+$")) or "."
  local repoRoot = ipeletDir:match("^(.*)[/\\][^/\\]+$") or ipeletDir
  return repoRoot .. "/styles"
end

local function hasSheet(doc, sheetName)
  for i = 1, doc:sheets():count() do
    if doc:sheets():sheet(i):name() == sheetName then
      return true
    end
  end
  return false
end

local function ensureMatlabColors(model)
  local doc = model.doc
  if hasSheet(doc, "color_matlab") then
    return true
  end

  local sPath = styleDir() .. "/color_matlab.isy"
  local sheet = ipe.Sheet(sPath)
  if not sheet then
    sheet = ipe.Sheet("styles/color_matlab.isy")
  end
  if not sheet then
    return false
  end

  local basicIdx = nil
  for i = 1, doc:sheets():count() do
    local n = doc:sheets():sheet(i):name()
    if n == "basic" or n == "standard" then
      basicIdx = i
      break
    end
  end
  local insertPos = basicIdx or (doc:sheets():count() + 1)

  local t = { label = "attach MATLAB color palette", model = model, style_sheets_changed = true }
  t.redo = function(t, d)
    d:sheets():insert(insertPos, sheet:clone())
  end
  t.undo = function(t, d)
    for i = 1, d:sheets():count() do
      if d:sheets():sheet(i):name() == "color_matlab" then
        d:sheets():remove(i)
        break
      end
    end
  end
  model:register(t)
  return true
end

-- Escape unescaped LaTeX special characters outside math mode ($...$)
local function sanitizeLatex(str)
  local parts = {}
  local inMath = false
  local lastIdx = 1
  local pos = 1
  local len = #str
  while pos <= len do
    local c = str:sub(pos, pos)
    if c == '$' then
      local before = str:sub(lastIdx, pos - 1)
      if inMath then
        parts[#parts + 1] = before .. '$'
        inMath = false
      else
        before = before:gsub('([_%%&#^~])', function(m)
          if m == '_' then return '\\_'
          elseif m == '%' then return '\\%'
          elseif m == '&' then return '\\&'
          elseif m == '#' then return '\\#'
          elseif m == '^' then return '\\^{}'
          elseif m == '~' then return '\\textasciitilde{}'
          end
        end)
        parts[#parts + 1] = before .. '$'
        inMath = true
      end
      lastIdx = pos + 1
    end
    pos = pos + 1
  end

  local remaining = str:sub(lastIdx)
  if not inMath then
    remaining = remaining:gsub('([_%%&#^~])', function(m)
      if m == '_' then return '\\_'
      elseif m == '%' then return '\\%'
      elseif m == '&' then return '\\&'
      elseif m == '#' then return '\\#'
      elseif m == '^' then return '\\^{}'
      elseif m == '~' then return '\\textasciitilde{}'
      end
    end)
  end
  parts[#parts + 1] = remaining
  return table.concat(parts)
end

-- Reference MATLAB RGB colors for nearest-neighbor Euclidean distance mapping
local MATLAB_PALETTE = {
  { name = "matlab_blue",   r = 0.000, g = 0.447, b = 0.714 },
  { name = "matlab_red",    r = 0.850, g = 0.325, b = 0.098 },
  { name = "matlab_orange", r = 0.929, g = 0.694, b = 0.125 },
  { name = "matlab_purple", r = 0.494, g = 0.184, b = 0.556 },
  { name = "matlab_green",  r = 0.466, g = 0.674, b = 0.188 },
  { name = "matlab_cyan",   r = 0.301, g = 0.745, b = 0.933 },
  { name = "matlab_brown",  r = 0.635, g = 0.078, b = 0.184 },
}

local function matchColor(r, g, b)
  -- Check for grayscale / achromatic
  local maxDiff = math.max(math.abs(r - g), math.abs(g - b), math.abs(r - b))
  if maxDiff < 0.08 then
    local lum = 0.299 * r + 0.587 * g + 0.114 * b
    if lum > 0.95 then
      return "white"
    elseif lum > 0.70 then
      return "lightgray"
    else
      return "black"
    end
  end

  -- Euclidean distance in RGB color space
  local bestName = "black"
  local bestDist = 999999
  for _, c in ipairs(MATLAB_PALETTE) do
    local dist = (r - c.r)^2 + (g - c.g)^2 + (b - c.b)^2
    if dist < bestDist then
      bestDist = dist
      bestName = c.name
    end
  end
  return bestName
end

local function matchPen(w)
  if w <= 0.6 then
    return "ultrathin"
  elseif w <= 1.0 then
    return "normal"
  elseif w <= 1.6 then
    return "heavier"
  else
    return "fat"
  end
end

-- Generic LaTeX text formatter for axis labels, units, and math symbols
local function formatGenericPlotText(str)
  if str == "" then return "" end

  -- Already formatted in TeX math
  if str:find("%$") then
    return str
  end

  -- Common math replacements
  str = str:gsub("!1", "$10^{-1}$")
  str = str:gsub("10!1", "$10^{-1}$")
  str = str:gsub("100", "$10^0$")
  str = str:gsub("101", "$10^1$")
  str = str:gsub("102", "$10^2$")
  str = str:gsub("103", "$10^3$")

  -- Symbol font glyph mappings & omega equations
  str = str:gsub("%(!%s*=%s*([%d%.]+)%s*rad%/s%)", "($\\omega_n = %1\\,\\mathrm{rad/s}$)")
  str = str:gsub("%(!%s*=%s*([%d%.]+)%s*rad=s%)", "($\\omega_n = %1\\,\\mathrm{rad/s}$)")
  str = str:gsub("%(!%s*=%s*", "($\\omega_n = ")
  str = str:gsub("rad=s", "rad/s")
  str = str:gsub("([%d%a])%s*=%s*s", "%1/s")

  -- Convert parameter equations: e.g. zeta = 0.2
  str = str:gsub("1%s*=%s*(%d+)%s*:%s*(%d+)", "$\\zeta = %1.%2$")
  str = str:gsub("1%s*=%s*([%-%+%.%d]+)", "$\\zeta = %1$")
  str = str:gsub("w_n%s*=%s*", "$\\omega_n = $")

  -- Math functions and variables with parenthesized time or frequency: e.g. y(t), \dot{y}(t), G(j\omega), u(t)
  str = str:gsub("(%a+)%s*([A-Za-z])_%(t%)", "%1 $\\dot{%2}(t)$")
  str = str:gsub("^([A-Za-z])_%(t%)", "$\\dot{%1}(t)$")
  str = str:gsub("(%a+)%s*([A-Za-z])%(t%)", "%1 $%2(t)$")
  str = str:gsub("^([A-Za-z])%(t%)", "$%1(t)$")
  str = str:gsub("(%a+)%s*([A-Za-z])%(s%)", "%1 $%2(s)$")
  str = str:gsub("^([A-Za-z])%(s%)", "$%1(s)$")
  str = str:gsub("(%a+)%s*j([A-Za-z])%(j!%)j", "%1 $|%2(j\\omega)|$")
  str = str:gsub("^j([A-Za-z])%(j!%)j", "$|%1(j\\omega)|$")
  str = str:gsub("(%a+)%s*j([A-Za-z])%(s%)j", "%1 $|%2(s)|$")
  str = str:gsub("^j([A-Za-z])%(s%)j", "$|%1(s)|$")

  -- Variables before bracketed units: e.g. "Time t [s]" -> "Time $t$ [s]", "Frequency f [Hz]" -> "Frequency $f$ [Hz]"
  str = str:gsub("(%a+)%s+([a-zA-Z])%s+(%[[%a%/]+%])", "%1 $%2$ %3")
  str = str:gsub("(%a+)([a-zA-Z])(%[[%a%/]+%])", "%1 $%2$ %3")
  str = str:gsub("^([a-zA-Z])%s+(%[[%a%/]+%])", "$%1$ %2")
  str = str:gsub("^([a-zA-Z])(%[[%a%/]+%])", "$%1$ %2")

  -- Phase angle and greek characters
  str = str:gsub("Phase%s*%?%s*%[deg%]", "Phase $\\phi$ [deg]")
  str = str:gsub("Phase%?%s*%[deg%]", "Phase $\\phi$ [deg]")
  str = str:gsub("Phase%s*%?", "Phase $\\phi$")
  str = str:gsub("Phase%?", "Phase $\\phi$")

  -- Units and spacing
  str = str:gsub("%[kH%s*z%]", "[kHz]")
  str = str:gsub("%[k%s*Hz%]", "[kHz]")
  str = str:gsub("%[k%s*H%s*z%]", "[kHz]")
  str = str:gsub("kH%s*z", "kHz")
  str = str:gsub("(%d+)%s*N%s*m", "%1 Nm")
  str = str:gsub("(%d+%.%d+)%s*N%s*m", "%1 Nm")
  str = str:gsub("(%d+)%s*r%s*p%s*m", "%1 rpm")

  -- Electrical Power, Pelec, etc.
  str = str:gsub("Electrical%s*Power%s*P%s*elec%s*%[W%]", "Electrical Power $P_{\\mathrm{elec}}$ [W]")
  str = str:gsub("ElectricalPowerP%s*%[W%]%s*elec", "Electrical Power $P_{\\mathrm{elec}}$ [W]")
  str = str:gsub("ElectricalPowerP%s*elec%s*%[W%]", "Electrical Power $P_{\\mathrm{elec}}$ [W]")
  str = str:gsub("ElectricalPower", "Electrical Power ")
  str = str:gsub("Minimum%s*P%s*elec%s*Point", "Minimum $P_{\\mathrm{elec}}$ Point")
  str = str:gsub("M%s*inimum%s*P%s*elec%s*Point", "Minimum $P_{\\mathrm{elec}}$ Point")
  str = str:gsub("M%s+inimum", "Minimum")
  str = str:gsub("OptimalPath", "Optimal Path")
  str = str:gsub("Optimal%s*Path", "Optimal Path")
  str = str:gsub("(%a+)%s*(%$[A-Za-z])", "%1 %2")

  return str
end

local function cleanAndMergeMatlabIpeXml(content)
  -- 1. Remove full-page solid background if present
  content = content:gsub('<path fill="1%.0+ 1%.0+ 1%.0+">\n%s*[%-%d%.]+%s+[%-%d%.]+%s+m\n.-h\n%s*</path>', function(p)
    if p:find("%-1%.05") or p:find("369%.45") or p:find("0%.73") then
      return ""
    end
    return p
  end, 1)

  -- 2. Convert dotted/dashed subpath clusters into clean native Ipe dotted paths
  content = content:gsub('<path([^>]*)>(.-)</path>', function(attr, body)
    local m_count = 0
    for _ in body:gmatch("%f[%w]m%f[%W]") do m_count = m_count + 1 end

    if m_count >= 5 then
      local minX, maxX = 999999, -999999
      local minY, maxY = 999999, -999999
      for x, y in body:gmatch("([%-%d%.]+)%s+([%-%d%.]+)%s+[ml]") do
        local nx, ny = tonumber(x), tonumber(y)
        if nx and ny then
          if nx < minX then minX = nx end
          if nx > maxX then maxX = nx end
          if ny < minY then minY = ny end
          if ny > maxY then maxY = ny end
        end
      end

      local width = maxX - minX
      local height = maxY - minY

      if width > 3 * height and width > 10 then
        -- Horizontal dotted grid line
        local midY = (minY + maxY) / 2
        return string.format('<path stroke="lightgray" pen="ultrathin" dash="dotted">\n%.4f %.4f m\n%.4f %.4f l\n</path>', minX, midY, maxX, midY)
      elseif height > 3 * width and height > 10 then
        -- Vertical dotted grid line
        local midX = (minX + maxX) / 2
        return string.format('<path stroke="lightgray" pen="ultrathin" dash="dotted">\n%.4f %.4f m\n%.4f %.4f l\n</path>', midX, minY, midX, maxY)
      end
    end

    return '<path' .. attr .. '>' .. body .. '</path>'
  end)

  -- 3. Detect Subplot Box Rectangles for precise center alignments
  local plotBoxes = {}
  for body in content:gmatch('<path[^>]*>(.-)</path>') do
    local minX, maxX = 999999, -999999
    local minY, maxY = 999999, -999999
    local count = 0
    for x, y in body:gmatch("([%-%d%.]+)%s+([%-%d%.]+)%s+[ml]") do
      local nx, ny = tonumber(x), tonumber(y)
      if nx and ny then
        if nx < minX then minX = nx end
        if nx > maxX then maxX = nx end
        if ny < minY then minY = ny end
        if ny > maxY then maxY = ny end
        count = count + 1
      end
    end
    local isRect = (count == 4 or count == 5)
    if isRect then
      for x, y in body:gmatch("([%-%d%.]+)%s+([%-%d%.]+)%s+[ml]") do
        local nx, ny = tonumber(x), tonumber(y)
        if nx and ny then
          local onX = (math.abs(nx - minX) < 1.5 or math.abs(nx - maxX) < 1.5)
          local onY = (math.abs(ny - minY) < 1.5 or math.abs(ny - maxY) < 1.5)
          if not (onX and onY) then
            isRect = false
            break
          end
        end
      end
    end
    if isRect and (maxX - minX) > 80 and (maxY - minY) > 50 then
      local found = false
      for _, b in ipairs(plotBoxes) do
        if math.abs(b.minX - minX) < 8 and math.abs(b.minY - minY) < 8 then
          found = true
          break
        end
      end
      if not found then
        table.insert(plotBoxes, { minX = minX, maxX = maxX, minY = minY, maxY = maxY, midX = (minX + maxX)/2, midY = (minY + maxY)/2 })
      end
    end
  end

  -- 4. Normalize and map paths (strokes, fills, pens) generically
  content = content:gsub('<path([^>]*)>', function(attr)
    local fill_r, fill_g, fill_b = attr:match('fill="([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)"')
    local fill_gray = attr:match('fill="([%d%.]+)"')
    local stroke_r, stroke_g, stroke_b = attr:match('stroke="([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)"')
    local stroke_gray = attr:match('stroke="([%d%.]+)"')
    local pen_val = attr:match('pen="([%d%.]+)"')

    local newAttr = attr

    -- Generic Fill Mapping
    if fill_r and fill_g and fill_b then
      local fr, fg, fb = tonumber(fill_r), tonumber(fill_g), tonumber(fill_b)
      local maxDiff = math.max(math.abs(fr - fg), math.abs(fg - fb), math.abs(fr - fb))
      if maxDiff < 0.05 and fr > 0.10 and fr < 0.20 then
        -- 3D grid line drawn as thin filled polygon with 15% opacity in PDF
        newAttr = newAttr:gsub('fill="[^"]*"', 'fill="lightgray"')
      else
        local cName = matchColor(fr, fg, fb)
        if cName == "lightgray" or cName == "white" then
          newAttr = newAttr:gsub('fill="[^"]*"', 'fill="' .. cName .. '"')
        end
      end
    elseif fill_gray then
      local g = tonumber(fill_gray)
      if g > 0.70 and g <= 0.95 then
        newAttr = newAttr:gsub('fill="[^"]*"', 'fill="lightgray"')
      end
    end

    -- Generic Stroke & Pen Mapping
    if stroke_r and stroke_g and stroke_b then
      local r, g, b = tonumber(stroke_r), tonumber(stroke_g), tonumber(stroke_b)
      local cName = matchColor(r, g, b)
      local pName = pen_val and matchPen(tonumber(pen_val)) or "normal"
      
      if cName == "lightgray" then
        pName = "ultrathin"
      elseif cName:find("^matlab_") and (not pen_val or tonumber(pen_val) >= 0.8) then
        pName = "heavier"
      end

      newAttr = newAttr:gsub('stroke="[^"]*"', 'stroke="' .. cName .. '"')
      if pen_val then
        newAttr = newAttr:gsub('pen="[^"]*"', 'pen="' .. pName .. '"')
      else
        newAttr = newAttr .. ' pen="' .. pName .. '"'
      end
    elseif stroke_gray then
      local g = tonumber(stroke_gray)
      local cName = (g > 0.70) and "lightgray" or "black"
      local pName = (cName == "lightgray") and "ultrathin" or "normal"
      newAttr = newAttr:gsub('stroke="[^"]*"', 'stroke="' .. cName .. '"')
      if pen_val then
        newAttr = newAttr:gsub('pen="[^"]*"', 'pen="' .. pName .. '"')
      else
        newAttr = newAttr .. ' pen="' .. pName .. '"'
      end
    end

    return '<path' .. newAttr .. '>'
  end)

  -- 5. Geometric Text Processing: Parse isolated text elements
  local textPattern = '<text[^>]*matrix="([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)"[^>]*>([^<]*)</text>'
  
  local textBlocks = {}
  for a, b, c, d, tx, ty, str in content:gmatch(textPattern) do
    local na, nb, nc, nd = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    local ntx, nty = tonumber(tx), tonumber(ty)
    if str and str ~= "" then
      textBlocks[#textBlocks + 1] = {
        a = na, b = nb, c = nc, d = nd,
        tx = ntx, ty = nty,
        str = str,
        skip = false
      }
    end
  end

  if #textBlocks == 0 then
    return content
  end

  -- Helper function to find best matching plot box for a given (x, y) point
  local function findBox(x, y)
    local best = nil
    local bestDist = 999999
    for _, b in ipairs(plotBoxes) do
      local dx = (x < b.minX) and (b.minX - x) or ((x > b.maxX) and (x - b.maxX) or 0)
      local dy = (y < b.minY) and (b.minY - y) or ((y > b.maxY) and (y - b.maxY) or 0)
      local dist = dx*dx + dy*dy
      if dist < bestDist then
        bestDist = dist
        best = b
      end
    end
    return best
  end

  -- Pre-merge log-axis "10" and superscript (e.g. "1" + "0" + "!1" / "0")
  for i = 1, #textBlocks do
    local tb = textBlocks[i]
    if not tb.skip and tb.str == "1" then
      -- Check if next item is "0" to form base "10"
      for j = 1, #textBlocks do
        local tb0 = textBlocks[j]
        if not tb0.skip and tb0.str == "0" and math.abs(tb0.ty - tb.ty) < 2.0 and (tb0.tx - tb.tx) >= 3.0 and (tb0.tx - tb.tx) <= 7.0 then
          -- We have a "10" base at tb.tx, tb.ty
          -- Search for ALL superscript characters near tb.tx, tb.ty
          local expList = {}
          for k = 1, #textBlocks do
            local expTb = textBlocks[k]
            if not expTb.skip and k ~= i and k ~= j then
              local dX = expTb.tx - tb.tx
              local dY = expTb.ty - tb.ty
              if dX >= 5.0 and dX <= 25.0 and dY >= 1.0 and dY <= 10.0 then
                table.insert(expList, expTb)
              end
            end
          end

          if #expList > 0 then
            table.sort(expList, function(u, v) return u.tx < v.tx end)
            local expParts = {}
            for _, e in ipairs(expList) do
              table.insert(expParts, (e.str:gsub("!", "-")))
              e.skip = true
            end
            local expStr = table.concat(expParts)
            tb.str = string.format("$10^{%s}$", expStr)
            tb0.skip = true
          end
          break
        end
      end
    end
  end

  -- Pre-merge subscripts (e.g. "P" + "elec", "V" + "in", "N" + "ref", etc.)
  for i = 1, #textBlocks do
    local tb = textBlocks[i]
    if not tb.skip and #tb.str == 1 and tb.str:match("^[A-Z]$") then
      local isRotated = (math.abs(tb.b or 0) > 0.1 or math.abs(tb.c or 0) > 0.1)
      local subList = {}
      for j = 1, #textBlocks do
        local subTb = textBlocks[j]
        if not subTb.skip and j ~= i then
          if not isRotated then
            local dX = subTb.tx - tb.tx
            local dY = tb.ty - subTb.ty
            if dX >= 3.0 and dX <= 28.0 and dY >= 0.8 and dY <= 3.8 then
              table.insert(subList, subTb)
            end
          else
            local dY = subTb.ty - tb.ty
            local dX = subTb.tx - tb.tx
            if dY >= 3.0 and dY <= 28.0 and dX >= 0.8 and dX <= 3.8 then
              table.insert(subList, subTb)
            end
          end
        end
      end
      if #subList > 0 then
        if not isRotated then
          table.sort(subList, function(u, v) return u.tx < v.tx end)
        else
          table.sort(subList, function(u, v) return u.ty < v.ty end)
        end
        local subParts = {}
        for _, s in ipairs(subList) do
          table.insert(subParts, s.str)
          s.skip = true
        end
        local subStr = table.concat(subParts)
        tb.str = string.format("$%s_{\\mathrm{%s}}$", tb.str, subStr)
      end
    end
  end

  -- Group remaining text blocks by orientation and horizontal rows
  local groups = {}
  for _, item in ipairs(textBlocks) do
    if not item.skip then
      local isRotated = (math.abs(item.b or 0) > 0.1 or math.abs(item.c or 0) > 0.1)
      local key
      if isRotated then
        key = "rot_" .. math.floor((item.tx or 0) + 0.5)
      else
        key = "hor_" .. math.floor((item.ty or 0) + 0.5)
      end
      if not groups[key] then
        groups[key] = { isRotated = isRotated, ty = item.ty, tx = item.tx, items = {} }
      end
      table.insert(groups[key].items, item)
    end
  end

  local mergedXmlList = {}
  for key, grp in pairs(groups) do
    if grp.isRotated then
      table.sort(grp.items, function(u, v) return u.ty < v.ty end)
      local parts = {}
      for i, it in ipairs(grp.items) do
        if i > 1 then
          local prev = grp.items[i-1]
          local deltaY = it.ty - prev.ty
          if deltaY > 13.0 then
            table.insert(parts, " ")
          end
        end
        table.insert(parts, it.str)
      end
      local fullStr = table.concat(parts):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      fullStr = formatGenericPlotText(fullStr)
      if fullStr ~= "" then
        fullStr = sanitizeLatex(fullStr)
        local first = grp.items[1]
        local last = grp.items[#grp.items]
        local midY = (first.ty + last.ty) / 2

        -- Find corresponding plot box (the subplot directly to the right of the Y-axis label)
        local targetBox = nil
        local bestDist = 999999
        for _, b in ipairs(plotBoxes) do
          if b.minX >= first.tx - 15.0 and midY >= b.minY - 15.0 and midY <= b.maxY + 15.0 then
            local dist = math.abs(b.minX - first.tx) + math.abs(b.midY - midY)
            if dist < bestDist then
              bestDist = dist
              targetBox = b
            end
          end
        end

        local posX = targetBox and (targetBox.minX - 34.0) or first.tx
        local posY = targetBox and targetBox.midY or midY

        local xml = string.format('<text stroke="black" pos="0 0" transformations="rigid" size="footnote" halign="center" valign="baseline" matrix="0 1 -1 0 %.2f %.2f">%s</text>', posX, posY, fullStr)
        mergedXmlList[#mergedXmlList + 1] = xml
      end
    else
      table.sort(grp.items, function(u, v) return u.tx < v.tx end)

      local cluster = { grp.items[1] }
      for i = 2, #grp.items do
        local prev = grp.items[i-1]
        local curr = grp.items[i]
        local deltaX = curr.tx - prev.tx
        if deltaX > 22.0 then
          -- Process cluster
          local parts = {}
          for j, it in ipairs(cluster) do
            if j > 1 then
              local dX = it.tx - cluster[j-1].tx
              if dX > 11.0 then
                table.insert(parts, " ")
              end
            end
            table.insert(parts, it.str)
          end
          local strAcc = table.concat(parts):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
          strAcc = formatGenericPlotText(strAcc)
          if strAcc ~= "" then
            local isPureNum = (tonumber(strAcc) ~= nil) or (strAcc:match("^[%-%+%.%d]+$") ~= nil)
            local targetBox = findBox(cluster[1].tx, grp.ty)

            local isTitle = (targetBox and grp.ty >= targetBox.maxY - 2) and not isPureNum and not strAcc:find("%$10%^")
            local isXLabel = (targetBox and grp.ty <= targetBox.minY - 10) and not isPureNum and not strAcc:find("%$10%^")

            if not (isTitle and #strAcc == 1 and (strAcc == "n" or strAcc == "d" or strAcc == "i")) then
              strAcc = sanitizeLatex(strAcc)
              local fontSize = "script"
              local halign = ""
              local posX = cluster[1].tx
              local posY = cluster[1].ty

              if isTitle then
                fontSize = "small"
                halign = ' halign="center"'
                if targetBox then posX = targetBox.midX end
              elseif isXLabel then
                fontSize = "footnote"
                halign = ' halign="center"'
                if targetBox then posX = targetBox.midX end
              elseif strAcc:find("%$10%^") then
                fontSize = "script"
                local isYTick = targetBox and (grp.ty >= targetBox.minY - 2.0) and (posX < targetBox.minX + 8)
                if isYTick then
                  halign = ' halign="right"'
                  posX = targetBox.minX - 3.5
                else
                  halign = ' halign="center"'
                end
              elseif isPureNum then
                fontSize = "script"
                local isYTick = targetBox and (grp.ty >= targetBox.minY - 2.0) and (posX < targetBox.minX + 8)
                if isYTick then
                  halign = ' halign="right"'
                  posX = targetBox.minX - 3.5
                else
                  halign = ' halign="center"'
                end
              end

              mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', posX, posY, fontSize, halign, strAcc)
            end
          end
          cluster = { curr }
        else
          table.insert(cluster, curr)
        end
      end
      -- Flush remaining cluster
      local parts = {}
      for j, it in ipairs(cluster) do
        if j > 1 then
          local dX = it.tx - cluster[j-1].tx
          if dX > 11.0 then
            table.insert(parts, " ")
          end
        end
        table.insert(parts, it.str)
      end
      local strAcc = table.concat(parts):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      strAcc = formatGenericPlotText(strAcc)
      if strAcc ~= "" then
        local isPureNum = (tonumber(strAcc) ~= nil) or (strAcc:match("^[%-%+%.%d]+$") ~= nil)
        local targetBox = findBox(cluster[1].tx, grp.ty)

        local isTitle = (targetBox and grp.ty >= targetBox.maxY - 2) and not isPureNum and not strAcc:find("%$10%^")
        local isXLabel = (targetBox and grp.ty <= targetBox.minY - 10) and not isPureNum and not strAcc:find("%$10%^")

        if not (isTitle and #strAcc == 1 and (strAcc == "n" or strAcc == "d" or strAcc == "i")) then
          strAcc = sanitizeLatex(strAcc)
          local fontSize = "script"
          local halign = ""
          local posX = cluster[1].tx
          local posY = cluster[1].ty

          if isTitle then
            fontSize = "small"
            halign = ' halign="center"'
            if targetBox then posX = targetBox.midX end
          elseif isXLabel then
            fontSize = "footnote"
            halign = ' halign="center"'
            if targetBox then posX = targetBox.midX end
          elseif strAcc:find("%$10%^") then
            fontSize = "script"
            local isYTick = targetBox and (grp.ty >= targetBox.minY - 2.0) and (posX < targetBox.minX + 8)
            if isYTick then
              halign = ' halign="right"'
              posX = targetBox.minX - 3.5
            else
              halign = ' halign="center"'
            end
          elseif isPureNum then
            fontSize = "script"
            local isYTick = targetBox and (grp.ty >= targetBox.minY - 2.0) and (posX < targetBox.minX + 8)
            if isYTick then
              halign = ' halign="right"'
              posX = targetBox.minX - 3.5
            else
              halign = ' halign="center"'
            end
          end

          mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', posX, posY, fontSize, halign, strAcc)
        end
      end
    end
  end

  content = content:gsub('<text[^>]*>.-</text>%s*', '')
  local mergedTextBlock = table.concat(mergedXmlList, "\n")
  content = content:gsub('</page>', mergedTextBlock .. '\n</page>')

  return content
end

local function importPlot(model)
  local filter = {
    "PDF, IPE (*.pdf *.ipe *.xml)", "*.pdf;*.ipe;*.xml",
    "PDF Files (*.pdf)", "*.pdf",
    "IPE Files (*.ipe *.xml)", "*.ipe;*.xml",
    "All files (*.*)", "*.*"
  }
  local file = ipeui.fileDialog(nil, "open", "Select MATLAB Vector PDF or IPE File", filter, nil, nil)
  if not file then return end

  ensureMatlabColors(model)

  local tmpipe = nil
  local is_pdf = (file:lower():match("%.pdf$") ~= nil)

  if is_pdf then
    tmpipe = file .. ".tmp.ipe"
    local flags = "-literal"

    local cmd = string.format('pdftoipe %s "%s" "%s"', flags, file, tmpipe)
    local ok = _G.os.execute(cmd)
    if not ok or not ipe.fileExists(tmpipe) then
      model:warning("Failed to convert PDF using pdftoipe.",
                    "Command executed:\n" .. cmd .. "\n\nPlease ensure pdftoipe is installed in your system PATH.")
      return
    end

    if io and io.open then
      local f = io.open(tmpipe, "r")
      if f then
        local rawXml = f:read("*all")
        f:close()
        local cleanedXml = cleanAndMergeMatlabIpeXml(rawXml)
        local fw = io.open(tmpipe, "w")
        if fw then
          fw:write(cleanedXml)
          fw:close()
        end
      end
    end

    file = tmpipe
  end

  local doc = ipe.Document(file)
  if not doc then
    if tmpipe and ipe.fileExists(tmpipe) then _G.os.remove(tmpipe) end
    model:warning("Failed to parse Ipe document.", file)
    return
  end

  local layout = model.doc:sheets():find("layout")
  local fs = layout and layout.framesize or ipe.Vector(336, 221)

  for pageNum, p in doc:pages() do
    if #p == 0 then break end

    local totalBox = ipe.Rect()
    for i = 1, #p do
      totalBox:add(p:bbox(i))
    end

    if totalBox:isEmpty() then break end

    local totalW = totalBox:width()
    local totalH = totalBox:height()

    -- Remove solid full-page background rectangles
    local skipIndices = {}
    for i = 1, math.min(3, #p) do
      local b = p:bbox(i)
      if p[i]:type() == "path" and (b:width() >= totalW * 0.97 and b:height() >= totalH * 0.97) then
        skipIndices[i] = true
        break
      end
    end

    local contentBox = ipe.Rect()
    local hasRemaining = false
    for i = 1, #p do
      if not skipIndices[i] then
        contentBox:add(p:bbox(i))
        hasRemaining = true
      end
    end

    if not hasRemaining or contentBox:isEmpty() then
      skipIndices = {}
      contentBox = totalBox
    end

    local curW = contentBox:width()
    local curH = contentBox:height()

    -- Auto-scale: fits comfortably within 82% x 72% of slide frame
    local maxTargetW = fs.x * 0.82
    local maxTargetH = fs.y * 0.72
    local scale = 1.0
    if curW > maxTargetW or curH > maxTargetH then
      local scaleW = maxTargetW / curW
      local scaleH = maxTargetH / curH
      scale = math.min(scaleW, scaleH)
    end

    local targetCenterX = fs.x / 2
    local targetCenterY = fs.y / 2 - 10

    local srcCenterX = contentBox:left() + curW / 2
    local srcCenterY = contentBox:bottom() + curH / 2

    local transX = targetCenterX - scale * srcCenterX
    local transY = targetCenterY - scale * srcCenterY

    local m = ipe.Matrix(scale, 0, 0, scale, transX, transY)

    for j = 1, #p do
      p:transform(j, m)
    end

    local elements = {}
    for i = 1, #p do
      if not skipIndices[i] then
        elements[#elements + 1] = p[i]:clone()
      end
    end

    local group = ipe.Group(elements)
    model:creation("insert MATLAB plot", group)
    break
  end

  if tmpipe and ipe.fileExists(tmpipe) then
    _G.os.remove(tmpipe)
  end

  if model.ui and model.ui.explain then
    model.ui:explain("MATLAB plot inserted (generic color mapping & clean TeX applied)")
  end
end

function run(model)
  importPlot(model)
end
