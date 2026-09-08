-- -- check prefs.lua for additional preference parameters
prefs.autosave_filename = "./%s.autosave"
prefs.autosave_interval = nil
prefs.editor_size = { 500, 500 }
-- external editor settings for visual studio code
-- if config.platform == "win" then
-- 	prefs.external_editor = "code.cmd --wait %s"
-- elseif config.platform == "apple" then
-- 	prefs.external_editor = "code --wait %s"
-- end
-- prefs.editable_textfile = config.latexdir .. "/temp.tex"
-- default stylesheets added to newly created docs
prefs.styles = { "basic", "preamble" }
-- default latex engine setting
-- prefs.tex_engine = "luatex"
-- default latex autorun setting
prefs.auto_run_latex = true
-- auto export document when saved as .ipe
prefs.auto_export = {"pdf"}

-- -- check shortcuts.lua for additional shortcut parameters
shortcuts.previous_view = "Up"
shortcuts.next_view = "Down"
shortcuts.previous_page = "Left"
shortcuts.next_page = "Right"

shortcuts.ipelet_1_rounded_rectangle = "Alt+B"
shortcuts.ipelet_1_textbox_background = "Alt+W"
shortcuts.ipelet_2_textbox_background = "Alt+Shift+W"
shortcuts.ipelet_5_textbox_background = "Alt+Ctrl+W"
