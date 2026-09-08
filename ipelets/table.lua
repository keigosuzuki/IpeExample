----------------------------------------------------------------------
-- table ipelet (TeX Table Generator)
----------------------------------------------------------------------
--
-- Inserts a beautifully formatted LaTeX tabular table into the Ipe
-- canvas. Supports academic 3-line table templates, custom row/column
-- grids, and automatic conversion from Excel/TSV/CSV/Markdown.
----------------------------------------------------------------------

label = "Table"

about = [[
Insert a LaTeX tabular table into Ipe.
Includes academic 3-line table templates, custom row/col grid generation,
and automatic conversion from TSV, CSV, or Markdown.
]]

local V = ipe.Vector

local DEFAULT_TEMPLATE = [[\begin{tabular}{ccc}
\hline\hline
Item & Parameter & Value \\
\hline
A & $x_1$ & 10.5 \\
B & $x_2$ & 20.3 \\
\hline\hline
\end{tabular}]]

local function generateGridTabular(rows, cols, align)
  rows = tonumber(rows) or 3
  cols = tonumber(cols) or 3
  align = align or "c"
  if rows < 1 then rows = 1 end
  if cols < 1 then cols = 1 end

  local colAlign = string.rep(align, cols)
  local res = "\\begin{tabular}{" .. colAlign .. "}\n\\hline\\hline\n"
  for r = 1, rows do
    local cells = {}
    for c = 1, cols do
      if r == 1 then
        cells[#cells + 1] = "Header " .. c
      else
        cells[#cells + 1] = string.format("Cell %d,%d", r, c)
      end
    end
    res = res .. table.concat(cells, " & ") .. " \\\\\n"
    if r == 1 then
      res = res .. "\\hline\n"
    end
  end
  res = res .. "\\hline\\hline\n\\end{tabular}"
  return res
end

local function tsvToTabular(text)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do
    if line:match("%S") then
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then return nil end

  local rows = {}
  local maxCols = 0
  for _, line in ipairs(lines) do
    local cells = {}
    if line:match("|") then
      for c in line:gmatch("[^|]+") do
        local cell = c:match("^%s*(.-)%s*$")
        if not cell:match("^%:?%-+%:?$") and #cell > 0 then
          cells[#cells + 1] = cell
        end
      end
    elseif line:match("\t") then
      for c in line:gmatch("[^\t]+") do
        cells[#cells + 1] = c:match("^%s*(.-)%s*$")
      end
    elseif line:match(",") then
      for c in line:gmatch("[^,]+") do
        cells[#cells + 1] = c:match("^%s*(.-)%s*$")
      end
    else
      for c in line:gmatch("%S+") do
        cells[#cells + 1] = c
      end
    end
    if #cells > 0 then
      rows[#rows + 1] = cells
      if #cells > maxCols then maxCols = #cells end
    end
  end

  if #rows == 0 or maxCols == 0 then return nil end

  local colAlign = string.rep("c", maxCols)
  local res = "\\begin{tabular}{" .. colAlign .. "}\n\\hline\\hline\n"
  for rIdx, row in ipairs(rows) do
    local rowCells = {}
    for cIdx = 1, maxCols do
      rowCells[#rowCells + 1] = row[cIdx] or ""
    end
    res = res .. table.concat(rowCells, " & ") .. " \\\\\n"
    if rIdx == 1 then
      res = res .. "\\hline\n"
    end
  end
  res = res .. "\\hline\\hline\n\\end{tabular}"
  return res
end

local function insertTeXTable(model)
  local d = ipeui.Dialog(model.ui:win(), "Insert TeX Table")
  local presets = {
    "Academic 3-Line Table (Template)",
    "Custom Grid (3 Rows x 3 Cols)",
    "Custom Grid (4 Rows x 4 Cols)",
    "Paste TSV / CSV / Markdown / LaTeX",
  }
  d:add("lbl1", "label", { label = "Select Preset or enter/paste Table Data:" }, 1, 1, 1, 4)
  d:add("preset", "combo", presets, 2, 1, 1, 4)
  d:add("table_text", "text", {
    syntax = "latex",
    focus = true,
  }, 3, 1, 1, 4)
  d:set("table_text", DEFAULT_TEMPLATE)

  d:add("lbl2", "label", { label = "Font Size:" }, 4, 1)
  local sizes = { "small", "footnote", "normal", "large", "script", "tiny" }
  d:add("size", "combo", sizes, 4, 2)
  d:set("size", 1) -- default "small"

  presets.action = function(dialog)
    local idx = dialog:get("preset")
    if idx == 1 then
      dialog:set("table_text", DEFAULT_TEMPLATE)
    elseif idx == 2 then
      dialog:set("table_text", generateGridTabular(3, 3, "c"))
    elseif idx == 3 then
      dialog:set("table_text", generateGridTabular(4, 4, "c"))
    elseif idx == 4 then
      dialog:set("table_text", "")
    end
  end

  d:addButton("ok", "&Insert Table", "accept")
  d:addButton("cancel", "&Cancel", "reject")

  local r = d:execute()
  if not r then return end

  local inputStr = d:get("table_text")
  local sizeName = sizes[d:get("size")] or "small"

  if not inputStr or inputStr:match("^%s*$") then
    inputStr = DEFAULT_TEMPLATE
  end

  inputStr = inputStr:match("^%s*(.-)%s*$")
  local tableCode
  if inputStr:find("\\begin{tabular}") then
    tableCode = inputStr
  else
    tableCode = tsvToTabular(inputStr) or inputStr
  end

  if not tableCode or tableCode:match("^%s*$") then return end

  local pos = model.ui:pos() or V(100, 100)
  local obj = ipe.Text(model.attributes, tableCode, pos)
  obj:set("textsize", sizeName)
  obj:set("transformations", "translations")

  model:creation("insert TeX table", obj)
  model:autoRunLatex()
  model.ui:explain("Inserted TeX table")
end

methods = {
  { label = "Insert TeX Table...", run = insertTeXTable },
}

function run(model, num)
  if num == 1 or not num then
    insertTeXTable(model)
  end
end
