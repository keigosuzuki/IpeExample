----------------------------------------------------------------------
-- video ipelet (Media & Video Presenter for Pympress)
----------------------------------------------------------------------
--
-- Enables inserting video media (MP4, GIF, MOV, WebM) into Ipe slides
-- with interactive placement, poster thumbnail generation via ffmpeg,
-- and 1-click export of presentation PDFs with native Movie annotations
-- for Pympress and pdfpc.
----------------------------------------------------------------------

label = "Media"

about = [[
Insert and play videos (MP4, GIF, MOV) in Ipe presentations using Pympress.
Includes interactive placement, automatic poster frame extraction,
and 1-click Pympress presentation export.
]]

local V = ipe.Vector

local SCRIPT_DIR = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local INJECT_SCRIPT = SCRIPT_DIR .. "inject_media.py"

local PRESET_SIZES = {
  { label = "16:9 Medium (384 x 216 pt)", w = 384, h = 216 },
  { label = "16:9 Large (480 x 270 pt)", w = 480, h = 270 },
  { label = "16:9 Full Slide (640 x 360 pt)", w = 640, h = 360 },
  { label = "4:3 Medium (320 x 240 pt)", w = 320, h = 240 },
  { label = "4:3 Large (440 x 330 pt)", w = 440, h = 330 },
  { label = "1:1 Square (240 x 240 pt)", w = 240, h = 240 },
  { label = "Custom Size", w = 384, h = 216 },
}

----------------------------------------------------------------------
-- Helpers: Placeholder Box & Thumbnail Generation
----------------------------------------------------------------------

local function createPlaceholderBox(model, w, h, videoPath)
  local bgShape = {
    type = "curve", closed = true;
    { type = "segment"; V(0, 0), V(w, 0) },
    { type = "segment"; V(w, 0), V(w, h) },
    { type = "segment"; V(w, h), V(0, h) },
  }
  local bg = ipe.Path(model.attributes, { bgShape })
  bg:set("fill", "black")
  bg:set("stroke", "darkblue")
  bg:set("pathmode", "strokedfilled")

  -- Play button triangle in center
  local cx, cy = w / 2, h / 2
  local r = math.min(w, h) * 0.15
  if r < 12 then r = 12 end
  if r > 36 then r = 36 end
  local p1 = V(cx - r * 0.6, cy + r * 0.8)
  local p2 = V(cx + r, cy)
  local p3 = V(cx - r * 0.6, cy - r * 0.8)
  local playShape = {
    type = "curve", closed = true;
    { type = "segment"; p1, p2 },
    { type = "segment"; p2, p3 },
    { type = "segment"; p3, p1 },
  }
  local playIcon = ipe.Path(model.attributes, { playShape })
  playIcon:set("fill", "white")
  playIcon:set("pathmode", "filled")

  -- Label text with video filename
  local basename = videoPath:match("([^/\\]+)$") or videoPath
  local labelText = ipe.Text(model.attributes, "\\texttt{" .. basename:gsub("_", "\\_") .. "}", V(w / 2, 12))
  labelText:set("textsize", "small")
  labelText:set("stroke", "white")
  labelText:set("horizontalalignment", "center")
  labelText:set("transformations", "translations")

  return { bg, playIcon, labelText }
end

local function extractPosterBitmap(videoPath, w, h)
  -- Check if video file exists
  local f = io.open(videoPath, "r")
  if not f then return nil end
  f:close()

  local tmpPoster = "/tmp/ipe_poster_" .. os.time() .. ".png"
  local cmd = string.format("ffmpeg -y -ss 00:00:00.5 -i %q -vframes 1 -s %dx%d %q > /dev/null 2>&1",
                            videoPath, math.floor(w), math.floor(h), tmpPoster)
  local res = os.execute(cmd)
  if res == 0 or res == true then
    local bitmap, err = ipe.readImage(tmpPoster, "png")
    os.remove(tmpPoster)
    return bitmap
  end
  return nil
end

----------------------------------------------------------------------
-- VIDEOTOOL: Interactive Placement Tool
----------------------------------------------------------------------

local VIDEOTOOL = {}
VIDEOTOOL.__index = VIDEOTOOL

function VIDEOTOOL:new(model, groupObj, w, h, desc)
  local tool = {}
  _G.setmetatable(tool, VIDEOTOOL)
  tool.model = model
  tool.groupObj = groupObj
  tool.w = w
  tool.h = h
  tool.pos = model.ui:pos() or V(100, 100)
  model.ui:shapeTool(tool)
  tool.setColor(0.0, 0.45, 0.85)
  tool.setSnapping(true, true)
  tool:updateShape()
  model.ui:explain(desc or "Click on canvas to place video (or press Esc to cancel)")
  return tool
end

function VIDEOTOOL:updateShape()
  local p = self.pos
  local w, h = self.w, self.h
  local box = {
    type = "curve", closed = true;
    { type = "segment"; p, V(p.x + w, p.y) },
    { type = "segment"; V(p.x + w, p.y), V(p.x + w, p.y + h) },
    { type = "segment"; V(p.x + w, p.y + h), V(p.x, p.y + h) },
  }
  self.setShape({ box })
end

function VIDEOTOOL:mouseButton(button, modifiers, press)
  if not press then return end
  self.pos = self.model.ui:pos()
  self.model.ui:finishTool()

  -- Position group at self.pos
  local m = ipe.Translation(self.pos)
  self.groupObj:setMatrix(m)

  self.model:creation("insert video", self.groupObj)
  self.model.ui:explain("Inserted video object (Pympress ready)")
end

function VIDEOTOOL:mouseMove()
  self.pos = self.model.ui:pos()
  self:updateShape()
  self.model.ui:update(false)
end

function VIDEOTOOL:key(text, modifiers)
  if text == "\027" then -- Esc
    self.model.ui:finishTool()
    self.model.ui:explain("Cancelled video insertion")
    return true
  else
    return false
  end
end

----------------------------------------------------------------------
-- Action: Insert Video
----------------------------------------------------------------------

local function insertVideo(model)
  local d = ipeui.Dialog(model.ui:win(), "Insert Video (Pympress Presentation)")
  local presetLabels = {}
  for _, item in ipairs(PRESET_SIZES) do
    table.insert(presetLabels, item.label)
  end

  d:add("lbl_path", "label", { label = "Video File Path (MP4 / GIF / MOV / WebM):" }, 1, 1, 1, 4)
  d:add("videopath", "input", {}, 2, 1, 1, 3)
  d:addButton("browse", "&Browse...", function(dialog)
    local filter = "Video files (*.mp4 *.gif *.mov *.webm *.avi *.mkv);;All files (*.*)"
    local path = ipeui.fileDialog(model.ui:win(), "open", "Select Video File", filter, model.file or "")
    if path and path ~= "" then
      dialog:set("videopath", path)
    end
  end, 2, 4)

  d:add("lbl_size", "label", { label = "Display Size Preset:" }, 3, 1, 1, 4)
  presetLabels.action = function(dialog)
    local idx = dialog:get("preset")
    if idx and PRESET_SIZES[idx] then
      dialog:set("width", tostring(PRESET_SIZES[idx].w))
      dialog:set("height", tostring(PRESET_SIZES[idx].h))
    end
  end
  d:add("preset", "combo", presetLabels, 4, 1, 1, 4)
  d:set("preset", 1)

  d:add("lbl_w", "label", { label = "Width (pt):" }, 5, 1)
  d:add("width", "input", {}, 5, 2)
  d:set("width", tostring(PRESET_SIZES[1].w))

  d:add("lbl_h", "label", { label = "Height (pt):" }, 5, 3)
  d:add("height", "input", {}, 5, 4)
  d:set("height", tostring(PRESET_SIZES[1].h))

  d:add("controls", "checkbox", { label = "Show playback controls in Pympress" }, 6, 1, 1, 2)
  d:set("controls", true)
  d:add("loop", "checkbox", { label = "Loop playback continuously" }, 6, 3, 1, 2)
  d:set("loop", true)
  d:add("autostart", "checkbox", { label = "Autostart on slide entry" }, 7, 1, 1, 2)
  d:set("autostart", true)
  d:add("poster", "checkbox", { label = "Extract 1st-frame thumbnail via ffmpeg" }, 7, 3, 1, 2)
  d:set("poster", true)

  d:addButton("ok", "&Insert Video", "accept")
  d:addButton("cancel", "&Cancel", "reject")

  local r = d:execute()
  if not r then return end

  local videoPath = d:get("videopath")
  if not videoPath or videoPath:match("^%s*$") then
    model.ui:explain("Video insertion cancelled: No file path provided")
    return
  end
  videoPath = videoPath:match("^%s*(.-)%s*$")

  local w = tonumber(d:get("width")) or 384
  local h = tonumber(d:get("height")) or 216
  local c = d:get("controls") and 1 or 0
  local l = d:get("loop") and 1 or 0
  local a = d:get("autostart") and 1 or 0
  local extractPoster = d:get("poster")

  local elements = {}
  local bitmap
  if extractPoster then
    bitmap = extractPosterBitmap(videoPath, w, h)
  end

  if bitmap then
    local r = ipe.Rect(V(0, 0), V(w, h))
    local img = ipe.Image(r, bitmap)
    table.insert(elements, img)

    -- Add a subtle border around the poster image
    local borderShape = {
      type = "curve", closed = true;
      { type = "segment"; V(0, 0), V(w, 0) },
      { type = "segment"; V(w, 0), V(w, h) },
      { type = "segment"; V(w, h), V(0, h) },
    }
    local border = ipe.Path(model.attributes, { borderShape })
    border:set("stroke", "darkblue")
    border:set("pen", "heavier")
    table.insert(elements, border)
  else
    elements = createPlaceholderBox(model, w, h, videoPath)
  end

  local group = ipe.Group(elements)
  local mediaUrl = string.format("movie:%s?controls=%d&loop=%d&autostart=%d", videoPath, c, l, a)
  group:setText(mediaUrl)

  VIDEOTOOL:new(model, group, w, h, "Click to place video on canvas (Esc to cancel)")
end

----------------------------------------------------------------------
-- Action: Export Presentation for Pympress
----------------------------------------------------------------------

local function exportForPympress(model)
  if not model.file then
    local path = ipeui.fileDialog(model.ui:win(), "save", "Save Ipe File First", "Ipe files (*.ipe)", "")
    if not path or path == "" then return end
    model.file = path
    model:save(model.file)
  else
    model:save(model.file)
  end

  local ipePath = model.file
  local pdfPath = ipePath:gsub("%.ipe$", ".pdf")
  if pdfPath == ipePath then pdfPath = ipePath .. ".pdf" end

  -- 1. Run ipetoipe -pdf
  local convCmd = string.format("ipetoipe -pdf %q %q", ipePath, pdfPath)
  local res = os.execute(convCmd)
  if res ~= 0 and res ~= true then
    model.ui:explain("Error: Failed to export PDF via ipetoipe")
    return
  end

  -- 2. Inject media annotations via inject_media.py
  local injectCmd = string.format("python3 %q %q", INJECT_SCRIPT, pdfPath)
  local injRes = os.execute(injectCmd)
  if injRes == 0 or injRes == true then
    model.ui:explain(string.format("Exported Pympress presentation: %s", pdfPath))
  else
    model.ui:explain("Warning: PDF exported but media annotation injection encountered an issue")
  end
  return pdfPath
end

----------------------------------------------------------------------
-- Action: Launch in Pympress
----------------------------------------------------------------------

local function launchInPympress(model)
  local pdfPath = exportForPympress(model)
  if pdfPath then
    os.execute(string.format("pympress %q > /dev/null 2>&1 &", pdfPath))
    model.ui:explain("Launched presentation in Pympress")
  end
end

----------------------------------------------------------------------
-- Ipelet Methods Registration
----------------------------------------------------------------------

methods = {
  { label = "Insert Video (MP4 / GIF / MOV)...", run = insertVideo },
  { label = "Export Presentation for Pympress", run = exportForPympress },
  { label = "Launch in Pympress (Preview)", run = launchInPympress },
}

function run(model, num)
  if num == 1 then
    insertVideo(model)
  elseif num == 2 then
    exportForPympress(model)
  elseif num == 3 then
    launchInPympress(model)
  end
end
