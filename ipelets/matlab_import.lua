----------------------------------------------------------------------
-- MATLAB Plot Importer ipelet for Ipe
----------------------------------------------------------------------
--
-- Features:
-- 1. Seamlessly imports MATLAB vector plots (PDF / IPE):
--    - Supports both transparent background PDFs (from export_ipe_plot)
--      and traditional white-background PDFs.
--    - Converts grid lines to light subtle gray (fill="0.88 0.88 0.88").
--    - Maps MATLAB RGB curve colors to symbolic colors in color_matlab.isy
--      (matlab_blue, matlab_red, matlab_orange, matlab_purple, etc.).
-- 2. Smart LaTeX Typography & Alignment:
--    - Merges fragmented letter sequences into coherent LaTeX text.
--    - Preserves true font sizes using transformations="translations".
--    - Automatically sets halign="right" on Y-axis tick numbers.
--    - Rotates Y-axis labels with transformations="rigid" and halign="center".
-- 3. Automatically attaches MATLAB color palette (color_matlab.isy).
-- 4. Instant one-click import with auto-fit centering.
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

local function cleanAndMergeMatlabIpeXml(content)
  -- 1. Remove full-page solid background if present
  content = content:gsub('<path fill="1%.0+ 1%.0+ 1%.0+">\n%s*[%-%d%.]+%s+[%-%d%.]+%s+m\n.-h\n%s*</path>', function(p)
    if p:find("%-1%.05") or p:find("369%.45") or p:find("0%.73") then
      return ""
    end
    return p
  end, 1)

  -- 2. Clean Grid lines: convert dark opaque 0.129410 fill to light gray
  content = content:gsub('fill="0%.12941%d+ 0%.12941%d+ 0%.12941%d+" fillrule="wind"', 'fill="0.88 0.88 0.88" fillrule="wind"')
  content = content:gsub('fill="0%.12941%d+ 0%.12941%d+ 0%.12941%d+"', 'fill="0.88 0.88 0.88"')

  -- 3. Map MATLAB standard 7 RGB curve colors to named symbolic colors
  content = content:gsub('stroke="0%.0+ 0%.44[67]%d* 0%.74%d+" pen="[^"]*"', 'stroke="matlab_blue" pen="heavier"')
  content = content:gsub('stroke="0%.0+ 0%.44[67]%d* 0%.74%d+"', 'stroke="matlab_blue" pen="heavier"')
  content = content:gsub('stroke="0%.85%d+ 0%.32%d+ 0%.09[89]%d*" pen="[^"]*"', 'stroke="matlab_red" pen="heavier"')
  content = content:gsub('stroke="0%.85%d+ 0%.32%d+ 0%.09[89]%d*"', 'stroke="matlab_red" pen="heavier"')
  content = content:gsub('stroke="0%.92%d+ 0%.69%d+ 0%.12%d+" pen="[^"]*"', 'stroke="matlab_orange" pen="heavier"')
  content = content:gsub('stroke="0%.92%d+ 0%.69%d+ 0%.12%d+"', 'stroke="matlab_orange" pen="heavier"')
  content = content:gsub('stroke="0%.49%d+ 0%.18%d+ 0%.55%d+" pen="[^"]*"', 'stroke="matlab_purple" pen="heavier"')
  content = content:gsub('stroke="0%.49%d+ 0%.18%d+ 0%.55%d+"', 'stroke="matlab_purple" pen="heavier"')
  content = content:gsub('stroke="0%.46%d+ 0%.67%d+ 0%.18%d+" pen="[^"]*"', 'stroke="matlab_green" pen="heavier"')
  content = content:gsub('stroke="0%.46%d+ 0%.67%d+ 0%.18%d+"', 'stroke="matlab_green" pen="heavier"')
  content = content:gsub('stroke="0%.30%d+ 0%.74%d+ 0%.93%d+" pen="[^"]*"', 'stroke="matlab_cyan" pen="heavier"')
  content = content:gsub('stroke="0%.30%d+ 0%.74%d+ 0%.93%d+"', 'stroke="matlab_cyan" pen="heavier"')
  content = content:gsub('stroke="0%.63%d+ 0%.07%d+ 0%.18%d+" pen="[^"]*"', 'stroke="matlab_brown" pen="heavier"')
  content = content:gsub('stroke="0%.63%d+ 0%.07%d+ 0%.18%d+"', 'stroke="matlab_brown" pen="heavier"')

  -- 4. Box borders and ticks
  content = content:gsub('stroke="0%.12941%d+ 0%.12941%d+ 0%.12941%d+" pen="[^"]*"', 'stroke="black" pen="normal"')
  content = content:gsub('stroke="0%.12941%d+ 0%.12941%d+ 0%.12941%d+"', 'stroke="black"')

  -- 5. Text processing: Parse isolated text elements and merge them
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
      local fullStr = ""
      for _, it in ipairs(grp.items) do
        if it.str then fullStr = fullStr .. it.str end
      end
      fullStr = fullStr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if fullStr ~= "" then
        local first = grp.items[1]
        local last = grp.items[#grp.items]
        local midY = (first.ty + last.ty) / 2
        local xml = string.format('<text stroke="black" pos="0 0" transformations="rigid" size="footnote" halign="center" valign="baseline" matrix="0 1 -1 0 %.2f %.2f">%s</text>', first.tx, midY, fullStr)
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
        if (curr.tx - prev.tx) > 25 then
          local strAcc = ""
          for _, it in ipairs(cluster) do
            if it.str then strAcc = strAcc .. it.str end
          end
          strAcc = strAcc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
          strAcc = strAcc:gsub("1%s*=%s*", "$\\zeta = $")
          if strAcc ~= "" then
            local fontSize = "script"
            local halign = ""
            if isTitle then
              fontSize = "small"
              halign = ' halign="center"'
            elseif isXLabel then
              fontSize = "footnote"
              halign = ' halign="center"'
            elseif tonumber(strAcc) or strAcc:match("^[%-%+%.%d]+$") then
              halign = ' halign="right"'
            end
            mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, halign, strAcc)
          end
          cluster = { curr }
        else
          table.insert(cluster, curr)
        end
      end
      -- Flush remaining cluster
      local strAcc = ""
      for _, it in ipairs(cluster) do
        if it.str then strAcc = strAcc .. it.str end
      end
      strAcc = strAcc:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      strAcc = strAcc:gsub("1%s*=%s*", "$\\zeta = $")
      if strAcc ~= "" then
        local fontSize = "script"
        local halign = ""
        if isTitle then
          fontSize = "small"
          halign = ' halign="center"'
        elseif isXLabel then
          fontSize = "footnote"
          halign = ' halign="center"'
        elseif tonumber(strAcc) or strAcc:match("^[%-%+%.%d]+$") then
          halign = ' halign="right"'
        end
        mergedXmlList[#mergedXmlList + 1] = string.format('<text stroke="black" pos="%.2f %.2f" transformations="translations" size="%s"%s valign="baseline">%s</text>', cluster[1].tx, cluster[1].ty, fontSize, halign, strAcc)
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

    -- Auto-scale: fits comfortably within 80% of slide frame
    local maxTargetW = fs.x * 0.82
    local maxTargetH = fs.y * 0.72
    local scale = 1.0
    if curW > maxTargetW or curH > maxTargetH then
      local scaleW = maxTargetW / curW
      local scaleH = maxTargetH / curH
      scale = math.min(scaleW, scaleH)
    end

    local targetCenterX = fs.x / 2
    local targetCenterY = fs.y / 2 - 10 -- slightly lower to leave room for title/bullets

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
