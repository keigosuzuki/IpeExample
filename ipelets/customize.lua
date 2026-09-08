-- -- check prefs.lua for additional preference parameters
prefs.autosave_filename = "./%s.autosave"
prefs.autosave_interval = nil
prefs.editor_size = { 500, 500 }
-- default stylesheets added to newly created docs
prefs.styles = { "basic", "preamble" }
-- default latex autorun setting
prefs.auto_run_latex = true
-- auto export document when saved as .ipe
prefs.auto_export = {"pdf"}

-- -- check shortcuts.lua for additional shortcut parameters
shortcuts.previous_view = "Up"
shortcuts.next_view = "Down"
shortcuts.previous_page = "Left"
shortcuts.next_page = "Right"

-- Goodies shortcuts
shortcuts.ipelet_1_goodies = "Alt+B"   -- Insert rounded rectangle
shortcuts.ipelet_11_goodies = "Ctrl+R" -- Precise rotate
shortcuts.ipelet_12_goodies = "Ctrl+K" -- Precise stretch

-- Automatically deduplicate ipelets (keeps the first occurrence from IPELETPATH, suppresses built-in duplicates)
if _G.ipelets then
  local seen = {}
  local i = 1
  while i <= #_G.ipelets do
    local item = _G.ipelets[i]
    if seen[item.name] then
      item.label = nil
      table.remove(_G.ipelets, i)
    else
      seen[item.name] = true
      i = i + 1
    end
  end
end
