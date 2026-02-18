@tool
extends EditorPlugin

const ReferencesPanel = preload("res://addons/reference_finder/references_panel.gd")

var references_panel: Control
var script_editor: ScriptEditor

func _enter_tree():
    # get script editor reference
    script_editor = get_editor_interface().get_script_editor()
    
    # Create references panel
    references_panel = ReferencesPanel.new()
    references_panel.editor_interface = get_editor_interface()
    add_control_to_bottom_panel(references_panel, "References")
    
    # add menu item to Script menu
    add_tool_menu_item("Find References (Shift+F12)", _find_references)
    
    print("Reference Finder Plugin activated!")
    print("Use: Shift+F12 or Script → Find References")

func _exit_tree():
    # Cleanup
    remove_tool_menu_item("Find References (Shift+F12)")
    
    if references_panel:
        remove_control_from_bottom_panel(references_panel)
        references_panel.queue_free()

func _input(event: InputEvent):
    # Handle Shift+F12 "shortcut"
    if event is InputEventKey:
        if event.pressed and not event.echo:
            if event.keycode == KEY_F12 and event.shift_pressed and not event.ctrl_pressed:
                _find_references()
                get_viewport().set_input_as_handled()

func _find_references():
    if not script_editor:
        print("Ups! No Script Editor found!")
        return
    
    var current_editor = script_editor.get_current_editor()
    if not current_editor:
        print("Ups! No active Script Editor!")
        return
    
    var code_edit = _find_code_edit(current_editor)
    if not code_edit:
        print("Ups! No Code Edit found!")
        return
    
    # Get selected token
    var token = _get_token_at_cursor(code_edit)
    if token.is_empty():
        print("No token found at cursor")
        push_warning("Place cursor on a variable/function and try again")
        return
    
    print("Searching for references to: '%s'" % token)
    
    # Search for references
    var references = _search_references(token)
    
    print("[Reference Finder] Found %d references" % references.size())
    
    # Show results in panle
    references_panel.show_references(token, references)
    make_bottom_panel_item_visible(references_panel)

func _get_token_at_cursor(code_edit: CodeEdit) -> String:
    var line_idx = code_edit.get_caret_line()
    var column = code_edit.get_caret_column()
    var line = code_edit.get_line(line_idx)
    
    if column >= len(line):
        column = len(line) - 1
    
    # Find token boundaries
    var start = column
    var end = column
    
    var valid_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    
    # Find start of token
    while start > 0 and valid_chars.contains(line[start - 1]):
        start -= 1
    
    # Find end of token
    while end < len(line) and valid_chars.contains(line[end]):
        end += 1
    
    var token = line.substr(start, end - start)
    
    # Check if there's a dot before (for Global.variable cases)
    if start > 0 and line[start - 1] == '.':
        var obj_start = start - 1
        while obj_start > 0 and valid_chars.contains(line[obj_start - 1]):
            obj_start -= 1
        token = line.substr(obj_start, end - obj_start)
    
    return token

func _search_references(token: String) -> Array:
    var references = []
    var dir = DirAccess.open("res://")
    
    if not dir:
        return references
    
    _search_in_directory("res://", token, references)
    
    return references

func _search_in_directory(path: String, token: String, references: Array):
    var dir = DirAccess.open(path)
    if not dir:
        return
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        var full_path = path.path_join(file_name)
        
        if dir.current_is_dir():
            if file_name != "." and file_name != ".." and not file_name.begins_with("."):
                _search_in_directory(full_path, token, references)
        elif file_name.ends_with(".gd"):
            _search_in_file(full_path, token, references)
        
        file_name = dir.get_next()
    
    dir.list_dir_end()

func _search_in_file(file_path: String, token: String, references: Array):
    var file = FileAccess.open(file_path, FileAccess.READ)
    if not file:
        return
    
    var line_number = 0
    
    while not file.eof_reached():
        var line = file.get_line()
        line_number += 1
        
        # Search for token with word boundaries
        if _contains_token(line, token):
            references.append({
                "file": file_path,
                "line": line_number,
                "text": line.strip_edges()
            })
    
    file.close()

func _contains_token(line: String, token: String) -> bool:
    var valid_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
    var index = 0
    
    while true:
        index = line.find(token, index)
        if index == -1:
            break
        
        # Check word boundaries
        var before_ok = (index == 0) or not valid_chars.contains(line[index - 1])
        var after_ok = (index + len(token) >= len(line)) or not valid_chars.contains(line[index + len(token)])
        
        if before_ok and after_ok:
            return true
        
        index += 1
    
    return false

func _find_code_edit(node: Node) -> CodeEdit:
    if node is CodeEdit:
        return node
    
    for child in node.get_children():
        var result = _find_code_edit(child)
        if result:
            return result
    
    return null
