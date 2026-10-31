@tool
extends Control
## Bottom-panel view that lists every reference (usage) of a symbol, grouped by
## file, with syntax-colored source lines (RichTextLabel + BBCode, like the
## rename preview). Clicking a line opens that file in the script editor at the
## exact position.

const LspClient   = preload("res://addons/gdscript_refactoring/qb_lsp_client.gd")
const FileScanner = preload("res://addons/gdscript_refactoring/qb_file_scanner.gd")

var editor_plugin: EditorPlugin

var _header:  Label
var _body:    RichTextLabel
var _busy:    bool = false
var _jump: Array = []


func _init() -> void:
	name = "References"
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0, 180)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 4)
	add_child(vb)

	_header = Label.new()
	_header.text = "Find all references — right-click a symbol and choose \"Find all references\" (Alt+Shift+F2)."
	_header.add_theme_color_override("font_color", Color(0.6, 0.62, 0.66))
	vb.add_child(_header)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = true
	_body.selection_enabled = true
	_body.focus_mode = Control.FOCUS_NONE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.meta_clicked.connect(_on_meta_clicked)
	_apply_monospace_font(_body)
	vb.add_child(_body)


func find_references(symbol: String, symbol_pos: Dictionary) -> void:
	if _busy:
		return
	if symbol_pos.is_empty():
		_header.text = "No cursor position available. Right-click on the symbol first."
		return
	_busy = true
	_header.text = "Searching for references to \"%s\"…" % symbol
	_body.text = ""
	_jump.clear()
	# Free any leftover detached highlighter from a previous search immediately
	# (queue_free is deferred; a lingering hidden CodeEdit child can make the
	# next _make_highlighter_edit pick the wrong editor / produce empty output).
	for child in get_children():
		if child is CodeEdit:
			remove_child(child)
			child.free()
	if editor_plugin:
		editor_plugin.make_bottom_panel_item_visible(self)
	_search_coroutine(symbol, symbol_pos)


func _search_coroutine(symbol: String, symbol_pos: Dictionary) -> void:
	var lsp := LspClient.new()
	lsp.setup(Engine.get_main_loop() as SceneTree)

	var project_abs := ProjectSettings.globalize_path("res://")
	var root_uri    := LspClient.path_to_uri(project_abs.trim_suffix("/").trim_suffix("\\"))

	var ok := await lsp.connect_to_lsp(root_uri)
	if not ok:
		_header.text = "Cannot connect to the GDScript language server."
		_busy = false
		return

	var sync_version := Time.get_ticks_msec()
	var scanner := FileScanner.new()
	var gd_files := scanner.collect_gd_files("res://")
	var sent := 0
	for abs_path in gd_files:
		var uri := LspClient.path_to_uri(abs_path)
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			var source := f.get_as_text()
			f.close()
			lsp.did_open(uri, source, sync_version)
			lsp.poll()
			sent += 1
			if sent % 5 == 0:
				await Engine.get_main_loop().process_frame

	await Engine.get_main_loop().create_timer(1.0).timeout

	var locations = await lsp.references(
		symbol_pos["uri"], symbol_pos["line"], symbol_pos["character"], true)
	lsp.disconnect_from_lsp()

	if locations == null or (locations is Array and (locations as Array).is_empty()):
		_header.text = "No references found for \"%s\"." % symbol
		_busy = false
		return

	_populate(symbol, locations as Array)
	_busy = false


func _populate(symbol: String, locations: Array) -> void:
	var by_file: Dictionary = {}
	for loc in locations:
		var abs_path := LspClient.uri_to_path(loc["uri"])
		var r: Dictionary = loc["range"]
		var entry := {
			"line": int(r["start"]["line"]),
			"sc":   int(r["start"]["character"]),
			"ec":   int(r["end"]["character"]),
		}
		if not by_file.has(abs_path):
			by_file[abs_path] = []
		by_file[abs_path].append(entry)

	var total := locations.size()
	var file_count := by_file.size()
	_header.text = "%d reference%s to \"%s\" in %d file%s   —   click a line to open it" % [
		total, "" if total == 1 else "s", symbol,
		file_count, "" if file_count == 1 else "s"]

	var string_color := _hex(_theme_color("string_color", Color(0.8, 0.8, 0.4)))
	var num_color    := _hex(_theme_color("line_number_color", Color(0.5, 0.5, 0.55)))

	var hl := _make_highlighter_edit()

	var bb := ""
	var files := by_file.keys()
	files.sort()
	for abs_path in files:
		var res_path := ProjectSettings.localize_path(abs_path)
		var entries: Array = by_file[abs_path]
		bb += "[color=#%s][b]%s[/b][/color]  [color=#888888](%d)[/color]\n" % [
			string_color, res_path, entries.size()]

		var lines := _read_lines(abs_path)
		if hl and not lines.is_empty():
			hl.text = "\n".join(PackedStringArray(lines))
		var members := _collect_member_variables(lines)

		var max_ln := 0
		for e in entries:
			max_ln = maxi(max_ln, int(e["line"]) + 1)
		var num_w := str(max_ln).length()

		entries.sort_custom(func(a, b): return a["line"] < b["line"])
		for e in entries:
			var ln: int = e["line"]
			var raw: String = lines[ln] if ln < lines.size() else ""
			var jump_idx := _jump.size()
			_jump.append({"path": res_path, "line": ln, "col": int(e["sc"])})

			var num := str(ln + 1).lpad(num_w)
			var colored := _colorize_line(hl, raw, ln, int(e["sc"]), int(e["ec"]), members)
			bb += "  [color=#%s]%s[/color]  [url=%d]%s[/url]\n" % [
				num_color, num, jump_idx, colored]
		bb += "\n"

	_body.text = bb

	if hl and is_instance_valid(hl):
		remove_child(hl)
		hl.free()


func _on_meta_clicked(meta: Variant) -> void:
	var idx := int(str(meta))
	if idx < 0 or idx >= _jump.size():
		return
	var jump: Dictionary = _jump[idx]
	var scr = load(jump["path"])
	if scr is Script:
		# The LSP reports 0-based lines; edit_script expects a 1-based line
		# (passing the 0-based value lands the caret one line too high).
		EditorInterface.edit_script(scr, int(jump["line"]) + 1, int(jump["col"]))


func _colorize_line(hl: CodeEdit, raw: String, line_index: int,
		sc: int, ec: int, members: Dictionary) -> String:
	if raw == "":
		return ""
	var default_col := _theme_color("text_color", Color(0.86, 0.86, 0.86))
	var member_col  := _theme_color("member_variable_color", Color(0.6, 0.75, 1.0))

	var col_map: Dictionary = {}
	if hl and line_index < hl.get_line_count():
		var sh = hl.syntax_highlighter
		if sh:
			col_map = sh.get_line_syntax_highlighting(line_index)

	var change_cols: Array = col_map.keys()
	change_cols.sort()

	# Clamp the highlight span to the actual line bounds so we never open a
	# [bgcolor] tag we can't close (an unbalanced tag makes the whole
	# RichTextLabel render empty — this was the intermittent blank-body bug).
	var hl_start := sc
	var hl_end   := ec
	if hl_start < 0:
		hl_start = 0
	if hl_end > raw.length():
		hl_end = raw.length()
	var do_highlight := hl_start < hl_end   # only if the span is non-empty & in-range

	var out := ""
	var cur_col := default_col
	var next_i := 0
	var member_spans := _member_spans(raw, members)
	var hl_open := false

	for i in raw.length():
		while next_i < change_cols.size() and int(change_cols[next_i]) <= i:
			var c = col_map[change_cols[next_i]]
			if c is Dictionary and c.has("color"):
				cur_col = c["color"]
			next_i += 1
		var use_col: Color = cur_col
		for ms in member_spans:
			if i >= ms[0] and i < ms[1]:
				use_col = member_col
				break
		if do_highlight and i == hl_start:
			out += "[bgcolor=#3d5a80]"
			hl_open = true
		var ch := raw[i]
		var esc := ch.replace("[", "[lb]")
		var draw_col := "ffffff" if hl_open else _hex(use_col)
		out += "[color=#%s]%s[/color]" % [draw_col, esc]
		if hl_open and i == hl_end - 1:
			out += "[/bgcolor]"
			hl_open = false
	# Safety: if the highlight opened but never closed (shouldn't happen after
	# clamping), close it so the BBCode stays balanced.
	if hl_open:
		out += "[/bgcolor]"
	return out


func _member_spans(raw: String, members: Dictionary) -> Array:
	var spans: Array = []
	if members.is_empty():
		return spans
	var rx := RegEx.new()
	rx.compile("[A-Za-z_]\\w*")
	for m in rx.search_all(raw):
		if members.has(m.get_string()):
			spans.append([m.get_start(), m.get_end()])
	return spans


func _read_lines(abs_path: String) -> Array:
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return []
	var src := f.get_as_text()
	f.close()
	return Array(src.split("\n"))


func _make_highlighter_edit() -> CodeEdit:
	var se := EditorInterface.get_script_editor()
	var base := se.get_current_editor()
	if base == null:
		return null
	var src_edit := _find_code_edit_node(base)
	if src_edit == null:
		return null
	var ce := CodeEdit.new()
	if src_edit.syntax_highlighter:
		ce.syntax_highlighter = src_edit.syntax_highlighter.duplicate(true)
	ce.visible = false
	add_child(ce)
	return ce


func _find_code_edit_node(node: Node) -> CodeEdit:
	if node is CodeEdit:
		return node as CodeEdit
	for child in node.get_children():
		var r := _find_code_edit_node(child)
		if r:
			return r
	return null


func _theme_color(key: String, fallback: Color) -> Color:
	var ed := EditorInterface.get_editor_settings()
	var c = ed.get_setting("text_editor/theme/highlighting/%s" % key)
	if c is Color:
		return c as Color
	return fallback


func _hex(c: Color) -> String:
	return c.to_html(false)


func _collect_member_variables(lines: Array) -> Dictionary:
	var members: Dictionary = {}
	var decl := RegEx.new()
	decl.compile("^(?:@\\w+\\s*(?:\\([^)]*\\))?\\s*)*(?:static\\s+)?(?:var|const)\\s+([A-Za-z_]\\w*)")
	for raw in lines:
		var line: String = raw
		if line.length() > 0 and (line[0] == " " or line[0] == "\t"):
			continue
		var m := decl.search(line)
		if m:
			members[m.get_string(1)] = true
	return members


func _apply_monospace_font(rtl: RichTextLabel) -> void:
	var ed := EditorInterface.get_editor_settings()
	var fp = ed.get_setting("interface/editor/code_font")
	if fp is String and fp != "" and ResourceLoader.exists(fp):
		var fnt = load(fp)
		if fnt is Font:
			rtl.add_theme_font_override("normal_font", fnt)
			rtl.add_theme_font_override("bold_font", fnt)
	var fs = ed.get_setting("interface/editor/code_font_size")
	if fs is int:
		rtl.add_theme_font_size_override("normal_font_size", fs)
		rtl.add_theme_font_size_override("bold_font_size", fs)
	rtl.add_theme_constant_override("line_separation", 4)
