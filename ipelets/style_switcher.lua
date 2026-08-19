----------------------------------------------------------------------
-- style switcher ipelet
----------------------------------------------------------------------
--
-- Lets you swap this document's font family (Noto Sans / Times) and
-- its black <-> projector-gray color mode from the Ipelets menu,
-- instead of hand-editing the attached style sheets each time.
--
-- Expects font_notosans.isy, font_weight_medium.isy, font_times.isy
-- and color_mode_projector.isy to live in a "styles" directory next
-- to the "ipelets" directory this file is loaded from.
----------------------------------------------------------------------

label = "Style Switcher"

about = [[
Switch font family (Noto Sans / Times) and black <-> projector-gray
color mode by swapping the relevant style sheets on the current
document.
]]

-- Ipe's ipelet loader sets the global `path` to this file's absolute
-- path before running it; derive the sibling "styles" directory from it.
local function styleDir()
  local ipeletDir = path:match("^(.*)[/\\][^/\\]+$") or "."
  local repoRoot = ipeletDir:match("^(.*)[/\\][^/\\]+$") or ipeletDir
  return repoRoot .. "/styles"
end

-- Managed sheets always sit in this order, right above basic/standard
-- in override priority. Mode comes before font so the two groups
-- never reshuffle relative to each other between calls.
local MODE_GROUP = { "color_mode_projector" }
local FONT_GROUP = { "font_notosans", "font_weight_medium", "font_times" }
local ALL_MANAGED = { "color_mode_projector", "font_notosans", "font_weight_medium", "font_times" }

local function findSheetIndex(doc, name)
  for i = 1, doc:sheets():count() do
    if doc:sheets():sheet(i):name() == name then return i end
  end
  return nil
end

-- NOTE: in ipe.Cascade, index 1 is the HIGHEST-priority sheet (checked
-- first, wins name clashes) and the built-in "basic"/"standard"
-- sheets sit at the highest indices (lowest priority) -- the reverse
-- of their order in the saved XML file. ipe's own add-style.lua
-- inserts new sheets at index 1 for this reason.

-- Clones of the currently attached sheets whose name is in `names`,
-- in their current relative order.
local function collectSheets(doc, names)
  local wanted = {}
  for _, n in ipairs(names) do wanted[n] = true end
  local found = {}
  for i = 1, doc:sheets():count() do
    local s = doc:sheets():sheet(i)
    if wanted[s:name()] then found[#found + 1] = s:clone() end
  end
  return found
end

local function removeSheets(doc, names)
  local wanted = {}
  for _, n in ipairs(names) do wanted[n] = true end
  local i = 1
  while i <= doc:sheets():count() do
    if wanted[doc:sheets():sheet(i):name()] then
      doc:sheets():remove(i)
    else
      i = i + 1
    end
  end
end

-- Place `sheets` at consecutive cascade positions immediately above
-- basic/standard, preserving the array's order exactly: sheets[1] ends
-- up highest-priority (lowest index), sheets[#sheets] lowest-priority
-- (but still above basic). This is the exact inverse of collectSheets,
-- so re-inserting a collected snapshot reproduces it faithfully.
--
-- Ipe concatenates <preamble> text from lowest-priority (highest
-- index) sheets first, highest-priority (index 1) sheets last. E.g.
-- font_notosans defines \ifluatex (via iftex) and font_weight_medium
-- consumes it, so font_weight_medium's preamble must be emitted AFTER
-- font_notosans's -- meaning font_weight_medium needs the lower index
-- (higher priority). Callers building a fresh sheet list must order it
-- accordingly (most-specific/dependent first).
local function insertSheets(doc, sheets)
  local anchor = findSheetIndex(doc, "basic") or findSheetIndex(doc, "standard")
    or (doc:sheets():count() + 1)
  for i, sheet in ipairs(sheets) do
    doc:sheets():insert(anchor + i - 1, sheet)
  end
end

-- Undoably resync the mode and font sheets to `modeSheets` / `fontSheets`.
-- Passing nil for either keeps whatever is currently attached for that
-- group, so a font change never disturbs the mode setting and vice versa.
local function applyState(model, actionLabel, modeSheets, fontSheets)
  local doc = model.doc
  local before = collectSheets(doc, ALL_MANAGED)
  local mode = modeSheets or collectSheets(doc, MODE_GROUP)
  local font = fontSheets or collectSheets(doc, FONT_GROUP)
  local after = {}
  for _, s in ipairs(mode) do after[#after + 1] = s end
  for _, s in ipairs(font) do after[#after + 1] = s end

  local t = { label = actionLabel, model = model, style_sheets_changed = true }
  t.redo = function(t, doc)
    removeSheets(doc, ALL_MANAGED)
    insertSheets(doc, after)
  end
  t.undo = function(t, doc)
    removeSheets(doc, ALL_MANAGED)
    insertSheets(doc, before)
  end
  model:register(t)
  model:runLatex()
end

local function loadSheet(fname)
  local p = styleDir() .. "/" .. fname
  local sheet = ipe.Sheet(p)
  return sheet, p
end

local function setFont(model, choice)
  local files
  if choice == "regular" then
    files = { "font_notosans.isy" }
  elseif choice == "medium" then
    -- font_weight_medium must end up higher-priority (lower cascade
    -- index) than font_notosans so its preamble is emitted after
    -- font_notosans's \usepackage{iftex} -- see insertSheets.
    files = { "font_weight_medium.isy", "font_notosans.isy" }
  else
    files = { "font_times.isy" }
  end
  local sheets = {}
  for _, f in ipairs(files) do
    local sheet, failedPath = loadSheet(f)
    if not sheet then
      model:warning("Could not load style sheet", failedPath)
      return
    end
    sheets[#sheets + 1] = sheet
  end
  applyState(model, "switch font to " .. choice, nil, sheets)
end

local function setProjectorMode(model, on)
  local sheets = {}
  if on then
    local sheet, failedPath = loadSheet("color_mode_projector.isy")
    if not sheet then
      model:warning("Could not load style sheet", failedPath)
      return
    end
    sheets = { sheet }
  end
  applyState(model, on and "enable projector color mode" or "disable projector color mode", sheets, nil)
end

methods = {
  { label = "Font: Noto Sans (Regular)", run = function(model) setFont(model, "regular") end },
  { label = "Font: Noto Sans (Medium, for slides)", run = function(model) setFont(model, "medium") end },
  { label = "Font: Times / Helvetica", run = function(model) setFont(model, "times") end },
  { label = "Color mode: Projector (gray)", run = function(model) setProjectorMode(model, true) end },
  { label = "Color mode: Print (black)", run = function(model) setProjectorMode(model, false) end },
}
