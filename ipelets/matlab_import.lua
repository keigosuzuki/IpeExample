----------------------------------------------------------------------
-- MATLAB Plot Importer ipelet for Ipe
----------------------------------------------------------------------
--
-- Features:
-- 1. Automatically cleans and fixes MATLAB vector graphics:
--    - Converts dark opaque grid lines to subtle light gray lines.
--    - Maps MATLAB RGB curve colors to symbolic colors in color_matlab.isy
--      (matlab_blue, matlab_red, matlab_orange, etc.) with pen="heavier".
--    - Fixes axis borders and ticks to clean black.
--    - Strips the opaque full-page background rectangle so slide
--      background templates remain intact.
-- 2. Smart text merging & true-size LaTeX typography:
--    - Text uses transformations="translations" so font size is never
--      shrunk by affine scaling (Title: large, Axis: normal, Ticks/Legend: small).
--    - Automatically restores broken Greek math formulas (e.g. \zeta).
--    - Fixes rotated Y-axis labels.
-- 3. Ensures the MATLAB color palette (color_matlab.isy) is attached.
-- 4. Interactive Import Dialog for scale mode & options.
--
----------------------------------------------------------------------

local _G = _G
local io = _G.io or io
local os = _G.os or os

label = "Insert MATLAB Plot"

about = [[
Seamlessly import MATLAB vector plots (PDF/IPE) into your Ipe document
or slide. Automatically attaches the MATLAB color palette, preserves
proper LaTeX text sizes (normal/large/small), and cleans grid lines.
]]

-- Sibling "styles" directory from this ipelet's path
local function styleDir()
  local ipeletDir = (path and path:match("^(.*)[/\\][^/\\]+$")) or "."
  local repoRoot = ipeletDir:match("^(.*)[/\\][^/\\]+$") or ipeletDir
  return repoRoot .. "/styles"
end

-- Ensure color_matlab.isy is attached to the current document
local function ensureMatlabColors(model)
  local doc = model.doc
  local sheets = doc:sheets()
  for i = 1, sheets:count() do
    if sheets:sheet(i):name() == "color_matlab" then
      return true -- Already attached
    end
  end

  local sheetPath = styleDir() .. "/color_matlab.isy"
  local sheet = ipe.Sheet(sheetPath)
  if not sheet then
    model:warning("Could not find style sheet", sheetPath)
    return false
  end

  local t = { label = "attach MATLAB color palette", model = model, style_sheets_changed = true }
  t.redo = function(t, d)
    d:sheets():insert(1, sheet:clone())
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
  model:runLatex()
  return true
end

-- Parse and clean MATLAB-generated IPE XML
local function cleanAndMergeMatlabIpeXml(content, discardText)
  -- 1. Replace gray/black grid line art with light gray pen
  content = content:gsub('stroke="0%.15 0%.15 0%.15"([^>]*)pen="0%.5"', 'stroke="0.85 0.85 0.85"%1pen="ultrathin"')
  content = content:gsub('stroke="0%.2 0%.2 0%.2"([^>]*)pen="0%.5"', 'stroke="0.85 0.85 0.85"%1pen="ultrathin"')
  content = content:gsub('stroke="black"([^>]*)pen="0%.5"', 'stroke="0.85 0.85 0.85"%1pen="ultrathin"')
  content = content:gsub('stroke="0%.15 0%.15 0%.15"', 'stroke="black"')

  -- 2. Map standard MATLAB RGB colors to symbolic color names
  local colorMap = {
    ['0 0%.447 0%.741'] = 'matlab_blue',
    ['0%.85 0%.325 0%.098'] = 'matlab_red',
    ['0%.929 0%.694 0%.125'] = 'matlab_yellow',
    ['0%.494 0%.184 0%.556'] = 'matlab_purple',
    ['0%.466 0%.674 0%.188'] = 'matlab_green',
    ['0%.301 0%.745 0%.933'] = 'matlab_cyan',
    ['0%.635 0%.078 0%.184'] = 'matlab_darkred',
  }

  for rgbPattern, symColor in pairs(colorMap) do
    content = content:gsub('stroke="' .. rgbPattern .. '"', 'stroke="' .. symColor .. '" pen="heavier"')
    content = content:gsub('fill="' .. rgbPattern .. '"', 'fill="' .. symColor .. '"')
  end

  if discardText then
    content = content:gsub('<text[^>]*>.-</text>%s*', '')
    return content
  end

  -- 3. Extract and cluster fragmented text objects
  local rawTexts = {}
  local minY, maxY = 1e9, -1e9
  local minX, maxX = 1e9, -1e9

  for stroke, pos, mat, size, val, str in content:gmatch('<text stroke="([^"]*)" pos="([^"]*)"%s*([^>]*)size="([^"]*)"[^>]*>([^<]*)</text>') do
    local px, py = pos:match("([%+%-%d%.]+)%s+([%+%-%d%.]+)")
    px = tonumber(px) or 0
    py = tonumber(py) or 0

    local m1, m2, m3, m4, tx, ty = mat:match('matrix="([%+%-%d%.]+)%s+([%+%-%d%.]+)%s+([%+%-%d%.]+)%s+([%+%-%d%.]+)%s+([%+%-%d%.]+)%s+([%+%-%d%.]+)"')
    if tx and ty then
      tx = tonumber(tx) + px
      ty = tonumber(ty) + py
    else
      tx = px
      ty = py
    end

    if tx < minX then minX = tx end
    if tx > maxX then maxX = tx end
    if ty < minY then minY = ty end
    if ty > maxY then maxY = ty end

    local isRotated = false
    if m1 and (math.abs(tonumber(m1)) < 0.1 and math.abs(tonumber(m2) or 0) > 0.8) then
      isRotated = true
    end

    rawTexts[#rawTexts + 1] = {
      str = str,
      tx = tx,
      ty = ty,
      isRotated = isRotated,
      size = size,
    }
  end

  if #rawTexts == 0 then
    return content
  end

  -- Group texts by horizontal line (Y-coord threshold 4pt)
  local yGroups = {}
  for _, item in ipairs(rawTexts) do
    local foundGroup = false
    for _, grp in ipairs(yGroups) do
      if not item.isRotated and not grp.isRotated and math.abs(grp.ty - item.ty) < 4.0 then
        table.insert(grp.items, item)
        foundGroup = true
        break
      elseif item.isRotated and grp.isRotated and math.abs(grp.tx - item.tx) < 4.0 then
        table.insert(grp.items, item)
        foundGroup = true
        break
      end
    end
    if not foundGroup then
      table.insert(yGroups, { ty = item.ty, tx = item.tx, isRotated = item.isRotated, items = { item } })
    end
  end

  local mergedXmlList = {}
  for _, grp in ipairs(yGroups) do
    if grp.isRotated then
      table.sort(grp.items, function(u, v) return u.ty < v.ty end)
      local fullStr = ""
      for _, it in ipairs(grp.items) do fullStr = fullStr .. it.str end
      fullStr = fullStr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if fullStr ~= "" then
        local first = grp.items[1]
        local last = grp.items[#grp.items]
        local midY = (first.ty + last.ty) / 2
        local xml = string.format('<text stroke="black" pos="0 0" transformations="affine" size="normal" valign="baseline" matrix="0 1 -1 0 %.2f %.2f">%s</text>', first.tx, midY - 20, fullStr)
        mergedXmlList[#mergedXmlList + 1] = xml
      end
    else
      table.sort(grp.items, function(u, v) return u.tx < v.tx end)
      
      local isTitle = (grp.ty >= maxY - 5)
      local isXLabel = (grp.ty <= minY + 5)

      local cluster = { grp.items[1] }
      for i = 2, #grp.items do
        local prev = grp.items[i-1]
        local curr = grp.items[i]
        if (curr.tx - prev.tx) > 20 then
          local strAcc = ""
          for _, it in ipairs(cluster) do strAcc = strAcc .. it.str end
          strAcc = strAcc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
          strAcc = strAcc:gsub("1%s*=%s*", "$\\zeta = $")
          if strAcc ~= "" then
            local fontSize = "small"
            if isTitle then fontSize = "large"
            elseif isXLabel then fontSize = "normal"
            end
            mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s" valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, strAcc)
          end
          cluster = { curr }
        else
          table.insert(cluster, curr)
        end
      end
      -- Flush remaining cluster
      local strAcc = ""
      for _, it in ipairs(cluster) do strAcc = strAcc .. it.str end
      strAcc = strAcc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      strAcc = strAcc:gsub("1%s*=%s*", "$\\zeta = $")
      if strAcc ~= "" then
        local fontSize = "small"
        if isTitle then fontSize = "large"
        elseif isXLabel then fontSize = "normal"
        end
        mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s" valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, strAcc)
      end
    end
  end

  content = content:gsub('<text[^>]*>.-</text>%s*', '')
  local mergedTextBlock = table.concat(mergedXmlList, "\n")
  content = content:gsub('</page>', mergedTextBlock .. '\n</page>')

  return content
end

local function importPlot(model)
  local win = (model.ui and model.ui.win and model.ui:win()) or nil
  local filter = {
    "PDF, IPE (*.pdf *.ipe *.xml)", "*.pdf;*.ipe;*.xml",
    "PDF Files (*.pdf)", "*.pdf",
    "IPE Files (*.ipe *.xml)", "*.ipe;*.xml",
    "All files (*.*)", "*.*"
  }
  local file = ipeui.fileDialog(win, "open", "Select MATLAB Vector PDF or IPE File", filter, nil, nil)
  if not file then return end

  -- Show Options Dialog
  local d = ipeui.Dialog(win, "MATLAB Plot Import Options")
  d:add("lbl1", "label", { label = "Import Scale / Placement Mode:" }, 1, 1)
  local modeOptions = { "Original 1:1 Size (Recommended)", "Auto-Fit to Slide Frame", "Clean Line Art Only (Discard Text)" }
  d:add("mode", "combo", modeOptions, 2, 1)
  d:add("attach_colors", "checkbox", { label = "Ensure MATLAB color palette attached (color_matlab.isy)" }, 3, 1)
  d:set("attach_colors", true)
  d:addButton("ok", "&Import", "accept")
  d:addButton("cancel", "&Cancel", "reject")
  if not d:execute() then return end

  local modeIdx = d:get("mode")
  local scaleMode = (modeIdx == 2 and "fit") or "original"
  local discardText = (modeIdx == 3)
  local doAttachColors = d:get("attach_colors")

  if doAttachColors then
    ensureMatlabColors(model)
  end

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
        local cleanedXml = cleanAndMergeMatlabIpeXml(rawXml, discardText)
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
  local fs = layout and layout.framesize or ipe.Vector(400, 300)

  for pageNum, p in doc:pages() do
    if #p == 0 then break end

    local totalBox = ipe.Rect()
    for i = 1, #p do
      totalBox:add(p:bbox(i))
    end

    if totalBox:isEmpty() then break end

    local totalW = totalBox:width()
    local totalH = totalBox:height()

    -- Remove full-page background rectangles
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

    local scale = 1.0
    if scaleMode == "fit" then
      local maxTargetW = fs.x * 0.65
      local maxTargetH = fs.y * 0.70
      if curW > maxTargetW or curH > maxTargetH then
        local scaleW = maxTargetW / curW
        local scaleH = maxTargetH / curH
        scale = math.min(scaleW, scaleH)
      end
    else
      scale = 1.0
    end

    local targetCenterX = fs.x / 2
    local targetCenterY = fs.y / 2

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
    model.ui:explain("MATLAB plot inserted (true-size LaTeX fonts & clean grid applied)")
  end
end

function run(model)
  importPlot(model)
end
