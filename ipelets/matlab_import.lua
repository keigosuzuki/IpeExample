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

  -- 2. Normalize and map paths (strokes, fills, pens) generically
  content = content:gsub('<path([^>]*)>', function(attr)
    local fill_r, fill_g, fill_b = attr:match('fill="([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)"')
    local fill_gray = attr:match('fill="([%d%.]+)"')
    local stroke_r, stroke_g, stroke_b = attr:match('stroke="([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)"')
    local stroke_gray = attr:match('stroke="([%d%.]+)"')
    local pen_val = attr:match('pen="([%d%.]+)"')

    local newAttr = attr

    -- Generic Fill Mapping
    if fill_r and fill_g and fill_b then
      local cName = matchColor(tonumber(fill_r), tonumber(fill_g), tonumber(fill_b))
      if cName == "lightgray" or cName == "white" then
        newAttr = newAttr:gsub('fill="[^"]*"', 'fill="' .. cName .. '"')
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

  -- 3. Geometric Text Processing: Cluster glyphs, restore spaces, detect superscript log-axes
  local textPattern = '<text[^>]*matrix="([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)%s+([%-%d%.]+)"[^>]*>([^<]*)</text>'
  
  local textBlocks = {}
  local maxY = -99999
  local minY = 99999
  for a, b, c, d, tx, ty, str in content:gmatch(textPattern) do
    local na, nb, nc, nd = tonumber(a), tonumber(b), tonumber(c), tonumber(d)
    local ntx, nty = tonumber(tx), tonumber(ty)
    if str and str ~= "" then
      textBlocks[#textBlocks + 1] = {
        a = na, b = nb, c = nc, d = nd,
        tx = ntx, ty = nty,
        str = str
      }
      if nty > maxY then maxY = nty end
      if nty < minY then minY = nty end
    end
  end

  if #textBlocks == 0 then
    return content
  end

  local groups = {}
  for _, item in ipairs(textBlocks) do
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

  local mergedXmlList = {}
  for key, grp in pairs(groups) do
    if grp.isRotated then
      table.sort(grp.items, function(u, v) return u.ty < v.ty end)
      local parts = {}
      for i, it in ipairs(grp.items) do
        if i > 1 then
          local prev = grp.items[i-1]
          local deltaY = it.ty - prev.ty
          -- Add space only when distance between characters clearly indicates a word gap (>13.0 pt)
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
        local posX = first.tx - 18.0 -- Move sufficiently left to prevent overlapping tick numbers
        local xml = string.format('<text stroke="black" pos="0 0" transformations="rigid" size="footnote" halign="center" valign="baseline" matrix="0 1 -1 0 %.2f %.2f">%s</text>', posX, midY, fullStr)
        mergedXmlList[#mergedXmlList + 1] = xml
      end
    else
      table.sort(grp.items, function(u, v) return u.tx < v.tx end)
      
      local isTitle = (grp.ty >= maxY - 8)
      local isXLabel = (grp.ty <= minY + 8)

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
            -- Filter out isolated single letter artifacts near title (e.g. leftover subscript "n" from \omega_n)
            if not (isTitle and #strAcc == 1 and (strAcc == "n" or strAcc == "d" or strAcc == "i")) then
              strAcc = sanitizeLatex(strAcc)
              local fontSize = "script"
              local halign = ""
              if isTitle then
                fontSize = "small"
                halign = ' halign="center"'
              elseif isXLabel or strAcc:find("%[") or strAcc:find("%$") then
                fontSize = "footnote"
                halign = ' halign="center"'
              elseif tonumber(strAcc) or strAcc:match("^[%-%+%.%d]+$") then
                halign = ' halign="right"'
              end
              mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, halign, strAcc)
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
        -- Filter out isolated single letter artifacts near title (e.g. leftover subscript "n" from \omega_n)
        if not (isTitle and #strAcc == 1 and (strAcc == "n" or strAcc == "d" or strAcc == "i")) then
          strAcc = sanitizeLatex(strAcc)
          local fontSize = "script"
          local halign = ""
          if isTitle then
            fontSize = "small"
            halign = ' halign="center"'
          elseif isXLabel or strAcc:find("%[") or strAcc:find("%$") then
            fontSize = "footnote"
            halign = ' halign="center"'
          elseif tonumber(strAcc) or strAcc:match("^[%-%+%.%d]+$") then
            halign = ' halign="right"'
          end
          mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, halign, strAcc)
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
